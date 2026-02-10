package table

import "../style"

Alignment :: enum {
  LEFT,
  CENTER,
  RIGHT,
}

Cell_Content :: union {
  string,
  style.Styled_Text,
}

Cell :: struct {
  content:   Cell_Content,
  alignment: Maybe(Alignment),
}

Column :: struct {
  header:    Cell_Content,
  alignment: Alignment,
  min_width: int,
  max_width: int,   // 0 = unlimited; if both set, max_width takes precedence
}

Row :: struct {
  cells: [dynamic]Cell,
  style: Maybe(style.Style),
}

Header_Config :: struct {
  style:     Maybe(style.Style),
  separator: bool,
}

Table :: struct {
  columns:       [dynamic]Column,
  rows:          [dynamic]Row,
  border:        Border_Style,
  header_config: Header_Config,
  padding:       int,
  width:         int,   // 0 = auto (default), >0 = target total display width
}

/* make_table creates a new Table with the given border style and padding.
   The caller must call destroy_table when done. */
make_table :: proc(
  border: Border_Style = BORDER_LIGHT,
  padding: int = 1,
  allocator := context.allocator,
) -> Table {
  return Table{
    columns       = make([dynamic]Column, allocator),
    rows          = make([dynamic]Row, allocator),
    border        = border,
    header_config = Header_Config{separator = true},
    padding       = padding,
  }
}

/* destroy_table frees all dynamic arrays owned by the table. */
destroy_table :: proc(t: ^Table) {
  for &row in t.rows {
    delete(row.cells)
  }
  delete(t.rows)
  delete(t.columns)
}

/* add_column adds a column definition to the table. */
add_column :: proc(
  t: ^Table,
  header: Cell_Content = nil,
  alignment: Alignment = .LEFT,
  min_width: int = 0,
  max_width: int = 0,
) {
  append(&t.columns, Column{
    header    = header,
    alignment = alignment,
    min_width = min_width,
    max_width = max_width,
  })
}

/* add_row adds a row of cell contents to the table. */
add_row :: proc(t: ^Table, contents: ..Cell_Content) {
  _append_row(t, nil, contents)
}

/* add_styled_row adds a row with a row-level style applied to plain string cells. */
add_styled_row :: proc(t: ^Table, row_style: style.Style, contents: ..Cell_Content) {
  _append_row(t, row_style, contents)
}

/* add_row_cells adds a row with per-cell alignment overrides. */
add_row_cells :: proc(t: ^Table, cells: ..Cell) {
  row := Row{
    cells = make([dynamic]Cell, 0, len(cells), t.rows.allocator),
  }
  for cell in cells {
    append(&row.cells, cell)
  }
  append(&t.rows, row)
}

/* set_header_style sets the style applied to all header cells. */
set_header_style :: proc(t: ^Table, header_style: style.Style) {
  t.header_config.style = header_style
}

@(private="file")
_append_row :: proc(t: ^Table, row_style: Maybe(style.Style), contents: []Cell_Content) {
  row := Row{
    cells = make([dynamic]Cell, 0, len(contents), t.rows.allocator),
    style = row_style,
  }
  for content in contents {
    append(&row.cells, Cell{content = content})
  }
  append(&t.rows, row)
}
