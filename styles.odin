package cli_style

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


