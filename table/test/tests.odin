package table_test

import "core:testing"
import "core:strings"
import "core:time"
import table ".."
import style "../../style"

@(test)
test_display_width :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		test_cases := []struct {
				content:  table.Cell_Content,
				expected: int,
		}{
				{"hello", 5},
				{"", 0},
				{"abc", 3},
				{style.Styled_Text{text = "styled", style = style.Style{text_styles = {.Bold}}}, 6},
				{style.Styled_Text{text = "", style = style.Style{}}, 0},
		}

		for tc in test_cases {
				result := table.display_width(tc.content)
				testing.expect_value(t, result, tc.expected)
		}
}

@(test)
test_text_display_width :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		test_cases := []struct {
				input:    string,
				expected: int,
		}{
				{"hello", 5},
				{"", 0},
				{"café", 4},
				{"abc123", 6},
		}

		for tc in test_cases {
				result := table.text_display_width(tc.input)
				testing.expect_value(t, result, tc.expected)
		}
}

@(test)
test_compute_column_widths :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Basic auto-sizing
		{
				tbl := table.make_table()
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "Name")
				table.add_column(&tbl, "Age")
				table.add_row(&tbl, "Alice", "30")
				table.add_row(&tbl, "Bob", "25")

				widths := table.compute_column_widths(tbl)
				testing.expect_value(t, widths[0], 5) // "Alice" is longest
				testing.expect_value(t, widths[1], 3) // "Age" header is longest
		}

		// Min width
		{
				tbl := table.make_table()
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "A", min_width = 10)
				table.add_row(&tbl, "hi")

				widths := table.compute_column_widths(tbl)
				testing.expect_value(t, widths[0], 10)
		}

		// Max width
		{
				tbl := table.make_table()
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "H", max_width = 3)
				table.add_row(&tbl, "longtext")

				widths := table.compute_column_widths(tbl)
				testing.expect_value(t, widths[0], 3)
		}
}

@(test)
test_alignment :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Test LEFT alignment via render
		{
				tbl := table.make_table(border = table.BORDER_ASCII)
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "Col", alignment = .LEFT, min_width = 8)
				table.add_row(&tbl, "hi")

				result, ok := table.to_str(tbl)
				defer delete(result)

				testing.expect(t, ok, "to_str should succeed")
				// "hi" left-aligned in 8 chars: "| hi       |"
				testing.expect(t, strings.contains(result, "| hi       |"), "LEFT alignment should pad right")
		}

		// Test RIGHT alignment via render
		{
				tbl := table.make_table(border = table.BORDER_ASCII)
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "Col", alignment = .RIGHT, min_width = 8)
				table.add_row(&tbl, "hi")

				result, ok := table.to_str(tbl)
				defer delete(result)

				testing.expect(t, ok, "to_str should succeed")
				testing.expect(t, strings.contains(result, "|       hi |"), "RIGHT alignment should pad left")
		}

		// Test CENTER alignment via render
		{
				tbl := table.make_table(border = table.BORDER_ASCII)
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "Col", alignment = .CENTER, min_width = 8)
				table.add_row(&tbl, "hi")

				result, ok := table.to_str(tbl)
				defer delete(result)

				testing.expect(t, ok, "to_str should succeed")
				testing.expect(t, strings.contains(result, "|    hi    |"), "CENTER alignment should pad both sides")
		}
}

@(test)
test_render_basic :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Name")
		table.add_column(&tbl, "Age")
		table.add_column(&tbl, "City")
		table.add_row(&tbl, "Alice", "30", "NYC")
		table.add_row(&tbl, "Bob", "25", "LA")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")

		expected := strings.concatenate({
				"+-------+-----+------+\n",
				"| Name  | Age | City |\n",
				"+-------+-----+------+\n",
				"| Alice | 30  | NYC  |\n",
				"| Bob   | 25  | LA   |\n",
				"+-------+-----+------+\n",
		})
		defer delete(expected)

		testing.expect_value(t, result, expected)
}

@(test)
test_border_none :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_NONE)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "A")
		table.add_column(&tbl, "B")
		table.add_row(&tbl, "1", "2")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		// No borders, just content with padding
		testing.expect(t, !strings.contains(result, "+"), "BORDER_NONE should have no border chars")
		testing.expect(t, !strings.contains(result, "|"), "BORDER_NONE should have no border chars")
}

@(test)
test_border_light :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_LIGHT)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "X")
		table.add_row(&tbl, "1")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		testing.expect(t, strings.contains(result, "┌"), "BORDER_LIGHT should use light box chars")
		testing.expect(t, strings.contains(result, "│"), "BORDER_LIGHT should use light box chars")
		testing.expect(t, strings.contains(result, "└"), "BORDER_LIGHT should use light box chars")
}

@(test)
test_border_rounded :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ROUNDED)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "X")
		table.add_row(&tbl, "1")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		testing.expect(t, strings.contains(result, "╭"), "BORDER_ROUNDED should use rounded corners")
		testing.expect(t, strings.contains(result, "╰"), "BORDER_ROUNDED should use rounded corners")
}

@(test)
test_styled_cells :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Status")
		table.add_column(&tbl, "Message")

		// Row with Styled_Text cell (cell-level style takes precedence)
		table.add_row(&tbl, style.bold("OK"), "All good")

		// Row with row-level style
		row_style := style.Style{foreground_color = style.ANSI_FG.Red}
		table.add_styled_row(&tbl, row_style, "FAIL", "Error occurred")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		// Styled cells should contain ANSI codes
		testing.expect(t, strings.contains(result, "\x1b["), "Styled cells should contain ANSI escape codes")
		testing.expect(t, strings.contains(result, "\x1b[0m"), "Styled cells should contain ANSI reset")
}

@(test)
test_header_style :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Name")
		table.add_column(&tbl, "Value")
		table.set_header_style(&tbl, style.Style{text_styles = {.Bold}})
		table.add_row(&tbl, "key", "val")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "to_str should succeed")
		// Header should contain bold ANSI code
		testing.expect(t, strings.contains(result, "\x1b[1m"), "Header should contain bold ANSI code")
}

@(test)
test_empty_table :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// No columns at all
		{
				tbl := table.make_table()
				defer table.destroy_table(&tbl)

				result, ok := table.to_str(tbl)
				defer delete(result)

				testing.expect(t, ok, "empty table should succeed")
				testing.expect_value(t, result, "")
		}

		// Columns but no rows
		{
				tbl := table.make_table(border = table.BORDER_ASCII)
				defer table.destroy_table(&tbl)

				table.add_column(&tbl, "Name")
				table.add_column(&tbl, "Age")

				result, ok := table.to_str(tbl)
				defer delete(result)

				testing.expect(t, ok, "headers-only table should succeed")
				testing.expect(t, strings.contains(result, "Name"), "should contain header text")
				testing.expect(t, strings.contains(result, "Age"), "should contain header text")
		}
}

@(test)
test_missing_cells :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "A")
		table.add_column(&tbl, "B")
		table.add_column(&tbl, "C")

		// Row with fewer cells than columns
		table.add_row(&tbl, "1")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "missing cells should succeed")
		// Should still render 3 columns
		lines := strings.split(result, "\n")
		defer delete(lines)
		// First data line should have correct number of separators
		for line in lines {
				if strings.contains(line, "|") {
						pipe_count := strings.count(line, "|")
						// With left+right borders and 2 internal separators = 4 pipes per data row
						testing.expect(t, pipe_count == 4, "should have correct number of column separators")
						break
				}
		}
}

@(test)
test_max_width_truncation :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Col", max_width = 5)
		table.add_row(&tbl, "very long text here")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "truncation should succeed")
		// Content should be truncated with ellipsis
		testing.expect(t, strings.contains(result, "…"), "truncated content should have ellipsis")
		// Column width should be limited
		testing.expect(t, !strings.contains(result, "very long"), "full text should not appear")
}

@(test)
test_single_column :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Only")
		table.add_row(&tbl, "one")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "single column should succeed")

		expected := strings.concatenate({
				"+------+\n",
				"| Only |\n",
				"+------+\n",
				"| one  |\n",
				"+------+\n",
		})
		defer delete(expected)

		testing.expect_value(t, result, expected)
}

@(test)
test_cell_alignment_override :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Col", alignment = .LEFT, min_width = 8)
		table.add_row_cells(&tbl, table.Cell{content = "right", alignment = .RIGHT})

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "cell alignment override should succeed")
		testing.expect(t, strings.contains(result, "|    right |"), "cell should be right-aligned despite LEFT column default")
}

@(test)
test_row_separator :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		border := table.BORDER_ASCII
		border.row_separator = true

		tbl := table.make_table(border = border)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "X")
		table.add_row(&tbl, "1")
		table.add_row(&tbl, "2")
		table.add_row(&tbl, "3")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "row separator should succeed")

		// Count horizontal separator lines (header sep + 2 row seps + top + bottom = 5)
		sep_count := strings.count(result, "+---+")
		testing.expect_value(t, sep_count, 5)
}

@(test)
test_no_header :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		// Columns with no headers
		table.add_column(&tbl)
		table.add_column(&tbl)
		table.add_row(&tbl, "a", "b")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "no header should succeed")

		expected := strings.concatenate({
				"+---+---+\n",
				"| a | b |\n",
				"+---+---+\n",
		})
		defer delete(expected)

		testing.expect_value(t, result, expected)
}

@(test)
test_truncate_text :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		test_cases := []struct {
				input:     string,
				max_width: int,
				expected:  string,
		}{
				{"hello", 10, "hello"},     // No truncation needed
				{"hello", 5, "hello"},      // Exact fit
				{"hello", 4, "hel…"},       // Truncate with ellipsis
				{"hello", 1, "…"},          // Minimum truncation
				{"hello", 0, "hello"},      // 0 means unlimited
				{"ab", 2, "ab"},            // Exact fit
				{"abc", 2, "a…"},           // One char + ellipsis
		}

		for tc in test_cases {
				result := table.truncate_text(tc.input, tc.max_width)
				testing.expect_value(t, result, tc.expected)
		}
}

@(test)
test_padding :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Custom padding = 2
		tbl := table.make_table(border = table.BORDER_ASCII, padding = 2)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "X")
		table.add_row(&tbl, "1")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "padding should succeed")
		// With padding=2, content "X" width 1, total cell = 2+1+2 = 5 dashes
		testing.expect(t, strings.contains(result, "|  X  |"), "padding=2 should have 2 spaces on each side")
}

@(test)
test_fill_width_expand :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// 2 columns "A","B" with content "xx","yy". Natural widths [2,2].
		// ASCII border overhead: left(1) + right(1) + sep(1) + padding(2*2*1=4) = 7.
		// width=27 → available=20, extra=16 → each gets 8 → widths [10,10].
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 27
		table.add_column(&tbl, "A")
		table.add_column(&tbl, "B")
		table.add_row(&tbl, "xx", "yy")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "fill expand should succeed")

		expected := strings.concatenate({
				"+------------+------------+\n",
				"| A          | B          |\n",
				"+------------+------------+\n",
				"| xx         | yy         |\n",
				"+------------+------------+\n",
		})
		defer delete(expected)

		testing.expect_value(t, result, expected)
}

@(test)
test_fill_width_shrink :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Natural widths: "hello world"=11, "testing stuff"=13, total=24.
		// overhead=7, width=20 → available=13, deficit=11.
		// Proportional shrink → widths [5,8] (col0 loses more per round).
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 20
		table.add_column(&tbl, "Name")
		table.add_column(&tbl, "Value")
		table.add_row(&tbl, "hello world", "testing stuff")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "fill shrink should succeed")
		testing.expect(t, strings.contains(result, "…"), "shrunk content should have ellipsis")
		// Verify total line width = 20
		lines := strings.split(result, "\n")
		defer delete(lines)
		for line in lines {
				if line == "" do continue
				w := table.text_display_width(line)
				testing.expect_value(t, w, 20)
		}
}

@(test)
test_fill_width_respects_max :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Col A: max_width=8. Col B: no max.
		// Natural widths [2,2], overhead=7, width=30 → available=23, extra=19.
		// Col A capped at 8, col B gets the rest = 15.
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 30
		table.add_column(&tbl, "A", max_width = 8)
		table.add_column(&tbl, "B")
		table.add_row(&tbl, "xx", "yy")

		widths := table.compute_column_widths(tbl)

		testing.expect_value(t, widths[0], 8)
		testing.expect_value(t, widths[1], 15)
}

@(test)
test_fill_width_respects_min :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Col Name: min_width=6. Col Value: no min.
		// Natural widths [11,13], overhead=7, width=20 → available=13, deficit=11.
		// Col Name can't go below 6; col Value absorbs more shrinkage.
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 20
		table.add_column(&tbl, "Name", min_width = 6)
		table.add_column(&tbl, "Value")
		table.add_row(&tbl, "hello world", "testing stuff")

		widths := table.compute_column_widths(tbl)

		testing.expect(t, widths[0] >= 6, "column with min_width=6 should not go below 6")
		testing.expect_value(t, widths[0] + widths[1], 13) // should sum to available
}

@(test)
test_fill_width_zero :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// width=0 (default) should behave exactly like auto-sizing.
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		table.add_column(&tbl, "Name")
		table.add_column(&tbl, "Age")
		table.add_row(&tbl, "Alice", "30")
		table.add_row(&tbl, "Bob", "25")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "width=0 should succeed")

		expected := strings.concatenate({
				"+-------+-----+\n",
				"| Name  | Age |\n",
				"+-------+-----+\n",
				"| Alice | 30  |\n",
				"| Bob   | 25  |\n",
				"+-------+-----+\n",
		})
		defer delete(expected)

		testing.expect_value(t, result, expected)
}

@(test)
test_fill_width_no_border :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// BORDER_NONE: no left/right/separator chars.
		// Overhead = just padding: 2 cols * 2 * 1 = 4.
		// width=20 → available=16, natural=[2,2], extra=12 → [8,8].
		tbl := table.make_table(border = table.BORDER_NONE)
		defer table.destroy_table(&tbl)

		tbl.width = 20
		table.add_column(&tbl, "A")
		table.add_column(&tbl, "B")
		table.add_row(&tbl, "xx", "yy")

		widths := table.compute_column_widths(tbl)

		testing.expect_value(t, widths[0] + widths[1], 16)
}

@(test)
test_fill_width_exact_fit :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Natural widths [5,3] = 8. Overhead = 7. Total natural = 15.
		// Setting width=15 should change nothing.
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 15
		table.add_column(&tbl, "Name")
		table.add_column(&tbl, "Age")
		table.add_row(&tbl, "Alice", "30")

		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "exact fit should succeed")

		// Same as auto-sized output
		auto_tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&auto_tbl)

		table.add_column(&auto_tbl, "Name")
		table.add_column(&auto_tbl, "Age")
		table.add_row(&auto_tbl, "Alice", "30")

		auto_result, auto_ok := table.to_str(auto_tbl)
		defer delete(auto_result)

		testing.expect(t, auto_ok, "auto table should succeed")
		testing.expect_value(t, result, auto_result)
}

@(test)
test_fill_width_extreme_shrink :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// Shrink so tight that columns hit minimum width of 1.
		// 2 cols, overhead=7, width=9 → available=2 → each column gets 1.
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 9
		table.add_column(&tbl, "Name")
		table.add_column(&tbl, "Value")
		table.add_row(&tbl, "hello", "world")

		widths := table.compute_column_widths(tbl)

		testing.expect_value(t, widths[0], 1)
		testing.expect_value(t, widths[1], 1)

		// Content should be just ellipsis
		result, ok := table.to_str(tbl)
		defer delete(result)

		testing.expect(t, ok, "extreme shrink should succeed")
		testing.expect(t, strings.contains(result, "| … | … |"), "cells should show single ellipsis")
}

@(test)
test_fill_width_uneven_columns :: proc(t: ^testing.T) {
		testing.set_fail_timeout(t, 5 * time.Second)

		// 3 columns with different natural widths: [1, 5, 10] = 16.
		// ASCII overhead for 3 cols: left(1)+right(1)+2 seps(2)+padding(3*2*1=6) = 10.
		// width=46 → available=36, extra=20.
		// Wider columns get proportionally more extra space.
		tbl := table.make_table(border = table.BORDER_ASCII)
		defer table.destroy_table(&tbl)

		tbl.width = 46
		table.add_column(&tbl, "A")
		table.add_column(&tbl, "BBBBB")
		table.add_column(&tbl, "CCCCCCCCCC")
		table.add_row(&tbl, "x", "yyyyy", "zzzzzzzzzz")

		widths := table.compute_column_widths(tbl)

		// Verify total fills available space
		total := 0
		for w in widths {
				total += w
		}
		testing.expect_value(t, total, 36)

		// Wider columns should get more space
		testing.expect(t, widths[2] > widths[1], "wider natural column should get more extra space")
		testing.expect(t, widths[1] > widths[0], "medium column should get more than narrow column")

		// Verify rendered line widths are all 46
		result, ok := table.to_str(tbl)
		defer delete(result)
		testing.expect(t, ok, "uneven columns should succeed")

		lines := strings.split(result, "\n")
		defer delete(lines)
		for line in lines {
				if line == "" do continue
				testing.expect_value(t, table.text_display_width(line), 46)
		}
}
