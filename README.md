# odin-cli

A terminal styling library for Odin that prioritizes ease of use and zero memory allocation in production code.

## Design Goals

1. **Zero allocation by default** - Styled text works with `fmt.println()` without heap allocation
2. **Seamless integration** - Works transparently with Odin's standard `fmt` and `log` packages
3. **Functional composition** - Chain style functions naturally: `bold(italic(red("text")))`

## Why cli_style?

Other Odin terminal color libraries take different approaches that require more memory management:

**[odin-color](https://github.com/hrszpuk/odin-color)** allocates a new string for every styled text:

```odin
// odin-color approach - allocates via fmt.aprintf
color :: proc(color, input: string, allocator := context.allocator) -> string {
    return fmt.aprintf("%s%s%s", color, input, RESET, allocator = allocator)
}

// Usage requires managing the allocated string
colored := red("Hello")
defer delete(colored)
fmt.println(colored)
```

**[TermCL](https://github.com/RaphGL/TermCL)** uses dynamic cell buffers and string builders - designed for full-screen TUI apps, not inline text styling.

**cli_style** takes a different approach:

```odin
// cli_style - zero allocation, works directly with fmt
fmt.println(red("Hello"))  // No allocation, no cleanup needed

// Chaining is also zero-allocation
fmt.println(bold(italic(red("Hello"))))  // Still no allocation
```

The key difference is that `Styled_Text` is a stack-allocated struct holding a reference to your string (not a copy), and a custom formatter writes ANSI codes directly to the output stream.

| Library | Allocation per styled text | fmt.println() integration | Chaining cost |
|---------|---------------------------|---------------------------|---------------|
| odin-color | Yes (`aprintf`) | No - returns string | N allocations |
| TermCL | Dynamic buffers | No - TUI focused | N/A |
| **cli_style** | **No** | **Yes** - custom formatter | **Zero** |

## Quick Start

```odin
import "odin-cli/style"

main :: proc() {
    // Basic colors
    fmt.println(style.red("Error occurred"))
    fmt.println(style.green("Success!"))

    // Chained styles
    fmt.println(style.bold(style.italic(style.blue("Important"))))

    // Background colors
    fmt.println(style.yellow("Highlighted", bg = true))

    // Semantic helpers
    fmt.println(style.warn("Warning message"))
    fmt.println(style.error("Error message"))
    fmt.println(style.success("Success message"))

    // Works with log package
    log.info("Status:", style.success("ready"))
}
```

## How It Works

The library registers a custom formatter with Odin's `fmt` package at initialization. When `fmt.println()` encounters a `Styled_Text`, it writes ANSI escape codes directly to the output - no intermediate string allocation needed.

`Styled_Text` is a lightweight struct that lives on the stack:

```odin
Styled_Text :: struct {
    text:  string,  // Reference to your string (not a copy)
    style: Style,   // Text styles + foreground/background colors
}
```

## Recommended Workflow

### 1. Experiment with `st()`

The `st()` function parses style strings, making it easy to try different combinations:

```odin
// Try different styles interactively
fmt.println(st("Hello", "bold red"))
fmt.println(st("World", "italic underline fg:rgb(255,128,0)"))
fmt.println(st("Test", "bold bg:#336699 fg:white"))
```

Supported style string formats:
- **Text styles**: `bold`, `italic`, `underline`, `strike`, `faint`, `blink_slow`, `blink_rapid`, `invert`, `hide`
- **Named colors**: `red`, `blue`, `green`, `yellow`, `magenta`, `cyan`, `black`, `white` (and `bright*` variants)
- **Hex colors**: `#FF5500` or `FF5500`
- **RGB**: `rgb(255, 128, 0)`
- **HSL**: `hsl(120, 1.0, 0.5)`
- **8-bit palette**: `color(172)`
- **Foreground/background prefix**: `fg:red`, `bg:blue`, `bg:#00FF00`

Combine multiple styles with spaces: `"bold italic fg:rgb(255,0,0) bg:black"`

### 2. Convert to Hard-Coded Procedures

Once you've found styles you like, convert them to dedicated procedures for production use. This eliminates the parsing overhead and memory allocation from `st()`.

**Before (uses temp allocator for parsing):**
```odin
fmt.println(st("Winner!", "bold italic fg:brightgreen blink_rapid"))
```

**After (zero allocation):**
```odin
winner :: proc(str: union{string, Styled_Text}) -> Styled_Text {
    value := get_or_create_styled_text(str)
    value.style = Style{
        foreground_color = ANSI_FG.Bright_Green,
        text_styles = {.Bold, .Italic, .Blink_Rapid},
    }
    return value
}

// Usage
fmt.println(winner("You won!"))
```

The built-in `warn`, `error`, and `success` procedures are examples of this pattern.

### Why This Matters

| Approach | Allocates | Parsing | Use Case |
|----------|-----------|---------|----------|
| `st("text", "bold red")` | Yes (temp) | Runtime | Development, experimentation |
| `bold(red("text"))` | No | None | Production |
| `my_custom_style("text")` | No | None | Production (custom styles) |

## Creating Custom Style Procedures

Use the existing semantic helpers as templates:

```odin
// Simple: single color + style
my_highlight :: proc(str: union{string, Styled_Text}) -> Styled_Text {
    value := get_or_create_styled_text(str)
    value.style = Style{
        foreground_color = ANSI_FG.Yellow,
        background_color = ANSI_BG.Blue,
        text_styles = {.Bold},
    }
    return value
}

// RGB colors
my_brand_color :: proc(str: union{string, Styled_Text}) -> Styled_Text {
    value := get_or_create_styled_text(str)
    value.style = Style{
        foreground_color = RGB{66, 135, 245},  // Your brand blue
        text_styles = {.Bold},
    }
    return value
}

// 8-bit palette color
my_orange :: proc(str: union{string, Styled_Text}) -> Styled_Text {
    value := get_or_create_styled_text(str)
    value.style = Style{
        foreground_color = EightBit(208),  // Orange from 256-color palette
    }
    return value
}
```

## Available Types

### Colors

```odin
// Standard ANSI (16 colors) - most compatible
ANSI_FG :: enum { Black, Red, Green, Yellow, Blue, Magenta, Cyan, White,
                  Bright_Black, Bright_Red, Bright_Green, Bright_Yellow,
                  Bright_Blue, Bright_Magenta, Bright_Cyan, Bright_White }

// 8-bit palette (256 colors)
EightBit :: distinct u8

// True color (16 million colors)
RGB :: struct { r, g, b: EightBit }
```

### Text Styles

```odin
Text_Style :: enum {
    Bold, Faint, Italic, Underline,
    Blink_Slow, Blink_Rapid, Invert, Hide, Strike
}

// Combine multiple styles with a bit_set
Text_Style_Set :: bit_set[Text_Style]
```

## API Reference

All procedures include docstrings in the source. Key functions:

- **Color functions**: `red()`, `green()`, `blue()`, `yellow()`, `magenta()`, `cyan()`, `black()`, `white()` and `bright_*` variants
- **Style functions**: `bold()`, `italic()`, `underline()`, `strike()`, `faint()`, `blink_slow()`, `blink_rapid()`, `invert()`, `hide()`
- **Semantic helpers**: `warn()`, `error()`, `success()`
- **Parsing**: `st(text, style_string)` - parse a style string (uses temp allocator)
- **Conversion**: `to_str(styled_text)` - convert to allocated string with ANSI codes (caller must `delete`)

## Debugging: Inspecting Styled_Text

By default, printing a `Styled_Text` applies the ANSI formatting. To inspect the underlying struct instead, use the `%w` verb:

```odin
styled := bold(red("Hello"))

// Prints with ANSI formatting (colored output)
fmt.println(styled)
fmt.printfln("%v", styled)
fmt.printfln("%s", styled)

// Prints the struct itself (for debugging)
fmt.printfln("%w", styled)
// Output: Styled_Text{text = "Hello", style = Style{text_styles = {Bold}, foreground_color = Red, background_color = nil}}
```

This is helpful when you want to verify what styles are being applied without the terminal interpreting the ANSI codes.

## When You Need an Allocated String

If you need the ANSI-formatted string itself (not just printing), use `to_str()`:

```odin
formatted := to_str(bold(red("Error")))
defer delete(formatted)
// Use formatted string...
```

## Code Style

This library follows the conventions of Odin's core library:

- Procedure and type documentation uses `/* */` block comments
- Parameter and return value documentation follows core library format
- Snake_case for types, snake_case for procedures and variables
- Explicit error handling with multiple return values or `#optional_ok`

See the source files for examples - all public procedures include docstrings.

## License

[Add your license here]
