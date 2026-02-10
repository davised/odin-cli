#+feature using-stmt
package progress

import "core:io"
import "core:os"
import "core:time"
import "core:terminal/ansi"
import "../style"
import "../term"

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
  _start_tick:     time.Tick,
  _started:        bool,
}

/* bar_block returns a block-style bar: [████░░░░] */
bar_block :: proc() -> Bar_Style {
  return Bar_Style{
    left_cap  = "[",
    right_cap = "]",
    fill      = "\u2588", // █
    empty     = "\u2591", // ░
    head      = "",
  }
}

/* bar_ascii returns an ASCII-style bar: [====>   ] */
bar_ascii :: proc() -> Bar_Style {
  return Bar_Style{
    left_cap  = "[",
    right_cap = "]",
    fill      = "=",
    empty     = " ",
    head      = ">",
  }
}

/* bar_thin returns a thin-line bar: │━━━───│ */
bar_thin :: proc() -> Bar_Style {
  return Bar_Style{
    left_cap  = "\u2502", // │
    right_cap = "\u2502", // │
    fill      = "\u2501", // ━
    empty     = "\u2500", // ─
    head      = "",
  }
}

/* make_progress creates a new progress bar with the given configuration. */
make_progress :: proc(
  total: int,
  bar_style: Maybe(Bar_Style) = nil,
  width := 0,
  message := "",
  show_percentage := true,
  show_count := false,
  show_elapsed := false,
) -> Progress {
  bs := bar_style.? or_else bar_block()
  return Progress{
    total           = total,
    current         = 0,
    width           = width,
    bar_style       = bs,
    message         = message,
    show_percentage = show_percentage,
    show_count      = show_count,
    show_elapsed    = show_elapsed,
    fill_style      = nil,
    _started        = false,
  }
}

/* start records the start time and draws the initial bar to stderr. */
start :: proc(p: ^Progress) {
  p._start_tick = time.tick_now()
  p._started = true
  _redraw(p)
}

/* update sets the current value and redraws the bar. */
update :: proc(p: ^Progress, current: int) {
  p.current = min(current, p.total)
  _redraw(p)
}

/* increment advances current by amount and redraws the bar. */
increment :: proc(p: ^Progress, amount := 1) {
  p.current = min(p.current + amount, p.total)
  _redraw(p)
}

/* complete fills the bar to 100%, writes a final message, and appends a newline. */
complete :: proc(p: ^Progress, final_message := "") {
  p.current = p.total
  w := os.stream_from_handle(os.stderr)
  io.write_string(w, "\r")
  io.write_string(w, ansi.CSI + "0" + ansi.EL)

  if final_message != "" {
    io.write_string(w, final_message)
  } else {
    to_writer(w, p^)
  }
  io.write_string(w, "\n")
}

@(private="file")
_redraw :: proc(p: ^Progress) {
  w := os.stream_from_handle(os.stderr)
  io.write_string(w, "\r")
  io.write_string(w, ansi.CSI + "0" + ansi.EL)
  to_writer(w, p^)
}
