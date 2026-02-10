package logger_test

import logger ".."
import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:testing"
import "core:time"

@(test)
test_make_logger_defaults :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger()
	testing.expect_value(t, lgr.lowest_level, runtime.Logger_Level.Info)
	testing.expect_value(t, lgr.timestamp_format, logger.Timestamp_Format.Time_Only)
	testing.expect_value(t, lgr.field_count, 0)
	testing.expect_value(t, lgr.show_caller, false)
	testing.expect_value(t, lgr.prefix, "")
}

@(test)
test_to_str_basic_info :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	// Disable color for predictable test output
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "hello world")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "INFO"), "should contain INFO level")
	testing.expect(t, strings.contains(result, "hello world"), "should contain message")
}

@(test)
test_to_str_all_levels :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Debug, timestamp_format = .None)
	lgr.options = {}

	levels := []struct {
		level:    runtime.Logger_Level,
		expected: string,
	}{{.Debug, "DEBU"}, {.Info, "INFO"}, {.Warning, "WARN"}, {.Error, "ERRO"}, {.Fatal, "FATA"}}

	for tc in levels {
		result, ok := logger.to_str(lgr, tc.level, "test")
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		testing.expectf(
			t,
			strings.contains(result, tc.expected),
			"level %v should contain %s, got: %s",
			tc.level,
			tc.expected,
			result,
		)
	}
}

@(test)
test_with_fields :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	sub := logger.with_fields(lgr, "host", "localhost", "port", "8080")
	testing.expect_value(t, sub.field_count, 2)

	result, ok := logger.to_str(sub, .Info, "started")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "host"), "should contain key 'host'")
	testing.expect(t, strings.contains(result, "localhost"), "should contain value 'localhost'")
	testing.expect(t, strings.contains(result, "port"), "should contain key 'port'")
	testing.expect(t, strings.contains(result, "8080"), "should contain value '8080'")

	// Original logger should be unaffected
	testing.expect_value(t, lgr.field_count, 0)
}

@(test)
test_with_fields_odd_args :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	// Odd number of args: trailing value should be ignored
	sub := logger.with_fields(lgr, "key1", "val1", "orphan")
	testing.expect_value(t, sub.field_count, 1)
}

@(test)
test_set_prefix :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	logger.set_prefix(&lgr, "myapp")

	result, ok := logger.to_str(lgr, .Info, "booting")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "myapp"), "should contain prefix")
	testing.expect(t, strings.contains(result, "booting"), "should contain message")
}

@(test)
test_timestamp_none :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "no time")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.has_prefix(result, "INFO"), "with None timestamp, output should start with level")
}

@(test)
test_timestamp_time_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .Time_Only)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "with time")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Should have HH:MM:SS pattern before INFO
	testing.expect(t, strings.contains(result, ":"), "time format should contain colons")
	// The timestamp should come before the level
	colon_idx := strings.index(result, ":")
	info_idx := strings.index(result, "INFO")
	testing.expect(t, colon_idx < info_idx, "timestamp should precede level prefix")
}

@(test)
test_timestamp_date_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .Date_Only)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "with date")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "-"), "date format should contain dashes")
}

@(test)
test_timestamp_date_time :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .Date_Time)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "full")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "-"), "should contain date dashes")
	testing.expect(t, strings.contains(result, ":"), "should contain time colons")
}

@(test)
test_show_caller :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	lgr.show_caller = true

	result, ok := logger.to_str(lgr, .Info, "with caller")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "<"), "should contain caller opening bracket")
	testing.expect(t, strings.contains(result, ">"), "should contain caller closing bracket")
	testing.expect(t, strings.contains(result, "tests.odin"), "should contain test file name")
}

@(test)
test_plain_styles :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	lgr.level_styles = logger.plain_level_styles()
	lgr.key_style = logger.plain_key_style()

	sub := logger.with_fields(lgr, "k", "v")
	result, ok := logger.to_str(sub, .Info, "plain")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// No ANSI escape sequences
	testing.expect(t, !strings.contains(result, "\x1b["), "plain output should have no ANSI escapes")
	testing.expect(t, strings.contains(result, "INFO"), "should still contain level")
	testing.expect(t, strings.contains(result, "k=v"), "should contain key=value")
}

@(test)
test_styled_output_has_ansi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	// Keep Terminal_Color option (default)

	result, ok := logger.to_str(lgr, .Info, "styled")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "\x1b["), "styled output should contain ANSI escapes")
}

@(test)
test_to_runtime_logger :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Warning)
	rl := logger.to_runtime_logger(&lgr)

	testing.expect(t, rl.procedure != nil, "runtime logger proc should be set")
	testing.expect(t, rl.data != nil, "runtime logger data should be set")
	testing.expect_value(t, rl.lowest_level, runtime.Logger_Level.Warning)
}

@(test)
test_fmt_formatter :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	formatted := fmt.aprintf("%v", lgr)
	defer delete(formatted)

	// The formatter should render a sample INFO line
	testing.expect(t, strings.contains(formatted, "INFO"), "fmt output should contain INFO")
	testing.expect(t, strings.contains(formatted, "logger"), "fmt output should contain 'logger'")
}

@(test)
test_with_fields_max_capacity :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	// Fill to MAX_FIELDS
	args: [logger.MAX_FIELDS * 2]string
	for i in 0 ..< logger.MAX_FIELDS {
		args[i * 2] = "k"
		args[i * 2 + 1] = "v"
	}
	sub := logger.with_fields(lgr, ..args[:])
	testing.expect_value(t, sub.field_count, logger.MAX_FIELDS)

	// Adding more should not overflow
	sub2 := logger.with_fields(sub, "extra_key", "extra_val")
	testing.expect_value(t, sub2.field_count, logger.MAX_FIELDS)
}

@(test)
test_empty_message :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed with empty message")
	testing.expect(t, strings.contains(result, "INFO"), "should still contain level")
}

@(test)
test_field_separator :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	lgr.key_style = logger.plain_key_style()

	sub := logger.with_fields(lgr, "method", "GET", "status", "200")
	result, ok := logger.to_str(sub, .Info, "request")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "method=GET"), "should contain method=GET")
	testing.expect(t, strings.contains(result, "status=200"), "should contain status=200")
}
