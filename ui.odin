package main

import "core:math"
import "core:strings"
import k2 "karl2d"

gui_locked := false
icon_button :: proc(
	rect: k2.Rect,
	icon: Icon,
	icon_color: k2.Color,
	icon_scale: f32 = 2,
	border_width: f32 = 3,
) -> bool {
	clicked: bool

	if !gui_locked && k2.point_in_rect(units_to_px(state.mouse_pos), rect) {
		if k2.mouse_button_went_up(.Left) {clicked = true} else {k2.draw_rect(rect, k2.RL_SKYBLUE)}
	} else {
		k2.draw_rect(rect, k2.LIGHT_GRAY)
	}
	k2.draw_rect_outline(rect, 3, k2.DARK_GRAY)

	k2.draw_texture_fit(ICONS, icon_rect[icon], rect, tint = k2.DARK_GRAY)
	return clicked
}

text_button :: proc(
	rect: k2.Rect,
	text: string,
	text_color, bg_color, highlight_color: k2.Color,
	font_size: f32,
	border_width: f32 = 0,
	border_color: k2.Color = 0,
) -> bool {
	clicked := false
	if !gui_locked && k2.point_in_rect(units_to_px(state.mouse_pos), rect) {
		if k2.mouse_button_went_up(
			.Left,
		) {clicked = true} else {k2.draw_rect(rect, highlight_color)}
	} else {
		k2.draw_rect(rect, bg_color)
	}
	k2.draw_rect_outline(rect, border_width, border_color)
	centered_text(text, font_size, {rect.x, rect.y} + {rect.w, rect.h} / 2, text_color)
	return clicked
}

centered_text :: proc(
	message: string,
	size: f32,
	pos: Vector2,
	color: k2.Color,
	center_vert: bool = true,
) -> Vector2 {
	width := k2.measure_text(message, size * state.unit_to_px_scaling.x)
	text_pos := pos - width / 2 if center_vert else pos - {width.x / 2, 0}
	return text(message, size, text_pos, color)
}

text :: proc(message: string, size: f32, pos: Vector2, color: k2.Color) -> Vector2 {
	k2.draw_text(message, pos, size * state.unit_to_px_scaling.x, color)
	return k2.measure_text(message, size * state.unit_to_px_scaling.x)
}

slider :: proc(bounds: k2.Rect, value: ^f32, min, max: f32) -> bool {
	k2.draw_rect(bounds, k2.LIGHT_GRAY)
	k2.draw_rect_outline(bounds, 1, k2.DARK_GRAY)
	k2.draw_rect(
		{
			math.remap(value^, min, max, bounds.x, bounds.x + bounds.w - bounds.h),
			bounds.y,
			bounds.h,
			bounds.h,
		},
		k2.RL_LIME,
	)

	if !gui_locked && k2.point_in_rect(units_to_px(state.mouse_pos), bounds) {
		if k2.mouse_button_is_held(.Left) {
			value^ = math.remap(
				units_to_px(state.mouse_pos).x,
				bounds.x,
				bounds.x + bounds.w,
				min,
				max,
			)
			return true
		}
	}
	return false
}

dropdown :: proc(bounds: k2.Rect, text: string, active: ^i32, editing: bool) -> bool {
	options := strings.split(text, ";", context.temp_allocator)

	if text_button(bounds, options[active^], k2.DARK_GRAY, k2.LIGHT_BLUE, k2.RL_SKYBLUE, 20) {
		return true
	}

	if editing {
		for option, idx in options {
			box := k2.Rect{bounds.x, bounds.y + f32(idx + 1) * bounds.h, bounds.w, bounds.h}
			if text_button(box, option, k2.DARK_GRAY, k2.LIGHT_GRAY, k2.RL_SKYBLUE, 15, 1) {
				active^ = i32(idx)
				return true
			}
		}
	}
	return false
}

stepper :: proc(
	bounds: k2.Rect,
	text: string,
	text_size: f32,
	active: ^i32,
	min, max: i32,
	fg, bg, inactive: k2.Color,
) {
	mouse_pos := units_to_px(state.mouse_pos)
	options := strings.split(text, ";", context.temp_allocator)
	k2.draw_rect(bounds, bg)

	left, right: bool
	if k2.point_in_rect(mouse_pos, bounds) {
		left = mouse_pos.x < bounds.x + bounds.w / 2 && active^ > min
		right = mouse_pos.x > bounds.x + bounds.w / 2 && active^ < max
	}

	k2.draw_texture_fit(
		ICONS,
		icon_rect[.BACK],
		{bounds.x, bounds.y, bounds.h, bounds.h},
		0,
		0,
		inactive if active^ == min else fg,
	)
	k2.draw_texture_fit(
		ICONS,
		icon_rect[.FORWARD],
		{bounds.x + bounds.w - bounds.h, bounds.y, bounds.h, bounds.h},
		0,
		0,
		inactive if active^ == max else fg,
	)
	centered_text(
		options[active^],
		text_size,
		{bounds.x + bounds.w / 2, bounds.y + bounds.h / 2},
		fg,
	)
	if k2.mouse_button_went_up(.Left) && k2.point_in_rect(mouse_pos, bounds) {
		if mouse_pos.x < bounds.x + bounds.w / 2 && active^ > min {
			active^ -= 1
		} else if mouse_pos.x > bounds.x + bounds.w / 2 && active^ < max {
			active^ += 1
		}
	}
}

Panel_Layout :: struct {
	pos:                      Vector2,
	size:                     Vector2,
	padding:                  f32,
	max_width:                f32,
	min_width:                f32,
	// background
	background_color:         k2.Color,
	background_outline_color: k2.Color,
	background_outline:       f32,
	// text info
	title_color:              k2.Color,
	title_font_size:          f32,
	body_color:               k2.Color,
	body_font_size:           f32,
	// button info
	button_bg:                k2.Color,
	button_highlight:         k2.Color,
	button_text:              k2.Color,
	// private
	_row_height:              f32,
}

panel_init :: proc(panel: ^Panel_Layout) {
	text_size := k2.measure_text("a", panel.body_font_size * state.unit_to_px_scaling.x)
	panel.size.x = clamp(panel.size.x, panel.min_width, panel.max_width)
	panel._row_height = text_size.y
}

panel_background :: proc(panel: ^Panel_Layout) {
	k2.draw_rect({panel.pos.x, panel.pos.y, panel.size.x, panel.size.y}, panel.background_color)

	k2.draw_rect_outline(
		{panel.pos.x, panel.pos.y, panel.size.x, panel.size.y},
		panel.background_outline,
		panel.background_outline_color,
	)
}

panel_title :: proc(panel: ^Panel_Layout, title: string) {
	panel.pos.y += panel.padding

	loc := Vector2{panel.pos.x + panel.size.x / 2, panel.pos.y}
	title_size := centered_text(title, panel.title_font_size, loc, panel.title_color, false)

	panel.pos.y += title_size.y + panel.padding
}

panel_row :: proc(panel: ^Panel_Layout, row_text: string, centered: bool = false) {
	if centered {
		loc := Vector2{panel.pos.x + panel.size.x / 2, panel.pos.y}
		centered_text(row_text, panel.body_font_size, loc, panel.body_color, false)
	} else {
		loc := Vector2{panel.pos.x + panel.padding, panel.pos.y}
		text(row_text, panel.body_font_size, loc, panel.body_color)
	}

	panel.pos.y += panel._row_height + panel.padding
}

panel_button :: proc(panel: ^Panel_Layout, button_text: string) -> bool {
	button := text_button(
		{
			panel.pos.x + panel.padding,
			panel.pos.y,
			panel.size.x - 2 * panel.padding,
			panel._row_height + 2 * panel.padding,
		},
		button_text,
		panel.button_text,
		panel.button_bg,
		panel.button_highlight,
		panel.body_font_size,
	)

	panel.pos.y += panel._row_height + 3 * panel.padding
	return button
}

panel_slider :: proc(panel: ^Panel_Layout, value: ^f32, min, max: f32) -> bool {
	result := slider(
		{
			panel.pos.x + panel.padding,
			panel.pos.y,
			panel.size.x - 2 * panel.padding,
			panel._row_height + 2 * panel.padding,
		},
		value,
		min,
		max,
	)
	panel.pos.y += panel._row_height + 3 * panel.padding
	return result
}

panel_dropdown :: proc(panel: ^Panel_Layout, text: string, active: ^i32, editing: bool) -> bool {
	menu := dropdown(
		{
			panel.pos.x + panel.padding,
			panel.pos.y,
			panel.size.x - 2 * panel.padding,
			panel._row_height + 2 * panel.padding,
		},
		text,
		active,
		editing,
	)
	panel.pos.y += panel._row_height + 3 * panel.padding
	return menu
}

panel_stepper :: proc(panel: ^Panel_Layout, text: string, active: ^i32, min, max: i32) {
	stepper(
		{
			panel.pos.x + panel.padding,
			panel.pos.y,
			panel.size.x - 2 * panel.padding,
			panel._row_height + 2 * panel.padding,
		},
		text,
		panel.body_font_size,
		active,
		min,
		max,
		panel.title_color,
		panel.background_color,
		panel.body_color,
	)

	panel.pos.y += panel._row_height + 3 * panel.padding
}
