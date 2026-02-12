package tutorial_01_basic

import "core:fmt"
import "core:os"
import "core:strings"
import "../../cli"

// Step 1: Define your flags as a struct.
// Each field becomes a command-line flag. Use `usage` tags for help text
// and `args` tags for parsing behavior.
Options :: struct {
	name:  string `args:"pos=0,required" usage:"Name of the person to greet"`,
	count: int    `args:"short=n"        usage:"Number of times to greet"`,
	loud:  bool   `args:"short=l"        usage:"SHOUT the greeting"`,
}

main :: proc() {
	options: Options

	// Step 2: Call parse_or_exit — it parses os.args, shows rich help on
	// --help, and exits with a styled error on bad input.
	// help_on_empty shows help when no arguments are given.
	cli.parse_or_exit(
		&options,
		os.args,
		description = "A friendly greeter.",
		version = "1.0.0",
		help_on_empty = true,
	)

	// Step 3: Use the parsed values.
	greeting := fmt.tprintf("Hello, %s!", options.name)
	if options.loud {
		greeting = strings.to_upper(greeting)
	}

	count := options.count if options.count > 0 else 1
	for _ in 0 ..< count {
		fmt.println(greeting)
	}
}
