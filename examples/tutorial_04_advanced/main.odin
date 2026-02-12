package tutorial_04_advanced

import "core:fmt"
import "core:os"
import "../../cli"

// Global flags are shared across all commands — parsed before dispatch.
Global_Flags :: struct {
	verbose: int    `args:"short=v,count" usage:"Increase verbosity (-v, -vv, -vvv)"`,
	config:  string `args:"short=c"       usage:"Path to config file"`,
}

// --- push command ---

Push_Flags :: struct {
	remote: string `args:"pos=0,required" usage:"Remote name"`,
	branch: string `args:"pos=1"          usage:"Branch to push"`,
	force:  bool   `args:"short=f"        usage:"Force push"`,
	tags:   bool   `args:"short=t"        usage:"Push tags"`,
}

push_action :: proc(flags: ^Push_Flags, program: string) -> int {
	branch := flags.branch if len(flags.branch) > 0 else "HEAD"
	fmt.printfln("Pushing %s to %s (force=%v, tags=%v)", branch, flags.remote, flags.force, flags.tags)
	return 0
}

// --- fetch command ---

Fetch_Flags :: struct {
	remote: string `args:"pos=0" usage:"Remote to fetch from (default: all)"`,
	all:    bool   `args:"short=a" usage:"Fetch from all remotes"`,
	prune:  bool   `args:"short=p" usage:"Prune deleted remote branches"`,
}

fetch_action :: proc(flags: ^Fetch_Flags, program: string) -> int {
	if flags.all {
		fmt.println("Fetching from all remotes...")
	} else {
		remote := flags.remote if len(flags.remote) > 0 else "origin"
		fmt.printfln("Fetching from %s (prune=%v)", remote, flags.prune)
	}
	return 0
}

// --- config set subcommand ---

Config_Set_Flags :: struct {
	key:   string `args:"pos=0,required" usage:"Config key to set"`,
	value: string `args:"pos=1,required" usage:"Value to assign"`,
}

config_set_action :: proc(flags: ^Config_Set_Flags, program: string) -> int {
	fmt.printfln("Setting %s = %s", flags.key, flags.value)
	return 0
}

// --- config get subcommand ---

Config_Get_Flags :: struct {
	key: string `args:"pos=0,required" usage:"Config key to read"`,
}

config_get_action :: proc(flags: ^Config_Get_Flags, program: string) -> int {
	fmt.printfln("Getting value for '%s'", flags.key)
	return 0
}

// --- config list subcommand (with custom validator) ---

Config_List_Flags :: struct {
	section: string `args:"short=s"       usage:"Filter by config section"`,
	json:    bool   `args:"xor=list-fmt"  usage:"Output as JSON"`,
	table:   bool   `args:"xor=list-fmt"  usage:"Output as table"`,
}

config_list_action :: proc(flags: ^Config_List_Flags, program: string) -> int {
	fmt.printfln("Listing config (section=%s, json=%v, table=%v)", flags.section, flags.json, flags.table)
	return 0
}

// A custom validator checks constraints that struct tags can't express.
config_list_validator :: proc(flags: ^Config_List_Flags) -> string {
	if flags.json && len(flags.section) == 0 {
		return "JSON output requires --section to be specified."
	}
	return ""
}

// Parent commands that only dispatch to subcommands still need a flags struct.
Config_Flags :: struct {
	help: bool `args:"hidden"`,
}

config_action :: proc(flags: ^Config_Flags, program: string) -> int {
	fmt.println("Use 'remote config <set|get|list>' to manage configuration.")
	return 1
}

main :: proc() {
	global: Global_Flags

	app := cli.make_app(
		"remote",
		description = "A git remote-like tool demonstrating advanced CLI features.",
		version = "1.0.0",
	)
	cli.set_global_flags(&app, Global_Flags, &global)

	cli.add_command(&app, Push_Flags, "push",
		description = "Push commits to a remote",
		action = push_action,
	)
	cli.add_command(&app, Fetch_Flags, "fetch",
		description = "Fetch updates from a remote",
		action = fetch_action,
		aliases = {"f"},
	)

	// Parent command for nested subcommands.
	cli.add_command(&app, Config_Flags, "config",
		description = "Manage remote configuration",
		action = config_action,
	)

	// Nested subcommands under "config".
	cli.add_subcommand(&app, Config_Set_Flags, "config", "set",
		description = "Set a config value",
		action = config_set_action,
	)
	cli.add_subcommand(&app, Config_Get_Flags, "config", "get",
		description = "Get a config value",
		action = config_get_action,
	)
	cli.add_subcommand(&app, Config_List_Flags, "config", "list",
		description = "List config values",
		action = config_list_action,
		aliases = {"ls"},
	)

	// Register a custom validator for a nested subcommand.
	cli.set_subcommand_validator(&app, "config", "list", Config_List_Flags, config_list_validator)

	code := cli.run(&app, os.args)
	cli.destroy_app(&app)
	os.exit(code)

	// After running, you can inspect global flags:
	// if global.verbose >= 2 { ... }
}
