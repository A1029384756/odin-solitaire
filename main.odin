package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:prof/spall"
import "core:slice"
import k2 "karl2d"

EASYWIN :: #config(EASYWIN, false)
PROFILING :: #config(PROFILING, false)
MEMTRACK :: #config(MEMTRACK, ODIN_DEBUG)

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
	update_tag:  f64,
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

STACK_COLOR :: k2.Color{0x1F, 0x1F, 0x1F, 0x5F}

CARD_SIZE_UNITS :: Vector2{100, 134}
PILE_SPACING :: 40

UNIT_SIZE :: Vector2{1000, 1000}
UNIT_ASPECT :: UNIT_SIZE.x / UNIT_SIZE.y

Icon :: enum {
	RESET,
	SHOW_PERF,
	BACK,
	FORWARD,
}

icon_rect := [Icon]k2.Rect {
	.RESET     = k2.Rect{3 * ICON_SIZE, 13 * ICON_SIZE, ICON_SIZE, ICON_SIZE},
	.SHOW_PERF = k2.Rect{14 * ICON_SIZE, 12 * ICON_SIZE, ICON_SIZE, ICON_SIZE},
	.BACK      = k2.Rect{2 * ICON_SIZE, 7 * ICON_SIZE, ICON_SIZE, ICON_SIZE},
	.FORWARD   = k2.Rect{3 * ICON_SIZE, 7 * ICON_SIZE, ICON_SIZE, ICON_SIZE},
}

ease_out_elastic :: #force_inline proc(t: f32) -> f32 {
	C4: f32 : 2 * math.PI / 3
	return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * C4) + 1
}

ease_out_quint :: #force_inline proc(t: f32) -> f32 {
	return 1 - math.pow(1 - t, 5)
}

units_to_px :: #force_inline proc(coord: Vector2) -> Vector2 {
	return coord * state.unit_to_px_scaling
}

px_to_units :: #force_inline proc(px: Vector2) -> Vector2 {
	return px / state.unit_to_px_scaling
}

draw_card :: proc(card: ^Card) {
	assert(card != nil, "card should exist")

	win_midpoint := state.resolution.x / 2
	px_pos := units_to_px(card.drawn_pos + state.camera_pos)
	px_size := units_to_px(CARD_SIZE_UNITS)
	px_pos += px_size / 2
	scaled_size := px_size * card.scale
	px_pos.x -= (scaled_size.x - px_size.x) / 2

	shadow_pos := px_pos
	shadow_pos.x -= 0.2 * (card.scale - 1) * (win_midpoint - shadow_pos.x)

	px_pos.y -= 2 * (scaled_size.y - px_size.y)
	px_size = scaled_size

	output_pos := k2.Rect{px_pos.x, px_pos.y, px_size.x, px_size.y}

	parabolic_show: f32 = max(0.3, math.pow((card.flip_prog - 0.5) * 2, 2))
	output_pos.x += (1 - parabolic_show) * output_pos.w / 2
	output_pos.w *= parabolic_show

	if card.scale > 1 {
		shadow_rect := k2.Rect{shadow_pos.x, shadow_pos.y, px_size.x, px_size.y}
		k2.draw_texture_fit(
			BLANK,
			{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
			shadow_rect,
			px_size / 2,
			card.angle,
			{0x2F, 0x2F, 0x2F, 0x2F},
		)
	}

	k2.draw_texture_fit(
		BLANK,
		{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
		output_pos,
		px_size / 2,
		card.angle,
	)

	tex_coord: Vector2 = {f32(card.rank), f32(card.suit)} * CARD_TEX_SIZE
	tex_rect := k2.Rect{tex_coord.x, tex_coord.y, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}

	k2.draw_texture_fit(
		CARDS,
		tex_rect,
		output_pos,
		px_size / 2,
		card.angle,
		{0xFF, 0xFF, 0xFF, u8(255 * card.flip_prog)},
	)
	k2.draw_texture_fit(
		BACKS,
		{0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y},
		output_pos,
		px_size / 2,
		card.angle,
		{0xFF, 0xFF, 0xFF, u8(255 * (1 - card.flip_prog))},
	)
}

card_collides_point :: proc(card: Vector2, coord: Vector2) -> bool {
	return(
		card.x < coord.x - state.camera_pos.x &&
		card.y < coord.y - state.camera_pos.y &&
		card.x + CARD_SIZE_UNITS.x > coord.x - state.camera_pos.x &&
		card.y + CARD_SIZE_UNITS.y > coord.y - state.camera_pos.y \
	)
}

cards_collide :: proc(a: Vector2, b: Vector2) -> bool {
	return abs(a.x - b.x) < CARD_SIZE_UNITS.x && abs(a.y - b.y) < CARD_SIZE_UNITS.y
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

	if pile == &state.discard {
		draw_discard(pile, &state.held_pile)
		return
	}

	px_pos := units_to_px(pile.pos + state.camera_pos)
	px_size := units_to_px(CARD_SIZE_UNITS)
	rect := k2.Rect{px_pos.x, px_pos.y, px_size.x, px_size.y}
	k2.draw_texture_fit(BLANK, {0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}, rect, 0, 0, STACK_COLOR)
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
	px_size := units_to_px(CARD_SIZE_UNITS)
	rect := k2.Rect{px_pos.x, px_pos.y, px_size.x, px_size.y}
	k2.draw_texture_fit(BLANK, {0, 0, CARD_TEX_SIZE.x, CARD_TEX_SIZE.y}, rect, 0, 0, STACK_COLOR)

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
			k2.get_frame_time() * 40 / math.pow(f32(idx + 1), 0.6),
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
	pile.update_tag = k2.get_time()
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
		camera_pos = state.camera_pos,
		game_time  = state.game_time,
		render_tex = state.render_tex,
		resolution = state.resolution,
	}

	switch settings.difficulty {
	case .EASY:
		create_solvable_board(&state.board)
	case .RANDOM:
		create_random_board(&state.board)
	}

	pile_num := 0
	for &stack, idx in state.stacks {
		stack.pos = {500 + (CARD_SIZE_UNITS.x + 10) * f32(idx), 70}
		stack.max_visible = 1
		state.mru_piles[pile_num] = &stack
		pile_num += 1
	}

	state.hand.spacing.x = 4
	state.hand.pos = {50, 70}
	state.hand.max_visible = 52
	state.mru_piles[pile_num] = &state.hand
	pile_num += 1

	state.discard.spacing.x = -20
	state.discard.pos = {350, 70}
	state.discard.max_visible = 3
	state.mru_piles[pile_num] = &state.discard
	pile_num += 1


	for &pile, idx in state.piles {
		pile.spacing.y = PILE_SPACING
		pile.pos = {f32(idx) * (CARD_SIZE_UNITS.x + 10) + 200, 250}
		pile.max_visible = 52
		state.mru_piles[pile_num] = &pile
		pile_num += 1
	}

	state.held_pile.spacing.y = PILE_SPACING
	state.held_pile.max_visible = 52
}

State :: struct {
	// rendering
	render_tex:         k2.Render_Texture,
	camera_pos:         Vector2,
	mouse_pos:          Vector2,
	resolution:         Vector2,
	screen_resolution:  Vector2,
	unit_to_px_scaling: Vector2,
	// board
	using board:        Board,
	// player items
	held_pile:          Held_Pile,
	// render info
	mru_piles:          [13]^Pile,
	diff_menu_edit:     bool,
	gui_locked:         bool,
	// game stats
	game_time:          f32,
	has_won:            bool,
	// win screen
	fade_in:            f32,
}

CARDS: k2.Texture
BLANK: k2.Texture
BACKS: k2.Texture
CARD_TEX_SIZE: Vector2 : {71, 95}

ICONS: k2.Texture
ICON_SIZE :: 18

state: State
settings: Settings

main :: proc() {
	when PROFILING {
		spall_ctx = spall.context_create("solitaire.spall")
		defer spall.context_destroy(&spall_ctx)

		buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)

		spall_buffer = spall.buffer_create(buffer_backing)
		defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	}

	when MEMTRACK {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	k2.init(800, 600, "Solitaire", {window_mode = .Windowed_Resizable})
	defer k2.shutdown()

	load_settings()
	init_state(&state)

	CARDS = k2.load_texture_from_file("assets/playing_cards.png")
	defer k2.destroy_texture(CARDS)

	BLANK = k2.load_texture_from_file("assets/blank_card.png")
	defer k2.destroy_texture(BLANK)

	BACKS = k2.load_texture_from_file("assets/card_backs.png")
	defer k2.destroy_texture(BACKS)

	ICONS = k2.load_texture_from_file("assets/icons.png")
	defer k2.destroy_texture(ICONS)

	state.render_tex = k2.create_render_texture(800, 800)
	defer k2.destroy_render_texture(state.render_tex)

	background_shader := k2.load_shader_from_file("shaders/default.vs", "shaders/fbm.fs")
	defer k2.destroy_shader(background_shader)

	time_loc := background_shader.constant_lookup["u_time"]
	k2.set_shader_constant(background_shader, time_loc, state.game_time)

	hue_loc := background_shader.constant_lookup["u_hue"]
	k2.set_shader_constant(background_shader, hue_loc, settings.hue_shift)

	res_loc := background_shader.constant_lookup["u_resolution"]
	state.resolution = k2.get_screen_size()
	k2.set_shader_constant(background_shader, res_loc, state.resolution)

	scanline_shader := k2.load_shader_from_file("shaders/default.vs", "shaders/scanlines.fs")
	defer k2.destroy_shader(scanline_shader)

	scanline_res_loc := scanline_shader.constant_lookup["u_resolution"]
	k2.set_shader_constant(scanline_shader, scanline_res_loc, state.resolution)

	for k2.update() {
		// general update
		k2.clear(k2.BLACK)
		// window resizing
		{
			new_resolution := k2.get_screen_size()
			if settings.scale_changed || state.screen_resolution != new_resolution {
				state.resolution = new_resolution * settings.render_scale
				state.screen_resolution = new_resolution
				k2.destroy_render_texture(state.render_tex)
				state.render_tex = k2.create_render_texture(
					int(state.resolution.x),
					int(state.resolution.y),
				)
				k2.set_shader_constant(background_shader, res_loc, state.resolution)
				k2.set_shader_constant(scanline_shader, scanline_res_loc, state.resolution)
				settings.scale_changed = false
			}
		}

		state.game_time += k2.get_frame_time()
		state.mouse_pos =
			settings.render_scale * k2.get_mouse_position() / state.unit_to_px_scaling

		// camera horizontal centering
		{
			aspect := state.resolution.x / state.resolution.y

			win_size_unit: Vector2
			if aspect > UNIT_ASPECT {
				win_size_unit = {UNIT_SIZE.y * aspect, UNIT_SIZE.y}
			} else {
				win_size_unit = {UNIT_SIZE.x, UNIT_SIZE.x / aspect}
			}

			state.unit_to_px_scaling = state.resolution / win_size_unit
			win_size_units := px_to_units(state.resolution)

			horz_overflow := win_size_units.x - UNIT_SIZE.x
			if horz_overflow > 0 {
				state.camera_pos.x = horz_overflow / 2
			} else {
				state.camera_pos.x = 0
			}
		}

		// card animation
		{
			state.held_pile.pos = state.mouse_pos
			for &card in state.cards {
				if card.held {
					mouse_delta := px_to_units(
						settings.render_scale * k2.get_mouse_delta() / (50 * k2.get_frame_time()),
					)
					if linalg.length(mouse_delta) > 0 {
						angle := clamp(
							math.asin(mouse_delta.x / linalg.length(mouse_delta)) *
							(min(abs(mouse_delta.x), 100) / 40),
							-math.PI / 2.3,
							math.PI / 2.3,
						)
						card.angle = math.angle_lerp(card.angle, angle, k2.get_frame_time() * 4)
					} else {
						card.angle = math.angle_lerp(card.angle, 0, k2.get_frame_time() * 6)
					}
				} else {
					if linalg.distance(card.pos, card.drawn_pos) > 0.1 {
						card.angle = math.lerp(card.angle, 0, k2.get_frame_time() * 20)
					} else {
						card.angle = math.lerp(card.angle, card.target_angle, k2.get_frame_time())
						if abs(card.angle - card.target_angle) < 0.001 {
							card.target_angle = rand.float32_range(-0.07, 0.07)
						}
					}
				}
				card.flip_prog = math.lerp(
					card.flip_prog,
					1 if card.flipped else 0,
					k2.get_frame_time() * 20,
				)

				card.scale = math.lerp(
					card.scale,
					1.1 if card.held else 1,
					k2.get_frame_time() * 10,
				)

				if !card.held {
					card.drawn_pos = math.lerp(card.drawn_pos, card.pos, k2.get_frame_time() * 10)
				}
			}
		}

		// input handlers
		if !state.has_won && !settings.menu_visible {
			if k2.mouse_button_went_down(.Left) {
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
		}

		if k2.mouse_button_went_up(.Left) {
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
								min(
									held_pos.x + CARD_SIZE_UNITS.x,
									top_pos.x + CARD_SIZE_UNITS.y,
								) -
								max(held_pos.x, top_pos.x),
							) *
							max(
								0,
								min(
									held_pos.y + CARD_SIZE_UNITS.x,
									top_pos.y + CARD_SIZE_UNITS.y,
								) -
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

		// rendering
		{
			// update MRU for render
			slice.sort_by(state.mru_piles[:], proc(a, b: ^Pile) -> bool {
				return a.update_tag < b.update_tag
			})

			// viewport
			{
				k2.set_render_texture(state.render_tex)
				defer k2.set_render_texture(nil)
				k2.clear(k2.BLACK)
				// card rendering
				{
					{
						k2.set_shader(background_shader)
						defer k2.set_shader(nil)
						k2.set_shader_constant(background_shader, time_loc, state.game_time)
						k2.set_shader_constant(background_shader, hue_loc, settings.hue_shift)
						k2.draw_rect({0, 0, state.resolution.x, state.resolution.y}, k2.WHITE)
					}

					for pile in state.mru_piles {
						draw_pile(pile)
					}

					draw_held_pile(&state.held_pile)
				}
				// ui rendering
				{
					// toolbar
					{
						if state.has_won || settings.menu_visible {gui_locked = true}
						defer gui_locked = false

						restart_loc := units_to_px({0, 0})
						restart_size := units_to_px({225, 50})
						if text_button(
							{restart_loc.x, restart_loc.y, restart_size.x, restart_size.y},
							"Restart",
							k2.DARK_GRAY,
							k2.LIGHT_GRAY,
							k2.RL_SKYBLUE,
							40,
						) {init_state(&state)}

						settings_loc := units_to_px({250, 0})
						settings_size := units_to_px({225, 50})
						if text_button(
							{settings_loc.x, settings_loc.y, settings_size.x, settings_size.y},
							"Settings",
							k2.DARK_GRAY,
							k2.LIGHT_GRAY,
							k2.RL_SKYBLUE,
							40,
						) {
							settings.menu_visible = true
							settings.menu_fade = 0
						}

						// performance overlay
						if settings.show_perf {
							perf_px := units_to_px(
								{state.resolution.x / state.unit_to_px_scaling.x - 150, 0},
							)
							perf_size := units_to_px({150, 50})
							k2.draw_rect(
								{perf_px.x, perf_px.y, perf_size.x, perf_size.y},
								k2.LIGHT_GRAY,
							)
							k2.draw_rect_outline(
								{perf_px.x, perf_px.y, perf_size.x, perf_size.y},
								3,
								k2.DARK_GRAY,
							)
							fps := fmt.tprintf("%v FPS", 1 / k2.get_frame_time())
							centered_text(fps, 20, perf_px + perf_size / 2, k2.DARK_GRAY)
						}
					}

					settings_menu()

					if state.has_won {
						victory_screen()
					}
				}
			}

			// postprocessing
			{
				k2.set_shader(scanline_shader)
				defer k2.set_shader(nil)
				scanline_shader.texture_bindpoints[scanline_shader.texture_lookup["texture0"]] =
					state.render_tex.texture.handle

				k2.draw_texture_fit(
					state.render_tex.texture,
					k2.get_texture_rect(state.render_tex.texture),
					{0, 0, state.screen_resolution.x, state.screen_resolution.y},
				)
			}
			k2.present()
			free_all(context.temp_allocator)
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
