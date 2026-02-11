package logger_demo

import "core:fmt"
import "core:log"
import "core:os"
import logger "../../logger"
import style "../../style"

main :: proc() {
	// --- Mode A: context.logger drop-in ---
	fmt.println("=== Mode A: context.logger ===\n")

	lgr := logger.make_logger(lowest_level = .Debug)
	context.logger = logger.to_runtime_logger(&lgr)

	log.debug("Initializing subsystems")
	log.info("Server started")
	log.warn("Cache miss rate high")
	log.error("Connection refused")

	// --- Mode B: direct structured logging ---
	fmt.println("\n=== Mode B: direct structured logging ===\n")

	app := logger.make_logger(lowest_level = .Trace)
	logger.set_prefix(&app, "myapp", style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Magenta})

	logger.log_trace(&app, "deep trace info", "subsystem", "parser")
	logger.log_debug(&app, "loading config", "path", "/etc/app.toml")
	logger.log_info(&app, "server started", "host", "0.0.0.0", "port", "8080")
	logger.log_hint(&app, "try --verbose for more detail")
	logger.log_success(&app, "all checks passed", "tests", "42")
	logger.log_warn(&app, "request slow", "duration", "2.5s", "path", "/api/users")
	logger.log_error(&app, "connection failed", "err", "timeout", "retries", "3")

	// --- Sub-loggers with pre-bound fields ---
	fmt.println("\n=== Sub-loggers with pre-bound fields ===\n")

	db := logger.with_fields(app, "component", "database", "driver", "postgres")
	logger.log_info(&db, "connection pool ready", "max_conns", "25")
	logger.log_warn(&db, "slow query", "duration", "850ms", "table", "users")

	http := logger.with_fields(app, "component", "http")
	logger.log_info(&http, "request", "method", "GET", "path", "/api/health", "status", "200")
	logger.log_success(&http, "request", "method", "POST", "path", "/api/users", "status", "201")
	logger.log_error(&http, "request", "method", "GET", "path", "/api/admin", "status", "403")

	// --- Multi-sink output ---
	fmt.println("\n=== Multi-sink output (stderr=WARN+, stdout=DEBUG+) ===\n")

	multi := logger.make_logger(lowest_level = .Warning)
	// Add stdout as a second sink at Debug level (auto-detects color from handle)
	logger.add_output_handle(&multi, os.stdout, .Debug)

	logger.log_debug(&multi, "this goes to stdout only")
	logger.log_info(&multi, "this also goes to stdout only")
	logger.log_warn(&multi, "this goes to both stderr and stdout")
	logger.log_error(&multi, "this also goes to both")

	// --- set_level for CLI verbosity ---
	fmt.println("\n=== CLI verbosity adjustment ===\n")

	cli := logger.make_logger()
	logger.log_debug(&cli, "hidden at default level")
	logger.log_info(&cli, "visible at default level")

	// Simulate -v flag
	logger.set_level(&cli, .Debug)
	logger.log_debug(&cli, "now visible after -v")

	// Simulate -q flag
	logger.set_level(&cli, .Warning)
	logger.log_info(&cli, "hidden after -q")
	logger.log_warn(&cli, "still visible after -q")

	// --- Timestamp formats ---
	fmt.println("\n=== Timestamp formats ===\n")

	for tf in logger.Timestamp_Format {
		l := logger.make_logger(timestamp_format = tf)
		logger.log_info(&l, fmt.tprintf("timestamp_format = %v", tf))
	}

	// --- Plain (no-color) output ---
	fmt.println("\n=== Plain output (no color) ===\n")

	plain := logger.make_logger(lowest_level = .Debug, timestamp_format = .None)
	plain.options = {}
	plain.level_styles = logger.plain_level_styles()
	plain.key_style = logger.plain_key_style()

	logger.log_info(&plain, "no ANSI escapes here", "key", "value")
	logger.log_error(&plain, "also plain", "code", "500")

	// --- Caller location (short = basename only, like core:log) ---
	fmt.println("\n=== With caller location (short) ===\n")

	cl := logger.make_logger(timestamp_format = .None)
	cl.caller_format = .Short

	logger.log_info(&cl, "short caller: basename + proc")
	logger.log_warn(&cl, "compact for per-line display")

	// --- Caller location (long = full path) ---
	fmt.println("\n=== With caller location (long) ===\n")

	cl_long := logger.make_logger(timestamp_format = .None)
	cl_long.caller_format = .Long

	logger.log_info(&cl_long, "long caller: full path + proc")

	// --- All levels ---
	fmt.println("\n=== All log levels ===\n")

	all := logger.make_logger(lowest_level = .Trace, timestamp_format = .None)
	logger.log_trace(&all, "ultra-verbose trace")
	logger.log_debug(&all, "detailed debug info")
	logger.log_info(&all, "normal operation")
	logger.log_hint(&all, "helpful suggestion")
	logger.log_success(&all, "operation completed")
	logger.log_warn(&all, "something looks off")
	logger.log_error(&all, "something went wrong")
	logger.log_fatal(&all, "cannot continue")
}
