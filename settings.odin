package main

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
}
