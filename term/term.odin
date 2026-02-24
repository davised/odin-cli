// Terminal utilities: display width, text truncation, word wrapping, and render mode detection.
package term

import "core:os"
import "core:terminal"

// Render_Mode controls how much ANSI output is emitted.
Render_Mode :: enum {
	Plain,    // No ANSI at all. Piped output / TERM=dumb.
	No_Color, // Text styles (bold/italic/underline) but no colors. NO_COLOR set on a TTY.
	Full,     // Everything: colors + text styles + terminal control.
}

// Color_Depth mirrors core:terminal.Color_Depth — the level of color support
// reported by the terminal at program startup.
Color_Depth :: terminal.Color_Depth

// detect_color_depth returns the terminal's color depth as detected at init time.
detect_color_depth :: proc() -> Color_Depth {
	return terminal.color_depth
}

/* terminal_width returns the current terminal width in columns.
	 Returns (0, false) if stdout is not a terminal. */
terminal_width :: proc() -> (int, bool) {
	return _terminal_width()
}

/* detect_render_mode determines the appropriate rendering mode for an output handle.

	 Precedence (highest to lowest):
	 1. NO_COLOR (set on any handle) → strips colors; if TTY returns .No_Color, else .Plain.
	 2. FORCE_COLOR (non-zero) / CLICOLOR_FORCE (non-zero) → .Full even through pipes.
	    FORCE_COLOR=0 is treated as a color disable, not a force.
	 3. TTY check: terminal → .Full, non-terminal → .Plain. */
detect_render_mode :: proc(handle: os.Handle) -> Render_Mode {
	if !terminal.is_terminal(handle) {
		if terminal.color_enabled && force_color_set() {
			return .Full
		}
		return .Plain
	}
	if !terminal.color_enabled {
		return .No_Color
	}
	return .Full
}

// _global_mode is the process-wide render mode, set once at startup.
// Defaults to .Full for backward compatibility if never explicitly set.
@(private = "file")
_global_mode: Render_Mode = .Full

// set_render_mode stores the detected render mode for the process.
// Called once by the CLI framework during run() / parse_or_exit().
set_render_mode :: proc(mode: Render_Mode) {
	_global_mode = mode
}

// get_render_mode returns the process-wide render mode.
get_render_mode :: proc() -> Render_Mode {
	return _global_mode
}

@(private = "file")
force_color_set :: proc() -> bool {
	fc, fc_ok := os.lookup_env("FORCE_COLOR", context.temp_allocator)
	if fc_ok && fc != "0" do return true
	ccf, ccf_ok := os.lookup_env("CLICOLOR_FORCE", context.temp_allocator)
	if ccf_ok && ccf != "" && ccf != "0" do return true
	return false
}
