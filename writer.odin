package cli_style

import "core:fmt"
import "core:encoding/ansi"
import "core:strings"
import "core:log"
import "core:mem"
import "core:io"

// text_styles_to_sb converts a set of text styles into ANSI escape sequences
// and appends them to the provided string builder.
//
// This procedure iterates through the provided `Text_Style_Set` and for each
// enabled text style, it generates the corresponding ANSI escape sequence
// and appends it to the given string builder.
//
// Generally, this does not need to be called directly, but is used by the
// `to_str` procedure.
//
// Parameters:
//   s: The `Text_Style_Set` containing the text styles to be applied.
//   sb: A pointer to the `strings.Builder` where the ANSI escape sequences will be appended.
text_styles_to_sb :: proc(s: Text_Style_Set, sb: ^strings.Builder) {
  for style in s {
    fmt.sbprint(sb, ansi.CSI, uint(style), ansi.SGR, sep="")
  }
}

// fg_color_to_sb converts a foreground color specification into ANSI escape sequences
// and appends them to the provided string builder.
//
// This procedure takes a `Color_Data` representing a foreground color and generates
// the appropriate ANSI escape sequence to set that color in the terminal. It
// supports ANSI standard colors, 8-bit colors, and 24-bit RGB colors.
//
// Generally, this does not need to be called directly, but is used by the
// `to_str` procedure.
//
// Parameters:
//   data: The `Color_Data` structure containing the foreground color specification.
//   sb: A pointer to the `strings.Builder` where the ANSI escape sequence will be appended.
fg_color_to_sb :: proc(data: Color_Data, sb: ^strings.Builder) {
  #partial switch c in data {
    case ANSI_FG_Colors:
      fmt.sbprint(sb, ansi.CSI, uint(c), ansi.SGR, sep="")
    case EightBit_Color_Data:
      fmt.sbprint(
        sb, ansi.CSI, ansi.FG_COLOR_8_BIT, ";", uint(c), ansi.SGR, sep="",
      )
    case RGB_Color_Data:
      fmt.sbprint(
        sb, 
        ansi.CSI, 
        ansi.FG_COLOR_24_BIT, 
        ";", uint(c.r),
        ";", uint(c.g),
        ";", uint(c.b), 
        ansi.SGR, 
        sep="",
      )
  }
}

// bg_color_to_sb converts a background color specification into ANSI escape sequences
// and appends them to the provided string builder.
//
// This procedure takes a `Color_Data` representing a background color and generates
// the appropriate ANSI escape sequence to set that color in the terminal. It
// supports ANSI standard colors, 8-bit colors, and 24-bit RGB colors.
//
// Generally, this does not need to be called directly, but is used by the
// `to_str` procedure.
//
// Parameters:
//   data: The `Color_Data` structure containing the background color specification.
//   sb: A pointer to the `strings.Builder` where the ANSI escape sequence will be appended.
bg_color_to_sb :: proc(data: Color_Data, sb: ^strings.Builder) {
  #partial switch c in data {
    case ANSI_BG_Colors:
      fmt.sbprint(sb, ansi.CSI, uint(c), ansi.SGR, sep="")
    case EightBit_Color_Data:
      fmt.sbprint(
        sb, ansi.CSI, ansi.BG_COLOR_8_BIT, ";", uint(c), ansi.SGR, sep="",
      )
    case RGB_Color_Data:
      fmt.sbprint(
        sb, 
        ansi.CSI, 
        ansi.BG_COLOR_24_BIT, 
        ";", uint(c.r),
        ";", uint(c.g),
        ";", uint(c.b), 
        ansi.SGR, 
        sep="",
      )
  }
}

// text_to_sb appends the text of a Styled_Text to a string builder,
// including the necessary ANSI reset sequence to ensure that the styling
// does not bleed into subsequent text.
//
// This procedure takes a `Styled_Text` object and appends its text content
// to the provided string builder. Importantly, it also appends an ANSI reset
// sequence after the text to revert the terminal's styling to default, preventing
// the styles applied to this text from affecting subsequent output.
//
// Generally, this does not need to be called directly, but is used by the
// `to_str` procedure.
//
// Parameters:
//   styled_text: The `Styled_Text` object whose text content will be appended.
//   sb: A pointer to the `strings.Builder` where the text and reset sequence will be appended.
text_to_sb :: proc(text: Text, sb: ^strings.Builder) {
  fmt.sbprint(sb, text, ansi.CSI, ansi.RESET, ansi.SGR, sep="",)
}

// print_string_as_bytes is a private debugging procedure that prints each byte
// of a string along with its index and hexadecimal representation.
//
// This procedure is intended for debugging purposes. It takes a string as input,
// iterates through its underlying bytes, and prints each byte's decimal and
// hexadecimal representation along with its index in the string. This can be
// useful for understanding the raw byte representation of a string, especially
// when dealing with encoding issues or non-ASCII characters.
//
// Parameters:
//   s: The string whose bytes will be printed.
@(private)
print_string_as_bytes :: proc(s: string) {
  // Convert string to slice of bytes
  bytes := transmute([]u8)s
  defer delete(bytes)
  
  // Print each byte
  for b, i in bytes {
    fmt.printf("Byte %d: %v (0x%02x)\n", i, b, b)
  }
}

// print_string_as_runes is a private debugging procedure that iterates over the runes
// in a string and prints each rune along with its index and Unicode code point.
//
// This procedure is intended for debugging purposes. It takes a string as input,
// iterates through its Unicode runes, and prints each rune's character representation
// and its Unicode code point in hexadecimal format. This is useful for understanding
// the logical characters within a string, especially when dealing with UTF-8 encoded text.
//
// Parameters:
//   s: The string whose runes will be printed.
@(private)
print_string_as_runes :: proc(s: string) {
  // Iterate over runes in the string
  for r, i in s {
    fmt.printf("Rune %d: %v (U+%04X)\n", i, r, r)
  }
}

// print_bytes_as_runes is a private debugging procedure that interprets a slice of bytes
// as runes and prints each interpreted rune along with its index and Unicode code point.
//
// This procedure is intended for debugging purposes. It takes a slice of bytes as
// input, interprets each byte as a rune (which might be part of a multi-byte rune),
// and prints the resulting rune's character representation and its Unicode code point
// in hexadecimal format along with the byte's original index.
//
// Parameters:
//   bytes: The slice of bytes to be interpreted and printed as runes.
@(private)
print_bytes_as_runes :: proc(bytes: []u8) {
  for b, i in bytes {
    r := rune(b)
    fmt.printf("Byte %d as rune: %v (U+%04X)\n", i, r, r)
  }
}

// generate_formatted_string is a private debugging procedure that generates a hardcoded
// ANSI escape sequence for red text. It's primarily used for testing and demonstrating
// how ANSI codes work.
//
// This procedure serves as a simple example of how to manually construct an ANSI
// escape sequence. It directly creates the string for setting the text color to red
// and includes a reset sequence. This is mainly for quick testing or demonstration
// purposes and is not intended for general use in applying styles.
//
// Returns:
//   string: A string containing the ANSI escape sequence for red text.
@(private)
generate_formatted_string :: proc() -> string {
  return(string(ansi.CSI + "1" + ansi.SGR + ansi.CSI + "31" + ansi.SGR + "Red Text" + ansi.CSI + "0" + ansi.SGR))}

// to_str converts a Styled_Text object into a string with the appropriate ANSI
// escape codes to apply the specified formatting.
//
// This procedure is the core of the styling functionality. It takes a `Styled_Text`
// object and constructs a string that includes the ANSI escape sequences for all
// the styles (text styles, foreground color, background color) defined in the
// `Styled_Text`'s `Style` field, followed by the actual text content and an ANSI
// reset sequence.
//
// This is the work-horse of the package.
//
// Parameters:
//   styled_text: The `Styled_Text` object to convert to a formatted string.
//
// Returns:
//   string: The formatted string with embedded ANSI escape codes.
to_str :: proc(styled_text: Styled_Text, allocator := context.temp_allocator) -> (string, bool) {
  if styled_text.Text == Text("") {
    return "", false
  }
  sb := strings.builder_make(allocator = allocator)
  using styled_text.Style
  
  // Apply text styles
  text_styles_to_sb(Text_Styles, &sb)

  // Apply foreground color
  fg_color_to_sb(Foreground_Color, &sb)

  // Apply background color
  bg_color_to_sb(Background_Color, &sb)

  // Write text to sb and reset codes
  text_to_sb(styled_text.Text, &sb)

  return strings.clone(strings.to_string(sb)), true
}

// Styled_Text_Formatter is a custom formatter for the fmt package that handles
// the formatting of Styled_Text objects. It converts the Styled_Text into a
// string with ANSI escape codes and writes it to the output.
//
// This procedure implements the `fmt.User_Formatter` interface, allowing the
// `fmt` package to handle `Styled_Text` objects specially. When a `Styled_Text`
// object is encountered in a `fmt.print` call (with the 'v' or 'w' verb), this
// formatter will be invoked. It calls `to_str` to generate the ANSI formatted
// string and writes it to the output writer.
//
// Parameters:
//   fi: A pointer to the `fmt.Info` struct, providing context for the formatting operation.
//   arg: The `any` value being formatted, which is expected to be a `Styled_Text`.
//   verb: The formatting verb used in the `fmt.print` call (e.g., 'v', 'w').
//
// Returns:
//   res: A boolean indicating whether the formatting was handled by this formatter.
//        Returns true if the argument was a `Styled_Text` and was successfully formatted.
Styled_Text_Formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> (res: bool) {
  res = false
  styled_text := cast(^Styled_Text)arg.data

  // using styled_text^.Style
  if verb != 'v' && verb != 'w' {
    fmt.fmt_bad_verb(fi, verb)
    return
  }

  if styled_text.Text == "" {
    io.write_string(fi.writer, "")
    return true
  }
  
  output, ok := to_str(styled_text^)
  defer delete(output)

  if ok {
    io.write_string(fi.writer, output)
    return true
  } else {
    io.write_string(fi.writer, "")
    return false
  }

}
