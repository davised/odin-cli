package cli

import "../style"

// Theme controls all styling for help and error output.
Theme :: struct {
	heading_style:     style.Style,  // "Arguments:", "Options:", "Commands:"
	usage_label_style: style.Style,  // "Usage:"
	program_style:     style.Style,  // program name
	flag_name_style:   style.Style,  // --verbose
	arg_name_style:    style.Style,  // FILE, OUTPUT
	type_style:        style.Style,  // <int>, <string>
	default_style:     style.Style,  // [default: false]
	required_style:    style.Style,  // [required]
	description_style: style.Style,  // usage text
	command_style:     style.Style,  // command names
	error_style:       style.Style,  // "Error:"
	suggest_style:     style.Style,  // "Did you mean?"
	meta_style:        style.Style,  // brackets, separators
	env_style:         style.Style,  // [env: VAR]
	choices_style:     style.Style,  // {json,yaml,toml}
	title_style:       style.Style,  // section title in border
}

// default_theme returns a colorful theme for terminal output.
default_theme :: proc() -> Theme {
	return Theme {
		heading_style     = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Yellow},
		usage_label_style = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Yellow},
		program_style     = style.Style{text_styles = {.Bold}},
		flag_name_style   = style.Style{foreground_color = style.ANSI_Color.Green},
		arg_name_style    = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Cyan},
		type_style        = style.Style{foreground_color = style.ANSI_Color.Yellow},
		default_style     = style.Style{foreground_color = style.ANSI_Color.Bright_Black},
		required_style    = style.Style{foreground_color = style.ANSI_Color.Red},
		description_style = style.Style{},
		command_style     = style.Style{foreground_color = style.ANSI_Color.Green},
		error_style       = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Red},
		suggest_style     = style.Style{foreground_color = style.ANSI_Color.Cyan},
		meta_style        = style.Style{foreground_color = style.ANSI_Color.Bright_Black},
		env_style         = style.Style{foreground_color = style.ANSI_Color.Bright_Black},
		choices_style     = style.Style{foreground_color = style.ANSI_Color.Yellow},
		title_style       = style.Style{text_styles = {.Bold}},
	}
}

// plain_theme returns a theme with no colors for piped/plain output.
plain_theme :: proc() -> Theme {
	return Theme{}
}
