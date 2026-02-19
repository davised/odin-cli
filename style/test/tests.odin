package style_test

import style ".."
import "../../term"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"
import "core:time"

// Type aliases to reduce `style.` noise in test cases.
RGB :: style.RGB
EightBit :: style.EightBit
ANSI_Color :: style.ANSI_Color
Colors :: style.Colors
Style :: style.Style
Styled_Text :: style.Styled_Text
Text_Style :: style.Text_Style
Text_Style_Set :: style.Text_Style_Set
OnError :: style.OnError

@(test)
test_hsl_to_rgb :: proc(t: ^testing.T) {
	test_cases := []struct {
		h, s, l:                            f32,
		expected_r, expected_g, expected_b: u8,
	} {
		{0, 1, 0.5, 255, 0, 0}, // Red
		{120, 1, 0.5, 0, 255, 0}, // Green
		{240, 1, 0.5, 0, 0, 255}, // Blue
		{0, 0, 1, 255, 255, 255}, // White
		{0, 0, 0, 0, 0, 0}, // Black
		{180, 0.5, 0.5, 64, 191, 191}, // Example HSL value
		{0, 0, 0.75, 191, 191, 191}, // Gray
		{300, 0.75, 0.25, 112, 16, 112}, // Another example
	}
	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		rgb, ok := style.hsl_to_rgb(test_case.h, test_case.s, test_case.l)
		testing.expect(t, ok, msg = "hsl_to_rgb conversion failed")
		if ok {
			testing.expect_value(t, rgb.r, EightBit(test_case.expected_r))
			testing.expect_value(t, rgb.g, EightBit(test_case.expected_g))
			testing.expect_value(t, rgb.b, EightBit(test_case.expected_b))
		}
	}

	// Test invalid inputs
	invalid_test_cases := []struct {
		h, s, l: f32,
	}{{-1, 1, 0.5}, {361, 1, 0.5}, {0, -1, 0.5}, {0, 2, 0.5}, {0, 1, -0.5}, {0, 1, 2}}

	for test_case in invalid_test_cases {
		_, ok := style.hsl_to_rgb(test_case.h, test_case.s, test_case.l)
		testing.expect(t, !ok, msg = "hsl_to_rgb should have failed for invalid inputs")
	}
}

@(test)
test_parse_color :: proc(t: ^testing.T) {
	test_cases := []struct {
		input_string:   string,
		expected_color: Colors,
		expected_ok:    bool,
	} {
		{"red", ANSI_Color.Red, true},
		{"RED", ANSI_Color.Red, false},
		{"brightblue", ANSI_Color.Bright_Blue, true},
		{"black", ANSI_Color.Black, true},
		{"#FF0000", RGB{255, 0, 0}, false},
		{"#ff0000", RGB{255, 0, 0}, true},
		{"FF0000", RGB{255, 0, 0}, false},
		{"rgb(255,0,0)", RGB{255, 0, 0}, true},
		{"rgb( 255 , 0 , 0 )", RGB{255, 0, 0}, true},
		{"hsl(0,1,0.5)", RGB{255, 0, 0}, true},
		{"hsl(0, 1, 0.5)", RGB{255, 0, 0}, true},
		{"hsl(120,1,0.5)", RGB{0, 255, 0}, true},
		{"hsl(240,1,0.5)", RGB{0, 0, 255}, true},
		{"hsl(180, 0.5, 0.5)", RGB{64, 191, 191}, true},
		{"hsl(0, 0, 0.75)", RGB{191, 191, 191}, true},
		{"hsl(0, 0, 0.44)", RGB{112, 112, 112}, true},
		{"hsl(0, 0, 0.17)", RGB{43, 43, 43}, true},
		{"color(1)", EightBit(1), true},
		{"color(255)", EightBit(255), true},
		{"badcolor", nil, false},
		{"rgb(255,0,0,0)", nil, false},
		{"rgb(256,0,0)", nil, false},
		{"hsl(0,1,0.5,0)", nil, false},
		{"hsl(0,2,0.5)", nil, false},
		{"color(256)", nil, false},
	}
	testing.set_fail_timeout(t, 5 * time.Second)

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)
	style.package_options.parsing = OnError.Warn

	for test_case in test_cases {
		color, ok := style.parse_color(test_case.input_string)
		testing.expectf(
			t,
			ok == test_case.expected_ok,
			"parse_color: expected ok to be %v, got %v for input '%s'",
			test_case.expected_ok,
			ok,
			test_case.input_string,
		)
		if ok {
			testing.expect_value(t, color, test_case.expected_color)
		}
	}
}


@(test)
test_st :: proc(t: ^testing.T) {
	test_cases := []struct {
		text:              string,
		style_string:      string,
		expected_text:     string,
		expected_styles:   Text_Style_Set,
		expected_fg_color: Colors,
		expected_bg_color: Colors,
		expected_ok:       bool,
	} {
		{"hello", "bold", "hello", {Text_Style.Bold}, nil, nil, true},
		{"world", "italic red", "world", {Text_Style.Italic}, ANSI_Color.Red, nil, true},
		{"test", "fg:blue bg:#00FF00", "test", {}, ANSI_Color.Blue, RGB{0, 255, 0}, true},
		{
			"123",
			"underline bold fg:rgb(255, 0, 0)bg:hsl(120,1,0.5)",
			"123",
			{Text_Style.Underline, Text_Style.Bold},
			RGB{255, 0, 0},
			RGB{0, 255, 0},
			true,
		},
		{
			"error",
			"fg:badcolor",
			"error",
			{},
			nil,
			nil,
			true, // Because ParseError default is Warn
		},
		{"warning", "bg:invalid", "warning", {}, nil, nil, true},
		{
			"test",
			"bold italic underline blink_slow blink_rapid invert hide strike",
			"test",
			{
				Text_Style.Bold,
				Text_Style.Italic,
				Text_Style.Underline,
				Text_Style.Blink_Slow,
				Text_Style.Blink_Rapid,
				Text_Style.Invert,
				Text_Style.Hide,
				Text_Style.Strike,
			},
			nil,
			nil,
			true,
		},
		{"numbers", "color( 123 )", "numbers", {}, EightBit(123), nil, true},
	}
	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		styled_text, ok := style.st(test_case.text, test_case.style_string)
		testing.expectf(
			t,
			ok == test_case.expected_ok,
			"st: expected ok to be %v, got %v for input '%s' with style '%s'",
			test_case.expected_ok,
			ok,
			test_case.text,
			test_case.style_string,
		)
		if ok {
			testing.expect_value(t, styled_text.text, test_case.expected_text)
			testing.expect_value(t, styled_text.style.text_styles, test_case.expected_styles)
			testing.expect_value(t, styled_text.style.foreground_color, test_case.expected_fg_color)
			testing.expect_value(t, styled_text.style.background_color, test_case.expected_bg_color)
		}
	}
}

@(test)
test_color_to_writer :: proc(t: ^testing.T) {
	// Foreground tests
	fg_cases := []struct {
		color:           Colors,
		expected_output: string,
	} {
		{ANSI_Color.Red, "\x1b[31m"},
		{ANSI_Color.Bright_Green, "\x1b[92m"},
		{EightBit(123), "\x1b[38;5;123m"},
		{RGB{255, 0, 100}, "\x1b[38;2;255;0;100m"},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in fg_cases {
		sb := strings.builder_make()
		n := 0
		style.color_to_writer(strings.to_writer(&sb), test_case.color, false, &n)
		output := strings.to_string(sb)
		testing.expect_value(t, output, test_case.expected_output)
		strings.builder_destroy(&sb)
	}

	// Background tests
	bg_cases := []struct {
		color:           Colors,
		expected_output: string,
	} {
		{ANSI_Color.Blue, "\x1b[44m"},
		{ANSI_Color.Bright_Magenta, "\x1b[105m"},
		{EightBit(55), "\x1b[48;5;55m"},
		{RGB{10, 200, 5}, "\x1b[48;2;10;200;5m"},
	}

	for test_case in bg_cases {
		sb := strings.builder_make()
		n := 0
		style.color_to_writer(strings.to_writer(&sb), test_case.color, true, &n)
		output := strings.to_string(sb)
		testing.expect_value(t, output, test_case.expected_output)
		strings.builder_destroy(&sb)
	}
}

@(test)
test_text_styles_to_writer :: proc(t: ^testing.T) {
	test_cases := []struct {
		styles:          Text_Style_Set,
		expected_output: string,
	} {
		{{Text_Style.Bold}, "\x1b[1m"},
		{{Text_Style.Italic, Text_Style.Underline}, "\x1b[3;4m"},
		{
			{
				Text_Style.Bold,
				Text_Style.Italic,
				Text_Style.Underline,
				Text_Style.Blink_Slow,
				Text_Style.Blink_Rapid,
				Text_Style.Invert,
				Text_Style.Hide,
				Text_Style.Strike,
			},
			"\x1b[1;3;4;5;6;7;8;9m",
		},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		sb := strings.builder_make()
		n := 0
		style.text_styles_to_writer(strings.to_writer(&sb), test_case.styles, &n)
		output := strings.to_string(sb)
		testing.expect_value(t, output, test_case.expected_output)
		strings.builder_destroy(&sb)
	}
}

@(test)
test_text_to_writer :: proc(t: ^testing.T) {
	test_cases := []struct {
		text:            string,
		expected_output: string,
	}{{"hello", "hello\x1b[0m"}, {"world", "world\x1b[0m"}}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		sb := strings.builder_make()
		n := 0
		style.text_to_writer(strings.to_writer(&sb), test_case.text, &n)
		output := strings.to_string(sb)
		testing.expect_value(t, output, test_case.expected_output)
		strings.builder_destroy(&sb)
	}
}

@(test)
test_to_str :: proc(t: ^testing.T) {
	test_cases := []struct {
		styled_text:     Styled_Text,
		expected_output: string,
	} {
		{
			Styled_Text {
				text = "hello",
				style = Style{text_styles = {Text_Style.Bold}, foreground_color = ANSI_Color.Red},
			},
			"\x1b[1m\x1b[31mhello\x1b[0m",
		},
		{
			Styled_Text {
				text = "world",
				style = Style{
					text_styles = {Text_Style.Italic, Text_Style.Underline},
					foreground_color = RGB{0, 255, 0},
					background_color = EightBit(123),
				},
			},
			"\x1b[3;4m\x1b[38;2;0;255;0m\x1b[48;5;123mworld\x1b[0m",
		},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		output, ok := style.to_str(test_case.styled_text, depth = term.Color_Depth.True_Color)
		defer delete(output)

		testing.expect(t, ok, "to_str should return ok=true")
		testing.expect_value(t, output, test_case.expected_output)
	}
}

@(test)
test_Styled_Text_Formatter :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	style.package_options.parsing = .Warn
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	// Bold + ANSI color: formatter uses auto-detected depth, so check structure not exact codes.
	{
		st := Styled_Text {
			text = "hello",
			style = Style{text_styles = {Text_Style.Bold}, foreground_color = ANSI_Color.Red},
		}
		output := fmt.aprintf("%v", st)
		defer delete(output)
		testing.expect(t, strings.contains(output, "hello"), "formatter should contain text")
		testing.expect(t, strings.has_prefix(output, "\x1b["), "formatter should start with CSI")
		testing.expect(t, strings.has_suffix(output, "\x1b[0m"), "formatter should end with reset")
	}

	// RGB + EightBit colors: exact codes depend on detected depth.
	{
		st := Styled_Text {
			text = "world",
			style = Style{
				text_styles = {Text_Style.Italic, Text_Style.Underline},
				foreground_color = RGB{0, 255, 0},
				background_color = EightBit(123),
			},
		}
		output := fmt.aprintf("%v", st)
		defer delete(output)
		testing.expect(t, strings.contains(output, "world"), "formatter should contain text")
		testing.expect(t, strings.has_prefix(output, "\x1b["), "formatter should start with CSI")
		testing.expect(t, strings.has_suffix(output, "\x1b[0m"), "formatter should end with reset")
	}

	// Empty text: should produce empty output regardless of styles.
	{
		st := Styled_Text {
			text = "",
			style = Style{text_styles = {Text_Style.Bold}, foreground_color = ANSI_Color.Red},
		}
		output := fmt.aprintf("%v", st)
		defer delete(output)
		testing.expect_value(t, output, "")
	}
}

@(test)
test_to_writer_plain :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text = "hello",
		style = Style{
			text_styles = {.Bold, .Italic},
			foreground_color = ANSI_Color.Red,
			background_color = ANSI_Color.Blue,
		},
	}

	result, ok := style.to_str(st, .Plain)
	defer delete(result)

	testing.expect(t, ok, "to_str Plain should succeed")
	testing.expect_value(t, result, "hello")
	testing.expect(t, !strings.contains(result, "\x1b["), "Plain mode should contain no ANSI codes")
}

@(test)
test_to_writer_no_color :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text = "hello",
		style = Style{
			text_styles = {.Bold, .Italic},
			foreground_color = ANSI_Color.Red,
			background_color = ANSI_Color.Blue,
		},
	}

	result, ok := style.to_str(st, .No_Color)
	defer delete(result)

	testing.expect(t, ok, "to_str No_Color should succeed")
	// Should contain bold+italic SGR and reset, but no color codes
	testing.expect(t, strings.contains(result, "\x1b[1;3m"), "No_Color should contain bold+italic SGR")
	testing.expect(t, strings.contains(result, "\x1b[0m"), "No_Color should contain reset")
	testing.expect(t, strings.contains(result, "hello"), "No_Color should contain text")
	// Should NOT contain color codes (31m for red, 44m for blue bg)
	testing.expect(t, !strings.contains(result, "\x1b[31m"), "No_Color should not contain fg color")
	testing.expect(t, !strings.contains(result, "\x1b[44m"), "No_Color should not contain bg color")
}

@(test)
test_to_writer_plain_empty :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text = "",
		style = Style{text_styles = {.Bold}, foreground_color = ANSI_Color.Red},
	}

	result, ok := style.to_str(st, .Plain)
	defer delete(result)

	testing.expect(t, ok, "Plain empty text should succeed")
	testing.expect_value(t, result, "")
}

@(test)
test_ansi_complex_style :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// bold+italic+underline + RGB fg + ANSI bg
	st := Styled_Text {
		text = "test",
		style = Style{
			text_styles = {.Bold, .Italic, .Underline},
			foreground_color = RGB{255, 128, 0},
			background_color = ANSI_Color.Blue,
		},
	}
	result, ok := style.to_str(st, depth = term.Color_Depth.True_Color)
	defer delete(result)

	testing.expect(t, ok, "complex style should succeed")
	testing.expect_value(t, result, "\x1b[1;3;4m\x1b[38;2;255;128;0m\x1b[44mtest\x1b[0m")
}

@(test)
test_ansi_styles_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text  = "hello",
		style = Style{text_styles = {.Bold}},
	}
	result, ok := style.to_str(st)
	defer delete(result)

	testing.expect(t, ok, "bold-only should succeed")
	testing.expect_value(t, result, "\x1b[1mhello\x1b[0m")
}

@(test)
test_ansi_eightbit :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text = "hi",
		style = Style{
			foreground_color = EightBit(42),
			background_color = EightBit(200),
		},
	}
	result, ok := style.to_str(st, depth = term.Color_Depth.True_Color)
	defer delete(result)

	testing.expect(t, ok, "8-bit colors should succeed")
	testing.expect_value(t, result, "\x1b[38;5;42m\x1b[48;5;200mhi\x1b[0m")
}

@(test)
test_ansi_rgb_fg_bg :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text = "x",
		style = Style{
			foreground_color = RGB{10, 20, 30},
			background_color = RGB{200, 100, 50},
		},
	}
	result, ok := style.to_str(st, depth = term.Color_Depth.True_Color)
	defer delete(result)

	testing.expect(t, ok, "RGB fg+bg should succeed")
	testing.expect_value(t, result, "\x1b[38;2;10;20;30m\x1b[48;2;200;100;50mx\x1b[0m")
}

@(test)
test_ansi_all_text_styles :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	st := Styled_Text {
		text = "z",
		style = Style{
			text_styles = {.Bold, .Italic, .Underline, .Blink_Slow, .Blink_Rapid, .Invert, .Hide, .Strike},
		},
	}
	result, ok := style.to_str(st)
	defer delete(result)

	testing.expect(t, ok, "all text styles should succeed")
	testing.expect_value(t, result, "\x1b[1;3;4;5;6;7;8;9mz\x1b[0m")
}

@(test)
test_new_sgr_styles :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Double underline (SGR 21)
	st1 := Styled_Text {
		text  = "x",
		style = Style{text_styles = {.Double_Underline}},
	}
	r1, ok1 := style.to_str(st1, depth = term.Color_Depth.True_Color)
	defer delete(r1)
	testing.expect(t, ok1, "double underline should succeed")
	testing.expect_value(t, r1, "\x1b[21mx\x1b[0m")

	// Overlined (SGR 53)
	st2 := Styled_Text {
		text  = "y",
		style = Style{text_styles = {.Overlined}},
	}
	r2, ok2 := style.to_str(st2, depth = term.Color_Depth.True_Color)
	defer delete(r2)
	testing.expect(t, ok2, "overlined should succeed")
	testing.expect_value(t, r2, "\x1b[53my\x1b[0m")

	// Framed + Encircled (SGR 51;52)
	st3 := Styled_Text {
		text  = "z",
		style = Style{text_styles = {.Framed, .Encircled}},
	}
	r3, ok3 := style.to_str(st3, depth = term.Color_Depth.True_Color)
	defer delete(r3)
	testing.expect(t, ok3, "framed+encircled should succeed")
	testing.expect_value(t, r3, "\x1b[51;52mz\x1b[0m")

	// Parse new styles via st()
	parsed, pok := style.st("test", "double_underline overline")
	testing.expect(t, pok, "st() should parse new style names")
	testing.expect(t, .Double_Underline in parsed.style.text_styles, "should contain Double_Underline")
	testing.expect(t, .Overlined in parsed.style.text_styles, "should contain Overlined")
}

@(test)
test_rgb_to_eightbit :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	cases := []struct {
		input:    RGB,
		expected: EightBit,
	} {
		// Pure primaries → color cube corners
		{RGB{255, 0, 0}, 196},     // (5,0,0) = 16 + 180
		{RGB{0, 255, 0}, 46},      // (0,5,0) = 16 + 30
		{RGB{0, 0, 255}, 21},      // (0,0,5) = 16 + 5
		{RGB{255, 255, 255}, 231},  // (5,5,5) = 16 + 215
		{RGB{0, 0, 0}, 16},        // (0,0,0) = 16
		// Exact cube boundary values
		{RGB{95, 95, 95}, 59},      // (1,1,1) = 16 + 36 + 6 + 1
		{RGB{175, 135, 215}, 140},  // (3,2,4) = 16 + 108 + 12 + 4
		// Grayscale ramp
		{RGB{128, 128, 128}, 244},  // gray ramp: 8+10*12=128
		{RGB{8, 8, 8}, 232},        // first gray ramp entry
		{RGB{238, 238, 238}, 255},  // last gray ramp entry
		// Near-gray but not exact — should still pick best match
		{RGB{130, 128, 128}, 244},  // slightly off-gray, nearest gray wins
	}

	for tc in cases {
		result := style.rgb_to_eightbit(tc.input)
		testing.expectf(
			t,
			result == tc.expected,
			"style.rgb_to_eightbit(%v,%v,%v): expected %v, got %v",
			tc.input.r, tc.input.g, tc.input.b,
			tc.expected, result,
		)
	}
}

@(test)
test_rgb_to_ansi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	cases := []struct {
		input:    RGB,
		expected: ANSI_Color,
	} {
		// Exact palette matches
		{RGB{255, 0, 0}, .Bright_Red},
		{RGB{0, 255, 0}, .Bright_Green},
		{RGB{0, 0, 255}, .Bright_Blue},
		{RGB{0, 0, 0}, .Black},
		{RGB{255, 255, 255}, .Bright_White},
		{RGB{128, 0, 0}, .Red},
		{RGB{0, 128, 0}, .Green},
		{RGB{128, 128, 128}, .Bright_Black},
		{RGB{192, 192, 192}, .White},
		// Near-palette: slightly off should still match nearest
		{RGB{130, 2, 2}, .Red},       // close to Red (128,0,0)
		{RGB{250, 5, 5}, .Bright_Red}, // close to Bright_Red (255,0,0)
	}

	for tc in cases {
		result := style.rgb_to_ansi(tc.input)
		testing.expectf(
			t,
			result == tc.expected,
			"style.rgb_to_ansi(%v,%v,%v): expected %v, got %v",
			tc.input.r, tc.input.g, tc.input.b,
			tc.expected, result,
		)
	}
}

@(test)
test_eightbit_to_ansi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	cases := []struct {
		input:    EightBit,
		expected: ANSI_Color,
	} {
		// Direct map for indices 0-15
		{0, .Black},
		{1, .Red},
		{2, .Green},
		{4, .Blue},
		{7, .White},
		{8, .Bright_Black},
		{9, .Bright_Red},
		{15, .Bright_White},
		// Color cube indices → nearest ANSI
		{196, .Bright_Red},   // pure red in cube
		{46, .Bright_Green},  // pure green in cube
		{21, .Bright_Blue},   // pure blue in cube
		// Grayscale ramp → nearest ANSI
		{232, .Black},        // darkest gray (8,8,8)
		{255, .Bright_White}, // lightest gray (238,238,238)
	}

	for tc in cases {
		result := style.eightbit_to_ansi(tc.input)
		testing.expectf(
			t,
			result == tc.expected,
			"style.eightbit_to_ansi(%v): expected %v, got %v",
			tc.input, tc.expected, result,
		)
	}
}

@(test)
test_eightbit_to_rgb :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	cases := []struct {
		input:    EightBit,
		expected: RGB,
	} {
		// ANSI palette (0-15)
		{0, RGB{0, 0, 0}},         // Black
		{1, RGB{128, 0, 0}},       // Red
		{7, RGB{192, 192, 192}},   // White
		{9, RGB{255, 0, 0}},       // Bright_Red
		{15, RGB{255, 255, 255}},  // Bright_White
		// Color cube (16-231): index = 16 + 36*r + 6*g + b
		{16, RGB{0, 0, 0}},        // cube (0,0,0)
		{196, RGB{255, 0, 0}},     // cube (5,0,0)
		{46, RGB{0, 255, 0}},      // cube (0,5,0)
		{21, RGB{0, 0, 255}},      // cube (0,0,5)
		{231, RGB{255, 255, 255}}, // cube (5,5,5)
		{59, RGB{95, 95, 95}},     // cube (1,1,1)
		{140, RGB{175, 135, 215}}, // cube (3,2,4)
		// Grayscale ramp (232-255): gray = 8 + 10*(idx-232)
		{232, RGB{8, 8, 8}},       // first: 8+10*0=8
		{244, RGB{128, 128, 128}}, // mid: 8+10*12=128
		{255, RGB{238, 238, 238}}, // last: 8+10*23=238
	}

	for tc in cases {
		result := style.eightbit_to_rgb(tc.input)
		testing.expectf(
			t,
			result == tc.expected,
			"style.eightbit_to_rgb(%v): expected RGB(%v,%v,%v), got RGB(%v,%v,%v)",
			tc.input,
			tc.expected.r, tc.expected.g, tc.expected.b,
			result.r, result.g, result.b,
		)
	}
}

@(test)
test_degrade_color :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	rgb_red := Colors(RGB{255, 0, 0})
	eb_42 := Colors(EightBit(42))
	ansi_blue := Colors(ANSI_Color.Blue)

	// True_Color: passthrough
	testing.expect_value(t, style.degrade_color(rgb_red, .True_Color), rgb_red)
	testing.expect_value(t, style.degrade_color(eb_42, .True_Color), eb_42)

	// Eight_Bit: RGB → EightBit, others unchanged
	degraded_eb := style.degrade_color(rgb_red, .Eight_Bit)
	_, is_eb := degraded_eb.(EightBit)
	testing.expect(t, is_eb, "RGB should degrade to EightBit at Eight_Bit depth")
	testing.expect_value(t, style.degrade_color(eb_42, .Eight_Bit), eb_42)
	testing.expect_value(t, style.degrade_color(ansi_blue, .Eight_Bit), ansi_blue)

	// Four_Bit: RGB → ANSI, EightBit → ANSI, ANSI unchanged
	degraded_4 := style.degrade_color(rgb_red, .Four_Bit)
	_, is_ansi := degraded_4.(ANSI_Color)
	testing.expect(t, is_ansi, "RGB should degrade to ANSI at Four_Bit depth")
	degraded_eb4 := style.degrade_color(eb_42, .Four_Bit)
	_, is_ansi2 := degraded_eb4.(ANSI_Color)
	testing.expect(t, is_ansi2, "EightBit should degrade to ANSI at Four_Bit depth")
	testing.expect_value(t, style.degrade_color(ansi_blue, .Four_Bit), ansi_blue)

	// Three_Bit: same behavior as Four_Bit
	degraded_3 := style.degrade_color(rgb_red, .Three_Bit)
	_, is_ansi3 := degraded_3.(ANSI_Color)
	testing.expect(t, is_ansi3, "RGB should degrade to ANSI at Three_Bit depth")
	testing.expect_value(t, style.degrade_color(ansi_blue, .Three_Bit), ansi_blue)

	// nil color: passthrough at all depths
	testing.expect_value(t, style.degrade_color(nil, .True_Color), Colors(nil))
	testing.expect_value(t, style.degrade_color(nil, .Four_Bit), Colors(nil))

	// None: everything → nil
	testing.expect_value(t, style.degrade_color(rgb_red, .None), Colors(nil))
	testing.expect_value(t, style.degrade_color(eb_42, .None), Colors(nil))
	testing.expect_value(t, style.degrade_color(ansi_blue, .None), Colors(nil))
}

@(test)
test_to_str_with_depth :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// RGB color at True_Color depth should pass through
	st_rgb := Styled_Text {
		text = "x",
		style = Style{foreground_color = RGB{255, 0, 0}},
	}
	r_tc, ok_tc := style.to_str(st_rgb, depth = term.Color_Depth.True_Color)
	defer delete(r_tc)
	testing.expect(t, ok_tc, "true color should succeed")
	testing.expect_value(t, r_tc, "\x1b[38;2;255;0;0mx\x1b[0m")

	// Same color at Eight_Bit should produce 8-bit code
	r_eb, ok_eb := style.to_str(st_rgb, depth = term.Color_Depth.Eight_Bit)
	defer delete(r_eb)
	testing.expect(t, ok_eb, "eight bit should succeed")
	testing.expect(t, strings.contains(r_eb, "\x1b[38;5;"), "should contain 8-bit prefix")

	// Same color at Four_Bit should produce ANSI code
	r_4b, ok_4b := style.to_str(st_rgb, depth = term.Color_Depth.Four_Bit)
	defer delete(r_4b)
	testing.expect(t, ok_4b, "four bit should succeed")
	// Bright red = 91
	testing.expect(t, strings.contains(r_4b, "\x1b[91m"), "should contain ANSI bright red code")

	// None depth should produce no color codes (just text)
	r_none, ok_none := style.to_str(st_rgb, depth = term.Color_Depth.None)
	defer delete(r_none)
	testing.expect(t, ok_none, "none should succeed")
	testing.expect_value(t, r_none, "x")
}

@(test)
test_css_color_parse :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)
	style.package_options.parsing = OnError.Warn

	// CSS color via parse_color
	color, ok := style.parse_color("coral")
	testing.expect(t, ok, "parse_color should recognize 'coral'")
	if ok {
		rgb, is_rgb := color.(RGB)
		testing.expect(t, is_rgb, "coral should be RGB")
		if is_rgb {
			testing.expect_value(t, rgb.r, EightBit(255))
			testing.expect_value(t, rgb.g, EightBit(127))
			testing.expect_value(t, rgb.b, EightBit(80))
		}
	}

	// CSS color via st()
	styled, sok := style.st("hello", "fg:coral")
	testing.expect(t, sok, "st() should parse CSS colors")
	if sok {
		rgb2, is_rgb2 := styled.style.foreground_color.(RGB)
		testing.expect(t, is_rgb2, "coral via st() should be RGB")
		if is_rgb2 {
			testing.expect_value(t, rgb2.r, EightBit(255))
		}
	}

	// CSS color as background
	styled_bg, bgok := style.st("hello", "bg:slateblue")
	testing.expect(t, bgok, "st() should parse CSS bg colors")
	if bgok {
		_, is_rgb3 := styled_bg.style.background_color.(RGB)
		testing.expect(t, is_rgb3, "slateblue bg should be RGB")
	}
}
