#+feature using-stmt
#+feature global-context
package logger

import "../style"
import "base:runtime"
import "core:fmt"
import "core:io"
import "core:strings"
import "core:time"

// --- fmt formatter registration ---

@(private = "file")
_formatter_map: map[typeid]fmt.User_Formatter

@(private = "file")
@(init)
init_formatter :: proc() {
	if fmt._user_formatters == nil {
		fmt._user_formatters = &_formatter_map
	}
	fmt.register_user_formatter(type_info_of(Logger).id, logger_formatter)
}

// --- Public rendering API ---

/* to_writer renders a single log line for the given level and message to an
   io.Writer. This is the zero-allocation rendering core. */
to_writer :: proc(
	w: io.Writer,
	lgr: Logger,
	level: Level,
	msg: string,
	location: runtime.Source_Code_Location = #caller_location,
	n: ^int = nil,
) -> bool {
	use_color := .Terminal_Color in lgr.options
	write_core(w, lgr, level, msg, use_color, n) or_return

	// Caller location (at end for Mode A)
	if lgr.show_caller {
		write_str(w, " ", n) or_return
		write_caller(w, location, lgr.caller_style, use_color, n) or_return
	}

	return true
}

/* to_str renders a log line to an allocated string. The caller owns the
   returned string. */
to_str :: proc(
	lgr: Logger,
	level: Level,
	msg: string,
	location: runtime.Source_Code_Location = #caller_location,
	allocator := context.allocator,
) -> (
	string,
	bool,
) #optional_ok {
	sb := strings.builder_make(allocator = allocator)
	ok := to_writer(strings.to_writer(&sb), lgr, level, msg, location)
	return strings.to_string(sb), ok
}

// --- fmt formatter ---

@(private = "file")
logger_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
	lgr := cast(^Logger)arg.data
	switch verb {
	case 'v', 's':
		return to_writer(fi.writer, lgr^, .Info, "logger", n = &fi.n)
	case 'w':
		fi.ignore_user_formatters = true
		fmt.fmt_value(fi = fi, v = lgr^, verb = 'w')
		return true
	case:
		return false
	}
}

// --- runtime.Logger_Proc implementation ---

/* logger_proc implements runtime.Logger_Proc so the logger can be used with
   context.logger. It respects the Terminal_Color option. */
logger_proc :: proc(data: rawptr, level: Level, text: string, options: Options, location := #caller_location) {
	lgr := cast(^Logger)data
	if lgr == nil do return
	if level < lgr.lowest_level do return

	// Use a copy so we can adjust options per-call without mutating the source.
	local := lgr^
	local.options = options

	if to_writer(local.output, local, level, text, location) {
		write_str(local.output, "\n", nil)
	}
}

// --- Internal: direct logging for Mode B ---

/* log_msg is the internal implementation for the direct log_debug/info/warn/error/fatal
   procs. It formats ..any args as key=value pairs using fmt.tprint (via the temp
   allocator) and writes the complete line plus newline. */
@(private)
log_msg :: proc(lgr: ^Logger, level: Level, msg: string, args: []any, loc: runtime.Source_Code_Location) {
	if level < lgr.lowest_level do return

	w := lgr.output
	use_color := .Terminal_Color in lgr.options

	if !write_core(w, lgr^, level, msg, use_color, nil) do return

	// Inline key=value args (alternating key: any, value: any)
	pairs := len(args) / 2
	for i in 0 ..< pairs {
		key_str := fmt.tprint(args[i * 2])
		val_str := fmt.tprint(args[i * 2 + 1])
		if !write_str(w, " ", nil) do return
		if !write_field(w, key_str, val_str, lgr.key_style, use_color, nil) do return
	}

	// Caller location (after inline args for Mode B)
	if lgr.show_caller {
		if !write_str(w, " ", nil) do return
		if !write_caller(w, loc, lgr.caller_style, use_color, nil) do return
	}

	write_str(w, "\n", nil)
}

// --- Shared rendering core ---

/* write_core renders the common parts of a log line: timestamp, level, prefix,
   message, and pre-bound fields. Both to_writer and log_msg call this. */
@(private = "file")
write_core :: proc(w: io.Writer, lgr: Logger, level: Level, msg: string, use_color: bool, n: ^int) -> bool {
	// Timestamp
	if lgr.timestamp_format != .None {
		write_timestamp(w, lgr.timestamp_format, lgr.timestamp_style, use_color, n) or_return
		write_str(w, " ", n) or_return
	}

	// Level prefix
	idx := level_to_index(level)
	ls := lgr.level_styles[idx]
	write_styled_str(w, ls.prefix, ls.prefix_style, use_color, n) or_return
	write_str(w, " ", n) or_return

	// Optional prefix
	if lgr.prefix != "" {
		write_styled_str(w, lgr.prefix, lgr.prefix_style, use_color, n) or_return
		write_str(w, " ", n) or_return
	}

	// Message
	if msg != "" {
		write_styled_str(w, msg, lgr.message_style, use_color, n) or_return
	}

	// Pre-bound fields
	for i in 0 ..< lgr.field_count {
		write_str(w, " ", n) or_return
		write_field(w, lgr.fields[i].key, lgr.fields[i].value, lgr.key_style, use_color, n) or_return
	}

	return true
}

// --- Internal helpers ---

@(private = "file")
write_str :: proc(w: io.Writer, s: string, n: ^int) -> bool {
	_, err := io.write_string(w, s, n)
	return err == .None
}

/* write_styled_str writes text with ANSI styling if the style is non-zero
   and use_color is true. Skips escape sequences for plain output. */
@(private = "file")
write_styled_str :: proc(w: io.Writer, text: string, sty: style.Style, use_color: bool, n: ^int) -> bool {
	if use_color && !is_zero_style(sty) {
		st := style.Styled_Text {
			text  = text,
			style = sty,
		}
		return style.to_writer(w, st, n)
	}
	return write_str(w, text, n)
}

/* is_zero_style returns true if the style has no text styles and no colors set. */
@(private = "file")
is_zero_style :: proc(sty: style.Style) -> bool {
	return sty.text_styles == {} && sty.foreground_color == nil && sty.background_color == nil
}

/* level_to_index maps Level enum values (0, 10, 20, 30, 40) to array indices 0-4. */
@(private = "file")
level_to_index :: proc(level: Level) -> int {
	switch level {
	case .Debug:
		return 0
	case .Info:
		return 1
	case .Warning:
		return 2
	case .Error:
		return 3
	case .Fatal:
		return 4
	}
	unreachable()
}

/* write_timestamp writes the current time formatted according to the timestamp
   format into the writer using a stack buffer. */
@(private = "file")
write_timestamp :: proc(w: io.Writer, tf: Timestamp_Format, sty: style.Style, use_color: bool, n: ^int) -> bool {
	if tf == .None do return true

	now := time.now()
	h, min, sec := time.clock_from_time(now)
	y, mon, d := time.date(now)

	buf: [20]u8 // "2006-01-02 15:04:05" = 19 chars max
	pos := 0

	if tf == .Date_Only || tf == .Date_Time {
		pos = write_int4(buf[:], pos, clamp(y, 0, 9999))
		buf[pos] = '-'
		pos += 1
		pos = write_int2(buf[:], pos, clamp(int(mon), 0, 99))
		buf[pos] = '-'
		pos += 1
		pos = write_int2(buf[:], pos, clamp(d, 0, 99))
	}

	if tf == .Date_Time {
		buf[pos] = ' '
		pos += 1
	}

	if tf == .Time_Only || tf == .Date_Time {
		pos = write_int2(buf[:], pos, clamp(h, 0, 99))
		buf[pos] = ':'
		pos += 1
		pos = write_int2(buf[:], pos, clamp(min, 0, 99))
		buf[pos] = ':'
		pos += 1
		pos = write_int2(buf[:], pos, clamp(sec, 0, 99))
	}

	ts := string(buf[:pos])
	return write_styled_str(w, ts, sty, use_color, n)
}

/* write_field writes a single key=value field with optional styling. */
@(private = "file")
write_field :: proc(w: io.Writer, key: string, value: string, ks: Key_Style, use_color: bool, n: ^int) -> bool {
	write_styled_str(w, key, ks.key_style, use_color, n) or_return
	write_styled_str(w, ks.separator, ks.separator_style, use_color, n) or_return
	write_styled_str(w, value, ks.value_style, use_color, n) or_return
	return true
}

/* write_caller writes a caller location as <file:line>. Each component is
   written directly to the writer to avoid fixed-buffer truncation. */
@(private = "file")
write_caller :: proc(
	w: io.Writer,
	loc: runtime.Source_Code_Location,
	sty: style.Style,
	use_color: bool,
	n: ^int,
) -> bool {
	line_buf: [16]u8
	line_str := itoa(line_buf[:], int(loc.line))

	if use_color && !is_zero_style(sty) {
		// Build the caller string in a single styled span
		caller_buf: [512]u8
		pos := 0
		pos = copy_to_buf(caller_buf[:], pos, "<")
		pos = copy_to_buf(caller_buf[:], pos, loc.file_path)
		pos = copy_to_buf(caller_buf[:], pos, ":")
		pos = copy_to_buf(caller_buf[:], pos, line_str)
		pos = copy_to_buf(caller_buf[:], pos, ">")
		st := style.Styled_Text {
			text  = string(caller_buf[:pos]),
			style = sty,
		}
		return style.to_writer(w, st, n)
	}

	// Plain mode: write components directly (no truncation risk)
	write_str(w, "<", n) or_return
	write_str(w, loc.file_path, n) or_return
	write_str(w, ":", n) or_return
	write_str(w, line_str, n) or_return
	write_str(w, ">", n) or_return
	return true
}

/* itoa converts a non-negative integer to a string in the provided buffer. */
@(private = "file")
itoa :: proc(buf: []u8, val: int) -> string {
	v := val
	if v < 0 do v = 0
	if v == 0 {
		buf[len(buf) - 1] = '0'
		return string(buf[len(buf) - 1:])
	}
	i := len(buf)
	for v > 0 {
		i -= 1
		buf[i] = u8('0' + v % 10)
		v /= 10
	}
	return string(buf[i:])
}

/* write_int2 writes a zero-padded 2-digit integer into buf at pos.
   Value must be in range 0-99 (caller should clamp). */
@(private = "file")
write_int2 :: proc(buf: []u8, pos: int, val: int) -> int {
	buf[pos] = u8('0' + val / 10)
	buf[pos + 1] = u8('0' + val % 10)
	return pos + 2
}

/* write_int4 writes a zero-padded 4-digit integer into buf at pos.
   Value must be in range 0-9999 (caller should clamp). */
@(private = "file")
write_int4 :: proc(buf: []u8, pos: int, val: int) -> int {
	buf[pos] = u8('0' + val / 1000)
	buf[pos + 1] = u8('0' + (val / 100) % 10)
	buf[pos + 2] = u8('0' + (val / 10) % 10)
	buf[pos + 3] = u8('0' + val % 10)
	return pos + 4
}

/* copy_to_buf copies src into buf starting at pos, returns new pos. */
@(private = "file")
copy_to_buf :: proc(buf: []u8, pos: int, src: string) -> int {
	end := min(pos + len(src), len(buf))
	copy(buf[pos:end], src)
	return end
}
