#+feature using-stmt
#+feature global-context
package progress

import "../style"
import "../term"
import "core:fmt"
import "core:io"
import "core:strings"
import "core:time"

@(private = "file")
_formatter_map: map[typeid]fmt.User_Formatter

@(private = "file")
@(init)
init_formatter :: proc() {
	if fmt._user_formatters == nil {
		fmt._user_formatters = &_formatter_map
	}
	fmt.register_user_formatter(type_info_of(Progress).id, progress_formatter)
}

/* to_writer renders the progress bar to an io.Writer.
   Output format: Message [████░░░░] 40% (80/200) 0:12
   The message string is written verbatim; callers passing untrusted input should
   sanitize with `term.strip_ansi`. The fill buffer is limited to 512 bytes.
   No terminal control sequences — testable with a string builder. */
to_writer :: proc(w: io.Writer, p: Progress, n: ^int = nil) -> bool {
	// Message prefix
	if p.message != "" {
		write_str(w, p.message, n) or_return
		write_str(w, " ", n) or_return
	}

	// Compute bar width
	bar_width := p.width
	if bar_width == 0 {
		bar_width = compute_auto_width(p)
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
	write_str(w, p.bar_style.left_cap, n) or_return

	// Apply fill style if set
	if s, has_style := p.fill_style.?; has_style {
		// Build the fill string in a stack buffer to avoid allocation
		fill_buf: [512]u8
		fill_len := 0
		fill_str := p.bar_style.fill
		for _ in 0 ..< filled {
			if fill_len + len(fill_str) > len(fill_buf) do break
			copy(fill_buf[fill_len:], fill_str)
			fill_len += len(fill_str)
		}
		st := style.Styled_Text {
			text  = string(fill_buf[:fill_len]),
			style = s,
		}
		style.to_writer(w, st, n, p.mode) or_return
	} else {
		for _ in 0 ..< filled {
			write_str(w, p.bar_style.fill, n) or_return
		}
	}

	if has_head {
		write_str(w, p.bar_style.head, n) or_return
	}

	for _ in 0 ..< empty_count {
		write_str(w, p.bar_style.empty, n) or_return
	}

	write_str(w, p.bar_style.right_cap, n) or_return

	// Percentage
	if p.show_percentage {
		pct := int(ratio * 100)
		buf: [8]u8
		pct_str := itoa(buf[:], pct)
		write_str(w, " ", n) or_return
		write_str(w, pct_str, n) or_return
		write_str(w, "%", n) or_return
	}

	// Count
	if p.show_count {
		cur_buf: [16]u8
		tot_buf: [16]u8
		write_str(w, " (", n) or_return
		write_str(w, itoa(cur_buf[:], p.current), n) or_return
		write_str(w, "/", n) or_return
		write_str(w, itoa(tot_buf[:], p.total), n) or_return
		write_str(w, ")", n) or_return
	}

	// Elapsed time
	if p.show_elapsed && p._started {
		elapsed := time.tick_since(p._start_tick)
		total_secs := int(time.duration_seconds(elapsed))
		mins := total_secs / 60
		secs := total_secs % 60
		min_buf: [8]u8
		sec_buf: [8]u8
		write_str(w, " ", n) or_return
		write_str(w, itoa(min_buf[:], mins), n) or_return
		write_str(w, ":", n) or_return
		if secs < 10 {
			write_str(w, "0", n) or_return
		}
		write_str(w, itoa(sec_buf[:], secs), n) or_return
	}

	return true
}

/*
to_str renders the progress bar to an allocated string.
The caller owns the returned string and must free it regardless of the ok
return value (a failed render may produce partial output).

Inputs:
- p: The Progress to render.
- allocator: Allocator for the resulting string.

Returns:
- string: The rendered progress bar.
- bool: true if rendering succeeded.
*/
to_str :: proc(p: Progress, allocator := context.allocator) -> (string, bool) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), p)
	return strings.to_string(sb), ok
}

/*
progress_formatter is a custom fmt.User_Formatter for Progress values.
Enables printing progress bars directly with fmt.println, fmt.aprintf, etc.
*/
@(private = "file")
progress_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
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

@(private = "file")
write_str :: proc(w: io.Writer, s: string, n: ^int) -> bool {
	_, err := io.write_string(w, s, n)
	return err == .None
}

@(private = "file")
itoa :: proc(buf: []u8, val: int) -> string {
	v := val
	if v < 0 do v = 0
	if v == 0 {
		buf[len(buf) - 1] = '0'
		return string(buf[len(buf) - 1:])
	}
	i := len(buf)
	for v > 0 {
		i -= 1
		buf[i] = u8('0' + v % 10)
		v /= 10
	}
	return string(buf[i:])
}

@(private = "file")
compute_auto_width :: proc(p: Progress) -> int {
	tw, ok := term.terminal_width()
	if !ok {
		tw = 80
	}

	overhead := 0

	// Message + space
	if p.message != "" {
		overhead += term.display_width(p.message) + 1
	}

	// Caps
	overhead += term.display_width(p.bar_style.left_cap) + term.display_width(p.bar_style.right_cap)

	// Percentage: " 100%"
	if p.show_percentage {
		overhead += 5
	}

	// Count: " (XXXXX/XXXXX)" — estimate digits from total
	if p.show_count {
		digits := digit_count(p.total)
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

@(private = "file")
digit_count :: proc(v: int) -> int {
	if v <= 0 do return 1
	count := 0
	n := v
	for n > 0 {
		count += 1
		n /= 10
	}
	return count
}
