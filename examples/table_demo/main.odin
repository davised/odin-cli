package table_demo

import "core:fmt"
import table "../../table"
import term "../../term"
import style "../../style"

main :: proc() {
	width := 80
	if w, ok := term.terminal_width(); ok {
		width = w
		fmt.printfln("Detected terminal width: %d", width)
	} else {
		fmt.printfln("Could not detect terminal (stdout piped?), using default: %d", width)
	}

	fmt.println()

	// Full-width table
	{
		tbl := table.make_table(border = table.BORDER_ROUNDED)
		defer table.destroy_table(&tbl)

		tbl.width = width

		table.add_column(&tbl, style.bold("Name"))
		table.add_column(&tbl, style.bold("Role"), alignment = .Center)
		table.add_column(&tbl, style.bold("Status"), alignment = .Center)
		table.add_column(&tbl, style.bold("Email"), alignment = .Right)

		table.add_row(&tbl, "Alice Johnson", "Engineering Lead", style.green("Active"), "alice@example.com")
		table.add_row(&tbl, "Bob Smith", "Designer", style.yellow("Away"), "bob@example.com")
		table.add_row(&tbl, "Charlie Brown", "Product Manager", style.green("Active"), "charlie@example.com")
		table.add_row(&tbl, "Diana Prince", "QA Engineer", style.red("Offline"), "diana@example.com")

		fmt.printfln("Full terminal width (%d cols):", width)
		fmt.printfln("%v", tbl)
	}

	fmt.println()

	// Half-width — should truncate
	{
		half := width / 2
		tbl := table.make_table(border = table.BORDER_ROUNDED)
		defer table.destroy_table(&tbl)

		tbl.width = half

		table.add_column(&tbl, style.bold("Name"))
		table.add_column(&tbl, style.bold("Role"), alignment = .Center)
		table.add_column(&tbl, style.bold("Status"), alignment = .Center)
		table.add_column(&tbl, style.bold("Email"), alignment = .Right)

		table.add_row(&tbl, "Alice Johnson", "Engineering Lead", style.green("Active"), "alice@example.com")
		table.add_row(&tbl, "Bob Smith", "Designer", style.yellow("Away"), "bob@example.com")
		table.add_row(&tbl, "Charlie Brown", "Product Manager", style.green("Active"), "charlie@example.com")
		table.add_row(&tbl, "Diana Prince", "QA Engineer", style.red("Offline"), "diana@example.com")

		fmt.printfln("Half width (%d cols):", half)
		fmt.printfln("%v", tbl)
	}

	fmt.println()

	// Auto-width (no fill) for comparison
	{
		tbl := table.make_table(border = table.BORDER_ROUNDED)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, style.bold("Name"))
		table.add_column(&tbl, style.bold("Role"), alignment = .Center)
		table.add_column(&tbl, style.bold("Status"), alignment = .Center)
		table.add_column(&tbl, style.bold("Email"), alignment = .Right)

		table.add_row(&tbl, "Alice Johnson", "Engineering Lead", style.green("Active"), "alice@example.com")
		table.add_row(&tbl, "Bob Smith", "Designer", style.yellow("Away"), "bob@example.com")
		table.add_row(&tbl, "Charlie Brown", "Product Manager", style.green("Active"), "charlie@example.com")
		table.add_row(&tbl, "Diana Prince", "QA Engineer", style.red("Offline"), "diana@example.com")

		fmt.println("Auto width (no fill):")
		fmt.printfln("%v", tbl)
	}
}
