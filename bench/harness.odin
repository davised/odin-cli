package bench

import "../prof"
import "core:io"
import "core:strings"
import "core:time"

Bench_Result :: struct {
	name:       string,
	iterations: int,
	total:      time.Duration,
	min_dur:    time.Duration,
	max_dur:    time.Duration,
	avg:        time.Duration,
}

Bench_Proc :: #type proc(state: ^Bench_State)
Bench_Setup_Proc :: #type proc() -> rawptr
Bench_Teardown_Proc :: #type proc(user_data: rawptr)

Bench_State :: struct {
	writer:    io.Writer,
	user_data: rawptr,
}

Bench_Scenario :: struct {
	name:       string,
	iterations: int,
	bench_proc: Bench_Proc,
	setup:      Bench_Setup_Proc,
	teardown:   Bench_Teardown_Proc,
}

WARMUP_ITERATIONS :: 10

run_bench :: proc(scenario: Bench_Scenario) -> Bench_Result {
	sb := strings.builder_make(0, 4096)
	defer strings.builder_destroy(&sb)

	user_data: rawptr
	if scenario.setup != nil {
		user_data = scenario.setup()
	}

	state := Bench_State {
		writer    = strings.to_writer(&sb),
		user_data = user_data,
	}

	// Warmup
	for _ in 0 ..< WARMUP_ITERATIONS {
		strings.builder_reset(&sb)
		scenario.bench_proc(&state)
		free_all(context.temp_allocator)
	}

	// Measurement
	total: time.Duration
	min_dur := max(time.Duration)
	max_dur := min(time.Duration)

	for _ in 0 ..< scenario.iterations {
		strings.builder_reset(&sb)

		prof.begin(scenario.name)
		start := time.tick_now()
		scenario.bench_proc(&state)
		elapsed := time.tick_since(start)
		prof.end()

		total += elapsed
		if elapsed < min_dur do min_dur = elapsed
		if elapsed > max_dur do max_dur = elapsed

		free_all(context.temp_allocator)
	}

	if scenario.teardown != nil {
		scenario.teardown(user_data)
	}

	avg := total / time.Duration(scenario.iterations) if scenario.iterations > 0 else 0

	return Bench_Result {
		name       = scenario.name,
		iterations = scenario.iterations,
		total      = total,
		min_dur    = min_dur,
		max_dur    = max_dur,
		avg        = avg,
	}
}
