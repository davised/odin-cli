package bench

import "../progress"

Progress_Bench_Data :: struct {
	simple: progress.Progress,
	full:   progress.Progress,
}

progress_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "progress/simple_bar",
			iterations = 100_000,
			bench_proc = bench_progress_simple,
			setup      = progress_setup,
			teardown   = progress_teardown,
		},
		{
			name       = "progress/full_bar",
			iterations = 100_000,
			bench_proc = bench_progress_full,
			setup      = progress_setup,
			teardown   = progress_teardown,
		},
	}
	return scenarios[:]
}

@(private = "file")
progress_setup :: proc() -> rawptr {
	data := new(Progress_Bench_Data)

	data.simple = progress.Progress {
		total           = 200,
		current         = 80,
		width           = 40,
		bar_style       = progress.bar_block(),
		show_percentage = true,
		mode            = .Plain,
	}

	data.full = progress.Progress {
		total           = 1000,
		current         = 420,
		width           = 50,
		bar_style       = progress.bar_block(),
		message         = "Processing",
		show_percentage = true,
		show_count      = true,
		show_elapsed    = true,
		mode            = .Plain,
	}

	return data
}

@(private = "file")
progress_teardown :: proc(user_data: rawptr) {
	free((^Progress_Bench_Data)(user_data))
}

@(private = "file")
bench_progress_simple :: proc(state: ^Bench_State) {
	data := (^Progress_Bench_Data)(state.user_data)
	progress.to_writer(state.writer, data.simple)
}

@(private = "file")
bench_progress_full :: proc(state: ^Bench_State) {
	data := (^Progress_Bench_Data)(state.user_data)
	progress.start(&data.full) // reset tick each iteration for consistent elapsed output
	progress.to_writer(state.writer, data.full)
}
