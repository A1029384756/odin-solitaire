package main

import "core:c"

@(link_name = SwapInterval)
glfw_swap_interval :: proc(val: c.int) ---

set_vsync :: proc(on: bool) {
	glfw_swap_interval(i32(on))
	// target := rl.GetMonitorRefreshRate(0) if on else max(i32)
	// rl.SetTargetFPS(target)
}
