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
	color: rl.Color,
	font_size: f32,
	border_width: f32 = 3,
) -> bool {
	clicked := false
	if !rl.GuiIsLocked() && rl.CheckCollisionPointRec(units_to_px(state.mouse_pos), rect) {
		if rl.IsMouseButtonReleased(
			.LEFT,
		) {clicked = true} else {rl.DrawRectangleRec(rect, rl.SKYBLUE)}
	} else {
		rl.DrawRectangleRec(rect, rl.LIGHTGRAY)
	}
	rl.DrawRectangleLinesEx(rect, border_width, rl.DARKGRAY)
	centered_text(text, font_size, {rect.x, rect.y} + {rect.width, rect.height} / 2, color)
	return clicked
}

centered_text :: proc(message: cstring, size: f32, pos: Vector2, color: rl.Color) {
	width := rl.MeasureTextEx(
		rl.GetFontDefault(),
		message,
		size * settings.render_scale,
		5 * settings.render_scale,
	)

	text(message, size, pos - width / 2, color)
}

text :: proc(message: cstring, size: f32, pos: Vector2, color: rl.Color) {
	rl.DrawText(message, i32(pos.x), i32(pos.y), i32(size * settings.render_scale), color)
}

slider :: proc(bounds: rl.Rectangle, value: ^f32, min: f32, max: f32) {
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
		}
	}
}

dropdown :: proc(bounds: rl.Rectangle, text: string, active: ^i32, editing: bool) -> bool {
	options := strings.split(text, ";", context.temp_allocator)

	current_option := strings.clone_to_cstring(options[active^], context.temp_allocator)

	if text_button(bounds, current_option, rl.DARKGRAY, 20) {
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

			if text_button(box, option, rl.DARKGRAY, 15, 1) {
				active^ = i32(idx)
				return true
			}
		}
	}
	return false
}
