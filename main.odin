package main

import "base:intrinsics"
import "core:fmt"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

v2 :: rl.Vector2

IS_READY: bool = true

SCREEN_WIDTH :: 600
SCREEN_HEIGHT :: 720

GRID_OFFSET_X :: 10.0
GRID_OFFSET_Y :: 10.0

GRID_HEIGHT :: SCREEN_HEIGHT - GRID_OFFSET_Y * 2 // 700
GRID_WIDTH :: GRID_HEIGHT / 2 // 350
CELL_SIZE :: GRID_WIDTH / 10 // 35

Game :: struct {
	gameBoard:      [200]i8,
	collidedBlocks: [dynamic]Block,
	score:          i16,
	currentBlock:   Block,
	nextBlock:      Block,
}

Block :: struct {
	pos:       v2, // x, y position of the block
	shape:     matrix[4, 2]i8,
	type:      BlockType,
	midPoints: [dynamic]v2,
}

BlockType :: enum u8 {
	LBlock,
	OBlock,
	TBlock,
	JBlock,
	SBlock,
	ZBlock,
	IBlock,
}

Move :: enum u8 {
	DOWN,
	LEFT,
	RIGHT,
	UP,
	ROTATE,
}

init_game_struct :: proc(#no_alias game: ^Game) {
	using game

	// Initilize the game Board
	for i in 0 ..< 200 {
		gameBoard[i] = 0
	}

	score = 0

	currentBlock = create_random_block()
	nextBlock = create_random_block()
}

draw_info :: proc(#no_alias game: ^Game) {
	using game

	buf: [8]byte

	result := strconv.itoa(buf[:], int(score))

	rl.DrawText("SCORE", 430, 10, 30, rl.GRAY)
	rl.DrawText(strings.clone_to_cstring(result), 430, 45, 30, rl.GRAY)

	draw_block_types(&nextBlock, true)

	for &block in collidedBlocks {
		draw_block_types(&block)
	}
}

draw_game_board :: proc(#no_alias game: ^Game) {
	using game

	for i := 0; i < 11; i += 1 {
		x: f32 = f32(i) * CELL_SIZE + GRID_OFFSET_X
		rl.DrawLineV({x, GRID_OFFSET_X}, {x, GRID_OFFSET_Y + GRID_HEIGHT}, rl.DARKGRAY)
	}

	for i := 0; i < 21; i += 1 {
		y: f32 = f32(i) * CELL_SIZE + GRID_OFFSET_Y
		rl.DrawLineV({GRID_OFFSET_X, y}, {GRID_OFFSET_Y + GRID_WIDTH, y}, rl.DARKGRAY)
	}

	draw_block_types(&currentBlock)
}

draw_block :: proc(v: v2) {
	lineThick: f32 = 2.0

	// LSP'nin {CELL_SIZE, CELL_SIZE} ifadesini otomatik v2 algılaması.
	rl.DrawRectangleV(v, {CELL_SIZE, CELL_SIZE}, rl.LIGHTGRAY)

	outer_rec: rl.Rectangle = {
		x      = f32(v.x),
		y      = f32(v.y),
		width  = CELL_SIZE,
		height = CELL_SIZE,
	}

	rl.DrawRectangleLinesEx(outer_rec, lineThick, rl.GRAY)
}

draw_block_types :: proc(block: ^Block, fixed: bool = false) {

	if IS_READY {
		add_mid_points_to_block(block)
		IS_READY = false
	}

	for &pos in block.midPoints {
		rl.DrawCircleV(pos, 2, rl.YELLOW)
	}

	if fixed {
		for i in 0 ..< 4 {
			posV: v2 =  {
				block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE + 200,
				block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE + 200,
			}

			draw_block(posV)
		}
	} else {
		for i in 0 ..< 4 {
			posV: v2 =  {
				block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE,
				block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE,
			}

			denemeV: v2 = {block.pos.x, block.pos.y}

			rl.DrawCircleV(posV, 2, rl.RED)
			rl.DrawCircleV(denemeV, 2, rl.GREEN)
			draw_block(posV)
		}
	}
}

rotate_block :: proc(block: ^Block) {

	@(static)
	rotation: i8 = 0
	rotation += 1

	// NOTE: Sunumda burasını örnek type olarak gösterebilirsin (enumerated array).
	rotationMatrices: [BlockType][4]matrix[4, 2]i8 = {
		.LBlock =  {
			{0, 0, 0, 1, 0, 2, 1, 2},
			{0, 1, 1, 1, -1, 1, -1, 2},
			{0, 0, 0, 1, 0, 2, -1, 0},
			{0, 1, 1, 1, -1, 1, 1, 0},
		},
		.OBlock =  {
			{0, 0, 0, 1, 1, 0, 1, 1},
			{0, 0, 0, 1, 1, 0, 1, 1},
			{0, 0, 0, 1, 1, 0, 1, 1},
			{0, 0, 0, 1, 1, 0, 1, 1},
		},
		.TBlock =  {
			{0, 0, 0, 1, 0, 2, -1, 1},
			{0, 0, 0, 1, -1, 1, 1, 1},
			{0, 0, 0, 1, 0, 2, 1, 1},
			{-1, 1, 1, 1, 0, 1, 0, 2},
		},
		.JBlock =  {
			{0, 0, 0, 1, 0, 2, -1, 2},
			{-1, 0, -1, 1, 0, 1, 1, 1},
			{0, 0, 0, 1, 0, 2, 1, 0},
			{0, 1, -1, 1, 1, 1, 1, 2},
		},
		.SBlock =  {
			{0, 0, 0, 1, -1, 1, -1, 2},
			{-1, 0, 0, 0, 0, 1, 1, 1},
			{1, 0, 1, 1, 0, 1, 0, 2},
			{-1, 1, 0, 1, 0, 2, 1, 2},
		},
		.ZBlock =  {
			{-1, 0, -1, 1, 0, 1, 0, 2},
			{-1, 1, 0, 0, 0, 1, 1, 0},
			{0, 0, 0, 1, 1, 1, 1, 2},
			{0, 1, 0, 2, -1, 2, 1, 1},
		},
		.IBlock =  {
			{0, 1, 0, 2, 0, 3, 0, 4},
			{1, 0, 2, 0, 3, 0, 4, 0},
			{0, 1, 0, 2, 0, 3, 0, 4},
			{1, 0, 2, 0, 3, 0, 4, 0},
		},
	}

	// TODO: Handle the big I block
	rotation = rotation % 4

	// Change the shape of the block according to the rotation variable
	block.shape = rotationMatrices[block.type][rotation]
	add_mid_points_to_block(block)
}

create_random_block :: proc() -> Block {
	block: Block
	using block

	pos.x = GRID_WIDTH / 2 + GRID_OFFSET_X
	pos.y = 10

	t: BlockType = rand.choice_enum(BlockType)
	type = t

	switch t {
	case .LBlock:
		shape = {0, 0, 0, 1, 0, 2, 1, 2}
	case .OBlock:
		shape = {0, 0, 0, 1, 1, 0, 1, 1}
	case .TBlock:
		shape = {0, 0, 0, 1, 0, 2, -1, 1}
	case .JBlock:
		shape = {0, 0, 0, 1, 0, 2, -1, 2}
	case .SBlock:
		shape = {0, 1, 0, 2, 1, 0, 1, 1}
	case .ZBlock:
		shape = {0, 0, 0, 1, 1, 1, 1, 2}
	case .IBlock:
		shape = {0, 1, 0, 2, 0, 3, 0, 4}
	}

	return block
}

update :: proc(#no_alias game: ^Game) {
	using rl, game

	movement: f32 = CELL_SIZE
	if IsKeyDown(KeyboardKey.LEFT) {
		if move_mid_points(game, Move.LEFT) {
			return
		}

		currentBlock.pos.x += -movement
	}

	if IsKeyDown(KeyboardKey.RIGHT) {
		if move_mid_points(game, Move.RIGHT) {
			return
		}

		currentBlock.pos.x += movement
	}

	if IsKeyDown(KeyboardKey.UP) {
		move_mid_points(game, Move.UP)
		currentBlock.pos.y -= movement
	}

	if IsKeyDown(KeyboardKey.DOWN) {
		if move_mid_points(game, Move.DOWN) {
			// FIXME: Handle the next block being the same with the current one.
			append(&collidedBlocks, currentBlock)
			delete(currentBlock.midPoints)

			set_indexes_by_block_pos(game)
			print_game_board(game)

			nextBlock = create_random_block()
			currentBlock = nextBlock

			IS_READY = true
			return
		}

		currentBlock.pos.y += movement
	}

	// FIXME: Do not let the player to rotate if the block is near edges
	if IsKeyPressed(KeyboardKey.R) {
		rotate_block(&currentBlock)
		move_mid_points(game, Move.ROTATE)
	}
}

is_collided_with_game_board :: proc(game: ^Game) -> bool {
	return false
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "TETRIS IN ODIN!")

	game := Game{}
	using game

	init_game_struct(&game)
	rl.DrawFPS(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, rl.WHITE)

	for !rl.WindowShouldClose() {
		// update the game logic here 

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		draw_game_board(&game)
		draw_info(&game)

		update(&game)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

add_mid_points_to_block :: proc(block: ^Block) {

	// Meaning the midpoints should be reset
	if len(block.midPoints) >= 16 {
		clear_dynamic_array(&block.midPoints)
	}

	// find the middle points 
	for i in 0 ..< 4 {
		m1: v2 =  {
			block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE + CELL_SIZE / 2,
			block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE,
		}

		m2: v2 =  {
			block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE,
			block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE + CELL_SIZE / 2,
		}

		m3: v2 =  {
			block.pos.x + (f32(block.shape[i, 0]) + 1) * CELL_SIZE,
			block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE + (CELL_SIZE / 2),
		}

		m4: v2 =  {
			block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE + CELL_SIZE / 2,
			block.pos.y + (f32(block.shape[i, 1]) + 1) * CELL_SIZE,
		}

		append(&block.midPoints, m1, m2, m3, m4)
	}
}

move_mid_points :: proc(game: ^Game, move: Move) -> bool {
	movement: f32 = CELL_SIZE
	block: Block = game.currentBlock

	down, right, left: bool = false, false, false

	switch move {
	case .DOWN:
		// move downwards
		for &pos, i in block.midPoints {
			pos.y += movement

			if pos.y > GRID_HEIGHT + GRID_OFFSET_Y {
				down = true
			}

			if check_collision(game, Move.DOWN) { 	// 10 for down
				down = true
			}

			if down {
				for &pos in block.midPoints[i + 1:len(block.midPoints) - 1] {
					pos.y += movement
				}

				return down
			}
		}

	case .UP:
		for &pos in block.midPoints {
			pos.y -= movement
		}

	case .RIGHT:
		// move right
		for &pos in block.midPoints {
			if pos.x >= GRID_OFFSET_X + GRID_WIDTH {
				return true
			}

			if check_collision(game, Move.RIGHT) { 	// 1 for right
				return true
			}
		}

		for &pos in block.midPoints {
			pos.x += movement
		}

	case .LEFT:
		// move left
		for &pos in block.midPoints {
			if pos.x <= GRID_OFFSET_X {
				return true
			}

			if check_collision(game, Move.LEFT) { 	// -1 for left
				return true
			}
		}

		for &pos in block.midPoints {
			pos.x += -movement
		}

	// TODO: We need to move the mid points to in the case of rotation. THAT IS THE PROBLEM 
	case .ROTATE:
	}

	return false
}

check_collision :: proc(game: ^Game, move: Move) -> bool {
	using game

	meanX: f32 = 0.0
	xIndex, yIndex: i16 = 0, 0

	for i := 1; i < 16; i += 4 {
		meanX = (currentBlock.midPoints[i + 1].x + currentBlock.midPoints[i].x) / 2

		xIndex = i16(meanX / CELL_SIZE)
		yIndex = i16(currentBlock.midPoints[i + 1].y / CELL_SIZE)

		#partial switch move {
		case .LEFT:
			xIndex -= 1

		case .RIGHT:
			xIndex += 1
		}

		gameBoardIndex: i32 = i32(10 * yIndex + xIndex)

		if gameBoardIndex > 0 {
			if gameBoard[gameBoardIndex] == 1 {
				return true
			}
		}
	}

	return false
}

set_indexes_by_block_pos :: proc(game: ^Game) {
	using game

	meanX: f32 = 0.0

	xIndex: i16 = 0
	yIndex: i16 = 0

	print_mid_points(&currentBlock)

	for i := 1; i < 16; i += 4 { 	// 1, 5, 9, 13

		meanX = (currentBlock.midPoints[i + 1].x + currentBlock.midPoints[i].x) / 2

		xIndex = i16(meanX / CELL_SIZE)
		yIndex = i16(currentBlock.midPoints[i + 1].y / CELL_SIZE) - 1

		gameBoardIndex := 10 * yIndex + xIndex

		if gameBoardIndex > 0 {
			gameBoard[gameBoardIndex] = 1
		}
	}
}

print_game_board :: proc(game: ^Game) {
	using game

	for i := 0; i < 200; i += 1 {
		if i % 10 == 0 {
			fmt.println()
		}

		fmt.printf("%d ", gameBoard[i])
	}

	fmt.printf("\n\n")
}

print_mid_points :: proc(block: ^Block) {
	using block

	// FIXME: I have some garbage value like POS X: %!d(f32=3.5264356e+21) --- POS Y: %!d(f32=4.5563e-41) at the first index.
	for &pos, i in midPoints {
		fmt.printfln("POS X: %f --- POS Y: %f", pos.x, pos.y)

		if (i + 1) % 4 == 0 {
			fmt.println("")
		}
	}
}
