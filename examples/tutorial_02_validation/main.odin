package tutorial_02_validation

import "core:fmt"
import "core:os"
import "../../cli"

// Enum fields are auto-detected — valid values are shown in help output.
Environment :: enum {
	Staging,
	Production,
}

Options :: struct {
	// Mutually exclusive: pick one target with an XOR group.
	staging:    bool   `args:"short=s,xor=target" usage:"Deploy to staging"`,
	production: bool   `args:"short=p,xor=target" usage:"Deploy to production"`,

	// Range validation: replicas must be between 1 and 100.
	replicas: int      `args:"short=r,min=1,max=100" usage:"Number of replicas (1-100)"`,

	// Path validation: config file must exist on disk.
	config: string     `args:"short=c,file_exists" usage:"Path to deploy config file"`,

	// Enum flag: only valid enum values are accepted.
	env: Environment   `args:"short=e" usage:"Target environment"`,

	// A plain flag with a short alias.
	dry_run: bool      `args:"short=d" usage:"Simulate without deploying"`,
}

main :: proc() {
	options: Options

	// Use panels to organize help into logical sections.
	cli.parse_or_exit(
		&options,
		os.args,
		description = "Deploy your application to the cloud.",
		version = "1.0.0",
		panel_config = {
			cli.Panel{name = "Target", fields = {"staging", "production", "env"}},
			cli.Panel{name = "Scaling", fields = {"replicas"}},
		},
	)

	target := "staging" if options.staging else "production" if options.production else "default"
	fmt.printfln("Deploying to %s (env=%v, replicas=%d)", target, options.env, options.replicas)
	if len(options.config) > 0 do fmt.printfln("  Config: %s", options.config)
	if options.dry_run do fmt.println("  (dry run — nothing deployed)")
}
