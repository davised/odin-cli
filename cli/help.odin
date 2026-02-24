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

// Number of columns in option tables: flag, type, description, meta.
@(private = "file")
OPTION_COLUMNS :: 4

// Minimum terminal width for rendering help. Below this, a message is shown instead.
@(private = "file")
MIN_HELP_WIDTH :: 60

// Help_Config bundles optional parameters for write_help.
Help_Config :: struct {
	parsing_style:   flags.Parsing_Style,
	commands:        []Command,
	panel_config:    []Panel,
	theme:           Maybe(Theme),
	description:     string,
	version:         string,
	max_width:       int,
	mode:            term.Render_Mode,
	defaults:        rawptr,
	global_flags:    []Flag_Info,
	global_defaults: rawptr,
	global_type:     Maybe(typeid),
	default_command: string,
}

// write_help renders styled help output for a flags-annotated struct type.
// When config.defaults is non-nil, it points to a zero-initialized instance
// of the flags struct; non-zero fields are shown as [default: value] in help.
write_help :: proc(
	w: io.Writer,
	data_type: typeid,
	program: string,
	config: Help_Config = {},
	n: ^int = nil,
) -> bool {
	theme := config.theme.? or_else default_theme()
	parsing_style := config.parsing_style
	commands := config.commands
	panel_config := config.panel_config
	description := config.description
	version := config.version
	mode := config.mode
	global_flags := config.global_flags
	global_defaults := config.global_defaults
	global_type := config.global_type
	defaults := config.defaults

	width := config.max_width
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

	// Bail out early if the terminal is too narrow for table sections.
	if width <= MIN_HELP_WIDTH {
		io.write_string(w, "\n", n)
		write_styled(w, fmt.tprintf("For detailed help, widen terminal to %d+ columns.\n", MIN_HELP_WIDTH + 1), theme.meta_style, mode, n)
		return true
	}

	// --- Collect option groups ---
	panel_fields := make(map[string]bool, allocator = context.temp_allocator)
	if len(panel_config) > 0 {
		for panel in panel_config {
			for field_name in panel.fields {
				panel_fields[field_name] = true
			}
		}
	}

	// Discover tag-based panels (first-seen order).
	// Fields claimed by panel_config are skipped.
	// Fields with panel tag and NOT in panel_config go to auto-discovered panels.
	// Fields with no panel assignment go to ungrouped "Options".
	Tag_Panel :: struct {
		name:   string,
		fields: [dynamic]Flag_Info,
	}
	tag_panels := make([dynamic]Tag_Panel, 0, 4, context.temp_allocator)
	tag_panel_index := make(map[string]int, allocator = context.temp_allocator)

	ungrouped := make([dynamic]Flag_Info, 0, len(options), context.temp_allocator)
	for opt in options {
		if opt.field_name in panel_fields {
			continue // claimed by panel_config
		}
		if len(opt.panel) > 0 {
			// Route to tag-discovered panel.
			if idx, found := tag_panel_index[opt.panel]; found {
				append(&tag_panels[idx].fields, opt)
			} else {
				tag_panel_index[opt.panel] = len(tag_panels)
				tp := Tag_Panel{name = opt.panel, fields = make([dynamic]Flag_Info, 0, 4, context.temp_allocator)}
				append(&tp.fields, opt)
				append(&tag_panels, tp)
			}
		} else {
			append(&ungrouped, opt)
		}
	}

	// Collect visible global flags.
	visible_global := make([dynamic]Flag_Info, 0, len(global_flags), context.temp_allocator)
	for f in global_flags {
		if !f.is_hidden && !f.is_positional {
			append(&visible_global, f)
		}
	}

	global_defaults_any: any
	if global_defaults != nil {
		if gt, gt_ok := global_type.?; gt_ok {
			global_defaults_any = any{global_defaults, gt}
		}
	}

	// --- Cross-panel column alignment ---
	// Compute has_any_short across ALL option sections for consistent alignment.
	has_any_short := false
	if parsing_style == .Unix {
		for opt in options {
			if len(opt.short_name) > 0 {
				has_any_short = true
				break
			}
		}
		if !has_any_short {
			for f in visible_global {
				if len(f.short_name) > 0 {
					has_any_short = true
					break
				}
			}
		}
	}

	// Build a scratch table with ALL option rows to compute unified flag column width.
	scratch := table.make_table(
		border = table.BORDER_ROUNDED,
		padding = 2,
		hide_column_separator = true,
		allocator = context.temp_allocator,
	)
	defer table.destroy_table(&scratch)
	table.add_column(&scratch, alignment = .Left) // flag
	table.add_column(&scratch, alignment = .Left) // type
	table.add_column(&scratch, alignment = .Left) // desc
	table.add_column(&scratch, alignment = .Right) // meta

	add_option_rows(&scratch, ungrouped[:], flag_prefix, parsing_style, has_any_short, theme, defaults_any)

	for panel in panel_config {
		panel_opts := collect_panel_options(options[:], panel)
		add_option_rows(&scratch, panel_opts, flag_prefix, parsing_style, has_any_short, theme, defaults_any)
	}

	for &tp in tag_panels {
		add_option_rows(&scratch, tp.fields[:], flag_prefix, parsing_style, has_any_short, theme, defaults_any)
	}

	add_option_rows(&scratch, visible_global[:], flag_prefix, parsing_style, has_any_short, theme, global_defaults_any)

	unified_widths := table.compute_column_widths(scratch)

	// --- Arguments section (positionals) ---
	if len(positionals) > 0 {
		io.write_string(w, "\n", n)
		if mode == .Plain {
			write_styled(w, "Arguments:", theme.heading_style, mode, n)
			io.write_string(w, "\n", n)
		}

		t := table.make_table(
			border = table.BORDER_ROUNDED,
			padding = 2,
			hide_column_separator = true,
			title = styled_content("Arguments", theme.title_style),
			wrap = true,
			allocator = context.temp_allocator,
		)
		defer table.destroy_table(&t)
		table.add_column(&t, alignment = .Left) // name
		table.add_column(&t, alignment = .Left) // description (expands)
		table.add_column(&t, alignment = .Right) // meta

		for p in positionals {
			name := strings.to_upper(p.display_name, context.temp_allocator)
			name_str := p.is_required ? name : fmt.tprintf("[%s]", name)
			table.add_row(
				&t,
				styled_content(name_str, theme.arg_name_style),
				styled_content(p.usage, theme.description_style),
				build_meta(p, theme, defaults_any),
			)
		}

		lock_columns_except(&t, 1)
		if mode != .Plain {
			t.width = width
		}
		table.to_writer(w, t, n, mode)
	}

	// --- Render option sections with unified widths ---
	if len(ungrouped) > 0 {
		io.write_string(w, "\n", n)
		write_options_panel(w, ungrouped[:], "Options", flag_prefix, parsing_style, has_any_short, theme, mode, n, defaults_any, width, unified_widths)
	}

	for panel in panel_config {
		panel_opts := collect_panel_options(options[:], panel)
		if len(panel_opts) == 0 do continue

		io.write_string(w, "\n", n)
		write_options_panel(w, panel_opts, panel.name, flag_prefix, parsing_style, has_any_short, theme, mode, n, defaults_any, width, unified_widths)
	}

	for &tp in tag_panels {
		if len(tp.fields) == 0 do continue

		io.write_string(w, "\n", n)
		write_options_panel(w, tp.fields[:], tp.name, flag_prefix, parsing_style, has_any_short, theme, mode, n, defaults_any, width, unified_widths)
	}

	if len(visible_global) > 0 {
		io.write_string(w, "\n", n)
		write_options_panel(w, visible_global[:], "Global Options", flag_prefix, parsing_style, has_any_short, theme, mode, n, global_defaults_any, width, unified_widths)
	}

	// --- Commands section ---
	if len(commands) > 0 {
		io.write_string(w, "\n", n)
		if mode == .Plain {
			write_styled(w, "Commands:", theme.heading_style, mode, n)
			io.write_string(w, "\n", n)
		}

		t := table.make_table(
			border = table.BORDER_ROUNDED,
			padding = 2,
			hide_column_separator = true,
			title = styled_content("Commands", theme.title_style),
			wrap = true,
			allocator = context.temp_allocator,
		)
		defer table.destroy_table(&t)
		table.add_column(&t, alignment = .Left) // name
		table.add_column(&t, alignment = .Left) // description (expands)

		for cmd in commands {
			if cmd.hidden do continue
			desc := cmd.description
			if len(config.default_command) > 0 && cmd.name == config.default_command {
				desc = len(desc) > 0 ? fmt.tprintf("%s  [default]", desc) : "[default]"
			}
			table.add_row(
				&t,
				styled_content(cmd.name, theme.command_style),
				styled_content(desc, theme.description_style),
			)
		}

		lock_columns_except(&t, 1)
		if mode != .Plain {
			t.width = width
		}
		table.to_writer(w, t, n, mode)
	}

	return true
}

// collect_panel_options returns the options that belong to a panel, preserving order.
@(private = "file")
collect_panel_options :: proc(options: []Flag_Info, panel: Panel) -> []Flag_Info {
	result := make([dynamic]Flag_Info, 0, len(panel.fields), context.temp_allocator)
	for opt in options {
		for field_name in panel.fields {
			if opt.field_name == field_name {
				append(&result, opt)
				break
			}
		}
	}
	return result[:]
}

// write_options_panel creates and renders a bordered options table with fixed column widths.
@(private = "file")
write_options_panel :: proc(
	w: io.Writer,
	opts: []Flag_Info,
	title: string,
	flag_prefix: string,
	parsing_style: flags.Parsing_Style,
	has_any_short: bool,
	theme: Theme,
	mode: term.Render_Mode,
	n: ^int,
	defaults_any: any,
	width: int,
	fixed_widths: []int,
) {
	if mode == .Plain {
		write_styled(w, fmt.tprintf("%s:", title), theme.heading_style, mode, n)
		io.write_string(w, "\n", n)
	}

	t := table.make_table(
		border = table.BORDER_ROUNDED,
		padding = 2,
		hide_column_separator = true,
		title = styled_content(title, theme.title_style),
		wrap = true,
		allocator = context.temp_allocator,
	)
	defer table.destroy_table(&t)
	// Lock only the flag column (0) to unified width for cross-panel alignment.
	// Type (1), description (2), and meta (3) are per-panel so wide enum choices
	// in one panel don't steal description space from other panels.
	for i in 0 ..< OPTION_COLUMNS {
		alignment: table.Alignment = i == 3 ? .Right : .Left
		if i == 0 && len(fixed_widths) > 0 {
			table.add_column(&t, alignment = alignment, min_width = fixed_widths[0], max_width = fixed_widths[0])
		} else {
			table.add_column(&t, alignment = alignment)
		}
	}

	add_option_rows(&t, opts, flag_prefix, parsing_style, has_any_short, theme, defaults_any)

	// Lock meta column to per-panel content width, letting description absorb extra space.
	lock_columns_except(&t, 2)
	if mode != .Plain {
		t.width = width
	}
	table.to_writer(w, t, n, mode)
}

// add_option_rows adds option flag rows to a table (4 columns expected).
@(private = "file")
add_option_rows :: proc(
	t: ^table.Table,
	opts: []Flag_Info,
	flag_prefix: string,
	parsing_style: flags.Parsing_Style,
	has_any_short: bool,
	theme: Theme,
	defaults_any: any,
) {
	for opt in opts {
		// Build flag name with optional short prefix.
		long_name: string
		if opt.is_boolean && parsing_style == .Unix {
			long_name = fmt.tprintf("%s[no-]%s", flag_prefix, opt.display_name)
		} else {
			long_name = fmt.tprintf("%s%s", flag_prefix, opt.display_name)
		}

		flag_str: string
		if len(opt.short_name) > 0 && parsing_style == .Unix {
			flag_str = fmt.tprintf("-%c, %s", opt.short_name[0], long_name)
		} else if has_any_short {
			flag_str = fmt.tprintf("    %s", long_name)
		} else {
			flag_str = long_name
		}

		// Type column: enum choices or type hint.
		type_str: string
		if opt.is_enum && len(opt.enum_names) > 0 {
			type_str = format_enum_choices(opt.enum_names)
		} else if !opt.is_boolean && !opt.is_count {
			type_str = opt.type_description
		}

		table.add_row(
			t,
			styled_content(flag_str, theme.flag_name_style),
			styled_content(type_str, opt.is_enum ? theme.choices_style : theme.type_style),
			styled_content(opt.usage, theme.description_style),
			build_meta(opt, theme, defaults_any),
		)
	}
}

// build_meta creates the metadata column content (e.g. "[env: VAR] [required]").
// Uses Rich_Text when multiple annotations need different styles.
@(private = "file")
build_meta :: proc(info: Flag_Info, theme: Theme, defaults_any: any = nil) -> table.Cell_Content {
	segments := make([dynamic]style.Styled_Text, 0, 4, context.temp_allocator)

	if len(info.group.name) > 0 {
		label: string
		switch info.group.mode {
		case .At_Most_One:  label = fmt.tprintf("[xor: %s]", info.group.name)
		case .Exactly_One:  label = fmt.tprintf("[one of: %s]", info.group.name)
		case .At_Least_One: label = fmt.tprintf("[any of: %s]", info.group.name)
		case .All_Or_None:  label = fmt.tprintf("[together: %s]", info.group.name)
		}
		append(&segments, style.Styled_Text{text = label, style = theme.meta_style})
	}

	// Range constraints.
	if min, min_ok := info.min_val.?; min_ok {
		if max, max_ok := info.max_val.?; max_ok {
			append(&segments, style.Styled_Text{
				text = fmt.tprintf("[%v..%v]", format_range_val(min), format_range_val(max)),
				style = theme.meta_style,
			})
		} else {
			append(&segments, style.Styled_Text{
				text = fmt.tprintf("[min: %v]", format_range_val(min)),
				style = theme.meta_style,
			})
		}
	} else if max, max_ok := info.max_val.?; max_ok {
		append(&segments, style.Styled_Text{
			text = fmt.tprintf("[max: %v]", format_range_val(max)),
			style = theme.meta_style,
		})
	}

	if info.is_multi {
		append(&segments, style.Styled_Text{text = "[multi]", style = theme.meta_style})
	}

	// Path constraints.
	if info.file_exists { append(&segments, style.Styled_Text{text = "[file]", style = theme.meta_style}) }
	if info.dir_exists  { append(&segments, style.Styled_Text{text = "[directory]", style = theme.meta_style}) }
	if info.path_exists { append(&segments, style.Styled_Text{text = "[path]", style = theme.meta_style}) }

	if len(info.env_var) > 0 {
		append(&segments, style.Styled_Text{text = fmt.tprintf("[env: %s]", info.env_var), style = theme.env_style})
	}

	if info.is_required {
		append(&segments, style.Styled_Text{text = "[required]", style = theme.required_style})
	} else if defaults_any != nil {
		field_val := reflect.struct_field_value_by_name(defaults_any, info.field_name)
		if field_val != nil && !is_zero_value(field_val) {
			append(&segments, style.Styled_Text{text = fmt.tprintf("[default: %v]", field_val), style = theme.default_style})
		}
	}

	if len(segments) == 0 do return nil
	if len(segments) == 1 do return segments[0]

	// Multiple annotations: build Rich_Text with space separators.
	with_spaces := make([dynamic]style.Styled_Text, 0, len(segments) * 2 - 1, context.temp_allocator)
	for seg, i in segments {
		if i > 0 {
			append(&with_spaces, style.Styled_Text{text = " "})
		}
		append(&with_spaces, seg)
	}
	return table.Rich_Text(with_spaces[:])
}

// format_enum_choices formats enum names as "{name1,name2,...}".
// normalize_enum_name lowercases an enum name and replaces underscores with
// hyphens to match core:flags parsing convention.
@(private)
normalize_enum_name :: proc(name: string) -> string {
	lower := strings.to_lower(name, context.temp_allocator)
	replaced, _ := strings.replace_all(lower, "_", "-", context.temp_allocator)
	return replaced
}

// format_enum_choices returns enum names as "{a,b,c}" for help display.
@(private = "file")
format_enum_choices :: proc(names: []string) -> string {
	sb := strings.builder_make(context.temp_allocator)
	strings.write_byte(&sb, '{')
	for name, i in names {
		if i > 0 do strings.write_byte(&sb, ',')
		strings.write_string(&sb, normalize_enum_name(name))
	}
	strings.write_byte(&sb, '}')
	return strings.to_string(sb)
}

// is_zero_value checks if a reflected value is the zero value for its type.
@(private)
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

// lock_columns_except locks all columns to their natural content width,
// except expand_col which absorbs extra space from t.width.
@(private = "file")
lock_columns_except :: proc(t: ^table.Table, expand_col: int) {
	natural := table.compute_column_widths(t^)
	for i in 0 ..< len(t.columns) {
		if i != expand_col && i < len(natural) {
			t.columns[i].min_width = natural[i]
			t.columns[i].max_width = natural[i]
		}
	}
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
