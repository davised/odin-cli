#+feature global-context
package tree

import style "../style"
import "../term"
import "core:fmt"
import "core:io"
import "core:strings"

// 64 levels handles any practical tree; exceeding this returns false.
MAX_DEPTH :: 64

// Cached_Enum_Widths stores pre-computed display widths for an enumerator's 4 strings.
@(private = "file")
Cached_Enum_Widths :: struct {
	e:           ^Enumerator,
	item_w:      int,
	last_item_w: int,
	branch_w:    int,
	padding_w:   int,
}

@(private = "file")
make_cached_enum_widths :: proc(e: ^Enumerator) -> Cached_Enum_Widths {
	return Cached_Enum_Widths {
		e           = e,
		item_w      = term.display_width(e.item),
		last_item_w = term.display_width(e.last_item),
		branch_w    = term.display_width(e.branch),
		padding_w   = term.display_width(e.padding),
	}
}

@(private = "file")
Render_State :: struct {
	w:                  io.Writer,
	n:                  ^int,
	default_enumerator: Enumerator,
	prefix:             [MAX_DEPTH]string,
	depth:              int,
	max_width:          int,
	prefix_width:       int, // cached cumulative display width of prefix[0..depth-1]
	mode:               term.Render_Mode,
	prefix_buf:         [MAX_DEPTH * 8]u8, // pre-concatenated prefix bytes
	prefix_buf_len:     int,               // current length of prefix_buf content
}

@(private = "file")
write_str :: proc(state: ^Render_State, s: string) -> bool {
	_, err := io.write_string(state.w, s, state.n)
	return err == .None
}

@(private = "file")
write_prefix :: proc(state: ^Render_State) -> bool {
	if state.prefix_buf_len > 0 {
		_, err := io.write_string(state.w, string(state.prefix_buf[:state.prefix_buf_len]), state.n)
		return err == .None
	}
	return true
}

@(private = "file")
write_styled :: proc(state: ^Render_State, text: string, is_styled: bool, s: style.Style) -> bool {
	if is_styled {
		style.to_writer(state.w, style.Styled_Text{text = text, style = s}, state.n, state.mode) or_return
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
Labels are written verbatim; callers passing untrusted input should sanitize
with `term.strip_ansi`. Depth is capped at MAX_DEPTH (64); the prefix buffer
is limited to MAX_DEPTH * 8 bytes.

Inputs:
	w: The io.Writer to write the rendered tree to.
	t: The Tree to render.
	enumerator: The Enumerator to use for branch characters. Defaults to DEFAULT_ENUMERATOR.
	n: Optional pointer to an int that accumulates the number of bytes written.

Returns:
	bool: true if rendering succeeded, false on write error or depth overflow.
*/
to_writer :: proc(w: io.Writer, t: Tree, enumerator: Enumerator = DEFAULT_ENUMERATOR, n: ^int = nil, mode: term.Render_Mode = .Full) -> bool {
	state := Render_State {
		w                  = w,
		n                  = n,
		default_enumerator = enumerator,
		max_width          = t.width,
		mode               = mode,
	}

	// Write root line if present (unconstrained — no prefix or connector overhead)
	if t.root != nil {
		write_wrapped(&state, t.root, state.max_width, "") or_return
	}

	// Render children
	enum_ptr := t.enumerator if t.enumerator != nil else &state.default_enumerator
	cew := make_cached_enum_widths(enum_ptr)
	render_children(&state, t.children, enum_ptr, &cew) or_return

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
to_str :: proc(
	t: Tree,
	enumerator: Enumerator = DEFAULT_ENUMERATOR,
	mode: term.Render_Mode = .Full,
	allocator := context.allocator,
) -> (
	string,
	bool,
) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), t, enumerator, mode = mode)
	return strings.to_string(sb), ok
}

/* Renders all children of a node at the current depth. */
@(private = "file")
render_children :: proc(state: ^Render_State, children: []Tree_Item, e: ^Enumerator, cew: ^Cached_Enum_Widths) -> bool {
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

		// Compute content budget using cached prefix width and cached connector width
		content_budget := 0
		if state.max_width > 0 {
			connector_width := cew.last_item_w if is_last else cew.item_w
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
			cont_width := cew.padding_w if is_last else cew.branch_w

			// Push to prefix buffer
			old_buf_len := state.prefix_buf_len
			cp_bytes := transmute([]u8)cont_prefix
			if old_buf_len + len(cp_bytes) > len(state.prefix_buf) {
				return false
			}
			copy(state.prefix_buf[old_buf_len:], cp_bytes)
			state.prefix_buf_len += len(cp_bytes)

			state.prefix_width += cont_width
			state.depth += 1
			sub_enum := c.enumerator if c.enumerator != nil else e
			// Only recompute cached widths if enumerator changed
			sub_cew: Cached_Enum_Widths
			if sub_enum != e {
				sub_cew = make_cached_enum_widths(sub_enum)
			} else {
				sub_cew = cew^
			}
			render_children(state, c.children, sub_enum, &sub_cew) or_return
			state.depth -= 1
			state.prefix_width -= cont_width
			state.prefix_buf_len = old_buf_len
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
