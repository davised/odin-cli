// Color depth degradation: converts colors to fit terminal capabilities.
package style

import "../term"

// Xterm 6x6x6 color cube component values (indices 0-5).
@(private = "file")
cube_values := [6]int{0, 95, 135, 175, 215, 255}

// Standard 16-color ANSI palette RGB values (VGA/xterm).
@(private = "file")
ansi_palette := [16]RGB {
	{0, 0, 0},       // Black
	{128, 0, 0},     // Red
	{0, 128, 0},     // Green
	{128, 128, 0},   // Yellow
	{0, 0, 128},     // Blue
	{128, 0, 128},   // Magenta
	{0, 128, 128},   // Cyan
	{192, 192, 192}, // White
	{128, 128, 128}, // Bright_Black
	{255, 0, 0},     // Bright_Red
	{0, 255, 0},     // Bright_Green
	{255, 255, 0},   // Bright_Yellow
	{0, 0, 255},     // Bright_Blue
	{255, 0, 255},   // Bright_Magenta
	{0, 255, 255},   // Bright_Cyan
	{255, 255, 255}, // Bright_White
}

// ANSI_Color values corresponding to palette indices 0-15.
@(private = "file")
ansi_palette_colors := [16]ANSI_Color {
	.Black, .Red, .Green, .Yellow, .Blue, .Magenta, .Cyan, .White,
	.Bright_Black, .Bright_Red, .Bright_Green, .Bright_Yellow,
	.Bright_Blue, .Bright_Magenta, .Bright_Cyan, .Bright_White,
}

/*
rgb_to_eightbit converts an RGB color to the nearest 8-bit (256-color) code.
Compares the 6x6x6 color cube (indices 16-231) and the 24-step grayscale ramp
(indices 232-255), returning whichever has lower Euclidean distance.

Zero allocation.
*/
rgb_to_eightbit :: proc(c: RGB) -> EightBit {
	r := int(c.r)
	g := int(c.g)
	b := int(c.b)

	// 6x6x6 color cube: index = 16 + 36*ri + 6*gi + bi
	ri := nearest_cube_index(r)
	gi := nearest_cube_index(g)
	bi := nearest_cube_index(b)
	cube_idx := 16 + 36 * ri + 6 * gi + bi
	cube_dist := sq_dist(r, g, b, cube_values[ri], cube_values[gi], cube_values[bi])

	// Grayscale ramp: indices 232-255, 24 shades from 8 to 238
	// gray_value = 8 + 10 * (index - 232)
	gray_idx: int
	if r == g && g == b {
		// Exact gray — find nearest ramp entry
		gray_idx = clamp((r - 8 + 5) / 10, 0, 23)
	} else {
		avg := (r + g + b) / 3
		gray_idx = clamp((avg - 8 + 5) / 10, 0, 23)
	}
	gray_val := 8 + 10 * gray_idx
	gray_dist := sq_dist(r, g, b, gray_val, gray_val, gray_val)

	if gray_dist < cube_dist {
		return EightBit(232 + gray_idx)
	}
	return EightBit(cube_idx)
}

/*
rgb_to_ansi converts an RGB color to the nearest 16-color ANSI_Color
using Euclidean distance against the standard VGA/xterm palette.

Zero allocation.
*/
rgb_to_ansi :: proc(c: RGB) -> ANSI_Color {
	r := int(c.r)
	g := int(c.g)
	b := int(c.b)

	best_idx := 0
	best_dist := max(int)
	for pal, i in ansi_palette {
		d := sq_dist(r, g, b, int(pal.r), int(pal.g), int(pal.b))
		if d < best_dist {
			best_dist = d
			best_idx = i
		}
	}
	return ansi_palette_colors[best_idx]
}

/*
eightbit_to_ansi converts a 256-color code to the nearest 16-color ANSI_Color.
Indices 0-15 map directly. Indices 16-255 are converted to RGB first, then
matched against the ANSI palette.

Zero allocation.
*/
eightbit_to_ansi :: proc(c: EightBit) -> ANSI_Color {
	idx := int(c)
	if idx < 16 {
		return ansi_palette_colors[idx]
	}
	// Convert 8-bit to RGB, then to ANSI
	return rgb_to_ansi(eightbit_to_rgb(c))
}

/*
eightbit_to_rgb converts a 256-color code to its RGB components.
Indices 0-15 use the standard ANSI palette. Indices 16-231 use the 6x6x6
color cube. Indices 232-255 use the grayscale ramp.
*/
eightbit_to_rgb :: proc(c: EightBit) -> RGB {
	idx := int(c)
	if idx < 16 {
		return ansi_palette[idx]
	}
	if idx < 232 {
		// 6x6x6 color cube
		ci := idx - 16
		bi := ci % 6
		gi := (ci / 6) % 6
		ri := ci / 36
		return RGB{EightBit(cube_values[ri]), EightBit(cube_values[gi]), EightBit(cube_values[bi])}
	}
	// Grayscale ramp
	gray := u8(8 + 10 * (idx - 232))
	return RGB{EightBit(gray), EightBit(gray), EightBit(gray)}
}

/*
degrade_color converts a color to fit the given color depth capability.

- True_Color / nil: return as-is
- Eight_Bit: RGB → EightBit; others unchanged
- Four_Bit / Three_Bit: RGB → ANSI, EightBit → ANSI; ANSI unchanged
- None: return nil (no color)

Zero allocation.
*/
degrade_color :: proc(c: Colors, depth: term.Color_Depth) -> Colors {
	switch depth {
	case .True_Color:
		return c
	case .Eight_Bit:
		if rgb, is_rgb := c.(RGB); is_rgb {
			return rgb_to_eightbit(rgb)
		}
		return c
	case .Four_Bit, .Three_Bit:
		switch v in c {
		case RGB:
			return rgb_to_ansi(v)
		case EightBit:
			return eightbit_to_ansi(v)
		case ANSI_Color:
			return v
		}
		return c
	case .None:
		return nil
	}
	return c
}

// nearest_cube_index returns the cube_values index closest to the given 0-255 value.
@(private = "file")
nearest_cube_index :: proc(val: int) -> int {
	best := 0
	best_dist := abs(val - cube_values[0])
	for i in 1 ..< 6 {
		d := abs(val - cube_values[i])
		if d < best_dist {
			best_dist = d
			best = i
		}
	}
	return best
}

// Squared Euclidean distance between two RGB triples.
@(private = "file")
sq_dist :: proc(r1, g1, b1, r2, g2, b2: int) -> int {
	dr := r1 - r2
	dg := g1 - g2
	db := b1 - b2
	return dr * dr + dg * dg + db * db
}
