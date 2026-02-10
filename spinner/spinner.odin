#+feature using-stmt
package spinner

import "core:io"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"
import "core:terminal/ansi"
import "../style"

Spinner_Frames :: struct {
  frames:   []string,
  interval: time.Duration,
}

Spinner :: struct {
  frames:      Spinner_Frames,
  message:     string,
  text_style:  Maybe(style.Style),
  _mutex:      sync.Mutex,           // guards message and _frame_idx
  _stop:       b32,                  // atomic stop flag
  _thread:     ^thread.Thread,
  _frame_idx:  int,
  _running:    bool,
}

/* spinner_dots returns the braille dot spinner frames (80ms). */
spinner_dots :: proc() -> Spinner_Frames {
  @(static) frames := [?]string{
    "\u280B", // ⠋
    "\u2819", // ⠙
    "\u2839", // ⠹
    "\u2838", // ⠸
    "\u283C", // ⠼
    "\u2834", // ⠴
    "\u2826", // ⠦
    "\u2827", // ⠧
    "\u2807", // ⠇
    "\u280F", // ⠏
  }
  return Spinner_Frames{
    frames   = frames[:],
    interval = 80 * time.Millisecond,
  }
}

/* spinner_line returns the line spinner frames (130ms). */
spinner_line :: proc() -> Spinner_Frames {
  @(static) frames := [?]string{"|", "/", "-", "\\"}
  return Spinner_Frames{
    frames   = frames[:],
    interval = 130 * time.Millisecond,
  }
}

/* spinner_circle returns the circle spinner frames (120ms). */
spinner_circle :: proc() -> Spinner_Frames {
  @(static) frames := [?]string{
    "\u25D0", // ◐
    "\u25D3", // ◓
    "\u25D1", // ◑
    "\u25D2", // ◒
  }
  return Spinner_Frames{
    frames   = frames[:],
    interval = 120 * time.Millisecond,
  }
}

/* make_spinner creates a new spinner with the given configuration. */
make_spinner :: proc(
  frames: Maybe(Spinner_Frames) = nil,
  message := "",
  text_style: Maybe(style.Style) = nil,
) -> Spinner {
  f := frames.? or_else spinner_dots()
  return Spinner{
    frames     = f,
    message    = message,
    text_style = text_style,
    _stop      = false,
    _thread    = nil,
    _frame_idx = 0,
    _running   = false,
  }
}

/* start hides the cursor and spawns the animation thread. */
start :: proc(s: ^Spinner) {
  w := os.stream_from_handle(os.stderr)
  io.write_string(w, ansi.CSI + ansi.DECTCEM_HIDE)

  sync.atomic_store_explicit(&s._stop, false, .Release)
  s._frame_idx = 0
  s._running = true

  t := thread.create(_spinner_thread_proc)
  t.data = rawptr(s)
  s._thread = t
  thread.start(t)
}

/* stop signals the thread to stop, joins it, clears the line, shows the cursor,
   and writes a final message with newline. */
stop :: proc(s: ^Spinner, final_message := "") {
  if !s._running do return

  sync.atomic_store_explicit(&s._stop, true, .Release)

  if s._thread != nil {
    thread.join(s._thread)
    thread.destroy(s._thread)
    s._thread = nil
  }

  s._running = false

  w := os.stream_from_handle(os.stderr)
  io.write_string(w, "\r")
  io.write_string(w, ansi.CSI + "0" + ansi.EL)

  if final_message != "" {
    io.write_string(w, final_message)
  }

  io.write_string(w, ansi.CSI + ansi.DECTCEM_SHOW)
  io.write_string(w, "\n")
}

/* set_message updates the spinner message in a thread-safe manner. */
set_message :: proc(s: ^Spinner, message: string) {
  sync.mutex_lock(&s._mutex)
  s.message = message
  sync.mutex_unlock(&s._mutex)
}

@(private="file")
_spinner_thread_proc :: proc(t: ^thread.Thread) {
  s := cast(^Spinner)t.data
  w := os.stream_from_handle(os.stderr)
  num_frames := len(s.frames.frames)
  if num_frames == 0 do return

  for !sync.atomic_load_explicit(&s._stop, .Acquire) {
    io.write_string(w, "\r")
    io.write_string(w, ansi.CSI + "0" + ansi.EL)

    // Snapshot message and frame_idx under lock, then render
    sync.mutex_lock(&s._mutex)
    snap := s^
    snap._frame_idx = s._frame_idx
    s._frame_idx = (s._frame_idx + 1) % num_frames
    sync.mutex_unlock(&s._mutex)

    to_writer(w, snap)

    time.sleep(s.frames.interval)
  }
}
