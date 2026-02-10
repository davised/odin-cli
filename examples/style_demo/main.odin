package style_demo

import "core:fmt"
import "core:log"
import "core:mem"
import style "../../style"

winner :: proc(str: union {
		string,
		style.Styled_Text,
	}) -> style.Styled_Text {
	value := style.get_or_create_styled_text(str)
	value.style = style.Style {
		foreground_color = style.ANSI_FG.Bright_Green,
		text_styles      = {.Bold, .Italic, .Blink_Rapid},
	}
	return value
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		context.logger = log.create_console_logger(lowest = log.Level.Debug)

		defer {
			log.destroy_console_logger(context.logger)
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	} else {
		context.logger = log.create_console_logger(lowest = log.Level.Info)
		defer log.destroy_console_logger(context.logger)
	}

	options := style.Options {
		parsing = .Error,
	}
	fmt.println("Setting options", options)
	style.set_options(&options)

	log.debug("This is debug")
	log.info("This is info")
	log.warn("This is warn")

	fmt.println(winner("You are today's winner!"))
	fmt.println(style.white("White"))
	fmt.println(style.st("Invalid hex", "#LLMMNN"))
	fmt.println(style.st("Valid rgb", "rgb(0,125,125)"))
	fmt.println(style.st("Invalid rgb", "rgb(256,125,125)"))

	// 1. Basic styled text with simple colors
	styled_text1 := style.Styled_Text {
		text = "Red Text",
		style = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_FG.Red},
	}
	fmt.println(styled_text1)
	fmt.printfln("%w", styled_text1)
	fmt.println(style.st("Red Text", "bold red"))
	fmt.println(style.st("", "bold red"))

	// 2. Styled text with 8-bit colors
	styled_text2 := style.Styled_Text {
		text = "8-bit Color Text",
		style = style.Style {
			text_styles      = {.Italic, .Underline},
			foreground_color = style.EightBit(48),
		},
	}
	fmt.println(styled_text2)
	fmt.println(style.st("8-bit Color Text", "italic underline color(48)"))

	// 3. Styled text with RGB colors and background
	styled_text3 := style.Styled_Text {
		text = "RGB Colored Text",
		style = style.Style {
			text_styles      = {.Bold, .Italic},
			foreground_color = style.RGB{250, 100, 50},
			background_color = style.RGB{10, 20, 30},
		},
	}
	fmt.println(styled_text3)

	// 4. No styling
	styled_text4 := style.Styled_Text {
		text  = "Plain Text",
		style = style.Style{},
	}
	fmt.println(styled_text4)

	fmt.println(style.blue("This is a blue text"))
	fmt.println(styled_text1, style.yellow(style.italic(style.bold(styled_text4))), style.blue(style.underline("String"), bg = true))

	log.info("This is an", style.bold("INFO"))
	log.warn("This is a", style.warn("warning"))
	log.error("This is an", style.error("error"))
	log.info("This", style.bold("isn't"), "an", style.strike("error"))
	log.info("This is", style.success("a success"))

	fmt.println("This is a", style.black("black"), "text")

	f2 := style.to_str(style.black(style.bold(style.italic("This is a test string"))))
	fmt.println(f2)
	defer delete(f2)
	formatted_str := style.to_str(styled_text1)
	fmt.println(formatted_str)
	defer delete(formatted_str)
}
