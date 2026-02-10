package term

/* terminal_width returns the current terminal width in columns.
   Returns (0, false) if stdout is not a terminal. */
terminal_width :: proc() -> (int, bool) {
  return _terminal_width()
}
