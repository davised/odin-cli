package tutorial_03_commands

import "core:fmt"
import "core:os"
import "../../cli"

// Each command gets its own flags struct.

Priority :: enum {
	Low,
	Medium,
	High,
}

// --- add command ---

Add_Flags :: struct {
	title:    string   `args:"pos=0,required" usage:"Task description"`,
	priority: Priority `args:"short=p" usage:"Task priority"`,
}

add_action :: proc(flags: ^Add_Flags, program: string) -> int {
	fmt.printfln("Added: \"%s\" (priority: %v)", flags.title, flags.priority)
	return 0
}

// --- list command ---

List_Flags :: struct {
	all: bool `args:"short=a" usage:"Show completed tasks too"`,
}

list_action :: proc(flags: ^List_Flags, program: string) -> int {
	if flags.all {
		fmt.println("Listing all tasks (including completed)...")
	} else {
		fmt.println("Listing open tasks...")
	}
	return 0
}

// --- done command ---

Done_Flags :: struct {
	id: int `args:"pos=0,required" usage:"Task ID to mark as done"`,
}

done_action :: proc(flags: ^Done_Flags, program: string) -> int {
	fmt.printfln("Marked task #%d as done.", flags.id)
	return 0
}

main :: proc() {
	// Create the app with make_app.
	// default_command runs "list" when no subcommand is given (e.g. just `tasks`).
	app := cli.make_app(
		"tasks",
		description = "A simple task manager.",
		version = "1.0.0",
		default_command = "list",
	)

	// Register commands with add_command. Each gets its own flags type
	// and action handler. Aliases let users type less.
	cli.add_command(&app, Add_Flags, "add",
		description = "Add a new task",
		action = add_action,
	)
	cli.add_command(&app, List_Flags, "list",
		description = "List tasks",
		action = list_action,
		aliases = {"ls"},
	)
	cli.add_command(&app, Done_Flags, "done",
		description = "Mark a task as complete",
		action = done_action,
	)

	// run() dispatches to the matched command's action and returns an exit code.
	code := cli.run(&app, os.args)
	cli.destroy_app(&app)
	os.exit(code)
}
