#+feature global-context
package table

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
	fmt.register_user_formatter(type_info_of(Table).id, table_formatter)
}

/* to_writer renders a table to an io.Writer. */
to_writer :: proc(w: io.Writer, t: Table, n: ^int = nil, mode: term.Render_Mode = .Full) -> bool {
	if len(t.columns) == 0 {
		return true
	}

	// Plain mode strips borders entirely
	t := t
	if mode == .Plain {
		t.border = BORDER_NONE
	}

	widths := compute_column_widths(t)
	has_headers := has_header_content(t)

	// Top border
	if t.border.top {
		if !write_border_line(w, t, widths, .Top, n, mode) do return false
	}

	// Header row
	if has_headers {
		header_cells := make([]Cell, len(t.columns), context.temp_allocator)
		for col, i in t.columns {
			header_cells[i] = Cell {
				content = col.header,
			}
		}
		if !write_row(w, t, header_cells, widths, t.header_config.style, n, mode) do return false

		if t.header_config.separator && t.border.header_separator {
			if !write_border_line(w, t, widths, .Middle, n, mode) do return false
		}
	}

	// Data rows
	for row, row_idx in t.rows {
		if !write_row(w, t, row.cells[:], widths, row.style, n, mode) do return false

		if t.border.row_separator && row_idx < len(t.rows) - 1 {
			if !write_border_line(w, t, widths, .Middle, n, mode) do return false
		}
	}

	// Bottom border
	if t.border.bottom {
		if !write_border_line(w, t, widths, .Bottom, n, mode) do return false
	}

	return true
}

/*
to_str renders a table to an allocated string.
The caller owns the returned string and must free it regardless of the ok
return value (a failed render may produce partial output).

Inputs:
- t: The Table to render.
- allocator: Allocator for the resulting string.

Returns:
- string: The rendered table.
- bool: true if rendering succeeded.
*/
to_str :: proc(t: Table, mode: term.Render_Mode = .Full, allocator := context.allocator) -> (string, bool) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), t, mode = mode)
	return strings.to_string(sb), ok
}

/*
table_formatter is a custom fmt.User_Formatter for Table values.
Enables printing tables directly with fmt.println, fmt.aprintf, etc.
*/
@(private = "file")
table_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
	t := cast(^Table)arg.data

	switch verb {
	case 'v', 's':
		return to_writer(fi.writer, t^, &fi.n)
	case 'w':
		fi.ignore_user_formatters = true
		fmt.fmt_value(fi = fi, v = t^, verb = 'w')
		return true
	case:
		return false
	}
}

// --- Internal rendering procedures ---

@(private = "file")
write_str :: proc(w: io.Writer, s: string, n: ^int) -> bool {
	_, err := io.write_string(w, s, n)
	return err == .None
}

@(private = "file")
Border_Position :: enum {
	Top,
	Middle,
	Bottom,
}

@(private = "file")
write_border_line :: proc(
	w: io.Writer,
	t: Table,
	widths: []int,
	pos: Border_Position,
	n: ^int,
	mode: term.Render_Mode = .Full,
) -> bool {
	chars := t.border.chars

	// Calculate total inner width (content + padding + separator slots).
	inner_width := 0
	for col_idx := 0; col_idx < len(widths); col_idx += 1 {
		inner_width += widths[col_idx] + 2 * t.padding
		if col_idx < len(widths) - 1 {
			inner_width += text_display_width(chars.vertical) // separator slot
		}
	}

	// Title rendering: when title is set and pos is TOP, render as a single span.
	if t.title != nil && pos == .Top {
		if t.border.left {
			if !write_str(w, chars.top_left, n) do return false
		}

		title_w := display_width(t.title)
		// Format: ─ Title ─────────────╮
		// Need at least: 1 horizontal + space + title + space + 1 horizontal
		min_needed := 1 + 1 + title_w + 1 + 1

		if inner_width >= min_needed {
			if !write_str(w, chars.horizontal, n) do return false
			if !write_str(w, " ", n) do return false
			if !write_cell_content(w, t.title, cell_text(t.title), nil, n, mode) do return false
			if !write_str(w, " ", n) do return false
			remaining := inner_width - (1 + 1 + title_w + 1) // horizontal + space + title + space
			for _ in 0 ..< remaining {
				if !write_str(w, chars.horizontal, n) do return false
			}
		} else {
			// Not enough room for title, just fill with horizontal.
			for _ in 0 ..< inner_width {
				if !write_str(w, chars.horizontal, n) do return false
			}
		}

		if t.border.right {
			if !write_str(w, chars.top_right, n) do return false
		}

		if !write_str(w, "\n", n) do return false
		return true
	}

	// Standard border line rendering.
	if t.border.left {
		left := chars.top_left
		switch pos {
		case .Middle:
			left = chars.left_tee
		case .Bottom:
			left = chars.bottom_left
		case .Top: // default
		}
		if !write_str(w, left, n) do return false
	}

	for col_idx := 0; col_idx < len(widths); col_idx += 1 {
		total := widths[col_idx] + 2 * t.padding
		for _ in 0 ..< total {
			if !write_str(w, chars.horizontal, n) do return false
		}

		if col_idx < len(widths) - 1 {
			if t.hide_column_separator {
				if !write_str(w, chars.horizontal, n) do return false
			} else {
				tee := chars.top_tee
				switch pos {
				case .Middle:
					tee = chars.cross
				case .Bottom:
					tee = chars.bottom_tee
				case .Top: // default
				}
				if !write_str(w, tee, n) do return false
			}
		} else if t.border.right {
			right := chars.top_right
			switch pos {
			case .Middle:
				right = chars.right_tee
			case .Bottom:
				right = chars.bottom_right
			case .Top: // default
			}
			if !write_str(w, right, n) do return false
		}
	}

	if !write_str(w, "\n", n) do return false
	return true
}

@(private = "file")
write_row :: proc(
	w: io.Writer,
	t: Table,
	cells: []Cell,
	widths: []int,
	fallback_style: Maybe(style.Style),
	n: ^int,
	mode: term.Render_Mode,
) -> bool {
	if t.wrap {
		return write_row_wrapped(w, t, cells, widths, fallback_style, n, mode)
	}
	return write_row_truncated(w, t, cells, widths, fallback_style, n, mode)
}

@(private = "file")
write_row_truncated :: proc(
	w: io.Writer,
	t: Table,
	cells: []Cell,
	widths: []int,
	fallback_style: Maybe(style.Style),
	n: ^int,
	mode: term.Render_Mode,
) -> bool {
	num_cols := len(t.columns)

	if t.border.left {
		if !write_str(w, t.border.chars.vertical, n) do return false
	}

	for col_idx := 0; col_idx < num_cols; col_idx += 1 {
		col := t.columns[col_idx]

		if !write_padding(w, t.padding, n) do return false

		effective_width := widths[col_idx]

		// Get cell (pad with empty if fewer cells than columns)
		cell: Cell
		if col_idx < len(cells) {
			cell = cells[col_idx]
		}

		content := cell.content
		content_w: int

		// For Rich_Text, truncate across segments and compute width from the truncated result.
		truncated_rt: Rich_Text
		if rt, is_rt := content.(Rich_Text); is_rt {
			truncated_rt = truncate_rich_text(rt, effective_width)
			content_w = 0
			for seg in truncated_rt {
				content_w += text_display_width(seg.text)
			}
		} else {
			text := cell_text(content)
			text = truncate_text(text, effective_width)
			content_w = text_display_width(text)
			// Update content with truncated text for write_cell_content.
			switch c in content {
			case string:
				content = text
			case style.Styled_Text:
				content = style.Styled_Text{text = text, style = c.style}
			case Rich_Text:
				// handled above
			case:
				// nil
			}
		}

		// Resolve alignment: cell override > column default
		alignment := col.alignment
		if cell_align, has_align := cell.alignment.?; has_align {
			alignment = cell_align
		}

		left_pad, right_pad := compute_alignment_padding(content_w, effective_width, alignment)
		if !write_padding(w, left_pad, n) do return false

		if truncated_rt != nil {
			if !write_cell_content(w, Rich_Text(truncated_rt), "", fallback_style, n, mode) do return false
		} else {
			if !write_cell_content(w, content, cell_text(content), fallback_style, n, mode) do return false
		}

		if !write_padding(w, right_pad, n) do return false
		if !write_padding(w, t.padding, n) do return false

		// Column separator
		if col_idx < num_cols - 1 {
			if t.hide_column_separator {
				// Replace vertical separator with spaces of equal width.
				sep_w := text_display_width(t.border.chars.vertical)
				if !write_padding(w, sep_w, n) do return false
			} else {
				if !write_str(w, t.border.chars.vertical, n) do return false
			}
		} else if t.border.right {
			if !write_str(w, t.border.chars.vertical, n) do return false
		}
	}

	if !write_str(w, "\n", n) do return false
	return true
}

// Maximum columns supported by zero-alloc wrap rendering. Tables with more
// columns fall back to temp-allocated arrays.
@(private = "file")
MAX_WRAP_COLS :: 16

@(private = "file")
write_row_wrapped :: proc(
	w: io.Writer,
	t: Table,
	cells: []Cell,
	widths: []int,
	fallback_style: Maybe(style.Style),
	n: ^int,
	mode: term.Render_Mode,
) -> bool {
	num_cols := len(t.columns)

	// Stack-allocated arrays for zero-alloc wrapping (common case).
	line_counts_buf: [MAX_WRAP_COLS]int
	wraps_buf: [MAX_WRAP_COLS]bool

	line_counts := line_counts_buf[:num_cols] if num_cols <= MAX_WRAP_COLS else make([]int, num_cols, context.temp_allocator)
	wraps := wraps_buf[:num_cols] if num_cols <= MAX_WRAP_COLS else make([]bool, num_cols, context.temp_allocator)

	// Pass 1: Count wrapped lines per column.
	max_lines := 1
	for col_idx := 0; col_idx < num_cols; col_idx += 1 {
		ew := widths[col_idx]

		cell: Cell
		if col_idx < len(cells) {
			cell = cells[col_idx]
		}

		cw := display_width(cell.content)

		if cw <= ew || ew <= 0 || cell.content == nil {
			line_counts[col_idx] = 1
		} else if _, is_rt := cell.content.(Rich_Text); is_rt {
			line_counts[col_idx] = 1 // Rich_Text truncates, not wraps
		} else {
			count := 0
			it := term.word_wrap_iterator_make(cell_text(cell.content), ew)
			for _ in term.word_wrap_iterate(&it) {
				count += 1
			}
			line_counts[col_idx] = count
			wraps[col_idx] = count > 1
		}

		if line_counts[col_idx] > max_lines {
			max_lines = line_counts[col_idx]
		}
	}

	// Pass 2: Render each physical line using fresh iterators.
	iterators_buf: [MAX_WRAP_COLS]term.Word_Wrap_Iterator
	iterators := iterators_buf[:num_cols] if num_cols <= MAX_WRAP_COLS else make([]term.Word_Wrap_Iterator, num_cols, context.temp_allocator)

	for col_idx := 0; col_idx < num_cols; col_idx += 1 {
		if wraps[col_idx] {
			cell: Cell
			if col_idx < len(cells) {
				cell = cells[col_idx]
			}
			iterators[col_idx] = term.word_wrap_iterator_make(cell_text(cell.content), widths[col_idx])
		}
	}

	for line_idx := 0; line_idx < max_lines; line_idx += 1 {
		if t.border.left {
			if !write_str(w, t.border.chars.vertical, n) do return false
		}

		for col_idx := 0; col_idx < num_cols; col_idx += 1 {
			col := t.columns[col_idx]
			ew := widths[col_idx]

			if !write_padding(w, t.padding, n) do return false

			cell: Cell
			if col_idx < len(cells) {
				cell = cells[col_idx]
			}

			// Resolve alignment: cell override > column default.
			alignment := col.alignment
			if cell_align, has_align := cell.alignment.?; has_align {
				alignment = cell_align
			}

			if line_idx >= line_counts[col_idx] {
				// Blank continuation line for this column.
				if !write_padding(w, ew, n) do return false
			} else if wraps[col_idx] {
				// Multi-line cell: get next line from iterator.
				line_text, _ := term.word_wrap_iterate(&iterators[col_idx])
				line_w := text_display_width(line_text)

				// Reconstruct Cell_Content preserving the original style.
				line_content: Cell_Content
				switch c in cell.content {
				case style.Styled_Text:
					line_content = style.Styled_Text{text = line_text, style = c.style}
				case string:
					line_content = line_text
				case Rich_Text:
					// Rich_Text doesn't wrap — shouldn't reach here.
					line_content = line_text
				case:
					line_content = line_text
				}

				left_pad, right_pad := compute_alignment_padding(line_w, ew, alignment)
				if !write_padding(w, left_pad, n) do return false
				if !write_cell_content(w, line_content, line_text, fallback_style, n, mode) do return false
				if !write_padding(w, right_pad, n) do return false
			} else if line_idx == 0 {
				// Single-line cell: render content directly (with Rich_Text truncation).
				content := cell.content
				cw := display_width(content)

				if rt, is_rt := content.(Rich_Text); is_rt && cw > ew && ew > 0 {
					truncated := truncate_rich_text(rt, ew)
					tw := 0
					for seg in truncated {
						tw += text_display_width(seg.text)
					}
					left_pad, right_pad := compute_alignment_padding(tw, ew, alignment)
					if !write_padding(w, left_pad, n) do return false
					if !write_cell_content(w, Rich_Text(truncated), "", fallback_style, n, mode) do return false
					if !write_padding(w, right_pad, n) do return false
				} else {
					left_pad, right_pad := compute_alignment_padding(cw, ew, alignment)
					if !write_padding(w, left_pad, n) do return false
					if !write_cell_content(w, content, cell_text(content), fallback_style, n, mode) do return false
					if !write_padding(w, right_pad, n) do return false
				}
			} else {
				// Single-line cell on continuation line — blank.
				if !write_padding(w, ew, n) do return false
			}

			if !write_padding(w, t.padding, n) do return false

			// Column separator.
			if col_idx < num_cols - 1 {
				if t.hide_column_separator {
					sep_w := text_display_width(t.border.chars.vertical)
					if !write_padding(w, sep_w, n) do return false
				} else {
					if !write_str(w, t.border.chars.vertical, n) do return false
				}
			} else if t.border.right {
				if !write_str(w, t.border.chars.vertical, n) do return false
			}
		}

		if !write_str(w, "\n", n) do return false
	}

	return true
}

@(private = "file")
write_cell_content :: proc(
	w: io.Writer,
	content: Cell_Content,
	text: string,
	fallback_style: Maybe(style.Style),
	n: ^int,
	mode: term.Render_Mode,
) -> bool {
	switch c in content {
	case style.Styled_Text:
		st := style.Styled_Text {
			text  = text,
			style = c.style,
		}
		return style.to_writer(w, st, n, mode)
	case Rich_Text:
		for seg in c {
			if !style.to_writer(w, seg, n, mode) do return false
		}
		return true
	case string:
		if s, has_style := fallback_style.?; has_style {
			st := style.Styled_Text {
				text  = text,
				style = s,
			}
			return style.to_writer(w, st, n, mode)
		}
		return write_str(w, text, n)
	case:
		return true
	}
}

// truncate_rich_text truncates Rich_Text to fit within max_width, preserving per-segment styles.
// Returns a temp-allocated slice — valid until the temp arena is freed.
@(private = "file")
truncate_rich_text :: proc(rt: Rich_Text, max_width: int) -> Rich_Text {
	if max_width <= 0 || len(rt) == 0 do return rt

	total := 0
	for seg in rt {
		total += text_display_width(seg.text)
	}
	if total <= max_width do return rt

	result := make([]style.Styled_Text, len(rt), context.temp_allocator)
	remaining := max_width
	count := 0

	for seg in rt {
		seg_w := text_display_width(seg.text)
		if seg_w <= remaining {
			result[count] = seg
			remaining -= seg_w
			count += 1
		} else {
			if remaining > 0 {
				result[count] = style.Styled_Text {
					text  = truncate_text(seg.text, remaining),
					style = seg.style,
				}
				count += 1
			}
			break
		}
	}

	return Rich_Text(result[:count])
}

@(private = "file")
compute_alignment_padding :: proc(text_w: int, col_w: int, alignment: Alignment) -> (left: int, right: int) {
	space := col_w - text_w
	if space <= 0 {
		return 0, 0
	}

	switch alignment {
	case .Left:
		return 0, space
	case .Right:
		return space, 0
	case .Center:
		left = space / 2
		right = space - left
		return
	}
	return 0, space
}

@(private = "file")
write_padding :: proc(w: io.Writer, count: int, n: ^int) -> bool {
	for _ in 0 ..< count {
		if !write_str(w, " ", n) do return false
	}
	return true
}

@(private = "file")
has_header_content :: proc(t: Table) -> bool {
	for col in t.columns {
		if cell_text(col.header) != "" {
			return true
		}
	}
	return false
}
