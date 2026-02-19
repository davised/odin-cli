package panel_test

import panel ".."
import style "../../style"
import "../../term"
import "core:fmt"
import "core:strings"
import "core:testing"
import "core:time"

@(test)
test_basic_rendering :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Hello", "World"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_LIGHT,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .Plain, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	// Plain mode: no borders, just content lines
	testing.expect_value(t, result, "Hello\nWorld\n")
}

@(test)
test_basic_with_borders :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Hi"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect(t, len(lines) >= 3, "should have at least 3 lines")
	testing.expect_value(t, lines[0], "+----+")
	testing.expect_value(t, lines[1], "| Hi |")
	testing.expect_value(t, lines[2], "+----+")
}

@(test)
test_auto_width_sizing :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Short", "A longer line"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "+---------------+")
	testing.expect_value(t, lines[1], "| Short         |")
	testing.expect_value(t, lines[2], "| A longer line |")
	testing.expect_value(t, lines[3], "+---------------+")
}

@(test)
test_fixed_width_truncation :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"This is a very long line that should be truncated"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
		width   = 20,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	for line, i in lines {
		if line == "" do continue
		w := term.display_width(line)
		testing.expectf(t, w == 20, "line %d: expected width 20, got %d: %q", i, w, line)
	}
}

@(test)
test_title_in_border :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Content"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		title   = "Title",
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "+- Title -+")
}

@(test)
test_styled_content :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	styled := style.Styled_Text{text = "Styled", style = style.Style{text_styles = {.Bold}}}
	content := [?]panel.Line{styled}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
	}

	// Full mode should include ANSI
	full_result, ok1 := panel.to_str(p, mode = .Full, allocator = context.temp_allocator)
	testing.expect(t, ok1, "full mode should succeed")
	testing.expect(t, strings.contains(full_result, "\x1b["), "full mode should contain ANSI escapes")

	// Plain mode should strip ANSI and borders
	plain_result, ok2 := panel.to_str(p, mode = .Plain, allocator = context.temp_allocator)
	testing.expect(t, ok2, "plain mode should succeed")
	testing.expect_value(t, plain_result, "Styled\n")
}

@(test)
test_rounded_border :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Hi"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ROUNDED,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "╭────╮")
	testing.expect_value(t, lines[1], "│ Hi │")
	testing.expect_value(t, lines[2], "╰────╯")
}

@(test)
test_no_border :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Line 1", "Line 2"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_NONE,
		padding = 0,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")
	testing.expect_value(t, result, "Line 1\nLine 2\n")
}

@(test)
test_empty_panel :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := panel.Panel {
		border  = panel.BORDER_ASCII,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "+--+")
	testing.expect_value(t, lines[1], "|  |")
	testing.expect_value(t, lines[2], "+--+")
}

@(test)
test_fmt_formatter :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Test"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
	}
	fmt_result := fmt.aprintf("%v", p, allocator = context.temp_allocator)
	str_result, _ := panel.to_str(p, allocator = context.temp_allocator)
	testing.expect_value(t, fmt_result, str_result)
}

@(test)
test_padding_zero :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"AB"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 0,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "+--+")
	testing.expect_value(t, lines[1], "|AB|")
	testing.expect_value(t, lines[2], "+--+")
}

@(test)
test_padding_large :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"X"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 3,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "+-------+")
	testing.expect_value(t, lines[1], "|   X   |")
	testing.expect_value(t, lines[2], "+-------+")
}

@(test)
test_consistent_line_widths :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Short", "Medium length", "A bit longer text"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ROUNDED,
		title   = "Demo",
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	expected_width := 0
	for line in lines {
		if line == "" do continue
		w := term.display_width(line)
		if expected_width == 0 {
			expected_width = w
		} else {
			testing.expectf(t, w == expected_width, "all lines should have same width %d, got %d: %q", expected_width, w, line)
		}
	}
}

@(test)
test_styled_title :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	title := style.Styled_Text{text = "Info", style = style.Style{text_styles = {.Bold}}}
	content := [?]panel.Line{"Content"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		title   = title,
		padding = 1,
	}

	// Full mode should have ANSI in the title
	full_result, ok := panel.to_str(p, mode = .Full, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(full_result, "\x1b["), "title should contain ANSI escapes in full mode")

	// Plain mode should have no borders, just content
	plain_result, ok2 := panel.to_str(p, mode = .Plain, allocator = context.temp_allocator)
	testing.expect(t, ok2, "plain mode should succeed")
	testing.expect_value(t, plain_result, "Content\n")
}

@(test)
test_heavy_border :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Hi"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_HEAVY,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "┏━━━━┓")
	testing.expect_value(t, lines[1], "┃ Hi ┃")
	testing.expect_value(t, lines[2], "┗━━━━┛")
}

@(test)
test_double_border :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"Hi"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_DOUBLE,
		padding = 1,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	testing.expect_value(t, lines[0], "╔════╗")
	testing.expect_value(t, lines[1], "║ Hi ║")
	testing.expect_value(t, lines[2], "╚════╝")
}

@(test)
test_fixed_width_exact :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	content := [?]panel.Line{"ABCDEF"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
		width   = 10,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	for line in lines {
		if line == "" do continue
		w := term.display_width(line)
		testing.expectf(t, w == 10, "expected width 10, got %d: %q", w, line)
	}
}

@(test)
test_negative_padding :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Negative padding should behave the same as padding=0
	content := [?]panel.Line{"AB"}
	neg := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = -5,
	}
	zero := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 0,
	}
	neg_result, _ := panel.to_str(neg, mode = .No_Color, allocator = context.temp_allocator)
	zero_result, _ := panel.to_str(zero, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect_value(t, neg_result, zero_result)
}

@(test)
test_border_none_with_title :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// BORDER_NONE + title: title is not rendered (no top border)
	content := [?]panel.Line{"Hello"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_NONE,
		title   = "Ignored",
		padding = 0,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")
	testing.expect_value(t, result, "Hello\n")
}

@(test)
test_tiny_fixed_width :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Width smaller than border+padding overhead: content_width clamps to 0
	content := [?]panel.Line{"Hello"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		padding = 1,
		width   = 2, // overhead is 4 (2 borders + 2 padding), content_width = 0
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")
	// Should still produce valid output without crashing
	testing.expect(t, len(result) > 0, "should produce some output")

	// All non-empty lines should have equal display width
	lines := strings.split(result, "\n", context.temp_allocator)
	expected_width := 0
	for line in lines {
		if line == "" do continue
		w := term.display_width(line)
		if expected_width == 0 {
			expected_width = w
		} else {
			testing.expectf(t, w == expected_width, "width=2: all lines should have same width %d, got %d: %q", expected_width, w, line)
		}
	}
}

@(test)
test_title_auto_sizing_with_zero_padding :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Title "ABCD" (4 chars) needs 4+4-0 = 8 content_width to fit in border.
	// Content "AB" (2 chars) alone would give content_width=2.
	// Auto-sizing should widen to fit the title.
	content := [?]panel.Line{"AB"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		title   = "ABCD",
		padding = 0,
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	// Title should be visible, not silently dropped
	testing.expect(t, strings.contains(lines[0], "ABCD"), "title should be rendered")

	// All lines should have equal width
	expected_width := 0
	for line in lines {
		if line == "" do continue
		w := term.display_width(line)
		if expected_width == 0 {
			expected_width = w
		} else {
			testing.expectf(t, w == expected_width, "all lines should have same width %d, got %d: %q", expected_width, w, line)
		}
	}
}

@(test)
test_title_truncation :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Fixed width too narrow for title — title should be truncated, not dropped
	content := [?]panel.Line{"Hi"}
	p := panel.Panel {
		lines   = content[:],
		border  = panel.BORDER_ASCII,
		title   = "A Very Long Title",
		padding = 0,
		width   = 10, // content_width=8, title needs 17+4=21 inner, only has 8
	}
	result, ok := panel.to_str(p, mode = .No_Color, allocator = context.temp_allocator)
	testing.expect(t, ok, "to_str should succeed")

	lines := strings.split(result, "\n", context.temp_allocator)
	// Title should be truncated (contains ellipsis), not silently dropped
	testing.expect(t, strings.contains(lines[0], "A V"), "title should be partially visible")

	// All lines should have equal width
	for line in lines {
		if line == "" do continue
		w := term.display_width(line)
		testing.expectf(t, w == 10, "expected width 10, got %d: %q", w, line)
	}
}
