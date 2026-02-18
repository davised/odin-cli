package term_test

import term ".."
import "core:strings"
import "core:testing"
import "core:time"

@(test)
test_display_width_ascii :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	testing.expect_value(t, term.display_width("hello"), 5)
	testing.expect_value(t, term.display_width(""), 0)
	testing.expect_value(t, term.display_width("abc123"), 6)
	testing.expect_value(t, term.display_width(" "), 1)
}

@(test)
test_display_width_cjk :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	testing.expect_value(t, term.display_width("你好"), 4)
	testing.expect_value(t, term.display_width("世界"), 4)
	testing.expect_value(t, term.display_width("中"), 2)
}

@(test)
test_display_width_mixed :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	testing.expect_value(t, term.display_width("hi你好"), 6)
	testing.expect_value(t, term.display_width("a中b"), 4)
}

@(test)
test_display_width_combining :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// e + combining acute accent = 1 grapheme, 1 column
	testing.expect_value(t, term.display_width("e\u0301"), 1)
	// cafe with combining accent on the e
	testing.expect_value(t, term.display_width("caf\u0065\u0301"), 4)
}

@(test)
test_truncate_no_op :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// String fits — no truncation
	testing.expect_value(t, term.truncate("hello", 10), "hello")
	testing.expect_value(t, term.truncate("hello", 5), "hello")
	// max_width=0 means unlimited
	testing.expect_value(t, term.truncate("hello", 0), "hello")
}

@(test)
test_truncate_ascii :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	testing.expect_value(t, term.truncate("hello", 4), "hel…")
	testing.expect_value(t, term.truncate("hello", 3), "he…")
	testing.expect_value(t, term.truncate("hello", 2), "h…")
	testing.expect_value(t, term.truncate("hello", 1), "…")
}

@(test)
test_truncate_cjk :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// "你好" is 4 cols wide
	// max_width=4: fits, no truncation
	testing.expect_value(t, term.truncate("你好", 4), "你好")
	// max_width=3: budget=2, '你' is 2 cols -> fits, '好' would be 4 > 2 -> stop
	testing.expect_value(t, term.truncate("你好", 3), "你…")
	// max_width=2: budget=1, '你' is 2 cols > 1 -> nothing fits
	testing.expect_value(t, term.truncate("你好", 2), "…")
	testing.expect_value(t, term.truncate("你好", 1), "…")
}

@(test)
test_truncate_mixed :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// "hi你好" is 6 cols
	testing.expect_value(t, term.truncate("hi你好", 6), "hi你好")
	testing.expect_value(t, term.truncate("hi你好", 5), "hi你…")
	// max_width=4: budget=3, h(1)+i(1)=2, 你(2) would exceed → "hi…"
	testing.expect_value(t, term.truncate("hi你好", 4), "hi…")
	testing.expect_value(t, term.truncate("hi你好", 3), "hi…")
}

@(test)
test_truncate_preserves_graphemes :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// "café" with combining accent: c(1) a(1) f(1) é(1) = 4 cols
	s := "caf\u0065\u0301"
	testing.expect_value(t, term.truncate(s, 4), s)
	// Truncate to 3: budget=2, c(1)+a(1)=2, f would be 3 > 2
	testing.expect_value(t, term.truncate(s, 3), "ca…")
}

@(test)
test_truncate_boundary_cases :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Exact fit — no truncation
	testing.expect_value(t, term.truncate("abcde", 5), "abcde")
	// One over — truncation
	testing.expect_value(t, term.truncate("abcdef", 5), "abcd…")
	// Negative max_width treated as unlimited
	testing.expect_value(t, term.truncate("hello", -1), "hello")
	// CJK boundary: "你好世" = 6 cols, max_width=5 → budget=4, "你好"=4 fits, "世" would exceed
	testing.expect_value(t, term.truncate("你好世", 5), "你好…")
	// CJK boundary: max_width=4 → budget=3, "你"=2 fits, "好"=4 would exceed
	testing.expect_value(t, term.truncate("你好世", 4), "你…")
}

@(test)
test_truncate_long_string :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// 200-char ASCII truncated to 5 — verifies early exit
	long := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"
	result := term.truncate(long, 5)
	testing.expect_value(t, result, "abcd…")
	testing.expect_value(t, term.display_width(result), 5)
}

// --- Wrap iterator tests ---

@(test)
test_wrap_ascii :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	it := term.wrap_iterator_make("hello world", 5)

	line1, ok1 := term.wrap_iterate(&it)
	testing.expect(t, ok1, "expected first line")
	testing.expect_value(t, line1, "hello")

	line2, ok2 := term.wrap_iterate(&it)
	testing.expect(t, ok2, "expected second line")
	testing.expect_value(t, line2, " worl")

	line3, ok3 := term.wrap_iterate(&it)
	testing.expect(t, ok3, "expected third line")
	testing.expect_value(t, line3, "d")

	_, ok4 := term.wrap_iterate(&it)
	testing.expect(t, !ok4, "expected end")
}

@(test)
test_wrap_cjk :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// "你好世界" = 8 cols, wrap at 5
	// '你'(2)+'好'(2)=4, '世'(2) would be 6>5 → first line "你好"
	// '世'(2)+'界'(2)=4 ≤ 5 → second line "世界"
	it := term.wrap_iterator_make("你好世界", 5)

	line1, ok1 := term.wrap_iterate(&it)
	testing.expect(t, ok1, "expected first line")
	testing.expect_value(t, line1, "你好")

	line2, ok2 := term.wrap_iterate(&it)
	testing.expect(t, ok2, "expected second line")
	testing.expect_value(t, line2, "世界")

	_, ok3 := term.wrap_iterate(&it)
	testing.expect(t, !ok3, "expected end")
}

@(test)
test_wrap_fits :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// String fits in one line — single iteration
	it := term.wrap_iterator_make("hi", 10)

	line, ok := term.wrap_iterate(&it)
	testing.expect(t, ok, "expected line")
	testing.expect_value(t, line, "hi")

	_, ok2 := term.wrap_iterate(&it)
	testing.expect(t, !ok2, "expected end")
}

@(test)
test_wrap_unlimited :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// max_width=0 yields entire string
	it := term.wrap_iterator_make("hello world", 0)

	line, ok := term.wrap_iterate(&it)
	testing.expect(t, ok, "expected line")
	testing.expect_value(t, line, "hello world")

	_, ok2 := term.wrap_iterate(&it)
	testing.expect(t, !ok2, "expected end")
}

@(test)
test_wrap_empty :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	it := term.wrap_iterator_make("", 5)

	_, ok := term.wrap_iterate(&it)
	testing.expect(t, !ok, "empty string yields nothing")
}

// --- Word wrap tests ---

@(test)
test_word_wrap_basic :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lines := term.word_wrap("hello world", 20)
	testing.expect_value(t, len(lines), 1)
	testing.expect_value(t, lines[0], "hello world")
}

@(test)
test_word_wrap_split :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lines := term.word_wrap("hello world", 7)
	testing.expect_value(t, len(lines), 2)
	testing.expect_value(t, lines[0], "hello")
	testing.expect_value(t, lines[1], "world")
}

@(test)
test_word_wrap_multi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lines := term.word_wrap("the quick brown fox jumps", 10)
	testing.expect_value(t, len(lines), 3)
	testing.expect_value(t, lines[0], "the quick")
	testing.expect_value(t, lines[1], "brown fox")
	testing.expect_value(t, lines[2], "jumps")
}

@(test)
test_word_wrap_long_word :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// A single word longer than max_width forces character break.
	lines := term.word_wrap("abcdefghij rest", 5)
	testing.expect(t, len(lines) >= 3, "long word should force character break")
	testing.expect_value(t, lines[0], "abcde")
	testing.expect_value(t, lines[1], "fghij")
	testing.expect_value(t, lines[2], "rest")
}

@(test)
test_word_wrap_exact_fit :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lines := term.word_wrap("hello", 5)
	testing.expect_value(t, len(lines), 1)
	testing.expect_value(t, lines[0], "hello")
}

@(test)
test_word_wrap_unlimited :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lines := term.word_wrap("hello world", 0)
	testing.expect_value(t, len(lines), 1)
	testing.expect_value(t, lines[0], "hello world")
}

@(test)
test_word_wrap_empty :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	lines := term.word_wrap("", 10)
	testing.expect_value(t, len(lines), 1)
	testing.expect_value(t, lines[0], "")
}

@(test)
test_word_wrap_long_text :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Long sentence wrapped at width 20 — verify all lines fit and content preserved.
	text := "the quick brown fox jumps over the lazy dog near the river bank"
	lines := term.word_wrap(text, 20)
	testing.expect(t, len(lines) >= 3, "long text should produce multiple lines")
	for line, i in lines {
		w := term.display_width(line)
		testing.expectf(t, w <= 20, "line %d width %d exceeds 20: '%s'", i, w, line)
	}
}

@(test)
test_word_wrap_preserves_content :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Rejoin all lines with spaces equals original (modulo leading/trailing).
	text := "hello world foo bar baz qux"
	lines := term.word_wrap(text, 10)

	// Rebuild by joining with spaces.
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	for line, i in lines {
		if i > 0 do strings.write_byte(&sb, ' ')
		strings.write_string(&sb, line)
	}
	testing.expect_value(t, strings.to_string(sb), text)
}

@(test)
test_word_wrap_cjk_narrow :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// CJK char (width 2) in column of width 1 — must not infinite loop.
	// The char should be force-included despite exceeding max_width.
	lines := term.word_wrap("你好", 1)
	testing.expect(t, len(lines) >= 2, "CJK in narrow column should produce multiple lines")
	testing.expect_value(t, lines[0], "你")
	testing.expect_value(t, lines[1], "好")
}

@(test)
test_wrap_cjk_narrow :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Character-level wrap with CJK in width=1 — must not infinite loop.
	it := term.wrap_iterator_make("你好", 1)

	line1, ok1 := term.wrap_iterate(&it)
	testing.expect(t, ok1, "expected first line")
	testing.expect_value(t, line1, "你")

	line2, ok2 := term.wrap_iterate(&it)
	testing.expect(t, ok2, "expected second line")
	testing.expect_value(t, line2, "好")

	_, ok3 := term.wrap_iterate(&it)
	testing.expect(t, !ok3, "expected end")
}

// --- ANSI detection tests ---

@(test)
test_contains_ansi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	testing.expect(t, !term.contains_ansi(""), "empty string has no ANSI")
	testing.expect(t, !term.contains_ansi("hello"), "plain ASCII has no ANSI")
	testing.expect(t, !term.contains_ansi("你好"), "CJK has no ANSI")
	testing.expect(t, term.contains_ansi("\x1b[31mred\x1b[0m"), "CSI is ANSI")
	testing.expect(t, term.contains_ansi("\x1b]0;title\x07"), "OSC is ANSI")
	testing.expect(t, term.contains_ansi("text\x1b"), "bare ESC is ANSI")
}

// --- strip_ansi tests ---

@(test)
test_strip_ansi_no_ansi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// No ANSI — returns original string (no allocation).
	testing.expect_value(t, term.strip_ansi("hello"), "hello")
	testing.expect_value(t, term.strip_ansi(""), "")
	testing.expect_value(t, term.strip_ansi("你好世界"), "你好世界")
}

@(test)
test_strip_ansi_csi :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Simple color codes
	s := term.strip_ansi("\x1b[31mhello\x1b[0m")
	testing.expect_value(t, s, "hello")

	// Bold + color
	s2 := term.strip_ansi("\x1b[1;31mbold red\x1b[0m")
	testing.expect_value(t, s2, "bold red")

	// Cursor movement (CSI H)
	s3 := term.strip_ansi("\x1b[2J\x1b[Htext")
	testing.expect_value(t, s3, "text")

	// Multiple CSI in sequence
	s4 := term.strip_ansi("\x1b[1m\x1b[31m\x1b[42mstyles\x1b[0m")
	testing.expect_value(t, s4, "styles")
}

@(test)
test_strip_ansi_osc :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// OSC with BEL terminator (set title)
	s := term.strip_ansi("\x1b]0;my title\x07visible")
	testing.expect_value(t, s, "visible")

	// OSC with ST terminator (ESC \)
	s2 := term.strip_ansi("\x1b]8;;https://example.com\x1b\\link\x1b]8;;\x1b\\")
	testing.expect_value(t, s2, "link")
}

@(test)
test_strip_ansi_fp :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Fp escape (0x30-0x3F): ESC 7 (save cursor) + ESC 8 (restore cursor)
	s := term.strip_ansi("\x1b7text\x1b8")
	testing.expect_value(t, s, "text")
}

@(test)
test_strip_ansi_fe :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Fe escape (0x40-0x5F): ESC D (index) + ESC M (reverse index)
	s := term.strip_ansi("\x1bDtext\x1bM")
	testing.expect_value(t, s, "text")
}

@(test)
test_strip_ansi_nf :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// nF escape: ESC ( B (select ASCII charset, 3 bytes)
	s := term.strip_ansi("\x1b(Btext")
	testing.expect_value(t, s, "text")

	// ESC ) 0 (select DEC special graphics for G1, 3 bytes)
	s2 := term.strip_ansi("before\x1b)0after")
	testing.expect_value(t, s2, "beforeafter")
}

@(test)
test_strip_ansi_bare_esc :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Bare ESC at end of string
	s := term.strip_ansi("text\x1b")
	testing.expect_value(t, s, "text")
}

@(test)
test_strip_ansi_unterminated :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Unterminated CSI — everything after ESC[ consumed
	s := term.strip_ansi("\x1b[31")
	testing.expect_value(t, s, "")

	// Unterminated OSC — everything after ESC] consumed
	s2 := term.strip_ansi("\x1b]no terminator")
	testing.expect_value(t, s2, "")
}

@(test)
test_strip_ansi_mixed :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// CSI + plain + OSC + Fe
	s := term.strip_ansi("\x1b[31mred\x1b[0m plain \x1b]0;t\x07\x1b7end\x1b8")
	testing.expect_value(t, s, "red plain end")
}

@(test)
test_strip_ansi_cjk :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	s := term.strip_ansi("\x1b[31m你好\x1b[0m世界")
	testing.expect_value(t, s, "你好世界")
}

// --- ANSI-aware display_width tests ---

@(test)
test_display_width_ansi_simple :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Red "hello" — 5 visible columns
	testing.expect_value(t, term.display_width("\x1b[31mhello\x1b[0m"), 5)
	// Bold + color
	testing.expect_value(t, term.display_width("\x1b[1;31mbold\x1b[0m"), 4)
	// Bare text with reset at end
	testing.expect_value(t, term.display_width("text\x1b[0m"), 4)
}

@(test)
test_display_width_ansi_multiple :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Multiple styled segments: "hello" + " " + "world" = 11
	s := "\x1b[1;31mhello\x1b[0m \x1b[32mworld\x1b[0m"
	testing.expect_value(t, term.display_width(s), 11)
}

@(test)
test_display_width_ansi_cjk :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Red CJK — 4 visible columns
	testing.expect_value(t, term.display_width("\x1b[31m你好\x1b[0m"), 4)
	// Mixed: ASCII + ANSI + CJK
	testing.expect_value(t, term.display_width("hi\x1b[31m你好\x1b[0m"), 6)
}

@(test)
test_display_width_ansi_osc :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// OSC hyperlink around "click" — 5 visible columns
	s := "\x1b]8;;https://example.com\x07click\x1b]8;;\x07"
	testing.expect_value(t, term.display_width(s), 5)
}

@(test)
test_display_width_ansi_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Pure ANSI with no visible content
	testing.expect_value(t, term.display_width("\x1b[31m\x1b[0m"), 0)
	testing.expect_value(t, term.display_width("\x1b[2J\x1b[H"), 0)
}

@(test)
test_display_width_ansi_bare_esc :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Bare ESC at end — zero width for the ESC byte
	testing.expect_value(t, term.display_width("text\x1b"), 4)
}
