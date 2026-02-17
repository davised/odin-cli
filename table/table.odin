// Formatted terminal tables with borders, alignment, wrapping, and column constraints.
package table

import "../style"

/* Horizontal text alignment within a table cell. */
Alignment :: enum {
	Left,
	Center,
	Right,
}

/* Multi-segment styled text for cells with mixed formatting (e.g. bold key + plain value). */
Rich_Text :: distinct []style.Styled_Text

/* Cell content: plain string, single Styled_Text, or Rich_Text with multiple styled segments. */
Cell_Content :: union {
	string,
	style.Styled_Text,
	Rich_Text,
}

/* Single table cell with content and an optional per-cell alignment override. */
Cell :: struct {
	content:   Cell_Content,
	alignment: Maybe(Alignment),
}

/* Column definition with header content, default alignment, and optional width constraints. */
Column :: struct {
	header:    Cell_Content,
	alignment: Alignment,
	min_width: int,
	max_width: int, // 0 = unlimited; if both set, max_width takes precedence
}

/* Table row containing cells and an optional row-level style applied to plain string cells. */
Row :: struct {
	cells: [dynamic]Cell,
	style: Maybe(style.Style),
}

/* Header row configuration: optional style and separator line toggle. */
Header_Config :: struct {
	style:     Maybe(style.Style),
	separator: bool,
}

/* Complete table: columns, rows, border style, width, padding, title, and wrapping options. */
Table :: struct {
	columns:               [dynamic]Column,
	rows:                  [dynamic]Row,
	border:                Border_Style,
	header_config:         Header_Config,
	padding:               int,
	width:                 int, // 0 = auto (default), >0 = target total display width
	title:                 Cell_Content, // Title rendered in top border
	hide_column_separator: bool, // When true, no vertical lines between columns
	wrap:                  bool, // When true, content wraps instead of truncating
}

/* make_table creates a new Table with the given border style and padding.
	 The caller must call destroy_table when done. */
make_table :: proc(
	border: Border_Style = BORDER_LIGHT,
	padding: int = 1,
	hide_column_separator: bool = false,
	title: Cell_Content = nil,
	wrap: bool = false,
	allocator := context.allocator,
) -> Table {
	return Table {
		columns = make([dynamic]Column, allocator),
		rows = make([dynamic]Row, allocator),
		border = border,
		header_config = Header_Config{separator = true},
		padding = padding,
		title = title,
		hide_column_separator = hide_column_separator,
		wrap = wrap,
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
	alignment: Alignment = .Left,
	min_width: int = 0,
	max_width: int = 0,
) {
	append(&t.columns, Column{header = header, alignment = alignment, min_width = min_width, max_width = max_width})
}

/* add_row adds a row of cell contents to the table. */
add_row :: proc(t: ^Table, contents: ..Cell_Content) {
	append_row(t, nil, contents)
}

/* add_styled_row adds a row with a row-level style applied to plain string cells. */
add_styled_row :: proc(t: ^Table, row_style: style.Style, contents: ..Cell_Content) {
	append_row(t, row_style, contents)
}

/* add_row_cells adds a row with per-cell alignment overrides. */
add_row_cells :: proc(t: ^Table, cells: ..Cell) {
	row := Row {
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

@(private = "file")
append_row :: proc(t: ^Table, row_style: Maybe(style.Style), contents: []Cell_Content) {
	row := Row {
		cells = make([dynamic]Cell, 0, len(contents), t.rows.allocator),
		style = row_style,
	}
	for content in contents {
		append(&row.cells, Cell{content = content})
	}
	append(&t.rows, row)
}
