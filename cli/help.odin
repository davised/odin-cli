package cli

import "base:runtime"
import "../style"
import "../table"
import "../term"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:reflect"
import "core:strings"

// write_help renders styled help output for a flags-annotated struct type.
// When defaults is non-nil, it points to a zero-initialized instance of the
// flags struct; non-zero fields are shown as [default: value] in help.
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
	defaults: rawptr = nil,
	global_flags: []Flag_Info = nil,
	global_defaults: rawptr = nil,
	global_type: Maybe(typeid) = nil,
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

	// Build defaults_any for reading default values.
	defaults_any: any
	if defaults != nil {
		defaults_any = any{defaults, data_type}
	}

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
			meta := build_meta(p, theme, defaults_any)

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
		write_options_table(w, ungrouped[:], flag_prefix, parsing_style, theme, mode, n, defaults_any)
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
			write_options_table(w, panel_opts[:], flag_prefix, parsing_style, theme, mode, n, defaults_any)
		}
	}

	// Global Options section.
	if len(global_flags) > 0 {
		global_opts := make([dynamic]Flag_Info, 0, len(global_flags), context.temp_allocator)
		for f in global_flags {
			if !f.is_hidden && !f.is_positional {
				append(&global_opts, f)
			}
		}
		if len(global_opts) > 0 {
			global_defaults_any: any
			if global_defaults != nil {
				if gt, gt_ok := global_type.?; gt_ok {
					global_defaults_any = any{global_defaults, gt}
				}
			}
			io.write_string(w, "\n", n)
			write_styled(w, "Global Options:", theme.heading_style, mode, n)
			io.write_string(w, "\n", n)
			write_options_table(w, global_opts[:], flag_prefix, parsing_style, theme, mode, n, global_defaults_any)
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
	parsing_style: flags.Parsing_Style,
	theme: Theme,
	mode: term.Render_Mode,
	n: ^int,
	defaults_any: any = nil,
) {
	t := table.make_table(table.BORDER_NONE, padding = 1, allocator = context.temp_allocator)
	table.add_column(&t, alignment = .LEFT) // flag name
	table.add_column(&t, alignment = .LEFT) // type hint
	table.add_column(&t, alignment = .LEFT) // description
	table.add_column(&t, alignment = .LEFT) // meta

	// Check once if any option has a short name, for alignment.
	has_any_short := false
	if parsing_style == .Unix {
		for o in opts {
			if len(o.short_name) > 0 {
				has_any_short = true
				break
			}
		}
	}

	for opt in opts {
		// Build flag name with optional short flag prefix.
		// For boolean flags in Unix style, show --[no-]flag format.
		long_name: string
		if opt.is_boolean && parsing_style == .Unix {
			long_name = fmt.tprintf("%s[no-]%s", flag_prefix, opt.display_name)
		} else {
			long_name = fmt.tprintf("%s%s", flag_prefix, opt.display_name)
		}

		flag_str: string
		if len(opt.short_name) > 0 && parsing_style == .Unix {
			flag_str = fmt.tprintf("  -%s, %s", opt.short_name, long_name)
		} else if has_any_short {
			// Indent to align with "-X, " prefix (6 chars).
			flag_str = fmt.tprintf("      %s", long_name)
		} else {
			flag_str = fmt.tprintf("  %s", long_name)
		}

		// Type column: enum choices or type hint.
		type_str: string
		if opt.is_enum && len(opt.enum_names) > 0 {
			type_str = format_enum_choices(opt.enum_names)
		} else if !opt.is_boolean {
			type_str = opt.type_description
		}

		meta := build_meta(opt, theme, defaults_any)

		table.add_row(
			&t,
			styled_content(flag_str, theme.flag_name_style),
			styled_content(type_str, opt.is_enum ? theme.choices_style : theme.type_style),
			styled_content(opt.usage, theme.description_style),
			meta,
		)
	}

	table.to_writer(w, t, n, mode)
}

// build_meta creates the metadata column content (e.g. "[env: VAR] [required]").
// Combines env var, required, and default annotations into a single string.
@(private = "file")
build_meta :: proc(info: Flag_Info, theme: Theme, defaults_any: any = nil) -> table.Cell_Content {
	parts := make([dynamic]string, 0, 4, context.temp_allocator)

	if len(info.xor_group) > 0 {
		append(&parts, fmt.tprintf("[xor: %s]", info.xor_group))
	}

	if len(info.env_var) > 0 {
		append(&parts, fmt.tprintf("[env: %s]", info.env_var))
	}

	if info.is_required {
		append(&parts, "[required]")
	} else if defaults_any != nil {
		// Show default value if non-zero.
		field_val := reflect.struct_field_value_by_name(defaults_any, info.field_name)
		if field_val != nil && !is_zero_value(field_val) {
			append(&parts, fmt.tprintf("[default: %v]", field_val))
		}
	}

	if len(parts) == 0 do return nil

	combined := strings.join(parts[:], " ", context.temp_allocator)

	// Use required_style if required is present, otherwise meta_style.
	s := theme.meta_style
	if info.is_required {
		s = theme.required_style
	}
	return styled_content(combined, s)
}

// format_enum_choices formats enum names as "{name1,name2,...}".
// Names are lowercased with underscores replaced by hyphens to match
// core:flags parsing convention.
@(private = "file")
format_enum_choices :: proc(names: []string) -> string {
	sb := strings.builder_make(context.temp_allocator)
	strings.write_byte(&sb, '{')
	for name, i in names {
		if i > 0 do strings.write_byte(&sb, ',')
		lower := strings.to_lower(name, context.temp_allocator)
		replaced, _ := strings.replace_all(lower, "_", "-", context.temp_allocator)
		strings.write_string(&sb, replaced)
	}
	strings.write_byte(&sb, '}')
	return strings.to_string(sb)
}

// is_zero_value checks if a reflected value is the zero value for its type.
is_zero_value :: proc(val: any) -> bool {
	if val == nil do return true

	ti := runtime.type_info_base(type_info_of(val.id))

	#partial switch _ in ti.variant {
	case runtime.Type_Info_String:
		return len((^string)(val.data)^) == 0
	case runtime.Type_Info_Boolean:
		return !(^bool)(val.data)^
	case runtime.Type_Info_Float:
		if ti.size == 4 do return (^f32)(val.data)^ == 0
		return (^f64)(val.data)^ == 0
	}

	// Generic: compare all bytes to zero (covers int, enum, etc.).
	bytes := ([^]byte)(val.data)[:ti.size]
	for b in bytes {
		if b != 0 do return false
	}
	return true
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
