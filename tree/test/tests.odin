package tree_test

import "core:testing"
import "core:strings"
import "core:time"
import tree ".."
import style "../../style"

@(test)
test_flat_tree :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	children := [?]tree.Tree_Item{"src", "README.md", "Makefile"}
	tr := tree.Tree{root = "my-project", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `my-project
├── src
├── README.md
└── Makefile
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_nested_tree :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	gc := [?]tree.Tree_Item{"main.odin", "utils.odin"}
	src := tree.Tree{root = "src", children = gc[:]}
	children := [?]tree.Tree_Item{&src, "README.md"}
	tr := tree.Tree{root = "my-project", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `my-project
├── src
│   ├── main.odin
│   └── utils.odin
└── README.md
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_single_child :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	children := [?]tree.Tree_Item{"only-child"}
	tr := tree.Tree{root = "parent", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `parent
└── only-child
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_root_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	tr := tree.Tree{root = "just-root"}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := "just-root\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_empty_tree :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	tr := tree.Tree{}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")
	testing.expect_value(t, strings.to_string(sb), "")
}

@(test)
test_forest :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	children := [?]tree.Tree_Item{"Item 1", "Item 2", "Item 3"}
	tr := tree.Tree{children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `├── Item 1
├── Item 2
└── Item 3
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_styled_items :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	styled_child := style.bold("hello")
	children := [?]tree.Tree_Item{styled_child}
	tr := tree.Tree{root = "root", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	output := strings.to_string(sb)
	// Should contain the ANSI bold code (\x1b[1m) and reset (\x1b[0m)
	testing.expect(t, strings.contains(output, "\x1b[1m"), "expected bold ANSI code")
	testing.expect(t, strings.contains(output, "hello"), "expected text content")
	testing.expect(t, strings.contains(output, "\x1b[0m"), "expected reset code")
	testing.expect(t, strings.has_prefix(output, "root\n"), "expected root line")
}

@(test)
test_ascii_enumerator :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	gc := [?]tree.Tree_Item{"child1"}
	sub := tree.Tree{root = "sub", children = gc[:]}
	children := [?]tree.Tree_Item{&sub, "last"}
	tr := tree.Tree{root = "root", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr, tree.ASCII_ENUMERATOR)
	testing.expect(t, ok, "to_writer failed")

	expected := "root\n|-- sub\n|   `-- child1\n`-- last\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_rounded_enumerator :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	children := [?]tree.Tree_Item{"first", "middle", "last"}
	tr := tree.Tree{root = "root", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr, tree.ROUNDED_ENUMERATOR)
	testing.expect(t, ok, "to_writer failed")

	expected := `root
├── first
├── middle
╰── last
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_to_str :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	children := [?]tree.Tree_Item{"a", "b"}
	tr := tree.Tree{root = "root", children = children[:]}

	result, ok := tree.to_str(tr)
	defer delete(result)
	testing.expect(t, ok, "to_str failed")

	expected := `root
├── a
└── b
`
	testing.expect_value(t, result, expected)
}

@(test)
test_mixed_items :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	gc := [?]tree.Tree_Item{"nested-child"}
	sub := tree.Tree{root = "subtree", children = gc[:]}
	styled := style.red("colored")
	children := [?]tree.Tree_Item{"plain", styled, &sub}
	tr := tree.Tree{root = "mix", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	output := strings.to_string(sb)
	// Verify structure
	testing.expect(t, strings.has_prefix(output, "mix\n"), "expected root line")
	testing.expect(t, strings.contains(output, "├── plain\n"), "expected plain child")
	testing.expect(t, strings.contains(output, "colored"), "expected styled text content")
	testing.expect(t, strings.contains(output, "subtree"), "expected subtree root")
	testing.expect(t, strings.contains(output, "nested-child"), "expected nested child")
}

@(test)
test_deep_nesting :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// 3 levels deep with siblings to exercise branch vs padding prefixes
	leaf := [?]tree.Tree_Item{"leaf"}
	deep := tree.Tree{root = "deep", children = leaf[:]}
	mid_children := [?]tree.Tree_Item{&deep, "sibling"}
	mid := tree.Tree{root = "mid", children = mid_children[:]}
	top_children := [?]tree.Tree_Item{&mid, "other"}
	tr := tree.Tree{root = "root", children = top_children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := "root\n" +
		"├── mid\n" +
		"│   ├── deep\n" +
		"│   │   └── leaf\n" +
		"│   └── sibling\n" +
		"└── other\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_subtree_enumerator_override :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Subtree uses rounded enumerator while parent uses default
	rounded := tree.ROUNDED_ENUMERATOR
	sub_children := [?]tree.Tree_Item{"a", "b"}
	sub := tree.Tree{root = "sub", children = sub_children[:], enumerator = &rounded}
	top_children := [?]tree.Tree_Item{&sub, "c"}
	tr := tree.Tree{root = "root", children = top_children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := "root\n" +
		"├── sub\n" +
		"│   ├── a\n" +
		"│   ╰── b\n" +
		"└── c\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_width_wrapping :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Long labels with width=20.
	// Connector "├── " / "└── " = 4 display cols each.
	// Content budget for depth-0 children = 20 - 4 = 16.
	children := [?]tree.Tree_Item{"very-long-filename.odin", "short"}
	tr := tree.Tree{root = "my-long-project-name", children = children[:], width = 20}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	// Root is unconstrained. "very-long-filename.odin" (23) wraps at 16:
	//   first line  "very-long-filena" (16)
	//   cont line   "me.odin" (7) with branch prefix "│   "
	// "short" (5) fits in 16.
	expected := "my-long-project-name\n" +
		"├── very-long-filena\n" +
		"│   me.odin\n" +
		"└── short\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_width_deep_nesting :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// 2-level deep tree with width=20.
	// Depth-1 child: prefix "    "(4) + connector "└── "(4) → budget = 20-4-4 = 12.
	leaf := [?]tree.Tree_Item{"deep-nested-label"}
	mid := tree.Tree{root = "mid", children = leaf[:]}
	top := [?]tree.Tree_Item{&mid}
	tr := tree.Tree{root = "root", children = top[:], width = 20}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	// "deep-nested-label" (17) wraps at 12:
	//   first line  "deep-nested-" (12)
	//   cont line   prefix "    " + cont "    " + "label" (5)
	expected := "root\n" +
		"└── mid\n" +
		"    └── deep-nested-\n" +
		"        label\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_width_zero_unlimited :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// width=0 (default) should produce the same output as before — no wrapping.
	children := [?]tree.Tree_Item{"very-long-filename.odin", "another-long-file.txt"}
	tr := tree.Tree{root = "my-project", children = children[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := "my-project\n" +
		"├── very-long-filename.odin\n" +
		"└── another-long-file.txt\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}
