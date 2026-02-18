package term

import "core:unicode/utf8"

ELLIPSIS :: "…"

// is_printable_ascii returns true if every byte in s is printable ASCII
// (0x20..0x7E). Control characters and multi-byte UTF-8 return false.
@(private)
is_printable_ascii :: proc(s: string) -> bool {
	for b in transmute([]u8)s {
		if b < 0x20 || b >= 0x7F do return false
	}
	return true
}

/* display_width returns the monospace terminal cell width of a string.
	 Handles CJK/fullwidth (2 cols), combining marks (0 cols), emoji, etc.
	 ANSI escape sequences (CSI, OSC, Fe) contribute zero width.
	 Uses a fast path for printable ASCII strings where len == display width. */
display_width :: proc(s: string) -> int {
	// Single pass: detect ESC and non-ASCII in one scan.
	has_non_ascii := false
	for b in transmute([]u8)s {
		if b == 0x1b do return display_width_ansi(s)
		if b < 0x20 || b >= 0x7F do has_non_ascii = true
	}
	if !has_non_ascii do return len(s)
	_, _, w := utf8.grapheme_count(s)
	return w
}

/* truncate truncates a string to fit within max_width display columns,
	 appending an ellipsis if truncation occurs. Returns the original string
	 when it fits or when max_width is 0 (unlimited). */
truncate :: proc(s: string, max_width: int, allocator := context.temp_allocator) -> string {
	if max_width <= 0 do return s

	// Fast path: if byte length fits and all bytes are printable ASCII, no truncation needed.
	if len(s) <= max_width && is_printable_ascii(s) do return s

	// Single-pass: walk graphemes tracking both budget cut point and max_width overflow.
	// If iterator exhausts without exceeding max_width, the string fits — return as-is.
	budget := max_width - 1 // reserve 1 column for ellipsis
	it := utf8.decode_grapheme_iterator_make(s)
	acc_width := 0
	byte_end := 0 // byte offset where budget is exceeded (cut point for ellipsis)
	found_cut := false

	for _, grapheme in utf8.decode_grapheme_iterate(&it) {
		if acc_width + grapheme.width > max_width {
			// Truncation confirmed — early exit.
			if !found_cut {
				byte_end = grapheme.byte_index
			}
			buf := make([]u8, byte_end + len(ELLIPSIS), allocator)
			copy(buf[:byte_end], s[:byte_end])
			copy(buf[byte_end:], ELLIPSIS)
			return string(buf)
		}
		if !found_cut && acc_width + grapheme.width > budget {
			byte_end = grapheme.byte_index
			found_cut = true
		}
		acc_width += grapheme.width
	}

	// Iterator exhausted without exceeding max_width — string fits.
	return s
}

/* Word_Wrap_Iterator yields lines of at most max_width display columns,
	 breaking at word boundaries (spaces). Falls back to character-level
	 breaking when a single word exceeds max_width. Each yielded line is a
	 slice of the original string — zero allocation. */
Word_Wrap_Iterator :: struct {
	s:               string,
	max_width:       int,
	offset:          int,
	remaining_width: int, // cached display width of s[offset:], avoids O(n) rescan
}

/* word_wrap_iterator_make creates a Word_Wrap_Iterator. If max_width <= 0,
	 the entire string is yielded as a single line (unlimited). */
word_wrap_iterator_make :: proc(s: string, max_width: int) -> Word_Wrap_Iterator {
	return Word_Wrap_Iterator{s = s, max_width = max_width, remaining_width = display_width(s)}
}

/* word_wrap_iterate returns the next word-wrapped line, or ok=false when exhausted.
	 Deterministic: same input always yields the same sequence of lines. */
word_wrap_iterate :: proc(it: ^Word_Wrap_Iterator) -> (line: string, ok: bool) {
	if it.offset >= len(it.s) do return "", false

	remaining := it.s[it.offset:]

	if it.max_width <= 0 {
		it.offset = len(it.s)
		it.remaining_width = 0
		return remaining, true
	}

	if it.remaining_width <= it.max_width {
		it.offset = len(it.s)
		it.remaining_width = 0
		return remaining, true
	}

	// Walk graphemes to find break point at max_width.
	git := utf8.decode_grapheme_iterator_make(remaining)
	acc_width := 0
	byte_end := len(remaining)
	last_space_byte := -1
	last_space_width := 0 // accumulated width at last space

	for _, grapheme in utf8.decode_grapheme_iterate(&git) {
		if acc_width + grapheme.width > it.max_width {
			byte_end = grapheme.byte_index
			break
		}
		if grapheme.byte_index < len(remaining) && remaining[grapheme.byte_index] == ' ' {
			last_space_byte = grapheme.byte_index
			last_space_width = acc_width
		}
		acc_width += grapheme.width
	}

	// Ensure forward progress when first grapheme exceeds max_width.
	if byte_end == 0 {
		byte_end = first_grapheme_size(remaining)
	}

	if last_space_byte > 0 {
		line = remaining[:last_space_byte]
		it.offset += last_space_byte + 1 // skip space
		skipped := 1
		// Skip leading spaces on next line.
		for it.offset < len(it.s) && it.s[it.offset] == ' ' {
			it.offset += 1
			skipped += 1
		}
		it.remaining_width -= last_space_width + skipped
	} else {
		line = remaining[:byte_end]
		it.offset += byte_end
		// acc_width covers graphemes before byte_end; for forced first-grapheme break
		// (byte_end was 0, bumped to first_grapheme_size), acc_width = 0 — use display_width.
		line_width := acc_width if acc_width > 0 else display_width(line)
		it.remaining_width -= line_width
		// Skip leading spaces on next line.
		for it.offset < len(it.s) && it.s[it.offset] == ' ' {
			it.offset += 1
			it.remaining_width -= 1
		}
	}

	return line, true
}

/* word_wrap splits a string into lines of at most max_width display columns,
	 breaking at word boundaries (spaces). Convenience wrapper around
	 Word_Wrap_Iterator. Returns a temp-allocated slice of string slices into
	 the original string — no string allocation. */
word_wrap :: proc(s: string, max_width: int) -> []string {
	it := word_wrap_iterator_make(s, max_width)
	lines := make([dynamic]string, 0, 4, context.temp_allocator)
	for line in word_wrap_iterate(&it) {
		append(&lines, line)
	}
	if len(lines) == 0 {
		result := make([]string, 1, context.temp_allocator)
		result[0] = s
		return result
	}
	return lines[:]
}

/* Iterator that yields lines of at most max_width display columns.
	 Each yielded line is a slice of the original string — zero allocation. */
Wrap_Iterator :: struct {
	s:         string,
	max_width: int,
	offset:    int,
}

/* wrap_iterator_make creates a Wrap_Iterator. If max_width <= 0, the
	 entire string is yielded as a single line (unlimited). */
wrap_iterator_make :: proc(s: string, max_width: int) -> Wrap_Iterator {
	return Wrap_Iterator{s = s, max_width = max_width}
}

/* wrap_iterate returns the next wrapped line, or ok=false when exhausted. */
wrap_iterate :: proc(it: ^Wrap_Iterator) -> (line: string, ok: bool) {
	if it.offset >= len(it.s) do return "", false

	remaining := it.s[it.offset:]

	if it.max_width <= 0 {
		it.offset = len(it.s)
		return remaining, true
	}

	git := utf8.decode_grapheme_iterator_make(remaining)
	acc_width := 0
	byte_end := len(remaining)

	for _, grapheme in utf8.decode_grapheme_iterate(&git) {
		if acc_width + grapheme.width > it.max_width {
			byte_end = grapheme.byte_index
			break
		}
		acc_width += grapheme.width
	}

	// Ensure forward progress when first grapheme exceeds max_width.
	if byte_end == 0 {
		byte_end = first_grapheme_size(remaining)
	}

	line = remaining[:byte_end]
	it.offset += byte_end
	return line, true
}

// first_grapheme_size returns the byte size of the first grapheme cluster in s.
@(private = "file")
first_grapheme_size :: proc(s: string) -> int {
	it := utf8.decode_grapheme_iterator_make(s)
	for _, _ in utf8.decode_grapheme_iterate(&it) {
		break // consume first grapheme
	}
	for _, g in utf8.decode_grapheme_iterate(&it) {
		return g.byte_index // start of second = end of first
	}
	return len(s) // only one grapheme
}
