package main

import "core:fmt"
import "core:math/rand"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

Vector2 :: distinct [2]int

Card :: struct {
	using pos: Vector2,
	flipped:   bool,
	rank:      int,
	suit:      int,
}

Pile :: struct {
	using pos: Vector2,
	cards:     [24]^Card,
	spacing:   Vector2,
	size:      int,
}

Stack :: struct {
	using pile: Pile,
	suit:       int,
}

Held_Pile :: struct {
	using pile:  Pile,
	source_pile: ^Pile,
}

CARD_WIDTH :: 100
CARD_HEIGHT :: 160
PILE_SPACING :: 20

draw_card :: proc(card: ^Card) {
	rl.DrawRectangle(i32(card.x), i32(card.y), CARD_WIDTH, CARD_HEIGHT, rl.LIGHTGRAY)
	rl.DrawRectangleLines(i32(card.x), i32(card.y), CARD_WIDTH, CARD_HEIGHT, rl.BLUE)
	if !card.flipped {
		return
	}

	label: string
	switch card.suit {
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

	rl.DrawText(
		strings.clone_to_cstring(
			fmt.tprintf("R: %d\nS: %s", card.rank, label),
			context.temp_allocator,
		),
		i32(card.x + CARD_WIDTH / 2),
		i32(card.y + CARD_HEIGHT / 2),
		20,
		rl.BLACK,
	)
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
	rl.DrawRectangle(i32(pile.x), i32(pile.y), CARD_WIDTH, CARD_HEIGHT, rl.YELLOW)
	for card, idx in pile.cards {
		if card == nil {break}
		card.pos = pile.pos.xy + pile.spacing.xy * idx
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

held_pile_send_to_pile :: proc(held_pile: ^Held_Pile, pile: ^Pile) {
	top, idx := pile_get_top(pile)
	if top == nil {
		copy(pile.cards[:], held_pile.cards[:])
	} else {
		copy(pile.cards[idx + 1:], held_pile.cards[:])
	}
	slice.zero(held_pile.cards[:])
	held_pile.source_pile = nil
}

pile_can_place :: proc(pile: ^Pile, held: ^Held_Pile) -> bool {
	top, _ := pile_get_top(pile)
	fmt.println(top)
	if top == nil {
		fmt.println(held.cards[0].rank)
		return held.cards[0].rank == 12
	}
	return held.cards[0].rank == top.rank - 1 && held.cards[0].suit % 2 != top.suit % 2
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
		pile.spacing.y = PILE_SPACING
		pile.pos = {idx * (CARD_WIDTH + 10) + 200, 300}
		for i in 0 ..< pile_card_count {
			pile.cards[i] = &state.cards[total_pile_dealt]
			total_pile_dealt += 1
			if i + 1 == pile_card_count {
				pile.cards[i].flipped = true
			}
		}
		pile_card_count += 1
	}

	for &card, idx in state.cards[total_pile_dealt:] {
		state.hand.cards[idx] = &card
		state.hand.spacing.x = 4
		state.hand.pos.xy = {50, 50}
	}

	for &stack, idx in state.stacks {
		stack.pos = {500 + (CARD_WIDTH + 10) * idx, 50}
		stack.suit = idx
	}

	state.held_pile.spacing.y = PILE_SPACING

	return state
}

State :: struct {
	cards:     [52]Card,
	piles:     [7]Pile,
	hand:      Pile,
	discard:   Pile,
	stacks:    [4]Stack,
	held_pile: Held_Pile,
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
			if rl.IsMouseButtonPressed(.LEFT) {
				#reverse for card, idx in pile.cards {
					if card == nil {continue}
					if card.flipped && card_collides(card, getmousepos()) {
						copy(state.held_pile.cards[:], pile.cards[idx:])
						state.held_pile.source_pile = &pile
						slice.zero(pile.cards[idx:])
						break
					}
				}
			}
			draw_pile(&pile)
		}

		draw_pile(&state.hand)
		for &stack in state.stacks {
			draw_stack(&stack)
		}

		if state.held_pile.cards[0] != nil {
			state.held_pile.pos = getmousepos()
			draw_pile(&state.held_pile)

			if rl.IsMouseButtonReleased(.LEFT) {
				for &pile in state.piles {
					if &pile == state.held_pile.source_pile {
						continue
					}

					if pile_collides(&pile, getmousepos()) &&
					   pile_can_place(&pile, &state.held_pile) {
						top, idx := pile_get_top(state.held_pile.source_pile)
						if top != nil {
							top.flipped = true
						}
						held_pile_send_to_pile(&state.held_pile, &pile)
						break
					}
				}

				if state.held_pile.cards[0] != nil {
					held_pile_send_to_pile(&state.held_pile, state.held_pile.source_pile)
				}
			}
		}


		rl.DrawFPS(0, 0)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}
