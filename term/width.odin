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

	line = remaining[:byte_end]
	it.offset += byte_end
	return line, true
}
