package main

import "core:c"
import "core:mem"
import "core:os"
import "core:strings"

foreign import glfw_ {
  "glfw3_mt.lib"
}

@(default_calling_convention="c", link_prefix="glfw")
foreign glfw_ {
  SwapInterval :: proc(val: c.int) ---
}

set_vsync :: proc(on: bool) {
  SwapInterval(i32(on))
}

get_config_dir :: proc(
	subfolder: string,
	allocator: mem.Allocator = context.temp_allocator,
) -> string {
	context.allocator = allocator

	sub: string = strings.trim(subfolder, "/")
	sub = strings.to_lower_camel_case(sub)
	dir := os.get_env("LocalAppData")
	if dir != "" {
		dir = strings.concatenate({dir, "/", sub})
	}

	return dir
}
