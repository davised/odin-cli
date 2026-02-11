package cli_app_demo

import "core:fmt"
import "core:os"
import "../../cli"

// -- init subcommand --

Init_Flags :: struct {
	name:     string `args:"pos=0,required" usage:"Project name"`,
	template: string `usage:"Template to use (basic, web, api)"`,
	force:    bool   `usage:"Overwrite existing directory"`,
}

init_action :: proc(flags: ^Init_Flags, program: string) -> int {
	fmt.printfln("Initializing project '%s' with template '%s'", flags.name, flags.template)
	if flags.force do fmt.println("(force mode)")
	return 0
}

// -- build subcommand --

Build_Flags :: struct {
	target:  string `usage:"Build target (debug, release)"`,
	output:  string `args:"name=out" usage:"Output directory"`,
	verbose: bool   `usage:"Show build details"`,
	jobs:    int    `usage:"Number of parallel jobs"`,
}

build_action :: proc(flags: ^Build_Flags, program: string) -> int {
	target := flags.target if len(flags.target) > 0 else "debug"
	fmt.printfln("Building (%s) -> %s", target, flags.output)
	if flags.verbose do fmt.printfln("Using %d jobs", flags.jobs)
	return 0
}

// -- serve subcommand --

Serve_Flags :: struct {
	port: int    `usage:"Port to listen on"`,
	host: string `usage:"Host address to bind"`,
	tls:  bool   `usage:"Enable TLS"`,
}

serve_action :: proc(flags: ^Serve_Flags, program: string) -> int {
	host := flags.host if len(flags.host) > 0 else "localhost"
	port := flags.port if flags.port > 0 else 8080
	fmt.printfln("Serving on %s:%d (tls=%v)", host, port, flags.tls)
	return 0
}

main :: proc() {
	app := cli.make_app(
		"myapp",
		description = "A multi-command demo application.",
		version = "2.0.0",
	)

	cli.add_command(&app, Init_Flags, "init",
		description = "Initialize a new project",
		action = init_action,
	)
	cli.add_command(&app, Build_Flags, "build",
		description = "Build the project",
		action = build_action,
		aliases = {"b"},
	)
	cli.add_command(&app, Serve_Flags, "serve",
		description = "Start a development server",
		action = serve_action,
		aliases = {"s"},
	)

	code := cli.run(&app, os.args)
	cli.destroy_app(&app)
	os.exit(code)
}
