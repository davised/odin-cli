#+feature global-context
package tree

import "core:fmt"
import "core:io"
import "core:strings"
import style "../style"

// 64 levels handles any practical tree; exceeding this returns false.
MAX_DEPTH :: 64

@(private = "file")
Render_State :: struct {
  w:                  io.Writer,
  n:                  ^int,
  default_enumerator: Enumerator,
  prefix:             [MAX_DEPTH]string,
  depth:              int,
}

@(private = "file")
write_str :: proc(state: ^Render_State, s: string) -> bool {
  _, err := io.write_string(state.w, s, state.n)
  return err == .None
}

/* Writes a Tree_Root value (string or Styled_Text) followed by a newline. Nil roots are skipped. */
@(private = "file")
write_line :: proc(state: ^Render_State, content: Tree_Root) -> bool {
  switch c in content {
  case string:
    write_str(state, c) or_return
    write_str(state, "\n") or_return
  case style.Styled_Text:
    style.to_writer(state.w, c, state.n) or_return
    write_str(state, "\n") or_return
  }
  return true
}

/*
to_writer renders a tree to an io.Writer.

Parameters:
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
  }

  // Write root line if present
  write_line(&state, t.root) or_return

  // Render children
  enum_ptr := t.enumerator if t.enumerator != nil else &state.default_enumerator
  render_children(&state, t.children, enum_ptr) or_return

  return true
}

/*
to_str converts a Tree to a string representation.
The caller owns the returned string and must delete it.

Parameters:
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
    for d in 0 ..< state.depth {
      write_str(state, state.prefix[d]) or_return
    }

    // Write connector
    connector := e.last_item if is_last else e.item
    write_str(state, connector) or_return

    switch c in child {
    case string:
      write_line(state, c) or_return
    case style.Styled_Text:
      write_line(state, c) or_return
    case ^Tree:
      // Write subtree root on the same line
      write_line(state, c.root) or_return

      // Push prefix and recurse
      if state.depth >= MAX_DEPTH {
        return false
      }
      state.prefix[state.depth] = e.padding if is_last else e.branch
      state.depth += 1
      sub_enum := c.enumerator if c.enumerator != nil else e
      render_children(state, c.children, sub_enum) or_return
      state.depth -= 1
    }
  }
  return true
}

@(private = "file")
@(init)
init_formatter :: proc() {
  if fmt._user_formatters == nil {
    fmt.set_user_formatters(new(map[typeid]fmt.User_Formatter))
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
