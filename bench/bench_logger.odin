package bench

import "../logger"

Logger_Bench_Data :: struct {
	simple:      logger.Logger,
	with_fields: logger.Logger,
	full:        logger.Logger,
}

logger_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "logger/simple",
			iterations = 100_000,
			bench_proc = bench_logger_simple,
			setup      = logger_setup,
			teardown   = logger_teardown,
		},
		{
			name       = "logger/with_fields",
			iterations = 10_000,
			bench_proc = bench_logger_with_fields,
			setup      = logger_setup,
			teardown   = logger_teardown,
		},
		{
			name       = "logger/full",
			iterations = 10_000,
			bench_proc = bench_logger_full,
			setup      = logger_setup,
			teardown   = logger_teardown,
		},
	}
	return scenarios[:]
}

@(private = "file")
logger_setup :: proc() -> rawptr {
	data := new(Logger_Bench_Data)

	// Simple: no timestamp, no fields, no color
	data.simple = logger.make_logger(timestamp_format = .None)
	data.simple.options = {}

	// With fields: Time_Only timestamp + 5 fields, no color
	data.with_fields = logger.with_fields(
		logger.make_logger(timestamp_format = .Time_Only),
		"service", "api",
		"region", "us-east-1",
		"version", "1.2.3",
		"host", "web-01",
		"pid", "12345",
	)
	data.with_fields.options = {}

	// Full: Date_Time + caller Short + prefix + 5 fields, no color
	full_base := logger.make_logger(timestamp_format = .Date_Time)
	full_base.caller_format = .Short
	logger.set_prefix(&full_base, "myapp")
	data.full = logger.with_fields(
		full_base,
		"service", "api",
		"region", "us-east-1",
		"version", "1.2.3",
		"host", "web-01",
		"pid", "12345",
	)
	data.full.options = {}

	return data
}

@(private = "file")
logger_teardown :: proc(user_data: rawptr) {
	free((^Logger_Bench_Data)(user_data))
}

@(private = "file")
bench_logger_simple :: proc(state: ^Bench_State) {
	data := (^Logger_Bench_Data)(state.user_data)
	logger.to_writer(state.writer, data.simple, .Info, "Request handled successfully")
}

@(private = "file")
bench_logger_with_fields :: proc(state: ^Bench_State) {
	data := (^Logger_Bench_Data)(state.user_data)
	logger.to_writer(state.writer, data.with_fields, .Info, "Request handled successfully")
}

@(private = "file")
bench_logger_full :: proc(state: ^Bench_State) {
	data := (^Logger_Bench_Data)(state.user_data)
	logger.to_writer(state.writer, data.full, .Warning, "Connection pool exhausted")
}
