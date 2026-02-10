#+feature using-stmt
package logger

import "../style"
import "base:runtime"
import "core:io"
import "core:os"

// Aliases for runtime logger types.
Level :: runtime.Logger_Level
Option :: runtime.Logger_Option
Options :: runtime.Logger_Options

MAX_FIELDS :: 16
LEVEL_COUNT :: 5

/* Timestamp_Format controls which time components are rendered. */
Timestamp_Format :: enum {
	None,
	Time_Only,
	Date_Only,
	Date_Time,
}

/* Field is a pre-bound key-value pair for structured logging. */
Field :: struct {
	key:   string,
	value: string,
}

/* Logger is the main logger struct. It holds styling configuration, output
   destination, pre-bound fields, and level filtering. All fields are value
   types so Logger can be cheaply copied (e.g. via with_fields). */
Logger :: struct {
	output:           io.Writer,
	lowest_level:     Level,
	level_styles:     [LEVEL_COUNT]Level_Style,
	key_style:        Key_Style,
	timestamp_format: Timestamp_Format,
	timestamp_style:  style.Style,
	message_style:    style.Style,
	prefix:           string,
	prefix_style:     style.Style,
	show_caller:      bool,
	caller_style:     style.Style,
	fields:           [MAX_FIELDS]Field,
	field_count:      int,
	options:          Options,
}

/* make_logger creates a new Logger with sensible defaults.
   Output defaults to stderr. Level defaults to .Info. */
make_logger :: proc(
	lowest_level: Level = .Info,
	output: Maybe(io.Writer) = nil,
	timestamp_format: Timestamp_Format = .Time_Only,
) -> Logger {
	w := output.? or_else os.stream_from_handle(os.stderr)
	return Logger {
		output = w,
		lowest_level = lowest_level,
		level_styles = default_level_styles(),
		key_style = default_key_style(),
		timestamp_format = timestamp_format,
		timestamp_style = default_timestamp_style(),
		caller_style = default_caller_style(),
		options = {.Terminal_Color},
	}
}

/* to_runtime_logger converts a Logger pointer into a runtime.Logger suitable
   for assigning to context.logger. The Logger must outlive the returned value. */
to_runtime_logger :: proc(lgr: ^Logger) -> runtime.Logger {
	return runtime.Logger{procedure = logger_proc, data = lgr, lowest_level = lgr.lowest_level, options = lgr.options}
}

/* with_fields returns a copy of the logger with additional pre-bound key-value
   fields. Keys and values are provided as alternating string arguments.
   Odd trailing values are ignored. The returned Logger is a value copy. */
with_fields :: proc(lgr: Logger, kvs: ..string) -> Logger {
	result := lgr
	pairs := len(kvs) / 2
	for i in 0 ..< pairs {
		if result.field_count >= MAX_FIELDS do break
		result.fields[result.field_count] = Field {
			key   = kvs[i * 2],
			value = kvs[i * 2 + 1],
		}
		result.field_count += 1
	}
	return result
}

/* set_prefix sets a prefix string and its style on the logger. */
set_prefix :: proc(lgr: ^Logger, text: string, sty: style.Style = {}) {
	lgr.prefix = text
	lgr.prefix_style = sty
}

/* log_debug logs a message at Debug level with optional structured key-value args.
   Args are alternating key/value pairs formatted via fmt.tprint (temp allocator). */
log_debug :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Debug, msg, args, loc)
}

/* log_info logs a message at Info level with optional structured key-value args.
   Args are alternating key/value pairs formatted via fmt.tprint (temp allocator). */
log_info :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Info, msg, args, loc)
}

/* log_warn logs a message at Warning level with optional structured key-value args.
   Args are alternating key/value pairs formatted via fmt.tprint (temp allocator). */
log_warn :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Warning, msg, args, loc)
}

/* log_error logs a message at Error level with optional structured key-value args.
   Args are alternating key/value pairs formatted via fmt.tprint (temp allocator). */
log_error :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Error, msg, args, loc)
}

/* log_fatal logs a message at Fatal level with optional structured key-value args.
   Args are alternating key/value pairs formatted via fmt.tprint (temp allocator). */
log_fatal :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Fatal, msg, args, loc)
}
