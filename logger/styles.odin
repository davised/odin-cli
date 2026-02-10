package logger

import "../style"

/* Level_Style defines the visual presentation for a log level prefix. */
Level_Style :: struct {
	prefix:       string,
	prefix_style: style.Style,
}

/* Key_Style defines how structured key=value fields are rendered. */
Key_Style :: struct {
	key_style:       style.Style,
	separator:       string,
	separator_style: style.Style,
	value_style:     style.Style,
}

/* default_level_styles returns colored and bold level prefixes. */
default_level_styles :: proc() -> [LEVEL_COUNT]Level_Style {
	return {
		// Debug: gray + bold
		{prefix = "DEBU", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_FG.Bright_Black}},
		// Info: blue + bold
		{prefix = "INFO", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_FG.Blue}},
		// Warning: yellow + bold
		{prefix = "WARN", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_FG.Yellow}},
		// Error: red + bold
		{prefix = "ERRO", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_FG.Red}},
		// Fatal: bright red + bold
		{prefix = "FATA", prefix_style = {text_styles = {.Bold}, foreground_color = style.ANSI_FG.Bright_Red}},
	}
}

/* plain_level_styles returns unstyled level prefixes. */
plain_level_styles :: proc() -> [LEVEL_COUNT]Level_Style {
	return {{prefix = "DEBU"}, {prefix = "INFO"}, {prefix = "WARN"}, {prefix = "ERRO"}, {prefix = "FATA"}}
}

/* default_key_style returns key=value styling: cyan+faint keys, gray separator, unstyled values. */
default_key_style :: proc() -> Key_Style {
	return Key_Style {
		key_style = {text_styles = {.Faint}, foreground_color = style.ANSI_FG.Cyan},
		separator = "=",
		separator_style = {foreground_color = style.ANSI_FG.Bright_Black},
	}
}

/* plain_key_style returns unstyled key=value rendering. */
plain_key_style :: proc() -> Key_Style {
	return Key_Style{separator = "="}
}

/* default_timestamp_style returns gray timestamp styling. */
default_timestamp_style :: proc() -> style.Style {
	return style.Style{foreground_color = style.ANSI_FG.Bright_Black}
}

/* default_caller_style returns faint caller location styling. */
default_caller_style :: proc() -> style.Style {
	return style.Style{text_styles = {.Faint}}
}
