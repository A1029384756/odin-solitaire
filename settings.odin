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

	show_fps := units_to_px({300, 75})
	if text_button(
		   {
			   state.resolution.x / 2 - show_fps.x / 2,
			   anim * state.resolution.y / 2 - show_fps.y / 2 - 150 * state.unit_to_px_scaling.y,
			   show_fps.x,
			   show_fps.y,
		   },
		   "Show FPS",
		   rl.DARKGRAY,
		   rl.LIGHTGRAY,
		   rl.SKYBLUE,
		   40,
	   ) &&
	   settings.menu_fade_in == 1 {
		settings.show_perf = !settings.show_perf
	}

	select_diffuculty := units_to_px({300, 75})
	if dropdown(
		   {
			   state.resolution.x / 2 - select_diffuculty.x / 2,
			   anim * state.resolution.y / 2 -
			   select_diffuculty.y / 2 -
			   300 * state.unit_to_px_scaling.y,
			   show_fps.x,
			   show_fps.y,
		   },
		   "Easy;Random",
		   cast(^i32)&settings.difficulty,
		   state.diff_menu_edit,
	   ) &&
	   settings.menu_fade_in == 1 {
		state.diff_menu_edit = !state.diff_menu_edit
	}

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
		   rl.LIGHTGRAY,
		   rl.SKYBLUE,
		   60,
	   ) &&
	   settings.menu_fade_in == 1 {
		settings.menu_visible = false
	}

	layout := Panel_Layout {
		pos              = units_to_px({30, 30}),
		size             = units_to_px(state.resolution / state.unit_to_px_scaling - {60, 60}),
		padding          = 10,
		background_color = rl.DARKGRAY,
		title_color      = rl.WHITE,
		title_font_size  = 40,
		body_color       = rl.LIGHTGRAY,
		body_font_size   = 20,
		button_text      = rl.LIGHTGRAY,
		button_bg        = rl.GRAY,
		button_highlight = rl.SKYBLUE,
	}
	panel_init(&layout)

	panel_background(&layout)
	panel_title(&layout, "Test Panel")
	panel_row(&layout, "demo text 1")
	panel_row(&layout, "demo text 2")
	panel_button(&layout, "demo_button 1")
	panel_button(&layout, "demo_button 2")
}
