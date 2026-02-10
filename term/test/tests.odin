package term_test

import term ".."
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
