#+feature using-stmt
#+feature global-context
package progress

import "core:fmt"
import "core:io"
import "core:strings"
import "core:time"
import "core:unicode/utf8"
import "../style"
import "../term"

@(private="file")
@(init)
init_formatter :: proc() {
  if fmt._user_formatters == nil {
    fmt.set_user_formatters(new(map[typeid]fmt.User_Formatter))
  }
  fmt.register_user_formatter(type_info_of(Progress).id, Progress_Formatter)
}

/* to_writer renders the progress bar to an io.Writer.
   Output format: Message [████░░░░] 40% (80/200) 0:12
   No terminal control sequences — testable with a string builder. */
to_writer :: proc(w: io.Writer, p: Progress, n: ^int = nil) -> bool {
  // Message prefix
  if p.message != "" {
    if !_write(w, p.message, n) do return false
    if !_write(w, " ", n) do return false
  }

  // Compute bar width
  bar_width := p.width
  if bar_width == 0 {
    bar_width = _compute_auto_width(p)
  }
  if bar_width < 1 {
    bar_width = 1
  }

  // Compute fill/empty counts
  ratio: f64 = 0
  if p.total > 0 {
    ratio = f64(p.current) / f64(p.total)
  }
  if ratio > 1 do ratio = 1
  if ratio < 0 do ratio = 0

  filled := int(ratio * f64(bar_width))
  if filled > bar_width do filled = bar_width

  has_head := p.bar_style.head != "" && filled < bar_width && filled > 0
  empty_count := bar_width - filled
  if has_head {
    empty_count -= 1
  }

  // Render bar
  if !_write(w, p.bar_style.left_cap, n) do return false

  // Apply fill style if set
  if s, has_style := p.fill_style.?; has_style {
    // Build the fill string in a stack buffer to avoid allocation
    fill_buf: [512]u8
    fill_len := 0
    fill_str := p.bar_style.fill
    for _ in 0..<filled {
      if fill_len + len(fill_str) > len(fill_buf) do break
      copy(fill_buf[fill_len:], fill_str)
      fill_len += len(fill_str)
    }
    st := style.Styled_Text{text = string(fill_buf[:fill_len]), style = s}
    if !style.to_writer(w, st, n) do return false
  } else {
    for _ in 0..<filled {
      if !_write(w, p.bar_style.fill, n) do return false
    }
  }

  if has_head {
    if !_write(w, p.bar_style.head, n) do return false
  }

  for _ in 0..<empty_count {
    if !_write(w, p.bar_style.empty, n) do return false
  }

  if !_write(w, p.bar_style.right_cap, n) do return false

  // Percentage
  if p.show_percentage {
    pct := int(ratio * 100)
    buf: [8]u8
    pct_str := _itoa(buf[:], pct)
    if !_write(w, " ", n) do return false
    if !_write(w, pct_str, n) do return false
    if !_write(w, "%", n) do return false
  }

  // Count
  if p.show_count {
    cur_buf: [16]u8
    tot_buf: [16]u8
    if !_write(w, " (", n) do return false
    if !_write(w, _itoa(cur_buf[:], p.current), n) do return false
    if !_write(w, "/", n) do return false
    if !_write(w, _itoa(tot_buf[:], p.total), n) do return false
    if !_write(w, ")", n) do return false
  }

  // Elapsed time
  if p.show_elapsed && p._started {
    elapsed := time.tick_since(p._start_tick)
    total_secs := int(time.duration_seconds(elapsed))
    mins := total_secs / 60
    secs := total_secs % 60
    min_buf: [8]u8
    sec_buf: [8]u8
    if !_write(w, " ", n) do return false
    if !_write(w, _itoa(min_buf[:], mins), n) do return false
    if !_write(w, ":", n) do return false
    if secs < 10 {
      if !_write(w, "0", n) do return false
    }
    if !_write(w, _itoa(sec_buf[:], secs), n) do return false
  }

  return true
}

/* to_str renders the progress bar to an allocated string. */
to_str :: proc(p: Progress, allocator := context.allocator) -> (string, bool) {
  sb := strings.builder_make(allocator = allocator)
  ok := to_writer(strings.to_writer(&sb), p)
  if !ok {
    strings.builder_destroy(&sb)
    return "", false
  }
  return strings.to_string(sb), true
}

/* Progress_Formatter is a custom fmt formatter for Progress values. */
Progress_Formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
  p := cast(^Progress)arg.data

  switch verb {
  case 'v', 's':
    return to_writer(fi.writer, p^, &fi.n)
  case 'w':
    fi.ignore_user_formatters = true
    fmt.fmt_value(fi = fi, v = p^, verb = 'w')
    return true
  case:
    return false
  }
}

// --- Internal helpers ---

@(private="file")
_write :: proc(w: io.Writer, s: string, n: ^int) -> bool {
  _, err := io.write_string(w, s, n)
  return err == .None
}

/* _itoa converts a non-negative integer to a string in the provided buffer. */
@(private="file")
_itoa :: proc(buf: []u8, val: int) -> string {
  v := val
  if v < 0 do v = 0
  if v == 0 {
    buf[len(buf)-1] = '0'
    return string(buf[len(buf)-1:])
  }
  i := len(buf)
  for v > 0 {
    i -= 1
    buf[i] = u8('0' + v % 10)
    v /= 10
  }
  return string(buf[i:])
}

/* _compute_auto_width computes bar width based on terminal width minus overhead. */
@(private="file")
_compute_auto_width :: proc(p: Progress) -> int {
  tw, ok := term.terminal_width()
  if !ok {
    tw = 80
  }

  overhead := 0

  // Message + space (use rune count for display width)
  if p.message != "" {
    overhead += utf8.rune_count_in_string(p.message) + 1
  }

  // Caps (rune count for display width)
  overhead += utf8.rune_count_in_string(p.bar_style.left_cap) + utf8.rune_count_in_string(p.bar_style.right_cap)

  // Percentage: " 100%"
  if p.show_percentage {
    overhead += 5
  }

  // Count: " (XXXXX/XXXXX)" — estimate digits from total
  if p.show_count {
    digits := _digit_count(p.total)
    overhead += 4 + digits * 2 // " (" + digits + "/" + digits + ")"
  }

  // Elapsed: " MM:SS"
  if p.show_elapsed {
    overhead += 6
  }

  bar_width := tw - overhead
  if bar_width < 5 {
    bar_width = 5
  }
  return bar_width
}

@(private="file")
_digit_count :: proc(v: int) -> int {
  if v <= 0 do return 1
  count := 0
  n := v
  for n > 0 {
    count += 1
    n /= 10
  }
  return count
}
