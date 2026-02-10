#+feature global-context
package tree

import "core:fmt"
import "core:io"
import "core:strings"
import style "../style"
import "../term"

// 64 levels handles any practical tree; exceeding this returns false.
MAX_DEPTH :: 64

@(private = "file")
Render_State :: struct {
	w:                  io.Writer,
	n:                  ^int,
	default_enumerator: Enumerator,
	prefix:             [MAX_DEPTH]string,
	depth:              int,
	max_width:          int,
	prefix_width:       int, // cached cumulative display width of prefix[0..depth-1]
}

@(private = "file")
write_str :: proc(state: ^Render_State, s: string) -> bool {
	_, err := io.write_string(state.w, s, state.n)
	return err == .None
}

@(private = "file")
write_prefix :: proc(state: ^Render_State) -> bool {
	for d in 0 ..< state.depth {
		write_str(state, state.prefix[d]) or_return
	}
	return true
}

@(private = "file")
write_styled :: proc(state: ^Render_State, text: string, is_styled: bool, s: style.Style) -> bool {
	if is_styled {
		style.to_writer(state.w, style.Styled_Text{text = text, style = s}, state.n) or_return
	} else {
		write_str(state, text) or_return
	}
	return true
}

/* Writes content with wrapping support. The first line is written at the
	 current cursor position (prefix + connector already emitted by caller).
	 Continuation lines are indented with ancestor prefixes + cont_prefix.
	 If content is nil, writes only a newline (bare connector line for
	 subtrees with no root label). */
@(private = "file")
write_wrapped :: proc(state: ^Render_State, content: Tree_Root, content_width: int, cont_prefix: string) -> bool {
	text: string
	is_styled: bool
	s: style.Style

	switch c in content {
	case string:
		text = c
	case style.Styled_Text:
		text = c.text
		is_styled = true
		s = c.style
	case:
		write_str(state, "\n") or_return
		return true
	}

	// No wrapping needed if unlimited or text fits
	if content_width <= 0 || term.display_width(text) <= content_width {
		write_styled(state, text, is_styled, s) or_return
		write_str(state, "\n") or_return
		return true
	}

	// Wrap across multiple lines
	wit := term.wrap_iterator_make(text, content_width)
	first := true
	for line in term.wrap_iterate(&wit) {
		if !first {
			write_prefix(state) or_return
			write_str(state, cont_prefix) or_return
		}
		write_styled(state, line, is_styled, s) or_return
		write_str(state, "\n") or_return
		first = false
	}

	return true
}

/*
to_writer renders a tree to an io.Writer.

Inputs:
	w: The io.Writer to write the rendered tree to.
	t: The Tree to render.
	enumerator: The Enumerator to use for branch characters. Defaults to DEFAULT_ENUMERATOR.
	n: Optional pointer to an int that accumulates the number of bytes written.

Returns:
	bool: true if rendering succeeded, false on write error or depth overflow.
*/
to_writer :: proc(w: io.Writer, t: Tree, enumerator: Enumerator = DEFAULT_ENUMERATOR, n: ^int = nil) -> bool {
	state := Render_State {
		w                  = w,
		n                  = n,
		default_enumerator = enumerator,
		max_width          = t.width,
	}

	// Write root line if present (unconstrained — no prefix or connector overhead)
	if t.root != nil {
		write_wrapped(&state, t.root, state.max_width, "") or_return
	}

	// Render children
	enum_ptr := t.enumerator if t.enumerator != nil else &state.default_enumerator
	render_children(&state, t.children, enum_ptr) or_return

	return true
}

/*
to_str converts a Tree to a string representation.
The caller owns the returned string and must free it regardless of the ok
return value (a failed render may produce partial output).

Inputs:
	t: The Tree to render.
	enumerator: The Enumerator to use for branch characters. Defaults to DEFAULT_ENUMERATOR.
	allocator: Allocator for the resulting string.

Returns:
	string: The rendered tree as a string.
	bool: true if rendering succeeded.
*/
to_str :: proc(t: Tree, enumerator: Enumerator = DEFAULT_ENUMERATOR, allocator := context.allocator) -> (string, bool) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), t, enumerator)
	return strings.to_string(sb), ok
}

/* Renders all children of a node at the current depth. */
@(private = "file")
render_children :: proc(state: ^Render_State, children: []Tree_Item, e: ^Enumerator) -> bool {
	count := len(children)
	for child, i in children {
		is_last := i == count - 1

		// Write accumulated prefix from ancestor levels
		write_prefix(state) or_return

		// Write connector
		connector := e.last_item if is_last else e.item
		write_str(state, connector) or_return

		// Continuation prefix for wrapped lines (same width, maintains vertical lines)
		cont_prefix := e.padding if is_last else e.branch

		// Compute content budget using cached prefix width
		content_budget := 0
		if state.max_width > 0 {
			connector_width := term.display_width(connector)
			content_budget = state.max_width - state.prefix_width - connector_width
			if content_budget < 1 {
				content_budget = 1
			}
		}

		switch c in child {
		case string:
			write_wrapped(state, c, content_budget, cont_prefix) or_return
		case style.Styled_Text:
			write_wrapped(state, c, content_budget, cont_prefix) or_return
		case ^Tree:
			// Write subtree root on the same line (may wrap)
			write_wrapped(state, c.root, content_budget, cont_prefix) or_return

			// Push prefix and recurse
			if state.depth >= MAX_DEPTH {
				return false
			}
			state.prefix[state.depth] = cont_prefix
			cont_width := term.display_width(cont_prefix)
			state.prefix_width += cont_width
			state.depth += 1
			sub_enum := c.enumerator if c.enumerator != nil else e
			render_children(state, c.children, sub_enum) or_return
			state.depth -= 1
			state.prefix_width -= cont_width
		}
	}
	return true
}

@(private = "file")
_formatter_map: map[typeid]fmt.User_Formatter

@(private = "file")
@(init)
init_formatter :: proc() {
	if fmt._user_formatters == nil {
		fmt._user_formatters = &_formatter_map
	}
	fmt.register_user_formatter(type_info_of(Tree).id, tree_formatter)
}

/*
tree_formatter is a custom fmt.User_Formatter for Tree values.
Enables printing trees directly with fmt.println, fmt.aprintf, etc.
*/
@(private = "file")
tree_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
	t := cast(^Tree)arg.data

	switch verb {
	case 'v', 's':
		return to_writer(fi.writer, t^, n = &fi.n)
	case 'w':
		fi.ignore_user_formatters = true
		fmt.fmt_value(fi = fi, v = t^, verb = 'w')
		return true
	case:
		return false
	}
}
