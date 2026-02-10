package tree

DEFAULT_ENUMERATOR :: Enumerator{
	item      = "├── ",
	last_item = "└── ",
	branch    = "│   ",
	padding   = "    ",
}

ROUNDED_ENUMERATOR :: Enumerator{
	item      = "├── ",
	last_item = "╰── ",
	branch    = "│   ",
	padding   = "    ",
}

ASCII_ENUMERATOR :: Enumerator{
	item      = "|-- ",
	last_item = "`-- ",
	branch    = "|   ",
	padding   = "    ",
}
