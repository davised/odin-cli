package cli_demo

import "core:fmt"
import "core:os"
import "../../cli"

Options :: struct {
	input:   string `args:"pos=0,required" usage:"Input file to process"`,
	output:  string `args:"pos=1" usage:"Output destination"`,
	format:  string `usage:"Output format (text, json, yaml)"`,
	verbose: bool   `usage:"Show verbose output"`,
	count:   int    `usage:"Number of iterations"`,
	token:   string `args:"required" usage:"API auth token"`,
	dry_run: bool   `usage:"Simulate without writing"`,
	hidden:  string `args:"hidden" usage:"Internal debug flag"`,
}

main :: proc() {
	options: Options

	cli.parse_or_exit(
		&options,
		os.args,
		description = "A demo tool showing rich CLI help output.",
		version = "1.0.0",
		panel_config = {
			cli.Panel{name = "Authentication", fields = {"token"}},
		},
		help_on_empty = true,
	)

	fmt.printfln("Input:   %s", options.input)
	fmt.printfln("Output:  %s", options.output)
	fmt.printfln("Format:  %s", options.format)
	fmt.printfln("Verbose: %v", options.verbose)
	fmt.printfln("Count:   %d", options.count)
	fmt.printfln("Token:   %s", options.token)
	fmt.printfln("Dry run: %v", options.dry_run)
}
