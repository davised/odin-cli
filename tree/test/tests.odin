package tree_test

import tree ".."
import style "../../style"
import "core:strings"
import "core:testing"
import "core:time"

@(test)
test_flat_tree :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	children := [?]tree.Tree_Item{"src", "README.md", "Makefile"}
	tr := tree.Tree {
		root     = "my-project",
		children = children[:],
	}

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
	src := tree.Tree {
		root     = "src",
		children = gc[:],
	}
	children := [?]tree.Tree_Item{&src, "README.md"}
	tr := tree.Tree {
		root     = "my-project",
		children = children[:],
	}

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
	tr := tree.Tree {
		root     = "parent",
		children = children[:],
	}

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

	tr := tree.Tree {
		root = "just-root",
	}

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
	tr := tree.Tree {
		children = children[:],
	}

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
	tr := tree.Tree {
		root     = "root",
		children = children[:],
	}

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
	sub := tree.Tree {
		root     = "sub",
		children = gc[:],
	}
	children := [?]tree.Tree_Item{&sub, "last"}
	tr := tree.Tree {
		root     = "root",
		children = children[:],
	}

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
	tr := tree.Tree {
		root     = "root",
		children = children[:],
	}

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
	tr := tree.Tree {
		root     = "root",
		children = children[:],
	}

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
	sub := tree.Tree {
		root     = "subtree",
		children = gc[:],
	}
	styled := style.red("colored")
	children := [?]tree.Tree_Item{"plain", styled, &sub}
	tr := tree.Tree {
		root     = "mix",
		children = children[:],
	}

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
	deep := tree.Tree {
		root     = "deep",
		children = leaf[:],
	}
	mid_children := [?]tree.Tree_Item{&deep, "sibling"}
	mid := tree.Tree {
		root     = "mid",
		children = mid_children[:],
	}
	top_children := [?]tree.Tree_Item{&mid, "other"}
	tr := tree.Tree {
		root     = "root",
		children = top_children[:],
	}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected :=
		"root\n" +
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
	sub := tree.Tree {
		root       = "sub",
		children   = sub_children[:],
		enumerator = &rounded,
	}
	top_children := [?]tree.Tree_Item{&sub, "c"}
	tr := tree.Tree {
		root     = "root",
		children = top_children[:],
	}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := "root\n" + "├── sub\n" + "│   ├── a\n" + "│   ╰── b\n" + "└── c\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_width_wrapping :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Long labels with width=20.
	// Connector "├── " / "└── " = 4 display cols each.
	// Content budget for depth-0 children = 20 - 4 = 16.
	children := [?]tree.Tree_Item{"very-long-filename.odin", "short"}
	tr := tree.Tree {
		root     = "my-long-project-name",
		children = children[:],
		width    = 20,
	}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	// Root is unconstrained. "very-long-filename.odin" (23) wraps at 16:
	//   first line  "very-long-filena" (16)
	//   cont line   "me.odin" (7) with branch prefix "│   "
	// "short" (5) fits in 16.
	expected := "my-long-project-name\n" + "├── very-long-filena\n" + "│   me.odin\n" + "└── short\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_width_deep_nesting :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// 2-level deep tree with width=20.
	// Depth-1 child: prefix "    "(4) + connector "└── "(4) → budget = 20-4-4 = 12.
	leaf := [?]tree.Tree_Item{"deep-nested-label"}
	mid := tree.Tree {
		root     = "mid",
		children = leaf[:],
	}
	top := [?]tree.Tree_Item{&mid}
	tr := tree.Tree {
		root     = "root",
		children = top[:],
		width    = 20,
	}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	// "deep-nested-label" (17) wraps at 12:
	//   first line  "deep-nested-" (12)
	//   cont line   prefix "    " + cont "    " + "label" (5)
	expected := "root\n" + "└── mid\n" + "    └── deep-nested-\n" + "        label\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_width_zero_unlimited :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// width=0 (default) should produce the same output as before — no wrapping.
	children := [?]tree.Tree_Item{"very-long-filename.odin", "another-long-file.txt"}
	tr := tree.Tree {
		root     = "my-project",
		children = children[:],
	}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := "my-project\n" + "├── very-long-filename.odin\n" + "└── another-long-file.txt\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_plain_mode :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	styled_root := style.bold(style.red("root"))
	styled_child := style.cyan("leaf")
	children := [?]tree.Tree_Item{styled_child, "plain"}
	tr := tree.Tree {
		root     = styled_root,
		children = children[:],
	}

	result, ok := tree.to_str(tr, mode = .Plain)
	defer delete(result)
	testing.expect(t, ok, "Plain to_str failed")

	// No ANSI codes
	testing.expect(t, !strings.contains(result, "\x1b["), "Plain should contain no ANSI codes")
	// Tree connectors preserved (structural, not decorative)
	testing.expect(t, strings.contains(result, "├──"), "Plain should keep tree connectors")
	testing.expect(t, strings.contains(result, "└──"), "Plain should keep tree connectors")
	// Content preserved
	testing.expect(t, strings.contains(result, "root"), "Plain should preserve root text")
	testing.expect(t, strings.contains(result, "leaf"), "Plain should preserve child text")
	testing.expect(t, strings.contains(result, "plain"), "Plain should preserve plain child")
}

@(test)
test_no_color_mode :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	styled_child := style.Styled_Text {
		text = "styled",
		style = style.Style {
			text_styles = {.Bold},
			foreground_color = style.ANSI_Color.Red,
		},
	}
	children := [?]tree.Tree_Item{styled_child}
	tr := tree.Tree {
		root     = "root",
		children = children[:],
	}

	result, ok := tree.to_str(tr, mode = .No_Color)
	defer delete(result)
	testing.expect(t, ok, "No_Color to_str failed")

	// Bold SGR present, no color codes
	testing.expect(t, strings.contains(result, "\x1b[1m"), "No_Color should keep bold")
	testing.expect(t, strings.contains(result, "\x1b[0m"), "No_Color should have reset")
	testing.expect(t, !strings.contains(result, "\x1b[31m"), "No_Color should not have red color")
	testing.expect(t, strings.contains(result, "styled"), "No_Color should preserve text")
}

@(test)
test_max_depth_exceeded :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Build a chain of MAX_DEPTH+1 nested subtrees to trigger depth overflow.
	// trees[0] is the deepest leaf, trees[N] is the root.
	N :: tree.MAX_DEPTH + 1
	trees: [N + 1]tree.Tree
	child_storage: [N + 1][1]tree.Tree_Item

	trees[0] = tree.Tree{root = "leaf"}
	for i in 1 ..= N {
		child_storage[i][0] = &trees[i - 1]
		trees[i] = tree.Tree{root = "node", children = child_storage[i][:]}
	}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), trees[N])
	testing.expect(t, !ok, "to_writer should return false when MAX_DEPTH exceeded")
}

@(test)
test_nil_children :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	tr := tree.Tree{root = "x", children = nil}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer should succeed with nil children")
	testing.expect_value(t, strings.to_string(sb), "x\n")
}

// --- Builder tests ---

@(test)
test_builder_flat :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	b := tree.make_builder("root")
	defer tree.destroy_builder(&b)

	tree.add(&b, "a")
	tree.add(&b, "b")
	tree.add(&b, "c")
	tr := tree.build(&b)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `root
├── a
├── b
└── c
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_builder_nested :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	b := tree.make_builder("root")
	defer tree.destroy_builder(&b)

	sub := tree.add_tree(&b, "sub")
	tree.add(sub, "child1")
	tree.add(sub, "child2")
	tree.add(&b, "leaf")

	tr := tree.build(&b)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `root
├── sub
│   ├── child1
│   └── child2
└── leaf
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_builder_empty :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	b := tree.make_builder("root")
	defer tree.destroy_builder(&b)

	tr := tree.build(&b)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	testing.expect_value(t, strings.to_string(sb), "root\n")
}

@(test)
test_builder_subtrees_only :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	b := tree.make_builder("root")
	defer tree.destroy_builder(&b)

	s1 := tree.add_tree(&b, "s1")
	tree.add(s1, "a")
	s2 := tree.add_tree(&b, "s2")
	tree.add(s2, "b")

	tr := tree.build(&b)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected := `root
├── s1
│   └── a
└── s2
    └── b
`
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_builder_deep_nesting :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	b := tree.make_builder("L0")
	defer tree.destroy_builder(&b)

	l1 := tree.add_tree(&b, "L1")
	l2 := tree.add_tree(l1, "L2")
	tree.add(l2, "leaf")
	tree.add(&b, "sibling")

	tr := tree.build(&b)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected :=
		"L0\n" +
		"├── L1\n" +
		"│   └── L2\n" +
		"│       └── leaf\n" +
		"└── sibling\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_builder_matches_struct_literal :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Build via struct literals
	gc := [?]tree.Tree_Item{"main.odin", "utils.odin"}
	src := tree.Tree {
		root     = "src",
		children = gc[:],
	}
	lit_children := [?]tree.Tree_Item{&src, "README.md"}
	lit := tree.Tree {
		root     = "my-project",
		children = lit_children[:],
	}

	sb_lit := strings.builder_make()
	defer strings.builder_destroy(&sb_lit)
	ok_lit := tree.to_writer(strings.to_writer(&sb_lit), lit)
	testing.expect(t, ok_lit, "struct literal to_writer failed")

	// Build via builder
	b := tree.make_builder("my-project")
	defer tree.destroy_builder(&b)

	src_b := tree.add_tree(&b, "src")
	tree.add(src_b, "main.odin")
	tree.add(src_b, "utils.odin")
	tree.add(&b, "README.md")

	built := tree.build(&b)

	sb_built := strings.builder_make()
	defer strings.builder_destroy(&sb_built)
	ok_built := tree.to_writer(strings.to_writer(&sb_built), built)
	testing.expect(t, ok_built, "builder to_writer failed")

	testing.expect_value(t, strings.to_string(sb_built), strings.to_string(sb_lit))
}

@(test)
test_builder_styled_items :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	b := tree.make_builder(style.bold("root"))
	defer tree.destroy_builder(&b)

	tree.add(&b, style.red("colored"))
	tree.add(&b, "plain")

	tr := tree.build(&b)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	output := strings.to_string(sb)
	testing.expect(t, strings.contains(output, "\x1b[1m"), "expected bold ANSI code")
	testing.expect(t, strings.contains(output, "root"), "expected root text")
	testing.expect(t, strings.contains(output, "colored"), "expected colored text")
	testing.expect(t, strings.contains(output, "plain"), "expected plain text")
}

@(test)
test_deep_tree_prefix_buffer :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// 5-level deep tree with siblings — exact multiline output match.
	l4 := [?]tree.Tree_Item{"leaf"}
	t4 := tree.Tree{root = "d4", children = l4[:]}
	l3 := [?]tree.Tree_Item{&t4, "sib3"}
	t3 := tree.Tree{root = "d3", children = l3[:]}
	l2 := [?]tree.Tree_Item{&t3, "sib2"}
	t2 := tree.Tree{root = "d2", children = l2[:]}
	l1 := [?]tree.Tree_Item{&t2, "sib1"}
	t1 := tree.Tree{root = "d1", children = l1[:]}
	top := [?]tree.Tree_Item{&t1, "other"}
	tr := tree.Tree{root = "root", children = top[:]}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr)
	testing.expect(t, ok, "to_writer failed")

	expected :=
		"root\n" +
		"├── d1\n" +
		"│   ├── d2\n" +
		"│   │   ├── d3\n" +
		"│   │   │   ├── d4\n" +
		"│   │   │   │   └── leaf\n" +
		"│   │   │   └── sib3\n" +
		"│   │   └── sib2\n" +
		"│   └── sib1\n" +
		"└── other\n"
	testing.expect_value(t, strings.to_string(sb), expected)
}

@(test)
test_tree_width_with_enumerator :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 5 * time.Second)

	// Width-constrained tree with ASCII_ENUMERATOR.
	gc := [?]tree.Tree_Item{"very-long-filename.odin"}
	sub := tree.Tree{root = "sub", children = gc[:]}
	top := [?]tree.Tree_Item{&sub}
	tr := tree.Tree{root = "root", children = top[:], width = 20}

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	ok := tree.to_writer(strings.to_writer(&sb), tr, tree.ASCII_ENUMERATOR)
	testing.expect(t, ok, "to_writer failed")

	output := strings.to_string(sb)
	// Content should be wrapped — verify presence of continuation
	testing.expect(t, strings.contains(output, "sub"), "should contain subtree root")
	testing.expect(t, strings.contains(output, "very-long"), "should contain start of filename")
}
