package tutorial_05_custom_types

import "base:runtime"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "../../cli"

// -- Custom types --

// A semantic version parsed from "major.minor.patch" strings.
Semver :: struct {
	major, minor, patch: int,
}

// An RGB color parsed from hex strings like "#ff0000" or "ff0000".
RGB :: struct {
	r, g, b: u8,
}

// -- Custom type setter --
// Handles multiple types by dispatching on data_type.
// Return handled=true for types you own, handled=false to let the default parser handle it.

custom_type_setter :: proc(
	data: rawptr,
	data_type: typeid,
	unparsed_value: string,
	args_tag: string,
) -> (
	error: string,
	handled: bool,
	alloc_error: runtime.Allocator_Error,
) {
	switch data_type {
	case Semver:
		handled = true
		ptr := cast(^Semver)data
		parts := strings.split(unparsed_value, ".", context.temp_allocator)
		if len(parts) != 3 {
			error = "Expected semver like '1.2.3'."
			return
		}
		major, major_ok := strconv.parse_int(parts[0])
		minor, minor_ok := strconv.parse_int(parts[1])
		patch, patch_ok := strconv.parse_int(parts[2])
		if !major_ok || !minor_ok || !patch_ok {
			error = "Semver components must be integers."
			return
		}
		ptr^ = Semver{major, minor, patch}

	case RGB:
		handled = true
		ptr := cast(^RGB)data
		hex := strings.trim_prefix(unparsed_value, "#")
		if len(hex) != 6 {
			error = "Expected hex color like '#ff0000' or 'ff0000'."
			return
		}
		r, r_ok := strconv.parse_uint(hex[0:2], 16)
		g, g_ok := strconv.parse_uint(hex[2:4], 16)
		b, b_ok := strconv.parse_uint(hex[4:6], 16)
		if !r_ok || !g_ok || !b_ok {
			error = "Invalid hex digits in color."
			return
		}
		ptr^ = RGB{u8(r), u8(g), u8(b)}
	}
	return
}

// -- Per-flag validation --
// Called after parsing for each flag that was set. Dispatch on the flag name.

custom_flag_checker :: proc(
	model: rawptr,
	name: string,
	value: any,
	args_tag: string,
) -> (
	error: string,
) {
	if name == "port" {
		port := value.(int)
		if port < 1024 || port > 65535 {
			error = "Port must be between 1024 and 65535."
		}
	}
	return
}

// -- Command flags --

Serve_Flags :: struct {
	port:    int    `args:"short=p,required" usage:"Port to listen on (1024-65535)"`,
	host:    string `args:"short=h"          usage:"Host address to bind"`,
	version: Semver `args:"short=v"          usage:"API version (e.g. 1.2.3)"`,
	accent:  RGB    `args:"short=a"          usage:"Theme accent color (e.g. #ff0000)"`,
}

serve_action :: proc(f: ^Serve_Flags, program: string) -> int {
	host := f.host if len(f.host) > 0 else "localhost"
	fmt.printfln("Serving on %s:%d", host, f.port)
	fmt.printfln("  API version: %d.%d.%d", f.version.major, f.version.minor, f.version.patch)
	fmt.printfln("  Accent color: rgb(%d, %d, %d)", f.accent.r, f.accent.g, f.accent.b)
	return 0
}

main :: proc() {
	// Register custom type setter and flag checker on core:flags directly.
	// These are globals — register once before parsing.
	flags.register_type_setter(custom_type_setter)
	flags.register_flag_checker(custom_flag_checker)

	app := cli.make_app(
		"server",
		description = "A demo showing custom types and per-flag validation.",
		version = "1.0.0",
	)

	cli.add_command(&app, Serve_Flags, "serve",
		description = "Start the server",
		action = serve_action,
	)

	code := cli.run(&app, os.args)
	cli.destroy_app(&app)
	os.exit(code)
}
