package cli

import "base:runtime"
import "core:fmt"
import "core:reflect"
import "core:strconv"
import "core:strings"

// Group_Mode defines the constraint semantics for a flag group.
Group_Mode :: enum {
	At_Most_One,  // xor — at most one flag in the group may be set
	Exactly_One,  // one_of — exactly one flag must be set
	At_Least_One, // any_of — at least one flag must be set
	All_Or_None,  // together — all flags set or none set
}

// Flag_Group identifies a named constraint group and its mode.
Flag_Group :: struct {
	name: string,
	mode: Group_Mode,
}

// Flag_Info holds metadata extracted from a core:flags-annotated struct field.
Flag_Info :: struct {
	field_name:       string,      // Odin struct field name (for panel matching)
	display_name:     string,      // CLI name (underscores -> hyphens, or name= override)
	usage:            string,      // from `usage` tag
	type_description: string,      // "<int>", "<string>", etc.
	short_name:       string,      // short alias chars, e.g. "v" or "pP" (from args:"short=v" or args:"short=pP"); first char is primary (shown in help)
	env_var:          string,      // env var name (from args:"env=VAR")
	enum_names:       []string,    // enum variant names (from Type_Info_Enum)
	pos:              int,         // positional index, or -1
	is_positional:    bool,
	is_required:      bool,
	is_boolean:       bool,
	is_hidden:        bool,
	is_greedy:        bool,        // from args:"greedy" — short-circuits before parse
	is_count:         bool,        // from args:"count" — int field, accumulates via repeated short flags
	is_multi:         bool,        // from args:"multi" — string field, merges repeated flag values with comma
	is_enum:          bool,        // auto-detected from field type
	group:            Flag_Group,  // constraint group (zero value = no group)
	panel:            string,      // from args:"panel=Name" — help panel assignment
	min_val:          Maybe(f64),  // from args:"min=N"
	max_val:          Maybe(f64),  // from args:"max=N"
	file_exists:      bool,        // from args:"file_exists"
	dir_exists:       bool,        // from args:"dir_exists"
	path_exists:      bool,        // from args:"path_exists"
}

// Tag constants matching core:flags.
@(private = "file")
TAG_ARGS :: "args"
@(private = "file")
TAG_USAGE :: "usage"
@(private = "file")
SUBTAG_NAME :: "name"
@(private = "file")
SUBTAG_POS :: "pos"
@(private = "file")
SUBTAG_REQUIRED :: "required"
@(private = "file")
SUBTAG_HIDDEN :: "hidden"
@(private = "file")
SUBTAG_SHORT :: "short"
@(private = "file")
SUBTAG_ENV :: "env"
@(private = "file")
SUBTAG_GREEDY :: "greedy"
@(private = "file")
SUBTAG_COUNT :: "count"
@(private = "file")
SUBTAG_MULTI :: "multi"
@(private = "file")
SUBTAG_XOR :: "xor"
@(private = "file")
SUBTAG_ONE_OF :: "one_of"
@(private = "file")
SUBTAG_ANY_OF :: "any_of"
@(private = "file")
SUBTAG_TOGETHER :: "together"
@(private = "file")
SUBTAG_MIN :: "min"
@(private = "file")
SUBTAG_MAX :: "max"
@(private = "file")
SUBTAG_FILE_EXISTS :: "file_exists"
@(private = "file")
SUBTAG_DIR_EXISTS :: "dir_exists"
@(private = "file")
SUBTAG_PATH_EXISTS :: "path_exists"
@(private = "file")
SUBTAG_PANEL :: "panel"

// extract_flags introspects a core:flags-annotated struct type and returns
// a slice of Flag_Info describing each field. Uses temp_allocator.
@(private)
extract_flags :: proc(data_type: typeid) -> []Flag_Info {
	fields := reflect.struct_fields_zipped(data_type)
	if len(fields) == 0 do return nil

	result := make([dynamic]Flag_Info, 0, len(fields), context.temp_allocator)

	for field in fields {
		info: Flag_Info
		info.field_name = field.name
		info.pos = -1

		// Parse "args" tag subtags.
		if args_tag, ok := reflect.struct_tag_lookup(field.tag, TAG_ARGS); ok {
			if _, is_hidden := get_subtag(args_tag, SUBTAG_HIDDEN); is_hidden {
				info.is_hidden = true
			}
			if pos_str, is_pos := get_subtag(args_tag, SUBTAG_POS); is_pos {
				info.is_positional = true
				if pos, parse_ok := strconv.parse_u64_of_base(pos_str, 10); parse_ok {
					info.pos = int(pos)
				}
			}
			if _, is_required := get_subtag(args_tag, SUBTAG_REQUIRED); is_required {
				info.is_required = true
			}
			if short_val, has_short := get_subtag(args_tag, SUBTAG_SHORT); has_short {
				info.short_name = short_val
			}
			if env_val, has_env := get_subtag(args_tag, SUBTAG_ENV); has_env {
				info.env_var = env_val
			}
			if _, has_greedy := get_subtag(args_tag, SUBTAG_GREEDY); has_greedy {
				info.is_greedy = true
			}
			if _, has_count := get_subtag(args_tag, SUBTAG_COUNT); has_count {
				info.is_count = true
			}
			if _, has_multi := get_subtag(args_tag, SUBTAG_MULTI); has_multi {
				base := runtime.type_info_base(field.type)
				_, is_str := base.variant.(runtime.Type_Info_String)
				assert(is_str, fmt.tprintf("args:\"multi\" on field '%s' requires a string type", field.name))
				info.is_multi = true
			}
			// Group tags (mutually exclusive — a flag can only be in one group).
			if xor_val, has_xor := get_subtag(args_tag, SUBTAG_XOR); has_xor {
				info.group = {name = xor_val, mode = .At_Most_One}
			} else if one_of_val, has_one_of := get_subtag(args_tag, SUBTAG_ONE_OF); has_one_of {
				info.group = {name = one_of_val, mode = .Exactly_One}
			} else if any_of_val, has_any_of := get_subtag(args_tag, SUBTAG_ANY_OF); has_any_of {
				info.group = {name = any_of_val, mode = .At_Least_One}
			} else if together_val, has_together := get_subtag(args_tag, SUBTAG_TOGETHER); has_together {
				info.group = {name = together_val, mode = .All_Or_None}
			}

			// Range tags.
			if min_str, has_min := get_subtag(args_tag, SUBTAG_MIN); has_min {
				if v, parse_ok := strconv.parse_f64(min_str); parse_ok {
					info.min_val = v
				}
			}
			if max_str, has_max := get_subtag(args_tag, SUBTAG_MAX); has_max {
				if v, parse_ok := strconv.parse_f64(max_str); parse_ok {
					info.max_val = v
				}
			}

			// Path tags.
			if _, has_file := get_subtag(args_tag, SUBTAG_FILE_EXISTS); has_file { info.file_exists = true }
			if _, has_dir := get_subtag(args_tag, SUBTAG_DIR_EXISTS); has_dir { info.dir_exists = true }
			if _, has_path := get_subtag(args_tag, SUBTAG_PATH_EXISTS); has_path { info.path_exists = true }

			// Panel tag.
			if panel_val, has_panel := get_subtag(args_tag, SUBTAG_PANEL); has_panel {
				info.panel = panel_val
			}
		}

		// Auto-detect enum types.
		base_type := runtime.type_info_base(field.type)
		if eti, eti_ok := base_type.variant.(runtime.Type_Info_Enum); eti_ok {
			info.is_enum = true
			info.enum_names = eti.names
		}

		// Display name: check name= subtag, else replace _ with -.
		info.display_name = get_field_name(field)

		// Boolean detection.
		info.is_boolean = reflect.is_boolean(field.type)

		// Multi mutual exclusivity checks.
		if info.is_multi {
			assert(!info.is_count, fmt.tprintf("Field '%s': args:\"multi\" and args:\"count\" are mutually exclusive", field.name))
			assert(!info.is_boolean, fmt.tprintf("Field '%s': args:\"multi\" cannot be used on boolean fields", field.name))
		}

		// Usage text from "usage" tag.
		if usage, ok := reflect.struct_tag_lookup(field.tag, TAG_USAGE); ok {
			info.usage = usage
		}

		// Type description.
		info.type_description = get_type_description(field, info.is_boolean)

		append(&result, info)
	}

	return result[:]
}

// get_field_name replicates core:flags get_field_name: check for name= subtag,
// otherwise replace underscores with hyphens.
@(private = "file")
get_field_name :: proc(field: reflect.Struct_Field) -> string {
	if args_tag, ok := reflect.struct_tag_lookup(field.tag, TAG_ARGS); ok {
		if name_subtag, name_ok := get_subtag(args_tag, SUBTAG_NAME); name_ok {
			return name_subtag
		}
	}
	name, _ := strings.replace_all(field.name, "_", "-", context.temp_allocator)
	return name
}

// get_subtag replicates core:flags get_subtag for parsing comma-separated subtags.
@(private = "file")
get_subtag :: proc(tag, id: string) -> (value: string, ok: bool) {
	tag := tag
	for subtag in strings.split_iterator(&tag, ",") {
		if equals := strings.index_byte(subtag, '='); equals != -1 && id == subtag[:equals] {
			return subtag[1 + equals:], true
		} else if id == subtag {
			return "", true
		}
	}
	return
}

// get_type_description generates a type hint string like "<int>", "<string>", etc.
@(private = "file")
get_type_description :: proc(field: reflect.Struct_Field, is_boolean: bool) -> string {
	if is_boolean do return ""

	#partial switch specific in field.type.variant {
	case runtime.Type_Info_Map:
		return "<map>"
	case runtime.Type_Info_Dynamic_Array:
		return fmt.tprintf("<%v, ...>", specific.elem.id)
	case:
		return fmt.tprintf("<%v>", field.type.id)
	}
}
