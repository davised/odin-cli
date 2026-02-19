package showcase

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import logger "../../logger"
import panel "../../panel"
import progress "../../progress"
import spinner "../../spinner"
import style "../../style"
import table "../../table"
import "../../term"
import tree "../../tree"

RESET :: "\x1b[0m"

main :: proc() {
	ta := context.temp_allocator
	depth := term.detect_color_depth()
	mode := term.detect_render_mode(os.stdout)

	lines := make([dynamic]panel.Line, 0, 256, ta)

	// ── Text Styles ─────────────────────────────────────────────────────
	section(&lines, "Text Styles")
	add_line(&lines, fmt.aprintf(
		"  %v  %v  %v  %v  %v  %v  %v",
		style.bold("Bold"), style.faint("Faint"), style.italic("Italic"),
		style.underline("Underline"), style.invert("Invert"), style.strike("Strike"),
		style.overlined("Overlined"),
		allocator = ta,
	))
	add_line(&lines, fmt.aprintf(
		"  %v  %v  %v  %v",
		style.double_underline("Double Underline"), style.framed("Framed"),
		style.encircled("Encircled"), style.blink_slow("Blink"),
		allocator = ta,
	))
	add_line(&lines, fmt.aprintf(
		"  %v  %v",
		style.bold(style.italic("Bold+Italic")),
		style.bold(style.underline(style.strike("Bold+Underline+Strike"))),
		allocator = ta,
	))
	blank(&lines)

	// ── ANSI 16 Colors ──────────────────────────────────────────────────
	section(&lines, "ANSI 16 Colors")
	{
		fg_colors := [8]struct{name: string, color: style.ANSI_Color} {
			{"Black", .Black}, {"Red", .Red}, {"Green", .Green}, {"Yellow", .Yellow},
			{"Blue", .Blue}, {"Magenta", .Magenta}, {"Cyan", .Cyan}, {"White", .White},
		}
		bright_colors := [8]struct{name: string, color: style.ANSI_Color} {
			{"Black", .Bright_Black}, {"Red", .Bright_Red}, {"Green", .Bright_Green}, {"Yellow", .Bright_Yellow},
			{"Blue", .Bright_Blue}, {"Magenta", .Bright_Magenta}, {"Cyan", .Bright_Cyan}, {"White", .Bright_White},
		}
		// FG row
		sb := strings.builder_make(ta)
		strings.write_string(&sb, "  FG: ")
		for c in fg_colors {
			st := style.Styled_Text{text = c.name, style = style.Style{foreground_color = c.color}}
			fmt.sbprintf(&sb, "%v ", st)
		}
		add_line(&lines, strings.to_string(sb))

		// Bright FG row
		sb2 := strings.builder_make(ta)
		strings.write_string(&sb2, "  BR: ")
		for c in bright_colors {
			st := style.Styled_Text{text = c.name, style = style.Style{foreground_color = c.color}}
			fmt.sbprintf(&sb2, "%v ", st)
		}
		add_line(&lines, strings.to_string(sb2))

		// BG row
		sb3 := strings.builder_make(ta)
		strings.write_string(&sb3, "  BG: ")
		for c in fg_colors {
			st := style.Styled_Text{text = "  ", style = style.Style{background_color = c.color}}
			fmt.sbprintf(&sb3, "%v", st)
		}
		strings.write_string(&sb3, " ")
		for c in bright_colors {
			st := style.Styled_Text{text = "  ", style = style.Style{background_color = c.color}}
			fmt.sbprintf(&sb3, "%v", st)
		}
		add_line(&lines, strings.to_string(sb3))
	}
	blank(&lines)

	// ── 256-Color Palette ───────────────────────────────────────────────
	section(&lines, "256-Color Palette")
	{
		// Color cube (6 rows of 36)
		add_line(&lines, "  Color cube (6x6x6):")
		for row in 0 ..< 6 {
			sb := strings.builder_make(ta)
			strings.write_string(&sb, "  ")
			w := strings.to_writer(&sb)
			for col in 0 ..< 36 {
				idx := 16 + row * 36 + col
				st := style.Styled_Text{text = "  ", style = style.Style{background_color = style.EightBit(u8(idx))}}
				style.to_writer(w, st, depth = depth)
			}
			strings.write_string(&sb, RESET)
			add_line(&lines, strings.to_string(sb))
		}
		// Grayscale ramp
		sb := strings.builder_make(ta)
		strings.write_string(&sb, "  Grayscale: ")
		w := strings.to_writer(&sb)
		for i in 232 ..= 255 {
			st := style.Styled_Text{text = "  ", style = style.Style{background_color = style.EightBit(u8(i))}}
			style.to_writer(w, st, depth = depth)
		}
		strings.write_string(&sb, RESET)
		add_line(&lines, strings.to_string(sb))
	}
	blank(&lines)

	// ── RGB Gradients ───────────────────────────────────────────────────
	section(&lines, "RGB Gradients (True Color)")
	{
		// Red → Blue gradient
		sb := strings.builder_make(ta)
		strings.write_string(&sb, "  R\u2192B: ")
		w := strings.to_writer(&sb)
		for i in 0 ..< 64 {
			r := u8(255 - i * 4)
			b := u8(i * 4)
			st := style.Styled_Text{text = " ", style = style.Style{background_color = style.RGB{style.EightBit(r), 0, style.EightBit(b)}}}
			style.to_writer(w, st, depth = depth)
		}
		strings.write_string(&sb, RESET)
		add_line(&lines, strings.to_string(sb))

		// HSL rainbow
		sb2 := strings.builder_make(ta)
		strings.write_string(&sb2, "  HSL: ")
		w2 := strings.to_writer(&sb2)
		for i in 0 ..< 64 {
			hue := f32(i) / 64.0 * 360.0
			rgb, _ := style.hsl_to_rgb(hue, 1.0, 0.5)
			st := style.Styled_Text{text = " ", style = style.Style{background_color = rgb}}
			style.to_writer(w2, st, depth = depth)
		}
		strings.write_string(&sb2, RESET)
		add_line(&lines, strings.to_string(sb2))
	}
	blank(&lines)

	// ── Color Depth ─────────────────────────────────────────────────────
	section(&lines, "Color Depth")
	{
		depth_name: string
		switch depth {
		case .None:       depth_name = "None"
		case .Three_Bit:  depth_name = "3-bit (8 colors)"
		case .Four_Bit:   depth_name = "4-bit (16 colors)"
		case .Eight_Bit:  depth_name = "8-bit (256 colors)"
		case .True_Color: depth_name = "True Color (24-bit)"
		}
		mode_name: string
		switch mode {
		case .Plain:    mode_name = "Plain"
		case .No_Color: mode_name = "No Color"
		case .Full:     mode_name = "Full"
		}
		add_line(&lines, fmt.aprintf("  Detected: %v  |  Render mode: %v", style.bold(depth_name), style.bold(mode_name), allocator = ta))

		demo_text := style.Styled_Text {
			text = "Hello, odin-cli!",
			style = style.Style{text_styles = {.Bold}, foreground_color = style.RGB{255, 100, 50}, background_color = style.RGB{20, 40, 80}},
		}
		depths := [?]struct{name: string, d: term.Color_Depth} {
			{"True Color", .True_Color},
			{"8-bit     ", .Eight_Bit},
			{"4-bit     ", .Four_Bit},
		}
		for entry in depths {
			sb := strings.builder_make(ta)
			strings.write_string(&sb, "  ")
			strings.write_string(&sb, entry.name)
			strings.write_string(&sb, ": ")
			style.to_writer(strings.to_writer(&sb), demo_text, depth = entry.d)
			add_line(&lines, strings.to_string(sb))
		}
	}
	blank(&lines)

	// ── Table ───────────────────────────────────────────────────────────
	section(&lines, "Table")
	{
		t := table.make_table(border = table.BORDER_ROUNDED, title = "Border Styles", allocator = ta)
		table.add_column(&t, header = style.bold("Style"))
		table.add_column(&t, header = style.bold("Characters"))
		table.add_column(&t, header = style.bold("Corners"))
		table.set_header_style(&t, style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Cyan})
		table.add_row(&t, "Light", "─ │", "┌ ┐ └ ┘")
		table.add_row(&t, "Heavy", "━ ┃", "┏ ┓ ┗ ┛")
		table.add_row(&t, "Double", "═ ║", "╔ ╗ ╚ ╝")
		table.add_row(&t, "Rounded", "─ │", "╭ ╮ ╰ ╯")
		table.add_row(&t, "ASCII", "- |", "+ + + +")

		table_str := table.to_str(t, allocator = ta)
		for line in strings.split(table_str, "\n", ta) {
			if line == "" do continue
			sb := strings.builder_make(ta)
			strings.write_string(&sb, "  ")
			strings.write_string(&sb, line)
			add_line(&lines, strings.to_string(sb))
		}
	}
	blank(&lines)

	// ── Tree ────────────────────────────────────────────────────────────
	section(&lines, "Tree")
	{
		b := tree.make_builder(style.bold("odin-cli"), ta)
		style_node := tree.add_tree(&b, style.cyan("style/"))
		tree.add(style_node, "styles.odin")
		tree.add(style_node, "parser.odin")
		tree.add(style_node, "writer.odin")
		table_node := tree.add_tree(&b, style.cyan("table/"))
		tree.add(table_node, "table.odin")
		tree.add(table_node, "writer.odin")
		term_node := tree.add_tree(&b, style.cyan("term/"))
		tree.add(term_node, "term.odin")
		tree.add(term_node, "width.odin")
		tree.add(&b, style.cyan("logger/"))
		tree.add(&b, style.cyan("panel/"))
		tree.add(&b, style.cyan("progress/"))
		tree.add(&b, style.cyan("spinner/"))
		tree.add(&b, style.cyan("cli/"))
		tr := tree.build(&b)

		tree_str := fmt.aprintf("%v", tr, allocator = ta)
		for line in strings.split(tree_str, "\n", ta) {
			if line == "" do continue
			sb := strings.builder_make(ta)
			strings.write_string(&sb, "  ")
			strings.write_string(&sb, line)
			add_line(&lines, strings.to_string(sb))
		}
	}
	blank(&lines)

	// ── Progress Bars ───────────────────────────────────────────────────
	section(&lines, "Progress Bars")
	{
		bars := [?]struct{pct: int, bs: progress.Bar_Style, msg: string, fill: Maybe(style.Style)} {
			{75, progress.bar_block(), "Block ", style.Style{foreground_color = style.ANSI_Color.Green}},
			{45, progress.bar_ascii(), "ASCII ", nil},
			{90, progress.bar_thin(),  "Thin  ", style.Style{foreground_color = style.ANSI_Color.Cyan}},
		}
		for entry in bars {
			p := progress.Progress {
				total           = 100,
				current         = entry.pct,
				width           = 40,
				bar_style       = entry.bs,
				message         = entry.msg,
				show_percentage = true,
				show_count      = true,
				fill_style      = entry.fill,
				mode            = mode,
			}
			sb := strings.builder_make(ta)
			strings.write_string(&sb, "  ")
			progress.to_writer(strings.to_writer(&sb), p)
			add_line(&lines, strings.to_string(sb))
		}
	}
	blank(&lines)

	// ── Spinners ────────────────────────────────────────────────────────
	section(&lines, "Spinner Frames")
	{
		spinners := [?]struct{frames: spinner.Spinner_Frames, msg: string} {
			{spinner.spinner_dots(),   "Loading..."},
			{spinner.spinner_circle(), "Processing..."},
			{spinner.spinner_line(),   "Working..."},
		}
		sb := strings.builder_make(ta)
		strings.write_string(&sb, "  ")
		for entry, i in spinners {
			s := spinner.Spinner {
				frames  = entry.frames,
				message = entry.msg,
				mode    = mode,
			}
			spinner.to_writer(strings.to_writer(&sb), s)
			if i < len(spinners) - 1 {
				strings.write_string(&sb, "   ")
			}
		}
		add_line(&lines, strings.to_string(sb))
	}
	blank(&lines)

	// ── Logger ──────────────────────────────────────────────────────────
	section(&lines, "Logger")
	{
		sb := strings.builder_make(ta)
		lgr := logger.make_logger(lowest_level = .Trace, output = strings.to_writer(&sb), timestamp_format = .None)
		lgr.outputs[0].use_color = true
		logger.log_info(&lgr, "Application started", "version", "0.1.0")
		logger.log_hint(&lgr, "Consider using the -o:speed flag")
		logger.log_success(&lgr, "All tests passed", "count", "23")
		logger.log_warn(&lgr, "Deprecated API usage detected")
		logger.log_error(&lgr, "Connection refused", "host", "db-01")

		for line in strings.split(strings.to_string(sb), "\n", ta) {
			if line == "" do continue
			lsb := strings.builder_make(ta)
			strings.write_string(&lsb, "  ")
			strings.write_string(&lsb, line)
			add_line(&lines, strings.to_string(lsb))
		}
	}
	blank(&lines)

	// ── st() Parser ─────────────────────────────────────────────────────
	section(&lines, "st() Parser")
	{
		examples := [?]struct{text: string, spec: string} {
			{"Bold red text", "bold red"},
			{"Italic cyan", "italic cyan"},
			{"Coral foreground", "fg:coral"},
			{"Custom RGB + BG", "fg:rgb(255,200,50) bg:rgb(10,20,30) bold"},
		}
		for ex in examples {
			st, ok := style.st(ex.text, ex.spec)
			if ok {
				add_line(&lines, fmt.aprintf("  st(\"%v\", \"%v\")  =>  %v", ex.text, ex.spec, st, allocator = ta))
			}
		}
	}
	blank(&lines)

	// ── Feature Matrix ──────────────────────────────────────────────────
	section(&lines, "Feature Matrix")
	{
		features := [?]struct{pkg: string, desc: string} {
			{"style",    "Text styling, colors, fmt formatter"},
			{"table",    "Formatted tables with borders"},
			{"tree",     "Tree rendering with enumerators"},
			{"progress", "Progress bars with styles"},
			{"spinner",  "Animated spinners"},
			{"logger",   "Styled structured logging"},
			{"term",     "Display width, truncate, wrap"},
			{"panel",    "Bordered text panels"},
			{"cli",      "Rich help output wrapping core:flags"},
		}
		for f in features {
			add_line(&lines, fmt.aprintf("  %v  %-10s %v", style.success("Done"), f.pkg, style.faint(f.desc), allocator = ta))
		}
	}

	// Build the panel
	p := panel.Panel {
		lines   = lines[:],
		border  = panel.BORDER_ROUNDED,
		title   = style.bold("odin-cli \u2014 Terminal UI Toolkit for Odin"),
		padding = 1,
	}

	w := os.stream_from_handle(os.stdout)
	io.write_string(w, "\n")
	panel.to_writer(w, p)
	io.write_string(w, "\n")
}

// --- Helpers ---

section :: proc(lines: ^[dynamic]panel.Line, title: string) {
	ta := context.temp_allocator
	bar_len := 60 - term.display_width(title)
	if bar_len < 4 do bar_len = 4

	buf: [128]u8
	pos := 0
	bar_char := transmute([]u8)string("\u2500")
	for _ in 0 ..< bar_len {
		if pos + len(bar_char) > len(buf) do break
		copy(buf[pos:], bar_char)
		pos += len(bar_char)
	}

	add_line(lines, fmt.aprintf("  %v %v", style.bold(title), style.faint(string(buf[:pos])), allocator = ta))
}

add_line :: proc(lines: ^[dynamic]panel.Line, s: string) {
	append(lines, panel.Line(s))
}

blank :: proc(lines: ^[dynamic]panel.Line) {
	append(lines, panel.Line(""))
}
