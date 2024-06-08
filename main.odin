package main

import "core:fmt"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

Vector2 :: distinct [2]int

Card :: struct {
	flipped:   bool,
	rank:      int,
	suit:      int,
	using pos: Vector2,
}

Pile :: struct {
	cards:     [13]^Card,
	using pos: Vector2,
}

Stack :: struct {
	cards:     [13]^Card,
	suit:      int,
	using pos: Vector2,
}

HeldCard :: struct {
	card:        ^Card,
	source_pile: ^Pile,
}

CARD_WIDTH :: 100
CARD_HEIGHT :: 160

draw_card :: proc(card: ^Card) {
	rl.DrawRectangle(i32(card.x), i32(card.y), CARD_WIDTH, CARD_HEIGHT, rl.LIGHTGRAY)
	rl.DrawRectangleLines(i32(card.x), i32(card.y), CARD_WIDTH, CARD_HEIGHT, rl.BLUE)
	rl.DrawText(
		strings.clone_to_cstring(
			fmt.tprintf("R: %d\nS: %d", card.rank, card.suit),
			context.temp_allocator,
		),
		i32(card.x + CARD_WIDTH / 2),
		i32(card.y + CARD_HEIGHT / 2),
		20,
		rl.BLACK,
	)
}

card_collides :: proc(card: ^Card, coord: Vector2) -> bool {
	return(
		card.x < coord.x &&
		card.y < coord.y &&
		card.x + CARD_WIDTH > coord.x &&
		card.y + CARD_HEIGHT > coord.y \
	)
}

pile_collides :: proc(pile: ^Pile, coord: Vector2) -> bool {
	top, idx := pile_get_top(pile)
	if top == nil {
		card := Card {
			pos = pile.pos,
		}
		return card_collides(&card, coord)
	}
	return card_collides(top, coord)
}

draw_pile :: proc(pile: ^Pile) {
	for card, idx in pile.cards {
		if card == nil {break}
		card.pos = {pile.x, pile.y + 10 * idx}
		draw_card(card)
	}
}

pile_get_top :: proc(pile: ^Pile) -> (^Card, int) {
	#reverse for card, idx in pile.cards {
		if card != nil {
			return card, idx
		}
	}
	return nil, 0
}

draw_stack :: proc(stack: ^Stack) {
	rl.DrawRectangle(i32(stack.x), i32(stack.y), CARD_WIDTH, CARD_HEIGHT, rl.YELLOW)

	label: cstring
	switch stack.suit {
	case 0:
		label = "h"
	case 1:
		label = "c"
	case 2:
		label = "d"
	case 3:
		label = "s"
	case:
		fmt.eprintln("bad suit")
	}
	rl.DrawText(label, i32(stack.x), i32(stack.y), 20, rl.BLACK)
}

vector2_to_int :: proc(v: rl.Vector2) -> Vector2 {
	return {int(v.x), int(v.y)}
}

getmousepos :: proc() -> Vector2 {
	return vector2_to_int(rl.GetMousePosition())
}

held_card_return_to_pile :: proc(held_card: ^HeldCard, pile: ^Pile) {
	top, idx := pile_get_top(pile)
	if top == nil {
		pile.cards[0] = held_card.card
	} else {
		pile.cards[idx + 1] = held_card.card
	}
	held_card.card = nil
	held_card.source_pile = nil
}

pile_can_place :: proc(pile: ^Pile, card: ^HeldCard) -> bool {
	top, idx := pile_get_top(pile)
	if top == nil {
		return card.card.rank == 12
	}
	return card.card.rank == top.rank - 1 && card.card.suit % 2 != top.suit % 2
}

reset_state :: proc(allocator := context.allocator) -> ^State {
	state := new(State, allocator)
	for &card, idx in state.cards {
		card.rank = idx % 13
		card.suit = idx % 4
	}
	rand.shuffle(state.cards[:])

	total_pile_dealt := 0
	pile_card_count := 1
	for &pile, idx in state.piles {
		pile.pos = {idx * (CARD_WIDTH + 10) + 200, 300}
		for i in 0 ..< pile_card_count {
			pile.cards[i] = &state.cards[total_pile_dealt]
			total_pile_dealt += 1
		}
		pile_card_count += 1
	}

	for &card, idx in state.cards[total_pile_dealt:] {
		state.hand[idx] = &card
		card.pos = {20 + idx * 4, 50}
	}

	for &stack, idx in state.stacks {
		stack.pos = {500 + (CARD_WIDTH + 10) * idx, 50}
		stack.suit = idx
	}

	return state
}

State :: struct {
	cards:     [52]Card,
	piles:     [7]Pile,
	hand:      [24]^Card,
	discard:   [24]^Card,
	stacks:    [4]Stack,
	held_card: HeldCard,
}

main :: proc() {
	state := reset_state()
	defer free(state)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(1920, 1080, "Solitaire")

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.R) {
			free(state)
			state = reset_state()
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		for &pile in state.piles {
			top, idx := pile_get_top(&pile)
			if top == nil {
				continue
			}
			if rl.IsMouseButtonPressed(.LEFT) && card_collides(top, getmousepos()) {
				state.held_card.card = top
				state.held_card.source_pile = &pile
				pile.cards[idx] = nil
			}
			draw_pile(&pile)
		}

		for &card in state.hand {
			draw_card(card)
		}
		for &stack in state.stacks {
			draw_stack(&stack)
		}

		if state.held_card.card != nil {
			state.held_card.card.pos = getmousepos()
			draw_card(state.held_card.card)

			if rl.IsMouseButtonReleased(.LEFT) {
				for &pile in state.piles {
					if &pile == state.held_card.source_pile {
						continue
					}

					if pile_collides(&pile, getmousepos()) &&
					   pile_can_place(&pile, &state.held_card) {
						held_card_return_to_pile(&state.held_card, &pile)
						break
					}
				}

				if state.held_card.card != nil {
					held_card_return_to_pile(&state.held_card, state.held_card.source_pile)
				}
			}
		}


		rl.DrawFPS(0, 0)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}
