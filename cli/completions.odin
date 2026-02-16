package cli

import "core:flags"
import "core:fmt"
import "core:io"
import "core:strings"

// Shell identifies a shell for completion script generation.
Shell :: enum {
	Bash,
	Zsh,
	Fish,
}

// write_completions generates a shell completion script for a multi-command App.
write_completions :: proc(w: io.Writer, app: ^App, shell: Shell, n: ^int = nil) {
	switch shell {
	case .Bash: write_bash_app(w, app, n)
	case .Zsh:  write_zsh_app(w, app, n)
	case .Fish: write_fish_app(w, app, n)
	}
}

// write_flag_completions generates a shell completion script for a standalone
// flags-only tool (used with parse_or_exit).
write_flag_completions :: proc(w: io.Writer, program: string, data_type: typeid, shell: Shell, parsing_style: flags.Parsing_Style = .Unix, n: ^int = nil) {
	flag_infos := extract_flags(data_type)
	switch shell {
	case .Bash: write_bash_flags_only(w, program, flag_infos, parsing_style, n)
	case .Zsh:  write_zsh_flags_only(w, program, flag_infos, parsing_style, n)
	case .Fish: write_fish_flags_only(w, program, flag_infos, parsing_style, n)
	}
}

// --- Shared helpers ---

// writeln writes a formatted line to the writer.
@(private = "file")
writeln :: proc(w: io.Writer, s: string, n: ^int) {
	io.write_string(w, s, n)
	io.write_string(w, "\n", n)
}

// sanitize_name replaces hyphens/dots with underscores for shell function names.
@(private = "file")
sanitize_name :: proc(name: string) -> string {
	result, _ := strings.replace_all(name, "-", "_", context.temp_allocator)
	result, _ = strings.replace_all(result, ".", "_", context.temp_allocator)
	return result
}

// format_enum_values returns space-separated normalized enum names.
@(private = "file")
format_enum_values :: proc(names: []string) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for name, i in names {
		if i > 0 do strings.write_byte(&sb, ' ')
		strings.write_string(&sb, normalize_enum_name(name))
	}
	return strings.to_string(sb)
}

// --- Bash ---

@(private = "file")
write_bash_app :: proc(w: io.Writer, app: ^App, n: ^int) {
	func_name := sanitize_name(app.name)
	global_infos: []Flag_Info
	if app._global_parse_proc != nil {
		global_infos = extract_flags(app._global_flags_type)
	}

	writeln(w, fmt.tprintf("_%s() {{", func_name), n)
	io.write_string(w, "    local cur prev words cword\n", n)
	io.write_string(w, "    _init_completion || return\n", n)
	io.write_string(w, "\n", n)

	// Determine which command we're in.
	io.write_string(w, "    local cmd=\"\"\n", n)
	io.write_string(w, "    for ((i=1; i < cword; i++)); do\n", n)
	io.write_string(w, "        case \"${words[i]}\" in\n", n)
	for &cmd in app.commands {
		if cmd.hidden do continue
		names := command_names_joined(&cmd, '|')
		writeln(w, fmt.tprintf("            %s) cmd=\"%s\"; break ;;", names, cmd.name), n)
	}
	io.write_string(w, "        esac\n", n)
	io.write_string(w, "    done\n", n)
	io.write_string(w, "\n", n)

	// Build global and built-in flag word lists.
	global_words := build_flag_words(global_infos, app.parsing_style)
	builtin_words := build_builtin_words(app.version, app.parsing_style)
	shared_words := join_words(global_words, builtin_words)

	io.write_string(w, "    case \"$cmd\" in\n", n)

	// Per-command completions.
	for &cmd in app.commands {
		if cmd.hidden do continue
		cmd_flags := extract_flags(cmd._flags_type)
		writeln(w, fmt.tprintf("        %s)", cmd.name), n)

		// Enum value completions for prev flag.
		write_bash_enum_cases(w, cmd_flags, app.parsing_style, n)
		write_bash_enum_cases(w, global_infos, app.parsing_style, n)

		// File/dir completions for prev flag.
		write_bash_path_cases(w, cmd_flags, app.parsing_style, n)
		write_bash_path_cases(w, global_infos, app.parsing_style, n)

		// Subcommand handling.
		if len(cmd.subcommands) > 0 {
			write_bash_subcommand_block(w, &cmd, cmd_flags, global_infos, app.parsing_style, builtin_words, n)
		} else {
			flag_words := build_flag_words(cmd_flags, app.parsing_style)
			all_words := join_words(flag_words, shared_words)
			writeln(w, fmt.tprintf("            COMPREPLY=($(compgen -W \"%s\" -- \"$cur\"))", all_words), n)
		}

		io.write_string(w, "            ;;\n", n)
	}

	// No command yet — complete commands + global flags.
	io.write_string(w, "        \"\")\n", n)
	cmd_words := build_command_words(app.commands[:])
	all_words := join_words(cmd_words, shared_words)
	writeln(w, fmt.tprintf("            COMPREPLY=($(compgen -W \"%s\" -- \"$cur\"))", all_words), n)
	io.write_string(w, "            ;;\n", n)

	io.write_string(w, "    esac\n", n)
	writeln(w, "}", n)
	writeln(w, fmt.tprintf("complete -o default -F _%s %s", func_name, app.name), n)
}

@(private = "file")
write_bash_subcommand_block :: proc(w: io.Writer, cmd: ^Command, cmd_flags: []Flag_Info, global_infos: []Flag_Info, parsing_style: flags.Parsing_Style, builtin_words: string, n: ^int) {
	// Detect subcommand in args.
	io.write_string(w, "            local subcmd=\"\"\n", n)
	io.write_string(w, "            for ((j=i+1; j < cword; j++)); do\n", n)
	io.write_string(w, "                case \"${words[j]}\" in\n", n)
	for &sub in cmd.subcommands {
		if sub.hidden do continue
		names := command_names_joined(&sub, '|')
		writeln(w, fmt.tprintf("                    %s) subcmd=\"%s\"; break ;;", names, sub.name), n)
	}
	io.write_string(w, "                esac\n", n)
	io.write_string(w, "            done\n", n)

	global_words := build_flag_words(global_infos, parsing_style)
	shared_words := join_words(global_words, builtin_words)

	io.write_string(w, "            case \"$subcmd\" in\n", n)
	for &sub in cmd.subcommands {
		if sub.hidden do continue
		sub_flags := extract_flags(sub._flags_type)
		writeln(w, fmt.tprintf("                %s)", sub.name), n)
		write_bash_enum_cases(w, sub_flags, parsing_style, n, "                    ")
		write_bash_enum_cases(w, global_infos, parsing_style, n, "                    ")
		write_bash_path_cases(w, sub_flags, parsing_style, n, "                    ")
		write_bash_path_cases(w, global_infos, parsing_style, n, "                    ")
		flag_words := build_flag_words(sub_flags, parsing_style)
		all_words := join_words(flag_words, shared_words)
		writeln(w, fmt.tprintf("                    COMPREPLY=($(compgen -W \"%s\" -- \"$cur\"))", all_words), n)
		io.write_string(w, "                    ;;\n", n)
	}
	// No subcommand yet — complete subcommands + parent flags.
	io.write_string(w, "                \"\")\n", n)
	sub_words := build_command_words(cmd.subcommands[:])
	parent_flag_words := build_flag_words(cmd_flags, parsing_style)
	all_words := join_words(sub_words, join_words(parent_flag_words, shared_words))
	writeln(w, fmt.tprintf("                    COMPREPLY=($(compgen -W \"%s\" -- \"$cur\"))", all_words), n)
	io.write_string(w, "                    ;;\n", n)
	io.write_string(w, "            esac\n", n)
}

@(private = "file")
write_bash_enum_cases :: proc(w: io.Writer, infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int, indent: string = "            ") {
	prefix := flag_prefix_for_style(parsing_style)
	has_enum := false
	for fi in infos {
		if fi.is_hidden || !fi.is_enum || len(fi.enum_names) == 0 do continue
		if !has_enum {
			writeln(w, fmt.tprintf("%scase \"$prev\" in", indent), n)
			has_enum = true
		}
		long := fmt.tprintf("%s%s", prefix, fi.display_name)
		if len(fi.short_name) > 0 && parsing_style == .Unix {
			pattern := strings.builder_make(context.temp_allocator)
			strings.write_string(&pattern, long)
			for ch in transmute([]u8)fi.short_name {
				strings.write_string(&pattern, "|-")
				strings.write_byte(&pattern, ch)
			}
			writeln(w, fmt.tprintf("%s    %s) COMPREPLY=($(compgen -W \"%s\" -- \"$cur\")); return ;;",
				indent, strings.to_string(pattern), format_enum_values(fi.enum_names)), n)
		} else {
			writeln(w, fmt.tprintf("%s    %s) COMPREPLY=($(compgen -W \"%s\" -- \"$cur\")); return ;;",
				indent, long, format_enum_values(fi.enum_names)), n)
		}
	}
	if has_enum {
		writeln(w, fmt.tprintf("%sesac", indent), n)
	}
}

@(private = "file")
write_bash_path_cases :: proc(w: io.Writer, infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int, indent: string = "            ") {
	prefix := flag_prefix_for_style(parsing_style)
	has_path := false
	for fi in infos {
		if fi.is_hidden do continue
		if !fi.file_exists && !fi.dir_exists && !fi.path_exists do continue
		if !has_path {
			writeln(w, fmt.tprintf("%scase \"$prev\" in", indent), n)
			has_path = true
		}
		long := fmt.tprintf("%s%s", prefix, fi.display_name)
		comp := fi.dir_exists ? "compgen -d" : "compgen -f"
		if len(fi.short_name) > 0 && parsing_style == .Unix {
			pattern := strings.builder_make(context.temp_allocator)
			strings.write_string(&pattern, long)
			for ch in transmute([]u8)fi.short_name {
				strings.write_string(&pattern, "|-")
				strings.write_byte(&pattern, ch)
			}
			writeln(w, fmt.tprintf("%s    %s) COMPREPLY=($(%s -- \"$cur\")); return ;;",
				indent, strings.to_string(pattern), comp), n)
		} else {
			writeln(w, fmt.tprintf("%s    %s) COMPREPLY=($(%s -- \"$cur\")); return ;;",
				indent, long, comp), n)
		}
	}
	if has_path {
		writeln(w, fmt.tprintf("%sesac", indent), n)
	}
}

@(private = "file")
write_bash_flags_only :: proc(w: io.Writer, program: string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int) {
	func_name := sanitize_name(program)
	prefix := flag_prefix_for_style(parsing_style)

	writeln(w, fmt.tprintf("_%s() {{", func_name), n)
	io.write_string(w, "    local cur prev words cword\n", n)
	io.write_string(w, "    _init_completion || return\n", n)
	io.write_string(w, "\n", n)

	// Enum value completions.
	write_bash_enum_cases(w, flag_infos, parsing_style, n, "    ")

	// File/dir completions.
	write_bash_path_cases(w, flag_infos, parsing_style, n, "    ")

	flag_words := build_flag_words(flag_infos, parsing_style)
	builtin := fmt.tprintf("%shelp %scompletions", prefix, prefix)
	all_words := join_words(flag_words, builtin)
	writeln(w, fmt.tprintf("    COMPREPLY=($(compgen -W \"%s\" -- \"$cur\"))", all_words), n)
	writeln(w, "}", n)
	writeln(w, fmt.tprintf("complete -o default -F _%s %s", func_name, program), n)
}

// --- Zsh ---

@(private = "file")
write_zsh_app :: proc(w: io.Writer, app: ^App, n: ^int) {
	writeln(w, fmt.tprintf("#compdef %s", app.name), n)
	io.write_string(w, "\n", n)
	writeln(w, fmt.tprintf("_%s() {{", sanitize_name(app.name)), n)

	// Global flags.
	global_infos: []Flag_Info
	if app._global_parse_proc != nil {
		global_infos = extract_flags(app._global_flags_type)
	}

	io.write_string(w, "    local -a global_flags\n", n)
	io.write_string(w, "    global_flags=(\n", n)
	write_zsh_flags(w, global_infos, app.parsing_style, n, "        ")
	io.write_string(w, "    )\n", n)
	io.write_string(w, "\n", n)

	io.write_string(w, "    _arguments -C \\\n", n)
	io.write_string(w, "        $global_flags \\\n", n)
	io.write_string(w, "        '--help[Show help]' \\\n", n)
	if len(app.version) > 0 {
		io.write_string(w, "        '--version[Show version]' \\\n", n)
	}
	io.write_string(w, "        '--completions[Generate shell completions]:shell:(bash zsh fish)' \\\n", n)
	io.write_string(w, "        '1: :->command' \\\n", n)
	io.write_string(w, "        '*::arg:->args'\n", n)
	io.write_string(w, "\n", n)

	io.write_string(w, "    case $state in\n", n)
	io.write_string(w, "        command)\n", n)
	io.write_string(w, "            local -a commands\n", n)
	io.write_string(w, "            commands=(\n", n)
	for &cmd in app.commands {
		if cmd.hidden do continue
		desc := zsh_escape(cmd.description)
		writeln(w, fmt.tprintf("                '%s:%s'", cmd.name, desc), n)
		for alias in cmd.aliases {
			writeln(w, fmt.tprintf("                '%s:%s'", alias, desc), n)
		}
	}
	io.write_string(w, "            )\n", n)
	io.write_string(w, "            _describe 'command' commands\n", n)
	io.write_string(w, "            ;;\n", n)

	io.write_string(w, "        args)\n", n)
	io.write_string(w, "            case $words[1] in\n", n)
	for &cmd in app.commands {
		if cmd.hidden do continue
		pattern := cmd.name
		if len(cmd.aliases) > 0 {
			pattern = fmt.tprintf("%s|%s", cmd.name, strings.join(cmd.aliases, "|", context.temp_allocator))
		}
		writeln(w, fmt.tprintf("                %s)", pattern), n)

		if len(cmd.subcommands) > 0 {
			write_zsh_subcommand_handler(w, &cmd, global_infos, app.parsing_style, n)
		} else {
			cmd_flags := extract_flags(cmd._flags_type)
			io.write_string(w, "                    _arguments \\\n", n)
			io.write_string(w, "                        $global_flags \\\n", n)
			write_zsh_flags(w, cmd_flags, app.parsing_style, n, "                        ", " \\")
			io.write_string(w, "                        '--help[Show help]'\n", n)
		}

		io.write_string(w, "                    ;;\n", n)
	}
	io.write_string(w, "            esac\n", n)
	io.write_string(w, "            ;;\n", n)

	io.write_string(w, "    esac\n", n)
	writeln(w, "}", n)
	writeln(w, fmt.tprintf("_%s", sanitize_name(app.name)), n)
}

@(private = "file")
write_zsh_subcommand_handler :: proc(w: io.Writer, cmd: ^Command, global_infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int) {
	io.write_string(w, "                    _arguments -C \\\n", n)
	io.write_string(w, "                        $global_flags \\\n", n)
	cmd_flags := extract_flags(cmd._flags_type)
	write_zsh_flags(w, cmd_flags, parsing_style, n, "                        ", " \\")
	io.write_string(w, "                        '1: :->subcmd' \\\n", n)
	io.write_string(w, "                        '*::arg:->subargs'\n", n)
	io.write_string(w, "                    case $state in\n", n)
	io.write_string(w, "                        subcmd)\n", n)
	io.write_string(w, "                            local -a subcommands\n", n)
	io.write_string(w, "                            subcommands=(\n", n)
	for &sub in cmd.subcommands {
		if sub.hidden do continue
		desc := zsh_escape(sub.description)
		writeln(w, fmt.tprintf("                                '%s:%s'", sub.name, desc), n)
		for alias in sub.aliases {
			writeln(w, fmt.tprintf("                                '%s:%s'", alias, desc), n)
		}
	}
	io.write_string(w, "                            )\n", n)
	io.write_string(w, "                            _describe 'subcommand' subcommands\n", n)
	io.write_string(w, "                            ;;\n", n)
	io.write_string(w, "                        subargs)\n", n)
	io.write_string(w, "                            case $words[1] in\n", n)
	for &sub in cmd.subcommands {
		if sub.hidden do continue
		sub_pattern := sub.name
		if len(sub.aliases) > 0 {
			sub_pattern = fmt.tprintf("%s|%s", sub.name, strings.join(sub.aliases, "|", context.temp_allocator))
		}
		sub_flags := extract_flags(sub._flags_type)
		writeln(w, fmt.tprintf("                                %s)", sub_pattern), n)
		io.write_string(w, "                                    _arguments \\\n", n)
		io.write_string(w, "                                        $global_flags \\\n", n)
		write_zsh_flags(w, sub_flags, parsing_style, n, "                                        ", " \\")
		io.write_string(w, "                                        '--help[Show help]'\n", n)
		io.write_string(w, "                                    ;;\n", n)
	}
	io.write_string(w, "                            esac\n", n)
	io.write_string(w, "                            ;;\n", n)
	io.write_string(w, "                    esac\n", n)
}

@(private = "file")
write_zsh_flags :: proc(w: io.Writer, infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int, indent: string, suffix: string = "") {
	prefix := flag_prefix_for_style(parsing_style)
	for fi in infos {
		if fi.is_hidden || fi.is_positional do continue
		desc := zsh_escape(fi.usage)
		long := fmt.tprintf("%s%s", prefix, fi.display_name)
		action := zsh_completion_action(fi)

		if len(fi.short_name) > 0 && parsing_style == .Unix {
			// Build exclusion group and brace expansion for all short aliases.
			excl := strings.builder_make(context.temp_allocator)
			brace := strings.builder_make(context.temp_allocator)
			for ch, idx in transmute([]u8)fi.short_name {
				if idx > 0 {
					strings.write_byte(&excl, ' ')
					strings.write_byte(&brace, ',')
				}
				strings.write_byte(&excl, '-')
				strings.write_byte(&excl, ch)
				strings.write_byte(&brace, '-')
				strings.write_byte(&brace, ch)
			}
			strings.write_byte(&excl, ' ')
			strings.write_string(&excl, long)
			strings.write_byte(&brace, ',')
			strings.write_string(&brace, long)
			excl_str := strings.to_string(excl)
			brace_str := strings.to_string(brace)
			if fi.is_boolean {
				writeln(w, fmt.tprintf("%s'(%s)'{{%s}}'[%s]'%s",
					indent, excl_str, brace_str, desc, suffix), n)
			} else {
				writeln(w, fmt.tprintf("%s'(%s)'{{%s}}'[%s]:%s:%s'%s",
					indent, excl_str, brace_str, desc, fi.display_name, action, suffix), n)
			}
		} else {
			if fi.is_boolean {
				writeln(w, fmt.tprintf("%s'%s[%s]'%s", indent, long, desc, suffix), n)
			} else {
				writeln(w, fmt.tprintf("%s'%s[%s]:%s:%s'%s", indent, long, desc, fi.display_name, action, suffix), n)
			}
		}
	}
}

@(private = "file")
zsh_completion_action :: proc(fi: Flag_Info) -> string {
	if fi.is_enum && len(fi.enum_names) > 0 {
		return fmt.tprintf("(%s)", format_enum_values(fi.enum_names))
	}
	if fi.file_exists || fi.path_exists {
		return "_files"
	}
	if fi.dir_exists {
		return "_directories"
	}
	return " "
}

@(private = "file")
write_zsh_flags_only :: proc(w: io.Writer, program: string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int) {
	func_name := sanitize_name(program)
	prefix := flag_prefix_for_style(parsing_style)
	writeln(w, fmt.tprintf("#compdef %s", program), n)
	io.write_string(w, "\n", n)
	writeln(w, fmt.tprintf("_%s() {{", func_name), n)
	io.write_string(w, "    _arguments \\\n", n)
	write_zsh_flags(w, flag_infos, parsing_style, n, "        ", " \\")
	writeln(w, fmt.tprintf("        '%shelp[Show help]' \\", prefix), n)
	writeln(w, fmt.tprintf("        '%scompletions[Generate shell completions]:shell:(bash zsh fish)'", prefix), n)
	writeln(w, "}", n)
	writeln(w, fmt.tprintf("_%s", func_name), n)
}

@(private = "file")
zsh_escape :: proc(s: string) -> string {
	if len(s) == 0 do return ""
	result, _ := strings.replace_all(s, "\\", "\\\\", context.temp_allocator)
	result, _ = strings.replace_all(result, "'", "'\\''", context.temp_allocator)
	result, _ = strings.replace_all(result, "[", "\\[", context.temp_allocator)
	result, _ = strings.replace_all(result, "]", "\\]", context.temp_allocator)
	result, _ = strings.replace_all(result, ":", "\\:", context.temp_allocator)
	return result
}

// --- Fish ---

@(private = "file")
write_fish_app :: proc(w: io.Writer, app: ^App, n: ^int) {
	prog := app.name
	global_infos: []Flag_Info
	if app._global_parse_proc != nil {
		global_infos = extract_flags(app._global_flags_type)
	}

	// Commands.
	io.write_string(w, "# Commands\n", n)
	for &cmd in app.commands {
		if cmd.hidden do continue
		writeln(w, fmt.tprintf("complete -c %s -f -n \"__fish_use_subcommand\" -a \"%s\" -d \"%s\"",
			prog, cmd.name, fish_escape(cmd.description)), n)
		for alias in cmd.aliases {
			writeln(w, fmt.tprintf("complete -c %s -f -n \"__fish_use_subcommand\" -a \"%s\" -d \"%s\"",
				prog, alias, fish_escape(cmd.description)), n)
		}
	}
	io.write_string(w, "\n", n)

	// Built-in and global flags.
	io.write_string(w, "# Global flags\n", n)
	writeln(w, fmt.tprintf("complete -c %s -l help -d \"Show help\"", prog), n)
	if len(app.version) > 0 {
		writeln(w, fmt.tprintf("complete -c %s -l version -d \"Show version\"", prog), n)
	}
	writeln(w, fmt.tprintf("complete -c %s -l completions -d \"Generate shell completions\" -r -f -a \"bash zsh fish\"", prog), n)
	write_fish_flags(w, prog, global_infos, "", app.parsing_style, n)
	io.write_string(w, "\n", n)

	// Per-command flags.
	for &cmd in app.commands {
		if cmd.hidden do continue
		cmd_flags := extract_flags(cmd._flags_type)
		if len(cmd_flags) > 0 || len(cmd.subcommands) > 0 {
			writeln(w, fmt.tprintf("# %s flags", cmd.name), n)
		}

		condition := fmt.tprintf("__fish_seen_subcommand_from %s", command_names_joined(&cmd, ' '))
		write_fish_flags(w, prog, cmd_flags, condition, app.parsing_style, n)

		// Subcommands.
		if len(cmd.subcommands) > 0 {
			// Subcommand names.
			all_sub_names := make([dynamic]string, 0, len(cmd.subcommands), context.temp_allocator)
			for &sub in cmd.subcommands {
				if sub.hidden do continue
				append(&all_sub_names, sub.name)
				for alias in sub.aliases {
					append(&all_sub_names, alias)
				}
			}
			sub_names_str := strings.join(all_sub_names[:], " ", context.temp_allocator)

			for &sub in cmd.subcommands {
				if sub.hidden do continue
				sub_cond := fmt.tprintf("__fish_seen_subcommand_from %s; and not __fish_seen_subcommand_from %s",
					command_names_joined(&cmd, ' '), sub_names_str)
				writeln(w, fmt.tprintf("complete -c %s -f -n \"%s\" -a \"%s\" -d \"%s\"",
					prog, sub_cond, sub.name, fish_escape(sub.description)), n)
				for alias in sub.aliases {
					writeln(w, fmt.tprintf("complete -c %s -f -n \"%s\" -a \"%s\" -d \"%s\"",
						prog, sub_cond, alias, fish_escape(sub.description)), n)
				}

				// Subcommand flags.
				sub_flags := extract_flags(sub._flags_type)
				sub_flag_cond := fmt.tprintf("__fish_seen_subcommand_from %s", command_names_joined(&sub, ' '))
				write_fish_flags(w, prog, sub_flags, sub_flag_cond, app.parsing_style, n)
			}
		}
		io.write_string(w, "\n", n)
	}
}

@(private = "file")
write_fish_flags :: proc(w: io.Writer, prog: string, infos: []Flag_Info, condition: string, parsing_style: flags.Parsing_Style, n: ^int) {
	for fi in infos {
		if fi.is_hidden || fi.is_positional do continue

		// Write flag completion directly to writer.
		io.write_string(w, "complete -c ", n)
		io.write_string(w, prog, n)

		if len(condition) > 0 {
			io.write_string(w, " -n \"", n)
			io.write_string(w, condition, n)
			io.write_string(w, "\"", n)
		}

		io.write_string(w, " -l ", n)
		io.write_string(w, fi.display_name, n)

		if len(fi.short_name) > 0 && parsing_style == .Unix {
			io.write_string(w, " -s ", n)
			io.write_byte(w, fi.short_name[0], n)
		}

		if len(fi.usage) > 0 {
			io.write_string(w, " -d \"", n)
			io.write_string(w, fish_escape(fi.usage), n)
			io.write_string(w, "\"", n)
		}

		if !fi.is_boolean {
			io.write_string(w, " -r", n)
		}

		if fi.file_exists || fi.path_exists || fi.dir_exists {
			io.write_string(w, " -F", n)
		}

		io.write_string(w, "\n", n)

		// Enum value completion using __fish_contains_opt.
		if fi.is_enum && len(fi.enum_names) > 0 {
			io.write_string(w, "complete -c ", n)
			io.write_string(w, prog, n)
			io.write_string(w, " -f -n \"", n)
			if len(condition) > 0 {
				io.write_string(w, condition, n)
				io.write_string(w, "; and ", n)
			}
			// __fish_contains_opt: long flags without dashes, -s for short.
			io.write_string(w, "__fish_contains_opt", n)
			if len(fi.short_name) > 0 && parsing_style == .Unix {
				io.write_string(w, " -s ", n)
				io.write_byte(w, fi.short_name[0], n)
			}
			io.write_string(w, " ", n)
			io.write_string(w, fi.display_name, n)
			io.write_string(w, "\" -a \"", n)
			io.write_string(w, format_enum_values(fi.enum_names), n)
			io.write_string(w, "\"\n", n)
		}
	}
}

@(private = "file")
write_fish_flags_only :: proc(w: io.Writer, program: string, flag_infos: []Flag_Info, parsing_style: flags.Parsing_Style, n: ^int) {
	writeln(w, fmt.tprintf("complete -c %s -l help -d \"Show help\"", program), n)
	writeln(w, fmt.tprintf("complete -c %s -l completions -d \"Generate shell completions\" -r -f -a \"bash zsh fish\"", program), n)
	write_fish_flags(w, program, flag_infos, "", parsing_style, n)
}

@(private = "file")
fish_escape :: proc(s: string) -> string {
	if len(s) == 0 do return ""
	result, _ := strings.replace_all(s, "\\", "\\\\", context.temp_allocator)
	result, _ = strings.replace_all(result, "\"", "\\\"", context.temp_allocator)
	return result
}

// --- Word-list builders ---

// build_builtin_words returns the built-in flags (--help, --version, --completions)
// as a space-separated string for inclusion in completion word lists.
@(private = "file")
build_builtin_words :: proc(version: string, parsing_style: flags.Parsing_Style) -> string {
	prefix := flag_prefix_for_style(parsing_style)
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, prefix)
	strings.write_string(&sb, "help")
	if len(version) > 0 {
		strings.write_byte(&sb, ' ')
		strings.write_string(&sb, prefix)
		strings.write_string(&sb, "version")
	}
	strings.write_byte(&sb, ' ')
	strings.write_string(&sb, prefix)
	strings.write_string(&sb, "completions")
	return strings.to_string(sb)
}

@(private = "file")
build_flag_words :: proc(infos: []Flag_Info, parsing_style: flags.Parsing_Style) -> string {
	prefix := flag_prefix_for_style(parsing_style)
	sb := strings.builder_make(context.temp_allocator)
	first := true
	for fi in infos {
		if fi.is_hidden || fi.is_positional do continue
		if !first do strings.write_byte(&sb, ' ')
		first = false
		strings.write_string(&sb, prefix)
		strings.write_string(&sb, fi.display_name)
		if len(fi.short_name) > 0 && parsing_style == .Unix {
			for ch in transmute([]u8)fi.short_name {
				strings.write_byte(&sb, ' ')
				strings.write_byte(&sb, '-')
				strings.write_byte(&sb, ch)
			}
		}
	}
	return strings.to_string(sb)
}

@(private = "file")
build_command_words :: proc(commands: []Command) -> string {
	sb := strings.builder_make(context.temp_allocator)
	first := true
	for cmd in commands {
		if cmd.hidden do continue
		if !first do strings.write_byte(&sb, ' ')
		first = false
		strings.write_string(&sb, cmd.name)
		for alias in cmd.aliases {
			strings.write_byte(&sb, ' ')
			strings.write_string(&sb, alias)
		}
	}
	return strings.to_string(sb)
}

@(private = "file")
join_words :: proc(a, b: string) -> string {
	if len(a) == 0 do return b
	if len(b) == 0 do return a
	return fmt.tprintf("%s %s", a, b)
}

// command_names_joined returns command name and aliases joined by sep.
// Use '|' for bash case patterns, ' ' for fish conditions.
@(private = "file")
command_names_joined :: proc(cmd: ^Command, sep: byte) -> string {
	if len(cmd.aliases) == 0 do return cmd.name
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, cmd.name)
	for alias in cmd.aliases {
		strings.write_byte(&sb, sep)
		strings.write_string(&sb, alias)
	}
	return strings.to_string(sb)
}
