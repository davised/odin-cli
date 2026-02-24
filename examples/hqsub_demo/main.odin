package hqsub_demo

import "core:fmt"
import "core:os"
import "../../cli"

// --- Global flags (shared across all subcommands) ---

Global_Flags :: struct {
	verbose: int    `args:"short=v,count"   usage:"Increase verbosity (-v, -vv, -vvv)"`,
	config:  string `args:"short=c,env=HQSUB_CONFIG" usage:"Path to config file"`,
	cluster: string `args:"env=HQSUB_CLUSTER"        usage:"Target cluster name"`,
	plain: bool  `usage:"Disable colored output"`,
}

// --- submit subcommand ---

Priority :: enum {
	Low,
	Normal,
	High,
	Urgent,
}

Output_Format :: enum {
	Text,
	Json,
	Yaml,
}

Submit_Flags :: struct {
	script:    string   `args:"pos=0,required" usage:"Job script to submit"`,
	name:      string   `args:"short=n,required" usage:"Job name (must be unique within the cluster queue)"`,
	queue:     string   `args:"short=q" usage:"Target queue to submit the job to"`,
	priority:  Priority `args:"short=p" usage:"Job priority level within the queue"`,
	cpus:      int      `args:"short=j,min=0,panel=Resources" usage:"Number of CPU cores to allocate for this job"`,
	memory:    string   `args:"short=m,panel=Resources" usage:"Memory limit per node (e.g. 4G, 512M). Jobs exceeding this limit will be killed by the scheduler."`,
	gpus:      int      `args:"min=0,panel=Resources" usage:"Number of GPUs to allocate. Requires a GPU-enabled queue."`,
	wall_time: string   `args:"short=t,panel=Resources" usage:"Maximum wall time for the job (e.g. 2h, 30m). Jobs running longer than this will be terminated."`,
	output:    string   `args:"short=o,panel=I/O" usage:"Path for stdout log file. Supports substitution patterns like %j (job ID) and %N (node name)."`,
	error_log: string   `args:"short=e,name=error,panel=I/O" usage:"Path for stderr log file. Defaults to the same path as stdout if not specified."`,
	notify:    string   `args:"env=HQSUB_NOTIFY,panel=I/O" usage:"Email address for job lifecycle notifications (begin, end, fail)"`,
	dry_run:   bool     `args:"short=d" usage:"Validate the job specification and print what would be submitted without actually submitting"`,
	wait:      bool     `args:"short=w" usage:"Block until the job completes and return its exit code"`,
	json:      bool     `args:"xor=output-fmt" usage:"Output as JSON"`,
	yaml:      bool     `args:"xor=output-fmt" usage:"Output as YAML"`,
	array:     string   `args:"panel=Advanced" usage:"Submit as an array job with the given range (e.g. 1-100, 1-50:5 for step size). Each array task runs independently."`,
	depend:    string   `args:"panel=Advanced" usage:"Job dependency expression (e.g. afterok:12345, afterany:12345:12346). Job will not start until dependencies are satisfied."`,
	image:     string   `args:"env=HQSUB_IMAGE,panel=Advanced" usage:"Container image for the job (e.g. docker://ubuntu:22.04). Requires container runtime on the cluster."`,
}

submit_action :: proc(flags: ^Submit_Flags, program: string) -> int {
	fmt.printfln("Submitting job '%s' from script '%s'", flags.name, flags.script)
	fmt.printfln("  Queue: %s, CPUs: %d, Memory: %s", flags.queue, flags.cpus, flags.memory)
	if flags.dry_run do fmt.println("  (dry run - not actually submitted)")
	return 0
}

// --- status subcommand ---

Status_Flags :: struct {
	job_id: string       `args:"pos=0" usage:"Job ID (omit for all jobs)"`,
	format: Output_Format `args:"short=f" usage:"Output format"`,
	all:    bool          `args:"short=a" usage:"Show all jobs including completed"`,
	user:   string        `args:"short=u,env=USER" usage:"Filter by user"`,
	queue:  string        `args:"short=q" usage:"Filter by queue"`,
	watch:  bool          `args:"short=w" usage:"Watch mode (refresh every 2s)"`,
	limit:  int           `args:"short=l" usage:"Max number of jobs to display"`,
}

status_action :: proc(flags: ^Status_Flags, program: string) -> int {
	if len(flags.job_id) > 0 {
		fmt.printfln("Status for job %s (format=%v)", flags.job_id, flags.format)
	} else {
		fmt.printfln("Listing jobs (all=%v, user=%s)", flags.all, flags.user)
	}
	return 0
}

// --- cancel subcommand ---

Cancel_Flags :: struct {
	job_ids: string `args:"pos=0,required" usage:"Job ID(s) to cancel (comma-separated or 'all')"`,
	force:   bool   `args:"short=f" usage:"Force immediate termination (SIGKILL)"`,
	signal:  string `args:"short=s" usage:"Signal to send (default: SIGTERM)"`,
	reason:  string `args:"short=r" usage:"Cancellation reason (logged)"`,
}

cancel_action :: proc(flags: ^Cancel_Flags, program: string) -> int {
	fmt.printfln("Cancelling job(s): %s", flags.job_ids)
	if flags.force do fmt.println("  (force kill)")
	return 0
}

// --- logs subcommand ---

Logs_Flags :: struct {
	job_id: string `args:"pos=0,required" usage:"Job ID"`,
	follow: bool   `args:"short=f" usage:"Follow log output (like tail -f)"`,
	stderr: bool   `usage:"Show stderr instead of stdout"`,
	tail:   int    `args:"short=n" usage:"Number of lines from end"`,
}

logs_action :: proc(flags: ^Logs_Flags, program: string) -> int {
	stream := "stderr" if flags.stderr else "stdout"
	fmt.printfln("Showing %s for job %s (follow=%v)", stream, flags.job_id, flags.follow)
	return 0
}

main :: proc() {
	global: Global_Flags

	app := cli.make_app(
		"hqsub",
		description = "HPC job submission and management tool.",
		version = "3.2.1",
	)
	cli.set_global_flags(&app, Global_Flags, &global)

	cli.add_command(&app, Submit_Flags, "submit",
		description = "Submit a new job to the cluster",
		action = submit_action,
		aliases = {"sub", "s"},
		epilog = "Examples:\n  hqsub submit job.sh -n myjob -j 4 -m 8G\n  hqsub submit --dry-run job.sh -n test -q gpu --gpus=2",
	)

	cli.add_command(&app, Status_Flags, "status",
		description = "Show job status",
		action = status_action,
		aliases = {"st"},
	)

	cli.add_command(&app, Cancel_Flags, "cancel",
		description = "Cancel running jobs",
		action = cancel_action,
		aliases = {"kill", "rm"},
	)

	cli.add_command(&app, Logs_Flags, "logs",
		description = "View job output logs",
		action = logs_action,
		aliases = {"log", "l"},
	)

	code := cli.run(&app, os.args)
	cli.destroy_app(&app)
	os.exit(code)
}
