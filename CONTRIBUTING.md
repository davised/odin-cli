# Contributing to odin-cli

Thanks for your interest in contributing! This guide covers development setup, conventions, and the pull request process.

## Prerequisites

- **Odin compiler** — `dev-2026-02` nightly or later. See [odin-lang.org](https://odin-lang.org/docs/install/) for install instructions.
- **Git** — for cloning and submitting changes.

Verify your setup:

```bash
odin version
# dev-2026-02-nightly:...
```

## Getting Started

```bash
git clone https://github.com/davised/odin-cli.git
cd odin-cli
```

## Development Commands

The Makefile provides all common development tasks:

```bash
make help       # Show available targets
make test       # Run all 306 tests across 9 packages
make examples   # Build all examples
make bench      # Build and run benchmarks
make clean      # Remove build artifacts
```

You can also run tests for a single package:

```bash
odin test style/test
odin test cli/test
```

All tests must pass before submitting a PR.

## Project Structure

```
odin-cli/
├── style/          # Text styling, colors, fmt formatter
├── table/          # Formatted tables with borders
├── tree/           # Hierarchical tree rendering
├── logger/         # Structured logging
├── spinner/        # Animated terminal spinners
├── progress/       # Progress bars
├── panel/          # Bordered text panels
├── cli/            # CLI framework (flags, help, completions)
├── term/           # Terminal detection utilities
├── bench/          # Benchmarks (development tool)
├── prof/           # Profiling harness (development tool)
└── examples/       # Runnable examples and tutorials
```

Each package is independently importable. Packages may depend on sibling packages (e.g., `table` uses `style` and `term`) but there are no circular dependencies.

## Code Conventions

### Naming

| Kind | Convention | Example |
|------|-----------|---------|
| Procedures | `snake_case` | `make_table`, `add_row` |
| Types | `Pascal_Case` | `Styled_Text`, `Text_Style` |
| Enum types | `SCREAMING_CASE` | `ANSI_Color`, `Render_Mode` |
| Enum values | `Pascal_Case` | `Bright_Black`, `Time_Only` |
| Constants | `SCREAMING_CASE` with `::` | `BORDER_ROUNDED :: Border{...}` |

### Documentation

Use `/* */` block comments above public types and procedures:

```odin
/* Renders a table to the given writer. Returns the number of bytes written. */
render :: proc(tbl: ^Table, w: io.Writer, n: ^int) { ... }
```

Single-line doc comments use `//` directly above the item.

### Design Principles

1. **Zero or minimal allocation** — prefer stack-allocated structs and references over heap allocation.
2. **`fmt` integration** — types should be printable via `fmt.println` using custom formatters registered at init.
3. **Writer pattern** — output procedures take `io.Writer` and `n: ^int` for byte counting.
4. **No memory management burden** — users shouldn't need `defer delete` for basic usage.

### Visibility

Use `@(private="file")` to hide file-local helpers. Do not use underscore-prefixed names for private procedures. Struct fields may use underscore prefixes (e.g., `_thread`) to signal internal use.

## Testing

Tests live in `<package>/test/tests.odin` and use `core:testing`:

```odin
package style_test

import style ".."
import "core:testing"

@(test)
test_red :: proc(t: ^testing.T) {
    result := style.sprint(style.red("hello"))
    defer delete(result)
    testing.expect_value(t, result, "\x1b[31mhello\x1b[0m")
}
```

Key patterns:
- Test packages are named `<package>_test` and import the parent as `<package> ".."`.
- Use `testing.expect_value` for equality checks.
- Use `testing.set_fail_timeout` for tests involving threads or timing.
- Tests render to strings (via `sprint` or `strings.Builder`) and compare against expected output.

## Submitting Changes

1. Fork the repository and create a feature branch from `main`.
2. Make your changes. Follow the conventions above.
3. Add or update tests for any new functionality.
4. Run the full test suite and verify everything passes.
5. Open a pull request against `main` with a clear description of what changed and why.

Keep PRs focused — one feature or fix per PR is easier to review than a large batch of changes.

## License

By contributing, you agree that your contributions will be licensed under the [zlib license](LICENSE).
