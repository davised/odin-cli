#+feature global-context
#+feature dynamic-literals
package style

import "core:log"
import "core:math"
import "core:strconv"
import "core:strings"

// OnError controls how parsing errors are reported.
OnError :: enum {
	Ignore,
	Warn,
	Error,
}

// Options holds package-level configuration.
Options :: struct {
	parsing: OnError,
}

// package_options stores the current package-level options (default: parsing = .Warn).
package_options: Options = Options{parsing = .Warn}

// set_options sets the package-level formatting options.
set_options :: proc(opts: ^Options) {
	package_options.parsing = opts.parsing
}

// report logs a message at the level determined by `package_options.parsing`.
@(private)
report :: proc(msg: string, args: ..any) {
	switch package_options.parsing {
	case .Error:
		log.errorf(msg, ..args)
	case .Warn:
		log.warnf(msg, ..args)
	case .Ignore:
		when ODIN_DEBUG {
			log.debugf(msg, ..args)
		}
	}
}

// color_map maps lowercase color names to their ANSI_Color values.
color_map := map[string]ANSI_Color {
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

// style_map maps lowercase style names to their Text_Style values.
style_map := map[string]Text_Style {
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
hex_to_rgb converts a hexadecimal color string to an RGB struct.
Accepts strings with or without the leading '#'.

Inputs:
- hex_string: The hexadecimal color string (e.g., "#ff0000" or "ff0000").

Returns:
- The RGB color value.
- true if the conversion was successful, false otherwise.
*/
hex_to_rgb :: proc(hex_string: string) -> (RGB, bool) {
	hex_bytes: string
	if strings.has_prefix(hex_string, "#") {
		hex_bytes = hex_string[1:]
	} else {
		hex_bytes = hex_string
	}

	if len(hex_bytes) != 6 {
		return RGB{}, false
	}

	r, err_r := strconv.parse_uint(hex_bytes[0:2], 16)
	g, err_g := strconv.parse_uint(hex_bytes[2:4], 16)
	b, err_b := strconv.parse_uint(hex_bytes[4:6], 16)

	if !err_r || !err_g || !err_b {
		return RGB{}, false
	}

	return RGB{EightBit(r), EightBit(g), EightBit(b)}, true
}

/*
hsl_to_rgb converts HSL (hue, saturation, lightness) color values to RGB.

Inputs:
- h: Hue in degrees (0-360).
- s: Saturation (0.0-1.0).
- l: Lightness (0.0-1.0).

Returns:
- The RGB color value.
- true if successful, false if any input value is out of range.
*/
hsl_to_rgb :: proc(h: f32, s: f32, l: f32) -> (RGB, bool) {
	if h < 0 || h > 360 || s < 0 || s > 1 || l < 0 || l > 1 {
		return RGB{}, false
	}

	if s == 0 {
		v := u8(math.round_f32(l * 255))
		return RGB{EightBit(v), EightBit(v), EightBit(v)}, true
	}

	hue_to_rgb :: proc(p, q: f32, t: f32) -> f32 {
		t_adj := t
		if t_adj < 0 do t_adj += 1
		if t_adj > 1 do t_adj -= 1
		if t_adj < 1.0 / 6.0 do return p + (q - p) * 6 * t_adj
		if t_adj < 1.0 / 2.0 do return q
		if t_adj < 2.0 / 3.0 do return p + (q - p) * (2.0 / 3.0 - t_adj) * 6
		return p
	}

	q := l < 0.5 ? l * (1 + s) : l + s - l * s
	p := 2 * l - q
	h_norm := h / 360

	r := hue_to_rgb(p, q, h_norm + 1.0 / 3.0)
	g := hue_to_rgb(p, q, h_norm)
	b := hue_to_rgb(p, q, h_norm - 1.0 / 3.0)

	return RGB {
			EightBit(math.round_f32(r * 255)),
			EightBit(math.round_f32(g * 255)),
			EightBit(math.round_f32(b * 255)),
		},
		true
}

/*
st parses a style string and applies it to the given text, returning a Styled_Text.
The style string can contain space-separated text styles and color specifications.
Colors without a prefix are assumed to be foreground.

Supported color formats:
- Named colors: black, red, green, brightblue, etc.
- Hexadecimal: #rrggbb or rrggbb
- RGB: rgb(r,g,b) where r, g, b are 0-255
- 8-bit: color(n) where n is 0-255
- HSL: hsl(h,s,l) where h is 0-360, s and l are 0.0-1.0

Prefixes `fg:` and `bg:` select foreground or background color targets.

Inputs:
- text: The string to be styled.
- style_string: A space-separated string of style and color tokens.
- allocator: (default: context.temp_allocator)

Returns:
- The styled text with the parsed styles applied.
- true if parsing succeeded (or only produced warnings), false on error or empty text.
*/
st :: proc(
	text: string,
	style_string: string,
	allocator := context.temp_allocator,
) -> (
	Styled_Text,
	bool,
) #optional_ok {
	result := Styled_Text {
		text = text,
	}
	if result.text == "" {
		return result, false
	}
	parsed_style := Style{}

	when ODIN_DEBUG {log.debugf("Parsing style string: '%s' for text: '%s'", style_string, text)}

	for part in parse_split(style_string, allocator = allocator) {
		when ODIN_DEBUG {log.debugf("Processing style part: '%s'", part)}

		if text_styles, text_ok := style_map[part]; text_ok {
			parsed_style.text_styles += {text_styles}
			when ODIN_DEBUG {log.debugf("Successfully parsed text style: '%s'", part)}
			continue
		}

		bg := false
		color_str := part

		if strings.has_prefix(color_str, "bg:") {
			when ODIN_DEBUG {log.debugf("Checking color_str as bg: %s", color_str)}
			bg = true
			color_str = color_str[3:]
		} else if strings.has_prefix(color_str, "fg:") {
			when ODIN_DEBUG {log.debugf("Checking color_str as fg: %s", color_str)}
			color_str = color_str[3:]
		} else {
			when ODIN_DEBUG {log.debugf("Checking color_str as fg: %s", color_str)}
		}

		if color, color_ok := parse_color(color_str); color_ok {
			if bg {
				when ODIN_DEBUG {log.debugf("Successfully parsed background color: '%s'", color_str)}
				parsed_style.background_color = color
			} else {
				when ODIN_DEBUG {log.debugf("Successfully parsed foreground color: '%s'", color_str)}
				parsed_style.foreground_color = color
			}
			continue
		}

		if package_options.parsing == .Error {
			log.errorf("Failed to parse style part as either color or text style: '%s'", part)
			return result, false
		} else if package_options.parsing == .Warn {
			log.warnf("Failed to parse style part as either color or text style: '%s'", part)
		} else if package_options.parsing == .Ignore {
			when ODIN_DEBUG {log.debugf("Failed to parse style part as either color or text style: '%s'", part)}
		}

	}

	when ODIN_DEBUG {log.debugf(
			"Successfully created Styled_Text with %d text styles and fg:%t bg:%t",
			card(parsed_style.text_styles),
			parsed_style.foreground_color != nil,
			parsed_style.background_color != nil,
		)}
	result.style = parsed_style
	return result, true
}

/*
parse_color parses a color string into a Colors value. Tries named colors, hex, HSL, RGB,
and 8-bit formats in order.

Inputs:
- color_str: A lowercase color string (e.g., "red", "#ff0000", "rgb(255,0,0)", "hsl(0,1,0.5)", "color(196)").

Returns:
- The parsed color value, or nil on failure.
- true if the color was successfully parsed.
*/
parse_color :: proc(color_str: string) -> (Colors, bool) {
	when ODIN_DEBUG {log.debugf("Parsing color string: '%s'", color_str)}

	if !all_valid(color_str) {
		report("Unable to parse color str: %s", color_str)
		return nil, false
	}

	if result, ok := color_map[color_str]; ok {
		when ODIN_DEBUG {log.debugf("Matched named color: '%s'", color_str)}
		return result, ok
	}

	// Try as hex color
	if strings.has_prefix(color_str, "#") || len(color_str) == 6 {
		if result, ok := hex_to_rgb(color_str); ok {
			when ODIN_DEBUG {log.debugf("Successfully parsed hex color: '%s'", color_str)}
			return result, ok
		}
		report("Failed to parse as hex color: '%s'", color_str)
		return nil, false
	}

	// Try as HSL format: hsl(h,s,l)
	if strings.has_prefix(color_str, "hsl(") && strings.has_suffix(color_str, ")") {
		hsl_str := color_str[4:len(color_str) - 1]
		hsl_parts := strings.count(hsl_str, ",")

		if hsl_parts != 2 {
			report("Invalid HSL format (wrong number of components): '%s'", color_str)
			return nil, false
		}

		h, s, l: f32
		h_ok, s_ok, l_ok: bool
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
			report("Failed to parse HSL components: '%s'", color_str)
			return nil, false
		}

		if result, ok := hsl_to_rgb(h, s, l); ok {
			when ODIN_DEBUG {log.debugf("Successfully parsed HSL color: hsl(%f,%f,%f)", h, s, l)}
			return result, ok
		} else {
			report("HSL values out of range: '%s'", color_str)
			return nil, false
		}
	}

	// Try as RGB format: rgb(r,g,b)
	if strings.has_prefix(color_str, "rgb(") && strings.has_suffix(color_str, ")") {
		rgb_str := color_str[4:len(color_str) - 1]
		rgb_parts := strings.count(rgb_str, ",")

		if rgb_parts != 2 {
			report("Invalid RGB format (wrong number of components): '%s'", color_str)
			return nil, false
		}

		r, g, b: uint
		r_ok, g_ok, b_ok: bool
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
			report("Failed to parse RGB components: '%s'", color_str)
			return nil, false
		}
		if r > 255 || g > 255 || b > 255 {
			report("RGB values out of range: '%s'", color_str)
			return nil, false
		}

		when ODIN_DEBUG {log.debugf("Successfully parsed RGB color: rgb(%d,%d,%d)", r, g, b)}
		return RGB{EightBit(r), EightBit(g), EightBit(b)}, true
	}

	// Try as 8-bit color: color(n)
	if strings.has_prefix(color_str, "color(") && strings.has_suffix(color_str, ")") {
		num_str := strings.trim_space(color_str[6:len(color_str) - 1])
		if value, ok := strconv.parse_uint(num_str, 10); ok && value <= 255 {
			when ODIN_DEBUG {log.debugf("Successfully parsed 8-bit color: %d", value)}
			return EightBit(value), true
		}
		report("Failed to parse 8-bit color value: '%s'", color_str)
		return nil, false
	}

	when ODIN_DEBUG {log.debugf("Failed to parse color string in any format: '%s'", color_str)}

	return nil, false
}

/*
parse_split splits a style string on spaces while preserving content within parentheses.
The input is lowercased before splitting.

Inputs:
- input: The style string to split.
- allocator: (default: context.temp_allocator)

Returns:
- A slice of the split tokens. Empty input returns an empty slice.

Example:
	parse_split("bold fg:rgb(255, 0, 0) underline") => ["bold", "fg:rgb(255,0,0)", "underline"]
*/
@(private)
parse_split :: proc(input: string, allocator := context.temp_allocator) -> []string {
	lower := strings.to_lower(input, allocator = allocator)
	result := make([dynamic]string, allocator = allocator)
	if lower == "" {
		return result[:]
	}
	in_paren := false

	temp_str := make([dynamic]string, 7, allocator = allocator)
	for item in strings.fields_iterator(&lower) {
		if in_paren {
			if n := strings.count(item, ")"); n > 0 {
				if n > 1 || !strings.has_suffix(item, ")") {
					when ODIN_DEBUG {log.debugf("Attempting to fix incorrect string: %s", item)}
					fixed := strings.split_after_n(item, ")", 2, allocator)
					append(&temp_str, fixed[0])
					if len(lower) > 0 {
						lower = strings.join({fixed[1], lower}, sep = " ", allocator = allocator)
					} else {
						lower = fixed[1]
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

// all_valid returns true if the string contains only valid style/color characters (a-z, 0-9, ():#.,  ).
all_valid :: proc(str: string) -> bool {
	for r in str {
		switch r {
		case 'a' ..= 'z', '0' ..= '9', '(', ')', ':', '#', '.', ',', ' ':
			continue
		case:
			report("Invalid text style component: '%v' from '%s'", r, str)
			return false
		}
	}
	return true
}
