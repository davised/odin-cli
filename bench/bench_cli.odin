package bench

import "../cli"

cli_scenarios :: proc() -> []Bench_Scenario {
	@(static) scenarios := [?]Bench_Scenario {
		{
			name       = "cli/simple_help (5 flags)",
			iterations = 1_000,
			bench_proc = bench_cli_simple,
		},
		{
			name       = "cli/complex_help (15 flags)",
			iterations = 500,
			bench_proc = bench_cli_complex,
		},
	}
	return scenarios[:]
}

Simple_Flags :: struct {
	output:  string `args:"name=output,short=o" usage:"Output file path"`,
	verbose: bool   `args:"name=verbose,short=v" usage:"Enable verbose output"`,
	count:   int    `args:"name=count,short=c" usage:"Number of items"`,
	format:  string `args:"name=format,short=f" usage:"Output format"`,
	quiet:   bool   `args:"name=quiet,short=q" usage:"Suppress output"`,
}

Output_Format :: enum {
	Json,
	Yaml,
	Toml,
	Csv,
	Xml,
}

Log_Level :: enum {
	Trace,
	Debug,
	Info,
	Warn,
	Error,
}

Complex_Flags :: struct {
	// I/O options
	input:     string        `args:"name=input,short=i" usage:"Input file path"`,
	output:    string        `args:"name=output,short=o" usage:"Output file path"`,
	format:    Output_Format `args:"name=format,short=f" usage:"Output format"`,
	append:    bool          `args:"name=append,short=a" usage:"Append to output"`,
	overwrite: bool          `args:"name=overwrite" usage:"Overwrite existing files"`,

	// Processing
	jobs:      int           `args:"name=jobs,short=j" usage:"Number of parallel jobs"`,
	timeout:   int           `args:"name=timeout,short=t" usage:"Timeout in seconds"`,
	retries:   int           `args:"name=retries" usage:"Number of retries on failure"`,
	batch:     int           `args:"name=batch-size" usage:"Batch size for processing"`,
	compress:  bool          `args:"name=compress" usage:"Compress output"`,

	// Logging
	verbose:   bool          `args:"name=verbose,short=v" usage:"Enable verbose logging"`,
	quiet:     bool          `args:"name=quiet,short=q" usage:"Suppress all output"`,
	log_level: Log_Level     `args:"name=log-level" usage:"Logging level"`,
	log_file:  string        `args:"name=log-file" usage:"Log output file"`,
	color:     bool          `args:"name=color" usage:"Force colored output"`,
}

@(private = "file")
bench_cli_simple :: proc(state: ^Bench_State) {
	cli.write_help(
		state.writer,
		Simple_Flags,
		"mybench",
		cli.Help_Config{
			mode      = .Plain,
			max_width = 80,
		},
	)
}

@(private = "file")
bench_cli_complex :: proc(state: ^Bench_State) {
	cli.write_help(
		state.writer,
		Complex_Flags,
		"mybench",
		cli.Help_Config{
			mode         = .Plain,
			max_width    = 100,
			description  = "A complex CLI tool for benchmarking purposes.",
			version      = "2.1.0",
			panel_config = {
				cli.Panel{name = "I/O Options", fields = {"input", "output", "format", "append", "overwrite"}},
				cli.Panel{name = "Processing", fields = {"jobs", "timeout", "retries", "batch", "compress"}},
				cli.Panel{name = "Logging", fields = {"verbose", "quiet", "log_level", "log_file", "color"}},
			},
		},
	)
}
