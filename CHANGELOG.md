# Changelog

All notable changes to odin-cli are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versions use `dev-YYYY-MM.minor.patch`, where `dev-YYYY-MM` matches the required Odin version.

## [Unreleased]

Initial development targeting Odin `dev-2026-02`.

### Added

- **style**: Zero-allocation ANSI text styling with `fmt` integration. `Styled_Text` holds a reference, not a copy — nothing to allocate or free. Chainable helpers (`bold`, `italic`, `red`, `green`, etc.) compose on the stack.
- **style**: Runtime style string parser (`st()`) supporting named colors, hex (`#FF5500`), RGB (`rgb(255,128,0)`), HSL (`hsl(120,1.0,0.5)`), and 8-bit palette (`color(172)`) with `fg:`/`bg:` prefixes.
- **style**: CSS named color lookup (148 colors) and automatic color depth degradation (True Color to 256 to 16 to none).
- **style**: Text styles: Bold, Faint, Italic, Underline, Double\_Underline, Blink\_Slow, Blink\_Rapid, Invert, Conceal, Strike, Overlined, Framed, Encircled.
- **table**: Formatted tables with Unicode borders, column alignment (left/center/right), auto-sizing, fixed-width mode, text wrapping, titles, row separators, and styled cells.
- **table**: Six predefined border styles: `BORDER_ROUNDED`, `BORDER_LIGHT`, `BORDER_HEAVY`, `BORDER_DOUBLE`, `BORDER_ASCII`, `BORDER_NONE`.
- **tree**: Hierarchical tree rendering with Unicode branch characters. Builder API for programmatic construction. Recursive nesting, per-subtree enumerator override, and forest mode (nil root).
- **tree**: Three predefined enumerators: `DEFAULT_ENUMERATOR`, `ROUNDED_ENUMERATOR`, `ASCII_ENUMERATOR`.
- **logger**: Structured logging with dual API — `context.logger` drop-in and direct structured logging with additional levels (Trace, Hint, Success).
- **logger**: Multi-sink output, per-sink level filtering, auto-color detection, configurable timestamps, caller location, sub-loggers with pre-bound fields, CLI verbosity adjustment.
- **spinner**: Animated terminal spinners with threaded animation. Three predefined animations: `spinner_dots()` (braille), `spinner_line()`, `spinner_circle()`. Thread-safe message updates. Falls back to static text when piped.
- **progress**: Progress bars with percentage, count, and elapsed time. Three predefined styles: `bar_block()`, `bar_ascii()`, `bar_thin()`. Customizable fill styles.
- **cli**: Rich CLI framework wrapping `core:flags` with formatted help output, input validation, multi-command apps, and shell completions.
- **cli**: Validation: `required`, `min`/`max` ranges, `file_exists`/`dir_exists`, `env=VAR`, flag groups (`xor`, `one_of`, `together`), custom validators.
- **cli**: Shell completion generation for Bash, Zsh, and Fish via `--completions`. Typo suggestions via Levenshtein distance. Negatable booleans (`--[no-]flag`). Count flags (`-vvv`). Multiple short aliases.
- **cli**: Tutorial with 5 progressive steps and runnable examples.
- **term**: Terminal capability detection — width, color depth (3/4/8/24-bit), render mode (Full/No\_Color/Plain).
- **term**: ANSI-aware display width calculation, `strip_ansi`, and `truncate` that preserves ANSI sequences.
- **term**: Respects `NO_COLOR`, `FORCE_COLOR`, and `CLICOLOR_FORCE` environment variables.
- **term**: Signal cleanup handler that automatically restores cursor visibility on Ctrl+C, Ctrl+Z, crashes, and termination signals. `install_cleanup_handler` + `should_exit` for graceful shutdown polling. POSIX suspend/resume (SIGTSTP/SIGCONT) re-hides cursor on `fg`.
- **panel**: Bordered text panels with optional styled title, configurable padding, auto-sizing to content width, and fixed-width mode with truncation.
- **panel**: Six predefined border styles matching table borders.
- **repo**: Comprehensive README, examples for every package, CLI tutorial.
- **repo**: Add compatibility section documenting versioning scheme (`dev-YYYY-MM.minor.patch`).
- **repo**: Add CONTRIBUTING.md, Makefile, and developer documentation.
- **repo**: Add CHANGELOG.md.
