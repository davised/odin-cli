#+feature global-context
package tree

import "base:runtime"
import style "../style"

/*
Tree_Builder provides a mutable construction API for building trees
whose structure is determined at runtime.

The builder owns all heap memory for the tree it constructs. The Tree
returned by build is a borrowed view — its children slice points into
builder-owned storage. Call destroy_builder only after you are done
with the built Tree. A typical pattern uses defer:

	b := tree.make_builder("Servers")
	defer tree.destroy_builder(&b)

	web := tree.add_tree(&b, "web-01")
	tree.add(web, "CPU: 45%")
	tree.add(web, "Mem: 2.1G")

	db := tree.add_tree(&b, "db-01")
	tree.add(db, "CPU: 78%")

	t := tree.build(&b)
	fmt.println(t)
*/
Tree_Builder :: struct {
	root:       Tree_Root,
	items:      [dynamic]Tree_Item,
	pending:    [dynamic]Pending_Subtree,
	enumerator: ^Enumerator,
	width:      int,
	allocator:  runtime.Allocator,
}

/* Tracks a subtree builder and its position in the parent's children list. */
@(private = "file")
Pending_Subtree :: struct {
	index:   int,
	builder: ^Tree_Builder,
}

/*
make_builder creates a new mutable tree builder with the given root label.

Inputs:
	root: The root label (string or Styled_Text).
	allocator: Allocator for internal dynamic arrays and subtree nodes.

Returns:
	Tree_Builder ready for add/add_tree calls.
*/
make_builder :: proc(root: Tree_Root, allocator := context.allocator) -> Tree_Builder {
	return Tree_Builder {
		root      = root,
		items     = make([dynamic]Tree_Item, allocator),
		pending   = make([dynamic]Pending_Subtree, allocator),
		allocator = allocator,
	}
}

/*
add appends a leaf item (string or Styled_Text) to the builder's children.
Insertion order is preserved in the final tree.

Inputs:
	b: The builder to add to.
	item: The leaf content.
*/
add :: proc(b: ^Tree_Builder, item: Tree_Root) {
	switch i in item {
	case string:
		append(&b.items, Tree_Item(i))
	case style.Styled_Text:
		append(&b.items, Tree_Item(i))
	case:
		// nil — nothing to add
	}
}

/*
add_tree appends a subtree to the builder's children and returns a pointer
to its builder for further population. The subtree's position among siblings
is determined by insertion order.

Inputs:
	b: The parent builder.
	root: The subtree's root label.

Returns:
	Pointer to the new child builder. Valid until destroy_builder is called
	on the root builder.
*/
add_tree :: proc(b: ^Tree_Builder, root: Tree_Root) -> ^Tree_Builder {
	child := new(Tree_Builder, b.allocator)
	child^ = make_builder(root, b.allocator)

	// Insert a placeholder ^Tree at the current position.
	// build() will finalize it with the child builder's contents.
	placeholder := new(Tree, b.allocator)
	append(&b.items, Tree_Item(placeholder))

	append(&b.pending, Pending_Subtree {
		index   = len(b.items) - 1,
		builder = child,
	})

	return child
}

/*
build recursively finalizes the builder into an immutable Tree.
The returned Tree borrows memory owned by the builder — do not
call destroy_builder until you are done with the Tree.

Inputs:
	b: The builder to finalize.

Returns:
	An immutable Tree suitable for rendering with to_writer or fmt.println.
*/
build :: proc(b: ^Tree_Builder) -> Tree {
	// Finalize each pending subtree into its placeholder.
	for p in b.pending {
		built := build(p.builder)
		placeholder, ok := b.items[p.index].(^Tree)
		assert(ok, "tree builder: corrupted children array — expected ^Tree placeholder")
		placeholder^ = built
	}

	return Tree {
		root       = b.root,
		children   = b.items[:],
		enumerator = b.enumerator,
		width      = b.width,
	}
}

/*
destroy_builder frees all memory owned by the builder, including
nested subtree builders and their placeholder Tree nodes.
Call this after you are done rendering the built Tree.

Inputs:
	b: The builder to destroy.
*/
destroy_builder :: proc(b: ^Tree_Builder) {
	for p in b.pending {
		destroy_builder(p.builder)
		free(p.builder, b.allocator)
		// Free the placeholder ^Tree node
		if tree_ptr, ok := b.items[p.index].(^Tree); ok {
			free(tree_ptr, b.allocator)
		}
	}
	delete(b.pending)
	delete(b.items)
	b^ = {}
}
