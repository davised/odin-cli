package cli

import "base:runtime"
import "../term"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"

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
	aliases:      []string,
	panel_config: []Panel,
	hidden:       bool,
	_run_proc:    _Run_Proc,
	_action_ptr:  rawptr,
	_flags_type:  typeid,
}

// App is the top-level multi-command application.
App :: struct {
	name:          string,
	version:       string,
	description:   string,
	commands:      [dynamic]Command,
	theme:         Theme,
	parsing_style: flags.Parsing_Style,
	max_width:     int,
	allocator:     runtime.Allocator,
}

// make_app creates a new App. Call destroy_app when done.
make_app :: proc(
	name: string,
	description: string = "",
	version: string = "",
	theme_override: Maybe(Theme) = nil,
	parsing_style: flags.Parsing_Style = .Unix,
	max_width: int = 0,
	allocator := context.allocator,
) -> App {
	return App {
		name          = name,
		description   = description,
		version       = version,
		commands      = make([dynamic]Command, allocator),
		theme         = theme_override.? or_else default_theme(),
		parsing_style = parsing_style,
		max_width     = max_width,
		allocator     = allocator,
	}
}

// destroy_app frees resources owned by the App.
destroy_app :: proc(app: ^App) {
	delete(app.commands)
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
) {
	// Monomorphized runner — Flags_Type is known at compile time here.
	runner :: proc(cmd: ^Command, args: []string, program: string, app: ^App, mode: term.Render_Mode) -> int {
		model: Flags_Type

		error := flags.parse(&model, args, app.parsing_style)
		if error != nil {
			_, is_help := error.(flags.Help_Request)
			if is_help {
				stdout := os.stream_from_handle(os.stdout)
				write_help(
					stdout, Flags_Type, program, app.parsing_style,
					nil, cmd.panel_config, app.theme,
					cmd.description, "", app.max_width, mode,
				)
				return 0
			}
			stderr := os.stream_from_handle(os.stderr)
			write_error(stderr, Flags_Type, error, program, app.parsing_style, app.theme, mode)
			return 1
		}

		if cmd._action_ptr != nil {
			action_proc := transmute(proc(^Flags_Type, string) -> int)cmd._action_ptr
			return action_proc(&model, program)
		}
		return 0
	}

	cmd := Command {
		name         = name,
		description  = description,
		aliases      = aliases,
		panel_config = panel_config,
		hidden       = hidden,
		_run_proc    = runner,
		_action_ptr  = transmute(rawptr)action,
		_flags_type  = Flags_Type,
	}

	append(&app.commands, cmd)
}

// run dispatches to the appropriate subcommand based on program_args.
// Returns the exit code.
run :: proc(app: ^App, program_args: []string) -> int {
	if len(program_args) == 0 do return 1

	program := filepath.base(program_args[0])
	args := program_args[1:] if len(program_args) > 1 else nil

	mode := term.detect_render_mode(os.stdout)
	stderr := os.stream_from_handle(os.stderr)
	stdout := os.stream_from_handle(os.stdout)

	Empty :: struct {}

	// No args: show app help with error exit.
	if len(args) == 0 {
		write_help(
			stdout, Empty, program, app.parsing_style,
			app.commands[:], nil, app.theme,
			app.description, app.version, app.max_width, mode,
		)
		return 1
	}

	// Top-level --help / -h (only if the first arg is a flag, not a command).
	first := args[0]
	is_flag := len(first) > 0 && first[0] == '-'
	if is_flag && is_help_flag(args, app.parsing_style) {
		write_help(
			stdout, Empty, program, app.parsing_style,
			app.commands[:], nil, app.theme,
			app.description, app.version, app.max_width, mode,
		)
		return 0
	}

	// Check for --version.
	if is_flag && len(app.version) > 0 && is_version_flag(args, app.parsing_style) {
		fmt.wprintfln(stdout, "%s %s", app.name, app.version)
		return 0
	}

	// Find matching command.
	cmd_name := args[0]
	cmd: ^Command
	for &c in app.commands {
		if c.name == cmd_name {
			cmd = &c
			break
		}
		for alias in c.aliases {
			if alias == cmd_name {
				cmd = &c
				break
			}
		}
		if cmd != nil do break
	}

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
	cmd_args := args[1:] if len(args) > 1 else nil

	return cmd._run_proc(cmd, cmd_args, cmd_program, app, mode)
}

// parse_or_exit is a drop-in replacement for flags.parse_or_exit with rich output.
parse_or_exit :: proc(
	model: ^$T,
	program_args: []string,
	parsing_style: flags.Parsing_Style = .Unix,
	panel_config: []Panel = nil,
	description: string = "",
	version: string = "",
	theme_override: Maybe(Theme) = nil,
	mode: Maybe(term.Render_Mode) = nil,
) {
	assert(len(program_args) > 0, "Program arguments slice is empty.")

	program := filepath.base(program_args[0])
	args: []string
	if len(program_args) > 1 {
		args = program_args[1:]
	}

	resolved_mode := resolve_mode(mode)

	// Check for --version before parsing.
	if len(version) > 0 && is_version_flag(args, parsing_style) {
		stdout := os.stream_from_handle(os.stdout)
		fmt.wprintfln(stdout, "%s %s", program, version)
		os.exit(0)
	}

	error := flags.parse(model, args, parsing_style)
	if error == nil do return

	_, is_help := error.(flags.Help_Request)
	if is_help {
		stdout := os.stream_from_handle(os.stdout)
		write_help(
			stdout, T, program, parsing_style,
			nil, panel_config, theme_override,
			description, version, 0, resolved_mode,
		)
		os.exit(0)
	}

	// Parse error.
	stderr := os.stream_from_handle(os.stderr)
	write_error(stderr, T, error, program, parsing_style, theme_override, resolved_mode)
	os.exit(1)
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
