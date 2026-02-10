package tree

import style "../style"

/* Content for a tree's root line — string or styled text (no recursive nesting). */
Tree_Root :: union {
  string,
  style.Styled_Text,
}

/* Content for tree children — can be leaf strings, styled text, or nested subtrees. */
Tree_Item :: union {
  string,
  style.Styled_Text,
  ^Tree,
}

/*
A tree node with optional root label and children.

When root is nil, children are rendered as a forest (no root line).
The enumerator field allows per-subtree override of branch characters.
*/
Tree :: struct {
  root:       Tree_Root,
  children:   []Tree_Item,
  enumerator: ^Enumerator,
}

/* Characters used to draw tree connectors. */
Enumerator :: struct {
  item:      string, // non-last child connector, e.g. "├── "
  last_item: string, // last child connector,     e.g. "└── "
  branch:    string, // continuing depth line,     e.g. "│   "
  padding:   string, // spacing when no connector, e.g. "    "
}
