package term

/*
contains_ansi reports whether s contains any ESC (`0x1B`) bytes, which may
indicate ANSI escape sequences. Useful for short-circuiting sanitization or
display-width calculations.
*/
contains_ansi :: proc(s: string) -> bool {
	for b in transmute([]u8)s {
		if b == 0x1b do return true
	}
	return false
}

/*
strip_ansi removes all ANSI escape sequences from s, returning a clean string.
Returns the original string without allocation when no ESC bytes are present.
Use this to sanitize untrusted input before passing to rendering procs
(style, table, tree, etc.) which write text content verbatim.

Handles CSI (e.g. `\e[31m`), OSC (e.g. `\e]0;title\a`), nF (e.g. `\e(B`),
and Fp/Fe/Fs two-byte escape sequences.

*Allocates Using Provided Allocator* (only when ANSI sequences are present)

Inputs:
- s: The string to strip.
- allocator: (default: context.temp_allocator)

Returns:
- A new string with all ANSI escape sequences removed, or the original string if none were found.
*/
strip_ansi :: proc(s: string, allocator := context.temp_allocator) -> string {
	if !contains_ansi(s) do return s

	bytes := transmute([]u8)s
	buf := make([]u8, len(s), allocator)
	pos := 0
	i := 0
	for i < len(bytes) {
		if bytes[i] == 0x1b {
			i += skip_ansi_sequence(bytes, i)
		} else {
			buf[pos] = bytes[i]
			pos += 1
			i += 1
		}
	}

	return string(buf[:pos])
}

// display_width_ansi computes display width of a string containing ANSI escape
// sequences by splitting into non-ANSI segments and summing their widths.
// Segments are guaranteed ANSI-free so display_width takes the optimal path.
@(private)
display_width_ansi :: proc(s: string) -> int {
	bytes := transmute([]u8)s
	total := 0
	seg_start := 0
	i := 0

	for i < len(bytes) {
		if bytes[i] == 0x1b {
			if i > seg_start {
				total += display_width(s[seg_start:i])
			}
			i += skip_ansi_sequence(bytes, i)
			seg_start = i
		} else {
			i += 1
		}
	}

	if seg_start < len(bytes) {
		total += display_width(s[seg_start:])
	}

	return total
}

// skip_ansi_sequence returns the byte count of an ANSI escape sequence starting
// at bytes[start]. Assumes bytes[start] == 0x1b.
//
// Handles per ECMA-48:
// - CSI: ESC [ <params 0x30-0x3F>* <intermediates 0x20-0x2F>* <final 0x40-0x7E>
// - OSC: ESC ] <text> (BEL | ST)
// - nF:  ESC <0x20-0x2F>+ <final 0x30-0x7E> (e.g. ESC ( B select charset)
// - Fp:  ESC <0x30-0x3F> (private, e.g. ESC 7 save cursor)
// - Fe:  ESC <0x40-0x5F> (C1 control, e.g. ESC M reverse index)
// - Fs:  ESC <0x60-0x7E> (standardized, e.g. ESC c full reset)
// - Bare ESC at end of string: returns 1
@(private)
skip_ansi_sequence :: proc(bytes: []u8, start: int) -> int {
	if start + 1 >= len(bytes) do return 1

	next := bytes[start + 1]

	// CSI: ESC [ ... final_byte(0x40-0x7E)
	if next == '[' {
		i := start + 2
		for i < len(bytes) {
			b := bytes[i]
			if b >= 0x40 && b <= 0x7E {
				return i - start + 1
			}
			i += 1
		}
		return len(bytes) - start // unterminated CSI
	}

	// OSC: ESC ] ... BEL(0x07) or ST(ESC \ or 0x9C)
	if next == ']' {
		i := start + 2
		for i < len(bytes) {
			if bytes[i] == 0x07 || bytes[i] == 0x9C {
				return i - start + 1
			}
			if bytes[i] == 0x1b && i + 1 < len(bytes) && bytes[i + 1] == '\\' {
				return i - start + 2
			}
			i += 1
		}
		return len(bytes) - start // unterminated OSC
	}

	// nF escape: ESC <intermediate 0x20-0x2F>+ <final 0x30-0x7E>
	if next >= 0x20 && next <= 0x2F {
		i := start + 2
		for i < len(bytes) && bytes[i] >= 0x20 && bytes[i] <= 0x2F {
			i += 1 // skip additional intermediates
		}
		if i < len(bytes) && bytes[i] >= 0x30 && bytes[i] <= 0x7E {
			return i - start + 1 // include final byte
		}
		return i - start // unterminated nF
	}

	// Fp (0x30-0x3F), Fe (0x40-0x5F), Fs (0x60-0x7E): 2-byte sequences
	if next >= 0x30 && next <= 0x7E {
		return 2
	}

	return 1 // unrecognized; skip bare ESC
}
