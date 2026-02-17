#+feature global-context
package style

import "../term"
import "core:fmt"
import "core:io"
import "core:strings"
import "core:terminal/ansi"

@(private = "file")
_formatter_map: map[typeid]fmt.User_Formatter

@(private = "file")
@(init)
init_formatter :: proc() {
	if fmt._user_formatters == nil {
		fmt._user_formatters = &_formatter_map
	}
	fmt.register_user_formatter(type_info_of(Styled_Text).id, Styled_Text_Formatter)
}

/*
text_styles_to_writer writes ANSI escape sequences for a set of text styles to the provided writer.
Multiple styles are combined into a single SGR sequence (e.g. `\e[1;3;4m` for bold+italic+underline).

Inputs:
- w: The writer to output escape sequences to.
- s: The text style set to encode.
- n: Pointer to a byte counter; incremented by the number of bytes written.

Returns:
- An `io.Error` if writing fails, `io.Error.None` on success.
*/
text_styles_to_writer :: proc(w: io.Writer, s: Text_Style_Set, n: ^int) -> io.Error {
	first := true
	num_styles := card(s)
	for style in s {
		if first {
			io.write_string(w, ansi.CSI, n) or_return
			io.write_uint(w, uint(style), 10, n) or_return
			first = false
		} else {
			io.write_string(w, ";", n) or_return
			io.write_uint(w, uint(style), 10, n) or_return
		}
	}
	if num_styles > 0 {
		io.write_string(w, ansi.SGR, n) or_return
	}
	return io.Error.None
}

/*
color_to_writer writes ANSI escape sequences for a color to the provided writer.
Supports ANSI_Color (standard 16 colors), EightBit (256 colors), and RGB (24-bit true color).
When `bg` is true, background codes are emitted; otherwise foreground codes.

Inputs:
- w: The writer to output escape sequences to.
- data: The color specification. A nil value produces no output.
- bg: When true, emits background color codes; otherwise foreground.
- n: Pointer to a byte counter; incremented by the number of bytes written.

Returns:
- An `io.Error` if writing fails, `io.Error.None` on success.
*/
color_to_writer :: proc(w: io.Writer, data: Colors, bg: bool, n: ^int) -> io.Error {
	#partial switch c in data {
	case ANSI_Color:
		io.write_string(w, ansi.CSI, n) or_return
		io.write_uint(w, uint(c) + (10 if bg else 0), 10, n) or_return
		io.write_string(w, ansi.SGR, n) or_return
	case EightBit:
		if bg {
			io.write_string(w, ansi.CSI + ansi.BG_COLOR_8_BIT + ";", n) or_return
		} else {
			io.write_string(w, ansi.CSI + ansi.FG_COLOR_8_BIT + ";", n) or_return
		}
		io.write_uint(w, uint(c), 10, n) or_return
		io.write_string(w, ansi.SGR, n) or_return
	case RGB:
		if bg {
			io.write_string(w, ansi.CSI + ansi.BG_COLOR_24_BIT + ";", n) or_return
		} else {
			io.write_string(w, ansi.CSI + ansi.FG_COLOR_24_BIT + ";", n) or_return
		}
		io.write_uint(w, uint(c.r), 10, n) or_return
		io.write_string(w, ";", n) or_return
		io.write_uint(w, uint(c.g), 10, n) or_return
		io.write_string(w, ";", n) or_return
		io.write_uint(w, uint(c.b), 10, n) or_return
		io.write_string(w, ansi.SGR, n) or_return
	}
	return io.Error.None
}

/*
text_to_writer writes the text content followed by an ANSI reset sequence (`\e[0m`).

Inputs:
- w: The writer to output text to.
- text: The string content to write.
- n: Pointer to a byte counter; incremented by the number of bytes written.

Returns:
- An `io.Error` if writing fails, `io.Error.None` on success.
*/
text_to_writer :: proc(w: io.Writer, text: string, n: ^int) -> io.Error {
	io.write_string(w, text, n) or_return
	io.write_string(w, ansi.CSI + ansi.RESET + ansi.SGR, n) or_return
	return io.Error.None
}

/*
to_writer writes a complete Styled_Text (styles, colors, text, and reset) to the provided writer.

Inputs:
- writer: The writer to output to.
- styled_text: The styled text to render.
- n: Optional pointer to a byte counter (default: nil).

Returns:
- true on success, false if any write operation fails.
*/
to_writer :: proc(
	writer: io.Writer,
	styled_text: Styled_Text,
	n: ^int = nil,
	mode: term.Render_Mode = .Full,
) -> bool {
	if mode == .Plain {
		_, err := io.write_string(writer, styled_text.text, n)
		return err == .None
	}

	has_styles := styled_text.style.text_styles != {}
	has_colors := styled_text.style.foreground_color != nil || styled_text.style.background_color != nil
	needs_ansi := (mode == .Full && (has_styles || has_colors)) || (mode == .No_Color && has_styles)

	if needs_ansi {
		// Build ANSI prefix into stack buffer, write once.
		// Worst case: text styles (18B) + RGB fg (19B) + RGB bg (19B) = 56B; 96B is safe.
		buf: [96]u8
		pos := 0

		if has_styles {
			pos += write_text_styles_to_buf(buf[pos:], styled_text.style.text_styles)
		}
		if mode == .Full {
			pos += write_color_to_buf(buf[pos:], styled_text.style.foreground_color, false)
			pos += write_color_to_buf(buf[pos:], styled_text.style.background_color, true)
		}

		// Write prefix + text + reset as 3 writes max.
		if pos > 0 {
			if !_write_str(writer, string(buf[:pos]), n) do return false
		}
		if !_write_str(writer, styled_text.text, n) do return false
		if !_write_str(writer, "\x1b[0m", n) do return false
	} else {
		_, err := io.write_string(writer, styled_text.text, n)
		if err != .None do return false
	}
	return true
}

// Writes text styles SGR sequence into buf. Returns bytes written.
@(private = "file")
write_text_styles_to_buf :: proc(buf: []u8, s: Text_Style_Set) -> int {
	if s == {} do return 0
	pos := 0
	// CSI = "\x1b["
	buf[pos] = 0x1b; pos += 1
	buf[pos] = '['; pos += 1
	first := true
	for style in s {
		if !first {
			buf[pos] = ';'; pos += 1
		}
		pos += write_uint_to_buf(buf[pos:], uint(style))
		first = false
	}
	// SGR = "m"
	buf[pos] = 'm'; pos += 1
	return pos
}

// Writes a color SGR sequence into buf. Returns bytes written.
@(private = "file")
write_color_to_buf :: proc(buf: []u8, data: Colors, bg: bool) -> int {
	pos := 0
	#partial switch c in data {
	case ANSI_Color:
		// CSI + code + SGR: e.g. "\x1b[31m"
		buf[pos] = 0x1b; pos += 1
		buf[pos] = '['; pos += 1
		pos += write_uint_to_buf(buf[pos:], uint(c) + (10 if bg else 0))
		buf[pos] = 'm'; pos += 1
	case EightBit:
		// "\x1b[38;5;Nm" or "\x1b[48;5;Nm"
		buf[pos] = 0x1b; pos += 1
		buf[pos] = '['; pos += 1
		if bg {
			for b in transmute([]u8)string("48;5;") { buf[pos] = b; pos += 1 }
		} else {
			for b in transmute([]u8)string("38;5;") { buf[pos] = b; pos += 1 }
		}
		pos += write_uint_to_buf(buf[pos:], uint(c))
		buf[pos] = 'm'; pos += 1
	case RGB:
		// "\x1b[38;2;R;G;Bm" or "\x1b[48;2;R;G;Bm"
		buf[pos] = 0x1b; pos += 1
		buf[pos] = '['; pos += 1
		if bg {
			for b in transmute([]u8)string("48;2;") { buf[pos] = b; pos += 1 }
		} else {
			for b in transmute([]u8)string("38;2;") { buf[pos] = b; pos += 1 }
		}
		pos += write_uint_to_buf(buf[pos:], uint(c.r))
		buf[pos] = ';'; pos += 1
		pos += write_uint_to_buf(buf[pos:], uint(c.g))
		buf[pos] = ';'; pos += 1
		pos += write_uint_to_buf(buf[pos:], uint(c.b))
		buf[pos] = 'm'; pos += 1
	}
	return pos
}

// Formats a uint into decimal digits in buf. Returns bytes written.
@(private = "file")
write_uint_to_buf :: proc(buf: []u8, val: uint) -> int {
	if val == 0 {
		buf[0] = '0'
		return 1
	}
	// Write digits in reverse, then reverse in place.
	digits: [10]u8
	count := 0
	v := val
	for v > 0 {
		digits[count] = u8(v % 10) + '0'
		v /= 10
		count += 1
	}
	for i in 0 ..< count {
		buf[i] = digits[count - 1 - i]
	}
	return count
}

@(private = "file")
_write_str :: proc(w: io.Writer, s: string, n: ^int) -> bool {
	_, err := io.write_string(w, s, n)
	return err == .None
}

/*
to_str converts a Styled_Text into a string with embedded ANSI escape codes.

*Allocates Using Provided Allocator*

Inputs:
- styled_text: The styled text to convert.
- allocator: (default: context.allocator)

Returns:
- The formatted string with ANSI escape codes, or "" if the text is empty.
- true if bytes were written, false otherwise (optional).
*/
to_str :: proc(
	styled_text: Styled_Text,
	mode: term.Render_Mode = .Full,
	allocator := context.allocator,
) -> (string, bool) #optional_ok {
	if styled_text.text == "" {
		return "", true
	}

	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), styled_text, mode = mode)
	return strings.to_string(sb), ok
}

/*
Styled_Text_Formatter is a `fmt.User_Formatter` for Styled_Text. Registered at init time,
it allows Styled_Text values to be used directly with `fmt.println`, `fmt.aprintf`, etc.

Supported verbs:
- 'v', 's': Renders the styled text with ANSI escape codes.
- 'w': Prints the raw struct representation (ignores user formatters).
*/
Styled_Text_Formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> (res: bool) {
	styled_text := cast(^Styled_Text)arg.data

	switch verb {
	case 'v', 's':
		if styled_text.text == "" {
			io.write_string(fi.writer, "")
			return true
		}
		return to_writer(fi.writer, styled_text^, &fi.n)
	case 'w':
		fi.ignore_user_formatters = true
		fmt.fmt_value(fi = fi, v = styled_text^, verb = 'w')
		return true
	case:
		return false
	}
}
