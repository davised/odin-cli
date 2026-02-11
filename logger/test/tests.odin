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
	testing.expect_value(t, lgr.lowest_level, logger.Level.Info)
	testing.expect_value(t, lgr.timestamp_format, logger.Timestamp_Format.Time_Only)
	testing.expect_value(t, lgr.field_count, 0)
	testing.expect_value(t, lgr.caller_format, logger.Caller_Format.None)
	testing.expect_value(t, lgr.prefix, "")
	testing.expect_value(t, lgr.output_count, 1)
}

@(test)
test_to_str_basic_info :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "hello world")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "[INFO"), "should contain [INFO level")
	testing.expect(t, strings.contains(result, "hello world"), "should contain message")
	testing.expect(t, strings.contains(result, "---"), "should contain --- separator")
}

@(test)
test_to_str_all_levels :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Trace, timestamp_format = .None)
	lgr.options = {}

	levels := []struct {
		level:    logger.Level,
		expected: string,
	} {
		{.Trace, "[TRACE"},
		{.Debug, "[DEBUG"},
		{.Info, "[INFO"},
		{.Hint, "[HINT"},
		{.Success, "[SUCCESS]"},
		{.Warning, "[WARN"},
		{.Error, "[ERROR"},
		{.Fatal, "[FATAL"},
	}

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
	testing.expect(t, strings.has_prefix(result, "[INFO"), "with None timestamp, output should start with [INFO")
}

@(test)
test_timestamp_time_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .Time_Only)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "with time")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Should have HH:MM:SS pattern after the --- separator
	testing.expect(t, strings.contains(result, ":"), "time format should contain colons")
	// The level should come before the timestamp
	info_idx := strings.index(result, "[INFO")
	colon_idx := strings.index(result, ":")
	testing.expect(t, info_idx < colon_idx, "level prefix should precede timestamp")
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
test_caller_short :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	lgr.caller_format = .Short

	result, ok := logger.to_str(lgr, .Info, "with caller")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "[tests.odin:"), "short caller should contain [basename:")
	testing.expect(t, !strings.contains(result, "logger/test/"), "short caller should not contain directory path")
	testing.expect(t, strings.contains(result, "()]"), "short caller should contain proc name with ()")
}

@(test)
test_caller_long :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	lgr.caller_format = .Long

	result, ok := logger.to_str(lgr, .Info, "with caller")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "logger/test/tests.odin:"), "long caller should contain full path")
	testing.expect(t, strings.contains(result, "()]"), "long caller should contain proc name with ()")
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
	testing.expect(t, strings.contains(result, "[INFO"), "should still contain level")
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
	// Warning maps to runtime.Logger_Level.Warning
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
	testing.expect(t, strings.contains(formatted, "[INFO"), "fmt output should contain [INFO")
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
	testing.expect(t, strings.contains(result, "[INFO"), "should still contain level")
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

// --- New level tests ---

@(test)
test_trace_level :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Trace, timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Trace, "trace msg")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "[TRACE"), "should contain [TRACE")
	testing.expect(t, strings.contains(result, "trace msg"), "should contain message")
}

@(test)
test_hint_level :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Trace, timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Hint, "hint msg")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "[HINT"), "should contain [HINT")
	testing.expect(t, strings.contains(result, "hint msg"), "should contain message")
}

@(test)
test_success_level :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Trace, timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Success, "success msg")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, strings.contains(result, "[SUCCESS]"), "should contain [SUCCESS]")
	testing.expect(t, strings.contains(result, "success msg"), "should contain message")
}

// --- Multi-sink tests ---

@(test)
test_add_output :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Info, timestamp_format = .None)
	testing.expect_value(t, lgr.output_count, 1)

	// Add a second output
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	idx := logger.add_output(&lgr, strings.to_writer(&sb), .Debug)

	testing.expect_value(t, idx, 1)
	testing.expect_value(t, lgr.output_count, 2)
	// lowest_level should be recomputed to Debug (the lowest of all sinks)
	testing.expect_value(t, lgr.lowest_level, logger.Level.Debug)
}

@(test)
test_add_output_max :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)

	// Already has 1 output, add MAX_OUTPUTS-1 more
	sbs: [logger.MAX_OUTPUTS]strings.Builder
	for i in 1 ..< logger.MAX_OUTPUTS {
		sbs[i] = strings.builder_make()
		idx := logger.add_output(&lgr, strings.to_writer(&sbs[i]), .Debug)
		testing.expect(t, idx >= 0, "add_output should succeed")
	}
	defer for &sb in sbs { strings.builder_destroy(&sb) }

	testing.expect_value(t, lgr.output_count, logger.MAX_OUTPUTS)

	// One more should fail
	sb_extra := strings.builder_make()
	defer strings.builder_destroy(&sb_extra)
	idx := logger.add_output(&lgr, strings.to_writer(&sb_extra), .Debug)
	testing.expect_value(t, idx, -1)
}

@(test)
test_multi_sink_level_filtering :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Create logger with output 0 at Warning level (to a string builder)
	sb0 := strings.builder_make()
	defer strings.builder_destroy(&sb0)
	lgr := logger.make_logger(lowest_level = .Warning, output = strings.to_writer(&sb0), timestamp_format = .None)
	lgr.options = {}

	// Add output 1 at Debug level
	sb1 := strings.builder_make()
	defer strings.builder_destroy(&sb1)
	logger.add_output(&lgr, strings.to_writer(&sb1), .Debug)

	// Log at Info — should only appear in output 1
	logger.log_info(&lgr, "info msg")
	out0 := strings.to_string(sb0)
	out1 := strings.to_string(sb1)
	testing.expect(t, !strings.contains(out0, "info msg"), "Warning-level sink should not contain Info message")
	testing.expect(t, strings.contains(out1, "info msg"), "Debug-level sink should contain Info message")

	// Log at Warning — should appear in both
	logger.log_warn(&lgr, "warn msg")
	out0 = strings.to_string(sb0)
	out1 = strings.to_string(sb1)
	testing.expect(t, strings.contains(out0, "warn msg"), "Warning-level sink should contain Warning message")
	testing.expect(t, strings.contains(out1, "warn msg"), "Debug-level sink should contain Warning message")
}

@(test)
test_set_level :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Info, timestamp_format = .None)
	testing.expect_value(t, lgr.lowest_level, logger.Level.Info)

	// Lower to Debug
	logger.set_level(&lgr, .Debug)
	testing.expect_value(t, lgr.outputs[0].level, logger.Level.Debug)
	testing.expect_value(t, lgr.lowest_level, logger.Level.Debug)

	// Raise to Warning
	logger.set_level(&lgr, .Warning)
	testing.expect_value(t, lgr.outputs[0].level, logger.Level.Warning)
	testing.expect_value(t, lgr.lowest_level, logger.Level.Warning)
}

@(test)
test_set_output_level :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Info, timestamp_format = .None)
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	logger.add_output(&lgr, strings.to_writer(&sb), .Warning)

	// Change output 1 to Error
	logger.set_output_level(&lgr, 1, .Error)
	testing.expect_value(t, lgr.outputs[1].level, logger.Level.Error)
	// lowest_level should still be Info (output 0)
	testing.expect_value(t, lgr.lowest_level, logger.Level.Info)
}

@(test)
test_bracketed_format :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(lowest_level = .Trace, timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "test")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// Should have bracketed format with --- separator
	testing.expect(t, strings.contains(result, "[INFO   ] --- test"), "should have bracketed format with --- separator")
}

@(test)
test_runtime_level_mapping :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Verify our level maps correctly to runtime levels
	testing.expect_value(t, logger.to_runtime_level(.Trace), runtime.Logger_Level.Debug)
	testing.expect_value(t, logger.to_runtime_level(.Debug), runtime.Logger_Level.Debug)
	testing.expect_value(t, logger.to_runtime_level(.Info), runtime.Logger_Level.Info)
	testing.expect_value(t, logger.to_runtime_level(.Hint), runtime.Logger_Level.Info)
	testing.expect_value(t, logger.to_runtime_level(.Success), runtime.Logger_Level.Info)
	testing.expect_value(t, logger.to_runtime_level(.Warning), runtime.Logger_Level.Warning)
	testing.expect_value(t, logger.to_runtime_level(.Error), runtime.Logger_Level.Error)
	testing.expect_value(t, logger.to_runtime_level(.Fatal), runtime.Logger_Level.Fatal)

	// Verify runtime → our level
	testing.expect_value(t, logger.runtime_to_level(.Debug), logger.Level.Debug)
	testing.expect_value(t, logger.runtime_to_level(.Info), logger.Level.Info)
	testing.expect_value(t, logger.runtime_to_level(.Warning), logger.Level.Warning)
	testing.expect_value(t, logger.runtime_to_level(.Error), logger.Level.Error)
	testing.expect_value(t, logger.runtime_to_level(.Fatal), logger.Level.Fatal)
}

@(test)
test_numeric_value_styling :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// With color: numeric values should get ANSI styling (yellow by default)
	lgr := logger.make_logger(timestamp_format = .None)
	sub := logger.with_fields(lgr, "port", "8080", "host", "localhost")
	result, ok := logger.to_str(sub, .Info, "test")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	// The numeric value "8080" should have ANSI escapes around it (yellow)
	// while "localhost" should not (value_style is zero by default)
	// We can verify by checking that the output contains the yellow color code
	// ESC[33m is yellow foreground
	testing.expect(t, strings.contains(result, "\x1b[33m"), "numeric value should be styled with yellow")
	testing.expect(t, strings.contains(result, "8080"), "should contain numeric value")
	testing.expect(t, strings.contains(result, "localhost"), "should contain text value")
}

@(test)
test_numeric_plain_no_styling :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// With plain key style: no number styling
	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}
	lgr.key_style = logger.plain_key_style()
	sub := logger.with_fields(lgr, "port", "8080")
	result, ok := logger.to_str(sub, .Info, "test")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, !strings.contains(result, "\x1b["), "plain style should have no ANSI escapes")
	testing.expect(t, strings.contains(result, "port=8080"), "should still contain key=value")
}

@(test)
test_caller_format_default_none :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lgr := logger.make_logger(timestamp_format = .None)
	lgr.options = {}

	result, ok := logger.to_str(lgr, .Info, "no caller")
	defer delete(result)

	testing.expect(t, ok, "to_str should succeed")
	testing.expect(t, !strings.contains(result, "tests.odin"), "default caller_format=None should not show location")
}
