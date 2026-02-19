// Terminal signal cleanup: restores cursor visibility on interruption, suspension, or crash.
package term

import "core:os"
import "core:sync"

// ESC[?25h — raw bytes for async-signal-safe write.
@(private = "package")
SHOW_CURSOR_SEQ :: [6]u8{0x1b, 0x5b, 0x3f, 0x32, 0x35, 0x68}

// ESC[?25l
@(private = "package")
HIDE_CURSOR_SEQ :: [6]u8{0x1b, 0x5b, 0x3f, 0x32, 0x35, 0x6c}

@(private = "package")
cleanup_state: struct {
	installed:     bool, // Only accessed from main thread; not atomic.
	cursor_hidden: b32,
	exit_flag:     b32,
	handle:        os.Handle, // Set before install_platform_handlers; never modified after.
}

/* install_cleanup_handler registers signal handlers that automatically
   restore terminal state (cursor visibility) on interruption or suspension.
   Call once at program start, before spawning worker threads.
   Safe to call multiple times (subsequent calls are no-ops).

   Signals handled:
   - SIGINT (Ctrl+C), SIGTERM, SIGHUP: restore cursor, allow graceful shutdown
     via should_exit. A repeated signal forces immediate termination.
   - SIGQUIT, SIGILL, SIGABRT, SIGFPE, SIGSEGV: restore cursor on crash,
     re-raise for core dump.
   - SIGTSTP (Ctrl+Z): restore cursor, suspend, re-hide on resume.
   - Windows: CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT. */
install_cleanup_handler :: proc(handle: os.Handle = os.stderr) {
	if cleanup_state.installed do return
	cleanup_state.handle = handle
	install_platform_handlers()
	cleanup_state.installed = true
}

/* should_exit returns true after a termination signal (SIGINT, SIGTERM, SIGHUP)
   has been received. Poll this in main loops for graceful shutdown. */
should_exit :: proc() -> bool {
	return bool(sync.atomic_load_explicit(&cleanup_state.exit_flag, .Acquire))
}

/* notify_cursor_hidden tracks that the cursor is currently hidden so the
   cleanup handler knows whether to restore it. Called automatically by
   spinner.start. Safe to call even if install_cleanup_handler was not called. */
notify_cursor_hidden :: proc() {
	sync.atomic_store_explicit(&cleanup_state.cursor_hidden, true, .Release)
}

/* notify_cursor_visible tracks that the cursor is now visible. Called
   automatically by spinner.stop. Safe to call even if install_cleanup_handler
   was not called. */
notify_cursor_visible :: proc() {
	sync.atomic_store_explicit(&cleanup_state.cursor_hidden, false, .Release)
}

// Restore cursor if hidden and clear the flag. Used by signal handlers and fini.
// Safe to call concurrently (redundant restores are harmless).
// NOT used by handle_tstp, which preserves the flag for SIGCONT re-hide.
@(private = "package")
restore_cursor_if_hidden :: proc "contextless" () {
	if sync.atomic_load_explicit(&cleanup_state.cursor_hidden, .Acquire) {
		restore_cursor()
		sync.atomic_store_explicit(&cleanup_state.cursor_hidden, false, .Release)
	}
}

// Ensure handle defaults to stderr for fini_restore_cursor even if
// install_cleanup_handler is never called.
@(private = "file", init)
init_cleanup :: proc "contextless" () {
	cleanup_state.handle = os.stderr
}

// Safety net: restore cursor if still hidden on normal exit.
@(private = "file", fini)
fini_restore_cursor :: proc "contextless" () {
	restore_cursor_if_hidden()
}
