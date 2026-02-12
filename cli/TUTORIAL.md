# CLI Package Tutorial

This tutorial walks through building command-line tools with the `cli` package, progressing from a simple greeter to a multi-command app with validation, subcommands, and custom constraints.

Each step has a runnable example in `examples/`. Build any example with:

```sh
odin build examples/tutorial_01_basic/
./tutorial_01_basic --help
```

---

## Step 1: Your First CLI

**Example:** `examples/tutorial_01_basic/main.odin`

The simplest way to parse command-line flags is `parse_or_exit`. Define a struct, tag its fields, and call one proc.

### Defining a flags struct

```odin
Options :: struct {
    name:  string `args:"pos=0,required" usage:"Name of the person to greet"`,
    count: int    `args:"short=n"        usage:"Number of times to greet"`,
    loud:  bool   `args:"short=l"        usage:"SHOUT the greeting"`,
}
```

Each struct field becomes a CLI flag. The two tags control behavior:

- **`usage:"..."`** — Description shown in `--help` output.
- **`args:"..."`** — Comma-separated parsing directives (see [Quick Reference](#quick-reference) below).

### Positional arguments

`args:"pos=0"` makes `name` a positional argument instead of a `--name` flag. Positional args are shown as `NAME` in the usage line. Add `required` to make it mandatory.

### Short flags

`args:"short=n"` lets users write `-n 3` instead of `--count 3`. Short flags are single characters.

### Boolean flags

Boolean fields like `loud` automatically support `--loud` to enable and `--no-loud` to disable (shown as `--[no-]loud` in help).

### Parsing

```odin
options: Options
cli.parse_or_exit(&options, os.args,
    description = "A friendly greeter.",
    version = "1.0.0",
    help_on_empty = true,
)
```

`parse_or_exit` handles `--help`, `--version`, parse errors, and validation. On success, your struct fields are populated and execution continues. On error, it prints a styled message and calls `os.exit`. With `help_on_empty = true`, running the program with no arguments shows help instead of returning an error.

### Running it

```
$ ./tutorial_01_basic Alice
Hello, Alice!

$ ./tutorial_01_basic Alice -n 3 --loud
HELLO, ALICE!
HELLO, ALICE!
HELLO, ALICE!

$ ./tutorial_01_basic --help
Usage: tutorial_01_basic [OPTIONS] NAME

A friendly greeter.
Version 1.0.0

Arguments:
  NAME    Name of the person to greet    [required]

Options:
  -n, --count        <int>    Number of times to greet
  -l, --[no-]loud             SHOUT the greeting
```

---

## Step 2: Input Validation

**Example:** `examples/tutorial_02_validation/main.odin`

Real tools need to validate their input. The `cli` package provides several validation mechanisms through struct tags.

### Enum flags

Define an Odin `enum` and use it as a field type. Valid values are shown automatically in help output:

```odin
Environment :: enum {
    Staging,
    Production,
}

Options :: struct {
    env: Environment `args:"short=e" usage:"Target environment"`,
}
```

Help displays: `--env {staging,production}`. Invalid values produce a clear error.

### Range validation

Constrain numeric fields with `min` and `max`:

```odin
replicas: int `args:"short=r,min=1,max=100" usage:"Number of replicas (1-100)"`,
```

Help displays: `[1..100]`. Values outside the range are rejected.

### Path validation

Require that a string path exists on disk:

```odin
config: string `args:"short=c,file_exists" usage:"Path to deploy config file"`,
```

The three path validators are:
- `file_exists` — must be an existing file
- `dir_exists` — must be an existing directory
- `path_exists` — must exist (file or directory)

### XOR groups (mutually exclusive flags)

When flags conflict, put them in an XOR group:

```odin
staging:    bool `args:"short=s,xor=target" usage:"Deploy to staging"`,
production: bool `args:"short=p,xor=target" usage:"Deploy to production"`,
```

If a user passes both `--staging` and `--production`, they get a clear error: *"Flags --staging, --production cannot be used together (group 'target')."*

### Organizing help with panels

For tools with many flags, panels group related options into named sections:

```odin
cli.parse_or_exit(&options, os.args,
    panel_config = {
        cli.Panel{name = "Target",  fields = {"staging", "production", "env"}},
        cli.Panel{name = "Scaling", fields = {"replicas"}},
    },
)
```

Flags listed in panels appear under their section heading. Remaining flags appear under "Options".

---

## Step 3: Multi-Command Apps

**Example:** `examples/tutorial_03_commands/main.odin`

For tools with subcommands (like `git commit`, `docker build`), use the App API: `make_app`, `add_command`, and `run`.

### Creating an App

```odin
app := cli.make_app(
    "tasks",
    description = "A simple task manager.",
    version = "1.0.0",
)
```

### Per-command flags

Each command defines its own flags struct and action handler. The action receives a pointer to the parsed flags and returns an exit code:

```odin
Add_Flags :: struct {
    title:    string   `args:"pos=0,required" usage:"Task description"`,
    priority: Priority `args:"short=p" usage:"Task priority"`,
}

add_action :: proc(flags: ^Add_Flags, program: string) -> int {
    fmt.printfln("Added: \"%s\" (priority: %v)", flags.title, flags.priority)
    return 0
}
```

### Adding commands

Register commands with `add_command`:

```odin
cli.add_command(&app, Add_Flags, "add",
    description = "Add a new task",
    action = add_action,
)
```

### Command aliases

Aliases let users type less:

```odin
cli.add_command(&app, List_Flags, "list",
    description = "List tasks",
    action = list_action,
    aliases = {"ls"},
)
```

Now `tasks list --all` and `tasks ls --all` are equivalent.

### Default command

When most invocations use the same command, set `default_command` so users can skip the subcommand name entirely:

```odin
app := cli.make_app(
    "tasks",
    description = "A simple task manager.",
    version = "1.0.0",
    default_command = "list",
)
```

Now `tasks` with no arguments runs `tasks list`, and `tasks --all` is the same as `tasks list --all`. The default command is shown with a `[default]` marker in help output. `--help` and `--version` still work as expected.

### Running the app

`run` dispatches to the matched command and returns its exit code:

```odin
code := cli.run(&app, os.args)
cli.destroy_app(&app)
os.exit(code)
```

Always call `destroy_app` to free resources, then `os.exit` with the returned code.

### Running it

```
$ ./tutorial_03_commands --help
Usage: tutorial_03_commands <command>

A simple task manager.
Version 1.0.0

Commands:
  add     Add a new task
  list    List tasks    [default]
  done    Mark a task as complete

$ ./tutorial_03_commands add "Buy milk" -p high
Added: "Buy milk" (priority: High)

$ ./tutorial_03_commands ls --all
Listing all tasks (including completed)...

$ ./tutorial_03_commands
Listing open tasks...

$ ./tutorial_03_commands --all
Listing all tasks (including completed)...
```

---

## Step 4: Advanced Features

**Example:** `examples/tutorial_04_advanced/main.odin`

This step builds a git remote-like tool demonstrating global flags, nested subcommands, count flags, XOR groups, and custom validators.

### Global flags

Flags shared across all commands are defined in a separate struct and registered with `set_global_flags`:

```odin
Global_Flags :: struct {
    verbose: int    `args:"short=v,count" usage:"Increase verbosity (-v, -vv, -vvv)"`,
    config:  string `args:"short=c"       usage:"Path to config file"`,
}

global: Global_Flags
app := cli.make_app("remote", ...)
cli.set_global_flags(&app, Global_Flags, &global)
```

Global flags appear in a "Global Options" section in help, and are parsed before command dispatch. After `run` returns, you can inspect `global.verbose`, `global.config`, etc.

### Count flags

`args:"count"` on an `int` field counts repeated short flags instead of taking a value:

```odin
verbose: int `args:"short=v,count" usage:"Increase verbosity (-v, -vv, -vvv)"`,
```

- `-v` → `verbose = 1`
- `-vvv` → `verbose = 3`

### Nested subcommands

Use `add_subcommand` to nest commands under a parent:

```odin
// Register the parent command.
cli.add_command(&app, Config_Flags, "config",
    description = "Manage remote configuration",
    action = config_action,
)

// Register children under "config".
cli.add_subcommand(&app, Config_Set_Flags, "config", "set",
    description = "Set a config value",
    action = config_set_action,
)
```

Users invoke nested commands with: `remote config set url https://...`

For deeper nesting, use slash-separated parent paths: `"config/advanced"`.

### Custom validators

When struct tags aren't expressive enough, register a custom validator. It runs after all built-in validation and returns `""` for success or an error message:

```odin
config_list_validator :: proc(flags: ^Config_List_Flags) -> string {
    if flags.json && len(flags.section) == 0 {
        return "JSON output requires --section to be specified."
    }
    return ""
}

cli.set_subcommand_validator(&app, "config", "list", Config_List_Flags, config_list_validator)
```

For top-level commands, use `set_validator` instead of `set_subcommand_validator`.

### Running it

```
$ ./tutorial_04_advanced --help
Usage: tutorial_04_advanced <command>
...
Global Options:
  -v, --verbose                Increase verbosity (-v, -vv, -vvv)
  -c, --config     <string>    Path to config file

Commands:
  push      Push commits to a remote
  fetch     Fetch updates from a remote
  config    Manage remote configuration

$ ./tutorial_04_advanced push origin main --force
Pushing main to origin (force=true, tags=false)

$ ./tutorial_04_advanced config set url https://example.com
Setting url = https://example.com

$ ./tutorial_04_advanced config list --json
Error: JSON output requires --section to be specified.
```

---

## Step 5: Shell Completions

Every app built with the `cli` package gets shell completions for free. Users run `--completions <shell>` to generate a completion script for Bash, Zsh, or Fish.

### How it works

The `--completions` flag is a built-in greedy flag (like `--help` and `--version`). When detected, the app prints a static completion script to stdout and exits. No extra code is needed — it's automatic for both `parse_or_exit` and `run`.

### Enabling completions

Users source the generated script in their shell:

**Bash** — add to `~/.bashrc`:
```sh
eval "$(myapp --completions bash)"
```

**Zsh** — add to `~/.zshrc`:
```sh
eval "$(myapp --completions zsh)"
```

**Fish** — run once:
```sh
myapp --completions fish > ~/.config/fish/completions/myapp.fish
```

### What gets completed

The generated scripts use your app's metadata to complete:

- **Commands and aliases** — `tasks <TAB>` suggests `add`, `list`, `ls`, `done`
- **Nested subcommands** — `remote config <TAB>` suggests `set`, `get`, `list`, `ls`
- **Flags** — `tasks add -<TAB>` suggests `--priority`, `-p`, etc.
- **Global flags** — available in all command contexts
- **Enum values** — `--priority <TAB>` suggests `low`, `medium`, `high`
- **File/directory paths** — flags with `file_exists`, `dir_exists`, or `path_exists` trigger path completion

### Standalone tools

Completions work for standalone `parse_or_exit` tools too. The greeter from Step 1 automatically supports:

```
$ eval "$(./tutorial_01_basic --completions bash)"
$ ./tutorial_01_basic -<TAB>
--count  --loud  -l  -n  --help  --completions
```

### Programmatic access

If you need to write completions to a custom writer (e.g., to a file):

```odin
// Multi-command app:
cli.write_completions(writer, &app, .Bash)

// Standalone flags-only tool:
cli.write_flag_completions(writer, "myapp", Options, .Zsh)
```

### Testing completions

```
$ ./tutorial_04_advanced --completions bash | bash -n && echo "valid"
valid

$ ./tutorial_04_advanced --completions zsh | zsh -n && echo "valid"
valid
```

---

## Quick Reference

### Struct Tags (`args:"..."`)

| Tag | Example | Description |
|-----|---------|-------------|
| `pos=N` | `pos=0` | Positional argument at index N |
| `required` | `required` | Flag must be provided |
| `short=X` | `short=v` | Single-character short flag |
| `name=X` | `name=error` | Override display name |
| `env=VAR` | `env=API_KEY` | Read from environment variable as fallback |
| `hidden` | `hidden` | Hide from help output |
| `count` | `count` | Count repeated short flags (int fields) |
| `greedy` | `greedy` | Short-circuit parsing when flag is present |
| `min=N` | `min=1` | Minimum numeric value |
| `max=N` | `max=100` | Maximum numeric value |
| `file_exists` | `file_exists` | Path must be an existing file |
| `dir_exists` | `dir_exists` | Path must be an existing directory |
| `path_exists` | `path_exists` | Path must exist |
| `xor=G` | `xor=fmt` | At most one flag in group G |
| `one_of=G` | `one_of=auth` | Exactly one flag in group G required |
| `any_of=G` | `any_of=feat` | At least one flag in group G required |
| `together=G` | `together=tls` | All flags in group G, or none |

### `parse_or_exit` Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `model` | `^$T` | Pointer to your flags struct |
| `program_args` | `[]string` | Usually `os.args` |
| `description` | `string` | Shown below usage line |
| `version` | `string` | Shown with `--version` and in help |
| `panel_config` | `[]Panel` | Group flags into named sections |
| `help_on_empty` | `bool` | Show help when no args given |
| `parsing_style` | `Parsing_Style` | `.Unix` (default) or `.Odin` |
| `theme_override` | `Maybe(Theme)` | Custom color theme |
| `mode` | `Maybe(Render_Mode)` | Force plain/color output |

### App API

| Proc | Description |
|------|-------------|
| `make_app(name, ...)` | Create an App |
| `destroy_app(&app)` | Free App resources |
| `set_global_flags(&app, T, &model)` | Register global flags |
| `add_command(&app, T, name, ...)` | Add a top-level command |
| `add_subcommand(&app, T, parent, name, ...)` | Add a nested command |
| `set_validator(&app, cmd, T, proc)` | Custom validator for a command |
| `set_subcommand_validator(&app, parent, cmd, T, proc)` | Custom validator for a subcommand |
| `run(&app, os.args)` | Parse and dispatch; returns exit code |
| `write_completions(w, &app, shell)` | Write shell completion script for an App |
| `write_flag_completions(w, name, T, shell)` | Write shell completion script for a flags struct |

### `make_app` Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `string` | Program name (used in help and completions) |
| `description` | `string` | Shown below usage line |
| `version` | `string` | Shown with `--version` and in help |
| `default_command` | `string` | Command to run when no subcommand is given |
| `parsing_style` | `Parsing_Style` | `.Unix` (default) or `.Odin` |
| `max_width` | `int` | Max help output width (0 = auto-detect) |
| `theme_override` | `Maybe(Theme)` | Custom color theme |

### Theme Customization

Use `default_theme()` as a starting point and override individual styles:

```odin
theme := cli.default_theme()
theme.heading_style = style.Style{text_styles = {.Bold}, foreground_color = style.ANSI_Color.Magenta}

cli.parse_or_exit(&options, os.args, theme_override = theme)
```

Use `plain_theme()` for no-color output (e.g., piped or CI environments).
