package bench

import "../style"

style_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "style/simple",
			iterations = 100_000,
			bench_proc = bench_style_simple,
		},
		{
			name       = "style/complex",
			iterations = 100_000,
			bench_proc = bench_style_complex,
		},
	}
	return scenarios[:]
}

@(private = "file")
bench_style_simple :: proc(state: ^Bench_State) {
	st := style.bold(style.red("Hello, styled world!"))
	style.to_writer(state.writer, st, mode = .Full)
}

@(private = "file")
bench_style_complex :: proc(state: ^Bench_State) {
	st := style.Styled_Text {
		text = "Complex styled text with many attributes",
		style = style.Style {
			text_styles      = {.Bold, .Italic, .Underline},
			foreground_color = style.RGB{r = 255, g = 128, b = 0},
			background_color = style.ANSI_Color.Blue,
		},
	}
	style.to_writer(state.writer, st, mode = .Full)
}
