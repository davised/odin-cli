package term

import "core:unicode/utf8"

ELLIPSIS :: "…"

/* display_width returns the monospace terminal cell width of a string.
	 Handles CJK/fullwidth (2 cols), combining marks (0 cols), emoji, etc. */
display_width :: proc(s: string) -> int {
	_, _, w := utf8.grapheme_count(s)
	return w
}

/* truncate truncates a string to fit within max_width display columns,
	 appending an ellipsis if truncation occurs. Returns the original string
	 when it fits or when max_width is 0 (unlimited). */
truncate :: proc(s: string, max_width: int, allocator := context.temp_allocator) -> string {
	if max_width <= 0 do return s

	_, _, total_width := utf8.grapheme_count(s)
	if total_width <= max_width do return s
	if max_width <= 1 do return ELLIPSIS

	budget := max_width - 1 // reserve 1 column for ellipsis
	it := utf8.decode_grapheme_iterator_make(s)
	acc_width := 0
	byte_end := len(s)

	for _, grapheme in utf8.decode_grapheme_iterate(&it) {
		if acc_width + grapheme.width > budget {
			// This grapheme's byte_index is the start of the cluster
			// that doesn't fit — i.e. the byte end of what DOES fit.
			byte_end = grapheme.byte_index
			break
		}
		acc_width += grapheme.width
	}

	buf := make([]u8, byte_end + len(ELLIPSIS), allocator)
	copy(buf[:byte_end], s[:byte_end])
	copy(buf[byte_end:], ELLIPSIS)
	return string(buf)
}

/* Word_Wrap_Iterator yields lines of at most max_width display columns,
	 breaking at word boundaries (spaces). Falls back to character-level
	 breaking when a single word exceeds max_width. Each yielded line is a
	 slice of the original string — zero allocation. */
Word_Wrap_Iterator :: struct {
	s:         string,
	max_width: int,
	offset:    int,
}

/* word_wrap_iterator_make creates a Word_Wrap_Iterator. If max_width <= 0,
	 the entire string is yielded as a single line (unlimited). */
word_wrap_iterator_make :: proc(s: string, max_width: int) -> Word_Wrap_Iterator {
	return Word_Wrap_Iterator{s = s, max_width = max_width}
}

/* word_wrap_iterate returns the next word-wrapped line, or ok=false when exhausted.
	 Deterministic: same input always yields the same sequence of lines. */
word_wrap_iterate :: proc(it: ^Word_Wrap_Iterator) -> (line: string, ok: bool) {
	if it.offset >= len(it.s) do return "", false

	remaining := it.s[it.offset:]

	if it.max_width <= 0 {
		it.offset = len(it.s)
		return remaining, true
	}

	rem_w := display_width(remaining)
	if rem_w <= it.max_width {
		it.offset = len(it.s)
		return remaining, true
	}

	// Walk graphemes to find break point at max_width.
	git := utf8.decode_grapheme_iterator_make(remaining)
	acc_width := 0
	byte_end := len(remaining)
	last_space_byte := -1

	for _, grapheme in utf8.decode_grapheme_iterate(&git) {
		if acc_width + grapheme.width > it.max_width {
			byte_end = grapheme.byte_index
			break
		}
		if grapheme.byte_index < len(remaining) && remaining[grapheme.byte_index] == ' ' {
			last_space_byte = grapheme.byte_index
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
	} else {
		line = remaining[:byte_end]
		it.offset += byte_end
	}

	// Skip leading spaces on next line.
	for it.offset < len(it.s) && it.s[it.offset] == ' ' {
		it.offset += 1
	}

	return line, true
}

/* word_wrap splits a string into lines of at most max_width display columns,
	 breaking at word boundaries (spaces). Convenience wrapper around
	 Word_Wrap_Iterator. Returns a temp-allocated slice of string slices into
	 the original string — no string allocation. */
word_wrap :: proc(s: string, max_width: int) -> []string {
	it := Word_Wrap_Iterator{s = s, max_width = max_width}
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
