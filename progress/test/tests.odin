package progress_test

import progress ".."
import style "../../style"
import "core:fmt"
import "core:strings"
import "core:testing"
import "core:time"

@(test)
test_to_writer_zero_percent :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false)
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Should have left_cap + 10 empty chars + right_cap
	testing.expect(t, strings.contains(result, "["), "should contain left cap")
	testing.expect(t, strings.contains(result, "]"), "should contain right cap")
	// All empty (░), no fill (█)
	testing.expect(t, !strings.contains(result, "\u2588"), "zero percent should have no fill chars")
	testing.expect(t, strings.count(result, "\u2591") == 10, "zero percent should have 10 empty chars")
}

@(test)
test_to_writer_full :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false)
	p.current = 100
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// All fill (█), no empty (░)
	testing.expect(t, strings.count(result, "\u2588") == 10, "full bar should have 10 fill chars")
	testing.expect(t, !strings.contains(result, "\u2591"), "full bar should have no empty chars")
}

@(test)
test_to_writer_half :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false)
	p.current = 50
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.count(result, "\u2588") == 5, "half bar should have 5 fill chars")
	testing.expect(t, strings.count(result, "\u2591") == 5, "half bar should have 5 empty chars")
}

@(test)
test_to_writer_with_percentage :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = true)
	p.current = 50
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, " 50%"), "should contain percentage")
}

@(test)
test_to_writer_with_count :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false, show_count = true)
	p.current = 50
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, " (50/100)"), "should contain count")
}

@(test)
test_to_writer_with_message :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false, message = "Loading")
	p.current = 0
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.has_prefix(result, "Loading "), "should start with message")
}

@(test)
test_to_writer_ascii_style :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, bar_style = progress.bar_ascii(), width = 10, show_percentage = false)
	p.current = 50
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// ASCII: fill "=", head ">", empty " "
	testing.expect(t, strings.contains(result, "="), "ascii style should contain = for fill")
	testing.expect(t, strings.contains(result, ">"), "ascii style should contain > for head")
	// 5 fill chars, 1 head, 4 empty = 10 total
	testing.expect(t, strings.count(result, "=") == 5, "should have 5 fill chars")
}

@(test)
test_bar_width_explicit :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 20, show_percentage = false)
	p.current = 0
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Should have exactly 20 empty chars between caps
	testing.expect(t, strings.count(result, "\u2591") == 20, "should have exactly 20 empty chars")
}

@(test)
test_increment :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false)
	testing.expect_value(t, p.current, 0)

	// Manually increment (don't call progress.increment which writes to stderr)
	p.current = min(p.current + 10, p.total)
	testing.expect_value(t, p.current, 10)

	p.current = min(p.current + 5, p.total)
	testing.expect_value(t, p.current, 15)

	// Increment past total should cap at total
	p.current = min(p.current + 200, p.total)
	testing.expect_value(t, p.current, 100)
}

@(test)
test_fmt_formatter :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = true)
	p.current = 75

	formatted := fmt.aprintf("%v", p)
	defer delete(formatted)

	direct, ok := progress.to_str(p)
	defer delete(direct)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect_value(t, formatted, direct)
}

@(test)
test_plain_mode :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = true, mode = .Plain)
	p.current = 50
	p.fill_style = style.Style{foreground_color = style.ANSI_Color.Green}
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "Plain to_str should succeed")
	testing.expect(t, !strings.contains(result, "\x1b["), "Plain should contain no ANSI codes")
	testing.expect(t, strings.contains(result, "["), "Plain should still have bar caps")
	testing.expect(t, strings.contains(result, "]"), "Plain should still have bar caps")
	testing.expect(t, strings.contains(result, "50%"), "Plain should preserve percentage")
}

@(test)
test_no_color_mode :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	p := progress.make_progress(100, width = 10, show_percentage = false, mode = .No_Color)
	p.current = 50
	p.fill_style = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Green}
	result, ok := progress.to_str(p)
	defer delete(result)

	testing.expect(t, ok, "No_Color to_str should succeed")
	// Bold SGR present on fill, color stripped
	testing.expect(t, strings.contains(result, "\x1b[1m"), "No_Color should keep bold on fill")
	testing.expect(t, strings.contains(result, "\x1b[0m"), "No_Color should have reset")
	testing.expect(t, !strings.contains(result, "\x1b[32m"), "No_Color should not have green color")
}
