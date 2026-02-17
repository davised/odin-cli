package prof

import "core:prof/spall"

ENABLED :: #config(ENABLE_SPALL, false)

@(private = "file")
ctx: spall.Context

@(private = "file")
buffer: spall.Buffer

@(private = "file")
backing: ^[spall.BUFFER_DEFAULT_SIZE]u8

init :: proc() {
	when ENABLED {
		backing = new([spall.BUFFER_DEFAULT_SIZE]u8)
		ctx = spall.context_create_with_scale("bench.spall", false, 1)
		buffer = spall.buffer_create(backing[:])
	}
}

destroy :: proc() {
	when ENABLED {
		spall.buffer_destroy(&ctx, &buffer)
		spall.context_destroy(&ctx)
		free(backing)
	}
}

@(no_instrumentation)
begin :: proc "contextless" (name: string) {
	when ENABLED {
		spall._buffer_begin(&ctx, &buffer, name)
	}
}

@(no_instrumentation)
end :: proc "contextless" () {
	when ENABLED {
		spall._buffer_end(&ctx, &buffer)
	}
}
