#+feature using-stmt
package progress

import "../style"
import "../term"
import "core:io"
import "core:os"
import "core:terminal/ansi"
import "core:time"

Bar_Style :: struct {
	left_cap:  string,
	right_cap: string,
	fill:      string,
	empty:     string,
	head:      string,
}

Progress :: struct {
	total:           int,
	current:         int,
	width:           int,
	bar_style:       Bar_Style,
	message:         string,
	show_percentage: bool,
	show_count:      bool,
	show_elapsed:    bool,
	fill_style:      Maybe(style.Style),
	mode:            term.Render_Mode,
	_start_tick:     time.Tick,
	_started:        bool,
}

/* bar_block returns a block-style bar: [████░░░░] */
bar_block :: proc() -> Bar_Style {
	return Bar_Style {
		left_cap  = "[",
		right_cap = "]",
		fill      = "\u2588", // █
		empty     = "\u2591", // ░
		head      = "",
	}
}

/* bar_ascii returns an ASCII-style bar: [====>   ] */
bar_ascii :: proc() -> Bar_Style {
	return Bar_Style{left_cap = "[", right_cap = "]", fill = "=", empty = " ", head = ">"}
}

/* bar_thin returns a thin-line bar: │━━━───│ */
bar_thin :: proc() -> Bar_Style {
	return Bar_Style {
		left_cap  = "\u2502", // │
		right_cap = "\u2502", // │
		fill      = "\u2501", // ━
		empty     = "\u2500", // ─
		head      = "",
	}
}

/* make_progress creates a new progress bar with the given configuration.
	 mode auto-detects from stderr when not specified. */
make_progress :: proc(
	total: int,
	bar_style: Maybe(Bar_Style) = nil,
	width := 0,
	message := "",
	show_percentage := true,
	show_count := false,
	show_elapsed := false,
	mode: Maybe(term.Render_Mode) = nil,
) -> Progress {
	bs := bar_style.? or_else bar_block()
	return Progress {
		total = total,
		current = 0,
		width = width,
		bar_style = bs,
		message = message,
		show_percentage = show_percentage,
		show_count = show_count,
		show_elapsed = show_elapsed,
		fill_style = nil,
		mode = mode.? or_else term.detect_render_mode(os.stderr),
		_started = false,
	}
}

/* start records the start time and draws the initial bar to stderr.
	 In Plain mode, records time without drawing. */
start :: proc(p: ^Progress) {
	p._start_tick = time.tick_now()
	p._started = true
	if p.mode != .Plain {
		redraw(p)
	}
}

/* update sets the current value and redraws the bar. */
update :: proc(p: ^Progress, current: int) {
	p.current = min(current, p.total)
	if p.mode != .Plain {
		redraw(p)
	}
}

/* increment advances current by amount and redraws the bar. */
increment :: proc(p: ^Progress, amount := 1) {
	p.current = min(p.current + amount, p.total)
	if p.mode != .Plain {
		redraw(p)
	}
}

/* complete fills the bar to 100%, writes a final message, and appends a newline.
	 In Plain mode, writes without terminal control sequences. */
complete :: proc(p: ^Progress, final_message := "") {
	p.current = p.total
	w := os.stream_from_handle(os.stderr)

	if p.mode != .Plain {
		io.write_string(w, "\r")
		io.write_string(w, ansi.CSI + "0" + ansi.EL)
	}

	if final_message != "" {
		io.write_string(w, final_message)
	} else {
		to_writer(w, p^)
	}
	io.write_string(w, "\n")
}

@(private = "file")
redraw :: proc(p: ^Progress) {
	w := os.stream_from_handle(os.stderr)
	io.write_string(w, "\r")
	io.write_string(w, ansi.CSI + "0" + ansi.EL)
	to_writer(w, p^)
}
