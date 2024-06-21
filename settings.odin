package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Settings :: struct {
	menu_visible:  bool,
	menu_fade_in:  f32,
	vsync:         bool,
	render_scale:  f32,
	scale_changed: bool,
	hue_shift:     f32,
	show_perf:     bool,
	difficulty:    enum {
		EASY   = 0,
		RANDOM = 1,
	},
}

settings_menu :: proc() {
	settings.menu_fade_in =
		settings.menu_fade_in + rl.GetFrameTime() if settings.menu_fade_in < 1 else 1
	anim := ease_out_elastic(settings.menu_fade_in)

	rl.DrawRectangle(
		0,
		0,
		i32(state.resolution.x),
		i32(state.resolution.y),
		{0x1F, 0x1F, 0x1, u8(0x5F * settings.menu_fade_in)},
	)

	slider_px := units_to_px({0, 150})
	slider_size := units_to_px({300, 20})
	slider(
		{
			state.resolution.x / 2 - slider_size.x / 2,
			anim * slider_px.y,
			slider_size.x,
			slider_size.y,
		},
		&settings.hue_shift,
		0,
		2 * math.PI,
	)

	button_px := units_to_px({500, 150})
	if text_button(
		   {
			   state.resolution.x / 2 - button_px.x / 2,
			   anim * state.resolution.y / 2 - button_px.y / 2 + 200 * state.unit_to_px_scaling.y,
			   button_px.x,
			   button_px.y,
		   },
		   "Exit",
		   rl.DARKGRAY,
		   60,
	   ) &&
	   settings.menu_fade_in == 1 {
		settings.menu_visible = false
	}
}
