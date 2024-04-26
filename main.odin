package main

// Include the SDL2 binding
import "core:fmt"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

v2 :: rl.Vector2

SCREEN_WIDTH :: 600
SCREEN_HEIGHT :: 720

GRID_OFFSET_X :: 10.0
GRID_OFFSET_Y :: 10.0

GRID_HEIGHT :: f32(SCREEN_HEIGHT) - GRID_OFFSET_Y * 2
GRID_WIDTH :: GRID_HEIGHT / 2

CELL_SIZE :: GRID_WIDTH / 10

Game :: struct {
	game_board: [200]i8,
	score:      i16,
}

Block :: struct {
	x:     i32,
	y:     i32,
	shape: matrix[4, 2]i8,
}

BlockType :: enum {
	LBlock,
	OBlock,
	TBlock,
	JBlock,
	SBlock,
	ZBlock,
}

init_game_struct :: proc(game: ^Game) {
	using game

	// Initilize the game Board
	for i in 0 ..< 200 {
		game_board[i] = 0
	}

	score = 0
}

draw_info :: proc(game: ^Game) {
	using game

	buf: [4]byte

	result := strconv.itoa(buf[:], int(score))

	rl.DrawText("SCORE", 430, 10, 30, rl.GRAY)
	rl.DrawText(strings.clone_to_cstring(result), 430, 45, 30, rl.GRAY)

	// TODO: Show the next piece of block here.
}

draw_game_board :: proc(game: ^Game) {
	using game

	for i := 0; i < 11; i += 1 {
		x: f32 = f32(i) * CELL_SIZE + GRID_OFFSET_X
		rl.DrawLineV({x, GRID_OFFSET_X}, {x, GRID_OFFSET_Y + GRID_HEIGHT}, rl.DARKGRAY)
	}

	for i := 0; i < 21; i += 1 {
		y: f32 = f32(i) * CELL_SIZE + GRID_OFFSET_Y
		rl.DrawLineV({GRID_OFFSET_X, y}, {GRID_OFFSET_Y + GRID_WIDTH, y}, rl.DARKGRAY)
	}
}

draw_block :: proc(x, y: i32) {
	lineThick: f32 = 2.0

	rl.DrawRectangle(x, y, i32(CELL_SIZE), i32(CELL_SIZE), rl.LIGHTGRAY)

	outer_rec: rl.Rectangle = {
		x      = f32(x),
		y      = f32(y),
		width  = CELL_SIZE,
		height = CELL_SIZE,
	}

	rl.DrawRectangleLinesEx(outer_rec, lineThick, rl.GRAY)
}

draw_block_types :: proc(block: ^Block) {
	using block

	for i in 0 ..< 4 {
		draw_block(
			x = x + i32(shape[i, 0]) * i32(CELL_SIZE),
			y = y + i32(shape[i, 1]) * i32(CELL_SIZE),
		)
	}
}

create_random_block :: proc() -> Block {
	block: Block

	using block

	x = i32(GRID_WIDTH / 2 + GRID_OFFSET_X)
	y = 10

	t: BlockType = rand.choice_enum(BlockType)

	switch t {
	case .LBlock:
		shape = {0, 0, 0, 1, 0, 2, 1, 2}
	case .OBlock:
		shape = {0, 0, 0, 1, 1, 0, 1, 1}
	case .TBlock:
		shape = {0, 1, 1, 0, 1, 1, 1, 2}
	case .JBlock:
		shape = {0, 2, 1, 0, 1, 1, 1, 2}
	case .SBlock:
		shape = {0, 1, 0, 2, 1, 0, 1, 1}
	case .ZBlock:
		shape = {0, 0, 0, 1, 1, 1, 1, 2}
	}

	return block
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "TETRIS IN ODIN!")

	game := Game{}
	using game

	m: matrix[4, 2]i8 = {0, 0, 0, 1, 0, 2, 1, 2}

	block: Block = {45, 10, m}

	init_game_struct(&game)

	for !rl.WindowShouldClose() {
		// update the game logic here 
		rl.SetTargetFPS(2)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		draw_game_board(&game)
		draw_info(&game)

		randomBlock: Block = create_random_block()
		draw_block_types(&randomBlock)

		block.y += 25

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
