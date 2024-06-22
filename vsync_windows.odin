package main

import rl "vendor:raylib"

set_vsync :: proc(on: bool) {
	target := rl.GetMonitorRefreshRate(0) if on else max(i32)
	rl.SetTargetFPS(target)
}
