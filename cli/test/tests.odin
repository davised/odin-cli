package cli_test

import "core:flags"
import "core:strings"
import "core:testing"
import cli ".."

// --- Test struct ---

Test_Options :: struct {
	input:   string `args:"pos=0,required" usage:"Input file"`,
	output:  string `args:"pos=1" usage:"Output destination"`,
	verbose: bool   `args:"short=v" usage:"Show verbose output"`,
	count:   int    `usage:"Number of iterations"`,
	format:  string `usage:"Output format"`,
	hidden:  string `args:"hidden" usage:"Internal flag"`,
	name_override: string `args:"name=custom-name" usage:"Custom named flag"`,
}

// --- extract_flags tests ---

@(test)
test_extract_flags_count :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	testing.expect_value(t, len(infos), 7)
}

@(test)
test_extract_flags_positional :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// input is pos=0
	testing.expect_value(t, infos[0].is_positional, true)
	testing.expect_value(t, infos[0].pos, 0)
	testing.expect_value(t, infos[0].is_required, true)
	testing.expect_value(t, infos[0].display_name, "input")
}

@(test)
test_extract_flags_optional_positional :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// output is pos=1, not required
	testing.expect_value(t, infos[1].is_positional, true)
	testing.expect_value(t, infos[1].pos, 1)
	testing.expect_value(t, infos[1].is_required, false)
}

@(test)
test_extract_flags_boolean :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// verbose is bool
	testing.expect_value(t, infos[2].is_boolean, true)
	testing.expect_value(t, infos[2].display_name, "verbose")
	testing.expect_value(t, infos[2].type_description, "")
}

@(test)
test_extract_flags_type_description :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// count is int
	testing.expect_value(t, infos[3].is_boolean, false)
	testing.expect_value(t, infos[3].type_description, "<int>")
}

@(test)
test_extract_flags_hidden :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// hidden field
	testing.expect_value(t, infos[5].is_hidden, true)
}

@(test)
test_extract_flags_name_override :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// name_override uses args:"name=custom-name"
	testing.expect_value(t, infos[6].display_name, "custom-name")
	testing.expect_value(t, infos[6].field_name, "name_override")
}

@(test)
test_extract_flags_underscore_to_hyphen :: proc(t: ^testing.T) {
	// Without name= override, underscores become hyphens.
	Opts :: struct {
		my_flag: string `usage:"test"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].display_name, "my-flag")
}

// --- Short flag extraction ---

@(test)
test_extract_flags_short_name :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// verbose has short=v
	testing.expect_value(t, infos[2].short_name, "v")
}

@(test)
test_extract_flags_short_name_missing :: proc(t: ^testing.T) {
	infos := cli.extract_flags(Test_Options)
	// count has no short name
	testing.expect_value(t, infos[3].short_name, "")
}

// --- Env var extraction ---

@(test)
test_extract_flags_env_var :: proc(t: ^testing.T) {
	Opts :: struct {
		token: string `args:"env=API_TOKEN" usage:"API token"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].env_var, "API_TOKEN")
}

// --- Greedy flag extraction ---

@(test)
test_extract_flags_greedy :: proc(t: ^testing.T) {
	Opts :: struct {
		dump_config: bool `args:"greedy" usage:"Dump config"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].is_greedy, true)
}

// --- Count flag extraction ---

@(test)
test_extract_flags_count_flag :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: int `args:"short=v,count" usage:"Verbosity level"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].is_count, true)
	testing.expect_value(t, infos[0].short_name, "v")
}

// --- Enum detection ---

Log_Level :: enum {
	Debug,
	Info,
	Warn,
	Error,
}

Format :: enum {
	Json,
	Yaml,
	Toml,
}

@(test)
test_extract_flags_enum :: proc(t: ^testing.T) {
	Opts :: struct {
		level: Log_Level `usage:"Log level"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].is_enum, true)
	testing.expect_value(t, len(infos[0].enum_names), 4)
	testing.expect_value(t, infos[0].enum_names[0], "Debug")
	testing.expect_value(t, infos[0].enum_names[3], "Error")
}

@(test)
test_extract_flags_non_enum :: proc(t: ^testing.T) {
	Opts :: struct {
		level: string `usage:"Log level"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].is_enum, false)
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

// --- Greedy flag in help ---

@(test)
test_extract_flags_greedy_and_short :: proc(t: ^testing.T) {
	Opts :: struct {
		dump_config: bool `args:"short=d,greedy" usage:"Dump config"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].is_greedy, true)
	testing.expect_value(t, infos[0].short_name, "d")
	testing.expect_value(t, infos[0].is_boolean, true)
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

// --- preprocess_short_flags tests ---

@(test)
test_preprocess_single_bool :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := cli.preprocess_short_flags({"-v"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "--verbose")
}

@(test)
test_preprocess_combined_bools :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "quiet", display_name = "quiet", short_name = "q", is_boolean = true},
		{field_name = "all", display_name = "all", short_name = "a", is_boolean = true},
	}
	result := cli.preprocess_short_flags({"-qa"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--quiet")
	testing.expect_value(t, result.args[1], "--all")
}

@(test)
test_preprocess_value_next_arg :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := cli.preprocess_short_flags({"-o", "file.txt"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--output")
	testing.expect_value(t, result.args[1], "file.txt")
}

@(test)
test_preprocess_value_attached :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := cli.preprocess_short_flags({"-ofoo"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--output")
	testing.expect_value(t, result.args[1], "foo")
}

@(test)
test_preprocess_value_equals :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := cli.preprocess_short_flags({"-o=file"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "--output=file")
}

@(test)
test_preprocess_count_flags :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_count = true},
	}
	result := cli.preprocess_short_flags({"-vvv"}, infos)
	testing.expect_value(t, len(result.args), 0)
	count, ok := result.counts["verbose"]
	testing.expect(t, ok, "Should have verbose in counts")
	testing.expect_value(t, count, 3)
}

@(test)
test_preprocess_mixed_bool_and_value :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := cli.preprocess_short_flags({"-vo", "file"}, infos)
	testing.expect_value(t, len(result.args), 3)
	testing.expect_value(t, result.args[0], "--verbose")
	testing.expect_value(t, result.args[1], "--output")
	testing.expect_value(t, result.args[2], "file")
}

@(test)
test_preprocess_long_flags_pass_through :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := cli.preprocess_short_flags({"--verbose", "--count=5"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--verbose")
	testing.expect_value(t, result.args[1], "--count=5")
}

@(test)
test_preprocess_unknown_short_pass_through :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := cli.preprocess_short_flags({"-x"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "-x")
}

@(test)
test_preprocess_count_and_value :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_count = true},
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := cli.preprocess_short_flags({"-vvo", "file"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--output")
	testing.expect_value(t, result.args[1], "file")
	count, ok := result.counts["verbose"]
	testing.expect(t, ok, "Should have verbose in counts")
	testing.expect_value(t, count, 2)
}

// --- XOR group tests ---

@(test)
test_extract_flags_xor_group :: proc(t: ^testing.T) {
	Opts :: struct {
		json: bool `args:"xor=format" usage:"Output as JSON"`,
		yaml: bool `args:"xor=format" usage:"Output as YAML"`,
		toml: bool `args:"xor=format" usage:"Output as TOML"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].xor_group, "format")
	testing.expect_value(t, infos[1].xor_group, "format")
	testing.expect_value(t, infos[2].xor_group, "format")
}

@(test)
test_extract_flags_no_xor :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool `usage:"Verbose"`,
	}
	infos := cli.extract_flags(Opts)
	testing.expect_value(t, infos[0].xor_group, "")
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

// --- Negatable boolean tests ---

@(test)
test_preprocess_negatable_basic :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	result := cli.preprocess_negatable_booleans({"--no-verbose"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--verbose=false")
}

@(test)
test_preprocess_negatable_real_flag_precedence :: proc(t: ^testing.T) {
	// "no-cache" is a real flag name — should NOT be treated as negation of "cache".
	infos := []cli.Flag_Info{
		{field_name = "cache", display_name = "cache", is_boolean = true},
		{field_name = "no_cache", display_name = "no-cache", is_boolean = true},
	}
	result := cli.preprocess_negatable_booleans({"--no-cache"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--no-cache") // pass through unchanged
}

@(test)
test_preprocess_negatable_unknown :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	result := cli.preprocess_negatable_booleans({"--no-unknown"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--no-unknown") // pass through
}

@(test)
test_preprocess_negatable_non_bool_ignored :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "output", display_name = "output", is_boolean = false},
	}
	result := cli.preprocess_negatable_booleans({"--no-output"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--no-output") // pass through (not boolean)
}

@(test)
test_preprocess_negatable_mixed :: proc(t: ^testing.T) {
	infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
		{field_name = "debug", display_name = "debug", is_boolean = true},
	}
	result := cli.preprocess_negatable_booleans({"--no-verbose", "--debug", "--no-debug"}, infos)
	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "--verbose=false")
	testing.expect_value(t, result[1], "--debug")
	testing.expect_value(t, result[2], "--debug=false")
}

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

// --- Global flags tests ---

@(test)
test_extract_global_args_basic :: proc(t: ^testing.T) {
	global_infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	global, remaining := cli.extract_global_args(
		{"--verbose", "build", "--output=x"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "--verbose")
	testing.expect_value(t, len(remaining), 2)
	testing.expect_value(t, remaining[0], "build")
	testing.expect_value(t, remaining[1], "--output=x")
}

@(test)
test_extract_global_args_value_flag :: proc(t: ^testing.T) {
	global_infos := []cli.Flag_Info{
		{field_name = "config", display_name = "config", is_boolean = false},
	}
	global, remaining := cli.extract_global_args(
		{"--config", "file.yml", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 2)
	testing.expect_value(t, global[0], "--config")
	testing.expect_value(t, global[1], "file.yml")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
}

@(test)
test_extract_global_args_equals_form :: proc(t: ^testing.T) {
	global_infos := []cli.Flag_Info{
		{field_name = "config", display_name = "config", is_boolean = false},
	}
	global, remaining := cli.extract_global_args(
		{"--config=file.yml", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "--config=file.yml")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
}

@(test)
test_extract_global_args_short_flag :: proc(t: ^testing.T) {
	global_infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	global, remaining := cli.extract_global_args(
		{"-v", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "-v")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
}

@(test)
test_extract_global_args_no_globals :: proc(t: ^testing.T) {
	global_infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	global, remaining := cli.extract_global_args(
		{"build", "--output=x"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 0)
	testing.expect_value(t, len(remaining), 2)
}

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

// --- Custom validator tests ---

@(test)
test_write_validation_error :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_validation_error(w, "Port must be between 1 and 65535.", "test-prog", .Unix, cli.default_theme(), .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Error:"), "Should contain Error:")
	testing.expect(t, strings.contains(output, "Port must be between 1 and 65535."), "Should contain error message")
	testing.expect(t, strings.contains(output, "--help"), "Should contain help hint")
}

// --- XOR validation via is_zero_value ---

@(test)
test_is_zero_value_bool :: proc(t: ^testing.T) {
	val_true := true
	val_false := false
	testing.expect(t, cli.is_zero_value(val_false), "false should be zero")
	testing.expect(t, !cli.is_zero_value(val_true), "true should not be zero")
}

@(test)
test_is_zero_value_string :: proc(t: ^testing.T) {
	empty := ""
	nonempty := "hello"
	testing.expect(t, cli.is_zero_value(empty), "empty string should be zero")
	testing.expect(t, !cli.is_zero_value(nonempty), "non-empty string should not be zero")
}

@(test)
test_is_zero_value_int :: proc(t: ^testing.T) {
	zero := 0
	nonzero := 42
	testing.expect(t, cli.is_zero_value(zero), "0 should be zero")
	testing.expect(t, !cli.is_zero_value(nonzero), "42 should not be zero")
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

// --- Global flag extraction with --no- prefix ---

@(test)
test_extract_global_args_negatable_bool :: proc(t: ^testing.T) {
	global_infos := []cli.Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	global, remaining := cli.extract_global_args(
		{"--no-verbose", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "--no-verbose")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
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
