#+feature using-stmt
package logger

import "../style"
import "base:runtime"
import "core:io"
import "core:os"
import "core:terminal"

// Custom log levels with explicit int values. Trace/Hint/Success are only
// reachable via the direct API (log_trace, log_hint, log_success).
// Debug/Info/Warning/Error/Fatal match their runtime.Logger_Level counterparts.
Level :: enum int {
	Trace   = -10,
	Debug   = 0,
	Info    = 10,
	Hint    = 13,
	Success = 15,
	Warning = 20,
	Error   = 30,
	Fatal   = 40,
}

LEVEL_COUNT :: 8

// Aliases for runtime logger types.
Option :: runtime.Logger_Option
Options :: runtime.Logger_Options

MAX_FIELDS :: 16
MAX_OUTPUTS :: 4

/* Timestamp_Format controls which time components are rendered. */
Timestamp_Format :: enum {
	None,
	Time_Only,
	Date_Only,
	Date_Time,
}

/* Caller_Format controls how source location is displayed.
   Short shows [file.odin:42:proc()] (basename only, like core:log).
   Long shows the full path. */
Caller_Format :: enum {
	None,
	Short,
	Long,
}

/* Field is a pre-bound key-value pair for structured logging. */
Field :: struct {
	key:   string,
	value: string,
}

/* Output is a single output sink with its own minimum level filter and
   color setting. Color is auto-detected from the terminal handle when
   using make_logger (default stderr) or add_output_handle. */
Output :: struct {
	writer:    io.Writer,
	level:     Level,
	use_color: bool,
}

/* Logger is the main logger struct. It holds styling configuration, output
   sinks, pre-bound fields, and level filtering. All fields are value types
   so Logger can be cheaply copied (e.g. via with_fields). */
Logger :: struct {
	outputs:          [MAX_OUTPUTS]Output,
	output_count:     int,
	lowest_level:     Level,
	level_styles:     [LEVEL_COUNT]Level_Style,
	key_style:        Key_Style,
	timestamp_format: Timestamp_Format,
	timestamp_style:  style.Style,
	message_style:    style.Style,
	prefix:           string,
	prefix_style:     style.Style,
	caller_format:    Caller_Format,
	caller_style:     style.Style,
	fields:           [MAX_FIELDS]Field,
	field_count:      int,
	options:          Options,
}

/* make_logger creates a new Logger with sensible defaults.
   Output defaults to stderr with auto-detected color (respects NO_COLOR
   and checks if stderr is a terminal). Level defaults to .Info. */
make_logger :: proc(
	lowest_level: Level = .Info,
	output: Maybe(io.Writer) = nil,
	timestamp_format: Timestamp_Format = .Time_Only,
) -> Logger {
	w: io.Writer
	use_color: bool

	if out, ok := output.?; ok {
		// Explicit writer — can't detect terminal, assume no color.
		w = out
		use_color = false
	} else {
		// Default: stderr with auto-detection.
		w = os.stream_from_handle(os.stderr)
		use_color = detect_color(os.stderr)
	}

	lgr := Logger {
		output_count     = 1,
		lowest_level     = lowest_level,
		level_styles     = default_level_styles(),
		key_style        = default_key_style(),
		timestamp_format = timestamp_format,
		timestamp_style  = default_timestamp_style(),
		caller_style     = default_caller_style(),
		options          = {.Terminal_Color},
	}
	lgr.outputs[0] = Output{writer = w, level = lowest_level, use_color = use_color}
	return lgr
}

/* to_runtime_logger converts a Logger pointer into a runtime.Logger suitable
   for assigning to context.logger. The Logger must outlive the returned value.
   Note: the runtime logger's level filter uses the coarse runtime.Logger_Level;
   if outputs are added after this call, the runtime copy won't reflect the change. */
to_runtime_logger :: proc(lgr: ^Logger) -> runtime.Logger {
	return runtime.Logger {
		procedure     = logger_proc,
		data          = lgr,
		lowest_level  = to_runtime_level(lgr.lowest_level),
		options       = lgr.options,
	}
}

/* add_output adds an output sink with explicit color control.
   Returns the index of the new output, or -1 if MAX_OUTPUTS is reached. */
add_output :: proc(lgr: ^Logger, w: io.Writer, level: Level, use_color: bool = false) -> int {
	if lgr.output_count >= MAX_OUTPUTS do return -1
	idx := lgr.output_count
	lgr.outputs[idx] = Output{writer = w, level = level, use_color = use_color}
	lgr.output_count += 1
	recompute_lowest_level(lgr)
	return idx
}

/* add_output_handle adds an output sink from an os.Handle with auto-detected
   color (respects NO_COLOR and checks if the handle is a terminal).
   Returns the index of the new output, or -1 if MAX_OUTPUTS is reached. */
add_output_handle :: proc(lgr: ^Logger, handle: os.Handle, level: Level) -> int {
	return add_output(lgr, os.stream_from_handle(handle), level, detect_color(handle))
}

/* set_level sets the minimum level of output 0 (the default sink).
   Useful for CLI -v/-q verbosity adjustment. Recomputes lowest_level. */
set_level :: proc(lgr: ^Logger, level: Level) {
	if lgr.output_count > 0 {
		lgr.outputs[0].level = level
	}
	recompute_lowest_level(lgr)
}

/* set_output_level sets the minimum level of a specific output sink.
   Recomputes lowest_level. */
set_output_level :: proc(lgr: ^Logger, index: int, level: Level) {
	if index >= 0 && index < lgr.output_count {
		lgr.outputs[index].level = level
	}
	recompute_lowest_level(lgr)
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

/* log_trace logs a message at Trace level with optional structured key-value args. */
log_trace :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Trace, msg, args, loc)
}

/* log_debug logs a message at Debug level with optional structured key-value args. */
log_debug :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Debug, msg, args, loc)
}

/* log_info logs a message at Info level with optional structured key-value args. */
log_info :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Info, msg, args, loc)
}

/* log_hint logs a message at Hint level with optional structured key-value args. */
log_hint :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Hint, msg, args, loc)
}

/* log_success logs a message at Success level with optional structured key-value args. */
log_success :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Success, msg, args, loc)
}

/* log_warn logs a message at Warning level with optional structured key-value args. */
log_warn :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Warning, msg, args, loc)
}

/* log_error logs a message at Error level with optional structured key-value args. */
log_error :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Error, msg, args, loc)
}

/* log_fatal logs a message at Fatal level with optional structured key-value args. */
log_fatal :: proc(lgr: ^Logger, msg: string, args: ..any, loc := #caller_location) {
	log_msg(lgr, .Fatal, msg, args, loc)
}

// --- Runtime level mapping helpers ---

/* to_runtime_level clamps our Level to runtime.Logger_Level for the runtime's
   coarse filter. Custom levels (Trace, Hint, Success) map to the nearest
   runtime level. */
to_runtime_level :: proc(level: Level) -> runtime.Logger_Level {
	if level <= .Debug   do return .Debug
	if level <= .Success do return .Info
	if level <= .Warning do return .Warning
	if level <= .Error   do return .Error
	return .Fatal
}

/* runtime_to_level maps an incoming runtime.Logger_Level to our Level. */
runtime_to_level :: proc(level: runtime.Logger_Level) -> Level {
	switch level {
	case .Debug:   return .Debug
	case .Info:    return .Info
	case .Warning: return .Warning
	case .Error:   return .Error
	case .Fatal:   return .Fatal
	}
	unreachable()
}

// --- Internal helpers ---

/* detect_color returns true if the handle is a terminal and color is globally
   enabled (respects NO_COLOR env var via core:terminal). */
@(private)
detect_color :: proc(handle: os.Handle) -> bool {
	return terminal.color_enabled && terminal.is_terminal(handle)
}

@(private)
recompute_lowest_level :: proc(lgr: ^Logger) {
	if lgr.output_count == 0 {
		lgr.lowest_level = .Fatal
		return
	}
	lowest := lgr.outputs[0].level
	for i in 1 ..< lgr.output_count {
		if lgr.outputs[i].level < lowest {
			lowest = lgr.outputs[i].level
		}
	}
	lgr.lowest_level = lowest
}
