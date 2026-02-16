package cli

// Tests for package-private internals. These symbols are @(private) (package-level)
// rather than @(private = "file") so this same-package test file can access them.
// In production code they are only used within their defining file.

import "core:strings"
import "core:testing"

// --- Test-only types ---

Test_Options :: struct {
	input:   string `args:"pos=0,required" usage:"Input file"`,
	output:  string `args:"pos=1" usage:"Output destination"`,
	verbose: bool   `args:"short=v" usage:"Show verbose output"`,
	count:   int    `usage:"Number of iterations"`,
	format:  string `usage:"Output format"`,
	hidden:  string `args:"hidden" usage:"Internal flag"`,
	name_override: string `args:"name=custom-name" usage:"Custom named flag"`,
}

Test_Log_Level :: enum {
	Debug,
	Info,
	Warn,
	Error,
}


// --- extract_flags tests ---

@(test)
test_extract_flags_count :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, len(infos), 7)
}

@(test)
test_extract_flags_positional :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[0].is_positional, true)
	testing.expect_value(t, infos[0].pos, 0)
	testing.expect_value(t, infos[0].is_required, true)
	testing.expect_value(t, infos[0].display_name, "input")
}

@(test)
test_extract_flags_optional_positional :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[1].is_positional, true)
	testing.expect_value(t, infos[1].pos, 1)
	testing.expect_value(t, infos[1].is_required, false)
}

@(test)
test_extract_flags_boolean :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[2].is_boolean, true)
	testing.expect_value(t, infos[2].display_name, "verbose")
	testing.expect_value(t, infos[2].type_description, "")
}

@(test)
test_extract_flags_type_description :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[3].is_boolean, false)
	testing.expect_value(t, infos[3].type_description, "<int>")
}

@(test)
test_extract_flags_hidden :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[5].is_hidden, true)
}

@(test)
test_extract_flags_name_override :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[6].display_name, "custom-name")
	testing.expect_value(t, infos[6].field_name, "name_override")
}

@(test)
test_extract_flags_underscore_to_hyphen :: proc(t: ^testing.T) {
	Opts :: struct {
		my_flag: string `usage:"test"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].display_name, "my-flag")
}

@(test)
test_extract_flags_short_name :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[2].short_name, "v")
}

@(test)
test_extract_flags_short_name_missing :: proc(t: ^testing.T) {
	infos := extract_flags(Test_Options)
	testing.expect_value(t, infos[3].short_name, "")
}

@(test)
test_extract_flags_env_var :: proc(t: ^testing.T) {
	Opts :: struct {
		token: string `args:"env=API_TOKEN" usage:"API token"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].env_var, "API_TOKEN")
}

@(test)
test_extract_flags_greedy :: proc(t: ^testing.T) {
	Opts :: struct {
		dump_config: bool `args:"greedy" usage:"Dump config"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].is_greedy, true)
}

@(test)
test_extract_flags_count_flag :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: int `args:"short=v,count" usage:"Verbosity level"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].is_count, true)
	testing.expect_value(t, infos[0].short_name, "v")
}

@(test)
test_extract_flags_enum :: proc(t: ^testing.T) {
	Opts :: struct {
		level: Test_Log_Level `usage:"Log level"`,
	}
	infos := extract_flags(Opts)
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
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].is_enum, false)
}

@(test)
test_extract_flags_greedy_and_short :: proc(t: ^testing.T) {
	Opts :: struct {
		dump_config: bool `args:"short=d,greedy" usage:"Dump config"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].is_greedy, true)
	testing.expect_value(t, infos[0].short_name, "d")
	testing.expect_value(t, infos[0].is_boolean, true)
}

@(test)
test_extract_flags_xor_group :: proc(t: ^testing.T) {
	Opts :: struct {
		json: bool `args:"xor=format" usage:"Output as JSON"`,
		yaml: bool `args:"xor=format" usage:"Output as YAML"`,
		toml: bool `args:"xor=format" usage:"Output as TOML"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].group.name, "format")
	testing.expect_value(t, infos[0].group.mode, Group_Mode.At_Most_One)
	testing.expect_value(t, infos[1].group.name, "format")
	testing.expect_value(t, infos[2].group.name, "format")
}

@(test)
test_extract_flags_no_group :: proc(t: ^testing.T) {
	Opts :: struct {
		verbose: bool `usage:"Verbose"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].group.name, "")
}

@(test)
test_extract_flags_group_modes :: proc(t: ^testing.T) {
	Opts :: struct {
		a: bool `args:"one_of=pick" usage:"A"`,
		b: bool `args:"any_of=acts" usage:"B"`,
		c: bool `args:"together=auth" usage:"C"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].group.name, "pick")
	testing.expect_value(t, infos[0].group.mode, Group_Mode.Exactly_One)
	testing.expect_value(t, infos[1].group.name, "acts")
	testing.expect_value(t, infos[1].group.mode, Group_Mode.At_Least_One)
	testing.expect_value(t, infos[2].group.name, "auth")
	testing.expect_value(t, infos[2].group.mode, Group_Mode.All_Or_None)
}

@(test)
test_extract_flags_min_max :: proc(t: ^testing.T) {
	Opts :: struct {
		port: int `args:"min=1,max=65535" usage:"Port"`,
	}
	infos := extract_flags(Opts)
	min_v, min_ok := infos[0].min_val.?
	max_v, max_ok := infos[0].max_val.?
	testing.expect(t, min_ok, "Should have min_val")
	testing.expect(t, max_ok, "Should have max_val")
	testing.expect_value(t, min_v, 1.0)
	testing.expect_value(t, max_v, 65535.0)
}

@(test)
test_extract_flags_min_only :: proc(t: ^testing.T) {
	Opts :: struct {
		count: int `args:"min=0" usage:"Count"`,
	}
	infos := extract_flags(Opts)
	min_v, min_ok := infos[0].min_val.?
	testing.expect(t, min_ok, "Should have min_val")
	testing.expect_value(t, min_v, 0.0)
	testing.expect_value(t, infos[0].max_val, nil)
}

@(test)
test_extract_flags_path_tags :: proc(t: ^testing.T) {
	Opts :: struct {
		input:  string `args:"file_exists" usage:"Input"`,
		outdir: string `args:"dir_exists" usage:"Output dir"`,
		any:    string `args:"path_exists" usage:"Any path"`,
		plain:  string `usage:"No path check"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].file_exists, true)
	testing.expect_value(t, infos[0].dir_exists, false)
	testing.expect_value(t, infos[1].dir_exists, true)
	testing.expect_value(t, infos[1].file_exists, false)
	testing.expect_value(t, infos[2].path_exists, true)
	testing.expect_value(t, infos[3].file_exists, false)
	testing.expect_value(t, infos[3].dir_exists, false)
	testing.expect_value(t, infos[3].path_exists, false)
}

// --- preprocess_short_flags tests ---

@(test)
test_preprocess_single_bool :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := preprocess_short_flags({"-v"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "--verbose")
}

@(test)
test_preprocess_combined_bools :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "quiet", display_name = "quiet", short_name = "q", is_boolean = true},
		{field_name = "all", display_name = "all", short_name = "a", is_boolean = true},
	}
	result := preprocess_short_flags({"-qa"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--quiet")
	testing.expect_value(t, result.args[1], "--all")
}

@(test)
test_preprocess_value_next_arg :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := preprocess_short_flags({"-o", "file.txt"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--output")
	testing.expect_value(t, result.args[1], "file.txt")
}

@(test)
test_preprocess_value_attached :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := preprocess_short_flags({"-ofoo"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--output")
	testing.expect_value(t, result.args[1], "foo")
}

@(test)
test_preprocess_value_equals :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := preprocess_short_flags({"-o=file"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "--output=file")
}

@(test)
test_preprocess_count_flags :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_count = true},
	}
	result := preprocess_short_flags({"-vvv"}, infos)
	testing.expect_value(t, len(result.args), 0)
	count, ok := result.counts["verbose"]
	testing.expect(t, ok, "Should have verbose in counts")
	testing.expect_value(t, count, 3)
}

@(test)
test_preprocess_mixed_bool_and_value :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := preprocess_short_flags({"-vo", "file"}, infos)
	testing.expect_value(t, len(result.args), 3)
	testing.expect_value(t, result.args[0], "--verbose")
	testing.expect_value(t, result.args[1], "--output")
	testing.expect_value(t, result.args[2], "file")
}

@(test)
test_preprocess_long_flags_pass_through :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := preprocess_short_flags({"--verbose", "--count=5"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--verbose")
	testing.expect_value(t, result.args[1], "--count=5")
}

@(test)
test_preprocess_unknown_short_pass_through :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := preprocess_short_flags({"-x"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "-x")
}

@(test)
test_preprocess_count_and_value :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_count = true},
		{field_name = "output", display_name = "output", short_name = "o"},
	}
	result := preprocess_short_flags({"-vvo", "file"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--output")
	testing.expect_value(t, result.args[1], "file")
	count, ok := result.counts["verbose"]
	testing.expect(t, ok, "Should have verbose in counts")
	testing.expect_value(t, count, 2)
}

// --- preprocess_negatable_booleans tests ---

@(test)
test_preprocess_negatable_basic :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	result := preprocess_negatable_booleans({"--no-verbose"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--verbose=false")
}

@(test)
test_preprocess_negatable_real_flag_precedence :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "cache", display_name = "cache", is_boolean = true},
		{field_name = "no_cache", display_name = "no-cache", is_boolean = true},
	}
	result := preprocess_negatable_booleans({"--no-cache"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--no-cache")
}

@(test)
test_preprocess_negatable_unknown :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	result := preprocess_negatable_booleans({"--no-unknown"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--no-unknown")
}

@(test)
test_preprocess_negatable_non_bool_ignored :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "output", display_name = "output", is_boolean = false},
	}
	result := preprocess_negatable_booleans({"--no-output"}, infos)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--no-output")
}

@(test)
test_preprocess_negatable_mixed :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
		{field_name = "debug", display_name = "debug", is_boolean = true},
	}
	result := preprocess_negatable_booleans({"--no-verbose", "--debug", "--no-debug"}, infos)
	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "--verbose=false")
	testing.expect_value(t, result[1], "--debug")
	testing.expect_value(t, result[2], "--debug=false")
}

// --- extract_global_args tests ---

@(test)
test_extract_global_args_basic :: proc(t: ^testing.T) {
	global_infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	global, remaining := extract_global_args(
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
	global_infos := []Flag_Info{
		{field_name = "config", display_name = "config", is_boolean = false},
	}
	global, remaining := extract_global_args(
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
	global_infos := []Flag_Info{
		{field_name = "config", display_name = "config", is_boolean = false},
	}
	global, remaining := extract_global_args(
		{"--config=file.yml", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "--config=file.yml")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
}

@(test)
test_extract_global_args_short_flag :: proc(t: ^testing.T) {
	global_infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	global, remaining := extract_global_args(
		{"-v", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "-v")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
}

@(test)
test_extract_global_args_no_globals :: proc(t: ^testing.T) {
	global_infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	global, remaining := extract_global_args(
		{"build", "--output=x"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 0)
	testing.expect_value(t, len(remaining), 2)
}

@(test)
test_extract_global_args_negatable_bool :: proc(t: ^testing.T) {
	global_infos := []Flag_Info{
		{field_name = "verbose", display_name = "verbose", is_boolean = true},
	}
	global, remaining := extract_global_args(
		{"--no-verbose", "build"}, global_infos, .Unix,
	)
	testing.expect_value(t, len(global), 1)
	testing.expect_value(t, global[0], "--no-verbose")
	testing.expect_value(t, len(remaining), 1)
	testing.expect_value(t, remaining[0], "build")
}

// --- is_zero_value tests ---

@(test)
test_is_zero_value_bool :: proc(t: ^testing.T) {
	val_true := true
	val_false := false
	testing.expect(t, is_zero_value(val_false), "false should be zero")
	testing.expect(t, !is_zero_value(val_true), "true should not be zero")
}

@(test)
test_is_zero_value_string :: proc(t: ^testing.T) {
	empty := ""
	nonempty := "hello"
	testing.expect(t, is_zero_value(empty), "empty string should be zero")
	testing.expect(t, !is_zero_value(nonempty), "non-empty string should not be zero")
}

@(test)
test_is_zero_value_int :: proc(t: ^testing.T) {
	zero := 0
	nonzero := 42
	testing.expect(t, is_zero_value(zero), "0 should be zero")
	testing.expect(t, !is_zero_value(nonzero), "42 should not be zero")
}

// --- write_validation_error tests ---

@(test)
test_write_validation_error :: proc(t: ^testing.T) {
	sb := strings.builder_make(context.temp_allocator)
	w := strings.to_writer(&sb)

	write_validation_error(w, "Port must be between 1 and 65535.", "test-prog", .Unix, default_theme(), .Plain)
	output := strings.to_string(sb)

	testing.expect(t, strings.contains(output, "Error:"), "Should contain Error:")
	testing.expect(t, strings.contains(output, "Port must be between 1 and 65535."), "Should contain error message")
	testing.expect(t, strings.contains(output, "--help"), "Should contain help hint")
}

// --- format_range_val tests ---

@(test)
test_format_range_val_whole_number :: proc(t: ^testing.T) {
	testing.expect_value(t, format_range_val(0), "0")
	testing.expect_value(t, format_range_val(100), "100")
	testing.expect_value(t, format_range_val(-1), "-1")
	testing.expect_value(t, format_range_val(65535), "65535")
}

@(test)
test_format_range_val_fractional :: proc(t: ^testing.T) {
	testing.expect_value(t, format_range_val(0.5), "0.5")
	testing.expect_value(t, format_range_val(3.14), "3.14")
	testing.expect_value(t, format_range_val(-2.5), "-2.5")
}

// --- Multi-short alias tests ---

@(test)
test_extract_flags_multi_short :: proc(t: ^testing.T) {
	Opts :: struct {
		processors: int `args:"short=pP" usage:"Number of processors"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].short_name, "pP")
}

@(test)
test_preprocess_multi_short_primary :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "processors", display_name = "processors", short_name = "pP"},
	}
	result := preprocess_short_flags({"-p", "4"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--processors")
	testing.expect_value(t, result.args[1], "4")
}

@(test)
test_preprocess_multi_short_alias :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "processors", display_name = "processors", short_name = "pP"},
	}
	result := preprocess_short_flags({"-P", "4"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--processors")
	testing.expect_value(t, result.args[1], "4")
}

@(test)
test_preprocess_multi_short_combined :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "processors", display_name = "processors", short_name = "pP", is_boolean = true},
		{field_name = "verbose", display_name = "verbose", short_name = "v", is_boolean = true},
	}
	result := preprocess_short_flags({"-Pv"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--processors")
	testing.expect_value(t, result.args[1], "--verbose")
}

@(test)
test_preprocess_multi_short_value :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "processors", display_name = "processors", short_name = "pP"},
	}
	result := preprocess_short_flags({"-P", "file"}, infos)
	testing.expect_value(t, len(result.args), 2)
	testing.expect_value(t, result.args[0], "--processors")
	testing.expect_value(t, result.args[1], "file")
}

@(test)
test_preprocess_multi_short_equals :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "processors", display_name = "processors", short_name = "pP"},
	}
	result := preprocess_short_flags({"-P=4"}, infos)
	testing.expect_value(t, len(result.args), 1)
	testing.expect_value(t, result.args[0], "--processors=4")
}

// --- preprocess_multi_flags tests ---

@(test)
test_extract_flags_multi :: proc(t: ^testing.T) {
	Opts :: struct {
		nodes: string `args:"multi" usage:"Node list"`,
	}
	infos := extract_flags(Opts)
	testing.expect_value(t, infos[0].is_multi, true)
}

@(test)
test_preprocess_multi_basic :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
	}
	result := preprocess_multi_flags({"--nodes", "foo", "--nodes", "bar"}, infos, .Unix)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--nodes=foo,bar")
}

@(test)
test_preprocess_multi_equals :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
	}
	result := preprocess_multi_flags({"--nodes=foo", "--nodes=bar"}, infos, .Unix)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--nodes=foo,bar")
}

@(test)
test_preprocess_multi_comma_merge :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
	}
	result := preprocess_multi_flags({"--nodes", "foo,bar", "--nodes", "baz"}, infos, .Unix)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--nodes=foo,bar,baz")
}

@(test)
test_preprocess_multi_single_unchanged :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
	}
	result := preprocess_multi_flags({"--nodes", "foo"}, infos, .Unix)
	testing.expect_value(t, len(result), 2)
	testing.expect_value(t, result[0], "--nodes")
	testing.expect_value(t, result[1], "foo")
}

@(test)
test_preprocess_multi_non_multi_pass_through :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "output", display_name = "output"},
	}
	result := preprocess_multi_flags({"--output", "foo", "--output", "bar"}, infos, .Unix)
	testing.expect_value(t, len(result), 4)
	testing.expect_value(t, result[0], "--output")
	testing.expect_value(t, result[1], "foo")
	testing.expect_value(t, result[2], "--output")
	testing.expect_value(t, result[3], "bar")
}

@(test)
test_preprocess_multi_mixed :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
		{field_name = "output", display_name = "output"},
	}
	result := preprocess_multi_flags({"--nodes", "foo", "--output", "out.txt", "--nodes", "bar"}, infos, .Unix)
	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "--nodes=foo,bar")
	testing.expect_value(t, result[1], "--output")
	testing.expect_value(t, result[2], "out.txt")
}

@(test)
test_preprocess_multi_mixed_eq_and_space :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
	}
	result := preprocess_multi_flags({"--nodes=foo", "--nodes", "bar"}, infos, .Unix)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--nodes=foo,bar")
}

@(test)
test_preprocess_multi_two_flags_one_single :: proc(t: ^testing.T) {
	// Regression: when one multi-flag has >1 occurrence (triggers merging)
	// and another multi-flag has exactly 1 occurrence, the single-occurrence
	// flag must not be silently dropped.
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", is_multi = true},
		{field_name = "opts", display_name = "opts", is_multi = true},
	}
	result := preprocess_multi_flags({"--nodes", "foo", "--opts", "bar", "--nodes", "baz"}, infos, .Unix)
	testing.expect_value(t, len(result), 3)
	testing.expect_value(t, result[0], "--nodes=foo,baz")
	testing.expect_value(t, result[1], "--opts")
	testing.expect_value(t, result[2], "bar")
}

@(test)
test_preprocess_multi_via_short_flags :: proc(t: ^testing.T) {
	infos := []Flag_Info{
		{field_name = "nodes", display_name = "nodes", short_name = "n", is_multi = true},
	}
	// Simulate pipeline: short flags first, then multi merge.
	short_result := preprocess_short_flags({"-n", "foo", "-n", "bar"}, infos)
	result := preprocess_multi_flags(short_result.args, infos, .Unix)
	testing.expect_value(t, len(result), 1)
	testing.expect_value(t, result[0], "--nodes=foo,bar")
}
