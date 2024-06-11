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
	flipped:   bool,
	rank:      int,
	suit:      int,
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

CARD_WIDTH :: 100
CARD_HEIGHT :: 134
PILE_SPACING :: 40

WIDTH_UNITS :: 1000

units_to_px :: proc(coord: Vector2) -> [2]f32 {
	win_size: Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	aspect := f32(win_size.x) / f32(win_size.y)

	unit_size: Vector2 = {WIDTH_UNITS, WIDTH_UNITS / aspect}
	scaling := win_size / unit_size
	return coord * scaling
}

draw_card :: proc(card: ^Card) {
	px_pos := units_to_px(card.pos + card.offset)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})

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
		card.x < coord.x &&
		card.y < coord.y &&
		card.x + CARD_WIDTH > coord.x &&
		card.y + CARD_HEIGHT > coord.y \
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
	px_pos := units_to_px(pile.pos)
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
	px_pos := units_to_px(pile.pos)
	px_size := units_to_px({CARD_WIDTH, CARD_HEIGHT})
	rect := rl.Rectangle{px_pos.x, px_pos.y, px_size.x, px_size.y}
	rl.DrawRectangleRounded(rect, 0.1, 1, STACK_COLOR)

	top, top_idx := pile_get_top(pile)
	_, held_idx := pile_get_top(held)
	num_disc := top_idx + 1
	num_held := held_idx + 1
	v := 3 - min(num_disc, 3)

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
				card.pos = pile.pos + pile.spacing * f32(2 - v - (top_idx - idx))
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

getmousepos :: proc() -> Vector2 {
	win_size: rl.Vector2 = {f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())}
	aspect := f32(win_size.x) / f32(win_size.y)

	unit_size: rl.Vector2 = {WIDTH_UNITS, WIDTH_UNITS / aspect}
	scaling := unit_size / win_size
	scaled_coords := rl.GetMousePosition() * scaling
	return Vector2(scaled_coords)
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
	return held.cards[0].rank == top.rank - 1 && held.cards[0].suit % 2 != top.suit % 2
}

stack_can_place :: proc(stack: ^Stack, held: ^Held_Pile) -> bool {
	top, idx := pile_get_top(stack)
	if idx == -1 {return held.cards[0].rank == 0}
	return held.cards[0].rank == top.rank + 1 && held.cards[0].suit == top.suit
}

init_state :: proc(state: ^State) {
	state^ = State {
		show_perf = state.show_perf,
	}
	for &card, idx in state.cards {
		card.rank = idx % 13
		card.suit = idx % 4
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
	state.hand.pos = {50, 50}
	state.hand.max_visible = 52

	state.discard.spacing.x = -20
	state.discard.pos = {350, 50}
	state.discard.max_visible = 3

	for &stack, idx in state.stacks {
		stack.pos = {500 + (CARD_WIDTH + 10) * f32(idx), 50}
		stack.suit = idx
		stack.max_visible = 1
	}

	state.held_pile.spacing.y = PILE_SPACING
	state.held_pile.max_visible = 52
}

State :: struct {
	cards:     [52]Card,
	piles:     [7]Pile,
	hand:      Pile,
	discard:   Pile,
	stacks:    [4]Stack,
	held_pile: Held_Pile,
	show_perf: bool,
}

CARDS: rl.Texture
BACKS: rl.Texture
CARD_TEX_SIZE: [2]f32 : {71, 95}

main :: proc() {
	state: State
	init_state(&state)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1080, 1080, "Solitaire")

	CARDS = rl.LoadTexture("assets/playing_cards.png")
	BACKS = rl.LoadTexture("assets/card_backs.png")

	for !rl.WindowShouldClose() {
		// general update
		{
			state.held_pile.pos = getmousepos()
			for &card in state.cards {
				card.offset = math.lerp(card.offset, 0, rl.GetFrameTime() * 10)

				if linalg.distance(card.offset, 0) < 2 {card.offset = 0}
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
					if pile_collides(&state.hand, getmousepos()) {
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
					if idx != -1 && card_collides(top, getmousepos()) {
						state.held_pile.cards[0] = top
						state.held_pile.hold_offset = getmousepos() - top.pos
						state.held_pile.source_pile = &state.discard
						state.discard.cards[idx] = nil
					}
				}

				// pick up from pile 
				{
					for &pile in state.piles {
						#reverse for card, idx in pile.cards {
							if card == nil {continue}
							if card.flipped && card_collides(card, getmousepos()) {
								copy(state.held_pile.cards[:], pile.cards[idx:])
								state.held_pile.hold_offset = getmousepos() - card.pos
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
						if pile_collides(&pile, getmousepos()) &&
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
						if pile_collides(&stack, getmousepos()) &&
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
			rl.ClearBackground(BG_COLOR)

			for &pile in state.piles {
				draw_pile(&pile)
			}

			for &stack in state.stacks {
				draw_pile(&stack)
			}

			draw_pile(&state.hand)
			draw_discard(&state.discard, &state.held_pile)

			for &pile in state.piles {
				for card in pile.cards {
					if card == nil {continue}
					if linalg.distance(card.offset, 0) > 0 {
						draw_card(card)
					}
				}
			}

			draw_held_pile(&state.held_pile)

			if state.show_perf {
				rl.DrawRectangleRounded(
					{10, 10, 90, 20},
					0.5,
					10,
					rl.Color{0xF0, 0xF0, 0xF0, 0xF0},
				)
				rl.DrawFPS(15, 11)
			}
			rl.EndDrawing()
		}
	}

	rl.CloseWindow()
}
