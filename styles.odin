package cli_style

import "core:strings"
import "core:encoding/ansi"
import "core:log"
import "core:fmt"

// Text_Style represents the various text style attributes.
Text_Style :: enum {
  None,
	Bold,
	Faint,
	Italic,
	Underline,
	Blink_Slow,
	Blink_Rapid,
	Invert,
	Hide,
	Strike,
}

Text_Style_Set :: bit_set[Text_Style]

// EightBit_Color represents a color using the standard ANSI or a single 8-bit color code
EightBit_Color_Data :: distinct u8 // 0-255, with 0-15 being the standard ANSI colors.

// For RGB colors, each value (r, g, b) is an 8-bit color code
RGB_Color_Data :: struct {
  r: EightBit_Color_Data,
  g: EightBit_Color_Data,
  b: EightBit_Color_Data,
}

// Color_Data is the union of types that can store color data.
Color_Data :: union {
  ANSI_FG_Colors,
  ANSI_BG_Colors,
  EightBit_Color_Data,
  RGB_Color_Data,
}

// Style holds all the styling information for a piece of text.
Style :: struct {
	Text_Styles:      Text_Style_Set,
	Foreground_Color: Color_Data,
	Background_Color: Color_Data,
}

// Styled_Text holds the Style and the string of the text.
Styled_Text :: struct {
  Text: string,
  Style: Style,
}

// Convenience functions

// bold applies the bold text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the bold style applied.
//   bool (optional): Indicates if the operation was successful.
bold :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// faint applies the faint text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the faint style applied.
//   bool (optional): Indicates if the operation was successful.
faint :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// italic applies the italic text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the italic style applied.
//   bool (optional): Indicates if the operation was successful.
italic :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// underline applies the underline text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the underline style applied.
//   bool (optional): Indicates if the operation was successful.
underline :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// blink_slow applies the slow blink text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the slow blink style applied.
//   bool (optional): Indicates if the operation was successful.
blink_slow :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// blink_rapid applies the rapid blink text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the rapid blink style applied.
//   bool (optional): Indicates if the operation was successful.
blink_rapid :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// invert applies the invert text style to the input string or Styled_Text, swapping foreground and background colors.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the invert style applied.
//   bool (optional): Indicates if the operation was successful.
invert :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// hide applies the hide text style to the input string or Styled_Text, making the text invisible.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the hide style applied.
//   bool (optional): Indicates if the operation was successful.
hide :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// strike applies the strikethrough text style to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text with the strikethrough style applied.
//   bool (optional): Indicates if the operation was successful.
strike :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_text_style(get_or_create_styled_text(str), style = #procedure)
}

// black applies the black foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the black color applied.
//   bool (optional): Indicates if the operation was successful.
black :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// red applies the red foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the red color applied.
//   bool (optional): Indicates if the operation was successful.
red :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// green applies the green foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the green color applied.
//   bool (optional): Indicates if the operation was successful.
green :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}
 
// yellow applies the yellow foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the yellow color applied.
//   bool (optional): Indicates if the operation was successful.
yellow :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// blue applies the blue foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the blue color applied.
//   bool (optional): Indicates if the operation was successful.
blue :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// magenta applies the magenta foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the magenta color applied.
//   bool (optional): Indicates if the operation was successful.
magenta :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// cyan applies the cyan foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the cyan color applied.
//   bool (optional): Indicates if the operation was successful.
cyan :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// white applies the white foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the white color applied.
//   bool (optional): Indicates if the operation was successful.
white :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_black applies the bright black foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright black color applied.
//   bool (optional): Indicates if the operation was successful.
bright_black :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_red applies the bright red foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright red color applied.
//   bool (optional): Indicates if the operation was successful.
bright_red :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_green applies the bright green foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright green color applied.
//   bool (optional): Indicates if the operation was successful.
bright_green :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}
 
// bright_yellow applies the bright yellow foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright yellow color applied.
//   bool (optional): Indicates if the operation was successful.
bright_yellow :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_blue applies the bright blue foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright blue color applied.
//   bool (optional): Indicates if the operation was successful.
bright_blue :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_magenta applies the bright magenta foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright magenta color applied.
//   bool (optional): Indicates if the operation was successful.
bright_magenta :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_cyan applies the bright cyan foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright cyan color applied.
//   bool (optional): Indicates if the operation was successful.
bright_cyan :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// bright_white applies the bright white foreground color to the input string or Styled_Text.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//   bg: If true, applies the color as the background color instead of the foreground. Defaults to false.
//
// Returns:
//   Styled_Text: The input text with the bright white color applied.
//   bool (optional): Indicates if the operation was successful.
bright_white :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  return update_color(get_or_create_styled_text(str), color = #procedure, bg = bg)
}

// warn styles the input string or Styled_Text with yellow foreground and bold text, indicating a warning.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text styled as a warning.
//   bool (optional): Indicates if the operation was successful.
warn :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  value = get_or_create_styled_text(str)
  value.Style = Style{Foreground_Color = ANSI_FG_Colors.Yellow,
                      Text_Styles = {Text_Style.Bold}}
  return value, true
}

// error styles the input string or Styled_Text with red foreground and bold text, indicating an error.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text styled as an error.
//   bool (optional): Indicates if the operation was successful.
error :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  value = get_or_create_styled_text(str)
  value.Style = Style{Foreground_Color = ANSI_FG_Colors.Red,
                      Text_Styles = {Text_Style.Bold}}
  return value, true
}

// success styles the input string or Styled_Text with green foreground and bold text, indicating success.
//
// Parameters:
//   str: The input, which can be either a plain string or an existing Styled_Text.
//
// Returns:
//   Styled_Text: The input text styled as a success message.
//   bool (optional): Indicates if the operation was successful.
success :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text, ok: bool) #optional_ok {
  value = get_or_create_styled_text(str)
  value.Style = Style{Foreground_Color = ANSI_FG_Colors.Green,
                      Text_Styles = {Text_Style.Bold}}
  return value, true
}

// update_color updates the color of a Styled_Text.
//
// Parameters:
//   st: The Styled_Text to update.
//   color: The name of the color to apply (e.g., "red", "blue").
//   bg: If true, sets the background color; otherwise, sets the foreground color. Defaults to false.
//
// Returns:
//   Styled_Text: The updated Styled_Text.
//   bool (optional): Indicates if the color was successfully applied.
update_color :: proc(st: Styled_Text, color: string = "", bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  using package_options
  value = st
  ok = false
  if bg {
    debug("Updating style with", color, "bg:", value.Style)
    value.Style.Background_Color = bg_map[color]
    debug("Updated style:", value.Style)
    ok = true
    return value, ok
  } else {
    debug("Updating style with", color, "fg:", value.Style)
    value.Style.Foreground_Color = fg_map[color]
    debug("Updated style:", value.Style)
    ok = true
    return value, ok
  }
  return
}

// update_text_style updates the text styles of a Styled_Text.
//
// Parameters:
//   st: The Styled_Text to update.
//   style: The name of the text style to apply (e.g., "bold", "italic").
//   bg: This parameter is ignored for the update_text_style function.
//
// Returns:
//   Styled_Text: The updated Styled_Text.
//   bool (optional): Indicates if the text style was successfully applied.
update_text_style :: proc(st: Styled_Text, style: string = "", bg: bool = false) -> (value: Styled_Text, ok: bool) #optional_ok {
  value = st
  ok = false
  using package_options
  debug("Updating text style with", style, ":", value.Style)
  text_styles, style_ok := parse_text_style(style)
  if style_ok {
    value.Style.Text_Styles += text_styles
    debug("Updated style:", value.Style)
    ok = true
    return value, ok
  } else {
    log.warn("Failed to update text style with", style)
  }
  return
}

// get_or_create_styled_text either returns the input if it's already a Styled_Text,
// or creates a new Styled_Text from the input string.
//
// Parameters:
//   str: Either a string or a Styled_Text.
//
// Returns:
//   Styled_Text: The input as a Styled_Text.
get_or_create_styled_text :: proc(str: union{string, Styled_Text}) -> Styled_Text {
  if text, is_string := str.(string); is_string {
    return Styled_Text{Text = text}
  }
  return str.(Styled_Text)
}
