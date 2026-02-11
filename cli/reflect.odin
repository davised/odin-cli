package cli

import "base:runtime"
import "core:fmt"
import "core:reflect"
import "core:strconv"
import "core:strings"

// Flag_Info holds metadata extracted from a core:flags-annotated struct field.
Flag_Info :: struct {
	field_name:       string,   // Odin struct field name (for panel matching)
	display_name:     string,   // CLI name (underscores -> hyphens, or name= override)
	usage:            string,   // from `usage` tag
	type_description: string,   // "<int>", "<string>", etc.
	pos:              int,      // positional index, or -1
	is_positional:    bool,
	is_required:      bool,
	is_boolean:       bool,
	is_hidden:        bool,
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

// extract_flags introspects a core:flags-annotated struct type and returns
// a slice of Flag_Info describing each field. Uses temp_allocator.
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
		}

		// Display name: check name= subtag, else replace _ with -.
		info.display_name = get_field_name(field)

		// Boolean detection.
		info.is_boolean = reflect.is_boolean(field.type)

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
