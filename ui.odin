package main

import "core:math"
import "core:strings"
import rl "vendor:raylib"

icon_button :: proc(
	rect: rl.Rectangle,
	icon: Icon,
	icon_color: rl.Color,
	icon_scale: f32 = 2,
	border_width: f32 = 3,
) -> bool {
	clicked: bool

	if !rl.GuiIsLocked() && rl.CheckCollisionPointRec(units_to_px(state.mouse_pos), rect) {
		if rl.IsMouseButtonReleased(
			.LEFT,
		) {clicked = true} else {rl.DrawRectangleRec(rect, rl.SKYBLUE)}
	} else {
		rl.DrawRectangleRec(rect, rl.LIGHTGRAY)
	}
	rl.DrawRectangleLinesEx(rect, 3, rl.DARKGRAY)

	rl.BeginBlendMode(.ALPHA)
	rl.DrawTexturePro(ICONS, icon_rect[icon], rect, 0, 0, rl.DARKGRAY)
	rl.EndBlendMode()
	return clicked
}

text_button :: proc(
	rect: rl.Rectangle,
	text: cstring,
	text_color, bg_color, highlight_color: rl.Color,
	font_size: f32,
	border_width: f32 = 0,
	border_color: rl.Color = 0,
) -> bool {
	clicked := false
	if !rl.GuiIsLocked() && rl.CheckCollisionPointRec(units_to_px(state.mouse_pos), rect) {
		if rl.IsMouseButtonReleased(
			.LEFT,
		) {clicked = true} else {rl.DrawRectangleRec(rect, highlight_color)}
	} else {
		rl.DrawRectangleRec(rect, bg_color)
	}
	rl.DrawRectangleLinesEx(rect, border_width, border_color)
	centered_text(text, font_size, {rect.x, rect.y} + {rect.width, rect.height} / 2, text_color)
	return clicked
}

centered_text :: proc(
	message: cstring,
	size: f32,
	pos: Vector2,
	color: rl.Color,
	center_vert: bool = true,
) -> Vector2 {
	width := rl.MeasureTextEx(
		rl.GetFontDefault(),
		message,
		size * state.unit_to_px_scaling.x,
		5 * settings.render_scale,
	)

	text_pos := pos - width / 2 if center_vert else pos - {width.x / 2, 0}
	return text(message, size, text_pos, color)
}

text :: proc(message: cstring, size: f32, pos: Vector2, color: rl.Color) -> Vector2 {
	rl.DrawText(message, i32(pos.x), i32(pos.y), i32(size * state.unit_to_px_scaling.x), color)
	return rl.MeasureTextEx(
		rl.GetFontDefault(),
		message,
		size * state.unit_to_px_scaling.x,
		5 * settings.render_scale,
	)
}

slider :: proc(bounds: rl.Rectangle, value: ^f32, min, max: f32) -> bool {
	rl.DrawRectangleRec(bounds, rl.LIGHTGRAY)
	rl.DrawRectangleLinesEx(bounds, 1, rl.DARKGRAY)
	rl.DrawRectangle(
		i32(math.remap(value^, min, max, bounds.x, bounds.x + bounds.width - bounds.height)),
		i32(bounds.y),
		i32(bounds.height),
		i32(bounds.height),
		rl.LIME,
	)

	if !rl.GuiIsLocked() && rl.CheckCollisionPointRec(units_to_px(state.mouse_pos), bounds) {
		if rl.IsMouseButtonDown(.LEFT) {
			value^ = math.remap(
				units_to_px(state.mouse_pos).x,
				bounds.x,
				bounds.x + bounds.width,
				min,
				max,
			)
			return true
		}
	}
	return false
}

dropdown :: proc(bounds: rl.Rectangle, text: string, active: ^i32, editing: bool) -> bool {
	options := strings.split(text, ";", context.temp_allocator)

	current_option := strings.clone_to_cstring(options[active^], context.temp_allocator)

	if text_button(bounds, current_option, rl.DARKGRAY, rl.LIGHTGRAY, rl.SKYBLUE, 20) {
		return true
	}

	if editing {
		for option, idx in options {
			box := rl.Rectangle {
				bounds.x,
				bounds.y + f32(idx + 1) * bounds.height,
				bounds.width,
				bounds.height,
			}

			option := strings.clone_to_cstring(option, context.temp_allocator)

			if text_button(box, option, rl.DARKGRAY, rl.LIGHTGRAY, rl.SKYBLUE, 15, 1) {
				active^ = i32(idx)
				return true
			}
		}
	}
	return false
}

stepper :: proc(
	bounds: rl.Rectangle,
	text: string,
	text_size: f32,
	active: ^i32,
	min, max: i32,
	fg, bg, inactive: rl.Color,
) {
	mouse_pos := units_to_px(state.mouse_pos)
	options := strings.split(text, ";", context.temp_allocator)
	current_option := strings.clone_to_cstring(options[active^], context.temp_allocator)

	rl.DrawRectangleRec(bounds, bg)

	if rl.CheckCollisionPointRec(mouse_pos, bounds) {
		if mouse_pos.x < bounds.x + bounds.width / 2 && active^ > min {
			rl.DrawRectangleGradientEx(
				{bounds.x, bounds.y, bounds.width / 2, bounds.height},
				inactive,
				inactive,
				bg,
				bg,
			)
		}
		if mouse_pos.x > bounds.x + bounds.width / 2 && active^ < max {
			rl.DrawRectangleGradientEx(
				{bounds.x + bounds.width / 2, bounds.y, bounds.width / 2, bounds.height},
				bg,
				bg,
				inactive,
				inactive,
			)
		}
	}

	rl.DrawTexturePro(
		ICONS,
		icon_rect[.BACK],
		{bounds.x, bounds.y, bounds.height, bounds.height},
		0,
		0,
		inactive if active^ == min else fg,
	)
	rl.DrawTexturePro(
		ICONS,
		icon_rect[.FORWARD],
		{bounds.x + bounds.width - bounds.height, bounds.y, bounds.height, bounds.height},
		0,
		0,
		inactive if active^ == max else fg,
	)
	centered_text(
		current_option,
		text_size,
		{bounds.x + bounds.width / 2, bounds.y + bounds.height / 2},
		fg,
	)
	if rl.IsMouseButtonReleased(.LEFT) && rl.CheckCollisionPointRec(mouse_pos, bounds) {
		if mouse_pos.x < bounds.x + bounds.width / 2 && active^ > min {
			active^ -= 1
		} else if mouse_pos.x > bounds.x + bounds.width / 2 && active^ < max {
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
	background_color:         rl.Color,
	background_outline_color: rl.Color,
	background_outline:       f32,
	// text info
	title_color:              rl.Color,
	title_font_size:          f32,
	body_color:               rl.Color,
	body_font_size:           f32,
	// button info
	button_bg:                rl.Color,
	button_highlight:         rl.Color,
	button_text:              rl.Color,
	// private
	_row_height:              f32,
}

panel_init :: proc(panel: ^Panel_Layout) {
	text_size := rl.MeasureTextEx(
		rl.GetFontDefault(),
		"a",
		panel.body_font_size * state.unit_to_px_scaling.x,
		5 * settings.render_scale,
	)
	panel.size.x = clamp(panel.size.x, panel.min_width, panel.max_width)
	panel._row_height = text_size.y
}

panel_background :: proc(panel: ^Panel_Layout) {
	rl.DrawRectangleRec(
		{panel.pos.x, panel.pos.y, panel.size.x, panel.size.y},
		panel.background_color,
	)

	rl.DrawRectangleLinesEx(
		{panel.pos.x, panel.pos.y, panel.size.x, panel.size.y},
		panel.background_outline,
		panel.background_outline_color,
	)
}

panel_title :: proc(panel: ^Panel_Layout, title: cstring) {
	panel.pos.y += panel.padding

	loc := Vector2{panel.pos.x + panel.size.x / 2, panel.pos.y}
	title_size := centered_text(title, panel.title_font_size, loc, panel.title_color, false)

	panel.pos.y += title_size.y + panel.padding
}

panel_row :: proc(panel: ^Panel_Layout, row_text: cstring, centered: bool = false) {
	if centered {
		loc := Vector2{panel.pos.x + panel.size.x / 2, panel.pos.y}
		centered_text(row_text, panel.body_font_size, loc, panel.body_color, false)
	} else {
		loc := Vector2{panel.pos.x + panel.padding, panel.pos.y}
		text(row_text, panel.body_font_size, loc, panel.body_color)
	}

	panel.pos.y += panel._row_height + panel.padding
}

panel_button :: proc(panel: ^Panel_Layout, button_text: cstring) -> bool {
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
