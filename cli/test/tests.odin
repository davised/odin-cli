package cli_test

import "core:flags"
import "core:strings"
import "core:testing"
import cli ".."

// --- Test struct ---

Test_Options :: struct {
	input:   string `args:"pos=0,required" usage:"Input file"`,
	output:  string `args:"pos=1" usage:"Output destination"`,
	verbose: bool   `usage:"Show verbose output"`,
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

// --- write_help tests ---

@(test)
test_write_help_contains_usage :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Usage:"), "Should contain 'Usage:'")
	testing.expect(t, strings.contains(output, "test-prog"), "Should contain program name")
}

@(test)
test_write_help_contains_arguments :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Arguments:"), "Should contain 'Arguments:' section")
	testing.expect(t, strings.contains(output, "INPUT"), "Should show positional args in uppercase")
}

@(test)
test_write_help_contains_options :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Options:"), "Should contain 'Options:' section")
	testing.expect(t, strings.contains(output, "--verbose"), "Should show verbose flag")
	testing.expect(t, strings.contains(output, "--count"), "Should show count flag")
}

@(test)
test_write_help_hides_hidden :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, !strings.contains(output, "--hidden"), "Should not show hidden flag")
}

@(test)
test_write_help_description :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Unix, description = "My tool.", mode = .Plain)
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

	cli.write_help(w, Test_Options, "test-prog", .Unix, panel_config = panels, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Output Config:"), "Should contain panel heading")
	testing.expect(t, strings.contains(output, "--format"), "Should show format in panel")
}

@(test)
test_write_help_required_marker :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Unix, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "[required]"), "Should mark required args")
}

@(test)
test_write_help_odin_style :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	cli.write_help(w, Test_Options, "test-prog", .Odin, mode = .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "-verbose"), "Should use single-dash for Odin style")
	testing.expect(t, !strings.contains(output, "--verbose"), "Should not use double-dash for Odin style")
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

	cli.write_help(w, Dummy, "myapp", .Unix, commands = commands, mode = .Plain)
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
