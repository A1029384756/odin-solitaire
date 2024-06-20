package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:prof/spall"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

EASYWIN :: #config(EASYWIN, false)
PROFILING :: #config(PROFILING, false)

when PROFILING {
	spall_ctx: spall.Context
	spall_buffer: spall.Buffer
}

Vector2 :: [2]f32

Card :: struct {
	using pos:    Vector2,
	drawn_pos:    Vector2,
	rank:         int,
	suit:         int,
	scale:        f32,
	target_angle: f32,
	angle:        f32,
	flip_prog:    f32,
	flipped:      bool,
	held:         bool,
}

Pile :: struct {
	using pos:   Vector2,
	cards:       [24]^Card,
	spacing:     Vector2,
	max_visible: int,
}

Held_Pile :: struct {
	using pile:  Pile,
	source_pile: ^Pile,
	hold_offset: Vector2,
}

Board :: struct {
	cards:   [52]Card,
	piles:   [7]Pile,
	hand:    Pile,
	discard: Pile,
	stacks:  [4]Pile,
}

STACK_COLOR :: rl.Color{0x1F, 0x1F, 0x1F, 0x5F}

CARD_WIDTH :: 100
CARD_HEIGHT :: 134
PILE_SPACING :: 40

WIDTH_UNITS :: 1000
HEIGHT_UNITS :: 1000
UNIT_ASPECT :: WIDTH_UNITS / HEIGHT_UNITS

Icon :: enum {
	RESET,
	SHOW_PERF,
}

icon_rect := [Icon]rl.Rectangle {
	.RESET     = rl.Rectangle{3 * ICON_SIZE, 13 * ICON_SIZE, ICON_SIZE, ICON_SIZE},
	.SHOW_PERF = rl.Rectangle{14 * ICON_SIZE, 12 * ICON_SIZE, ICON_SIZE, ICON_SIZE},
}

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
	width := rl.MeasureTextEx(rl.GetFontDefault(), message, size, 5)
	rl.DrawText(message, i32(pos.x - width.x / 2), i32(pos.y - width.y / 2), i32(size), color)
}

ease_out_elastic :: #force_inline proc(t: f32) -> f32 {
	C4: f32 = 2 * math.PI / 3
	return math.pow(2, -10 * state.fade_in) * math.sin((state.fade_in * 10 - 0.75) * C4) + 1
}

units_to_px :: #force_inline proc(coord: Vector2) -> Vector2 {
	return coord * state.unit_to_px_scaling
}

px_to_units :: #force_inline proc(px: Vector2) -> Vector2 {
	return px / state.unit_to_px_scaling
}

draw_card :: proc(card: ^Card) {
	assert(card != nil, "card should exist")

	win_midpoint := state.resolution.x * state.unit_to_px_scaling.x / 2
	px_pos := units_to_px(card.drawn_pos + state.camera_pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	px_pos += px_size / 2
	scaled_size := px_size * card.scale
	px_pos.x -= (scaled_size.x - px_size.x) / 2

	shadow_pos := px_pos
	shadow_pos.x -= 0.1 * (card.scale - 1) * (win_midpoint - shadow_pos.x)

	px_pos.y -= 2 * (scaled_size.y - px_size.y)
	px_size = scaled_size

	output_pos := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}

	parabolic_show: f32 = max(0.3, math.pow((card.flip_prog - 0.5) * 2, 2))
	output_pos.x += (1 - parabolic_show) * output_pos.width / 2
	output_pos.width *= parabolic_show

	if card.scale > 1 {
		shadow_rect := rl.Rectangle{shadow_pos.x, shadow_pos.y, px_size.x, px_size.y}
		rl.DrawTexturePro(
			BLANK,
			{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
			shadow_rect,
			px_size / 2,
			math.to_degrees(card.angle),
			rl.Color{0x2F, 0x2F, 0x2F, 0x2F},
		)
	}

	rl.DrawTexturePro(
		BLANK,
		{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
		output_pos,
		px_size / 2,
		math.to_degrees(card.angle),
		rl.WHITE,
	)

	tex_coord: Vector2 = {f32(card.rank), f32(card.suit)} * CARD_TEX_SIZE
	tex_rect := rl.Rectangle{tex_coord.x, tex_coord.y, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}

	rl.DrawTexturePro(
		CARDS,
		tex_rect,
		output_pos,
		px_size / 2,
		math.to_degrees(card.angle),
		{0xFF, 0xFF, 0xFF, u8(255 * card.flip_prog)},
	)
	rl.DrawTexturePro(
		BACKS,
		{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
		output_pos,
		px_size / 2,
		math.to_degrees(card.angle),
		{0xFF, 0xFF, 0xFF, u8(255 * (1 - card.flip_prog))},
	)
}

card_collides_point :: proc(card: Vector2, coord: Vector2) -> bool {
	return(
		card.x < coord.x - state.camera_pos.x &&
		card.y < coord.y - state.camera_pos.y &&
		card.x + CARD_WIDTH > coord.x - state.camera_pos.x &&
		card.y + CARD_HEIGHT > coord.y - state.camera_pos.y \
	)
}

cards_collide :: proc(a: Vector2, b: Vector2) -> bool {
	return abs(a.x - b.x) < CARD_WIDTH && abs(a.y - b.y) < CARD_HEIGHT
}

pile_collides_point :: proc(pile: ^Pile, coord: Vector2) -> bool {
	assert(pile != nil, "pile should exist")

	for card in pile.cards {
		if card == nil {break}
		if card_collides_point(card, coord) {return true}
	}
	return card_collides_point(pile.pos, coord)
}

piles_collide :: proc(a: ^Pile, b: ^Pile) -> bool {
	assert(a.cards[0] != nil, "pile 'a' should contain a card")

	for card_a in a.cards {
		if card_a == nil {break}
		for card_b in b.cards {
			if card_b == nil {break}
			if !card_b.flipped {continue}
			if cards_collide(card_a.pos, card_b.pos) {return true}
		}
	}

	return b.cards[0] == nil && cards_collide(a.cards[0].pos, b.pos)
}

draw_pile :: proc(pile: ^Pile) {
	assert(pile != nil, "pile should exist")

	px_pos := units_to_px(pile.pos + state.camera_pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	rect := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
	rl.DrawTexturePro(BLANK, {0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}, rect, 0, 0, STACK_COLOR)
	for card, idx in pile.cards {
		if card == nil {break}
		card.pos = pile.pos + pile.spacing * f32(idx)
		draw_card(card)
	}
}

draw_discard :: proc(pile: ^Pile, held: ^Held_Pile) {
	assert(held != nil, "held pile should exist")
	assert(pile != nil, "pile should exist")

	px_pos := units_to_px(pile.pos + state.camera_pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	rect := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
	rl.DrawTexturePro(BLANK, {0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}, rect, 0, 0, STACK_COLOR)

	top, top_idx := pile_get_top(pile)
	_, held_idx := pile_get_top(held)
	num_disc := top_idx + 1
	num_held := held_idx + 1

	for card, idx in pile.cards {
		if card == nil {break}
		if num_held > 0 && held.source_pile == pile {
			if top_idx - idx < min(num_disc - num_held, 2) {
				card.pos = pile.pos + pile.spacing * f32(2 - num_held - (top_idx - idx))
			} else {
				card.pos = pile.pos
			}
		} else {
			if top_idx - idx < 3 {
				card.pos = pile.pos + pile.spacing * f32(min(num_disc, 3) - top_idx + idx - 1)
			} else {
				card.pos = pile.pos
			}
		}
		draw_card(card)
	}
}

draw_held_pile :: proc(pile: ^Held_Pile) {
	assert(pile != nil, "pile should exist")

	for card, idx in pile.cards {
		if card == nil {break}
		card.pos = pile.pos - pile.hold_offset + pile.spacing * f32(idx)
		card.drawn_pos = math.lerp(
			card.drawn_pos,
			card.pos,
			rl.GetFrameTime() * 40 / math.pow(f32(idx + 1), 0.6),
		)
		draw_card(card)
	}
}

pile_get_top :: proc(pile: ^Pile) -> (^Card, int) {
	assert(pile != nil, "pile should exist")

	#reverse for card, idx in pile.cards {
		if card != nil {
			return card, idx
		}
	}
	return nil, -1
}

held_pile_send_to_pile :: proc(held_pile: ^Held_Pile, pile: ^Pile) {
	assert(held_pile != nil, "held pile should exist")
	assert(pile != nil, "pile should exist")

	top, idx := pile_get_top(pile)
	if top == nil {
		copy(pile.cards[:], held_pile.cards[:])
	} else {
		copy(pile.cards[idx + 1:], held_pile.cards[:])
	}

	for card in held_pile.cards[:] {
		if card == nil {break}
		card.held = false
	}
	slice.zero(held_pile.cards[:])
	held_pile.hold_offset = 0
	held_pile.source_pile = nil
}

pile_can_place :: proc(pile: ^Pile, held: ^Held_Pile) -> bool {
	assert(held != nil, "held pile should exist")
	assert(pile != nil, "pile should exist")

	top, _ := pile_get_top(pile)
	if top == nil {
		return held.cards[0].rank == 12
	}
	return(
		held.cards[0].rank == top.rank - 1 &&
		held.cards[0].suit % 2 != top.suit % 2 &&
		top.flipped \
	)
}

stack_can_place :: proc(stack: ^Pile, held: ^Held_Pile) -> bool {
	assert(stack != nil, "stack should exist")
	assert(held != nil, "held pile should exist")

	top, idx := pile_get_top(stack)
	if idx == -1 {return held.cards[0].rank == 0}
	return held.cards[0].rank == top.rank + 1 && held.cards[0].suit == top.suit
}

create_solvable_board :: proc(board: ^Board) {
	for &stack, suit in board.stacks {
		for idx in 0 ..< 13 {
			board.cards[idx * 4 + suit] = Card {
				rank  = idx,
				suit  = suit,
				scale = 1,
			}
			stack.cards[idx] = &board.cards[idx * 4 + suit]
		}
	}

	for &stack, suit in board.stacks {
		top, idx := pile_get_top(&stack)
		assert(top != nil)
		assert(top.rank == 12)
		assert(top.suit == suit)
	}

	placed := 0
	for placed < 52 {
		suit := rand.int_max(4)
		top, top_idx := pile_get_top(&board.stacks[suit])
		if top == nil {continue}

		output_loc := rand.int_max(20)
		switch output_loc {
		case 0 ..< 7:
			_, output_top_idx := pile_get_top(&board.piles[output_loc])
			if output_top_idx >= output_loc {continue}

			board.piles[output_loc].cards[output_top_idx + 1] = top
			board.stacks[suit].cards[top_idx] = nil
		case:
			_, output_top_idx := pile_get_top(&board.hand)
			if output_top_idx >= len(board.hand.cards) - 1 {continue}

			board.hand.cards[output_top_idx + 1] = top
			board.stacks[suit].cards[top_idx] = nil
		}

		placed += 1
	}

	for &pile, idx in board.piles {
		top, _ := pile_get_top(&pile)
		top.flipped = true
	}

	for i := 0; i < len(board.hand.cards); i += 3 {
		slice.reverse(board.hand.cards[i:i + 3])
	}
}

create_random_board :: proc(board: ^Board) {
	for &card, idx in board.cards {
		card.rank = idx % 13
		card.suit = idx % 4
		card.scale = 1
	}
	rand.shuffle(board.cards[:])

	total_pile_dealt := 0
	pile_card_count := 1
	for &pile, idx in board.piles {
		for i in 0 ..< pile_card_count {
			pile.cards[i] = &board.cards[total_pile_dealt]
			total_pile_dealt += 1
			if i + 1 == pile_card_count {
				pile.cards[i].flipped = true
			}
		}
		pile_card_count += 1
	}

	for &card, idx in board.cards[total_pile_dealt:] {
		board.hand.cards[idx] = &card
	}
}

init_state :: proc(state: ^State) {
	state^ = State {
		show_perf  = state.show_perf,
		camera_pos = state.camera_pos,
		game_time  = state.game_time,
		hue_shift  = state.hue_shift,
		render_tex = state.render_tex,
		resolution = state.resolution,
		difficulty = state.difficulty,
	}

	switch state.difficulty {
	case .EASY:
		create_solvable_board(&state.board)
	case .RANDOM:
		create_random_board(&state.board)
	}

	for &pile, idx in state.piles {
		pile.spacing.y = PILE_SPACING
		pile.pos = {f32(idx) * (CARD_WIDTH + 10) + 200, 250}
		pile.max_visible = 52
	}

	state.hand.spacing.x = 4
	state.hand.pos = {50, 70}
	state.hand.max_visible = 52

	state.discard.spacing.x = -20
	state.discard.pos = {350, 70}
	state.discard.max_visible = 3

	for &stack, idx in state.stacks {
		stack.pos = {500 + (CARD_WIDTH + 10) * f32(idx), 70}
		stack.max_visible = 1
	}

	state.held_pile.spacing.y = PILE_SPACING
	state.held_pile.max_visible = 52
}

State :: struct {
	// rendering
	render_tex:         rl.RenderTexture2D,
	camera_pos:         Vector2,
	mouse_pos:          Vector2,
	resolution:         Vector2,
	unit_to_px_scaling: Vector2,
	// board
	using board:        Board,
	// player items
	held_pile:          Held_Pile,
	// settings
	hue_shift:          f32,
	show_perf:          bool,
	difficulty:         enum {
		EASY   = 0,
		RANDOM = 1,
	},
	diff_menu_edit:     bool,
	gui_locked:         bool,
	// game stats
	game_time:          f32,
	has_won:            bool,
	// win screen
	fade_in:            f32,
}

CARDS: rl.Texture
BLANK: rl.Texture
BACKS: rl.Texture
CARD_TEX_SIZE: Vector2 : {71, 95}

ICONS: rl.Texture
ICON_SIZE :: 18

state: State

main :: proc() {
	when PROFILING {
		spall_ctx = spall.context_create("solitaire.spall")
		defer spall.context_destroy(&spall_ctx)

		buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)

		spall_buffer = spall.buffer_create(buffer_backing)
		defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	}

	init_state(&state)
	state.hue_shift = 2.91
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})

	when !ODIN_DEBUG {
		rl.SetTraceLogLevel(.ERROR)
	}

	rl.InitWindow(800, 800, "Solitaire")
	defer rl.CloseWindow()

	rl.ChangeDirectory(rl.GetApplicationDirectory())
	CARDS = rl.LoadTexture("assets/playing_cards.png")
	defer rl.UnloadTexture(CARDS)

	BLANK = rl.LoadTexture("assets/blank_card.png")
	defer rl.UnloadTexture(BLANK)

	BACKS = rl.LoadTexture("assets/card_backs.png")
	defer rl.UnloadTexture(BACKS)

	ICONS = rl.LoadTexture("assets/icons.png")
	defer rl.UnloadTexture(ICONS)

	state.render_tex = rl.LoadRenderTexture(800, 800)
	defer rl.UnloadRenderTexture(state.render_tex)

	background_shader := rl.LoadShader(nil, "shaders/fbm.fs")
	defer rl.UnloadShader(background_shader)

	time_loc := rl.GetShaderLocation(background_shader, "u_time")
	rl.SetShaderValue(background_shader, time_loc, &state.game_time, .FLOAT)

	hue_loc := rl.GetShaderLocation(background_shader, "u_hue")
	rl.SetShaderValue(background_shader, hue_loc, &state.hue_shift, .FLOAT)

	res_loc := rl.GetShaderLocation(background_shader, "u_resolution")
	state.resolution = Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	rl.SetShaderValue(background_shader, res_loc, &state.resolution, .VEC2)

	scanline_shader := rl.LoadShader(nil, "shaders/scanlines.fs")
	defer rl.UnloadShader(scanline_shader)

	scanline_res_loc := rl.GetShaderLocation(scanline_shader, "u_resolution")
	rl.SetShaderValue(scanline_shader, scanline_res_loc, &state.resolution, .VEC2)

	for !rl.WindowShouldClose() {
		// general update
		if rl.IsWindowFocused() {
			// window resizing
			{
				new_resolution := Vector2{f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())}
				if new_resolution != state.resolution {
					state.resolution = new_resolution
					rl.UnloadRenderTexture(state.render_tex)
					state.render_tex = rl.LoadRenderTexture(
						i32(state.resolution.x),
						i32(state.resolution.y),
					)
				}
			}

			state.game_time += rl.GetFrameTime()
			state.mouse_pos = rl.GetMousePosition() * (1 / state.unit_to_px_scaling)

			// camera horizontal centering
			{
				aspect := state.resolution.x / state.resolution.y

				win_size_unit: Vector2
				if aspect > UNIT_ASPECT {
					win_size_unit = {HEIGHT_UNITS * aspect, HEIGHT_UNITS}
				} else {
					win_size_unit = {WIDTH_UNITS, WIDTH_UNITS / aspect}
				}

				state.unit_to_px_scaling = state.resolution / win_size_unit
				win_size_units := px_to_units(state.resolution)

				horz_overflow := win_size_units.x - WIDTH_UNITS
				if horz_overflow > 0 {
					state.camera_pos.x = horz_overflow / 2
				} else {
					state.camera_pos.x = 0
				}
			}

			state.held_pile.pos = state.mouse_pos
			for &card in state.cards {
				if card.held {
					mouse_delta := rl.GetMouseDelta()
					if linalg.length(mouse_delta) > 0 {
						angle :=
							math.asin(mouse_delta.x / linalg.length(mouse_delta)) *
							(min(abs(mouse_delta.x), 100) / 40)
						card.angle = math.angle_lerp(card.angle, angle, rl.GetFrameTime() * 8)
					} else {
						card.angle = math.angle_lerp(card.angle, 0, rl.GetFrameTime() * 6)
					}
				} else {
					if linalg.distance(card.pos, card.drawn_pos) > 0.1 {
						card.angle = math.lerp(card.angle, 0, rl.GetFrameTime() * 20)
					} else {
						card.angle = math.lerp(card.angle, card.target_angle, rl.GetFrameTime())
						if abs(card.angle - card.target_angle) < 0.001 {
							card.target_angle = rand.float32_range(-0.07, 0.07)
						}
					}
				}
				card.flip_prog = math.lerp(
					card.flip_prog,
					1 if card.flipped else 0,
					rl.GetFrameTime() * 20,
				)

				card.scale = math.lerp(card.scale, 1.1 if card.held else 1, rl.GetFrameTime() * 10)

				if !card.held {
					card.drawn_pos = math.lerp(card.drawn_pos, card.pos, rl.GetFrameTime() * 10)
				}
			}
		}

		// input handlers
		if !state.has_won && rl.IsWindowFocused() {
			// reset game
			if rl.IsKeyPressed(.R) {init_state(&state)}

			if rl.IsKeyPressed(.P) {state.show_perf = !state.show_perf}

			if rl.IsMouseButtonPressed(.LEFT) {
				// handle discard
				{
					if pile_collides_point(&state.hand, state.mouse_pos) {
						top, idx := pile_get_top(&state.hand)
						_, discard_size := pile_get_top(&state.discard)
						switch idx {
						case -1:
							copy(state.hand.cards[:], state.discard.cards[:])
							slice.zero(state.discard.cards[:])
							slice.reverse(state.hand.cards[:discard_size + 1])
							for card, idx in state.hand.cards {
								if card == nil {break}
								card.flipped = false
							}
						case 0 ..< 3:
							copy(
								state.discard.cards[discard_size + 1:],
								state.hand.cards[:idx + 1],
							)
							slice.zero(state.hand.cards[:idx + 1])
							slice.reverse(
								state.discard.cards[discard_size + 1:discard_size + 1 + idx + 1],
							)
							for card in state.discard.cards[discard_size + 1:] {
								if card == nil {break}
								card.flipped = true
								card.pos = state.discard.pos
							}
						case:
							copy(
								state.discard.cards[discard_size + 1:],
								state.hand.cards[idx - 2:],
							)
							slice.zero(state.hand.cards[idx - 2:])
							slice.reverse(state.discard.cards[discard_size + 1:discard_size + 4])
							for card in state.discard.cards[discard_size + 1:] {
								if card == nil {break}
								card.flipped = true
								card.pos = state.discard.pos
							}
						}
					}
				}

				// pick up from discard 
				{
					top, idx := pile_get_top(&state.discard)
					if idx != -1 && card_collides_point(top, state.mouse_pos) {
						state.held_pile.cards[0] = top
						state.held_pile.cards[0].held = true
						state.held_pile.hold_offset = state.mouse_pos - top.pos
						state.held_pile.source_pile = &state.discard
						state.discard.cards[idx] = nil
					}
				}

				// pick up from stack 
				{
					for &stack in state.stacks {
						top, idx := pile_get_top(&stack)
						if idx != -1 && card_collides_point(top, state.mouse_pos) {
							state.held_pile.cards[0] = top
							state.held_pile.cards[0].held = true
							state.held_pile.hold_offset = state.mouse_pos - top.pos
							state.held_pile.source_pile = &stack
							stack.cards[idx] = nil
							break
						}
					}
				}

				// pick up from pile 
				{
					for &pile in state.piles {
						#reverse for card, idx in pile.cards {
							if card == nil {continue}
							if card.flipped && card_collides_point(card, state.mouse_pos) {
								copy(state.held_pile.cards[:], pile.cards[idx:])
								for card in state.held_pile.cards {
									if card == nil {break}
									card.held = true
								}
								state.held_pile.hold_offset = state.mouse_pos - card.pos
								state.held_pile.source_pile = &pile
								slice.zero(pile.cards[idx:])
								break
							}
						}
					}
				}
			}

			if rl.IsMouseButtonReleased(.LEFT) {
				// add hand pile to pile
				if state.held_pile.source_pile != nil {
					candidate_piles: [7]^Pile
					num_candidates := 0

					for &pile in state.piles {
						if state.held_pile.source_pile == &pile {continue}
						if piles_collide(&state.held_pile, &pile) &&
						   pile_can_place(&pile, &state.held_pile) {
							candidate_piles[num_candidates] = &pile
							num_candidates += 1
						}
					}

					if num_candidates > 0 {
						closest_pile: ^Pile
						max_overlap := min(f32)
						for i in 0 ..< num_candidates {
							candidate_top, top_idx := pile_get_top(candidate_piles[i])
							top_pos :=
								candidate_top == nil ? candidate_piles[i].pos : candidate_top.pos
							held_pos := state.held_pile.cards[0].pos

							overlap :=
								max(
									0,
									min(held_pos.x + CARD_WIDTH, top_pos.x + CARD_WIDTH) -
									max(held_pos.x, top_pos.x),
								) *
								max(
									0,
									min(held_pos.y + CARD_HEIGHT, top_pos.y + CARD_HEIGHT) -
									max(held_pos.y, top_pos.y),
								)

							if overlap >= max_overlap {
								closest_pile = candidate_piles[i]
								max_overlap = overlap
							}
						}

						top, idx := pile_get_top(state.held_pile.source_pile)
						if top != nil {top.flipped = true}

						when EASYWIN {
							state.has_won = true
						}

						held_pile_send_to_pile(&state.held_pile, closest_pile)
					}
				}

				// add card to stack
				if state.held_pile.source_pile != nil {
					for &stack in state.stacks {
						if piles_collide(&state.held_pile, &stack) &&
						   stack_can_place(&stack, &state.held_pile) {
							top, idx := pile_get_top(state.held_pile.source_pile)
							if top != nil {top.flipped = true}
							held_pile_send_to_pile(&state.held_pile, &stack)
							break
						}
					}
				}

				// return unassigned hand pile to source
				if state.held_pile.source_pile != nil {
					held_pile_send_to_pile(&state.held_pile, state.held_pile.source_pile)
				}

				// win condition
				{
					for &stack, idx in state.stacks {
						top, top_idx := pile_get_top(&stack)
						if top_idx != 12 {break}
						if idx == 3 {state.has_won = true}
					}
				}
			}
		}

		// rendering 
		{
			// viewport
			{
				rl.BeginTextureMode(state.render_tex)
				defer rl.EndTextureMode()
				// card rendering
				{
					{
						rl.BeginShaderMode(background_shader)
						rl.SetShaderValue(background_shader, time_loc, &state.game_time, .FLOAT)
						rl.SetShaderValue(background_shader, hue_loc, &state.hue_shift, .FLOAT)
						rl.SetShaderValue(background_shader, res_loc, &state.resolution, .VEC2)
						rl.DrawRectangle(
							0,
							0,
							i32(state.resolution.x),
							i32(state.resolution.y),
							rl.BLANK,
						)
						defer rl.EndShaderMode()
					}

					for &pile in state.piles {
						draw_pile(&pile)
					}

					for &stack in state.stacks {
						draw_pile(&stack)
					}

					draw_pile(&state.hand)
					draw_discard(&state.discard, &state.held_pile)

					for &stack in state.stacks {
						for card in stack.cards {
							if card == nil {break}
							if linalg.distance(card.pos, card.drawn_pos) > 0.1 {
								draw_card(card)
							}
						}
					}

					for &pile in state.piles {
						for card in pile.cards {
							if card == nil {break}
							if linalg.distance(card.pos, card.drawn_pos) > 0.1 {
								draw_card(card)
							}
						}
					}

					draw_held_pile(&state.held_pile)
				}
				// ui rendering
				{
					// toolbar
					{
						if state.has_won {rl.GuiLock()}
						out_loc := units_to_px({50, 50})
						rl.DrawRectangle(
							0,
							0,
							i32(state.resolution.x),
							i32(out_loc.y),
							rl.LIGHTGRAY,
						)
						if icon_button({0, 0, out_loc.x, out_loc.y}, .RESET, rl.DARKGRAY) {
							init_state(&state)
						}
						if icon_button(
							{out_loc.x + 2, 0, out_loc.x, out_loc.y},
							.SHOW_PERF,
							rl.DARKGRAY,
						) {
							state.show_perf = !state.show_perf
						}
						rl.GuiSlider(
							{
								(out_loc.x + 2) * 2,
								15 * state.unit_to_px_scaling.y,
								out_loc.x * 3,
								20 * state.unit_to_px_scaling.y,
							},
							"",
							"",
							&state.hue_shift,
							0,
							2 * math.PI,
						)

						if rl.GuiDropdownBox(
							{(out_loc.x + 2) * 5, 0, out_loc.x * 2, out_loc.y},
							"Easy;Random",
							cast(^i32)&state.difficulty,
							state.diff_menu_edit,
						) {state.diff_menu_edit = !state.diff_menu_edit}
					}

					// performance overlay
					if state.show_perf {
						perf_px := Vector2 {
							f32(state.resolution.x) - 100,
							f32(state.resolution.y) - 30,
						}
						rl.DrawRectangleRounded(
							{perf_px.x, perf_px.y, 90, 20},
							0.5,
							10,
							rl.Color{0xF0, 0xF0, 0xF0, 0xF0},
						)
						rl.DrawFPS(i32(perf_px.x) + 5, i32(perf_px.y))
					}

					// victory screen
					if state.has_won {
						rl.GuiUnlock()
						state.fade_in =
							state.fade_in + rl.GetFrameTime() if state.fade_in < 1 else 1

						anim := ease_out_elastic(state.fade_in)

						rl.DrawRectangle(
							0,
							0,
							i32(state.resolution.x),
							i32(state.resolution.y),
							{0x1F, 0x1F, 0x1, u8(0x5F * state.fade_in)},
						)

						draw_text_centered("YOU WIN!", 60, state.resolution / 2, rl.WHITE)

						button_px := units_to_px({500, 150})
						if text_button(
							   {
								   state.resolution.x / 2 - button_px.x / 2,
								   anim * state.resolution.y / 2 -
								   button_px.y / 2 +
								   200 * state.unit_to_px_scaling.y,
								   button_px.x,
								   button_px.y,
							   },
							   "RESTART",
							   rl.WHITE,
							   60,
						   ) &&
						   state.fade_in == 1 {
							init_state(&state)
						}
					}
				}
			}

			// postprocessing
			{
				rl.BeginDrawing()
				defer rl.EndDrawing()

				{
					rl.BeginShaderMode(scanline_shader)
					defer rl.EndShaderMode()
					rl.SetShaderValue(scanline_shader, scanline_res_loc, &state.resolution, .VEC2)
					rl.DrawTextureRec(
						state.render_tex.texture,
						{
							0,
							0,
							f32(state.render_tex.texture.width),
							f32(-state.render_tex.texture.height),
						},
						0,
						rl.WHITE,
					)
				}
			}
		}
	}
}

when PROFILING {
	@(instrumentation_enter)
	spall_enter :: proc "contextless" (
		proc_address, call_site_return_address: rawptr,
		loc: runtime.Source_Code_Location,
	) {
		spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
	}

	@(instrumentation_exit)
	spall_exit :: proc "contextless" (
		proc_address, call_site_return_address: rawptr,
		loc: runtime.Source_Code_Location,
	) {
		spall._buffer_end(&spall_ctx, &spall_buffer)
	}
}
