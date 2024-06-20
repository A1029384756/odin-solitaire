package main

import rl "vendor:raylib"

icon_button :: proc(
	rect: rl.Rectangle,
	icon: Icon,
	icon_color: rl.Color,
	icon_scale: f32 = 2,
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

text_button :: proc(rect: rl.Rectangle, text: cstring, color: rl.Color, font_size: f32) -> bool {
	clicked := false
	if !rl.GuiIsLocked() && rl.CheckCollisionPointRec(units_to_px(state.mouse_pos), rect) {
		if rl.IsMouseButtonReleased(
			.LEFT,
		) {clicked = true} else {rl.DrawRectangleRec(rect, rl.SKYBLUE)}
	} else {
		rl.DrawRectangleRec(rect, rl.LIGHTGRAY)
	}
	rl.DrawRectangleLinesEx(rect, 3, rl.DARKGRAY)
	draw_text_centered(text, font_size, {rect.x, rect.y} + {rect.width, rect.height} / 2, color)
	return clicked
}

draw_text_centered :: proc(message: cstring, size: f32, pos: Vector2, color: rl.Color) {
	width := rl.MeasureTextEx(
		rl.GetFontDefault(),
		message,
		size * settings.render_scale,
		5 * settings.render_scale,
	)
	rl.DrawText(
		message,
		i32(pos.x - width.x / 2),
		i32(pos.y - width.y / 2),
		i32(size * settings.render_scale),
		color,
	)
}
