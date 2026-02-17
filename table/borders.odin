package table

/* Box-drawing character set defining the 11 junction and edge characters for table borders. */
Border_Chars :: struct {
	horizontal:   string,
	vertical:     string,
	top_left:     string,
	top_right:    string,
	bottom_left:  string,
	bottom_right: string,
	top_tee:      string,
	bottom_tee:   string,
	left_tee:     string,
	right_tee:    string,
	cross:        string,
}

/* Border configuration: character set plus which edges (top, bottom, left, right) to render. */
Border_Style :: struct {
	chars:            Border_Chars,
	top:              bool,
	bottom:           bool,
	left:             bool,
	right:            bool,
	row_separator:    bool,
	header_separator: bool,
}

/* No borders — renders cells with padding only. */
BORDER_NONE :: Border_Style{}

/* ASCII border using +, -, and | characters. */
BORDER_ASCII :: Border_Style {
	chars = Border_Chars {
		horizontal = "-",
		vertical = "|",
		top_left = "+",
		top_right = "+",
		bottom_left = "+",
		bottom_right = "+",
		top_tee = "+",
		bottom_tee = "+",
		left_tee = "+",
		right_tee = "+",
		cross = "+",
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
	row_separator = false,
	header_separator = true,
}

/* Light box-drawing border (─ │ ┌ ┐ └ ┘). Default style. */
BORDER_LIGHT :: Border_Style {
	chars = Border_Chars {
		horizontal = "─",
		vertical = "│",
		top_left = "┌",
		top_right = "┐",
		bottom_left = "└",
		bottom_right = "┘",
		top_tee = "┬",
		bottom_tee = "┴",
		left_tee = "├",
		right_tee = "┤",
		cross = "┼",
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
	row_separator = false,
	header_separator = true,
}

/* Heavy box-drawing border (━ ┃ ┏ ┓ ┗ ┛). */
BORDER_HEAVY :: Border_Style {
	chars = Border_Chars {
		horizontal = "━",
		vertical = "┃",
		top_left = "┏",
		top_right = "┓",
		bottom_left = "┗",
		bottom_right = "┛",
		top_tee = "┳",
		bottom_tee = "┻",
		left_tee = "┣",
		right_tee = "┫",
		cross = "╋",
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
	row_separator = false,
	header_separator = true,
}

/* Double-line box-drawing border (═ ║ ╔ ╗ ╚ ╝). */
BORDER_DOUBLE :: Border_Style {
	chars = Border_Chars {
		horizontal = "═",
		vertical = "║",
		top_left = "╔",
		top_right = "╗",
		bottom_left = "╚",
		bottom_right = "╝",
		top_tee = "╦",
		bottom_tee = "╩",
		left_tee = "╠",
		right_tee = "╣",
		cross = "╬",
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
	row_separator = false,
	header_separator = true,
}

/* Rounded-corner border using light lines with arc corners (╭ ╮ ╰ ╯). */
BORDER_ROUNDED :: Border_Style {
	chars = Border_Chars {
		horizontal = "─",
		vertical = "│",
		top_left = "╭",
		top_right = "╮",
		bottom_left = "╰",
		bottom_right = "╯",
		top_tee = "┬",
		bottom_tee = "┴",
		left_tee = "├",
		right_tee = "┤",
		cross = "┼",
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
	row_separator = false,
	header_separator = true,
}
