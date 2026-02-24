#+feature global-context
package panel

import "../style"
import "../term"
import "core:fmt"
import "core:io"
import "core:strings"

@(private = "file")
_formatter_map: map[typeid]fmt.User_Formatter

@(private = "file")
@(init)
init_formatter :: proc() {
	if fmt._user_formatters == nil {
		fmt._user_formatters = &_formatter_map
	}
	fmt.register_user_formatter(type_info_of(Panel).id, panel_formatter)
}

/* to_writer renders a panel to an io.Writer.
   Content strings are written verbatim; callers passing untrusted input
   should sanitize with `term.strip_ansi`. */
to_writer :: proc(w: io.Writer, p: Panel, n: ^int = nil, mode: term.Render_Mode = .Full) -> bool {
	p := p
	if mode == .Plain {
		p.border = BORDER_NONE
		p.padding = 0
	}

	padding := max(p.padding, 0)
	content_width := compute_content_width(p, padding)

	// Top border
	if p.border.top {
		if !write_top_border(w, p, content_width, padding, n, mode) do return false
	}

	// Content lines
	for line in p.lines {
		if !write_content_line(w, p, line, content_width, padding, n, mode) do return false
	}

	// Empty panel with borders but no lines — render one empty line
	if len(p.lines) == 0 && (p.border.left || p.border.right) {
		if !write_content_line(w, p, nil, content_width, padding, n, mode) do return false
	}

	// Bottom border
	if p.border.bottom {
		if !write_bottom_border(w, p, content_width, padding, n) do return false
	}

	return true
}

/*
to_str renders a panel to an allocated string.
The caller owns the returned string and must free it regardless of the ok
return value (a failed render may produce partial output).
*/
to_str :: proc(p: Panel, mode: term.Render_Mode = .Full, allocator := context.allocator) -> (string, bool) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), p, mode = mode)
	return strings.to_string(sb), ok
}

@(private = "file")
panel_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
	p := cast(^Panel)arg.data

	switch verb {
	case 'v', 's':
		return to_writer(fi.writer, p^, &fi.n, term.get_render_mode())
	case 'w':
		fi.ignore_user_formatters = true
		fmt.fmt_value(fi = fi, v = p^, verb = 'w')
		return true
	case:
		return false
	}
}

// --- Internal rendering procedures ---

@(private = "file")
compute_content_width :: proc(p: Panel, padding: int) -> int {
	if p.width > 0 {
		// Fixed width: subtract border + padding overhead
		overhead := 2 * padding
		if p.border.left do overhead += 1 // vertical char is 1 display col
		if p.border.right do overhead += 1
		return max(p.width - overhead, 0)
	}

	// Auto-size: scan all lines + title for max display width.
	// Title rendering needs title_w + 4 inner columns (horizontal + space + title + space + horizontal),
	// so content_width must be at least title_w + 4 - 2*padding to guarantee the title fits.
	w := 0
	for line in p.lines {
		lw := line_display_width(line)
		if lw > w do w = lw
	}
	// Title is only rendered in the top border, so only reserve space when it's enabled.
	if p.border.top {
		tw := line_display_width(p.title)
		if tw > 0 {
			title_needed := tw + 4 - 2 * padding
			if title_needed > w do w = title_needed
		}
	}
	return max(w, 0)
}

@(private = "file")
write_top_border :: proc(
	w: io.Writer,
	p: Panel,
	content_width: int,
	padding: int,
	n: ^int,
	mode: term.Render_Mode,
) -> bool {
	chars := p.border.chars
	inner_width := content_width + 2 * padding

	if p.border.left {
		if !write_str(w, chars.top_left, n) do return false
	}

	// Title in top border: ─ Title ──────╮
	title_w := line_display_width(p.title)
	if title_w > 0 {
		// Need at least: horizontal + space + 1_char + space + horizontal = 5
		MIN_TITLE_DECORATION :: 5
		if inner_width >= MIN_TITLE_DECORATION {
			available_for_title := inner_width - 4 // subtract 2 horizontals + 2 spaces
			truncated_title: string
			actual_title_w := title_w
			if title_w > available_for_title {
				truncated_title = term.truncate(line_text(p.title), available_for_title)
				actual_title_w = term.display_width(truncated_title)
			}
			if !write_str(w, chars.horizontal, n) do return false
			if !write_str(w, " ", n) do return false
			if !write_line_content(w, p.title, truncated_title, n, mode) do return false
			if !write_str(w, " ", n) do return false
			remaining := inner_width - (1 + 1 + actual_title_w + 1)
			if !write_repeated(w, chars.horizontal, remaining, n) do return false
		} else {
			if !write_repeated(w, chars.horizontal, inner_width, n) do return false
		}
	} else {
		if !write_repeated(w, chars.horizontal, inner_width, n) do return false
	}

	if p.border.right {
		if !write_str(w, chars.top_right, n) do return false
	}

	if !write_str(w, "\n", n) do return false
	return true
}

@(private = "file")
write_bottom_border :: proc(
	w: io.Writer,
	p: Panel,
	content_width: int,
	padding: int,
	n: ^int,
) -> bool {
	chars := p.border.chars
	inner_width := content_width + 2 * padding

	if p.border.left {
		if !write_str(w, chars.bottom_left, n) do return false
	}

	if !write_repeated(w, chars.horizontal, inner_width, n) do return false

	if p.border.right {
		if !write_str(w, chars.bottom_right, n) do return false
	}

	if !write_str(w, "\n", n) do return false
	return true
}

@(private = "file")
write_content_line :: proc(
	w: io.Writer,
	p: Panel,
	line: Line,
	content_width: int,
	padding: int,
	n: ^int,
	mode: term.Render_Mode,
) -> bool {
	if p.border.left {
		if !write_str(w, p.border.chars.vertical, n) do return false
	}

	if !write_padding(w, padding, n) do return false

	// When content_width <= 0 (fixed width too small for overhead), skip content entirely.
	if content_width > 0 {
		// Write content, truncating if wider than content_width
		lw := line_display_width(line)
		if lw > content_width {
			truncated := term.truncate(line_text(line), content_width)
			lw = term.display_width(truncated)
			if !write_line_content(w, line, truncated, n, mode) do return false
		} else {
			if !write_line_content(w, line, "", n, mode) do return false
		}
		if !write_padding(w, content_width - lw, n) do return false
	}

	if !write_padding(w, padding, n) do return false

	if p.border.right {
		if !write_str(w, p.border.chars.vertical, n) do return false
	}

	if !write_str(w, "\n", n) do return false
	return true
}

// write_line_content writes a Line's content. When truncated_text is non-empty,
// it replaces the line's text (preserving style for Styled_Text lines).
@(private = "file")
write_line_content :: proc(w: io.Writer, line: Line, truncated_text: string, n: ^int, mode: term.Render_Mode) -> bool {
	switch l in line {
	case style.Styled_Text:
		st := l
		if truncated_text != "" do st.text = truncated_text
		return style.to_writer(w, st, n, mode)
	case string:
		text := truncated_text if truncated_text != "" else l
		return write_str(w, text, n)
	case:
		return true // nil
	}
}

@(private = "file")
line_text :: proc(line: Line) -> string {
	switch l in line {
	case style.Styled_Text:
		return l.text
	case string:
		return l
	case:
		return ""
	}
}

@(private = "file")
line_display_width :: proc(line: Line) -> int {
	return term.display_width(line_text(line))
}

@(private = "file")
write_str :: proc(w: io.Writer, s: string, n: ^int) -> bool {
	_, err := io.write_string(w, s, n)
	return err == .None
}

// write_repeated writes string s repeated count times using a pre-filled stack buffer.
@(private = "file")
write_repeated :: proc(w: io.Writer, s: string, count: int, n: ^int) -> bool {
	if count <= 0 do return true
	s_bytes := transmute([]u8)s
	s_len := len(s_bytes)
	if s_len == 0 do return true

	buf: [512]u8
	total_needed := count * s_len
	fill_limit := min(total_needed, len(buf))
	filled := 0
	for filled + s_len <= fill_limit {
		copy(buf[filled:filled + s_len], s_bytes)
		filled += s_len
	}
	if filled == 0 {
		for _ in 0 ..< count {
			if !write_str(w, s, n) do return false
		}
		return true
	}

	remaining := count
	for remaining > 0 {
		copies_in_buf := filled / s_len
		batch := min(remaining, copies_in_buf)
		chunk := batch * s_len
		if !write_str(w, string(buf[:chunk]), n) do return false
		remaining -= batch
	}
	return true
}

@(private = "file")
PADDING_BUF :: "                                                                                                                                "

@(private = "file")
write_padding :: proc(w: io.Writer, count: int, n: ^int) -> bool {
	buf := PADDING_BUF
	remaining := count
	for remaining > 0 {
		chunk := min(remaining, len(buf))
		if !write_str(w, buf[:chunk], n) do return false
		remaining -= chunk
	}
	return true
}
