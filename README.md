# odin-cli

A terminal toolkit for Odin — styled text, tables, logging, spinners, progress bars, trees, panels, and CLI framework, all with zero-allocation design and seamless `fmt` integration.

Inspired by [Rich](https://github.com/Textualize/rich) for Python.

## Packages

| Package | Description |
|---------|-------------|
| [`style`](style/) | Zero-allocation ANSI text styling with `fmt` integration |
| [`table`](table/) | Formatted tables with borders, alignment, and styled cells |
| [`logger`](logger/) | Structured logging with multiple sinks and `context.logger` drop-in |
| [`spinner`](spinner/) | Animated terminal spinners with threaded animation |
| [`progress`](progress/) | Progress bars with customizable styles and elapsed time |
| [`tree`](tree/) | Hierarchical tree rendering with Unicode branch characters |
| [`panel`](panel/) | Bordered text panels with title, padding, and auto/fixed width |
| [`cli`](cli/) | CLI framework with rich help output, validation, and shell completions |
| [`term`](term/) | Terminal capability detection (width, color, render mode) |

Each package can be imported independently — use only what you need.

## Compatibility

odin-cli versions track Odin releases directly. The version format is `dev-YYYY-MM.minor.patch`, where `dev-YYYY-MM` matches the Odin version and `minor.patch` tracks odin-cli releases:

| odin-cli version | Odin version | Branch |
|------------------|--------------|--------|
| `dev-2026-02.x.x` | `dev-2026-02` or later | `main` |

Tags are made on `main` for the current Odin version. When a new Odin version is released, the previous version gets a `release/dev-YYYY-MM` maintenance branch and `main` moves forward. Bug fixes go to `main` first, then get cherry-picked to maintained release branches as needed.

Pick the tag that matches your Odin version. See [Releases](https://github.com/davised/odin-cli/releases) for the latest.

## Installation

### As a git subtree (recommended)

Copies the source directly into your project — no special steps for collaborators who clone your repo:

```bash
git subtree add --prefix deps/odin-cli https://github.com/davised/odin-cli.git dev-2026-02.0.0 --squash
```

Then import the packages you need:

```odin
import "deps/odin-cli/style"
import "deps/odin-cli/table"
import "deps/odin-cli/logger"
```

To update to a newer release:

```bash
git subtree pull --prefix deps/odin-cli https://github.com/davised/odin-cli.git dev-2026-02.1.0 --squash
```

### As a git submodule

Keeps a lightweight reference instead of copying the source. Best when you want to pin to a specific version and update deliberately:

```bash
git submodule add -b main https://github.com/davised/odin-cli.git deps/odin-cli
cd deps/odin-cli && git checkout dev-2026-02.0.0 && cd ../..
git add deps/odin-cli
```

Collaborators cloning your project need an extra step:

```bash
git clone --recurse-submodules https://github.com/yourname/yourproject.git
# or, if already cloned:
git submodule update --init
```

To update to a newer release:

```bash
cd deps/odin-cli && git fetch && git checkout dev-2026-02.1.0 && cd ../..
git add deps/odin-cli && git commit -m "Update odin-cli to dev-2026-02.1.0"
```

### Into the Odin shared collection

For system-wide availability across all your projects:

```bash
cd /path/to/Odin/shared
git clone -b main https://github.com/davised/odin-cli.git odin-cli
```

Then import with:

```odin
import "shared:odin-cli/style"
import "shared:odin-cli/table"
```

Note: your build command or `ols.json` must know where the shared collection lives. If you haven't configured one, pass it to the compiler: `odin build . -collection:shared=/path/to/Odin/shared`.

## Design Philosophy

### Zero allocation by default

Most terminal styling libraries allocate a new string for every styled text — you get a string back, you `defer delete` it, and if you forget, you leak. odin-cli takes a different approach: `Styled_Text` is a stack-allocated struct that holds a *reference* to your string (not a copy). Nothing is allocated; nothing needs to be freed.

```odin
// Other libraries: allocate, print, free
colored := other_lib.red("Hello")
defer delete(colored)
fmt.println(colored)

// odin-cli: just print
fmt.println(style.red("Hello"))
```

This extends to chaining — `style.bold(style.italic(style.red("Hello")))` is still zero allocation. Each call returns a small struct on the stack.

### Custom fmt formatters

At program init, each package registers a custom formatter with Odin's `fmt` package. This means styled text, tables, and trees work transparently anywhere `fmt` does — `fmt.println`, `fmt.printfln`, `log.info`, string interpolation via `fmt.tprintf`, all of it.

### The io.Writer pattern

Every package that produces output writes directly to an `io.Writer`. No intermediate string buffers, no allocations for the output itself. Tables write row-by-row, trees write line-by-line, loggers write field-by-field — all straight to the destination.

### Render mode awareness

All output packages auto-detect terminal capabilities. The CLI framework sets a process-wide render mode at startup, and all `fmt` formatters read it automatically. They respect the [`NO_COLOR`](https://no-color.org/) standard, detect TTY vs pipe, and degrade gracefully: full color in terminals, plain text through pipes — including when using `fmt.println` directly.

## Quick Start

```odin
import "deps/odin-cli/style"

main :: proc() {
    // Basic colors
    fmt.println(style.red("Error occurred"))
    fmt.println(style.green("Success!"))

    // Chained styles — still zero allocation
    fmt.println(style.bold(style.italic(style.blue("Important"))))

    // Semantic helpers
    fmt.println(style.warn("Warning message"))
    fmt.println(style.error("Error message"))
    fmt.println(style.success("Success message"))

    // Works with log package
    log.info("Status:", style.success("ready"))
}
```

### Style strings for prototyping

The `st()` function parses style strings at runtime (uses temp allocator). Once you've settled on styles, convert to zero-allocation procedure calls for production:

```odin
// Prototyping — parses at runtime
fmt.println(style.st("Hello", "bold italic fg:rgb(255,128,0)"))

// Production — write a custom procedure, zero allocation
highlight :: proc(str: union{string, style.Styled_Text}) -> style.Styled_Text {
    value := style.get_or_create_styled_text(str)
    value.style = style.Style{
        foreground_color = style.RGB{255, 128, 0},
        text_styles      = {.Bold, .Italic},
    }
    return value
}

fmt.println(highlight("Hello"))
```

Supported formats: named colors (`red`, `bright_green`), hex (`#FF5500`), RGB (`rgb(255,128,0)`), HSL (`hsl(120,1.0,0.5)`), 8-bit palette (`color(172)`), with `fg:`/`bg:` prefixes for foreground/background.

## Packages

### table

Formatted tables with Unicode borders, column alignment, auto-sizing, and styled cells.

```odin
tbl := table.make_table(border = table.BORDER_ROUNDED)
defer table.destroy_table(&tbl)

table.add_column(&tbl, style.bold("Name"))
table.add_column(&tbl, style.bold("Status"), alignment = .Center)

table.add_row(&tbl, "Alice", style.green("Active"))
table.add_row(&tbl, "Bob",   style.yellow("Away"))

fmt.println(tbl)
```

Predefined borders: `BORDER_ROUNDED`, `BORDER_LIGHT`, `BORDER_HEAVY`, `BORDER_DOUBLE`, `BORDER_ASCII`, `BORDER_NONE`. Supports fixed-width mode, text wrapping, titles, row separators, and per-cell alignment.

See [`examples/table_demo`](examples/table_demo) for more.

### logger

Structured logging with styled output, multiple sinks, and a dual API — use it as a `context.logger` drop-in or call the direct structured logging API for additional levels like Trace, Hint, and Success.

```odin
// Drop-in replacement for context.logger
lgr := logger.make_logger(lowest_level = .Debug)
context.logger = logger.to_runtime_logger(&lgr)

log.info("Server started")
log.warn("Cache miss rate high")

// Or use the direct API for structured key-value logging
logger.log_info(&lgr, "request handled", "method", "GET", "status", "200")

// Sub-loggers with pre-bound fields
db := logger.with_fields(lgr, "component", "database")
logger.log_warn(&db, "slow query", "duration", "850ms")
```

Features: per-sink level filtering, auto-color detection, timestamps, caller location, CLI verbosity adjustment (`set_level` for `-v`/`-q` flags).

See [`examples/logger_demo`](examples/logger_demo) for more.

### spinner

Animated terminal spinners with threaded animation and graceful degradation.

```odin
s := spinner.make_spinner(message = "Loading...")
spinner.start(&s)

// Do work...

spinner.stop(&s, message = "Done!")
```

Predefined animations: `spinner_dots()` (braille), `spinner_line()`, `spinner_circle()`. Thread-safe message updates via `set_message`. Falls back to static text when piped.

### progress

Progress bars with customizable fill styles, percentage, count, and elapsed time.

```odin
bar := progress.make_progress(total = 100, message = "Processing")
progress.start(&bar)

for i in 0..<100 {
    // Do work...
    progress.increment(&bar)
}

progress.complete(&bar, message = "Complete!")
```

Predefined styles: `bar_block()` (`████░░`), `bar_ascii()` (`===>`), `bar_thin()` (`━━━───`).

### tree

Hierarchical tree rendering with Unicode branch characters and styled nodes.

```odin
t := tree.Tree{
    root = "Project",
    children = {
        "README.md",
        style.bold("src/"),
        &tree.Tree{
            root = style.blue("lib/"),
            children = {"utils.odin", "core.odin"},
        },
    },
}

fmt.println(t)
```

Predefined enumerators: `DEFAULT_ENUMERATOR` (`├──`/`└──`), `ROUNDED_ENUMERATOR` (`├──`/`╰──`), `ASCII_ENUMERATOR` (`|--`/`\--`). Supports recursive nesting, per-subtree enumerator override, and forest mode (nil root).

### panel

Bordered text panels with title, configurable padding, and auto or fixed width.

```odin
p := panel.Panel{
    lines = {
        style.bold("odin-cli"),
        "A terminal toolkit for Odin.",
        style.faint("Zero allocation. Works with fmt."),
    },
    border  = panel.BORDER_ROUNDED,
    title   = style.bold("About"),
    padding = 1,
}

fmt.println(p)
```

Predefined borders: `BORDER_ROUNDED`, `BORDER_LIGHT`, `BORDER_HEAVY`, `BORDER_DOUBLE`, `BORDER_ASCII`, `BORDER_NONE`. Supports styled titles, auto-sizing to content width, and fixed-width mode with truncation.

### cli

Rich CLI framework wrapping `core:flags` with beautiful help output, input validation, multi-command apps, and shell completions.

**Simple single-command:**

```odin
Options :: struct {
    input:   string `args:"pos=0,required,file_exists" usage:"Input file"`,
    verbose: bool   `args:"short=v" usage:"Verbose output"`,
    count:   int    `args:"min=1,max=100" usage:"Iterations"`,
}

main :: proc() {
    options: Options
    cli.parse_or_exit(&options, os.args,
        description = "My tool.",
        version = "1.0.0",
    )
}
```

**Multi-command app:**

```odin
app := cli.make_app("mytool",
    description = "My multi-command tool.",
    version = "1.0.0",
)

cli.add_command(&app, Build_Flags, "build",
    description = "Build the project",
    action = build_action,
    aliases = {"b"},
)

cli.run(&app, os.args)
```

Validation tags: `required`, `min`/`max`, `file_exists`/`dir_exists`, `env=VAR`, `short=X`, `count` (for `-vvv`), flag groups (`xor`, `one_of`, `together`). Auto-generates `--completions` for Bash/Zsh/Fish. Typo suggestions via Levenshtein distance.

See [`examples/cli_demo`](examples/cli_demo), [`examples/hqsub_demo`](examples/hqsub_demo), and the [CLI tutorial](cli/TUTORIAL.md) for more.

### term

Terminal capability detection used by all output packages.

```odin
// Detect terminal width
if width, ok := term.terminal_width(); ok {
    fmt.printfln("Terminal is %d columns wide", width)
}

// Detect color/style support for an output handle
mode := term.detect_render_mode(os.stderr)
// Returns: .Full (color + styles), .No_Color (styles only), or .Plain (nothing)
```

Respects `NO_COLOR`, `FORCE_COLOR`, and `CLICOLOR_FORCE` environment variables.

## Development

```bash
make test       # Run all 306 tests across 9 packages
make examples   # Build all examples
make bench      # Build and run benchmarks
make clean      # Remove build artifacts
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full development setup, code conventions, and PR guidelines.

## See Also

Odin has a growing ecosystem of terminal libraries at different levels of abstraction:

- [**afmt**](https://github.com/OnlyXuul/afmt) — ANSI printing library that mirrors `core:fmt` with color and attribute format strings. If you just want colored `println` without the rest of the toolkit, afmt is a clean, focused choice.
- [**TermCL**](https://github.com/RaphGL/TermCL) — Terminal control library for building TUIs. Provides cursor control, input handling, raw mode, and even an SDL3 rendering backend. Different scope — where odin-cli formats output, TermCL controls the terminal.
- [**karvi**](https://github.com/greenm01/karvi) — ANSI terminal support library with screen management, cursor control, and event handling. Similar scope to TermCL.
- [**odin-color**](https://github.com/hrszpuk/odin-color) — Simple ANSI color package inspired by Rust's `colored` crate.
- Odin's built-in [`core:terminal`](https://pkg.odin-lang.org/core/terminal/) and [`core:terminal/ansi`](https://pkg.odin-lang.org/core/terminal/ansi/) packages provide raw ANSI constants and terminal detection that many of these libraries (including odin-cli) build on.

odin-cli focuses on **output formatting** — styled text, tables, trees, panels, logging, progress indicators, and CLI framework — rather than terminal control. If you need both, odin-cli pairs well with a TUI library like TermCL or karvi.

## Acknowledgments

This project is inspired by [Rich](https://github.com/Textualize/rich) by [Will McGugan](https://github.com/willmcgugan) — a fantastic Python library for terminal output. Rich demonstrated that CLI tools don't have to look boring, and that a well-designed terminal toolkit can make a real difference in developer experience.

## AI Transparency

The majority of this project was written with [Claude Code](https://claude.ai/claude-code) (Opus 4.6). The development workflow is human-directed, AI-assisted: architectural decisions, API design, and code review are done by a human; implementation, testing, and iteration are collaborative.

## Contributing

Issues and PRs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code conventions, and how to run tests.

## License

zlib — see [LICENSE](LICENSE) for details.
