extends Node
## 2048-style game board with grid logic, spawn, and merge detection
## Manages the 5x5 game grid, tile spawning, and merge operations

# Signals
signal tile_spawned(pos: Vector2i, value: int)
signal tile_merged(pos: Vector2i, value: int, merged_from: Array[Vector2i])
signal board_changed()
signal game_won()
signal no_moves_available()

# Grid configuration
const GRID_SIZE: int = 5
const CELL_SIZE: int = 64
const WIN_VALUE: int = 2048

# Grid state: 2D array where 0 = empty, value = tile value
var grid: Array = []
var score: int = 0

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	grid.clear()
	for i in range(GRID_SIZE):
		grid.append([])
		for j in range(GRID_SIZE):
			grid[i].append(0)

## Get tile value at grid position
func get_tile(pos: Vector2i) -> int:
	if _is_valid_pos(pos):
		return grid[pos.y][pos.x]
	return 0

## Set tile value at grid position
func set_tile(pos: Vector2i, value: int) -> void:
	if _is_valid_pos(pos):
		grid[pos.y][pos.x] = value
		board_changed.emit()

## Check if a position is within the grid bounds
func _is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE

## Get all empty positions on the board
func get_empty_positions() -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if grid[y][x] == 0:
				empty.append(Vector2i(x, y))
	return empty

## Check if the board is completely full
func is_full() -> bool:
	return get_empty_positions().is_empty()

## Spawn a new tile in a random empty position
## Returns the spawn position, or null if no space available
func spawn_tile() -> Vector2i:
	var empty_positions = get_empty_positions()
	if empty_positions.is_empty():
		return Vector2i(-1, -1)
	
	var pos = empty_positions[randi() % empty_positions.size()]
	# 90% chance of spawning a 2, 10% chance of spawning a 4
	var value = 2 if randf() < 0.9 else 4
	grid[pos.y][pos.x] = value
	tile_spawned.emit(pos, value)
	board_changed.emit()
	return pos

## Clear the entire board
func clear_board() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			grid[y][x] = 0
	score = 0
	board_changed.emit()

## Initialize a new game with two starting tiles
func setup_new_game() -> void:
	clear_board()
	spawn_tile()
	spawn_tile()

# ==================== MERGE DETECTION ====================

## Check if any merges are possible in the current board state
func has_possible_merges() -> bool:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var current = grid[y][x]
			if current == 0:
				continue
			# Check right neighbor
			if x + 1 < GRID_SIZE and grid[y][x + 1] == current:
				return true
			# Check bottom neighbor
			if y + 1 < GRID_SIZE and grid[y + 1][x] == current:
				return true
	return false

## Check if any moves are possible (slide or merge)
func has_possible_moves() -> bool:
	# If there's an empty cell, moves are possible
	if not is_full():
		return true
	
	# Check all adjacent pairs for potential merges
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var current = grid[y][x]
			# Check right
			if x + 1 < GRID_SIZE and grid[y][x + 1] == current:
				return true
			# Check down
			if y + 1 < GRID_SIZE and grid[y + 1][x] == current:
				return true
	return false

## Get all positions that would merge if the board slides in a direction
## Returns array of merge info: {pos, value, merged_from}
func get_merges_in_direction(direction: Vector2i) -> Array:
	var merges: Array = []
	var worked = _slide_direction(direction, true)  # dry run
	if worked:
		# Actually perform the slide to get merge positions
		var result = _slide_direction(direction, false)
		if result.size() > 0:
			merges = result
	return merges

## Slide all tiles in a direction and handle merges
## direction: Vector2i (1,0) = right, (-1,0) = left, (0,1) = down, (0,-1) = up
## dry_run: if true, only check if slide is possible without modifying
## Returns array of merge info [{pos, value, merged_from}, ...]
func _slide_direction(direction: Vector2i, dry_run: bool) -> Array:
	var merges: Array = []
	var moved: bool = false
	
	# Determine iteration order based on direction
	var x_range = range(GRID_SIZE) if direction.x <= 0 else range(GRID_SIZE - 1, -1, -1)
	var y_range = range(GRID_SIZE) if direction.y <= 0 else range(GRID_SIZE - 1, -1, -1)
	
	# Track which cells have already merged this turn
	var merged: Array = []
	for i in range(GRID_SIZE):
		merged.append([])
		for j in range(GRID_SIZE):
			merged[i].append(false)
	
	for y in y_range:
		for x in x_range:
			var current = grid[y][x]
			if current == 0:
				continue
			
			var pos = Vector2i(x, y)
			var new_pos = _find_final_position(pos, direction, merged)
			
			if new_pos != pos:
				moved = true
				if not dry_run:
					# Check for merge with target tile
					var target_value = grid[new_pos.y][new_pos.x]
					if target_value == current and not merged[new_pos.y][new_pos.x]:
						# Merge!
						var merged_value = current * 2
						grid[new_pos.y][new_pos.x] = merged_value
						grid[y][x] = 0
						merged[new_pos.y][new_pos.x] = true
						score += merged_value
						
						var merge_info = {
							"pos": new_pos,
							"value": merged_value,
							"merged_from": [pos]
						}
						merges.append(merge_info)
						tile_merged.emit(new_pos, merged_value, [pos])
						
						# Check for win condition
						if merged_value >= WIN_VALUE:
							game_won.emit()
					else:
						# Just move
						grid[new_pos.y][new_pos.x] = current
						grid[y][x] = 0
	
	if moved and not dry_run:
		board_changed.emit()
	
	return merges if moved else Array()

## Find the final position a tile would land at when sliding
func _find_final_position(start: Vector2i, direction: Vector2i, merged: Array) -> Vector2i:
	var pos = start + direction
	
	while _is_valid_pos(pos):
		var tile_at_pos = grid[pos.y][pos.x]
		if tile_at_pos != 0:
			# Stop at the tile before this one
			return pos - direction
		pos += direction
	
	# Reached edge
	return pos - direction

## Slide tiles right
func slide_right() -> Array:
	return _slide_direction(Vector2i(1, 0), false)

## Slide tiles left
func slide_left() -> Array:
	return _slide_direction(Vector2i(-1, 0), false)

## Slide tiles down
func slide_down() -> Array:
	return _slide_direction(Vector2i(0, 1), false)

## Slide tiles up
func slide_up() -> Array:
	return _slide_direction(Vector2i(0, -1), false)

## Check if a slide in any direction is possible
func can_slide_any_direction() -> bool:
	return slide_left().size() > 0 or slide_right().size() > 0 or slide_up().size() > 0 or slide_down().size() > 0

# ==================== DRAG-DROP MERGE HANDLING ====================

## Handle merge between two items of the same tier
func merge(item1: MergeItem, item2: MergeItem) -> bool:
	if item1.tier != item2.tier:
		return false
	
	# Prevent merging max tier items
	if item1.tier >= 7:
		return false
	
	# Get positions
	var pos1 = item1.grid_position
	var pos2 = item2.grid_position
	
	# Update grid
	var new_tier = item1.tier + 1
	grid[pos1.y][pos1.x] = new_tier
	grid[pos2.y][pos2.x] = 0
	
	# Emit merge signal
	tile_merged.emit(pos1, new_tier, [pos1, pos2])
	board_changed.emit()
	
	return true

## Handle swap between two items of different tiers
func swap(item1: MergeItem, item2: MergeItem) -> bool:
	if item1.tier == item2.tier:
		return false
	
	# Get positions
	var pos1 = item1.grid_position
	var pos2 = item2.grid_position
	
	# Swap in grid
	var temp = grid[pos1.y][pos1.x]
	grid[pos1.y][pos1.x] = grid[pos2.y][pos2.x]
	grid[pos2.y][pos2.x] = temp
	
	board_changed.emit()
	return true

## Get grid position from world position
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / CELL_SIZE),
		int(world_pos.y / CELL_SIZE)
	)

## Get world position from grid position
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2,
		grid_pos.y * CELL_SIZE + CELL_SIZE / 2
	)
