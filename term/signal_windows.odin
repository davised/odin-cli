#+build windows
#+private
package term

import "core:sync"
import "core:sys/windows"

install_platform_handlers :: proc() {
	windows.SetConsoleCtrlHandler(console_handler, true)
}

// Runs on a separate OS thread (not a signal context).
// First CTRL_C/CTRL_BREAK: set flag for graceful shutdown (return TRUE).
// Repeated signal or CTRL_CLOSE: pass to default handler (return FALSE).
@(private = "file")
console_handler :: proc "system" (ctrl_type: windows.DWORD) -> windows.BOOL {
	switch ctrl_type {
	case windows.CTRL_C_EVENT, windows.CTRL_BREAK_EVENT, windows.CTRL_CLOSE_EVENT:
		restore_cursor_if_hidden()
		already_flagged := bool(sync.atomic_load_explicit(&cleanup_state.exit_flag, .Acquire))
		sync.atomic_store_explicit(&cleanup_state.exit_flag, true, .Release)
		if ctrl_type == windows.CTRL_CLOSE_EVENT || already_flagged {
			return 0 // FALSE — pass to default handler (terminate)
		}
		return 1 // TRUE — handled, process continues for graceful shutdown
	}
	return 0
}

// Package-visible: called by restore_cursor_if_hidden in signal.odin.
restore_cursor :: proc "contextless" () {
	seq := SHOW_CURSOR_SEQ
	written: windows.DWORD
	windows.WriteFile(
		windows.HANDLE(cleanup_state.handle),
		rawptr(raw_data(&seq)),
		size_of(seq),
		&written,
		nil,
	)
}
