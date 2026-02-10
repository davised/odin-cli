#+feature dynamic-literals
#+feature global-context
package style

import "core:strings"
import "core:strconv"
import "core:log"
import "core:fmt"
import "core:math"

OnError :: enum { Ignore, Warn, Error }

Options :: struct {
  parsing: OnError,
}

package_options: ^Options

// set_options sets the package-level formatting options.
//
// Parameters:
//   opts: The Options struct containing the desired formatting settings.
set_options :: proc(opts: ^Options) {
  package_options.parsing = opts.parsing
}

@(private="file")
@(init)
init_options :: proc() {
  default_options := Options{ parsing = OnError.Warn }

  package_options = &default_options
}

invalid_parsing_enum_msg :: proc() {
  log.errorf("The package_options.parsing setting (%w) is invalid. This should not happen.", package_options.parsing)
}

/*
fg_map maps string representations of foreground colors to their corresponding ANSI_FG enum values.
This map is used to quickly look up the ANSI code for a given foreground color name.

Example keys: "red", "brightblue"
Example values: ANSI_FG.Red, ANSI_FG.Bright_Blue
*/
fg_map := map[string]ANSI_FG {
  "none"          = .None,
  "black"         = .Black,
  "red"           = .Red,
  "green"         = .Green,
  "yellow"        = .Yellow,
  "blue"          = .Blue,
  "magenta"       = .Magenta,
  "cyan"          = .Cyan,
  "white"         = .White,
  "brightblack"   = .Bright_Black,
  "brightred"     = .Bright_Red,
  "brightgreen"   = .Bright_Green,
  "brightyellow"  = .Bright_Yellow,
  "brightblue"    = .Bright_Blue,
  "brightmagenta" = .Bright_Magenta,
  "brightcyan"    = .Bright_Cyan,
  "brightwhite"   = .Bright_White,
}

/*
bg_map maps string representations of background colors to their corresponding ANSI_BG enum values.
This map is used to quickly look up the ANSI code for a given background color name.

Example keys: "red", "brightblue"
Example values: ANSI_BG.Red, ANSI_BG.Bright_Blue
*/
bg_map := map[string]ANSI_BG {
  "none"          = .None,
  "black"         = .Black,
  "red"           = .Red,
  "green"         = .Green,
  "yellow"        = .Yellow,
  "blue"          = .Blue,
  "magenta"       = .Magenta,
  "cyan"          = .Cyan,
  "white"         = .White,
  "brightblack"   = .Bright_Black,
  "brightred"     = .Bright_Red,
  "brightgreen"   = .Bright_Green,
  "brightyellow"  = .Bright_Yellow,
  "brightblue"    = .Bright_Blue,
  "brightmagenta" = .Bright_Magenta,
  "brightcyan"    = .Bright_Cyan,
  "brightwhite"   = .Bright_White,
}

/*
style_map maps string representations of text styles to their corresponding Text_Style enum values.

Example keys: "bold", "italic"
Example values: Text_Style.Bold, Text_Style,Italic
*/
style_map := map[string]Text_Style {
  "none"        = .None,
  "bold"        = .Bold,
  "faint"       = .Faint,
  "italic"      = .Italic,
  "underline"   = .Underline,
  "blink_slow"  = .Blink_Slow,
  "blink_rapid" = .Blink_Rapid,
  "invert"      = .Invert,
  "hide"        = .Hide,
  "strike"      = .Strike,
}

/*
hex_to_rgb converts a hex color string to an RGB struct.
It accepts strings with or without the leading '#'.

Parameters:
  hex_string: The hexadecimal color string (e.g., "#FF0000" or "FF0000").

Returns:
  RGB: The RGB color data.
  bool: True if the conversion was successful, false otherwise.
*/
hex_to_rgb :: proc(hex_string: string) -> (RGB, bool) {
    // Remove the '#' if it exists
    hex_bytes: string
    if strings.has_prefix(hex_string, "#") {
      hex_bytes = hex_string[1:]
    } else {
      hex_bytes = hex_string
    }

    // Check for valid length (6 hex characters)
    if len(hex_bytes) != 6 {
        return RGB{}, false
    }

    // Parse each color component
    r, err_r := strconv.parse_uint(hex_bytes[0:2], 16)
    g, err_g := strconv.parse_uint(hex_bytes[2:4], 16)
    b, err_b := strconv.parse_uint(hex_bytes[4:6], 16)

    // Check for parsing errors
    if !err_r || !err_g || !err_b {
        return RGB{}, false
    }

    return RGB{EightBit(r), EightBit(g), EightBit(b)}, true
}

/*
hsl_to_rgb converts HSL color values to RGB.

Parameters:
  h: The hue value (0-360 degrees).
  s: The saturation value (0.0-1.0).
  l: The lightness value (0.0-1.0).

Returns:
  RGB: The RGB color data.
  bool: True if the conversion was successful, false otherwise (e.g., if input values are out of range).
*/
hsl_to_rgb :: proc(h: f32, s: f32, l: f32) -> (RGB, bool) {
  // Validate input ranges
  if h < 0 || h > 360 || s < 0 || s > 1 || l < 0 || l > 1 {
      return RGB{}, false
  }

  // Handle special case of saturation = 0 (grayscale)
  if s == 0 {
      v := u8(math.round_f32(l * 255))
      return RGB{EightBit(v), EightBit(v), EightBit(v)}, true
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

  return RGB{
      EightBit(math.round_f32(r * 255)),
      EightBit(math.round_f32(g * 255)),
      EightBit(math.round_f32(b * 255)),
  }, true
}

/*
st takes a text string and a style string and returns a Styled_Text.
The style string can contain text styles (bold, italic, etc.) and color specifications
for the foreground (fg:<color>) and background (bg:<color>).
Note: If a color code is found without a prefix, it is assumed to be foreground.

Supported color formats:
  - Named colors: black, red, green, etc.
  - Hexadecimal: #RRGGBB or RRGGBB
  - RGB: rgb(r,g,b) where r, g, and b are 0-255
  - 8-bit color: color(n) where n is 0-255
  - HSL: hsl(h,s,l) where h is 0-360, s and l are between 0..=1

Parameters:
  text: The string of text to be styled.
  style_string: A string specifying the desired styles.

Returns:
  Styled_Text: The text with the applied styles.
  bool (optional): Indicates if the style string was parsed successfully.
*/
st :: proc(text: string, style_string: string, allocator := context.temp_allocator) -> (Styled_Text, bool) #optional_ok {
  result := Styled_Text{text = text}
  if result.text == "" {
    // No style info added when text is empty.
    return result, false
  }
  style := Style{}

  when ODIN_DEBUG { log.debugf("Parsing style string: '%s' for text: '%s'", style_string, text) }

  // Each part will correspond to a lowercase text or color style
  for part in parse_split(style_string, allocator = allocator) {
    when ODIN_DEBUG { log.debugf("Processing style part: '%s'", part) }

    // Check text_style first as most strings will be text_style
    if text_styles, text_ok := style_map[part]; text_ok {
      style.text_styles += {text_styles}
      when ODIN_DEBUG { log.debugf("Successfully parsed text style: '%s'", part) }
      continue
    } 

    // Assume foreground color if not text_style
    bg := false
    color_str := part

    if strings.has_prefix(color_str, "bg:") {
      when ODIN_DEBUG { log.debugf("Checking color_str as bg: %s", color_str) }
      bg = true 
      color_str = color_str[3:]
    } else if strings.has_prefix(color_str, "fg:") {
      when ODIN_DEBUG { log.debugf("Checking color_str as fg: %s", color_str) }
      color_str = color_str[3:]
    } else {
      when ODIN_DEBUG { log.debugf("Checking color_str as fg: %s", color_str) }
    }

    if color, color_ok := parse_color(color_str, bg); color_ok {
      if bg {
        when ODIN_DEBUG { log.debugf("Successfully parsed background color: '%s'", color_str) }
        style.background_color = color
      } else {
        when ODIN_DEBUG { log.debugf("Successfully parsed foreground color: '%s'", color_str) }
        style.foreground_color = color
      }
      continue
    }

    if package_options.parsing == .Error {
      log.errorf("Failed to parse style part as either color or text style: '%s'", part)
      return result, false
    } else if package_options.parsing == .Warn {
      log.warnf("Failed to parse style part as either color or text style: '%s'", part)
    } else if package_options.parsing == .Ignore {
      when ODIN_DEBUG { log.debugf("Failed to parse style part as either color or text style: '%s'", part) }
    }

  }

  when ODIN_DEBUG { log.debugf("Successfully created Styled_Text with %d text styles and fg:%t bg:%t", card(style.text_styles), style.foreground_color != nil, style.background_color != nil) }
  result.style = style
  return result, true
}

// parse_color handles different color format inputs and returns a Colors.
// It attempts to parse the input string as a named color, a hexadecimal color,
// an RGB color (rgb(r,g,b)), a HSL color(hsl(h, s, l)) or an 8-bit color (color(n)).
//
// Parameters:
//   color_str: The string representing the color.
//   bg: A boolean flag indicating if the color should be parsed as a background color.
//
// Returns:
//   Colors: The parsed color data. This can be an ANSI color code or RGB data.
//   bool: True if the color string was successfully parsed, false otherwise.
parse_color :: proc(color_str: string, bg: bool = false) -> (Colors, bool) {
  // assert(all_lower(color_str))
  when ODIN_DEBUG { log.debugf("Parsing color string: '%s'", color_str) }

  // Checking for unrecognized characters. Expect lowercase a-z, 0-9, parens, colon, period, comma, #, and space
  if !all_valid(color_str) {
    switch package_options.parsing {
    case .Error:
      log.errorf("Unable to parse color str: %s", color_str)
    case .Warn:
      log.warnf("Unable to parse color str: %s", color_str)
    case .Ignore:
    }
    return nil, false
  }

  // Try as named color
  if bg {
    if result, ok := bg_map[color_str]; ok {
      when ODIN_DEBUG { log.debugf("Matched named background color: '%s'", color_str) }
      return result, ok
    }
  } else {
    if result, ok := fg_map[color_str]; ok {
      when ODIN_DEBUG { log.debugf("Matched named foreground color: '%s'", color_str) }
      return result, ok
    }
  }

  // Try as hex color
  if strings.has_prefix(color_str, "#") || len(color_str) == 6 {
    if result, ok := hex_to_rgb(color_str); ok {
      when ODIN_DEBUG { log.debugf("Successfully parsed hex color: '%s'", color_str) }
      return result, ok
    }
    switch package_options.parsing{
    case .Error:
      log.errorf("Failed to parse as hex color: '%s'", color_str)
    case .Warn:
      log.warnf("Failed to parse as hex color: '%s'", color_str)
    case .Ignore:
      when ODIN_DEBUG { log.debugf("Failed to parse as hex color: '%s'", color_str) }
    case:
      invalid_parsing_enum_msg()
    }
    return nil, false
  }

  // Try as HSL format: hsl(h,s,l)
  if strings.has_prefix(color_str, "hsl(") && strings.has_suffix(color_str, ")") {
    hsl_str := color_str[4:len(color_str)-1]
    hsl_parts := strings.count(hsl_str, ",")

    if hsl_parts != 2 {
        switch package_options.parsing{
        case .Error:
          log.errorf("Invalid HSL format (wrong number of components): '%s'", color_str)
        case .Warn:
          log.warnf("Invalid HSL format (wrong number of components): '%s'", color_str)
        case .Ignore:
          when ODIN_DEBUG { log.debugf("Invalid HSL format (wrong number of components): '%s'", color_str) }
        case:
          invalid_parsing_enum_msg()
        }
        return nil, false
    }

    h, s, l : f32
    h_ok, s_ok, l_ok : bool
    i := 0
    for value in strings.split_iterator(&hsl_str, ",") {
      switch i {
      case 0:
        h, h_ok = strconv.parse_f32(strings.trim_space(value))
      case 1:
        s, s_ok = strconv.parse_f32(strings.trim_space(value))
      case 2:
        l, l_ok = strconv.parse_f32(strings.trim_space(value))
      }
      i += 1
    }

    if !h_ok || !s_ok || !l_ok {
      switch package_options.parsing{
      case .Error:
        log.errorf("Failed to parse HSL components: '%s'", color_str)
      case .Warn:
        log.warnf("Failed to parse HSL components: '%s'", color_str)
      case .Ignore:
        when ODIN_DEBUG { log.debugf("Failed to parse HSL components: '%s'", color_str) }
      case:
        invalid_parsing_enum_msg()
      }
      return nil, false
    }

    if result, ok := hsl_to_rgb(h, s, l); ok {
        when ODIN_DEBUG { log.debugf("Successfully parsed HSL color: hsl(%f,%f,%f)", h, s, l) }
        return result, ok
    } else {
        switch package_options.parsing{
        case .Error:
          log.errorf("HSL values out of range: '%s'", color_str)
        case .Warn:
          log.warnf("HSL values out of range: '%s'", color_str)
        case .Ignore:
          when ODIN_DEBUG { log.debugf("HSL values out of range: '%s'", color_str) }
        case:
          invalid_parsing_enum_msg()
        }
        return nil, false
    }
  }

  // Try as RGB format: rgb(r,g,b)
  if strings.has_prefix(color_str, "rgb(") && strings.has_suffix(color_str, ")") {
    rgb_str := color_str[4:len(color_str)-1]
    rgb_parts := strings.count(rgb_str, ",")
    
    if rgb_parts != 2 {
      switch package_options.parsing{
      case .Error:
        log.errorf("Invalid RGB format (wrong number of components): '%s'", color_str)
      case .Warn:
        log.warnf("Invalid RGB format (wrong number of components): '%s'", color_str)
      case .Ignore:
        when ODIN_DEBUG { log.debugf("Invalid RGB format (wrong number of components): '%s'", color_str) }
      case:
        invalid_parsing_enum_msg()
      }
      return nil, false
    }

    r, g, b : uint
    r_ok, g_ok, b_ok : bool
    i := 0
    for value in strings.split_iterator(&rgb_str, ",") {
      switch i {
      case 0:
        r, r_ok = strconv.parse_uint(strings.trim_space(value), 10)
      case 1:
        g, g_ok = strconv.parse_uint(strings.trim_space(value), 10)
      case 2:
        b, b_ok = strconv.parse_uint(strings.trim_space(value), 10)
      }
      i += 1
    }

    if !r_ok || !g_ok || !b_ok {
      switch package_options.parsing{
      case .Error:
        log.errorf("Failed to parse RGB components: '%s'", color_str)
      case .Warn:
        log.warnf("Failed to parse RGB components: '%s'", color_str)
      case .Ignore:
        when ODIN_DEBUG { log.debugf("Failed to parse RGB components: '%s'", color_str) }
      case:
        invalid_parsing_enum_msg()
      }
      return nil, false
    }
    if r > 255 || g > 255 || b > 255 {
      switch package_options.parsing{
      case .Error:
        log.errorf("RGB values out of range: '%s'", color_str)
      case .Warn:
        log.warnf("RGB values out of range: '%s'", color_str)
      case .Ignore:
        when ODIN_DEBUG { log.debugf("RGB values out of range: '%s'", color_str) }
      case:
        invalid_parsing_enum_msg()
      }
      return nil, false
    }

    when ODIN_DEBUG { log.debugf("Successfully parsed RGB color: rgb(%d,%d,%d)", r, g, b) }
    return RGB{EightBit(r), EightBit(g), EightBit(b)}, true
  }

  // Try as 8-bit color: color(n)
  if strings.has_prefix(color_str, "color(") && strings.has_suffix(color_str, ")") {
      num_str := strings.trim_space(color_str[6:len(color_str)-1])
      if value, ok := strconv.parse_uint(num_str, 10); ok && value <= 255 {
          when ODIN_DEBUG { log.debugf("Successfully parsed 8-bit color: %d", value) }
          return EightBit(value), true
      }
      switch package_options.parsing{
      case .Error:
        log.errorf("Failed to parse 8-bit color value: '%s'", color_str)
      case .Warn:
        log.warnf("Failed to parse 8-bit color value: '%s'", color_str)
      case .Ignore:
        when ODIN_DEBUG { log.debugf("Failed to parse 8-bit color value: '%s'", num_str) }
      case:
        invalid_parsing_enum_msg()
      }
      return nil, false
  }

  when ODIN_DEBUG { log.debugf("Failed to parse color string in any format: '%s'", color_str) }

  return nil, false
}

/*
parse_split Splits a string on spaces while preserving spaces within parentheses.

Parameters:
  input: string - The input string to be split. Can contain nested parentheses
                  and spaces both inside and outside parentheses.

Returns:
  []string - A slice containing the split string parts. Spaces outside parentheses
             are used as delimiters and removed. Content within parentheses,
             including spaces, is preserved intact as a single element.

Example:
  input: "hello world (foo bar) baz"
  returns: ["hello", "world", "(foo bar)", "baz"]

Note:
  - Empty input returns an empty slice
  - Multiple consecutive spaces are treated as a single delimiter
  - Handles nested parentheses correctly
  - Doesn't handle unclosed parens
*/
@(private)
parse_split :: proc(input: string, allocator := context.temp_allocator) -> []string {
  input := strings.to_lower(input, allocator = allocator)
  result := make([dynamic]string, allocator = allocator)
  if input == "" {
    append(&result, "")
    return result[:]
  }
  in_paren := false
  
  // parsing_str := &input

  temp_str := make([dynamic]string, 7, allocator = allocator)
  for item in strings.fields_iterator(&input) {
    if in_paren {
      if n := strings.count(item, ")"); n > 0 {
        if n > 1 || !strings.has_suffix(item, ")") {
          // Split the string to try and fix it
          when ODIN_DEBUG { log.debugf("Attempting to fix incorrect string: %s", item) }
          fixed := strings.split_after_n(item, ")", 2, allocator)
          append(&temp_str, fixed[0])
          if len(input) > 0 {
            input = strings.join({ fixed[1], input }, sep = " ", allocator = allocator)
          } else {
            input = fixed[1]
          }
        } else {
          append(&temp_str, item)
        }
        append(&result, strings.concatenate(temp_str[:], allocator = allocator))
        clear(&temp_str)
        in_paren = false
      } else {
        append(&temp_str, item)
      }
    } else {
      if strings.contains_rune(item, '(') {
        if strings.has_suffix(item, ")") {
          append(&result, item)
        } else if strings.contains_rune(item, ')') {
          log.errorf("Style string seems to be malformed, closing paren is not at end of string '%s'", item)
        } else {
          append(&temp_str, item)
          in_paren = true
        }
      } else {
        append(&result, item)
      }
    }
  }

  if in_paren {
    log.errorf("Style string seems to be malformed, final closing paren is missing")
    append(&result, strings.concatenate(temp_str[:], allocator = allocator))
    clear(&temp_str)
    in_paren = false
  }

  if len(input) > 0 {
    append(&result, input)
  }

  return result[:]
}

all_valid :: proc(str: string) -> bool {
  for r in str {
    switch r {
    case 'a'..='z', '0'..='9', '(', ')', ':', '#', '.', ',', ' ':
      continue
    case:
      switch package_options.parsing{
      case .Error:
        log.errorf("Invalid text style component: '%v' from '%s'", r, str)
      case .Warn:
        log.warnf("Invalid text style component: '%v' from '%s'", r, str)
      case .Ignore:
        when ODIN_DEBUG { log.debugf("Invalid text style component: '%v' from '%s'", r, str) }
      }
      return false
    }
  }
  return true
}
