#+feature global-context
#+feature using-stmt
package style

import "core:fmt"
import "core:terminal/ansi"
import "core:strings"
import "core:log"
import "core:io"

/*
init_formatter initializes the formatting system with optional settings.

Enables use of println and other default-format printers.
*/
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
text_styles_to_writer converts a set of text styles into ANSI escape sequences
and appends them to the provided io.Writer.

This procedure iterates through the provided `Text_Style_Set` and for each
enabled text style, it generates the corresponding ANSI escape sequence
and appends it to the given writer.

Generally, this does not need to be called directly, but is used by the
`to_writer` procedure.

Parameters:
  w: The io.Writer object where the codes and escape characters will be written.
  s: The `Text_Style_Set` containing the text styles to be applied.
  n: A pointer to the int where the number of characters will be summed.
*/
text_styles_to_writer :: proc(w: io.Writer, s: Text_Style_Set, n: ^int) -> (io.Error) {
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
fg_color_to_writer converts a foreground color specification into ANSI escape sequences
and appends them to the provided io.Writer.

This procedure takes a `Colors` representing a foreground color and generates
the appropriate ANSI escape sequence to set that color in the terminal. It
supports ANSI standard colors, 8-bit colors, and 24-bit RGB colors.

Generally, this does not need to be called directly, but is used by the
`to_writer` procedure.

Parameters:
  w: The io.Writer object where the codes and escape characters will be written.
  data: The `Colors` structure containing the foreground color specification.
  n: A pointer to the int where the number of characters will be summed.
*/
fg_color_to_writer :: proc(w: io.Writer, data: Colors, n: ^int) -> (io.Error) {
  #partial switch c in data {
    case ANSI_FG:
      io.write_string(w, ansi.CSI, n) or_return
      io.write_uint(w, uint(c), 10, n) or_return
      io.write_string(w, ansi.SGR, n) or_return
    case EightBit:
      io.write_string(w, ansi.CSI + ansi.FG_COLOR_8_BIT + ";", n) or_return
      io.write_uint(w, uint(c), 10, n) or_return
      io.write_string(w, ansi.SGR, n) or_return
    case RGB:
      io.write_string(w, ansi.CSI + ansi.FG_COLOR_24_BIT + ";", n) or_return
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
bg_color_to_writer converts a background color specification into ANSI escape sequences
and appends them to the provided io.Writer.

This procedure takes a `Colors` representing a background color and generates
the appropriate ANSI escape sequence to set that color in the terminal. It
supports ANSI standard colors, 8-bit colors, and 24-bit RGB colors.

Generally, this does not need to be called directly, but is used by the
`to_writer` procedure.

Parameters:
  w: The io.Writer object where the codes and escape characters will be written.
  data: The `Colors` structure containing the background color specification.
  n: A pointer to the int where the number of characters will be summed.
*/
bg_color_to_writer :: proc(w: io.Writer, data: Colors, n: ^int) -> (io.Error) {
  #partial switch c in data {
    case ANSI_BG:
      io.write_string(w, ansi.CSI, n) or_return
      io.write_uint(w, uint(c), 10, n) or_return
      io.write_string(w, ansi.SGR, n) or_return
    case EightBit:
      io.write_string(w, ansi.CSI + ansi.BG_COLOR_8_BIT + ";", n) or_return
      io.write_uint(w, uint(c), 10, n) or_return
      io.write_string(w, ansi.SGR, n) or_return
    case RGB:
      io.write_string(w, ansi.CSI + ansi.BG_COLOR_24_BIT + ";", n) or_return
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
text_to_writer appends the text of a Styled_Text to an io.Writer,
including the necessary ANSI reset sequence to ensure that the styling
does not bleed into subsequent text.

Generally, this does not need to be called directly, but is used by the
`to_writer` procedure.

Parameters:

  w: The io.Writer object where the text will be written.
  styled_text: The `Styled_Text` object whose text content will be written.
  n: A pointer to the int where the number of characters will be summed.
*/
text_to_writer :: proc(w: io.Writer, text: Text, n: ^int) -> (io.Error) {
  io.write_string(w, text, n) or_return
  io.write_string(w, ansi.CSI + ansi.RESET + ansi.SGR, n) or_return
  return io.Error.None
}

to_writer :: proc(writer: io.Writer, styled_text: Styled_Text, n: ^int = nil) -> bool {
  using styled_text.style
  
  // Apply text styles
  if text_styles_to_writer(writer, text_styles, n) != io.Error.None {
    return false
  }

  // Apply foreground color
  if fg_color_to_writer(writer, foreground_color, n) != io.Error.None {
    return false
  }

  // Apply background color
  if bg_color_to_writer(writer, background_color, n) != io.Error.None {
    return false
  }

  // Write text and reset codes
  if text_to_writer(writer, styled_text.text, n) != io.Error.None {
    return false
  }

  return true
}

/*
to_str converts a Styled_Text object into a string with the appropriate ANSI
escape codes to apply the specified formatting.

This procedure is the core of the styling functionality. It takes a `Styled_Text`
object and constructs a string that includes the ANSI escape sequences for all
the styles (text styles, foreground color, background color) defined in the
`Styled_Text`'s `Style` field, followed by the actual text content and an ANSI
reset sequence.

Parameters:
  styled_text: The `Styled_Text` object to convert to a formatted string.
  intermediate_allocator: Allocator to make the string builder for intermediate text.
  allocator: Allocator for the final string

Returns:
  string: The formatted string with embedded ANSI escape codes.
  bool: Check if n (num bytes written) > 0.
*/
to_str :: proc(styled_text: Styled_Text, allocator := context.allocator) -> (string, bool) #optional_ok {
  n := 0

  if styled_text.text == "" {
    return "", n > 0
  }

  sb := strings.builder_make(allocator = allocator)
  using styled_text.style
  
  // Apply text styles
  text_styles_to_writer(strings.to_writer(&sb), text_styles, &n)

  // Apply foreground color
  fg_color_to_writer(strings.to_writer(&sb), foreground_color, &n)

  // Apply background color
  bg_color_to_writer(strings.to_writer(&sb), background_color, &n)

  // Write text to sb and reset codes
  text_to_writer(strings.to_writer(&sb), styled_text.text, &n)

  return strings.to_string(sb), n > 0
}

/*
Styled_Text_Formatter is a custom formatter for the fmt package that handles
the formatting of Styled_Text objects. It converts the Styled_Text into a
string with ANSI escape codes and writes it to the output.

This procedure implements the `fmt.User_Formatter` interface, allowing the
`fmt` package to handle `Styled_Text` objects specially. When a `Styled_Text`
object is encountered in a `fmt.print` call (with the 'v', 's', or 'w' verb), this
formatter will be invoked. It calls `to_writer` to generate the ANSI formatted
string and writes it sequentially to the output writer.

Parameters:
  fi: A pointer to the `fmt.Info` struct, providing context for the formatting operation.
  arg: The `any` value being formatted, which is expected to be a `Styled_Text`.
  verb: The formatting verb used in the `fmt.print` call (e.g., 'v', 'w').

Returns:
  res: A boolean indicating whether the formatting was handled by this formatter.
       Returns true if the argument was a `Styled_Text` and was successfully formatted.
*/
Styled_Text_Formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> (res: bool) {
  styled_text := cast(^Styled_Text)arg.data

  switch verb {
  case 'v', 's':
    if styled_text.text == "" {
      io.write_string(fi.writer, "")
      return true
    }
    when ODIN_DEBUG {
      defer log.debugf("Wrote %i bytes", fi.n)
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
