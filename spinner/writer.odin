#+feature using-stmt
#+feature global-context
package spinner

import "../style"
import "core:fmt"
import "core:io"
import "core:strings"

@(private = "file")
_formatter_map: map[typeid]fmt.User_Formatter

@(private = "file")
@(init)
init_formatter :: proc() {
	if fmt._user_formatters == nil {
		fmt._user_formatters = &_formatter_map
	}
	fmt.register_user_formatter(type_info_of(Spinner).id, spinner_formatter)
}

/* to_writer renders the current spinner frame and message to an io.Writer.
   Output format: ⠋ Loading...
   No terminal control sequences — testable with a string builder. */
to_writer :: proc(w: io.Writer, s: Spinner, n: ^int = nil) -> bool {
	num_frames := len(s.frames.frames)
	if num_frames == 0 do return true

	frame := s.frames.frames[s._frame_idx % num_frames]

	// Render frame with optional style
	if ts, has_style := s.text_style.?; has_style {
		st := style.Styled_Text {
			text  = frame,
			style = ts,
		}
		style.to_writer(w, st, n) or_return
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

/*
to_str renders the current spinner frame and message to an allocated string.
The caller owns the returned string and must free it regardless of the ok
return value (a failed render may produce partial output).

Inputs:
- s: The Spinner to render.
- allocator: Allocator for the resulting string.

Returns:
- string: The rendered spinner frame and message.
- bool: true if rendering succeeded.
*/
to_str :: proc(s: Spinner, allocator := context.allocator) -> (string, bool) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), s)
	return strings.to_string(sb), ok
}

/*
spinner_formatter is a custom fmt.User_Formatter for Spinner values.
Enables printing spinners directly with fmt.println, fmt.aprintf, etc.
*/
@(private = "file")
spinner_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
	s := cast(^Spinner)arg.data

	switch verb {
	case 'v', 's':
		return to_writer(fi.writer, s^, &fi.n)
	case 'w':
		fi.ignore_user_formatters = true
		fmt.fmt_value(fi = fi, v = s^, verb = 'w')
		return true
	case:
		return false
	}
}
