#+build linux, darwin
#+private
package term

import "core:sync"
import "core:sys/posix"

install_platform_handlers :: proc() {
	set_signal_handler(.SIGINT, handle_terminate)
	set_signal_handler(.SIGTERM, handle_terminate)
	set_signal_handler(.SIGHUP, handle_terminate)

	set_signal_handler(.SIGQUIT, handle_crash)
	set_signal_handler(.SIGILL, handle_crash)
	set_signal_handler(.SIGABRT, handle_crash)
	set_signal_handler(.SIGFPE, handle_crash)
	set_signal_handler(.SIGSEGV, handle_crash)

	set_signal_handler(.SIGTSTP, handle_tstp)
	set_signal_handler(.SIGCONT, handle_cont)
}

// First termination signal (any of SIGINT/SIGTERM/SIGHUP): restore cursor, set exit flag.
// Any subsequent termination signal: reset to default and re-raise to force exit.
@(private = "file")
handle_terminate :: proc "c" (sig: posix.Signal) {
	restore_cursor_if_hidden()
	already_flagged := bool(sync.atomic_load_explicit(&cleanup_state.exit_flag, .Acquire))
	sync.atomic_store_explicit(&cleanup_state.exit_flag, true, .Release)
	if already_flagged {
		reset_signal(sig)
		posix.raise(sig)
	}
}

// SIGQUIT, SIGILL, SIGABRT, SIGFPE, SIGSEGV: reset handler first to prevent
// recursive crash, restore cursor as best effort, then re-raise for core dump.
@(private = "file")
handle_crash :: proc "c" (sig: posix.Signal) {
	reset_signal(sig)
	restore_cursor_if_hidden()
	posix.raise(sig)
}

// SIGTSTP (Ctrl+Z): show cursor then suspend via default handler.
// Does NOT clear cursor_hidden — SIGCONT needs it to decide whether to re-hide.
@(private = "file")
handle_tstp :: proc "c" (_sig: posix.Signal) {
	if sync.atomic_load_explicit(&cleanup_state.cursor_hidden, .Acquire) {
		restore_cursor()
	}
	reset_signal(.SIGTSTP)
	posix.raise(.SIGTSTP)
	// Execution resumes here after SIGCONT; the SIGCONT handler re-hides.
}

// SIGCONT (resume after Ctrl+Z): re-hide cursor if it was hidden, re-install
// our SIGTSTP handler so subsequent Ctrl+Z works.
@(private = "file")
handle_cont :: proc "c" (_sig: posix.Signal) {
	if sync.atomic_load_explicit(&cleanup_state.exit_flag, .Acquire) {
		return // Shutting down — don't re-hide.
	}
	if sync.atomic_load_explicit(&cleanup_state.cursor_hidden, .Acquire) {
		hide_cursor()
	}
	set_signal_handler(.SIGTSTP, handle_tstp)
}

// Install a signal handler via sigaction. Uses default flags (handler persists,
// interrupted syscalls return EINTR). Preferred over signal() for portability
// (signal() resets to SIG_DFL on musl libc).
@(private = "file")
set_signal_handler :: proc "contextless" (sig: posix.Signal, handler: proc "c" (posix.Signal)) {
	act: posix.sigaction_t
	act.sa_handler = handler
	posix.sigaction(sig, &act, nil)
}

// Reset a signal to default behavior. Async-signal-safe.
@(private = "file")
reset_signal :: proc "contextless" (sig: posix.Signal) {
	act: posix.sigaction_t
	act.sa_handler = auto_cast posix.SIG_DFL
	posix.sigaction(sig, &act, nil)
}

// Package-visible: called by restore_cursor_if_hidden in signal.odin.
restore_cursor :: proc "contextless" () {
	seq := SHOW_CURSOR_SEQ
	posix.write(posix.FD(cleanup_state.handle), raw_data(&seq), size_of(seq))
}

@(private = "file")
hide_cursor :: proc "contextless" () {
	seq := HIDE_CURSOR_SEQ
	posix.write(posix.FD(cleanup_state.handle), raw_data(&seq), size_of(seq))
}
