package bench

import "../style"
import "../table"
import "core:fmt"

Table_Bench_Data :: struct {
	small:  table.Table,
	medium: table.Table,
	large:  table.Table,
}

table_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "table/small (3x5)",
			iterations = 10_000,
			bench_proc = bench_table_small,
			setup      = table_setup,
			teardown   = table_teardown,
		},
		{
			name       = "table/medium (5x50)",
			iterations = 1_000,
			bench_proc = bench_table_medium,
			setup      = table_setup,
			teardown   = table_teardown,
		},
		{
			name       = "table/large (10x500)",
			iterations = 100,
			bench_proc = bench_table_large,
			setup      = table_setup,
			teardown   = table_teardown,
		},
	}
	return scenarios[:]
}

@(private = "file")
table_setup :: proc() -> rawptr {
	data := new(Table_Bench_Data)

	// Small: 3 cols, 5 rows
	data.small = table.make_table(border = table.BORDER_LIGHT)
	table.add_column(&data.small, header = "Name")
	table.add_column(&data.small, header = "Value")
	table.add_column(&data.small, header = "Status")
	for i in 0 ..< 5 {
		table.add_row(&data.small, fmt.aprintf("Item %d", i), fmt.aprintf("%d", i * 42), "OK")
	}

	// Medium: 5 cols, 50 rows, styled header, mixed alignment
	data.medium = table.make_table(border = table.BORDER_ROUNDED)
	table.add_column(&data.medium, header = "ID", alignment = .Right)
	table.add_column(&data.medium, header = "Name")
	table.add_column(&data.medium, header = "Category", alignment = .Center)
	table.add_column(&data.medium, header = "Score", alignment = .Right)
	table.add_column(&data.medium, header = "Description")
	table.set_header_style(&data.medium, style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Cyan})
	for i in 0 ..< 50 {
		table.add_row(
			&data.medium,
			fmt.aprintf("%d", i + 1),
			fmt.aprintf("Entry %d", i),
			fmt.aprintf("Cat-%c", rune('A' + i % 5)),
			fmt.aprintf("%.1f", f64(i * 17 % 100)),
			fmt.aprintf("Description for entry number %d", i),
		)
	}

	// Large: 10 cols, 500 rows
	data.large = table.make_table(border = table.BORDER_LIGHT)
	data.large.width = 120
	for c in 0 ..< 10 {
		table.add_column(&data.large, header = fmt.aprintf("Col %d", c))
	}
	for r in 0 ..< 500 {
		table.add_row(
			&data.large,
			fmt.aprintf("R%d", r),
			fmt.aprintf("data-%d", r),
			fmt.aprintf("%d", r * 7),
			fmt.aprintf("val%d", r % 20),
			"text",
			fmt.aprintf("%d%%", r % 100),
			"info",
			fmt.aprintf("x%d", r),
			"more",
			fmt.aprintf("end-%d", r),
		)
	}

	return data
}

@(private = "file")
table_teardown :: proc(user_data: rawptr) {
	data := (^Table_Bench_Data)(user_data)
	table.destroy_table(&data.small)
	table.destroy_table(&data.medium)
	table.destroy_table(&data.large)
	free(data)
}

@(private = "file")
bench_table_small :: proc(state: ^Bench_State) {
	data := (^Table_Bench_Data)(state.user_data)
	table.to_writer(state.writer, data.small, mode = .Plain)
}

@(private = "file")
bench_table_medium :: proc(state: ^Bench_State) {
	data := (^Table_Bench_Data)(state.user_data)
	table.to_writer(state.writer, data.medium, mode = .Full)
}

@(private = "file")
bench_table_large :: proc(state: ^Bench_State) {
	data := (^Table_Bench_Data)(state.user_data)
	table.to_writer(state.writer, data.large, mode = .Plain)
}
