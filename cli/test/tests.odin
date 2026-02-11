package cli_test

import "core:flags"
import "core:strings"
import "core:testing"
import cli ".."

// --- Test struct (local copy for public API tests) ---

Test_Options :: struct {
	input:   string `args:"pos=0,required" usage:"Input file"`,
	output:  string `args:"pos=1" usage:"Output destination"`,
	verbose: bool   `args:"short=v" usage:"Show verbose output"`,
	count:   int    `usage:"Number of iterations"`,
	format:  string `usage:"Output format"`,
	hidden:  string `args:"hidden" usage:"Internal flag"`,
	name_override: string `args:"name=custom-name" usage:"Custom named flag"`,
}

// --- Enum types used by help display tests ---

Format :: enum {
	Json,
	Yaml,
	Toml,
}

// --- write_help tests ---

@(test)
test_write_help_contains_usage :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Usage:"), "Should contain 'Usage:'")
	testing.expect(t, strings.contains(output, "test-prog"), "Should contain program name")
}

@(test)
test_write_help_contains_arguments :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Arguments:"), "Should contain 'Arguments:' section")
	testing.expect(t, strings.contains(output, "INPUT"), "Should show positional args in uppercase")
}

@(test)
test_write_help_contains_options :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Options:"), "Should contain 'Options:' section")
	testing.expect(t, strings.contains(output, "--[no-]verbose"), "Should show verbose flag")
	testing.expect(t, strings.contains(output, "--count"), "Should show count flag")
}

@(test)
test_write_help_hides_hidden :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, !strings.contains(output, "--hidden"), "Should not show hidden flag")
}

@(test)
test_write_help_description :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, description = "My tool.", mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "My tool."), "Should contain description")
}

@(test)
test_write_help_panels :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	panels := []cli.Panel{
		{name = "Output Config", fields = {"format"}},
	}

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, panel_config = panels, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Output Config:"), "Should contain panel heading")
	testing.expect(t, strings.contains(output, "--format"), "Should show format in panel")
}

@(test)
test_write_help_required_marker :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[required]"), "Should mark required args")
}

@(test)
test_write_help_odin_style :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Odin, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "-verbose"), "Should use single-dash for Odin style")
	testing.expect(t, !strings.contains(output, "--verbose"), "Should not use double-dash for Odin style")
}

// --- Short flag display in help ---

@(test)
test_write_help_short_flag_display :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "-v, --[no-]verbose"), "Should show short flag format")
}

@(test)
test_write_help_short_flag_alignment :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool `args:"short=v" usage:"Verbose"`,
		debug:   bool `usage:"Debug mode"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	// Flags without short names should be indented to align.
	testing.expect(t, strings.contains(output, "-v, --[no-]verbose"), "Should show short flag")
	testing.expect(t, strings.contains(output, "      --[no-]debug"), "Should indent flags without short name")
}

// --- Default values in help ---

@(test)
test_write_help_default_values :: proc(t: ^testing.T) {
	Opts :: struct {
		format: string `usage:"Output format"`,
		count:  int    `usage:"Iterations"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	defaults := Opts{format = "json", count = 10}
	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain, defaults = &defaults})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[default: json]"), "Should show string default")
	testing.expect(t, strings.contains(output, "[default: 10]"), "Should show int default")
}

@(test)
test_write_help_no_default_for_zero :: proc(t: ^testing.T) {
	Opts :: struct {
		count: int `usage:"Iterations"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	defaults := Opts{} // zero value
	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain, defaults = &defaults})
	output := strings.to_string(sb)

	testing.expect(t, !strings.contains(output, "[default:"), "Should not show default for zero value")
}

@(test)
test_write_help_no_default_for_required :: proc(t: ^testing.T) {
	Opts :: struct {
		token: string `args:"required" usage:"API token"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	defaults := Opts{token = "xxx"}
	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain, defaults = &defaults})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[required]"), "Should show required")
	testing.expect(t, !strings.contains(output, "[default:"), "Should not show default for required flag")
}

// --- Env var display in help ---

@(test)
test_write_help_env_var_display :: proc(t: ^testing.T) {
	Opts :: struct {
		token: string `args:"env=API_TOKEN,required" usage:"API token"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[env: API_TOKEN]"), "Should show env var")
	testing.expect(t, strings.contains(output, "[required]"), "Should also show required")
}

// --- Enum choices display in help ---

@(test)
test_write_help_enum_choices :: proc(t: ^testing.T) {
	Opts :: struct {
		format: Format `usage:"Output format"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "{json,yaml,toml}"), "Should show enum choices")
	testing.expect(t, !strings.contains(output, "<"), "Should not show type hint for enum")
}

@(test)
test_write_help_enum_with_underscores :: proc(t: ^testing.T) {
	My_Format :: enum {
		Plain_Text,
		Rich_Html,
	}
	Opts :: struct {
		format: My_Format `usage:"Output format"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "{plain-text,rich-html}"), "Should lowercase and replace underscores")
}

// --- write_error tests ---

@(test)
test_write_error_parse_error :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	err := flags.Error(flags.Parse_Error{
		reason  = flags.Parse_Error_Reason.Bad_Value,
		message = "Invalid value 'abc' for flag.",
	})

	cli.write_error(w, Test_Options, err, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Error:"), "Should contain 'Error:'")
	testing.expect(t, strings.contains(output, "Invalid value"), "Should contain error message")
	testing.expect(t, strings.contains(output, "--help"), "Should suggest --help")
}

@(test)
test_write_error_suggestion :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	err := flags.Error(flags.Parse_Error{
		reason  = flags.Parse_Error_Reason.Missing_Flag,
		message = "Unable to find any flag named `verbos`.",
	})

	cli.write_error(w, Test_Options, err, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Did you mean"), "Should contain 'Did you mean'")
	testing.expect(t, strings.contains(output, "--verbose"), "Should suggest --verbose")
}

// --- Commands tests ---

@(test)
test_write_help_commands :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	Dummy :: struct {}
	commands := []cli.Command{
		{name = "init", description = "Initialize a project"},
		{name = "build", description = "Build the project"},
		{name = "secret", description = "Hidden command", hidden = true},
	}

	cli.write_help(w, Dummy, "myapp", cli.Help_Config{parsing_style = .Unix, commands = commands, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Commands:"), "Should contain 'Commands:' section")
	testing.expect(t, strings.contains(output, "init"), "Should show init command")
	testing.expect(t, strings.contains(output, "build"), "Should show build command")
	testing.expect(t, !strings.contains(output, "secret"), "Should not show hidden command")
}

// --- Theme tests ---

@(test)
test_default_theme_has_styles :: proc(t: ^testing.T) {
	theme := cli.default_theme()
	testing.expect(t, theme.heading_style.text_styles != {}, "Heading should have text styles")
	testing.expect(t, theme.error_style.foreground_color != nil, "Error should have color")
}

@(test)
test_plain_theme_is_empty :: proc(t: ^testing.T) {
	theme := cli.plain_theme()
	testing.expect(t, theme.heading_style.text_styles == {}, "Plain heading should have no styles")
	testing.expect(t, theme.error_style.foreground_color == nil, "Plain error should have no color")
}

// --- Theme: env_style and choices_style ---

@(test)
test_default_theme_has_env_and_choices :: proc(t: ^testing.T) {
	theme := cli.default_theme()
	testing.expect(t, theme.env_style.foreground_color != nil, "Env style should have color")
	testing.expect(t, theme.choices_style.foreground_color != nil, "Choices style should have color")
}

// --- Combined features test ---

@(test)
test_write_help_combined_features :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool   `args:"short=v"        usage:"Verbose output"`,
		output:  string `args:"short=o"        usage:"Output file"`,
		format:  Format `args:"env=MY_FORMAT"  usage:"Output format"`,
		token:   string `args:"env=TOKEN,required" usage:"Auth token"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	defaults := Opts{format = .Yaml} // Yaml is non-zero (not first variant)
	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain, defaults = &defaults})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "-v, --[no-]verbose"), "Should show -v short flag")
	testing.expect(t, strings.contains(output, "-o, --output"), "Should show -o short flag") // not boolean, no [no-]
	testing.expect(t, strings.contains(output, "{json,yaml,toml}"), "Should show enum choices for format")
	testing.expect(t, strings.contains(output, "[env: MY_FORMAT]"), "Should show env var for format")
	testing.expect(t, strings.contains(output, "[env: TOKEN]"), "Should show env var for token")
	testing.expect(t, strings.contains(output, "[required]"), "Should show required for token")
	testing.expect(t, strings.contains(output, "[default: Yaml]"), "Should show default for format")
}

// --- Nested subcommand: write_help with subcommands ---

@(test)
test_write_help_with_subcommands :: proc(t: ^testing.T) {
	Opts :: struct {
		dry_run: bool `usage:"Preview only"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	subcommands := []cli.Command{
		{name = "staging", description = "Deploy to staging"},
		{name = "production", description = "Deploy to production"},
	}

	cli.write_help(w, Opts, "myapp deploy", cli.Help_Config{parsing_style = .Unix, commands = subcommands, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Commands:"), "Should show subcommands section")
	testing.expect(t, strings.contains(output, "staging"), "Should show staging subcommand")
	testing.expect(t, strings.contains(output, "production"), "Should show production subcommand")
	testing.expect(t, strings.contains(output, "--[no-]dry-run"), "Should show parent's options")
	testing.expect(t, strings.contains(output, "<command>"), "Should show <command> in usage line")
}

@(test)
test_write_help_xor_meta :: proc(t: ^testing.T) {
	Opts :: struct {
		json: bool `args:"xor=format" usage:"Output as JSON"`,
		yaml: bool `args:"xor=format" usage:"Output as YAML"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[xor: format]"), "Should show xor group in meta")
}

// --- Negatable boolean help display tests ---

@(test)
test_write_help_negatable_display :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool `args:"short=v" usage:"Show verbose output"`,
		debug:   bool `usage:"Debug mode"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "--[no-]verbose"), "Should show negatable format for verbose")
	testing.expect(t, strings.contains(output, "--[no-]debug"), "Should show negatable format for debug")
}

@(test)
test_write_help_negatable_odin_style_no_negatable :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool `usage:"Verbose"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Odin, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, !strings.contains(output, "[no-]"), "Odin style should not show negatable format")
	testing.expect(t, strings.contains(output, "-verbose"), "Should show plain flag name")
}

// --- Global flags help display ---

@(test)
test_write_help_global_options_section :: proc(t: ^testing.T) {
	Opts :: struct {
		output: string `usage:"Output file"`,
	}

	global_infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true, usage = "Verbose output"},
		{field_name = "config", display_name = "config", usage = "Config file"},
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(
		w, Opts, "test-prog",
		cli.Help_Config{
			parsing_style = .Unix,
			mode = .Plain,
			global_flags = global_infos,
		},
	)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Global Options:"), "Should show global options section")
	testing.expect(t, strings.contains(output, "verbose"), "Should show verbose global flag")
	testing.expect(t, strings.contains(output, "config"), "Should show config global flag")
}

// --- XOR integration tests (via App + add_command) ---

Xor_Test_Opts :: struct {
	json: bool `args:"xor=format" usage:"Output as JSON"`,
	yaml: bool `args:"xor=format" usage:"Output as YAML"`,
}

@(private = "file")
xor_action :: proc(opts: ^Xor_Test_Opts, program: string) -> int { return 0 }

@(test)
test_xor_single_flag_ok :: proc(t: ^testing.T) {
	app := cli.make_app("xor-test", allocator = context.temp_allocator)
	cli.add_command(&app, Xor_Test_Opts, "run", action = xor_action)

	// Single XOR flag should succeed.
	code := cli.run(&app, {"xor-test", "run", "--json"})
	testing.expect_value(t, code, 0)
}

@(test)
test_xor_conflict_error :: proc(t: ^testing.T) {
	app := cli.make_app("xor-test", allocator = context.temp_allocator)
	cli.add_command(&app, Xor_Test_Opts, "run", action = xor_action)

	// Two XOR flags should fail with exit code 1.
	code := cli.run(&app, {"xor-test", "run", "--json", "--yaml"})
	testing.expect_value(t, code, 1)
}

@(test)
test_xor_no_flags_ok :: proc(t: ^testing.T) {
	app := cli.make_app("xor-test", allocator = context.temp_allocator)
	cli.add_command(&app, Xor_Test_Opts, "run", action = xor_action)

	// No XOR flags should succeed.
	code := cli.run(&app, {"xor-test", "run"})
	testing.expect_value(t, code, 0)
}

// --- Custom validator integration test ---

Validator_Test_Opts :: struct {
	port: int `usage:"Port number"`,
}

@(private = "file")
validator_action :: proc(opts: ^Validator_Test_Opts, program: string) -> int { return 0 }

@(private = "file")
port_validator :: proc(opts: ^Validator_Test_Opts) -> string {
	if opts.port > 0 && opts.port <= 65535 do return ""
	return "Port must be between 1 and 65535."
}

@(test)
test_validator_pass :: proc(t: ^testing.T) {
	app := cli.make_app("val-test", allocator = context.temp_allocator)
	cli.add_command(&app, Validator_Test_Opts, "serve", action = validator_action)
	cli.set_validator(&app, "serve", Validator_Test_Opts, port_validator)

	code := cli.run(&app, {"val-test", "serve", "--port=8080"})
	testing.expect_value(t, code, 0)
}

@(test)
test_validator_fail :: proc(t: ^testing.T) {
	app := cli.make_app("val-test", allocator = context.temp_allocator)
	cli.add_command(&app, Validator_Test_Opts, "serve", action = validator_action)
	cli.set_validator(&app, "serve", Validator_Test_Opts, port_validator)

	code := cli.run(&app, {"val-test", "serve", "--port=99999"})
	testing.expect_value(t, code, 1)
}

// --- Bordered panel help output tests ---

@(test)
test_write_help_bordered_panels :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	// Use plain theme to avoid ANSI codes in title text.
	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Full, max_width = 80, theme = cli.plain_theme()})
	output := strings.to_string(sb)

	// Should have bordered sections with titles
	testing.expect(t, strings.contains(output, "╭─ Arguments ─"), "Should have bordered Arguments title")
	testing.expect(t, strings.contains(output, "╭─ Options ─"), "Should have bordered Options title")
	testing.expect(t, strings.contains(output, "╰"), "Should have bottom border")
	testing.expect(t, strings.contains(output, "╮"), "Should have top-right corner")
}

@(test)
test_write_help_bordered_commands :: proc(t: ^testing.T) {
	Dummy :: struct {}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	commands := []cli.Command{
		{name = "init", description = "Initialize a project"},
		{name = "build", description = "Build the project"},
	}

	cli.write_help(w, Dummy, "myapp", cli.Help_Config{parsing_style = .Unix, commands = commands, mode = .Full, max_width = 80, theme = cli.plain_theme()})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "╭─ Commands ─"), "Should have bordered Commands title")
	testing.expect(t, strings.contains(output, "init"), "Should contain init command")
	testing.expect(t, strings.contains(output, "build"), "Should contain build command")
}

@(test)
test_write_help_bordered_panels_plain_fallback :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	// In Plain mode, should fall back to standalone headings (no borders)
	testing.expect(t, strings.contains(output, "Arguments:"), "Plain should have standalone Arguments heading")
	testing.expect(t, strings.contains(output, "Options:"), "Plain should have standalone Options heading")
	testing.expect(t, !strings.contains(output, "╭"), "Plain should not have border chars")
	testing.expect(t, !strings.contains(output, "│"), "Plain should not have vertical borders")
}

@(test)
test_write_help_cross_panel_alignment :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool   `args:"short=v" usage:"Verbose"`,
		output:  string `args:"short=o" usage:"Output file"`,
		token:   string `usage:"API token"`,
	}

	panels := []cli.Panel{
		{name = "Auth", fields = {"token"}},
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, panel_config = panels, mode = .Full, max_width = 80, theme = cli.plain_theme()})
	output := strings.to_string(sb)

	// Both Options and Auth panels should be present
	testing.expect(t, strings.contains(output, "╭─ Options ─"), "Should have Options panel")
	testing.expect(t, strings.contains(output, "╭─ Auth ─"), "Should have Auth panel")
}

@(test)
test_write_help_rich_text_meta :: proc(t: ^testing.T) {
	Opts :: struct {
		token: string `args:"env=TOKEN,required" usage:"API token"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain, max_width = 80})
	output := strings.to_string(sb)

	// Multi-part meta should have both env and required
	testing.expect(t, strings.contains(output, "[env: TOKEN]"), "Should show env var")
	testing.expect(t, strings.contains(output, "[required]"), "Should show required")
}

@(test)
test_write_help_global_bordered :: proc(t: ^testing.T) {
	Opts :: struct {
		output: string `usage:"Output file"`,
	}

	global_infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true, usage = "Verbose output"},
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(
		w, Opts, "test-prog",
		cli.Help_Config{
			parsing_style = .Unix,
			mode = .Full,
			max_width = 80,
			global_flags = global_infos,
			theme = cli.plain_theme(),
		},
	)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "╭─ Global Options ─"), "Should have bordered Global Options")
	testing.expect(t, strings.contains(output, "verbose"), "Should show global verbose flag")
}

@(test)
test_write_help_narrow_terminal :: proc(t: ^testing.T) {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", cli.Help_Config{
		parsing_style = .Unix,
		description = "A test tool.",
		version = "1.0.0",
		max_width = 55,
		mode = .Plain,
	})
	output := strings.to_string(sb)

	// Should still contain usage line and description.
	testing.expect(t, strings.contains(output, "Usage:"), "narrow help should include usage line")
	testing.expect(t, strings.contains(output, "A test tool."), "narrow help should include description")
	testing.expect(t, strings.contains(output, "Version 1.0.0"), "narrow help should include version")
	testing.expect(t, strings.contains(output, "widen terminal"), "narrow help should include widen hint")
	// Should NOT contain table sections.
	testing.expect(t, !strings.contains(output, "Arguments:"), "narrow help should not include Arguments section")
	testing.expect(t, !strings.contains(output, "Options:"), "narrow help should not include Options section")
}

// --- Exactly_One group validation tests ---

@(private = "file")
exactly_one_action :: proc(opts: ^Exactly_One_Opts, program: string) -> int { return 0 }

Exactly_One_Opts :: struct {
	json: bool `args:"one_of=format" usage:"JSON"`,
	yaml: bool `args:"one_of=format" usage:"YAML"`,
	toml: bool `args:"one_of=format" usage:"TOML"`,
}

@(test)
test_exactly_one_pass :: proc(t: ^testing.T) {
	app := cli.make_app("eo-test", allocator = context.temp_allocator)
	cli.add_command(&app, Exactly_One_Opts, "run", action = exactly_one_action)
	code := cli.run(&app, {"eo-test", "run", "--json"})
	testing.expect_value(t, code, 0)
}

@(test)
test_exactly_one_none_fails :: proc(t: ^testing.T) {
	app := cli.make_app("eo-test", allocator = context.temp_allocator)
	cli.add_command(&app, Exactly_One_Opts, "run", action = exactly_one_action)
	code := cli.run(&app, {"eo-test", "run"})
	testing.expect_value(t, code, 1)
}

@(test)
test_exactly_one_multiple_fails :: proc(t: ^testing.T) {
	app := cli.make_app("eo-test", allocator = context.temp_allocator)
	cli.add_command(&app, Exactly_One_Opts, "run", action = exactly_one_action)
	code := cli.run(&app, {"eo-test", "run", "--json", "--yaml"})
	testing.expect_value(t, code, 1)
}

// --- At_Least_One group validation tests ---

@(private = "file")
at_least_one_action :: proc(opts: ^At_Least_One_Opts, program: string) -> int { return 0 }

At_Least_One_Opts :: struct {
	lint:  bool `args:"any_of=actions" usage:"Run linting"`,
	test:  bool `args:"any_of=actions" usage:"Run tests"`,
	build: bool `args:"any_of=actions" usage:"Run build"`,
}

@(test)
test_at_least_one_pass :: proc(t: ^testing.T) {
	app := cli.make_app("al-test", allocator = context.temp_allocator)
	cli.add_command(&app, At_Least_One_Opts, "run", action = at_least_one_action)
	code := cli.run(&app, {"al-test", "run", "--lint", "--test"})
	testing.expect_value(t, code, 0)
}

@(test)
test_at_least_one_single_pass :: proc(t: ^testing.T) {
	app := cli.make_app("al-test", allocator = context.temp_allocator)
	cli.add_command(&app, At_Least_One_Opts, "run", action = at_least_one_action)
	code := cli.run(&app, {"al-test", "run", "--build"})
	testing.expect_value(t, code, 0)
}

@(test)
test_at_least_one_none_fails :: proc(t: ^testing.T) {
	app := cli.make_app("al-test", allocator = context.temp_allocator)
	cli.add_command(&app, At_Least_One_Opts, "run", action = at_least_one_action)
	code := cli.run(&app, {"al-test", "run"})
	testing.expect_value(t, code, 1)
}

// --- All_Or_None group validation tests ---

@(private = "file")
together_action :: proc(opts: ^Together_Opts, program: string) -> int { return 0 }

Together_Opts :: struct {
	user: string `args:"together=auth" usage:"Username"`,
	pass: string `args:"together=auth" usage:"Password"`,
}

@(test)
test_together_all_pass :: proc(t: ^testing.T) {
	app := cli.make_app("tg-test", allocator = context.temp_allocator)
	cli.add_command(&app, Together_Opts, "run", action = together_action)
	code := cli.run(&app, {"tg-test", "run", "--user=admin", "--pass=secret"})
	testing.expect_value(t, code, 0)
}

@(test)
test_together_none_pass :: proc(t: ^testing.T) {
	app := cli.make_app("tg-test", allocator = context.temp_allocator)
	cli.add_command(&app, Together_Opts, "run", action = together_action)
	code := cli.run(&app, {"tg-test", "run"})
	testing.expect_value(t, code, 0)
}

@(test)
test_together_partial_fails :: proc(t: ^testing.T) {
	app := cli.make_app("tg-test", allocator = context.temp_allocator)
	cli.add_command(&app, Together_Opts, "run", action = together_action)
	code := cli.run(&app, {"tg-test", "run", "--user=admin"})
	testing.expect_value(t, code, 1)
}

// --- Range validation tests ---

@(private = "file")
range_action :: proc(opts: ^Range_Opts, program: string) -> int { return 0 }

Range_Opts :: struct {
	port: int `args:"min=1,max=65535" usage:"Port"`,
}

@(test)
test_range_int_pass :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Range_Opts, "run", action = range_action)
	code := cli.run(&app, {"rng-test", "run", "--port=8080"})
	testing.expect_value(t, code, 0)
}

@(test)
test_range_int_below_min :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Range_Opts, "run", action = range_action)
	// Explicitly providing --port=0 should fail since min=1.
	code := cli.run(&app, {"rng-test", "run", "--port=0"})
	testing.expect_value(t, code, 1)
}

@(test)
test_range_int_negative_below_min :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Range_Opts, "run", action = range_action)
	code := cli.run(&app, {"rng-test", "run", "--port=-1"})
	testing.expect_value(t, code, 1)
}

@(test)
test_range_int_above_max :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Range_Opts, "run", action = range_action)
	code := cli.run(&app, {"rng-test", "run", "--port=99999"})
	testing.expect_value(t, code, 1)
}

@(test)
test_range_zero_skipped :: proc(t: ^testing.T) {
	// Zero value should skip validation (field not provided).
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Range_Opts, "run", action = range_action)
	code := cli.run(&app, {"rng-test", "run"})
	testing.expect_value(t, code, 0)
}

@(private = "file")
min_only_action :: proc(opts: ^Min_Only_Opts, program: string) -> int { return 0 }

Min_Only_Opts :: struct {
	count: int `args:"min=0" usage:"Count"`,
}

@(test)
test_range_min_only_pass :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Min_Only_Opts, "run", action = min_only_action)
	code := cli.run(&app, {"rng-test", "run", "--count=5"})
	testing.expect_value(t, code, 0)
}

@(test)
test_range_min_only_fail :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Min_Only_Opts, "run", action = min_only_action)
	code := cli.run(&app, {"rng-test", "run", "--count=-1"})
	testing.expect_value(t, code, 1)
}

@(private = "file")
max_only_action :: proc(opts: ^Max_Only_Opts, program: string) -> int { return 0 }

Max_Only_Opts :: struct {
	pct: int `args:"max=100" usage:"Percent"`,
}

@(test)
test_range_max_only_fail :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Max_Only_Opts, "run", action = max_only_action)
	code := cli.run(&app, {"rng-test", "run", "--pct=200"})
	testing.expect_value(t, code, 1)
}

@(test)
test_range_max_only_pass :: proc(t: ^testing.T) {
	app := cli.make_app("rng-test", allocator = context.temp_allocator)
	cli.add_command(&app, Max_Only_Opts, "run", action = max_only_action)
	code := cli.run(&app, {"rng-test", "run", "--pct=50"})
	testing.expect_value(t, code, 0)
}

// --- Path validation tests ---

@(private = "file")
path_action :: proc(opts: ^Path_Opts, program: string) -> int { return 0 }

Path_Opts :: struct {
	input: string `args:"path_exists" usage:"Input path"`,
}

@(test)
test_path_exists_pass :: proc(t: ^testing.T) {
	app := cli.make_app("path-test", allocator = context.temp_allocator)
	cli.add_command(&app, Path_Opts, "run", action = path_action)
	code := cli.run(&app, {"path-test", "run", "--input=/tmp"})
	testing.expect_value(t, code, 0)
}

@(test)
test_path_exists_fail :: proc(t: ^testing.T) {
	app := cli.make_app("path-test", allocator = context.temp_allocator)
	cli.add_command(&app, Path_Opts, "run", action = path_action)
	code := cli.run(&app, {"path-test", "run", "--input=/nonexistent_path_xyz_123"})
	testing.expect_value(t, code, 1)
}

@(private = "file")
file_action :: proc(opts: ^File_Opts, program: string) -> int { return 0 }

File_Opts :: struct {
	input: string `args:"file_exists" usage:"Input file"`,
}

@(test)
test_file_exists_fail_on_directory :: proc(t: ^testing.T) {
	app := cli.make_app("file-test", allocator = context.temp_allocator)
	cli.add_command(&app, File_Opts, "run", action = file_action)
	// /tmp is a directory, not a file
	code := cli.run(&app, {"file-test", "run", "--input=/tmp"})
	testing.expect_value(t, code, 1)
}

@(private = "file")
dir_action :: proc(opts: ^Dir_Opts, program: string) -> int { return 0 }

Dir_Opts :: struct {
	outdir: string `args:"dir_exists" usage:"Output dir"`,
}

@(test)
test_dir_exists_pass :: proc(t: ^testing.T) {
	app := cli.make_app("dir-test", allocator = context.temp_allocator)
	cli.add_command(&app, Dir_Opts, "run", action = dir_action)
	code := cli.run(&app, {"dir-test", "run", "--outdir=/tmp"})
	testing.expect_value(t, code, 0)
}

@(test)
test_dir_exists_fail_on_file :: proc(t: ^testing.T) {
	app := cli.make_app("dir-test", allocator = context.temp_allocator)
	cli.add_command(&app, Dir_Opts, "run", action = dir_action)
	// /etc/hosts is a file, not a directory
	code := cli.run(&app, {"dir-test", "run", "--outdir=/etc/hosts"})
	testing.expect_value(t, code, 1)
}

@(test)
test_path_empty_skipped :: proc(t: ^testing.T) {
	// Empty string (not provided) should skip validation.
	app := cli.make_app("path-test", allocator = context.temp_allocator)
	cli.add_command(&app, Path_Opts, "run", action = path_action)
	code := cli.run(&app, {"path-test", "run"})
	testing.expect_value(t, code, 0)
}

// --- Help display for new features ---

@(test)
test_help_shows_range :: proc(t: ^testing.T) {
	Opts :: struct {
		port: int `args:"min=0,max=65535" usage:"Port number"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[0..65535]"), "Should show range in help")
}

@(test)
test_help_shows_min_only :: proc(t: ^testing.T) {
	Opts :: struct {
		count: int `args:"min=0" usage:"Count"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[min: 0]"), "Should show min-only in help")
}

@(test)
test_help_shows_max_only :: proc(t: ^testing.T) {
	Opts :: struct {
		pct: int `args:"max=100" usage:"Percent"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[max: 100]"), "Should show max-only in help")
}

@(test)
test_help_shows_group_mode :: proc(t: ^testing.T) {
	Opts :: struct {
		json: bool `args:"one_of=format" usage:"JSON"`,
		yaml: bool `args:"one_of=format" usage:"YAML"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[one of: format]"), "Should show one_of group mode in help")
}

@(test)
test_help_shows_file_constraint :: proc(t: ^testing.T) {
	Opts :: struct {
		input: string `args:"file_exists" usage:"Input file"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[file]"), "Should show file constraint in help")
}

@(test)
test_help_shows_dir_constraint :: proc(t: ^testing.T) {
	Opts :: struct {
		outdir: string `args:"dir_exists" usage:"Output dir"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[directory]"), "Should show directory constraint in help")
}

@(test)
test_help_shows_path_constraint :: proc(t: ^testing.T) {
	Opts :: struct {
		any_path: string `args:"path_exists" usage:"Any path"`,
	}

	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Opts, "test-prog", cli.Help_Config{parsing_style = .Unix, mode = .Plain})
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[path]"), "Should show path constraint in help")
}
