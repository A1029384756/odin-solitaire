package main

import "vendor:glfw"
set_vsync :: proc(on: bool) {
	glfw.SwapInterval(i32(on))
}
