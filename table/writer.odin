#+feature global-context
package table

import "core:fmt"
import "core:io"
import "core:strings"
import "../style"

@(private="file")
@(init)
init_formatter :: proc() {
  // style's @(init) runs first (dependency ordering) and creates the map
  fmt.register_user_formatter(type_info_of(Table).id, Table_Formatter)
}

/* to_writer renders a table to an io.Writer. */
to_writer :: proc(w: io.Writer, t: Table, n: ^int = nil) -> bool {
  if len(t.columns) == 0 {
    return true
  }

  widths := compute_column_widths(t)
  has_headers := _has_headers(t)

  // Top border
  if t.border.top {
    if !write_border_line(w, t, widths, .TOP, n) do return false
  }

  // Header row
  if has_headers {
    header_cells := make([]Cell, len(t.columns), context.temp_allocator)
    for col, i in t.columns {
      header_cells[i] = Cell{content = col.header}
    }
    if !write_row(w, t, header_cells, widths, t.header_config.style, n) do return false

    if t.header_config.separator && t.border.header_separator {
      if !write_border_line(w, t, widths, .MIDDLE, n) do return false
    }
  }

  // Data rows
  for row, row_idx in t.rows {
    if !write_row(w, t, row.cells[:], widths, row.style, n) do return false

    if t.border.row_separator && row_idx < len(t.rows) - 1 {
      if !write_border_line(w, t, widths, .MIDDLE, n) do return false
    }
  }

  // Bottom border
  if t.border.bottom {
    if !write_border_line(w, t, widths, .BOTTOM, n) do return false
  }

  return true
}

/* to_str renders a table to an allocated string. */
to_str :: proc(t: Table, allocator := context.allocator) -> (string, bool) {
  sb := strings.builder_make(allocator = allocator)
  ok := to_writer(strings.to_writer(&sb), t)
  if !ok {
    strings.builder_destroy(&sb)
    return "", false
  }
  return strings.to_string(sb), true
}

/* Table_Formatter is a custom fmt formatter for Table values. */
Table_Formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
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

@(private="file")
write_str :: proc(w: io.Writer, s: string, n: ^int) -> bool {
  _, err := io.write_string(w, s, n)
  return err == .None
}

@(private="file")
Border_Position :: enum {
  TOP,
  MIDDLE,
  BOTTOM,
}

@(private="file")
write_border_line :: proc(w: io.Writer, t: Table, widths: []int, pos: Border_Position, n: ^int) -> bool {
  chars := t.border.chars

  if t.border.left {
    left := chars.top_left
    switch pos {
    case .MIDDLE: left = chars.left_tee
    case .BOTTOM: left = chars.bottom_left
    case .TOP:    // default
    }
    if !write_str(w, left, n) do return false
  }

  for col_idx := 0; col_idx < len(widths); col_idx += 1 {
    total := widths[col_idx] + 2 * t.padding
    for _ in 0..<total {
      if !write_str(w, chars.horizontal, n) do return false
    }

    if col_idx < len(widths) - 1 {
      tee := chars.top_tee
      switch pos {
      case .MIDDLE: tee = chars.cross
      case .BOTTOM: tee = chars.bottom_tee
      case .TOP:    // default
      }
      if !write_str(w, tee, n) do return false
    } else if t.border.right {
      right := chars.top_right
      switch pos {
      case .MIDDLE: right = chars.right_tee
      case .BOTTOM: right = chars.bottom_right
      case .TOP:    // default
      }
      if !write_str(w, right, n) do return false
    }
  }

  if !write_str(w, "\n", n) do return false
  return true
}

/* write_row renders a single row of cells (used for both header and data rows). */
@(private="file")
write_row :: proc(
  w: io.Writer,
  t: Table,
  cells: []Cell,
  widths: []int,
  fallback_style: Maybe(style.Style),
  n: ^int,
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
    text := cell_text(content)
    text = truncate_text(text, effective_width)
    text_w := text_display_width(text)

    // Resolve alignment: cell override > column default
    alignment := col.alignment
    if cell_align, has_align := cell.alignment.?; has_align {
      alignment = cell_align
    }

    left_pad, right_pad := compute_alignment_padding(text_w, effective_width, alignment)
    if !write_padding(w, left_pad, n) do return false

    if !write_cell_content(w, content, text, fallback_style, n) do return false

    if !write_padding(w, right_pad, n) do return false
    if !write_padding(w, t.padding, n) do return false

    // Column separator
    if col_idx < num_cols - 1 {
      if !write_str(w, t.border.chars.vertical, n) do return false
    } else if t.border.right {
      if !write_str(w, t.border.chars.vertical, n) do return false
    }
  }

  if !write_str(w, "\n", n) do return false
  return true
}

@(private="file")
write_cell_content :: proc(
  w: io.Writer,
  content: Cell_Content,
  text: string,
  fallback_style: Maybe(style.Style),
  n: ^int,
) -> bool {
  switch c in content {
  case style.Styled_Text:
    st := style.Styled_Text{text = text, style = c.style}
    return style.to_writer(w, st, n)
  case string:
    if s, has_style := fallback_style.?; has_style {
      st := style.Styled_Text{text = text, style = s}
      return style.to_writer(w, st, n)
    }
    return write_str(w, text, n)
  case:
    return true
  }
}

@(private="file")
compute_alignment_padding :: proc(text_w: int, col_w: int, alignment: Alignment) -> (left: int, right: int) {
  space := col_w - text_w
  if space <= 0 {
    return 0, 0
  }

  switch alignment {
  case .LEFT:
    return 0, space
  case .RIGHT:
    return space, 0
  case .CENTER:
    left = space / 2
    right = space - left
    return
  }
  return 0, space
}

@(private="file")
write_padding :: proc(w: io.Writer, count: int, n: ^int) -> bool {
  for _ in 0..<count {
    if !write_str(w, " ", n) do return false
  }
  return true
}

@(private="file")
_has_headers :: proc(t: Table) -> bool {
  for col in t.columns {
    if cell_text(col.header) != "" {
      return true
    }
  }
  return false
}
