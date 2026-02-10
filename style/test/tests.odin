package style_test

import style ".."
import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"
import "core:time"

@(test)
test_hsl_to_rgb :: proc(t: ^testing.T) {
	// Test cases: { h, s, l, expected_r, expected_g, expected_b }
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
			testing.expect_value(t, rgb.r, style.EightBit(test_case.expected_r))
			testing.expect_value(t, rgb.g, style.EightBit(test_case.expected_g))
			testing.expect_value(t, rgb.b, style.EightBit(test_case.expected_b))
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
	// Test cases: { input_string, expected_color_data, expected_ok }
	test_cases := []struct {
		input_string:   string,
		bg_flag:        bool,
		expected_color: style.Colors,
		expected_ok:    bool,
	} {
		{"red", false, style.ANSI_FG.Red, true},
		{"RED", false, style.ANSI_FG.Red, false},
		{"brightblue", false, style.ANSI_FG.Bright_Blue, true},
		{"black", true, style.ANSI_BG.Black, true},
		{"#FF0000", false, style.RGB{255, 0, 0}, false},
		{"#ff0000", false, style.RGB{255, 0, 0}, true},
		{"FF0000", false, style.RGB{255, 0, 0}, false},
		{"rgb(255,0,0)", false, style.RGB{255, 0, 0}, true},
		{"rgb( 255 , 0 , 0 )", false, style.RGB{255, 0, 0}, true},
		{"hsl(0,1,0.5)", false, style.RGB{255, 0, 0}, true},
		{"hsl(0, 1, 0.5)", false, style.RGB{255, 0, 0}, true},
		{"hsl(120,1,0.5)", false, style.RGB{0, 255, 0}, true},
		{"hsl(240,1,0.5)", false, style.RGB{0, 0, 255}, true},
		{"hsl(180, 0.5, 0.5)", false, style.RGB{64, 191, 191}, true},
		{"hsl(0, 0, 0.75)", false, style.RGB{191, 191, 191}, true},
		{"hsl(0, 0, 0.44)", false, style.RGB{112, 112, 112}, true},
		{"hsl(0, 0, 0.17)", false, style.RGB{43, 43, 43}, true},
		{"color(1)", false, style.EightBit(1), true},
		{"color(255)", false, style.EightBit(255), true},
		{"badcolor", false, nil, false},
		{"rgb(255,0,0,0)", false, nil, false},
		{"rgb(256,0,0)", false, nil, false},
		{"hsl(0,1,0.5,0)", false, nil, false},
		{"hsl(0,2,0.5)", false, nil, false},
		{"color(256)", false, nil, false},
	}
	testing.set_fail_timeout(t, 5 * time.Second)

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)
	style.package_options.parsing = style.OnError.Warn

	for test_case in test_cases {
		color, ok := style.parse_color(test_case.input_string, test_case.bg_flag)
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
		expected_styles:   style.Text_Style_Set,
		expected_fg_color: style.Colors,
		expected_bg_color: style.Colors,
		expected_ok:       bool,
	} {
		{"hello", "bold", "hello", {style.Text_Style.Bold}, nil, nil, true},
		{"world", "italic red", "world", {style.Text_Style.Italic}, style.ANSI_FG.Red, nil, true},
		{"test", "fg:blue bg:#00FF00", "test", {}, style.ANSI_FG.Blue, style.RGB{0, 255, 0}, true},
		{
			"123",
			"underline bold fg:rgb(255, 0, 0)bg:hsl(120,1,0.5)",
			"123",
			{style.Text_Style.Underline, style.Text_Style.Bold},
			style.RGB{255, 0, 0},
			style.RGB{0, 255, 0},
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
				style.Text_Style.Bold,
				style.Text_Style.Italic,
				style.Text_Style.Underline,
				style.Text_Style.Blink_Slow,
				style.Text_Style.Blink_Rapid,
				style.Text_Style.Invert,
				style.Text_Style.Hide,
				style.Text_Style.Strike,
			},
			nil,
			nil,
			true,
		},
		{"numbers", "color( 123 )", "numbers", {}, style.EightBit(123), nil, true},
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
test_fg_color_to_writer :: proc(t: ^testing.T) {
	test_cases := []struct {
		color:           style.Colors,
		expected_output: string,
	} {
		{style.ANSI_FG.Red, "\x1b[31m"},
		{style.ANSI_FG.Bright_Green, "\x1b[92m"},
		{style.EightBit(123), "\x1b[38;5;123m"},
		{style.RGB{255, 0, 100}, "\x1b[38;2;255;0;100m"},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		sb := strings.builder_make()
		n := 0
		style.fg_color_to_writer(strings.to_writer(&sb), test_case.color, &n)
		output := strings.to_string(sb)
		testing.expect_value(t, output, test_case.expected_output)
		strings.builder_destroy(&sb)
	}
}

@(test)
test_bg_color_to_writer :: proc(t: ^testing.T) {
	test_cases := []struct {
		color:           style.Colors,
		expected_output: string,
	} {
		{style.ANSI_BG.Blue, "\x1b[44m"},
		{style.ANSI_BG.Bright_Magenta, "\x1b[105m"},
		{style.EightBit(55), "\x1b[48;5;55m"},
		{style.RGB{10, 200, 5}, "\x1b[48;2;10;200;5m"},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		sb := strings.builder_make()
		n := 0
		style.bg_color_to_writer(strings.to_writer(&sb), test_case.color, &n)
		output := strings.to_string(sb)
		testing.expect_value(t, output, test_case.expected_output)
		strings.builder_destroy(&sb)
	}
}

@(test)
test_text_styles_to_writer :: proc(t: ^testing.T) {
	test_cases := []struct {
		styles:          style.Text_Style_Set,
		expected_output: string,
	} {
		{{style.Text_Style.Bold}, "\x1b[1m"},
		{{style.Text_Style.Italic, style.Text_Style.Underline}, "\x1b[3;4m"},
		{
			{
				style.Text_Style.Bold,
				style.Text_Style.Italic,
				style.Text_Style.Underline,
				style.Text_Style.Blink_Slow,
				style.Text_Style.Blink_Rapid,
				style.Text_Style.Invert,
				style.Text_Style.Hide,
				style.Text_Style.Strike,
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
		text:            style.Text,
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
		styled_text:     style.Styled_Text,
		expected_output: string,
	} {
		{
			style.Styled_Text {
				text = "hello",
				style = style.Style{text_styles = {style.Text_Style.Bold}, foreground_color = style.ANSI_FG.Red},
			},
			"\x1b[1m\x1b[31mhello\x1b[0m",
		},
		{
			style.Styled_Text {
				text = "world",
				style = style.Style {
					text_styles = {style.Text_Style.Italic, style.Text_Style.Underline},
					foreground_color = style.RGB{0, 255, 0},
					background_color = style.EightBit(123),
				},
			},
			"\x1b[3;4m\x1b[38;2;0;255;0m\x1b[48;5;123mworld\x1b[0m",
		},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	for test_case in test_cases {
		output, ok := style.to_str(test_case.styled_text)
		defer delete(output)

		testing.expect_value(t, output, test_case.expected_output)
	}
}

@(test)
test_Styled_Text_Formatter :: proc(t: ^testing.T) {
	test_cases := []struct {
		styled_text:     style.Styled_Text,
		expected_output: string,
	} {
		{
			style.Styled_Text {
				text = "hello",
				style = style.Style{text_styles = {style.Text_Style.Bold}, foreground_color = style.ANSI_FG.Red},
			},
			"\x1b[1m\x1b[31mhello\x1b[0m",
		},
		{
			style.Styled_Text {
				text = "world",
				style = style.Style {
					text_styles = {style.Text_Style.Italic, style.Text_Style.Underline},
					foreground_color = style.RGB{0, 255, 0},
					background_color = style.EightBit(123),
				},
			},
			"\x1b[3;4m\x1b[38;2;0;255;0m\x1b[48;5;123mworld\x1b[0m",
		},
		{
			style.Styled_Text {
				text = "",
				style = style.Style{text_styles = {style.Text_Style.Bold}, foreground_color = style.ANSI_FG.Red},
			},
			"",
		},
	}

	testing.set_fail_timeout(t, 5 * time.Second)

	debug := true
	style.package_options.parsing = .Warn
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	for test_case in test_cases {
		output := fmt.aprintf("%v", test_case.styled_text)
		defer delete(output)
		testing.expect_value(t, output, test_case.expected_output)
	}
}
