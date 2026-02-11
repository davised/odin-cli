package logger

import "../style"

/* Level_Style defines the visual presentation for a log level prefix. */
Level_Style :: struct {
	prefix:       string,
	prefix_style: style.Style,
}

/* Key_Style defines how structured key=value fields are rendered.
   Numeric values are styled with value_number_style if set (non-zero);
   otherwise they fall back to value_style. */
Key_Style :: struct {
	key_style:          style.Style,
	separator:          string,
	separator_style:    style.Style,
	value_style:        style.Style,
	value_number_style: style.Style,
}

/* default_level_styles returns colored and bold bracketed level prefixes.
   Padded to 7 chars (length of "SUCCESS") inside brackets for alignment. */
default_level_styles :: proc() -> [LEVEL_COUNT]Level_Style {
	return {
		// Trace: faint + gray
		{prefix = "[TRACE  ]", prefix_style = {text_styles = {.Faint}, foreground_color = style.ANSI_Color.Bright_Black}},
		// Debug: bold + gray
		{prefix = "[DEBUG  ]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Bright_Black}},
		// Info: bold + blue
		{prefix = "[INFO   ]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Blue}},
		// Hint: bold + cyan
		{prefix = "[HINT   ]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Cyan}},
		// Success: bold + green
		{prefix = "[SUCCESS]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Green}},
		// Warning: bold + yellow
		{prefix = "[WARN   ]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Yellow}},
		// Error: bold + red
		{prefix = "[ERROR  ]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Red}},
		// Fatal: bold + bright red
		{prefix = "[FATAL  ]", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_Color.Bright_Red}},
	}
}

/* plain_level_styles returns unstyled bracketed level prefixes. */
plain_level_styles :: proc() -> [LEVEL_COUNT]Level_Style {
	return {
		{prefix = "[TRACE  ]"},
		{prefix = "[DEBUG  ]"},
		{prefix = "[INFO   ]"},
		{prefix = "[HINT   ]"},
		{prefix = "[SUCCESS]"},
		{prefix = "[WARN   ]"},
		{prefix = "[ERROR  ]"},
		{prefix = "[FATAL  ]"},
	}
}

/* default_key_style returns key=value styling: cyan+faint keys, gray separator,
   unstyled text values, yellow numeric values. */
default_key_style :: proc() -> Key_Style {
	return Key_Style {
		key_style          = {text_styles = {.Faint}, foreground_color = style.ANSI_Color.Cyan},
		separator          = "=",
		separator_style    = {foreground_color = style.ANSI_Color.Bright_Black},
		value_number_style = {foreground_color = style.ANSI_Color.Yellow},
	}
}

/* plain_key_style returns unstyled key=value rendering. */
plain_key_style :: proc() -> Key_Style {
	return Key_Style{separator = "="}
}

/* default_timestamp_style returns gray timestamp styling. */
default_timestamp_style :: proc() -> style.Style {
	return style.Style{foreground_color = style.ANSI_Color.Bright_Black}
}

/* default_caller_style returns faint caller location styling. */
default_caller_style :: proc() -> style.Style {
	return style.Style{text_styles = {.Faint}}
}
