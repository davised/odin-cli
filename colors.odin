package cli_style

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:math"

ANSI_FG_Colors :: enum u8 {
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

ANSI_BG_Colors :: enum u8 {
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

// hex_to_rgb converts a hex color string to an RGB_Color_Data struct.
// It accepts strings with or without the leading '#'.
//
// Parameters:
//   hex_string: The hexadecimal color string (e.g., "#FF0000" or "FF0000").
//
// Returns:
//   RGB_Color_Data: The RGB color data.
//   bool: True if the conversion was successful, false otherwise.
hex_to_rgb :: proc(hex_string: string) -> (RGB_Color_Data, bool) {
    // Remove the '#' if it exists
    hex_bytes: string
    if strings.has_prefix(hex_string, "#") {
      hex_bytes = hex_string[1:]
    } else {
      hex_bytes = hex_string
    }

    // Check for valid length (6 hex characters)
    if len(hex_bytes) != 6 {
        return RGB_Color_Data{}, false
    }

    // Parse each color component
    r, err_r := strconv.parse_uint(hex_bytes[0:2], 16)
    g, err_g := strconv.parse_uint(hex_bytes[2:4], 16)
    b, err_b := strconv.parse_uint(hex_bytes[4:6], 16)

    // Check for parsing errors
    if !err_r || !err_g || !err_b {
        return RGB_Color_Data{}, false
    }

    return RGB_Color_Data{EightBit_Color_Data(r), EightBit_Color_Data(g), EightBit_Color_Data(b)}, true
}

// hsl_to_rgb converts HSL color values to RGB.
//
// Parameters:
//   h: The hue value (0-360 degrees).
//   s: The saturation value (0.0-1.0).
//   l: The lightness value (0.0-1.0).
//
// Returns:
//   RGB_Color_Data: The RGB color data.
//   bool: True if the conversion was successful, false otherwise (e.g., if input values are out of range).
hsl_to_rgb :: proc(h: f32, s: f32, l: f32) -> (RGB_Color_Data, bool) {
  // Validate input ranges
  if h < 0 || h > 360 || s < 0 || s > 1 || l < 0 || l > 1 {
      return RGB_Color_Data{}, false
  }

  // Handle special case of saturation = 0 (grayscale)
  if s == 0 {
      v := u8(math.round_f32(l * 255))
      return RGB_Color_Data{EightBit_Color_Data(v), EightBit_Color_Data(v), EightBit_Color_Data(v)}, true
  }

  // Helper function for hue to RGB conversion
  hue_to_rgb :: proc(p, q: f32, t: f32) -> f32 {
      t_adj := t
      if t_adj < 0 do t_adj += 1
      if t_adj > 1 do t_adj -= 1
      if t_adj < 1.0/6.0 do return p + (q - p) * 6 * t_adj
      if t_adj < 1.0/2.0 do return q
      if t_adj < 2.0/3.0 do return p + (q - p) * (2.0/3.0 - t_adj) * 6
      return p
  }

  q := l < 0.5 ? l * (1 + s) : l + s - l * s
  p := 2 * l - q
  h_norm := h / 360

  r := hue_to_rgb(p, q, h_norm + 1.0/3.0)
  g := hue_to_rgb(p, q, h_norm)
  b := hue_to_rgb(p, q, h_norm - 1.0/3.0)

  return RGB_Color_Data{
      EightBit_Color_Data(math.round_f32(r * 255)),
      EightBit_Color_Data(math.round_f32(g * 255)),
      EightBit_Color_Data(math.round_f32(b * 255)),
  }, true
}
