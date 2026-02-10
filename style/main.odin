package style

import "core:fmt"
import "core:io"
import "core:log"
import "core:mem"
import "core:strings"

winner :: proc(str: union {
		string,
		Styled_Text,
	}) -> (value: Styled_Text, ok: bool) #optional_ok {
	value = get_or_create_styled_text(str)
	value.style = Style {
		foreground_color = ANSI_FG.Bright_Green,
		text_styles      = {.Bold, .Italic, .Blink_Rapid},
	}
	return value, true
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

	options := Options {
		parsing = .Error,
	}
	fmt.println("Setting options", options)
	set_options(&options)
	fmt.println(package_options)

	log.debug("This is debug")
	log.info("This is info")
	log.warn("This is warn")
	log.info("This is nil:")
	log.infof("%v", "")
	fmt.printfln("%v", "")

	fmt.println(winner("You are today's winner!"))
	fmt.println(white("White"))
	fmt.println(st("Invalid hex", "#LLMMNN"))
	fmt.println(st("Valid rgb", "rgb(0,125,125)"))
	fmt.println(st("Invalid rgb", "rgb(256,125,125)"))

	// 1. Basic styled text with simple colors
	styled_text1 := Styled_Text {
		text = "Red Text",
		style = Style{text_styles = {Text_Style.Bold}, foreground_color = ANSI_FG.Red},
	}
	fmt.println(styled_text1)
	fmt.printfln("%w", styled_text1)
	fmt.println(st("Red Text", "bold red"))
	fmt.println(st("", "bold red"))

	// 2. Styled text with 8-bit colors
	styled_text2 := Styled_Text {
		text = "8-bit Color Text",
		style = Style {
			text_styles      = {Text_Style.Italic, Text_Style.Underline},
			foreground_color = EightBit(48), // Example 8-bit color
		},
	}
	fmt.println(styled_text2)
	fmt.println(st("8-bit Color Text", "italic underline color(48)"))

	// 3. Styled text with RGB colors and background
	styled_text3 := Styled_Text {
		text = "RGB Colored Text",
		style = Style {
			text_styles = {Text_Style.Bold, Text_Style.Italic},
			foreground_color = RGB{250, 100, 50},
			background_color = RGB{10, 20, 30},
		},
	}
	fmt.println(styled_text3)

	// 4. No styling
	styled_text4 := Styled_Text {
		text  = "Plain Text",
		style = Style{},
	}
	fmt.println(styled_text4)

	fmt.println(blue("This is a blue text"))
	fmt.println(styled_text1, yellow(italic(bold(styled_text4))), blue(underline("String"), bg = true))

	log.info("This is an", bold("INFO"))
	log.warn("This is a", warn("warning"))
	log.error("This is an", error("error"))
	log.info("This", bold("isn't"), "an", strike("error"))
	log.info("This is", success("a success"))

	fmt.println("This is a", black("black"), "text")

	f2 := to_str(black(bold(italic("This is a test string"))))
	fmt.println(f2)
	defer delete(f2)
	formatted_str := to_str(styled_text1)
	fmt.println(formatted_str)
	defer delete(formatted_str)
	// formatted_str := generate_formatted_string()
	// print_string_as_runes(formatted_str)
	// fmt.println(formatted_str)
}
