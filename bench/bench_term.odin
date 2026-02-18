package bench

import "../style"
import "../term"
import "core:fmt"

term_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "term/display_width ASCII",
			iterations = 100_000,
			bench_proc = bench_display_width_ascii,
		},
		{
			name       = "term/display_width ANSI",
			iterations = 100_000,
			bench_proc = bench_display_width_ansi,
		},
		{
			name       = "term/truncate ASCII",
			iterations = 100_000,
			bench_proc = bench_truncate_ascii,
		},
		{
			name       = "term/truncate ANSI",
			iterations = 100_000,
			bench_proc = bench_truncate_ansi,
		},
		{
			name       = "term/truncate ANSI no-op",
			iterations = 100_000,
			bench_proc = bench_truncate_ansi_noop,
		},
		{
			name       = "term/strip_ansi",
			iterations = 100_000,
			bench_proc = bench_strip_ansi,
		},
		{
			name       = "style/st() multi-token",
			iterations = 100_000,
			bench_proc = bench_st_multi_token,
		},
		{
			name       = "style/st() paren-concat",
			iterations = 100_000,
			bench_proc = bench_st_paren_concat,
		},
	}
	return scenarios[:]
}

// --- display_width ---

@(private = "file")
PLAIN_80 :: "The quick brown fox jumps over the lazy dog near the river bank, watching clouds"

@(private = "file")
ANSI_MULTI :: "\x1b[1;31mThe quick\x1b[0m \x1b[32mbrown fox\x1b[0m \x1b[34mjumps over\x1b[0m the lazy dog"

@(private = "file")
bench_display_width_ascii :: proc(state: ^Bench_State) {
	_ = term.display_width(PLAIN_80)
}

@(private = "file")
bench_display_width_ansi :: proc(state: ^Bench_State) {
	_ = term.display_width(ANSI_MULTI)
}

// --- truncate ---

@(private = "file")
bench_truncate_ascii :: proc(state: ^Bench_State) {
	_ = term.truncate(PLAIN_80, 40)
}

@(private = "file")
bench_truncate_ansi :: proc(state: ^Bench_State) {
	_ = term.truncate(ANSI_MULTI, 25)
}

@(private = "file")
bench_truncate_ansi_noop :: proc(state: ^Bench_State) {
	// ANSI string that fits — exercises early-exit path
	_ = term.truncate(ANSI_MULTI, 200)
}

// --- strip_ansi ---

@(private = "file")
bench_strip_ansi :: proc(state: ^Bench_State) {
	_ = term.strip_ansi(ANSI_MULTI)
}

// --- style/st() parsing ---

@(private = "file")
bench_st_multi_token :: proc(state: ^Bench_State) {
	st := style.st("hello", "bold italic fg:red bg:blue")
	style.to_writer(state.writer, st, mode = .Full)
}

@(private = "file")
bench_st_paren_concat :: proc(state: ^Bench_State) {
	// Exercises parse_split with parenthesized tokens and no-space concatenation
	st := style.st("hello", "underline bold fg:rgb(255, 0, 0)bg:hsl(120,1,0.5)")
	style.to_writer(state.writer, st, mode = .Full)
}
