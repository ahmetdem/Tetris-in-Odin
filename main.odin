package main

import "base:intrinsics"
import "core:fmt"
import "core:math/rand"
import "core:mem"
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
	gameBoard:    [200]i8,
	score:        i16,
	currentBlock: Block,
	nextBlock:    Block,
	gameFinished: bool,
}

Block :: struct {
	pos:       v2, // x, y position of the block
	color:     Color,
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

Color :: enum {
	YELLOW,
	GOLD,
	ORANGE,
	PINK,
	RED,
	MAROON,
	LIME,
	DARKGREEN,
	BLUE,
	DARKBLUE,
	PURPLE,
	VIOLET,
	DARKPURPLE,
	BEIGE,
	DARKBROWN,
	MAGENTA,
	RAYWHITE,
	BLACK,
}

ColorMap: map[Color]rl.Color = {
	.YELLOW     = rl.YELLOW,
	.GOLD       = rl.GOLD,
	.ORANGE     = rl.ORANGE,
	.PINK       = rl.PINK,
	.RED        = rl.RED,
	.MAROON     = rl.MAROON,
	.LIME       = rl.LIME,
	.DARKGREEN  = rl.DARKGREEN,
	.BLUE       = rl.BLUE,
	.DARKBLUE   = rl.DARKBLUE,
	.PURPLE     = rl.PURPLE,
	.VIOLET     = rl.VIOLET,
	.DARKPURPLE = rl.DARKPURPLE,
	.BEIGE      = rl.BEIGE,
	.DARKBROWN  = rl.DARKBROWN,
	.MAGENTA    = rl.MAGENTA,
	.RAYWHITE   = rl.RAYWHITE,
	.BLACK      = rl.BLACK,
}

init_game_struct :: proc(#no_alias game: ^Game) {
	using game

	// Initilize the game Board
	for i in 0 ..< 200 {
		gameBoard[i] = 0
	}

	score = 0
	gameFinished = false

	currentBlock = create_random_block()
	nextBlock = create_random_block()
}

draw_info :: proc(#no_alias game: ^Game) {
	using game

	buf: [8]byte
	result := strconv.itoa(buf[:], int(score))
	cloned := strings.clone_to_cstring(result)

	rl.DrawText("SCORE", 430, 10, 30, rl.GRAY)
	rl.DrawText(cloned, 430, 45, 30, rl.GRAY)

	delete(cloned)
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

	for row in 0 ..< 20 {
		for col in 0 ..< 10 {
			if gameBoard[row * 10 + col] == 1 {
				posV: v2 =  {
					f32(col) * CELL_SIZE + GRID_OFFSET_X,
					f32(row) * CELL_SIZE + GRID_OFFSET_Y,
				}
				draw_block(posV, ColorMap[currentBlock.color])
			}
		}
	}

	draw_block_types(&currentBlock)
}

draw_block :: proc(v: v2, color: rl.Color) {
	lineThick: f32 = 2.0

	// NOTE:LSP'nin {CELL_SIZE, CELL_SIZE} ifadesini otomatik v2 algılaması.
	rl.DrawRectangleV(v, {CELL_SIZE, CELL_SIZE}, color)

	outer_rec: rl.Rectangle = {
		x      = f32(v.x),
		y      = f32(v.y),
		width  = CELL_SIZE,
		height = CELL_SIZE,
	}

	rl.DrawRectangleLinesEx(outer_rec, lineThick, rl.GRAY)
}

draw_block_types :: proc(block: ^Block, fixed: bool = false) {
	color: rl.Color = ColorMap[block.color]

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
				block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE + 300,
				block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE + 200,
			}

			draw_block(posV, color)
		}
	} else {
		for i in 0 ..< 4 {
			posV: v2 =  {
				block.pos.x + f32(block.shape[i, 0]) * CELL_SIZE,
				block.pos.y + f32(block.shape[i, 1]) * CELL_SIZE,
			}

			rl.DrawCircleV(posV, 2, rl.RED)
			draw_block(posV, color)
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
	color = Color.BEIGE // rand.choice_enum(Color)

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
			delete(currentBlock.midPoints)
			set_indexes_by_block_pos(game)

			when ODIN_DEBUG {
				print_game_board(game)
			}

			currentBlock = nextBlock
			nextBlock = create_random_block()

			delete_complete_lines(game)
			IS_READY = true
			return
		}

		currentBlock.pos.y += movement
	}

	// FIXME: Do not let the player to rotate if the block is near edges
	if IsKeyPressed(KeyboardKey.R) {
		rotate_block(&currentBlock)
		check_collision(&currentBlock, &gameBoard, Move.ROTATE)
	}
}

delete_complete_lines :: proc(game: ^Game) {
	using game

	for i := 0; i < 10; i += 1 {
		if gameBoard[i] == 1 {
			gameFinished = true
		}
	}

	for row := 0; row < 20; row += 1 { 	// Loop through each row
		isComplete: bool = true

		// Check if the current row is complete
		for col := 0; col < 10; col += 1 {
			if gameBoard[row * 10 + col] == 0 {
				isComplete = false
				break
			}
		}

		// If the row is complete, remove it and move the rows above down
		if isComplete {
			// Move rows above down
			for r := row; r > 0; r -= 1 {
				for col := 0; col < 10; col += 1 {
					gameBoard[r * 10 + col] = gameBoard[(r - 1) * 10 + col]
				}
			}

			// Clear the top row
			for col := 0; col < 10; col += 1 {
				gameBoard[col] = 0
			}

			score += 100

			when ODIN_DEBUG {
				fmt.printfln("Row %d is complete.", row)
			}
		}
	}
}

main :: proc() {
	when ODIN_DEBUG { 	// Sunum: When keyword ve Free olmayan allocateleri göstermesi
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "TETRIS IN ODIN!")

	game := Game{}
	using game

	init_game_struct(&game)
	rl.SetTargetFPS(30)

	for !rl.WindowShouldClose() {

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		draw_game_board(&game)
		draw_info(&game)

		update(&game)

		if gameFinished {
			break
		}

		rl.EndDrawing()
	}

	delete(currentBlock.midPoints)
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

	#partial switch move {
	case .DOWN:
		// move downwards
		for &pos, i in block.midPoints {
			pos.y += movement

			if pos.y > GRID_HEIGHT + GRID_OFFSET_Y {
				down = true
			}

			if check_collision(&game.currentBlock, &game.gameBoard, Move.DOWN) {
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

			if check_collision(&game.currentBlock, &game.gameBoard, Move.RIGHT) {
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

			if check_collision(&game.currentBlock, &game.gameBoard, Move.LEFT) {
				return true
			}
		}

		for &pos in block.midPoints {
			pos.x += -movement
		}

		return false
	}

	return false
}

@(optimization_mode = "speed")
check_collision :: proc(block: ^Block, gameBoard: ^[200]i8, move: Move) -> bool {
	meanX: f32 = 0.0
	xIndex, yIndex: i16 = 0, 0

	for i := 1; i < 16; i += 4 {
		meanX = (block.midPoints[i + 1].x + block.midPoints[i].x) / 2

		xIndex = i16(meanX / CELL_SIZE)
		yIndex = i16(block.midPoints[i + 1].y / CELL_SIZE)

		#partial switch move {
		case .LEFT:
			xIndex -= 1

		case .RIGHT:
			xIndex += 1

		case .ROTATE:
			if xIndex >= GRID_WIDTH / CELL_SIZE {
				when ODIN_DEBUG {
					fmt.printfln("X_INDEX: %d --- Y_INDEX: %d", xIndex, yIndex)
				}

				return true
			}
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

	when ODIN_DEBUG {
		print_mid_points(&currentBlock)
	}

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

@(cold)
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

@(cold)
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
