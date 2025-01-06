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
parse_text_style :: proc(s: string) -> (styles: Text_Style_Set, ok: bool) {
  ok = false
  switch strings.to_lower(s) {
  case "bold":
    styles = {.Bold}
    ok = true
    return
  case "faint":
    styles = {.Faint}
    ok = true
    return
  case "italic":
    styles = {.Italic}
    ok = true
    return
  case "underline":
    styles = {.Underline}
    ok = true
    return
  case "blink_slow":
    styles = {.Blink_Slow}
    ok = true
    return
  case "blink_rapid":
    styles = {.Blink_Rapid}
    ok = true
    return
  case "invert":
    styles = {.Invert}
    ok = true
    return
  case "hide":
    styles = {.Hide}
    ok = true
    return
  case "strike":
    styles = {.Strike}
    ok = true
    return
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
  result := Styled_Text{Text = text}
  style := Style{}
  ok := true
  using package_options

  debug("Parsing style string: '%s' for text: '%s'", style_string, text, printer = .debugf)

  // Split style string into parts
  parts := strings.split(style_string, " ")
  defer delete(parts)

  for part in parts {
    debug("Processing style part: '%s'", part, printer = .debugf)
    if strings.has_prefix(part, "bg:") {
      color_str := part[3:]
      style.Background_Color, ok = parse_color(color_str, true)
      if !ok {
        if ParseError == .Error {
          log.errorf("Failed to parse background color: '%s'", color_str)
          return result, ok
        } else if ParseError == .Warn {
          log.warnf("Failed to parse background color: '%s'", color_str)
          continue
        } else if ParseError == .Ignore {
          debug("Failed to parse background color: '%s'", color_str, printer = .debugf)
          continue
        }
      }
      debug("Successfully parsed background color: '%s'", color_str, printer = .debugf)
    } else if strings.has_prefix(part, "fg:") {
      color_str := part[3:]
      style.Foreground_Color, ok = parse_color(color_str, false)
      if !ok {
        if ParseError == .Error {
          log.errorf("Failed to parse foreground color: '%s'", color_str)
          return result, ok
        } else if ParseError == .Warn {
          log.warnf("Failed to parse foreground color: '%s'", color_str)
          continue
        } else if ParseError == .Ignore {
          debug("Failed to parse foreground color: '%s'", color_str, printer = .debugf)
          continue
        }
      }
      debug("Successfully parsed foreground color: '%s'", color_str, printer = .debugf)
    } else {
        // Try to parse as color first
        if color, ok := parse_color(part, false); ok {
            style.Foreground_Color = color
            debug("Successfully parsed unprefixed color: '%s'", part, printer = .debugf)
        } else {
            // Try to parse as text style
            text_styles, ok := parse_text_style(part)
            if ok {
              style.Text_Styles += text_styles
              debug("Successfully parsed text style: '%s'", part, printer = .debugf)
            } else {
              if ParseError == .Error {
                log.errorf("Failed to parse style part as either color or text style: '%s'", part)
                return result, ok
              } else if ParseError == .Warn {
                log.warnf("Failed to parse style part as either color or text style: '%s'", part)
                continue
              } else if ParseError == .Ignore {
                debug("Failed to parse style part as either color or text style: '%s'", part)
                continue
              }
            }
        }
    }
  }

  debug("Successfully created Styled_Text with %d text styles", card(style.Text_Styles), printer = .debugf)
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
  color_str_lower := strings.to_lower(color_str)
  debug("Parsing color string: '%s'", color_str, printer = .debugf)

  if bg {
    result = ANSI_BG_Colors.None
  } else {
    result = ANSI_FG_Colors.None
  }

  // Try as named color
  if bg {
    if result, ok := bg_map[color_str_lower]; ok {
      debug("Matched named background color: '%s'", color_str_lower, printer = .debugf)
      return result, true
    }
  } else {
    if result, ok := fg_map[color_str_lower]; ok {
      debug("Matched named foreground color: '%s'", color_str_lower, printer = .debugf)
      return result, true
    }
  }

  // Try as hex color
  if strings.has_prefix(color_str, "#") || len(color_str) == 6 {
      if result, ok := hex_to_rgb(color_str); ok {
          debug("Successfully parsed hex color: '%s'", color_str, printer = .debugf)
          return result, true
      }
      debug("Failed to parse as hex color: '%s'", color_str, printer = .debugf)
  }

  // Try as HSL format: hsl(h,s,l)
  if strings.has_prefix(color_str_lower, "hsl(") && strings.has_suffix(color_str_lower, ")") {
    hsl_str := color_str_lower[4:len(color_str_lower)-1]
    hsl_parts := strings.split(hsl_str, ",")
    defer delete(hsl_parts)

    if len(hsl_parts) != 3 {
        debug("Invalid HSL format (wrong number of components): '%s'", color_str, printer = .debugf)
        return ANSI_FG_Colors.None, false
    }

    h, ok1 := strconv.parse_f32(strings.trim_space(hsl_parts[0]))
    s, ok2 := strconv.parse_f32(strings.trim_space(hsl_parts[1]))
    l, ok3 := strconv.parse_f32(strings.trim_space(hsl_parts[2]))

    if !ok1 || !ok2 || !ok3 {
        debug("Failed to parse HSL components: '%s'", color_str, printer = .debugf)
        return ANSI_FG_Colors.None, false
    }

    if result, ok := hsl_to_rgb(h, s, l); ok {
        debug("Successfully parsed HSL color: hsl(%f,%f,%f)", h, s, l, printer = .debugf)
        return result, true
    } else {
        debug("HSL values out of range: '%s'", color_str, printer = .debugf)
        return ANSI_FG_Colors.None, false
    }
  }


  // Try as RGB format: rgb(r,g,b)
  if strings.has_prefix(color_str_lower, "rgb(") && strings.has_suffix(color_str_lower, ")") {
      rgb_str := color_str_lower[4:len(color_str_lower)-1]
      rgb_parts := strings.split(rgb_str, ",")
      defer delete(rgb_parts)
      
      if len(rgb_parts) != 3 {
          debug("Invalid RGB format (wrong number of components): '%s'", color_str, printer = .debugf)
          return ANSI_FG_Colors.None, false
      }

      r, ok1 := strconv.parse_uint(strings.trim_space(rgb_parts[0]), 10)
      g, ok2 := strconv.parse_uint(strings.trim_space(rgb_parts[1]), 10)
      b, ok3 := strconv.parse_uint(strings.trim_space(rgb_parts[2]), 10)

      if !ok1 || !ok2 || !ok3 {
          debug("Failed to parse RGB components: '%s'", color_str, printer = .debugf)
          return ANSI_FG_Colors.None, false
      }
      if r > 255 || g > 255 || b > 255 {
          debug("RGB components out of range: '%s'", color_str, printer = .debugf)
          return ANSI_FG_Colors.None, false
      }

      debug("Successfully parsed RGB color: rgb(%d,%d,%d)", r, g, b)
      return RGB_Color_Data{EightBit_Color_Data(r), EightBit_Color_Data(g), EightBit_Color_Data(b)}, true
  }

  // Try as 8-bit color: color(n)
  if strings.has_prefix(color_str_lower, "color(") && strings.has_suffix(color_str_lower, ")") {
      num_str := color_str_lower[6:len(color_str_lower)-1]
      if value, ok := strconv.parse_uint(num_str, 10); ok && value <= 255 {
          debug("Successfully parsed 8-bit color: %d", value, printer = .debugf)
          return EightBit_Color_Data(value), true
      }
      debug("Failed to parse 8-bit color value: '%s'", num_str, printer = .debugf)
  }

  debug("Failed to parse color string in any format: '%s'", color_str, printer = .debugf)

  return result, false
}
