package main

import rl "vendor:raylib"

set_vsync :: proc(on: bool) {
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))
}
