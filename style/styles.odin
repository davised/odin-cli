// Text styling with ANSI colors, 8-bit, RGB, and text decorations for terminal output.
package style

// Text_Style represents ANSI SGR text style attributes. Values correspond to SGR parameter numbers.
Text_Style :: enum {
	Bold = 1,
	Faint,
	Italic,
	Underline,
	Blink_Slow,
	Blink_Rapid,
	Invert,
	Hide,
	Strike,
	// 10-20: font selection (rarely supported)
	Double_Underline = 21,
	// 22-29: disable codes (not needed — we reset with \e[0m)
	// 50: proportional spacing (not useful)
	Framed    = 51,
	Encircled = 52,
	Overlined = 53,
}

// Text_Style_Set is a bit set of text style attributes that can be combined.
Text_Style_Set :: bit_set[Text_Style]

// ANSI_Color represents the 16 standard ANSI terminal colors. Values are foreground SGR codes;
// background codes are computed as value + 10.
ANSI_Color :: enum u8 {
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

// EightBit represents an 8-bit color code (0-255).
EightBit :: distinct u8

// RGB represents a 24-bit true color with red, green, and blue components.
RGB :: struct {
	r: EightBit,
	g: EightBit,
	b: EightBit,
}

// Colors is the union of all supported color types. A nil value means no color is set.
Colors :: union {
	ANSI_Color,
	EightBit,
	RGB,
}

// Style holds all styling information: text styles, foreground color, and background color.
Style :: struct {
	text_styles:      Text_Style_Set,
	foreground_color: Colors,
	background_color: Colors,
}

// Styled_Text pairs a string with a Style for formatted terminal output.
Styled_Text :: struct {
	text:  string,
	style: Style,
}

/*
get_or_create_styled_text returns the input as a Styled_Text, either passing through
an existing Styled_Text or wrapping a plain string in one. Used for chaining style functions.

Inputs:
- str: A plain string or an existing Styled_Text.

Returns:
- The input as a Styled_Text.
*/
get_or_create_styled_text :: proc(str: union {
		string,
		Styled_Text,
	}) -> Styled_Text {
	if text, is_string := str.(string); is_string {
		return Styled_Text{text = text}
	}
	return str.(Styled_Text)
}

/*
apply_color sets a foreground or background ANSI color on the input.

Inputs:
- str: A plain string or an existing Styled_Text.
- color: The ANSI color to apply.
- bg: When true, applies as background color; otherwise foreground.

Returns:
- The styled text with the color applied.
*/
@(private)
apply_color :: proc(str: union {string, Styled_Text}, color: ANSI_Color, bg: bool) -> Styled_Text {
	value := get_or_create_styled_text(str)
	if bg {
		value.style.background_color = color
	} else {
		value.style.foreground_color = color
	}
	return value
}

/*
apply_text_style adds a text style attribute to the input.

Inputs:
- str: A plain string or an existing Styled_Text.
- ts: The text style to add.

Returns:
- The styled text with the text style added.
*/
@(private)
apply_text_style :: proc(str: union {string, Styled_Text}, ts: Text_Style) -> Styled_Text {
	value := get_or_create_styled_text(str)
	value.style.text_styles += {ts}
	return value
}

// Color convenience functions

// black applies the black color as foreground (default) or background.
black :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Black, bg) }
// red applies the red color as foreground (default) or background.
red :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Red, bg) }
// green applies the green color as foreground (default) or background.
green :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Green, bg) }
// yellow applies the yellow color as foreground (default) or background.
yellow :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Yellow, bg) }
// blue applies the blue color as foreground (default) or background.
blue :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Blue, bg) }
// magenta applies the magenta color as foreground (default) or background.
magenta :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Magenta, bg) }
// cyan applies the cyan color as foreground (default) or background.
cyan :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Cyan, bg) }
// white applies the white color as foreground (default) or background.
white :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .White, bg) }
// bright_black applies the bright black color as foreground (default) or background.
bright_black :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Black, bg) }
// bright_red applies the bright red color as foreground (default) or background.
bright_red :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Red, bg) }
// bright_green applies the bright green color as foreground (default) or background.
bright_green :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Green, bg) }
// bright_yellow applies the bright yellow color as foreground (default) or background.
bright_yellow :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Yellow, bg) }
// bright_blue applies the bright blue color as foreground (default) or background.
bright_blue :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Blue, bg) }
// bright_magenta applies the bright magenta color as foreground (default) or background.
bright_magenta :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Magenta, bg) }
// bright_cyan applies the bright cyan color as foreground (default) or background.
bright_cyan :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_Cyan, bg) }
// bright_white applies the bright white color as foreground (default) or background.
bright_white :: proc(str: union {string, Styled_Text}, bg: bool = false) -> Styled_Text { return apply_color(str, .Bright_White, bg) }

// Text style convenience functions

// bold applies the bold text style.
bold :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Bold) }
// faint applies the faint (dim) text style.
faint :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Faint) }
// italic applies the italic text style.
italic :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Italic) }
// underline applies the underline text style.
underline :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Underline) }
// blink_slow applies the slow blink text style.
blink_slow :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Blink_Slow) }
// blink_rapid applies the rapid blink text style.
blink_rapid :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Blink_Rapid) }
// invert applies the reverse video text style, swapping foreground and background.
invert :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Invert) }
// hide applies the hidden text style, making text invisible.
hide :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Hide) }
// strike applies the strikethrough text style.
strike :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Strike) }
// double_underline applies the double underline text style.
double_underline :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Double_Underline) }
// framed applies the framed text style.
framed :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Framed) }
// encircled applies the encircled text style.
encircled :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Encircled) }
// overlined applies the overline text style.
overlined :: proc(str: union {string, Styled_Text}) -> Styled_Text { return apply_text_style(str, .Overlined) }

// Semantic convenience functions — these override the entire style (intentional).

// warn styles text as a warning: bold yellow foreground. Replaces any existing style.
warn :: proc(str: union {string, Styled_Text}) -> (value: Styled_Text) {
	value = get_or_create_styled_text(str)
	value.style = Style {
		foreground_color = ANSI_Color.Yellow,
		text_styles      = {.Bold},
	}
	return
}

// error styles text as an error: bold red foreground. Replaces any existing style.
error :: proc(str: union {string, Styled_Text}) -> (value: Styled_Text) {
	value = get_or_create_styled_text(str)
	value.style = Style {
		foreground_color = ANSI_Color.Red,
		text_styles      = {.Bold},
	}
	return
}

// success styles text as a success message: bold green foreground. Replaces any existing style.
success :: proc(str: union {string, Styled_Text}) -> (value: Styled_Text) {
	value = get_or_create_styled_text(str)
	value.style = Style {
		foreground_color = ANSI_Color.Green,
		text_styles      = {.Bold},
	}
	return
}
