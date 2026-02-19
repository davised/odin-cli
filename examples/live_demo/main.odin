#+feature using-stmt
package live_demo

import "../../progress"
import "../../spinner"
import "../../style"
import "../../term"
import "core:io"
import "core:os"
import "core:terminal/ansi"
import "core:time"

NUM_BARS :: 3

main :: proc() {
	term.install_cleanup_handler()

	w := os.stream_from_handle(os.stderr)
	mode := term.detect_render_mode(os.stderr)

	// Hide cursor
	if mode == .Full {
		term.notify_cursor_hidden()
		io.write_string(w, ansi.CSI + ansi.DECTCEM_HIDE)
	}

	bars: [NUM_BARS]progress.Progress
	spinners: [NUM_BARS]spinner.Spinner
	labels := [NUM_BARS]string{"Downloading", "Processing ", "Thinking   "}
	speeds := [NUM_BARS]int{2, 1, 0} // 0 = indeterminate
	THINKING_LIMIT :: 80 // ticks until "Thinking" completes

	first_frame := true
	tick_count := 0

	reset_bars :: proc(
		bars: ^[NUM_BARS]progress.Progress,
		spinners: ^[NUM_BARS]spinner.Spinner,
		mode: term.Render_Mode,
	) {
		bars[0] = progress.Progress {
			total           = 100,
			width           = 40,
			bar_style       = progress.bar_block(),
			message         = "",
			show_percentage = true,
			show_elapsed    = true,
			fill_style      = style.Style{foreground_color = .Green},
			mode            = mode,
		}
		bars[0]._start_tick = time.tick_now()
		bars[0]._started = true

		bars[1] = progress.Progress {
			total           = 100,
			width           = 40,
			bar_style       = progress.bar_ascii(),
			message         = "",
			show_percentage = true,
			show_elapsed    = true,
			mode            = mode,
		}
		bars[1]._start_tick = time.tick_now()
		bars[1]._started = true

		bars[2] = progress.Progress {
			total           = 100,
			width           = 40,
			bar_style       = progress.bar_thin(),
			message         = "",
			show_percentage = false,
			show_elapsed    = true,
			mode            = mode,
		}
		bars[2]._start_tick = time.tick_now()
		bars[2]._started = true

		spinners[0] = spinner.Spinner {
			frames = spinner.spinner_dots(),
			mode   = mode,
		}
		spinners[1] = spinner.Spinner {
			frames = spinner.spinner_circle(),
			mode   = mode,
		}
		spinners[2] = spinner.Spinner {
			frames = spinner.spinner_line(),
			mode   = mode,
		}
	}

	reset_bars(&bars, &spinners, mode)

	for !term.should_exit() {
		// Move cursor up to overwrite previous frame (skip on first)
		if !first_frame && mode == .Full {
			for _ in 0 ..< NUM_BARS {
				io.write_string(w, ansi.CSI + "1" + ansi.CUU)
			}
		}
		first_frame = false

		// Advance progress
		for i in 0 ..< NUM_BARS {
			if speeds[i] > 0 {
				bars[i].current = min(bars[i].current + speeds[i], bars[i].total)
			} else {
				// Indeterminate: complete after fixed duration
				if tick_count >= THINKING_LIMIT {
					bars[i].current = bars[i].total
				}
			}
		}

		// Render each line
		for i in 0 ..< NUM_BARS {
			if mode == .Full {
				io.write_string(w, "\r" + ansi.CSI + "0" + ansi.EL)
			}

			// Advance spinner frame
			num_frames := len(spinners[i].frames.frames)
			if num_frames > 0 {
				spinners[i]._frame_idx = tick_count % num_frames
			}

			// Spinner frame
			spinner.to_writer(w, spinners[i])
			io.write_string(w, " ")

			// Label
			io.write_string(w, labels[i])
			io.write_string(w, "  ")

			// Progress bar
			progress.to_writer(w, bars[i])
			io.write_string(w, "\n")
		}

		tick_count += 1

		// Check if all complete
		all_done := true
		for i in 0 ..< NUM_BARS {
			if bars[i].current < bars[i].total {
				all_done = false
				break
			}
		}

		if all_done {
			// Reset for next loop
			reset_bars(&bars, &spinners, mode)
			tick_count = 0
			first_frame = true
		}

		time.sleep(80 * time.Millisecond)
	}

	// Clean exit: show cursor
	if mode == .Full {
		io.write_string(w, ansi.CSI + ansi.DECTCEM_SHOW)
		term.notify_cursor_visible()
	}
}
