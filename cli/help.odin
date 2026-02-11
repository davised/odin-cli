package cli

import "../style"
import "../table"
import "../term"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:strings"

// write_help renders styled help output for a flags-annotated struct type.
write_help :: proc(
	w: io.Writer,
	data_type: typeid,
	program: string,
	parsing_style: flags.Parsing_Style = .Unix,
	commands: []Command = nil,
	panel_config: []Panel = nil,
	theme_override: Maybe(Theme) = nil,
	description: string = "",
	version: string = "",
	max_width: int = 0,
	mode: term.Render_Mode = .Full,
	n: ^int = nil,
) -> bool {
	theme := theme_override.? or_else default_theme()

	width := max_width
	if width <= 0 {
		if tw, ok := term.terminal_width(); ok {
			width = tw
		} else {
			width = 80
		}
	}

	all_flags := extract_flags(data_type)

	// Separate positional from option flags (skip hidden).
	positionals := make([dynamic]Flag_Info, 0, len(all_flags), context.temp_allocator)
	options := make([dynamic]Flag_Info, 0, len(all_flags), context.temp_allocator)

	for f in all_flags {
		if f.is_hidden do continue
		if f.is_positional {
			append(&positionals, f)
		} else {
			append(&options, f)
		}
	}

	flag_prefix := flag_prefix_for_style(parsing_style)

	// Usage line.
	write_styled(w, "Usage: ", theme.usage_label_style, mode, n)
	write_styled(w, program, theme.program_style, mode, n)

	if len(commands) > 0 {
		io.write_string(w, " ", n)
		write_styled(w, "<command>", theme.command_style, mode, n)
	}

	if len(options) > 0 {
		io.write_string(w, " ", n)
		write_styled(w, "[OPTIONS]", theme.meta_style, mode, n)
	}

	// Positionals in usage line.
	for p in positionals {
		io.write_string(w, " ", n)
		name := strings.to_upper(p.display_name, context.temp_allocator)
		if p.is_required {
			write_styled(w, name, theme.arg_name_style, mode, n)
		} else {
			write_styled(w, "[", theme.meta_style, mode, n)
			write_styled(w, name, theme.arg_name_style, mode, n)
			write_styled(w, "]", theme.meta_style, mode, n)
		}
	}

	io.write_string(w, "\n", n)

	// Description and version.
	if len(description) > 0 || len(version) > 0 {
		io.write_string(w, "\n", n)
		if len(description) > 0 {
			io.write_string(w, description, n)
			io.write_string(w, "\n", n)
		}
		if len(version) > 0 {
			write_styled(w, fmt.tprintf("Version %s", version), theme.meta_style, mode, n)
			io.write_string(w, "\n", n)
		}
	}

	// Arguments section (positionals).
	if len(positionals) > 0 {
		io.write_string(w, "\n", n)
		write_styled(w, "Arguments:", theme.heading_style, mode, n)
		io.write_string(w, "\n", n)

		t := table.make_table(table.BORDER_NONE, padding = 1, allocator = context.temp_allocator)
		table.add_column(&t, alignment = .LEFT) // name
		table.add_column(&t, alignment = .LEFT) // description
		table.add_column(&t, alignment = .LEFT) // meta (required/type)

		for p in positionals {
			name := strings.to_upper(p.display_name, context.temp_allocator)
			meta := build_meta(p, theme)

			table.add_row(
				&t,
				styled_content(fmt.tprintf("  %s", name), theme.arg_name_style),
				styled_content(p.usage, theme.description_style),
				meta,
			)
		}

		table.to_writer(w, t, n, mode)
	}

	// Determine which options belong to panels and which are ungrouped.
	panel_fields := make(map[string]bool, allocator = context.temp_allocator)
	if len(panel_config) > 0 {
		for panel in panel_config {
			for field_name in panel.fields {
				panel_fields[field_name] = true
			}
		}
	}

	// Ungrouped options.
	ungrouped := make([dynamic]Flag_Info, 0, len(options), context.temp_allocator)
	for opt in options {
		if opt.field_name not_in panel_fields {
			append(&ungrouped, opt)
		}
	}

	if len(ungrouped) > 0 {
		io.write_string(w, "\n", n)
		write_styled(w, "Options:", theme.heading_style, mode, n)
		io.write_string(w, "\n", n)
		write_options_table(w, ungrouped[:], flag_prefix, theme, mode, n)
	}

	// Panel groups.
	if len(panel_config) > 0 {
		for panel in panel_config {
			panel_opts := make([dynamic]Flag_Info, 0, len(panel.fields), context.temp_allocator)
			for opt in options {
				for field_name in panel.fields {
					if opt.field_name == field_name {
						append(&panel_opts, opt)
						break
					}
				}
			}

			if len(panel_opts) == 0 do continue

			io.write_string(w, "\n", n)
			write_styled(w, fmt.tprintf("%s:", panel.name), theme.heading_style, mode, n)
			io.write_string(w, "\n", n)
			write_options_table(w, panel_opts[:], flag_prefix, theme, mode, n)
		}
	}

	// Commands section.
	if len(commands) > 0 {
		io.write_string(w, "\n", n)
		write_styled(w, "Commands:", theme.heading_style, mode, n)
		io.write_string(w, "\n", n)

		t := table.make_table(table.BORDER_NONE, padding = 1, allocator = context.temp_allocator)
		table.add_column(&t, alignment = .LEFT) // name
		table.add_column(&t, alignment = .LEFT) // description

		for cmd in commands {
			if cmd.hidden do continue
			table.add_row(
				&t,
				styled_content(fmt.tprintf("  %s", cmd.name), theme.command_style),
				styled_content(cmd.description, theme.description_style),
			)
		}

		table.to_writer(w, t, n, mode)
	}

	return true
}

// write_options_table renders a table of option flags.
@(private = "file")
write_options_table :: proc(
	w: io.Writer,
	opts: []Flag_Info,
	flag_prefix: string,
	theme: Theme,
	mode: term.Render_Mode,
	n: ^int,
) {
	t := table.make_table(table.BORDER_NONE, padding = 1, allocator = context.temp_allocator)
	table.add_column(&t, alignment = .LEFT) // flag name
	table.add_column(&t, alignment = .LEFT) // type hint
	table.add_column(&t, alignment = .LEFT) // description
	table.add_column(&t, alignment = .LEFT) // meta

	for opt in opts {
		flag_str := fmt.tprintf("  %s%s", flag_prefix, opt.display_name)
		type_str := opt.type_description if !opt.is_boolean else ""
		meta := build_meta(opt, theme)

		table.add_row(
			&t,
			styled_content(flag_str, theme.flag_name_style),
			styled_content(type_str, theme.type_style),
			styled_content(opt.usage, theme.description_style),
			meta,
		)
	}

	table.to_writer(w, t, n, mode)
}

// build_meta creates the metadata column content (e.g. "[required]", type hint).
@(private = "file")
build_meta :: proc(info: Flag_Info, theme: Theme) -> table.Cell_Content {
	if info.is_required {
		return styled_content("[required]", theme.required_style)
	}
	return nil
}

// styled_content creates a table Cell_Content from a string and style.
@(private = "file")
styled_content :: proc(text: string, s: style.Style) -> table.Cell_Content {
	if text == "" do return nil
	return style.Styled_Text{text = text, style = s}
}

// write_styled writes a styled string to the writer. Package-private for use by errors.odin and cli.odin.
@(private)
write_styled :: proc(w: io.Writer, text: string, s: style.Style, mode: term.Render_Mode, n: ^int) {
	st := style.Styled_Text{text = text, style = s}
	style.to_writer(w, st, n, mode)
}

// flag_prefix_for_style returns the flag prefix for a parsing style.
@(private)
flag_prefix_for_style :: proc(parsing_style: flags.Parsing_Style) -> string {
	switch parsing_style {
	case .Odin:  return "-"
	case .Unix:  return "--"
	}
	return "--"
}
