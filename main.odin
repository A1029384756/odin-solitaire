package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

Vector2 :: [2]f32

Card :: struct {
	using pos: Vector2,
	offset:    Vector2,
	rank:      int,
	suit:      int,
	scale:     f32,
	flipped:   bool,
	held:      bool,
}

Pile :: struct {
	using pos:   Vector2,
	cards:       [24]^Card,
	spacing:     Vector2,
	size:        int,
	max_visible: int,
}

Stack :: struct {
	using pile: Pile,
	suit:       int,
}

Held_Pile :: struct {
	using pile:  Pile,
	source_pile: ^Pile,
	hold_offset: Vector2,
}


BG_COLOR :: rl.Color{0x34, 0xA2, 0x49, 0xFF}
STACK_COLOR :: rl.Color{0x2B, 0x7B, 0x3B, 0xFF}

ICON_SIZE :: 18

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

	if rl.CheckCollisionPointRec(units_to_px(state.mouse_pos), rect) {
		if rl.IsMouseButtonReleased(
			.LEFT,
		) {clicked = true} else {rl.DrawRectangleRec(rect, rl.SKYBLUE)}
	} else {
		rl.DrawRectangleRec(rect, rl.LIGHTGRAY)
	}
	rl.DrawRectangleLinesEx(rect, 3, rl.DARKGRAY)

	overflow := Vector2{rect.width, rect.height}
	overflow -= ICON_SIZE * f32(icon_scale)

	rl.BeginBlendMode(.ALPHA)
	rl.DrawTexturePro(ICONS, icon_rect[icon], rect, 0, 0, rl.DARKGRAY)
	rl.EndBlendMode()
	return clicked
}

units_to_px :: #force_inline proc(coord: Vector2) -> Vector2 {
	return coord * state.unit_to_px_scaling
}

px_to_units :: #force_inline proc(px: Vector2) -> Vector2 {
	return px / state.unit_to_px_scaling
}

draw_card :: proc(card: ^Card) {
	px_pos := units_to_px(card.pos + card.offset + state.camera_pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	scaled_size := px_size * card.scale
	px_pos -= (scaled_size - px_size) / 2
  px_size = scaled_size

	card_rect := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
	rl.DrawRectangleRounded(card_rect, 0.1, 1, rl.WHITE)
	rl.DrawRectangleRoundedLines(card_rect, 0.1, 1, 1, rl.LIGHTGRAY)
	if card.flipped {
		tex_coord: Vector2 = {f32(card.rank), f32(card.suit)} * CARD_TEX_SIZE
		tex_rect := rl.Rectangle{tex_coord.x, tex_coord.y, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}

		output_pos := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
		rl.DrawTexturePro(CARDS, tex_rect, output_pos, 0, 0, rl.WHITE)
	} else {
		output_pos := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
		rl.DrawTexturePro(
			BACKS,
			{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
			output_pos,
			0,
			0,
			rl.WHITE,
		)
	}
}

card_collides :: proc(card: Vector2, coord: Vector2) -> bool {
	return(
		card.x < coord.x - state.camera_pos.x &&
		card.y < coord.y - state.camera_pos.y &&
		card.x + CARD_WIDTH > coord.x - state.camera_pos.x &&
		card.y + CARD_HEIGHT > coord.y - state.camera_pos.y \
	)
}

pile_collides :: proc(pile: ^Pile, coord: Vector2) -> bool {
	for card in pile.cards {
		if card == nil {continue}
		if card_collides(card, coord) {return true}
	}
	if card_collides(pile.pos, coord) {return true}
	return false
}

draw_pile :: proc(pile: ^Pile) {
	px_pos := units_to_px(pile.pos + state.camera_pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	rect := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
	rl.DrawRectangleRounded(rect, 0.1, 1, STACK_COLOR)
	for card, idx in pile.cards {
		if card == nil {break}
		card.pos = pile.pos + pile.spacing * f32(idx)
		draw_card(card)
	}
}

draw_discard :: proc(pile: ^Pile, held: ^Held_Pile) {
	px_pos := units_to_px(pile.pos + state.camera_pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	rect := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
	rl.DrawRectangleRounded(rect, 0.1, 1, STACK_COLOR)

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
	for card, idx in pile.cards {
		if card == nil {break}
		card.pos = pile.pos - pile.hold_offset + pile.spacing * f32(idx)
		draw_card(card)
	}
}

pile_get_top :: proc(pile: ^Pile) -> (^Card, int) {
	#reverse for card, idx in pile.cards {
		if card != nil {
			return card, idx
		}
	}
	return nil, -1
}

held_pile_send_to_pile :: proc(held_pile: ^Held_Pile, pile: ^Pile) {
	top, idx := pile_get_top(pile)
	if top == nil {
		copy(pile.cards[:], held_pile.cards[:])
	} else {
		copy(pile.cards[idx + 1:], held_pile.cards[:])
	}

	for card in held_pile.cards[:] {
		if card == nil {break}
		card.held = false
		card.offset =
			(held_pile.pos - held_pile.hold_offset) -
			pile.pos -
			f32(min(idx + 1, pile.max_visible - 1)) * pile.spacing
	}
	slice.zero(held_pile.cards[:])
	held_pile.hold_offset = 0
	held_pile.source_pile = nil
}

pile_can_place :: proc(pile: ^Pile, held: ^Held_Pile) -> bool {
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

stack_can_place :: proc(stack: ^Stack, held: ^Held_Pile) -> bool {
	top, idx := pile_get_top(stack)
	if idx == -1 {return held.cards[0].rank == 0}
	return held.cards[0].rank == top.rank + 1 && held.cards[0].suit == top.suit
}

init_state :: proc(state: ^State) {
	state^ = State {
		show_perf  = state.show_perf,
		camera_pos = state.camera_pos,
	}
	for &card, idx in state.cards {
		card.rank = idx % 13
		card.suit = idx % 4
		card.scale = 1
	}
	rand.shuffle(state.cards[:])

	total_pile_dealt := 0
	pile_card_count := 1
	for &pile, idx in state.piles {
		pile.spacing.y = PILE_SPACING
		pile.pos = {f32(idx) * (CARD_WIDTH + 10) + 200, 250}
		for i in 0 ..< pile_card_count {
			pile.cards[i] = &state.cards[total_pile_dealt]
			total_pile_dealt += 1
			if i + 1 == pile_card_count {
				pile.cards[i].flipped = true
			}
		}
		pile_card_count += 1
		pile.max_visible = 52
	}

	for &card, idx in state.cards[total_pile_dealt:] {
		state.hand.cards[idx] = &card
	}
	state.hand.spacing.x = 4
	state.hand.pos = {50, 70}
	state.hand.max_visible = 52

	state.discard.spacing.x = -20
	state.discard.pos = {350, 70}
	state.discard.max_visible = 3

	for &stack, idx in state.stacks {
		stack.pos = {500 + (CARD_WIDTH + 10) * f32(idx), 70}
		stack.suit = idx
		stack.max_visible = 1
	}

	state.held_pile.spacing.y = PILE_SPACING
	state.held_pile.max_visible = 52
}

State :: struct {
	cards:              [52]Card,
	piles:              [7]Pile,
	hand:               Pile,
	discard:            Pile,
	stacks:             [4]Stack,
	held_pile:          Held_Pile,
	show_perf:          bool,
	camera_pos:         Vector2,
	mouse_pos:          Vector2,
	unit_to_px_scaling: Vector2,
}

CARDS: rl.Texture
BACKS: rl.Texture
CARD_TEX_SIZE: Vector2 : {71, 95}
ICONS: rl.Texture

state: State

main :: proc() {
	init_state(&state)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})

	when !ODIN_DEBUG {
		rl.SetTraceLogLevel(.ERROR)
	}

	rl.InitWindow(1080, 1080, "Solitaire")

	CARDS = rl.LoadTexture("assets/playing_cards.png")
	defer rl.UnloadTexture(CARDS)

	BACKS = rl.LoadTexture("assets/card_backs.png")
	defer rl.UnloadTexture(BACKS)

	ICONS = rl.LoadTexture("assets/icons.png")
	defer rl.UnloadTexture(ICONS)

	for !rl.WindowShouldClose() {
		// general update
		{
			state.mouse_pos = rl.GetMousePosition() * (1 / state.unit_to_px_scaling)

			// Camera horizontal centering
			{
				win_size_px := Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
				aspect := win_size_px.x / win_size_px.y

				win_size_unit: Vector2
				if aspect > UNIT_ASPECT {
					win_size_unit = {HEIGHT_UNITS * aspect, HEIGHT_UNITS}
				} else {
					win_size_unit = {WIDTH_UNITS, WIDTH_UNITS / aspect}
				}

				state.unit_to_px_scaling = win_size_px / win_size_unit
				win_size_units := px_to_units(win_size_px)

				horz_overflow := win_size_units.x - WIDTH_UNITS
				if horz_overflow > 0 {
					state.camera_pos.x = horz_overflow / 2
				} else {
					state.camera_pos.x = 0
				}
			}

			state.held_pile.pos = state.mouse_pos
			for &card in state.cards {
				card.offset = math.lerp(card.offset, 0, rl.GetFrameTime() * 10)
				if linalg.distance(card.offset, 0) < 2 {card.offset = 0}
				card.scale = math.lerp(card.scale, 1.1 if card.held else 1, rl.GetFrameTime() * 10)
			}
		}

		// input handlers
		{
			// reset game
			if rl.IsKeyPressed(.R) {init_state(&state)}

			if rl.IsKeyPressed(.P) {state.show_perf = !state.show_perf}

			if rl.IsMouseButtonPressed(.LEFT) {
				// handle discard
				{
					if pile_collides(&state.hand, state.mouse_pos) {
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
								card.offset =
									state.discard.pos -
									state.hand.pos -
									f32(min(state.hand.max_visible, idx)) * state.hand.spacing
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
								card.offset =
									state.hand.pos -
									state.discard.pos -
									f32(min(state.discard.max_visible, idx)) *
										state.discard.spacing
							}
							for card in state.discard.cards[:discard_size + 1] {
								card.offset = card.pos - state.discard.pos
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
								card.offset =
									state.hand.pos -
									state.discard.pos -
									f32(min(state.discard.max_visible, idx)) *
										state.discard.spacing
							}
							for card in state.discard.cards[:discard_size + 1] {
								card.offset = card.pos - state.discard.pos
							}
						}
					}
				}

				// pick up from discard 
				{
					top, idx := pile_get_top(&state.discard)
					if idx != -1 && card_collides(top, state.mouse_pos) {
						state.held_pile.cards[0] = top
						state.held_pile.cards[0].held = true
						state.held_pile.hold_offset = state.mouse_pos - top.pos
						state.held_pile.source_pile = &state.discard
						state.discard.cards[idx] = nil
					}
				}

				// pick up from pile 
				{
					for &pile in state.piles {
						#reverse for card, idx in pile.cards {
							if card == nil {continue}
							if card.flipped && card_collides(card, state.mouse_pos) {
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
				{
					for &pile in state.piles {
						if state.held_pile.source_pile == nil {continue}
						if pile_collides(&pile, state.mouse_pos) &&
						   pile_can_place(&pile, &state.held_pile) {
							top, idx := pile_get_top(state.held_pile.source_pile)
							if top != nil {top.flipped = true}
							if state.held_pile.source_pile == &state.discard {
								switch idx {
								case -1:
								case 0 ..< 3:
								case:
									for card, idx in state.discard.cards[idx - 1:idx + 1] {
										card.offset =
											card.pos -
											state.discard.pos -
											f32(min(state.discard.max_visible - 1, idx + 1)) *
												state.discard.spacing
									}
								}
							}
							held_pile_send_to_pile(&state.held_pile, &pile)
						}
					}
				}

				// add card to stack
				{
					for &stack in state.stacks {
						if pile_collides(&stack, state.mouse_pos) &&
						   state.held_pile.cards[0] != nil &&
						   stack_can_place(&stack, &state.held_pile) {
							top, idx := pile_get_top(state.held_pile.source_pile)
							if top != nil {top.flipped = true}
							if state.held_pile.source_pile == &state.discard {
								switch idx {
								case -1:
								case 0 ..< 3:
								case:
									for card, idx in state.discard.cards[idx - 1:idx + 1] {
										card.offset =
											card.pos -
											state.discard.pos -
											f32(min(state.discard.max_visible - 1, idx + 1)) *
												state.discard.spacing
									}
								}
							}
							held_pile_send_to_pile(&state.held_pile, &stack)
						}
					}
				}

				// return unassigned hand pile to source
				if state.held_pile.cards[0] != nil {
					held_pile_send_to_pile(&state.held_pile, state.held_pile.source_pile)
				}

				// win condition
				{
					for &stack, idx in state.stacks {
						top, top_idx := pile_get_top(&stack)
						if top_idx != 12 {
							break
						}
						if idx == 3 {
							fmt.println("you win")
							init_state(&state)
						}
					}
				}
			}
		}

		// rendering 
		{
			rl.BeginDrawing()

			// card rendering
			{
				rl.ClearBackground(BG_COLOR)

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
						if linalg.distance(card.offset, 0) > 0 {
							draw_card(card)
						}
					}
				}

				for &pile in state.piles {
					for card in pile.cards {
						if card == nil {break}
						if linalg.distance(card.offset, 0) > 0 {
							draw_card(card)
						}
					}
				}

				draw_held_pile(&state.held_pile)

				if state.show_perf {
					perf_px := Vector2 {
						f32(rl.GetScreenWidth()) - 100,
						f32(rl.GetScreenHeight()) - 30,
					}
					rl.DrawRectangleRounded(
						{perf_px.x, perf_px.y, 90, 20},
						0.5,
						10,
						rl.Color{0xF0, 0xF0, 0xF0, 0xF0},
					)
					rl.DrawFPS(i32(perf_px.x) + 5, i32(perf_px.y))
				}
			}
		}

		// ui rendering
		{
			// toolbar
			{
				out_loc := units_to_px({50, 50})
				rl.DrawRectangle(0, 0, rl.GetScreenWidth(), i32(out_loc.y), rl.LIGHTGRAY)
				if icon_button({0, 0, out_loc.x, out_loc.y}, .RESET, rl.DARKGRAY) {
					init_state(&state)
				}
				if icon_button({out_loc.x + 2, 0, out_loc.x, out_loc.y}, .SHOW_PERF, rl.DARKGRAY) {
					state.show_perf = !state.show_perf
				}
			}
		}

		rl.EndDrawing()
	}


	rl.CloseWindow()
}
