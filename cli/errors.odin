package cli

import "../term"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:strings"

// write_error renders a styled error message for a flags parse error.
write_error :: proc(
	w: io.Writer,
	data_type: typeid,
	error: flags.Error,
	program: string,
	parsing_style: flags.Parsing_Style = .Unix,
	theme_override: Maybe(Theme) = nil,
	mode: term.Render_Mode = .Full,
	n: ^int = nil,
) -> bool {
	theme := theme_override.? or_else default_theme()

	switch err in error {
	case flags.Parse_Error:
		write_parse_error(w, data_type, err, program, parsing_style, theme, mode, n)
	case flags.Open_File_Error:
		write_styled(w, "Error: ", theme.error_style, mode, n)
		io.write_string(w, fmt.tprintf("Unable to open file '%s': %v", err.filename, err.errno), n)
		io.write_string(w, "\n", n)
	case flags.Validation_Error:
		write_styled(w, "Error: ", theme.error_style, mode, n)
		io.write_string(w, err.message, n)
		io.write_string(w, "\n", n)
	case flags.Help_Request:
		return false
	}

	return true
}

@(private = "file")
write_parse_error :: proc(
	w: io.Writer,
	data_type: typeid,
	err: flags.Parse_Error,
	program: string,
	parsing_style: flags.Parsing_Style,
	theme: Theme,
	mode: term.Render_Mode,
	n: ^int,
) {
	prefix := flag_prefix_for_style(parsing_style)

	write_styled(w, "Error: ", theme.error_style, mode, n)
	io.write_string(w, err.message, n)
	io.write_string(w, "\n", n)

	// "Did you mean?" suggestion for unknown flag errors.
	reason, is_parse_reason := err.reason.(flags.Parse_Error_Reason)
	if !is_parse_reason do return

	if reason == .Missing_Flag {
		unknown_flag := extract_unknown_flag(err.message)
		if len(unknown_flag) > 0 {
			all_flags := extract_flags(data_type)
			if suggestion, ok := find_suggestion(unknown_flag, all_flags); ok {
				io.write_string(w, "\n", n)
				write_styled(w, "Did you mean ", theme.suggest_style, mode, n)
				write_styled(w, fmt.tprintf("%s%s", prefix, suggestion), theme.flag_name_style, mode, n)
				write_styled(w, "?", theme.suggest_style, mode, n)
				io.write_string(w, "\n", n)
			}
		}
	}

	// Usage hint.
	io.write_string(w, "\n", n)
	write_styled(w, "For more information, try ", theme.meta_style, mode, n)
	write_styled(w, fmt.tprintf("%shelp", prefix), theme.flag_name_style, mode, n)
	write_styled(w, ".", theme.meta_style, mode, n)
	io.write_string(w, "\n", n)
}

// extract_unknown_flag pulls the flag name from error messages like
// "Flag 'foo' is not a valid flag."
@(private = "file")
extract_unknown_flag :: proc(message: string) -> string {
	// core:flags uses backticks: "Unable to find any flag named `foo`."
	start := strings.index_byte(message, '`')
	if start < 0 do return ""
	rest := message[start + 1:]
	end := strings.index_byte(rest, '`')
	if end < 0 do return ""
	return rest[:end]
}

// find_suggestion finds the closest matching flag name using Levenshtein distance.
// Also checks short flag names for single-character unknowns.
@(private = "file")
find_suggestion :: proc(unknown: string, all_flags: []Flag_Info) -> (string, bool) {
	// Single-character unknown: check if it matches a short flag name.
	if len(unknown) == 1 {
		for f in all_flags {
			if f.is_hidden do continue
			for ch in transmute([]u8)f.short_name {
				if ch == unknown[0] {
					return f.display_name, true
				}
			}
		}
	}

	best_name: string
	best_dist := max(int)
	threshold := max(3, len(unknown) / 2)

	for f in all_flags {
		if f.is_hidden do continue
		dist := levenshtein(unknown, f.display_name)
		if dist < best_dist {
			best_dist = dist
			best_name = f.display_name
		}
		// Also compare against short names.
		if len(f.short_name) > 0 {
			dist = levenshtein(unknown, f.short_name)
			if dist < best_dist {
				best_dist = dist
				best_name = f.display_name // suggest the long name
			}
		}
	}

	if best_dist <= threshold {
		return best_name, true
	}
	return "", false
}

// levenshtein computes the Levenshtein edit distance between two strings.
// Package-private for reuse by cli.odin's command suggestion.
@(private)
levenshtein :: proc(a, b: string) -> int {
	// Decode runes.
	a_runes := make([dynamic]rune, context.temp_allocator)
	b_runes := make([dynamic]rune, context.temp_allocator)
	for r in a do append(&a_runes, r)
	for r in b do append(&b_runes, r)

	m := len(a_runes)
	n := len(b_runes)
	if m == 0 do return n
	if n == 0 do return m

	// Two-row approach.
	prev := make([]int, n + 1, context.temp_allocator)
	curr := make([]int, n + 1, context.temp_allocator)

	for j := 0; j <= n; j += 1 {
		prev[j] = j
	}

	for i := 1; i <= m; i += 1 {
		curr[0] = i
		for j := 1; j <= n; j += 1 {
			cost := 0 if a_runes[i - 1] == b_runes[j - 1] else 1
			del := prev[j] + 1
			ins := curr[j - 1] + 1
			sub := prev[j - 1] + cost
			curr[j] = min(del, ins, sub)
		}
		prev, curr = curr, prev
	}

	return prev[n]
}
