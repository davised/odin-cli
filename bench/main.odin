package bench

import "../prof"
import "../style"
import "../table"
import "../term"
import "core:fmt"
import "core:os"
import "core:time"

main :: proc() {
	prof.init()
	defer prof.destroy()

	all_scenarios: [dynamic]Bench_Scenario
	defer delete(all_scenarios)

	append(&all_scenarios, ..style_scenarios())
	append(&all_scenarios, ..progress_scenarios())
	append(&all_scenarios, ..table_scenarios())
	append(&all_scenarios, ..tree_scenarios())
	append(&all_scenarios, ..logger_scenarios())
	append(&all_scenarios, ..cli_scenarios())
	append(&all_scenarios, ..term_scenarios())

	results: [dynamic]Bench_Result
	defer delete(results)

	fmt.println("Running benchmarks...\n")

	for scenario in all_scenarios {
		fmt.printf("  %-35s", scenario.name)
		result := run_bench(scenario)
		append(&results, result)
		fmt.printf(" %10s avg\n", format_duration(result.avg))
	}

	fmt.println()
	display_results(results[:])
}

@(private = "file")
display_results :: proc(results: []Bench_Result) {
	t := table.make_table(
		border = table.BORDER_ROUNDED,
		padding = 1,
	)
	defer table.destroy_table(&t)

	header_style := style.Style {
		text_styles      = {.Bold},
		foreground_color = style.ANSI_Color.Cyan,
	}
	table.set_header_style(&t, header_style)

	table.add_column(&t, header = "Benchmark")
	table.add_column(&t, header = "Iterations", alignment = .Right)
	table.add_column(&t, header = "Total (ms)", alignment = .Right)
	table.add_column(&t, header = "Avg (us)", alignment = .Right)
	table.add_column(&t, header = "Min (us)", alignment = .Right)
	table.add_column(&t, header = "Max (us)", alignment = .Right)

	for r in results {
		table.add_row(
			&t,
			r.name,
			fmt.tprintf("%d", r.iterations),
			format_ms(r.total),
			format_us(r.avg),
			format_us(r.min_dur),
			format_us(r.max_dur),
		)
	}

	w := os.stream_from_handle(os.stdout)
	mode := term.detect_render_mode(os.stdout)
	table.to_writer(w, t, mode = mode)
}

@(private = "file")
format_duration :: proc(d: time.Duration) -> string {
	us := time.duration_microseconds(d)
	if us < 1 {
		ns := time.duration_nanoseconds(d)
		return fmt.tprintf("%dns", ns)
	}
	if us < 1000 {
		return fmt.tprintf("%.1fus", us)
	}
	ms := time.duration_milliseconds(d)
	if ms < 1000 {
		return fmt.tprintf("%.2fms", ms)
	}
	secs := time.duration_seconds(d)
	return fmt.tprintf("%.2fs", secs)
}

@(private = "file")
format_ms :: proc(d: time.Duration) -> string {
	ms := time.duration_milliseconds(d)
	return fmt.tprintf("%.2f", ms)
}

@(private = "file")
format_us :: proc(d: time.Duration) -> string {
	us := time.duration_microseconds(d)
	if us < 1 {
		ns := time.duration_nanoseconds(d)
		return fmt.tprintf("0.%03d", ns)
	}
	return fmt.tprintf("%.3f", us)
}
