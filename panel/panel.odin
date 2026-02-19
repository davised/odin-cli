// Bordered text panels for terminal output.
package panel

import "../style"

/* Line is a single content line: either a plain string or a Styled_Text. */
Line :: union {
	string,
	style.Styled_Text,
}

/* Border_Chars defines the 6 box-drawing characters for a panel border. */
Border_Chars :: struct {
	horizontal:   string,
	vertical:     string,
	top_left:     string,
	top_right:    string,
	bottom_left:  string,
	bottom_right: string,
}

/* Border_Style configures which edges to draw and the character set. */
Border_Style :: struct {
	chars:  Border_Chars,
	top:    bool,
	bottom: bool,
	left:   bool,
	right:  bool,
}

/* Panel is a bordered text box with optional title and configurable width.

   Fields:
   - lines: Content lines (caller-owned slice).
   - border: Border style and edge configuration.
   - title: Optional title rendered in the top border (nil = no title).
   - padding: Horizontal padding inside borders (default 1).
   - width: Total outer width. 0 = auto-size to widest line. */
Panel :: struct {
	lines:   []Line,
	border:  Border_Style,
	title:   Line,
	padding: int,
	width:   int,
}

/* No borders — renders content lines only. */
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
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
}

/* Light box-drawing border (─ │ ┌ ┐ └ ┘). */
BORDER_LIGHT :: Border_Style {
	chars = Border_Chars {
		horizontal = "─",
		vertical = "│",
		top_left = "┌",
		top_right = "┐",
		bottom_left = "└",
		bottom_right = "┘",
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
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
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
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
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
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
	},
	top = true,
	bottom = true,
	left = true,
	right = true,
}
