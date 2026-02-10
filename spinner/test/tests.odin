package spinner_test

import "core:testing"
import "core:strings"
import "core:time"
import spinner ".."
import style "../../style"

@(test)
test_to_writer_basic :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	s := spinner.make_spinner(message = "Loading...")
	result, ok := spinner.to_str(s)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// First frame of dots is ⠋
	testing.expect(t, strings.has_prefix(result, "\u280B"), "should start with first dot frame")
	testing.expect(t, strings.has_suffix(result, "Loading..."), "should end with message")
	testing.expect(t, strings.contains(result, " "), "should have space between frame and message")
}

@(test)
test_to_writer_no_message :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	s := spinner.make_spinner(message = "")
	result, ok := spinner.to_str(s)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Just the frame character, no trailing space
	testing.expect_value(t, result, "\u280B")
}

@(test)
test_to_writer_styled :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	s := spinner.make_spinner(
		message = "Working",
		text_style = style.Style{foreground_color = style.ANSI_FG.Cyan},
	)
	result, ok := spinner.to_str(s)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Should contain ANSI escape codes for cyan
	testing.expect(t, strings.contains(result, "\x1b["), "styled spinner should contain ANSI codes")
	testing.expect(t, strings.contains(result, "\x1b[0m"), "styled spinner should contain ANSI reset")
	testing.expect(t, strings.contains(result, "Working"), "should contain message")
}

@(test)
test_frame_cycling :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	frames := spinner.spinner_dots()
	s := spinner.make_spinner(frames = frames, message = "")

	// Render each frame
	for i in 0..<len(frames.frames) {
		s._frame_idx = i
		result, ok := spinner.to_str(s)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		testing.expect_value(t, result, frames.frames[i])
	}

	// Wrapping: frame_idx == len should wrap to frame 0
	s._frame_idx = len(frames.frames)
	result, ok := spinner.to_str(s)
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed for wrapped index")
	testing.expect_value(t, result, frames.frames[0])
}

@(test)
test_preset_frames :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// spinner_dots
	{
		frames := spinner.spinner_dots()
		testing.expect(t, len(frames.frames) > 0, "dots should have frames")
		testing.expect(t, frames.interval > 0, "dots should have positive interval")
	}

	// spinner_line
	{
		frames := spinner.spinner_line()
		testing.expect(t, len(frames.frames) > 0, "line should have frames")
		testing.expect(t, frames.interval > 0, "line should have positive interval")
	}

	// spinner_circle
	{
		frames := spinner.spinner_circle()
		testing.expect(t, len(frames.frames) > 0, "circle should have frames")
		testing.expect(t, frames.interval > 0, "circle should have positive interval")
	}
}
