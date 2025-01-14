package cli_style

import "core:strings"
import "core:strconv"
import "core:log"

// fg_map maps string representations of foreground colors to their corresponding ANSI_FG_Colors enum values.
// This map is used to quickly look up the ANSI code for a given foreground color name.
//
// Example keys: "red", "brightblue"
// Example values: ANSI_FG_Colors.Red, ANSI_FG_Colors.Bright_Blue
fg_map := map[string]ANSI_FG_Colors {
  "black"         = ANSI_FG_Colors.Black,
  "red"           = ANSI_FG_Colors.Red,
  "green"         = ANSI_FG_Colors.Green,
  "yellow"        = ANSI_FG_Colors.Yellow,
  "blue"          = ANSI_FG_Colors.Blue,
  "magenta"       = ANSI_FG_Colors.Magenta,
  "cyan"          = ANSI_FG_Colors.Cyan,
  "white"         = ANSI_FG_Colors.White,
  "brightblack"   = ANSI_FG_Colors.Bright_Black,
  "brightred"     = ANSI_FG_Colors.Bright_Red,
  "brightgreen"   = ANSI_FG_Colors.Bright_Green,
  "brightyellow"  = ANSI_FG_Colors.Bright_Yellow,
  "brightblue"    = ANSI_FG_Colors.Bright_Blue,
  "brightmagenta" = ANSI_FG_Colors.Bright_Magenta,
  "brightcyan"    = ANSI_FG_Colors.Bright_Cyan,
  "brightwhite"   = ANSI_FG_Colors.Bright_White,
}

// bg_map maps string representations of background colors to their corresponding ANSI_BG_Colors enum values.
// This map is used to quickly look up the ANSI code for a given background color name.
//
// Example keys: "red", "brightblue"
// Example values: ANSI_BG_Colors.Red, ANSI_BG_Colors.Bright_Blue
bg_map := map[string]ANSI_BG_Colors {
  "black"         = ANSI_BG_Colors.Black,
  "red"           = ANSI_BG_Colors.Red,
  "green"         = ANSI_BG_Colors.Green,
  "yellow"        = ANSI_BG_Colors.Yellow,
  "blue"          = ANSI_BG_Colors.Blue,
  "magenta"       = ANSI_BG_Colors.Magenta,
  "cyan"          = ANSI_BG_Colors.Cyan,
  "white"         = ANSI_BG_Colors.White,
  "brightblack"   = ANSI_BG_Colors.Bright_Black,
  "brightred"     = ANSI_BG_Colors.Bright_Red,
  "brightgreen"   = ANSI_BG_Colors.Bright_Green,
  "brightyellow"  = ANSI_BG_Colors.Bright_Yellow,
  "brightblue"    = ANSI_BG_Colors.Bright_Blue,
  "brightmagenta" = ANSI_BG_Colors.Bright_Magenta,
  "brightcyan"    = ANSI_BG_Colors.Bright_Cyan,
  "brightwhite"   = ANSI_BG_Colors.Bright_White,
}

// parse_text_style attempts to parse a string into a Text_Style_Set.
// It checks if the input string matches one of the supported text style names (e.g., "bold", "italic").
//
// Parameters:
//   s: The string to parse.
//
// Returns:
//   Text_Style_Set: A set containing the parsed text style, if successful.
//   bool: True if the string was successfully parsed into a text style, false otherwise.
parse_text_style :: proc(input: string, allocator := context.temp_allocator) -> (styles: Text_Style_Set, ok: bool) {
  ok = false
  if input == "" {
    switch package_options.parsing {
    case .Error:
      log.errorf("No text style provided")
      ok = false
    case .Warn:
      log.warnf("No text style provided")
      ok = true
    case .Ignore:
      ok = true
    }
    return
  }
  // st() procedure usually passes space-delimited strings, but this could be used to parse strings with more than
  // one style.
  for &style in strings.fields(input, allocator = allocator) {
    style = strings.to_lower(style, allocator = allocator)
    switch style {
    case "bold":
      styles += {.Bold}
      ok = true
    case "faint":
      styles += {.Faint}
      ok = true
    case "italic":
      styles += {.Italic}
      ok = true
    case "underline":
      styles += {.Underline}
      ok = true
    case "blink_slow":
      styles += {.Blink_Slow}
      ok = true
    case "blink_rapid":
      styles += {.Blink_Rapid}
      ok = true
    case "invert":
      styles += {.Invert}
      ok = true
    case "hide":
      styles += {.Hide}
      ok = true
    case "strike":
      styles += {.Strike}
      ok = true
    case:
      switch package_options.parsing {
      case .Error:
        log.errorf("Unknown text style '%s'", style)
        ok = false
      case .Warn:
        log.warnf("Unknown text style '%s'", style)
        ok = true
      case .Ignore:
        ok = true
      }
    }
  }
  return
}

// st takes a text string and a style string and returns a Styled_Text.
// The style string can contain text styles (bold, italic, etc.) and color specifications
// for the foreground (fg:<color>) and background (bg:<color>).
// Note: If a color code is found without a prefix, it is assumed to be foreground.
//
// Supported color formats:
//   - Named colors: black, red, green, etc.
//   - Hexadecimal: #RRGGBB or RRGGBB
//   - RGB: rgb(r,g,b) where r, g, and b are 0-255
//   - 8-bit color: color(n) where n is 0-255
//
// Parameters:
//   text: The string of text to be styled.
//   style_string: A string specifying the desired styles.
//
// Returns:
//   Styled_Text: The text with the applied styles.
//   bool (optional): Indicates if the style string was parsed successfully.
st :: proc(text: string, style_string: string) -> (Styled_Text, bool) #optional_ok {
  result := Styled_Text{Text = Text(text)}
  if result.Text == "" {
    // No style info added when text is empty.
    return result, false
  }
  style := Style{}
  ok := true

  when ODIN_DEBUG {log.debugf("Parsing style string: '%s' for text: '%s'", style_string, text)}

  // Split style string into parts
  parts := parse_split(style_string)

  for part in parts {
    when ODIN_DEBUG { log.debugf("Processing style part: '%s'", part) }
    if strings.has_prefix(part, "bg:") {
      color_str := part[3:]
      style.Background_Color, ok = parse_color(color_str, true)
      if !ok {
        if package_options.parsing == .Error {
          log.errorf("Failed to parse background color: '%s'", color_str)
          return result, ok
        } else if package_options.parsing == .Warn {
          log.warnf("Failed to parse background color: '%s'", color_str)
          continue
        } else if package_options.parsing == .Ignore {
          when ODIN_DEBUG { log.debugf("Failed to parse background color: '%s'", color_str) }
          continue
        }
      }
      when ODIN_DEBUG { log.debugf("Successfully parsed background color: '%s'", color_str) }
    } else if strings.has_prefix(part, "fg:") {
      color_str := part[3:]
      style.Foreground_Color, ok = parse_color(color_str, false)
      if !ok {
        if package_options.parsing == .Error {
          log.errorf("Failed to parse foreground color: '%s'", color_str)
          return result, ok
        } else if package_options.parsing == .Warn {
          log.warnf("Failed to parse foreground color: '%s'", color_str)
          continue
        } else if package_options.parsing == .Ignore {
          when ODIN_DEBUG { log.debugf("Failed to parse foreground color: '%s'", color_str) }
          continue
        }
      }
      when ODIN_DEBUG { log.debugf("Successfully parsed foreground color: '%s'", color_str) }
    } else {
        // Try to parse as color first
        if color, ok := parse_color(part, false); ok {
            style.Foreground_Color = color
            when ODIN_DEBUG { log.debugf("Successfully parsed unprefixed color: '%s'", part) }
        } else {
            // Try to parse as text style
            text_styles, text_ok := parse_text_style(part)
            if text_ok {
              style.Text_Styles += text_styles
              when ODIN_DEBUG { log.debugf("Successfully parsed text style: '%s'", part) }
            } else {
              if package_options.parsing == .Error {
                log.errorf("Failed to parse style part as either color or text style: '%s'", part)
                return result, text_ok
              } else if package_options.parsing == .Warn {
                log.warnf("Failed to parse style part as either color or text style: '%s'", part)
                continue
              } else if package_options.parsing == .Ignore {
                when ODIN_DEBUG { log.debugf("Failed to parse style part as either color or text style: '%s'", part) }
                continue
              }
            }
        }
    }
  }

  when ODIN_DEBUG { log.debugf("Successfully created Styled_Text with %d text styles", card(style.Text_Styles)) }
  result.Style = style
  return result, true
}

// parse_color handles different color format inputs and returns a Color_Data.
// It attempts to parse the input string as a named color, a hexadecimal color,
// an RGB color (rgb(r,g,b)), a HSL color(hsl(h, s, l)) or an 8-bit color (color(n)).
//
// Parameters:
//   color_str: The string representing the color.
//   bg: A boolean flag indicating if the color should be parsed as a background color.
//
// Returns:
//   Color_Data: The parsed color data. This can be an ANSI color code or RGB data.
//   bool: True if the color string was successfully parsed, false otherwise.
parse_color :: proc(color_str: string, bg: bool = false) -> (Color_Data, bool) {
  result: Color_Data
  color_str := strings.to_lower(color_str, context.temp_allocator)
  when ODIN_DEBUG { log.debugf("Parsing color string: '%s'", color_str) }

  if bg {
    result = ANSI_BG_Colors.None
  } else {
    result = ANSI_FG_Colors.None
  }

  // Try as named color
  if bg {
    if result, ok := bg_map[color_str]; ok {
      when ODIN_DEBUG { log.debugf("Matched named background color: '%s'", color_str) }
      return result, true
    }
  } else {
    if result, ok := fg_map[color_str]; ok {
      when ODIN_DEBUG { log.debugf("Matched named foreground color: '%s'", color_str) }
      return result, true
    }
  }

  // Try as hex color
  if strings.has_prefix(color_str, "#") || len(color_str) == 6 {
      if result, ok := hex_to_rgb(color_str); ok {
          when ODIN_DEBUG { log.debugf("Successfully parsed hex color: '%s'", color_str) }
          return result, true
      }
      when ODIN_DEBUG { log.debugf("Failed to parse as hex color: '%s'", color_str) }
  }

  // Try as HSL format: hsl(h,s,l)
  if strings.has_prefix(color_str, "hsl(") && strings.has_suffix(color_str, ")") {
    hsl_str := color_str[4:len(color_str)-1]
    hsl_parts := strings.split(hsl_str, ",")
    defer delete(hsl_parts)

    if len(hsl_parts) != 3 {
        when ODIN_DEBUG { log.debugf("Invalid HSL format (wrong number of components): '%s'", color_str) }
        return ANSI_FG_Colors.None, false
    }

    h, ok1 := strconv.parse_f32(strings.trim_space(hsl_parts[0]))
    s, ok2 := strconv.parse_f32(strings.trim_space(hsl_parts[1]))
    l, ok3 := strconv.parse_f32(strings.trim_space(hsl_parts[2]))

    if !ok1 || !ok2 || !ok3 {
        when ODIN_DEBUG { log.debugf("Failed to parse HSL components: '%s'", color_str) }
        return ANSI_FG_Colors.None, false
    }

    if result, ok := hsl_to_rgb(h, s, l); ok {
        when ODIN_DEBUG { log.debugf("Successfully parsed HSL color: hsl(%f,%f,%f)", h, s, l) }
        return result, true
    } else {
        when ODIN_DEBUG { log.debugf("HSL values out of range: '%s'", color_str) }
        return ANSI_FG_Colors.None, false
    }
  }

  // Try as RGB format: rgb(r,g,b)
  if strings.has_prefix(color_str, "rgb(") && strings.has_suffix(color_str, ")") {
      rgb_str := color_str[4:len(color_str)-1]
      rgb_parts := strings.split(rgb_str, ",", context.temp_allocator)
      
      if len(rgb_parts) != 3 {
          when ODIN_DEBUG { log.debugf("Invalid RGB format (wrong number of components): '%s'", color_str) }
          return ANSI_FG_Colors.None, false
      }

      r, ok1 := strconv.parse_uint(strings.trim_space(rgb_parts[0]), 10)
      g, ok2 := strconv.parse_uint(strings.trim_space(rgb_parts[1]), 10)
      b, ok3 := strconv.parse_uint(strings.trim_space(rgb_parts[2]), 10)

      if !ok1 || !ok2 || !ok3 {
          when ODIN_DEBUG { log.debugf("Failed to parse RGB components: '%s'", color_str) }
          return ANSI_FG_Colors.None, false
      }
      if r > 255 || g > 255 || b > 255 {
          when ODIN_DEBUG { log.debugf("RGB components out of range: '%s'", color_str) }
          return ANSI_FG_Colors.None, false
      }

      when ODIN_DEBUG { log.debugf("Successfully parsed RGB color: rgb(%d,%d,%d)", r, g, b) }
      return RGB_Color_Data{EightBit_Color_Data(r), EightBit_Color_Data(g), EightBit_Color_Data(b)}, true
  }

  // Try as 8-bit color: color(n)
  if strings.has_prefix(color_str, "color(") && strings.has_suffix(color_str, ")") {
      num_str := strings.trim_space(color_str[6:len(color_str)-1])
      if value, ok := strconv.parse_uint(num_str, 10); ok && value <= 255 {
          when ODIN_DEBUG { log.debugf("Successfully parsed 8-bit color: %d", value) }
          return EightBit_Color_Data(value), true
      }
      when ODIN_DEBUG { log.debugf("Failed to parse 8-bit color value: '%s'", num_str) }
  }

  when ODIN_DEBUG { log.debugf("Failed to parse color string in any format: '%s'", color_str) }

  return result, false
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
  returns: ["hello", "(foo bar)", "baz"]

Note:
  - Empty input returns an empty slice
  - Multiple consecutive spaces are treated as a single delimiter
  - Handles nested parentheses correctly
  - Doesn't handle unclosed parens
*/
@(private)
parse_split :: proc(input: string, allocator := context.temp_allocator) -> []string {
  input := input
  result := make([dynamic]string, allocator = allocator)
  if input == "" {
    append(&result, "")
    return result[:]
  }
  in_paren := false
  
  temp_str := make([dynamic]string, 7, allocator = allocator)
  for {
    item := strings.fields_iterator(&input) or_break
    if in_paren {
      if strings.has_suffix(item, ")") {
        append(&temp_str, item)
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
        } else {
          append(&temp_str, item)
          in_paren = true
        }
      } else {
        append(&result, item)
      }
    }
  }

  if len(input) > 0 {
    append(&result, input)
  }

  return result[:]
}
