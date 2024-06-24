package main

import "core:mem"
import "core:os"
import "core:strings"
import "vendor:glfw"

set_vsync :: proc(on: bool) {
	glfw.SwapInterval(i32(on))
}

get_config_dir :: proc(
	subfolder: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> string {
	context.allocator = allocator
	sub: string = strings.trim(subfolder, "/")
	sub = strings.to_lower_camel_case(sub)
	dir := os.get_env("XDG_CACHE_HOME")
	dir = strings.concatenate({dir, "/.config"})
	if dir != "" {
		dir = strings.concatenate({dir, "/", sub})
	}

	return dir
}
