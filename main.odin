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

GRID_HEIGHT :: SCREEN_HEIGHT - GRID_OFFSET_Y * 2
GRID_WIDTH :: GRID_HEIGHT / 2
CELL_SIZE :: GRID_WIDTH / 10

Game :: struct {
	gameBoard:    [200]bool,
	score:        i16,
	currentBlock: Block,
	nextBlock:    Block,
	dt:           f32,
}

/* Block :: struct {
	x:       f32,
	y:       f32,
	leftX:   f32,
	rightX:  f32,
	bottomY: f32,
	shape:   matrix[4, 2]i8,
	type:    BlockType,
} */

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

init_game_struct :: proc(#no_alias game: ^Game) {
	using game

	// Initilize the game Board
	for i in 0 ..< 200 {
		gameBoard[i] = false
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
	// FIXME: problem here regarding initial positions of (some) blocks

	if IS_READY {
		block_add_mid_points(block)
		IS_READY = false
	}

	// Why 0 and 4?
	// fmt.println(len(block.midPoints))

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

			// rl.DrawCircleV(posV, 2, rl.RED)
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
	// assign_min_max_of_shape(block)
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

	/* rightX = x + 2 * CELL_SIZE
	bottomY = y + 3 * CELL_SIZE

	if t == .IBlock {
		rightX = x + CELL_SIZE
		bottomY = y + 5 * CELL_SIZE

	} else if t == .OBlock {
		bottomY = y + 2 * CELL_SIZE
	} */

	// assign_min_max_of_shape(&block)
	return block
}

/* is_collided_with_ground :: proc(#no_alias game: ^Game) -> bool {
	using game

	if currentBlock.bottomY >= GRID_HEIGHT + GRID_OFFSET_Y {
		score += 10
		return true
	}

	return false
}

update :: proc(#no_alias game: ^Game) {
	using rl, game

	isTimeForNext: bool = false

	if is_collided_with_ground(game) {
		isTimeForNext = true
		currentBlock = nextBlock
	}

	if isTimeForNext {
		nextBlock = create_random_block()
	}

	movement: f32 = CELL_SIZE

	if IsKeyDown(KeyboardKey.LEFT) && currentBlock.leftX > GRID_OFFSET_X {
		currentBlock.x += -movement
		currentBlock.rightX += -movement
		currentBlock.leftX += -movement

	} else if (IsKeyDown(KeyboardKey.RIGHT) && currentBlock.rightX < GRID_WIDTH + GRID_OFFSET_X) {
		currentBlock.x += movement
		currentBlock.rightX += movement
		currentBlock.leftX += movement

	} else if (IsKeyDown(KeyboardKey.DOWN)) {
		currentBlock.bottomY += movement
		currentBlock.y += movement
	}

	if IsKeyPressed(KeyboardKey.R) {
		rotate_block(&currentBlock)
	}
} */

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "TETRIS IN ODIN!")

	game := Game{}
	using game

	init_game_struct(&game)
	rl.SetTargetFPS(40)

	for !rl.WindowShouldClose() {
		// update the game logic here 
		dt = rl.GetFrameTime()

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		draw_game_board(&game)
		draw_info(&game)

		// update(&game)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

block_add_mid_points :: proc(block: ^Block) {
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
			block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE + CELL_SIZE / 2,
		}

		m4: v2 =  {
			block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE + CELL_SIZE / 2,
			block.pos.y + (f32(block.shape[i, 1]) + 1) * CELL_SIZE,
		}

		append(&block.midPoints, m1, m2, m3, m4)
	}
}

/* assign_min_max_of_shape :: proc(block: ^Block) {
	// TODO: Maybe store the min and max values in each block
	min, max: i8 = 2, -2

	for v, i in intrinsics.matrix_flatten(block.shape) {

		if i >= 4 {
			break
		}

		if min > v {
			min = v
		}

		if max < v {
			max = v
		}
	}

	if max != 0 {
		block.rightX = block.x + f32(max + 1) * CELL_SIZE
	} else {
		block.rightX = block.x + 1.0 * CELL_SIZE
	}

	if min != 0 {
		block.leftX = block.x - CELL_SIZE
	} else {
		block.leftX = block.x
	}
} */
