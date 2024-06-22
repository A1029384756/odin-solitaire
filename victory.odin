package main

import rl "vendor:raylib"

victory_screen :: proc() {
	state.fade_in = state.fade_in + rl.GetFrameTime() if state.fade_in < 1 else 1
	anim := ease_out_elastic(state.fade_in)

	rl.DrawRectangle(
		0,
		0,
		i32(state.resolution.x),
		i32(state.resolution.y),
		{0x1F, 0x1F, 0x1, u8(0x5F * state.fade_in)},
	)

	centered_text("YOU WIN!", 60, state.resolution / 2, rl.WHITE)

	button_px := units_to_px({500, 150})
	if text_button(
		   {
			   state.resolution.x / 2 - button_px.x / 2,
			   anim * state.resolution.y / 2 - button_px.y / 2 + 200 * state.unit_to_px_scaling.y,
			   button_px.x,
			   button_px.y,
		   },
		   "RESTART",
		   rl.WHITE,
		   rl.LIGHTGRAY,
		   rl.SKYBLUE,
		   60,
	   ) &&
	   state.fade_in == 1 {
		init_state(&state)
	}
}
