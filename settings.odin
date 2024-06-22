package main

import "core:fmt"
import "core:math"
import "vendor:glfw"
import rl "vendor:raylib"

Settings :: struct {
	menu_visible:  bool,
	menu_fade:     f32,
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
	settings.menu_fade =
		settings.menu_fade + 2 * rl.GetFrameTime() if settings.menu_fade < 1 else 1
	anim: f32
	if settings.menu_visible {
		anim = ease_out_quint(settings.menu_fade)
	} else {
		anim = 1 - ease_out_quint(settings.menu_fade)
	}

	rl.DrawRectangle(
		0,
		0,
		i32(state.resolution.x),
		i32(state.resolution.y),
		{0x1F, 0x1F, 0x1, u8(0x5F * settings.menu_fade) * u8(settings.menu_visible)},
	)

	layout := Panel_Layout {
		size             = units_to_px(state.resolution / state.unit_to_px_scaling - {60, 60}),
		max_width        = units_to_px({1200, 0}).x,
		min_width        = units_to_px({400, 0}).x,
		padding          = 10 * settings.render_scale,
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
	layout.pos =
		{state.resolution.x / 2 - layout.size.x / 2, 0} + units_to_px({0, 30 - 2000 * (1 - anim)})

	panel_background(&layout)
	panel_title(&layout, "Settings")
	panel_row(&layout, "Performance")
	perf_str := fmt.ctprintf("Show FPS: %s", "On" if settings.show_perf else "Off")
	if panel_button(&layout, perf_str) {settings.show_perf = !settings.show_perf}
	panel_row(&layout, "Render Scale")
	if panel_slider(&layout, &settings.render_scale, 0.7, 2) {settings.scale_changed = true}

	vsync_str := fmt.ctprintf("VSync: %s", "On" if settings.vsync else "Off")
	if panel_button(&layout, vsync_str) {
		settings.vsync = !settings.vsync
		glfw.SwapInterval(i32(settings.vsync))
	}

	panel_row(&layout, "Difficulty")
	panel_stepper(&layout, "Easy;Random", cast(^i32)&settings.difficulty, 0, 1)

	panel_row(&layout, "Background Hue")
	panel_slider(&layout, &settings.hue_shift, 0, 2 * math.PI)

	if panel_button(&layout, "Exit") {
		settings.menu_visible = false
		settings.menu_fade = 0
	}
}
