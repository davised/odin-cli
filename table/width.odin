package table

import "core:unicode/utf8"
import "../style"

ELLIPSIS :: "…"

/* display_width returns the display width of a Cell_Content value. */
display_width :: proc(content: Cell_Content) -> int {
  switch c in content {
  case string:
    return text_display_width(c)
  case style.Styled_Text:
    return text_display_width(c.text)
  }
  return 0
}

/* text_display_width returns the display width of a plain string.
   Uses rune count as an approximation (1 rune = 1 column).
   Note: CJK/fullwidth characters (2 columns each) and combining marks
   (0 columns) are not handled — tables containing these may misalign. */
text_display_width :: proc(s: string) -> int {
  return utf8.rune_count_in_string(s)
}

/* compute_column_widths calculates the rendered width for each column,
   accounting for content, min/max constraints, and padding.
   Returns a temp-allocated slice. */
compute_column_widths :: proc(t: Table) -> []int {
  num_cols := len(t.columns)
  if num_cols == 0 {
    return nil
  }

  widths := make([]int, num_cols, context.temp_allocator)

  // Start with header widths
  for col, i in t.columns {
    widths[i] = display_width(col.header)
  }

  // Expand to fit cell contents
  for row in t.rows {
    for cell, i in row.cells {
      if i >= num_cols do break
      w := display_width(cell.content)
      if w > widths[i] {
        widths[i] = w
      }
    }
  }

  // Apply min/max constraints
  for col, i in t.columns {
    if col.min_width > 0 && widths[i] < col.min_width {
      widths[i] = col.min_width
    }
    if col.max_width > 0 && widths[i] > col.max_width {
      widths[i] = col.max_width
    }
  }

  // Fill to target width
  if t.width > 0 {
    overhead := _border_overhead(t, num_cols)
    available := t.width - overhead
    if available < num_cols {
      available = num_cols // minimum 1 per column
    }

    current_total := 0
    for w in widths {
      current_total += w
    }

    if available > current_total {
      _distribute_extra(widths, t.columns[:], available - current_total)
    } else if available < current_total {
      _distribute_deficit(widths, t.columns[:], current_total - available)
    }
  }

  return widths
}

/* cell_text extracts the plain text string from a Cell_Content value. */
cell_text :: proc(content: Cell_Content) -> string {
  switch c in content {
  case string:
    return c
  case style.Styled_Text:
    return c.text
  }
  return ""
}

/* _border_overhead returns the total display width consumed by borders,
   separators, and padding — everything except column content. */
@(private="file")
_border_overhead :: proc(t: Table, num_cols: int) -> int {
  if num_cols == 0 do return 0

  sep_w := text_display_width(t.border.chars.vertical)
  overhead := num_cols * 2 * t.padding

  if num_cols > 1 {
    overhead += (num_cols - 1) * sep_w
  }
  if t.border.left {
    overhead += sep_w
  }
  if t.border.right {
    overhead += sep_w
  }
  return overhead
}

/* _distribute_extra expands columns proportionally to fill extra space.
   Columns with max_width are capped; leftover is redistributed. */
@(private="file")
_distribute_extra :: proc(widths: []int, columns: []Column, extra: int) {
  remaining := extra
  locked := make([]bool, len(widths), context.temp_allocator)

  for remaining > 0 {
    unlocked_total := 0
    for i in 0..<len(widths) {
      if !locked[i] {
        unlocked_total += widths[i]
      }
    }

    budget := remaining
    distributed := 0

    if unlocked_total > 0 {
      for i in 0..<len(widths) {
        if locked[i] do continue
        share := budget * widths[i] / unlocked_total
        if columns[i].max_width > 0 {
          cap := columns[i].max_width - widths[i]
          if cap <= 0 {
            locked[i] = true
            continue
          }
          if share > cap {
            share = cap
            locked[i] = true
          }
        }
        widths[i] += share
        distributed += share
      }
    }

    remaining -= distributed
    if distributed == 0 {
      // Integer rounding left us stuck; distribute 1 at a time
      for i in 0..<len(widths) {
        if remaining <= 0 do break
        if locked[i] do continue
        if columns[i].max_width > 0 && widths[i] >= columns[i].max_width {
          locked[i] = true
          continue
        }
        widths[i] += 1
        remaining -= 1
      }
      // Check if all columns are locked
      all_locked := true
      for i in 0..<len(widths) {
        if !locked[i] { all_locked = false; break }
      }
      if all_locked do break
    }
  }
}

/* _distribute_deficit shrinks columns proportionally to meet a target width.
   Columns respect min_width; absolute minimum is 1 (enough for ellipsis). */
@(private="file")
_distribute_deficit :: proc(widths: []int, columns: []Column, deficit: int) {
  remaining := deficit
  locked := make([]bool, len(widths), context.temp_allocator)

  for remaining > 0 {
    shrinkable_total := 0
    for i in 0..<len(widths) {
      if locked[i] do continue
      min_w := max(columns[i].min_width, 1)
      if widths[i] <= min_w {
        locked[i] = true
        continue
      }
      shrinkable_total += widths[i]
    }
    if shrinkable_total == 0 do break

    budget := remaining
    reduced := 0

    for i in 0..<len(widths) {
      if locked[i] do continue
      min_w := max(columns[i].min_width, 1)
      share := budget * widths[i] / shrinkable_total
      cap := widths[i] - min_w
      if share > cap {
        share = cap
        locked[i] = true
      }
      widths[i] -= share
      reduced += share
    }

    remaining -= reduced
    if reduced == 0 {
      for i in 0..<len(widths) {
        if remaining <= 0 do break
        if locked[i] do continue
        min_w := max(columns[i].min_width, 1)
        if widths[i] <= min_w {
          locked[i] = true
          continue
        }
        widths[i] -= 1
        remaining -= 1
      }
      all_locked := true
      for i in 0..<len(widths) {
        if !locked[i] { all_locked = false; break }
      }
      if all_locked do break
    }
  }
}

/* truncate_text truncates a string to max_width runes, appending an
   ellipsis if truncation occurs. Returns the original string if it fits. */
truncate_text :: proc(s: string, max_width: int) -> string {
  if max_width <= 0 {
    return s
  }
  rune_len := utf8.rune_count_in_string(s)
  if rune_len <= max_width {
    return s
  }
  // Truncate to max_width-1 runes + ellipsis
  if max_width <= 1 {
    return ELLIPSIS
  }
  target := max_width - 1
  byte_offset := 0
  for i := 0; i < target; i += 1 {
    _, size := utf8.decode_rune_in_string(s[byte_offset:])
    byte_offset += size
  }
  // Build truncated string in temp allocator
  buf := make([]u8, byte_offset + len(ELLIPSIS), context.temp_allocator)
  copy(buf[:byte_offset], s[:byte_offset])
  copy(buf[byte_offset:], ELLIPSIS)
  return string(buf)
}
