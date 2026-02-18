package bench

import "../tree"
import "base:runtime"
import "core:fmt"

Tree_Bench_Data :: struct {
	shallow_builder:  tree.Tree_Builder,
	shallow_tree:     tree.Tree,
	deep_builder:     tree.Tree_Builder,
	deep_tree:        tree.Tree,
	balanced_builder: tree.Tree_Builder,
	balanced_tree:    tree.Tree,
	arena:            runtime.Arena,
}

tree_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "tree/shallow_wide (1x50)",
			iterations = 10_000,
			bench_proc = bench_tree_shallow,
			setup      = tree_setup,
			teardown   = tree_teardown,
		},
		{
			name       = "tree/deep_narrow (10x1)",
			iterations = 10_000,
			bench_proc = bench_tree_deep,
			setup      = tree_setup,
			teardown   = tree_teardown,
		},
		{
			name       = "tree/balanced (4x5)",
			iterations = 1_000,
			bench_proc = bench_tree_balanced,
			setup      = tree_setup,
			teardown   = tree_teardown,
		},
	}
	return scenarios[:]
}

@(private = "file")
tree_setup :: proc() -> rawptr {
	data := new(Tree_Bench_Data)
	alloc := runtime.arena_allocator(&data.arena)

	// Shallow wide: 1 level, 50 children
	data.shallow_builder = tree.make_builder("Root")
	for i in 0 ..< 50 {
		tree.add(&data.shallow_builder, fmt.aprintf("Child %d", i, allocator = alloc))
	}
	data.shallow_tree = tree.build(&data.shallow_builder)

	// Deep narrow: 10 levels, 1 child each
	data.deep_builder = tree.make_builder("Level 0")
	parent := &data.deep_builder
	for i in 1 ..< 10 {
		parent = tree.add_tree(parent, fmt.aprintf("Level %d", i, allocator = alloc))
	}
	tree.add(parent, "Leaf")
	data.deep_tree = tree.build(&data.deep_builder)

	// Balanced: 4 levels, 5 children each (~155 nodes)
	data.balanced_builder = tree.make_builder("Root")
	populate_balanced(&data.balanced_builder, 4, 5, 1, alloc)
	data.balanced_tree = tree.build(&data.balanced_builder)

	return data
}

@(private = "file")
populate_balanced :: proc(b: ^tree.Tree_Builder, depth: int, breadth: int, current_depth: int, alloc: runtime.Allocator) {
	if current_depth >= depth {
		for i in 0 ..< breadth {
			tree.add(b, fmt.aprintf("Leaf %d-%d", current_depth, i, allocator = alloc))
		}
		return
	}
	for i in 0 ..< breadth {
		child := tree.add_tree(b, fmt.aprintf("Node %d-%d", current_depth, i, allocator = alloc))
		populate_balanced(child, depth, breadth, current_depth + 1, alloc)
	}
}

@(private = "file")
tree_teardown :: proc(user_data: rawptr) {
	data := (^Tree_Bench_Data)(user_data)
	tree.destroy_builder(&data.shallow_builder)
	tree.destroy_builder(&data.deep_builder)
	tree.destroy_builder(&data.balanced_builder)
	runtime.arena_destroy(&data.arena)
	free(data)
}

@(private = "file")
bench_tree_shallow :: proc(state: ^Bench_State) {
	data := (^Tree_Bench_Data)(state.user_data)
	tree.to_writer(state.writer, data.shallow_tree, mode = .Plain)
}

@(private = "file")
bench_tree_deep :: proc(state: ^Bench_State) {
	data := (^Tree_Bench_Data)(state.user_data)
	tree.to_writer(state.writer, data.deep_tree, mode = .Plain)
}

@(private = "file")
bench_tree_balanced :: proc(state: ^Bench_State) {
	data := (^Tree_Bench_Data)(state.user_data)
	tree.to_writer(state.writer, data.balanced_tree, mode = .Plain)
}
