// Rich CLI framework wrapping core:flags with styled help output, validation, and shell completions.
package cli

import "base:runtime"
import "../term"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"

// Panel defines a named group of flags for organized help output.
Panel :: struct {
	name:   string,   // "Authentication Options"
	fields: []string, // Odin struct field names in this group
}

// _Run_Proc is the type-erased command runner signature. Monomorphized per Flags_Type
// inside add_command, so it knows the concrete type for flags.parse.
@(private = "file")
_Run_Proc :: #type proc(
	cmd: ^Command,
	args: []string,
	program: string,
	app: ^App,
	mode: term.Render_Mode,
) -> int

// Command represents a subcommand with its own flags type and action.
Command :: struct {
	name:         string,
	description:  string,
	epilog:       string,
	aliases:      []string,
	panel_config: []Panel,
	hidden:       bool,
	subcommands:  [dynamic]Command,
	_run_proc:       _Run_Proc,
	_action_ptr:     rawptr,
	_validator_ptr:  rawptr,
	_flags_type:     typeid,
}

// _Global_Parse_Proc is the type-erased proc for parsing global flags.
@(private = "file")
_Global_Parse_Proc :: #type proc(rawptr, []string, flags.Parsing_Style) -> flags.Error

// App is the top-level multi-command application.
App :: struct {
	name:                string,
	version:             string,
	description:         string,
	commands:            [dynamic]Command,
	theme:               Theme,
	parsing_style:       flags.Parsing_Style,
	max_width:           int,
	allocator:           runtime.Allocator,
	_default_command:    string,
	_global_flags_type:  typeid,
	_global_flags_ptr:   rawptr,
	_global_parse_proc:  _Global_Parse_Proc,
}

// make_app creates a new App. Call destroy_app when done.
// default_command names a command to run when no subcommand is given
// (e.g. when the user passes only flags, or no args at all).
make_app :: proc(
	name: string,
	description: string = "",
	version: string = "",
	theme_override: Maybe(Theme) = nil,
	parsing_style: flags.Parsing_Style = .Unix,
	max_width: int = 0,
	default_command: string = "",
	allocator := context.allocator,
) -> App {
	return App {
		name             = name,
		description      = description,
		version          = version,
		commands         = make([dynamic]Command, allocator),
		theme            = theme_override.? or_else default_theme(),
		parsing_style    = parsing_style,
		max_width        = max_width,
		_default_command = default_command,
		allocator        = allocator,
	}
}

// set_global_flags registers a global flags struct with the App.
// Global flags are parsed from top-level args before command dispatch.
set_global_flags :: proc(app: ^App, $T: typeid, model: ^T) {
	app._global_flags_type = T
	app._global_flags_ptr = model
	app._global_parse_proc = proc(ptr: rawptr, args: []string, style: flags.Parsing_Style) -> flags.Error {
		return flags.parse((^T)(ptr), args, style)
	}
}

// destroy_app frees resources owned by the App.
destroy_app :: proc(app: ^App) {
	destroy_commands(app.commands[:])
	delete(app.commands)
}

// destroy_commands recursively frees subcommand dynamic arrays.
@(private = "file")
destroy_commands :: proc(commands: []Command) {
	for &cmd in commands {
		if len(cmd.subcommands) > 0 {
			destroy_commands(cmd.subcommands[:])
			delete(cmd.subcommands)
		}
	}
}

// add_command registers a subcommand. The action proc receives parsed flags
// and the program name, and returns an exit code. Uses $Flags_Type for
// monomorphization so flags.parse works with the concrete type.
add_command :: proc(
	app: ^App,
	$Flags_Type: typeid,
	name: string,
	description: string = "",
	action: proc(flags_val: ^Flags_Type, program: string) -> int = nil,
	aliases: []string = nil,
	panel_config: []Panel = nil,
	hidden: bool = false,
	epilog: string = "",
) {
	append(&app.commands, Command {
		name           = name,
		description    = description,
		epilog         = epilog,
		aliases        = aliases,
		panel_config   = panel_config,
		hidden         = hidden,
		_run_proc      = make_runner(Flags_Type),
		_action_ptr    = transmute(rawptr)action,
		_flags_type    = Flags_Type,
		subcommands    = make([dynamic]Command, app.allocator),
	})
}

// set_validator registers a custom validator for a command.
// The validator returns "" for success, or an error message string.
set_validator :: proc(app: ^App, command_name: string, $Flags_Type: typeid, validator: proc(flags_val: ^Flags_Type) -> string) {
	cmd := find_command(app.commands[:], command_name)
	assert(cmd != nil, fmt.tprintf("Command '%s' not found", command_name))
	cmd._validator_ptr = transmute(rawptr)validator
}

// add_subcommand registers a nested command under a parent.
// parent_path is a slash-separated path: "deploy" or "deploy/config".
add_subcommand :: proc(
	app: ^App,
	$Flags_Type: typeid,
	parent_path: string,
	name: string,
	description: string = "",
	action: proc(flags_val: ^Flags_Type, program: string) -> int = nil,
	aliases: []string = nil,
	panel_config: []Panel = nil,
	hidden: bool = false,
	epilog: string = "",
) {
	parent := find_command_by_path(app, parent_path)
	assert(parent != nil, fmt.tprintf("Parent command '%s' not found", parent_path))

	append(&parent.subcommands, Command {
		name           = name,
		description    = description,
		epilog         = epilog,
		aliases        = aliases,
		panel_config   = panel_config,
		hidden         = hidden,
		_run_proc      = make_runner(Flags_Type),
		_action_ptr    = transmute(rawptr)action,
		_flags_type    = Flags_Type,
		subcommands    = make([dynamic]Command, app.allocator),
	})
}

// set_subcommand_validator registers a custom validator for a nested command.
// parent_path is a slash-separated path to the parent, name is the subcommand name.
set_subcommand_validator :: proc(app: ^App, parent_path: string, name: string, $Flags_Type: typeid, validator: proc(flags_val: ^Flags_Type) -> string) {
	parent := find_command_by_path(app, parent_path)
	assert(parent != nil, fmt.tprintf("Parent command '%s' not found", parent_path))
	cmd := find_command(parent.subcommands[:], name)
	assert(cmd != nil, fmt.tprintf("Subcommand '%s' not found under '%s'", name, parent_path))
	cmd._validator_ptr = transmute(rawptr)validator
}

// find_command finds a command by name or alias in a command list.
@(private = "file")
find_command :: proc(commands: []Command, name: string) -> ^Command {
	for &c in commands {
		if c.name == name do return &c
		for alias in c.aliases {
			if alias == name do return &c
		}
	}
	return nil
}

// find_command_by_path finds a command by slash-separated path, e.g. "deploy/config".
// Supports aliases at each level.
@(private = "file")
find_command_by_path :: proc(app: ^App, path: string) -> ^Command {
	path := path
	segments := make([dynamic]string, 0, 4, context.temp_allocator)
	for segment in strings.split_iterator(&path, "/") {
		append(&segments, segment)
	}
	if len(segments) == 0 do return nil

	cmd := find_command(app.commands[:], segments[0])
	if cmd == nil do return nil

	for i := 1; i < len(segments); i += 1 {
		cmd = find_command(cmd.subcommands[:], segments[i])
		if cmd == nil do return nil
	}

	return cmd
}

// make_runner creates a monomorphized runner proc for a given Flags_Type.
@(private = "file")
make_runner :: proc($Flags_Type: typeid) -> _Run_Proc {
	runner :: proc(cmd: ^Command, args: []string, program: string, app: ^App, mode: term.Render_Mode) -> int {
		all_flags := extract_flags(Flags_Type)
		stdout := os.stream_from_handle(os.stdout)
		stderr := os.stream_from_handle(os.stderr)

		// Extract and parse global flags if configured.
		cmd_args := args
		global_infos: []Flag_Info
		if app._global_parse_proc != nil {
			global_infos = extract_flags(app._global_flags_type)
			remaining, g_ok := parse_global_flags(app, args, global_infos, stderr, program, mode)
			if !g_ok do return 1
			cmd_args = remaining
		}

		// Check for nested subcommand dispatch.
		if len(cmd.subcommands) > 0 && len(cmd_args) > 0 {
			first := cmd_args[0]
			is_flag := len(first) > 0 && first[0] == '-'
			if !is_flag {
				code, dispatched := dispatch_subcommand(cmd.subcommands[:], cmd_args, program, app, mode)
				if dispatched do return code
				// Not a known subcommand — fall through to parse as flags.
			}
		}

		// Greedy: intercept --help before parsing so it works even with invalid flags.
		if is_help_flag(cmd_args, app.parsing_style) {
			defaults: Flags_Type
			write_help(
				stdout, Flags_Type, program,
				Help_Config{
					parsing_style = app.parsing_style,
					commands = cmd.subcommands[:] if len(cmd.subcommands) > 0 else nil,
					panel_config = cmd.panel_config,
					theme = app.theme,
					description = cmd.description,
					epilog = cmd.epilog,
					max_width = app.max_width,
					mode = mode,
					defaults = &defaults,
					global_flags = global_infos,
					global_defaults = app._global_flags_ptr,
					global_type = app._global_flags_type,
				},
			)
			return 0
		}

		// Check for user-defined greedy flags.
		if greedy_field, found := find_greedy_flag(cmd_args, all_flags, app.parsing_style); found {
			model: Flags_Type
			set_bool_field(&model, Flags_Type, greedy_field, true)
			if cmd._action_ptr != nil {
				action_proc := cast(proc(^Flags_Type, string) -> int)cmd._action_ptr
				return action_proc(&model, program)
			}
			return 0
		}

		// Run preprocessing pipeline (short flags, env vars, negatable booleans).
		processed_args, preprocess_result := preprocess_args(cmd_args, all_flags, app.parsing_style)

		model: Flags_Type
		error := flags.parse(&model, processed_args, app.parsing_style)
		if error != nil {
			write_error(stderr, Flags_Type, error, program, app.parsing_style, app.theme, mode)
			return 1
		}

		// Apply count flags post-parse.
		if len(preprocess_result.counts) > 0 {
			apply_counts(&model, Flags_Type, preprocess_result.counts)
		}

		// Group validation (xor, one_of, any_of, together).
		if group_err := validate_groups(&model, Flags_Type, all_flags, app.parsing_style); len(group_err) > 0 {
			write_validation_error(stderr, group_err, program, app.parsing_style, app.theme, mode)
			return 1
		}

		// Range validation.
		if range_err := validate_ranges(&model, Flags_Type, all_flags, app.parsing_style, processed_args); len(range_err) > 0 {
			write_validation_error(stderr, range_err, program, app.parsing_style, app.theme, mode)
			return 1
		}

		// Path validation.
		if path_err := validate_paths(&model, Flags_Type, all_flags, app.parsing_style, processed_args); len(path_err) > 0 {
			write_validation_error(stderr, path_err, program, app.parsing_style, app.theme, mode)
			return 1
		}

		// Custom validator.
		if cmd._validator_ptr != nil {
			validator_proc := cast(proc(^Flags_Type) -> string)cmd._validator_ptr
			if val_err := validator_proc(&model); len(val_err) > 0 {
				write_validation_error(stderr, val_err, program, app.parsing_style, app.theme, mode)
				return 1
			}
		}

		if cmd._action_ptr != nil {
			action_proc := cast(proc(^Flags_Type, string) -> int)cmd._action_ptr
			return action_proc(&model, program)
		}

		// No action and has subcommands — show help.
		if len(cmd.subcommands) > 0 {
			defaults: Flags_Type
			write_help(
				stdout, Flags_Type, program,
				Help_Config{
					parsing_style = app.parsing_style,
					commands = cmd.subcommands[:],
					panel_config = cmd.panel_config,
					theme = app.theme,
					description = cmd.description,
					epilog = cmd.epilog,
					max_width = app.max_width,
					mode = mode,
					defaults = &defaults,
					global_flags = global_infos,
					global_defaults = app._global_flags_ptr,
					global_type = app._global_flags_type,
				},
			)
			return 1
		}
		return 0
	}
	return runner
}

// dispatch_default dispatches to the app's default command if one is configured.
// Returns (exit_code, true) if dispatched, (0, false) if no default command.
@(private = "file")
dispatch_default :: proc(app: ^App, program: string, args: []string, mode: term.Render_Mode) -> (int, bool) {
	if len(app._default_command) == 0 do return 0, false
	cmd := find_command(app.commands[:], app._default_command)
	if cmd == nil do return 0, false
	cmd_program := fmt.tprintf("%s %s", program, cmd.name)
	return cmd._run_proc(cmd, args, cmd_program, app, mode), true
}

// dispatch_subcommand tries to match the first arg against subcommands.
// Returns (exit_code, true) if dispatched, (0, false) if no match.
@(private = "file")
dispatch_subcommand :: proc(
	commands: []Command,
	args: []string,
	program: string,
	app: ^App,
	mode: term.Render_Mode,
) -> (int, bool) {
	c := find_command(commands, args[0])
	if c == nil do return 0, false

	cmd_program := fmt.tprintf("%s %s", program, c.name)
	cmd_args := args[1:] if len(args) > 1 else nil
	return c._run_proc(c, cmd_args, cmd_program, app, mode), true
}

// run dispatches to the appropriate subcommand based on program_args.
// Returns the exit code.
run :: proc(app: ^App, program_args: []string) -> int {
	if len(program_args) == 0 do return 1

	program := filepath.base(program_args[0])
	args := program_args[1:] if len(program_args) > 1 else nil

	mode := term.detect_render_mode(os.stdout)
	term.set_render_mode(mode)
	stderr := os.stream_from_handle(os.stderr)
	stdout := os.stream_from_handle(os.stdout)

	Empty :: struct {}

	// Validate default command configuration.
	if len(app._default_command) > 0 {
		if find_command(app.commands[:], app._default_command) == nil {
			panic(fmt.tprintf("default_command '%s' not found in registered commands", app._default_command))
		}
	}

	// Resolve global flags info for help rendering.
	global_infos: []Flag_Info
	if app._global_parse_proc != nil {
		global_infos = extract_flags(app._global_flags_type)
	}

	// Build reusable help config for app-level help.
	app_help := Help_Config{
		parsing_style = app.parsing_style,
		commands = app.commands[:],
		theme = app.theme,
		description = app.description,
		version = app.version,
		max_width = app.max_width,
		mode = mode,
		global_flags = global_infos,
		global_defaults = app._global_flags_ptr,
		global_type = app._global_flags_type,
		default_command = app._default_command,
	}

	// No args: dispatch to default command, or show app help.
	if len(args) == 0 {
		if code, ok := dispatch_default(app, program, nil, mode); ok do return code
		write_help(stdout, Empty, program, app_help)
		return 1
	}

	// Extract global args before checking flags/commands.
	remaining_args := args
	if app._global_parse_proc != nil && len(global_infos) > 0 {
		remaining, g_ok := parse_global_flags(app, args, global_infos, stderr, program, mode)
		if !g_ok do return 1
		remaining_args = remaining
	}

	// Top-level --help / -h (only if the first arg is a flag, not a command).
	first := remaining_args[0] if len(remaining_args) > 0 else ""
	is_flag := len(first) > 0 && first[0] == '-'
	if is_flag && is_help_flag(remaining_args, app.parsing_style) {
		write_help(stdout, Empty, program, app_help)
		return 0
	}

	// Check for --version.
	if is_flag && len(app.version) > 0 && is_version_flag(remaining_args, app.parsing_style) {
		fmt.wprintfln(stdout, "%s %s", app.name, app.version)
		return 0
	}

	// Check for --completions.
	if is_flag {
		if shell, ok := check_completions_flag(remaining_args, app.parsing_style); ok {
			write_completions(stdout, app, shell)
			return 0
		}
	}

	// First arg is a flag but not --help/--version/--completions: dispatch to default command,
	// or show help if no default is configured.
	if is_flag {
		if code, ok := dispatch_default(app, program, remaining_args, mode); ok do return code
		write_help(stdout, Empty, program, app_help)
		return 1
	}

	// Handle no remaining args after global extraction.
	if len(remaining_args) == 0 {
		if code, ok := dispatch_default(app, program, nil, mode); ok do return code
		write_help(stdout, Empty, program, app_help)
		return 1
	}

	// Find matching command.
	cmd_name := remaining_args[0]
	cmd := find_command(app.commands[:], cmd_name)

	if cmd == nil {
		write_styled(stderr, "Error: ", app.theme.error_style, mode, nil)
		fmt.wprintfln(stderr, "Unknown command '%s'.", cmd_name)

		if suggestion, ok := find_command_suggestion(cmd_name, app.commands[:]); ok {
			io.write_string(stderr, "\n")
			write_styled(stderr, "Did you mean ", app.theme.suggest_style, mode, nil)
			write_styled(stderr, suggestion, app.theme.command_style, mode, nil)
			write_styled(stderr, "?", app.theme.suggest_style, mode, nil)
			io.write_string(stderr, "\n")
		}
		return 1
	}

	// Dispatch to command.
	cmd_program := fmt.tprintf("%s %s", program, cmd.name)
	cmd_args := remaining_args[1:] if len(remaining_args) > 1 else nil

	return cmd._run_proc(cmd, cmd_args, cmd_program, app, mode)
}

// parse_or_exit is a drop-in replacement for flags.parse_or_exit with rich output.
// For custom validation, check the model after this proc returns.
// For the full-featured App API with built-in validators, use make_app + set_validator.
parse_or_exit :: proc(
	model: ^$T,
	program_args: []string,
	parsing_style: flags.Parsing_Style = .Unix,
	panel_config: []Panel = nil,
	description: string = "",
	version: string = "",
	epilog: string = "",
	theme_override: Maybe(Theme) = nil,
	mode: Maybe(term.Render_Mode) = nil,
	help_on_empty: bool = false,
) {
	assert(len(program_args) > 0, "Program arguments slice is empty.")

	program := filepath.base(program_args[0])
	args: []string
	if len(program_args) > 1 {
		args = program_args[1:]
	}

	resolved_mode := resolve_mode(mode)
	term.set_render_mode(resolved_mode)
	all_flags := extract_flags(T)

	// Check for --completions before help_on_empty (user may run `myapp --completions bash` with help_on_empty).
	if len(args) > 0 {
		if shell, ok := check_completions_flag(args, parsing_style); ok {
			stdout := os.stream_from_handle(os.stdout)
			write_flag_completions(stdout, program, T, shell, parsing_style)
			os.exit(0)
		}
	}

	// Show help when invoked with no arguments.
	if help_on_empty && len(args) == 0 {
		stdout := os.stream_from_handle(os.stdout)
		defaults: T
		write_help(
			stdout, T, program,
			Help_Config{
				parsing_style = parsing_style,
				panel_config = panel_config,
				theme = theme_override,
				description = description,
				version = version,
				epilog = epilog,
				mode = resolved_mode,
				defaults = &defaults,
			},
		)
		os.exit(0)
	}

	// Greedy: intercept --help and --version before parsing, so they
	// work even alongside invalid flags (e.g. `myapp --bad --help`).
	if is_help_flag(args, parsing_style) {
		stdout := os.stream_from_handle(os.stdout)
		defaults: T
		write_help(
			stdout, T, program,
			Help_Config{
				parsing_style = parsing_style,
				panel_config = panel_config,
				theme = theme_override,
				description = description,
				version = version,
				epilog = epilog,
				mode = resolved_mode,
				defaults = &defaults,
			},
		)
		os.exit(0)
	}
	if len(version) > 0 && is_version_flag(args, parsing_style) {
		stdout := os.stream_from_handle(os.stdout)
		fmt.wprintfln(stdout, "%s %s", program, version)
		os.exit(0)
	}

	// Check for user-defined greedy flags.
	if greedy_field, found := find_greedy_flag(args, all_flags, parsing_style); found {
		set_bool_field(model, T, greedy_field, true)
		return
	}

	// Run preprocessing pipeline (short flags, env vars, negatable booleans).
	processed_args, preprocess_result := preprocess_args(args, all_flags, parsing_style)

	error := flags.parse(model, processed_args, parsing_style)
	if error != nil {
		stderr := os.stream_from_handle(os.stderr)
		write_error(stderr, T, error, program, parsing_style, theme_override, resolved_mode)
		os.exit(1)
	}

	// Apply count flags post-parse.
	if len(preprocess_result.counts) > 0 {
		apply_counts(model, T, preprocess_result.counts)
	}

	// Group validation (xor, one_of, any_of, together).
	if group_err := validate_groups(model, T, all_flags, parsing_style); len(group_err) > 0 {
		stderr := os.stream_from_handle(os.stderr)
		theme := theme_override.? or_else default_theme()
		write_validation_error(stderr, group_err, program, parsing_style, theme, resolved_mode)
		os.exit(1)
	}

	// Range and path validation.
	{
		stderr := os.stream_from_handle(os.stderr)
		theme := theme_override.? or_else default_theme()

		if range_err := validate_ranges(model, T, all_flags, parsing_style, processed_args); len(range_err) > 0 {
			write_validation_error(stderr, range_err, program, parsing_style, theme, resolved_mode)
			os.exit(1)
		}
		if path_err := validate_paths(model, T, all_flags, parsing_style, processed_args); len(path_err) > 0 {
			write_validation_error(stderr, path_err, program, parsing_style, theme, resolved_mode)
			os.exit(1)
		}
	}
}

// Preprocess_Result holds the output of short flag preprocessing.
@(private)
Preprocess_Result :: struct {
	args:   []string,       // rewritten args for flags.parse
	counts: map[string]int, // field_name → count (for count flags)
}

// preprocess_short_flags rewrites short flags to their long equivalents.
// -v → --verbose, -v=val → --verbose=val, -o val → --output val
// -vvv → counts["verbose"] = 3 for count flags
@(private)
preprocess_short_flags :: proc(args: []string, flag_infos: []Flag_Info) -> Preprocess_Result {
	// Build short_char → Flag_Info lookup with collision detection.
	short_map := make(map[byte]Flag_Info, allocator = context.temp_allocator)
	for fi in flag_infos {
		if len(fi.short_name) > 0 {
			for ch in transmute([]u8)fi.short_name {
				if existing, has := short_map[ch]; has {
					assert(false, fmt.tprintf(
						"Short flag '-%c' collision: '%s' and '%s'",
						rune(ch), existing.field_name, fi.field_name,
					))
				}
				short_map[ch] = fi
			}
		}
	}

	if len(short_map) == 0 {
		return {args = args}
	}

	result := make([dynamic]string, 0, len(args), context.temp_allocator)
	counts := make(map[string]int, allocator = context.temp_allocator)

	i := 0
	for i < len(args) {
		arg := args[i]

		// Skip if not a short flag, or if it's a long flag (--).
		if len(arg) < 2 || arg[0] != '-' || arg[1] == '-' {
			append(&result, arg)
			i += 1
			continue
		}

		// Handle -X=value form (single char only, e.g. -o=file).
		if len(arg) > 3 && arg[2] == '=' {
			short_char := arg[1]
			if fi, ok := short_map[short_char]; ok {
				append(&result, fmt.tprintf("--%s=%s", fi.display_name, arg[3:]))
			} else {
				append(&result, arg) // unknown, pass through
			}
			i += 1
			continue
		}

		// Walk characters after the '-'.
		chars := arg[1:]
		j := 0
		unknown := false
		for j < len(chars) {
			ch := chars[j]
			fi, ok := short_map[ch]
			if !ok {
				// Unknown short flag — pass original arg through.
				append(&result, arg)
				unknown = true
				break
			}

			if fi.is_count {
				counts[fi.field_name] = (counts[fi.field_name] or_else 0) + 1
				j += 1
			} else if fi.is_boolean {
				append(&result, fmt.tprintf("--%s", fi.display_name))
				j += 1
			} else {
				// Value flag: consume rest of chars as value, or next arg.
				append(&result, fmt.tprintf("--%s", fi.display_name))
				rest := chars[j + 1:]
				if len(rest) > 0 {
					// -ofoo → --output=foo
					append(&result, string(rest))
				} else if i + 1 < len(args) {
					// -o foo → --output foo
					i += 1
					append(&result, args[i])
				}
				j = len(chars) // done with this arg
			}
		}

		i += 1
	}

	return {args = result[:], counts = counts}
}

// preprocess_args runs the full preprocessing pipeline: short flag expansion,
// env var injection, and negatable boolean rewriting. Returns the processed
// args and any count flag accumulations.
@(private = "file")
preprocess_args :: proc(args: []string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style) -> (processed: []string, result: Preprocess_Result) {
	if parsing_style != .Unix {
		return args, {}
	}
	result = preprocess_short_flags(args, flag_infos)
	processed = preprocess_env_vars(result.args, flag_infos, parsing_style)
	processed = preprocess_multi_flags(processed, flag_infos, parsing_style)
	processed = preprocess_negatable_booleans(processed, flag_infos)
	return
}

// preprocess_env_vars injects env var values for flags not already in args.
@(private = "file")
preprocess_env_vars :: proc(args: []string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style) -> []string {
	prefix := flag_prefix_for_style(parsing_style)

	// Collect flags with env vars.
	env_flags := make([dynamic]Flag_Info, 0, len(flag_infos), context.temp_allocator)
	for fi in flag_infos {
		if len(fi.env_var) > 0 {
			append(&env_flags, fi)
		}
	}
	if len(env_flags) == 0 do return args

	// Check which flags are already present in args.
	present := make(map[string]bool, allocator = context.temp_allocator)
	for arg in args {
		for fi in env_flags {
			long_flag := fmt.tprintf("%s%s", prefix, fi.display_name)
			if arg == long_flag || strings.has_prefix(arg, fmt.tprintf("%s=", long_flag)) {
				present[fi.field_name] = true
			}
		}
	}

	// Prepend env var values for missing flags.
	env_args := make([dynamic]string, 0, len(env_flags), context.temp_allocator)
	for fi in env_flags {
		if fi.field_name in present do continue
		if val, found := os.lookup_env(fi.env_var, context.temp_allocator); found {
			if fi.is_boolean {
				// For booleans, only inject if truthy.
				lower := strings.to_lower(val, context.temp_allocator)
				if lower == "1" || lower == "true" || lower == "yes" {
					append(&env_args, fmt.tprintf("%s%s", prefix, fi.display_name))
				}
			} else {
				append(&env_args, fmt.tprintf("%s%s=%s", prefix, fi.display_name, val))
			}
		}
	}

	if len(env_args) == 0 do return args

	// Combine: env-derived args + original CLI args.
	combined := make([dynamic]string, 0, len(env_args) + len(args), context.temp_allocator)
	append(&combined, ..env_args[:])
	append(&combined, ..args)
	return combined[:]
}

// parse_global_flags extracts global args from the input, preprocesses and parses them.
// Returns the remaining (non-global) args. On parse error, writes the error and returns ok=false.
@(private = "file")
parse_global_flags :: proc(
	app: ^App,
	args: []string,
	global_infos: []Flag_Info,
	stderr: io.Writer,
	program: string,
	mode: term.Render_Mode,
) -> (remaining: []string, ok: bool) {
	global_extracted, remaining_args := extract_global_args(args, global_infos, app.parsing_style)
	if len(global_extracted) > 0 {
		global_processed, _ := preprocess_args(global_extracted, global_infos, app.parsing_style)
		if g_err := app._global_parse_proc(app._global_flags_ptr, global_processed, app.parsing_style); g_err != nil {
			write_error(stderr, app._global_flags_type, g_err, program, app.parsing_style, app.theme, mode)
			return nil, false
		}
	}
	return remaining_args, true
}

// extract_global_args splits args into global flag args and remaining args.
@(private)
extract_global_args :: proc(
	args: []string,
	global_infos: []Flag_Info,
	parsing_style: flags.Parsing_Style,
) -> (global_args, remaining_args: []string) {
	prefix := flag_prefix_for_style(parsing_style)

	// Build lookup maps.
	name_map := make(map[string]Flag_Info, allocator = context.temp_allocator)
	short_map := make(map[byte]Flag_Info, allocator = context.temp_allocator)
	for fi in global_infos {
		name_map[fi.display_name] = fi
		if len(fi.short_name) > 0 && parsing_style == .Unix {
			for ch in transmute([]u8)fi.short_name {
				short_map[ch] = fi
			}
		}
	}

	global := make([dynamic]string, 0, len(args), context.temp_allocator)
	remaining := make([dynamic]string, 0, len(args), context.temp_allocator)

	i := 0
	for i < len(args) {
		arg := args[i]

		// Check --flag=value or --flag forms.
		if strings.has_prefix(arg, prefix) {
			rest := arg[len(prefix):]
			name := rest
			if eq := strings.index_byte(rest, '='); eq != -1 {
				name = rest[:eq]
			}

			// Direct match.
			if fi, ok := name_map[name]; ok {
				append(&global, arg)
				// If --flag (no =) and non-bool, consume next arg as value.
				if strings.index_byte(rest, '=') == -1 && !fi.is_boolean {
					if i + 1 < len(args) {
						i += 1
						append(&global, args[i])
					}
				}
				i += 1
				continue
			}

			// Check --no-{name} for negatable boolean globals.
			if parsing_style == .Unix && strings.has_prefix(name, "no-") {
				base_name := name[3:]
				if fi, nok := name_map[base_name]; nok && fi.is_boolean {
					append(&global, arg)
					i += 1
					continue
				}
			}
		}

		// Check -X short flag (Unix only).
		if parsing_style == .Unix && len(arg) == 2 && arg[0] == '-' && arg[1] != '-' {
			if fi, ok := short_map[arg[1]]; ok {
				append(&global, arg)
				if !fi.is_boolean {
					if i + 1 < len(args) {
						i += 1
						append(&global, args[i])
					}
				}
				i += 1
				continue
			}
		}

		// Everything else → remaining.
		append(&remaining, arg)
		i += 1
	}

	return global[:], remaining[:]
}

// preprocess_multi_flags merges repeated occurrences of multi-tagged flags by
// comma-joining their values into a single --flag=v1,v2,... arg.
@(private)
preprocess_multi_flags :: proc(args: []string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style) -> []string {
	prefix := flag_prefix_for_style(parsing_style)

	// Build lookup of multi flag display names.
	multi_names := make(map[string]bool, allocator = context.temp_allocator)
	for fi in flag_infos {
		if fi.is_multi {
			multi_names[fi.display_name] = true
		}
	}
	if len(multi_names) == 0 do return args

	// Pass 1: Collect values per multi flag name, track consumed indices and first occurrence.
	Flag_Data :: struct {
		values:    [dynamic]string,
		first_idx: int,
	}
	collected := make(map[string]Flag_Data, allocator = context.temp_allocator)
	consumed := make(map[int]bool, allocator = context.temp_allocator)
	first_idx_to_name := make(map[int]string, allocator = context.temp_allocator)

	i := 0
	for i < len(args) {
		arg := args[i]

		if strings.has_prefix(arg, prefix) {
			rest := arg[len(prefix):]
			name: string
			value: string
			has_eq := false

			if eq := strings.index_byte(rest, '='); eq != -1 {
				name = rest[:eq]
				value = rest[eq + 1:]
				has_eq = true
			} else {
				name = rest
			}

			if name in multi_names {
				if name not_in collected {
					collected[name] = Flag_Data{
						values    = make([dynamic]string, 0, 4, context.temp_allocator),
						first_idx = i,
					}
					first_idx_to_name[i] = name
				}
				entry := &collected[name]

				if has_eq {
					append(&entry.values, value)
					consumed[i] = true
				} else if i + 1 < len(args) {
					append(&entry.values, args[i + 1])
					consumed[i] = true
					consumed[i + 1] = true
					i += 1
				} else {
					// Bare multi flag at end of args — consume it so it
					// doesn't appear as a duplicate. flags.parse will
					// handle the missing-value error on the merged form.
					consumed[i] = true
				}
			}
		}
		i += 1
	}

	// If no multi flag appeared more than once, return args unchanged.
	any_merged := false
	for _, data in collected {
		if len(data.values) > 1 {
			any_merged = true
			break
		}
	}
	if !any_merged do return args

	// Pass 2: Rebuild args — emit merged --flag=v1,v2 at first occurrence, skip rest.
	result := make([dynamic]string, 0, len(args), context.temp_allocator)
	for idx in 0 ..< len(args) {
		if idx in consumed {
			if name, is_first := first_idx_to_name[idx]; is_first {
				data := collected[name]
				if len(data.values) > 1 {
					joined := strings.join(data.values[:], ",", context.temp_allocator)
					append(&result, fmt.tprintf("%s%s=%s", prefix, name, joined))
				} else if len(data.values) == 1 {
					// Single occurrence — re-emit in original form.
					append(&result, fmt.tprintf("%s%s", prefix, name))
					append(&result, data.values[0])
				}
			}
		} else {
			append(&result, args[idx])
		}
	}
	return result[:]
}

// preprocess_negatable_booleans rewrites --no-flag to --flag=false for boolean flags.
// If a flag literally named "no-{name}" exists, it takes precedence (pass through).
// Only applies to Unix parsing style.
@(private)
preprocess_negatable_booleans :: proc(args: []string, flag_infos: []Flag_Info) -> []string {
	// Build lookup maps.
	bool_flags := make(map[string]bool, allocator = context.temp_allocator) // display_name → true for booleans
	all_names := make(map[string]bool, allocator = context.temp_allocator)  // all display_names
	for fi in flag_infos {
		all_names[fi.display_name] = true
		if fi.is_boolean {
			bool_flags[fi.display_name] = true
		}
	}

	result := make([dynamic]string, 0, len(args), context.temp_allocator)
	for arg in args {
		// Only process args starting with "--no-".
		if !strings.has_prefix(arg, "--no-") {
			append(&result, arg)
			continue
		}

		// Strip --no- prefix, and any =value suffix.
		rest := arg[5:] // after "--no-"
		name := rest
		if eq := strings.index_byte(rest, '='); eq != -1 {
			name = rest[:eq]
		}

		// If a flag literally named "no-{name}" exists, pass through.
		negated_name := fmt.tprintf("no-%s", name)
		if negated_name in all_names {
			append(&result, arg)
			continue
		}

		// If {name} is a known boolean flag, rewrite.
		if name in bool_flags {
			append(&result, fmt.tprintf("--%s=false", name))
			continue
		}

		// Unknown — pass through.
		append(&result, arg)
	}
	return result[:]
}

// find_greedy_flag scans args for any flag marked as greedy.
@(private = "file")
find_greedy_flag :: proc(args: []string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style) -> (field_name: string, ok: bool) {
	prefix := flag_prefix_for_style(parsing_style)
	for arg in args {
		for fi in flag_infos {
			if !fi.is_greedy do continue
			long_flag := fmt.tprintf("%s%s", prefix, fi.display_name)
			if arg == long_flag do return fi.field_name, true
			// Also check short name.
			if len(fi.short_name) > 0 && parsing_style == .Unix {
				short_flag := fmt.tprintf("-%s", fi.short_name)
				if arg == short_flag do return fi.field_name, true
			}
		}
	}
	return "", false
}

// set_bool_field sets a bool struct field by name via reflection.
@(private = "file")
set_bool_field :: proc(model: rawptr, type_id: typeid, field_name: string, value: bool) {
	fields := reflect.struct_fields_zipped(type_id)
	for field in fields {
		if field.name == field_name {
			assert(reflect.is_boolean(field.type), "greedy flag must be bool")
			ptr := rawptr(uintptr(model) + field.offset)
			(^bool)(ptr)^ = value
			return
		}
	}
}

// apply_counts sets int fields from the counts map via reflection.
@(private = "file")
apply_counts :: proc(model: rawptr, type_id: typeid, counts: map[string]int) {
	fields := reflect.struct_fields_zipped(type_id)
	for field in fields {
		if count, ok := counts[field.name]; ok {
			if field.type.id != int do continue
			ptr := rawptr(uintptr(model) + field.offset)
			(^int)(ptr)^ = count
		}
	}
}

// validate_groups checks flag group constraints (xor, one_of, any_of, together).
// Returns an error message on violation, or "" on success.
@(private = "file")
validate_groups :: proc(
	model: rawptr,
	type_id: typeid,
	flag_infos: []Flag_Info,
	parsing_style: flags.Parsing_Style,
) -> (error_msg: string) {
	prefix := flag_prefix_for_style(parsing_style)

	// Collect flags into groups by name, preserving the mode from the first member.
	Group_Entry :: struct {
		mode:    Group_Mode,
		members: [dynamic]Flag_Info,
	}
	groups := make(map[string]Group_Entry, allocator = context.temp_allocator)
	for fi in flag_infos {
		if len(fi.group.name) == 0 do continue
		if fi.group.name not_in groups {
			groups[fi.group.name] = Group_Entry{
				mode    = fi.group.mode,
				members = make([dynamic]Flag_Info, 0, 4, context.temp_allocator),
			}
		}
		entry := &groups[fi.group.name]
		assert(entry.mode == fi.group.mode, fmt.tprintf(
			"Flag '%s' has group mode '%v' but group '%s' was declared as '%v'",
			fi.field_name, fi.group.mode, fi.group.name, entry.mode,
		))
		append(&entry.members, fi)
	}

	model_any := any{model, type_id}
	errors := make([dynamic]string, 0, len(groups), context.temp_allocator)

	for group_name, entry in groups {
		set_names := make([dynamic]string, 0, len(entry.members), context.temp_allocator)
		all_names := make([dynamic]string, 0, len(entry.members), context.temp_allocator)
		for fi in entry.members {
			append(&all_names, fmt.tprintf("%s%s", prefix, fi.display_name))
			field_val := reflect.struct_field_value_by_name(model_any, fi.field_name)
			if field_val != nil && !is_zero_value(field_val) {
				append(&set_names, fmt.tprintf("%s%s", prefix, fi.display_name))
			}
		}

		set_count := len(set_names)
		total := len(entry.members)
		all_joined := strings.join(all_names[:], ", ", context.temp_allocator)
		set_joined := strings.join(set_names[:], ", ", context.temp_allocator)

		switch entry.mode {
		case .At_Most_One:
			if set_count > 1 {
				append(&errors, fmt.tprintf(
					"Flags %s cannot be used together (group '%s').",
					set_joined, group_name,
				))
			}
		case .Exactly_One:
			if set_count != 1 {
				append(&errors, fmt.tprintf(
					"Exactly one of %s must be specified (group '%s').",
					all_joined, group_name,
				))
			}
		case .At_Least_One:
			if set_count == 0 {
				append(&errors, fmt.tprintf(
					"At least one of %s must be specified (group '%s').",
					all_joined, group_name,
				))
			}
		case .All_Or_None:
			if set_count > 0 && set_count < total {
				append(&errors, fmt.tprintf(
					"Flags %s must all be specified together, or none at all (group '%s').",
					all_joined, group_name,
				))
			}
		}
	}

	if len(errors) > 0 {
		return strings.join(errors[:], "\n", context.temp_allocator)
	}
	return ""
}

// validate_ranges checks that numeric flag values fall within min/max bounds.
// Uses args to determine if a flag was explicitly provided (not relying on zero-value detection).
// Returns an error message on violation, or "" on success.
@(private = "file")
validate_ranges :: proc(
	model: rawptr,
	type_id: typeid,
	flag_infos: []Flag_Info,
	parsing_style: flags.Parsing_Style,
	args: []string,
) -> (error_msg: string) {
	prefix := flag_prefix_for_style(parsing_style)
	model_any := any{model, type_id}
	errors := make([dynamic]string, 0, 4, context.temp_allocator)

	for fi in flag_infos {
		has_min := fi.min_val != nil
		has_max := fi.max_val != nil
		if !has_min && !has_max do continue

		// Skip if the flag was not explicitly provided on the command line.
		if !was_flag_provided(fi, args, parsing_style) do continue

		field_val := reflect.struct_field_value_by_name(model_any, fi.field_name)
		if field_val == nil do continue

		value, ok := get_numeric_value(field_val)
		if !ok do continue

		if min_v, min_ok := fi.min_val.?; min_ok && value < min_v {
			if max_v, max_ok := fi.max_val.?; max_ok {
				append(&errors, fmt.tprintf(
					"Value %v for %s%s is out of range [%v, %v].",
					format_range_val(value), prefix, fi.display_name,
					format_range_val(min_v), format_range_val(max_v),
				))
			} else {
				append(&errors, fmt.tprintf(
					"Value %v for %s%s must be at least %v.",
					format_range_val(value), prefix, fi.display_name,
					format_range_val(min_v),
				))
			}
			continue
		}

		if max_v, max_ok := fi.max_val.?; max_ok && value > max_v {
			if min_v, min_ok := fi.min_val.?; min_ok {
				append(&errors, fmt.tprintf(
					"Value %v for %s%s is out of range [%v, %v].",
					format_range_val(value), prefix, fi.display_name,
					format_range_val(min_v), format_range_val(max_v),
				))
			} else {
				append(&errors, fmt.tprintf(
					"Value %v for %s%s must be at most %v.",
					format_range_val(value), prefix, fi.display_name,
					format_range_val(max_v),
				))
			}
		}
	}

	if len(errors) > 0 {
		return strings.join(errors[:], "\n", context.temp_allocator)
	}
	return ""
}

// validate_paths checks that string flag values point to existing files/dirs/paths.
// Uses args to determine if a flag was explicitly provided.
// Returns an error message on violation, or "" on success.
@(private = "file")
validate_paths :: proc(
	model: rawptr,
	type_id: typeid,
	flag_infos: []Flag_Info,
	parsing_style: flags.Parsing_Style,
	args: []string,
) -> (error_msg: string) {
	prefix := flag_prefix_for_style(parsing_style)
	model_any := any{model, type_id}
	errors := make([dynamic]string, 0, 4, context.temp_allocator)

	for fi in flag_infos {
		if !fi.file_exists && !fi.dir_exists && !fi.path_exists do continue

		field_val := reflect.struct_field_value_by_name(model_any, fi.field_name)
		if field_val == nil do continue

		// For paths, skip only if the string is empty (not provided).
		if is_zero_value(field_val) do continue

		// Verify the field is a string type before casting.
		field_ti := runtime.type_info_base(type_info_of(field_val.id))
		if _, is_string := field_ti.variant.(runtime.Type_Info_String); !is_string do continue

		path := (^string)(field_val.data)^
		if len(path) == 0 do continue

		exists := os.exists(path)
		if !exists {
			append(&errors, fmt.tprintf(
				"Path '%s' for %s%s does not exist.",
				path, prefix, fi.display_name,
			))
			continue
		}

		if fi.file_exists && os.is_dir(path) {
			append(&errors, fmt.tprintf(
				"Path '%s' for %s%s is not a file.",
				path, prefix, fi.display_name,
			))
		} else if fi.dir_exists && !os.is_dir(path) {
			append(&errors, fmt.tprintf(
				"Path '%s' for %s%s is not a directory.",
				path, prefix, fi.display_name,
			))
		}
	}

	if len(errors) > 0 {
		return strings.join(errors[:], "\n", context.temp_allocator)
	}
	return ""
}

// was_flag_provided checks if a flag was explicitly provided in the command-line args.
// Handles both --flag=value and --flag value forms, as well as positional args.
@(private = "file")
was_flag_provided :: proc(fi: Flag_Info, args: []string, parsing_style: flags.Parsing_Style) -> bool {
	if fi.is_positional {
		// Positional args: count non-flag args and check if enough were provided.
		pos_count := 0
		for arg in args {
			if len(arg) > 0 && arg[0] == '-' do continue
			if pos_count == fi.pos do return true
			pos_count += 1
		}
		return false
	}

	prefix := flag_prefix_for_style(parsing_style)
	long_flag := fmt.tprintf("%s%s", prefix, fi.display_name)

	for arg in args {
		if arg == long_flag do return true
		if strings.has_prefix(arg, long_flag) && len(arg) > len(long_flag) && arg[len(long_flag)] == '=' {
			return true
		}
	}
	return false
}

// get_numeric_value extracts a float64 from a reflected integer or float value.
@(private = "file")
get_numeric_value :: proc(val: any) -> (value: f64, ok: bool) {
	ti := runtime.type_info_base(type_info_of(val.id))

	#partial switch info in ti.variant {
	case runtime.Type_Info_Integer:
		if info.signed {
			switch ti.size {
			case 1: return f64((^i8)(val.data)^), true
			case 2: return f64((^i16)(val.data)^), true
			case 4: return f64((^i32)(val.data)^), true
			case 8: return f64((^i64)(val.data)^), true
			}
		} else {
			switch ti.size {
			case 1: return f64((^u8)(val.data)^), true
			case 2: return f64((^u16)(val.data)^), true
			case 4: return f64((^u32)(val.data)^), true
			case 8: return f64((^u64)(val.data)^), true
			}
		}
	case runtime.Type_Info_Float:
		switch ti.size {
		case 4: return f64((^f32)(val.data)^), true
		case 8: return (^f64)(val.data)^, true
		}
	}
	return 0, false
}

// format_range_val displays a number without decimal point if it's a whole number.
@(private)
format_range_val :: proc(v: f64) -> string {
	if v == f64(int(v)) {
		return fmt.tprintf("%d", int(v))
	}
	return fmt.tprintf("%g", v)
}

// write_validation_error renders a styled validation error with a help hint footer.
@(private)
write_validation_error :: proc(
	w: io.Writer,
	message: string,
	program: string,
	parsing_style: flags.Parsing_Style,
	theme: Theme,
	mode: term.Render_Mode,
	n: ^int = nil,
) {
	prefix := flag_prefix_for_style(parsing_style)
	write_styled(w, "Error: ", theme.error_style, mode, n)
	io.write_string(w, message, n)
	io.write_string(w, "\n", n)
	io.write_string(w, "\n", n)
	write_styled(w, "For more information, try ", theme.meta_style, mode, n)
	write_styled(w, fmt.tprintf("%shelp", prefix), theme.flag_name_style, mode, n)
	write_styled(w, ".", theme.meta_style, mode, n)
	io.write_string(w, "\n", n)
}

// resolve_mode determines the render mode, auto-detecting from stdout if not specified.
@(private = "file")
resolve_mode :: proc(mode: Maybe(term.Render_Mode)) -> term.Render_Mode {
	if m, ok := mode.?; ok {
		return m
	}
	return term.detect_render_mode(os.stdout)
}

// is_help_flag checks if args contain a help flag.
@(private = "file")
is_help_flag :: proc(args: []string, parsing_style: flags.Parsing_Style) -> bool {
	for arg in args {
		switch parsing_style {
		case .Unix:
			if arg == "--help" || arg == "-h" do return true
		case .Odin:
			if arg == "-help" || arg == "-h" do return true
		}
	}
	return false
}

// is_version_flag checks if args contain a version flag.
@(private = "file")
is_version_flag :: proc(args: []string, parsing_style: flags.Parsing_Style) -> bool {
	for arg in args {
		switch parsing_style {
		case .Unix:
			if arg == "--version" do return true
		case .Odin:
			if arg == "-version" do return true
		}
	}
	return false
}

// parse_shell_name converts a shell name string to a Shell enum value.
@(private = "file")
parse_shell_name :: proc(name: string) -> (Shell, bool) {
	switch name {
	case "bash": return .Bash, true
	case "zsh":  return .Zsh, true
	case "fish": return .Fish, true
	}
	return {}, false
}

// check_completions_flag scans args for --completions <shell> (Unix) or -completions <shell> (Odin).
// Returns the shell and true if found.
@(private = "file")
check_completions_flag :: proc(args: []string, parsing_style: flags.Parsing_Style) -> (shell: Shell, ok: bool) {
	flag: string
	switch parsing_style {
	case .Unix: flag = "--completions"
	case .Odin: flag = "-completions"
	}
	for arg, i in args {
		if arg == flag && i + 1 < len(args) {
			if s, s_ok := parse_shell_name(args[i + 1]); s_ok do return s, true
		}
		// Also handle --completions=bash form.
		if strings.has_prefix(arg, flag) && len(arg) > len(flag) && arg[len(flag)] == '=' {
			if s, s_ok := parse_shell_name(arg[len(flag) + 1:]); s_ok do return s, true
		}
	}
	return {}, false
}

// find_command_suggestion finds the closest matching command name.
@(private = "file")
find_command_suggestion :: proc(unknown: string, commands: []Command) -> (string, bool) {
	best_name: string
	best_dist := max(int)
	threshold := max(3, len(unknown) / 2)

	for cmd in commands {
		if cmd.hidden do continue
		dist := levenshtein(unknown, cmd.name)
		if dist < best_dist {
			best_dist = dist
			best_name = cmd.name
		}
		for alias in cmd.aliases {
			dist = levenshtein(unknown, alias)
			if dist < best_dist {
				best_dist = dist
				best_name = alias
			}
		}
	}

	if best_dist <= threshold {
		return best_name, true
	}
	return "", false
}
