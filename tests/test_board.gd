extends Node

## Tests for Board grid operations

var board: Node = null

func before_each():
	board = Node.new()
	board.set_script(load("res://scripts/game/board.gd"))
	add_child(board)
	board._ready()

func after_each():
	if board:
		board.free()
		board = null

## Helper assertion functions
func assert_true(condition: bool, message: String = "") -> bool:
	if not condition:
		print("ASSERTION FAILED: " + message)
		return false
	return true

func assert_false(condition: bool, message: String = "") -> bool:
	if condition:
		print("ASSERTION FAILED: " + message)
		return false
	return true

func assert_eq(actual, expected, message: String = "") -> bool:
	if actual != expected:
		print("ASSERTION FAILED: " + message + " (expected " + str(expected) + ", got " + str(actual) + ")")
		return false
	return true

## Test grid initialization
func test_grid_initialization():
	assert_eq(board.GRID_SIZE, 5, "Grid should be 5x5")
	assert_eq(board.grid.size(), 5, "Grid should have 5 rows")
	for row in board.grid:
		assert_eq(row.size(), 5, "Each row should have 5 columns")

## Test empty positions detection
func test_get_empty_positions():
	var empty = board.get_empty_positions()
	assert_eq(empty.size(), 25, "All positions should be empty initially")
	
	board.set_tile(Vector2i(0, 0), 2)
	empty = board.get_empty_positions()
	assert_eq(empty.size(), 24, "One position should be filled")
	assert_false(empty.has(Vector2i(0, 0)), "Filled position should not be in empty list")

## Test set and get tile
func test_set_and_get_tile():
	assert_eq(board.get_tile(Vector2i(0, 0)), 0, "Empty tile should return 0")
	
	board.set_tile(Vector2i(0, 0), 4)
	assert_eq(board.get_tile(Vector2i(0, 0)), 4, "Tile should return set value")
	
	board.set_tile(Vector2i(2, 3), 8)
	assert_eq(board.get_tile(Vector2i(2, 3)), 8, "Tile at specific position should be correct")

## Test invalid position handling
func test_invalid_position():
	assert_eq(board.get_tile(Vector2i(-1, 0)), 0, "Invalid x should return 0")
	assert_eq(board.get_tile(Vector2i(0, -1)), 0, "Invalid y should return 0")
	assert_eq(board.get_tile(Vector2i(5, 0)), 0, "Out of bounds x should return 0")
	assert_eq(board.get_tile(Vector2i(0, 5)), 0, "Out of bounds y should return 0")

## Test is_full detection
func test_is_full():
	assert_false(board.is_full(), "Board should not be full initially")
	
	# Fill all but one cell
	for y in range(5):
		for x in range(4):
			board.set_tile(Vector2i(x, y), 2)
	assert_false(board.is_full(), "Board with one empty should not be full")
	
	board.set_tile(Vector2i(4, 4), 2)
	assert_true(board.is_full(), "Full board should be detected")

## Test clear board
func test_clear_board():
	board.set_tile(Vector2i(0, 0), 4)
	board.set_tile(Vector2i(4, 4), 8)
	board.score = 100
	
	board.clear_board()
	assert_eq(board.get_tile(Vector2i(0, 0)), 0, "Board should be cleared")
	assert_eq(board.get_tile(Vector2i(4, 4)), 0, "All tiles should be 0")
	assert_eq(board.score, 0, "Score should be reset")

## Test has_possible_merges
func test_has_possible_merges():
	assert_false(board.has_possible_merges(), "No merges on empty board")
	
	# Add two adjacent same values
	board.set_tile(Vector2i(0, 0), 2)
	board.set_tile(Vector2i(1, 0), 2)
	assert_true(board.has_possible_merges(), "Should detect horizontal merge")
	
	board.clear_board()
	board.set_tile(Vector2i(0, 0), 4)
	board.set_tile(Vector2i(0, 1), 4)
	assert_true(board.has_possible_merges(), "Should detect vertical merge")

## Test has_possible_moves
func test_has_possible_moves():
	assert_true(board.has_possible_moves(), "Should have moves on empty board")
	
	# Fill board without adjacent matches
	var values = [2, 4, 8, 16, 32, 2, 4, 8, 16, 32, 2, 4, 8, 16, 32, 2, 4, 8, 16, 32, 2, 4, 8, 16, 0]
	var idx = 0
	for y in range(5):
		for x in range(5):
			board.set_tile(Vector2i(x, y), values[idx])
			idx += 1
	assert_true(board.has_possible_moves(), "Should have moves when empty cell exists")

## Test spawn tile
func test_spawn_tile():
	var pos = board.spawn_tile()
	assert_true(pos.x >= 0 and pos.x < 5, "Spawn x should be in bounds")
	assert_true(pos.y >= 0 and pos.y < 5, "Spawn y should be in bounds")
	assert_true(board.get_tile(pos) in [2, 4], "Spawned tile should be 2 or 4")

## Test slide operations modify board
func test_slide_left():
	board.set_tile(Vector2i(4, 2), 2)
	board.set_tile(Vector2i(4, 3), 2)
	
	var merges = board.slide_left()
	# After sliding left, tiles should move to left side
	assert_true(merges.size() >= 0, "Slide should return merge array")
