#+feature using-stmt
package spinner

import "core:io"
import "core:strings"
import "../style"

/* to_writer renders the current spinner frame and message to an io.Writer.
   Output format: ⠋ Loading...
   No terminal control sequences — testable with a string builder. */
to_writer :: proc(w: io.Writer, s: Spinner, n: ^int = nil) -> bool {
  num_frames := len(s.frames.frames)
  if num_frames == 0 do return true

  frame := s.frames.frames[s._frame_idx % num_frames]

  // Render frame with optional style
  if ts, has_style := s.text_style.?; has_style {
    st := style.Styled_Text{text = frame, style = ts}
    if !style.to_writer(w, st, n) do return false
  } else {
    _, err := io.write_string(w, frame, n)
    if err != .None do return false
  }

  // Message with separating space
  if s.message != "" {
    _, err := io.write_string(w, " ", n)
    if err != .None do return false
    _, err2 := io.write_string(w, s.message, n)
    if err2 != .None do return false
  }

  return true
}

/* to_str renders the current spinner frame and message to an allocated string. */
to_str :: proc(s: Spinner, allocator := context.allocator) -> (string, bool) {
  sb := strings.builder_make(allocator = allocator)
  ok := to_writer(strings.to_writer(&sb), s)
  if !ok {
    strings.builder_destroy(&sb)
    return "", false
  }
  return strings.to_string(sb), true
}
