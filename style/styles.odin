package style

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

ANSI_FG :: enum u8 {
  None           = 0,
  Black          = 30,
  Red            = 31,
  Green          = 32,
  Yellow         = 33,
  Blue           = 34,
  Magenta        = 35,
  Cyan           = 36,
  White          = 37,
  Bright_Black   = 90,
  Bright_Red     = 91,
  Bright_Green   = 92,
  Bright_Yellow  = 93,
  Bright_Blue    = 94,
  Bright_Magenta = 95,
  Bright_Cyan    = 96,
  Bright_White   = 97,
}

ANSI_BG :: enum u8 {
  None           = 0,
  Black          = 40,
  Red            = 41,
  Green          = 42,
  Yellow         = 43,
  Blue           = 44,
  Magenta        = 45,
  Cyan           = 46,
  White          = 47,
  Bright_Black   = 100,
  Bright_Red     = 101,
  Bright_Green   = 102,
  Bright_Yellow  = 103,
  Bright_Blue    = 104,
  Bright_Magenta = 105,
  Bright_Cyan    = 106,
  Bright_White   = 107,
}

// EightBit represents a color using the standard ANSI or a single 8-bit color code
EightBit :: distinct u8 // 0-255, with 0-15 being the standard ANSI colors.

// For RGB colors, each value (r, g, b) is an 8-bit color code
RGB :: struct {
  r: EightBit,
  g: EightBit,
  b: EightBit,
}

// Colors is the union of types that can store color data.
Colors :: union {
  ANSI_FG,
  ANSI_BG,
  EightBit,
  RGB,
}

// Style holds all the styling information for a piece of text.
Style :: struct {
	text_styles:      Text_Style_Set,
	foreground_color: Colors,
	background_color: Colors,
}

// Text is the text to be styled.
Text :: string

// Styled_Text holds the Style and the string of the text.
Styled_Text :: struct {
  text: Text,
  style: Style,
}

// Convenience functions

/*
bold applies the bold text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the bold style applied.
*/
bold :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Bold}
  return
}

/*
faint applies the faint text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the faint style applied.
*/
faint :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Faint}
  return
}

/*
italic applies the italic text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the italic style applied.
*/
italic :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Italic}
  return
}

/*
underline applies the underline text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the underline style applied.
*/
underline :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Underline}
  return
}

/*
blink_slow applies the slow blink text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the slow blink style applied.
*/
blink_slow :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Blink_Slow}
  return
}

/*
blink_rapid applies the rapid blink text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the rapid blink style applied.
*/
blink_rapid :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Blink_Rapid}
  return
}

/*
invert applies the invert text style to the input string or Styled_Text, swapping foreground and background colors.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the invert style applied.
*/
invert :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Invert}
  return
}

/*
hide applies the hide text style to the input string or Styled_Text, making the text invisible.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the hide style applied.
*/
hide :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Hide}
  return
}

/*
strike applies the strikethrough text style to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text with the strikethrough style applied.
*/
strike :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style.text_styles += {.Strike}
  return
}

/*
black applies the black foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the black color applied.
*/
black :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Black
  } else {
    foreground_color = ANSI_FG.Black
  }
  return
}

/*
red applies the red foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the red color applied.
*/
red :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Red
  } else {
    foreground_color = ANSI_FG.Red
  }
  return
}

/*
green applies the green foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the green color applied.
*/
green :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Green
  } else {
    foreground_color = ANSI_FG.Green
  }
  return
}

/*
yellow applies the yellow foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the yellow color applied.
*/
yellow :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Yellow
  } else {
    foreground_color = ANSI_FG.Yellow
  }
  return
}

/*
blue applies the blue foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the blue color applied.
*/
blue :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Blue
  } else {
    foreground_color = ANSI_FG.Blue
  }
  return
}

/*
magenta applies the magenta foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the magenta color applied.
*/
magenta :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Magenta
  } else {
    foreground_color = ANSI_FG.Magenta
  }
  return
}

/*
cyan applies the cyan foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the cyan color applied.
*/
cyan :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Cyan
  } else {
    foreground_color = ANSI_FG.Cyan
  }
  return
}

/*
white applies the white foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the white color applied.
*/
white :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.White
  } else {
    foreground_color = ANSI_FG.White
  }
  return
}

/*
bright_black applies the bright black foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright black color applied.
*/
bright_black :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Black
  } else {
    foreground_color = ANSI_FG.Bright_Black
  }
  return
}

/*
bright_red applies the bright red foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright red color applied.
*/
bright_red :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Red
  } else {
    foreground_color = ANSI_FG.Bright_Red
  }
  return
}

/*
bright_green applies the bright green foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright green color applied.
*/
bright_green :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Green
  } else {
    foreground_color = ANSI_FG.Bright_Green
  }
  return
}

/*
bright_yellow applies the bright yellow foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright yellow color applied.
*/
bright_yellow :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Yellow
  } else {
    foreground_color = ANSI_FG.Bright_Yellow
  }
  return
}

/*
bright_blue applies the bright blue foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright blue color applied.
*/
bright_blue :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Blue
  } else {
    foreground_color = ANSI_FG.Bright_Blue
  }
  return
}

/*
bright_magenta applies the bright magenta foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright magenta color applied.
*/
bright_magenta :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Magenta
  } else {
    foreground_color = ANSI_FG.Bright_Magenta
  }
  return
}

/*
bright_cyan applies the bright cyan foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright cyan color applied.
*/
bright_cyan :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_Cyan
  } else {
    foreground_color = ANSI_FG.Bright_Cyan
  }
  return
}

/*
bright_white applies the bright white foreground color to the input string or Styled_Text.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.
  bg: If true, applies the color as the background color instead of the foreground.
      Defaults to false.

Returns:
  Styled_Text: The input text with the bright white color applied.
*/
bright_white :: proc(str: union{string, Styled_Text}, bg: bool = false) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  using value.style
  if bg {
    background_color = ANSI_BG.Bright_White
  } else {
    foreground_color = ANSI_FG.Bright_White
  }
  return
}

/*
warn styles the input string or Styled_Text with yellow foreground and bold text,
indicating a warning.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text styled as a warning.
*/
warn :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style = Style{foreground_color = ANSI_FG.Yellow,
                      background_color = nil,
                      text_styles = {.Bold}}
  return
}

/*
error styles the input string or Styled_Text with red foreground and bold text,
indicating an error.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text styled as an error.
*/
error :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style = Style{foreground_color = ANSI_FG.Red,
                      background_color = nil,
                      text_styles = {.Bold}}
  return
}

/*
success styles the input string or Styled_Text with green foreground and bold
text, indicating success.

Parameters:
  str: The input, which can be either a plain string or an existing Styled_Text.

Returns:
  Styled_Text: The input text styled as a success message.
*/
success :: proc(str: union{string, Styled_Text}) -> (value: Styled_Text) {
  value = get_or_create_styled_text(str)
  value.style = Style{foreground_color = ANSI_FG.Green,
                      background_color = nil,
                      text_styles = {.Bold}}
  return
}

/*
get_or_create_styled_text either returns the input if it's already a Styled_Text,
or creates a new Styled_Text from the input string. This is necessary for chaining
style functions.

Parameters:
  str: Either a string or a Styled_Text.

Returns:
  Styled_Text: The input as a Styled_Text.
*/
get_or_create_styled_text :: proc(str: union{string, Styled_Text}) -> Styled_Text {
  if text, is_string := str.(string); is_string {
    return Styled_Text{text = text}
  }
  return str.(Styled_Text)
}
