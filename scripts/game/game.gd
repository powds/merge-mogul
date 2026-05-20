extends Node2D
## Main game scene that ties together board, items, and UI
## Manages game flow, drag-drop interactions, and coordinates all subsystems

# References to child nodes
@onready var board: Node = $Board
@onready var ui: CanvasLayer = $UI

# Game state
var move_count: int = 0
var is_game_active: bool = false

# Item management
var item_scene: PackedScene = preload("res://scenes/game/item.tscn")
var items: Array[Node] = []

# Board config
const GRID_DIMENSION: int = 5
const CELL_SIZE: int = 64
const GRID_OFFSET: Vector2 = Vector2(0, 0)

# Merge rewards config
const MERGE_COIN_REWARDS: Dictionary = {
	2: 1,    # 2+2=4
	3: 3,    # 4+4=8
	4: 10,   # 8+8=16
	5: 25,   # 16+16=32
	6: 50,   # 32+32=64
	7: 100,  # 64+64=128
}

func _ready() -> void:
	_setup_board()
	_connect_signals()
	_load_or_start_game()

func _setup_board() -> void:
	if board.has_method("setup_new_game"):
		board.setup_new_game()
	elif board.has_method("clear_board"):
		board.clear_board()

func _connect_signals() -> void:
	if board.has_signal("tile_spawned"):
		board.tile_spawned.connect(_on_tile_spawned)
	if board.has_signal("tile_merged"):
		board.tile_merged.connect(_on_tile_merged)
	if board.has_signal("board_changed"):
		board.board_changed.connect(_on_board_changed)
	if board.has_signal("game_won"):
		board.game_won.connect(_on_game_won)
	if board.has_signal("no_moves_available"):
		board.no_moves_available.connect(_on_no_moves)

	if ui.has_signal("restart_pressed"):
		ui.restart_pressed.connect(_on_restart)
	if ui.has_signal("menu_pressed"):
		ui.menu_pressed.connect(_on_menu)
	if ui.has_signal("pause_pressed"):
		ui.pause_pressed.connect(_on_pause)
	if ui.has_signal("watch_ad_requested"):
		ui.watch_ad_requested.connect(_on_watch_ad)

func _load_or_start_game() -> void:
	if GameManager.current_state != GameManager.GameState.IDLE:
		restore_game_state()
	else:
		_start_new_game()

func _start_new_game() -> void:
	move_count = 0
	is_game_active = true
	_clear_items()
	
	if board.has_method("setup_new_game"):
		board.setup_new_game()
	else:
		# Spawn 3-5 initial items
		var initial_count = randi() % 3 + 3  # 3 to 5
		_spawn_initial_items(initial_count)
	
	GameManager.start_game()
	_update_ui()

func _spawn_initial_items(count: int) -> void:
	for i in range(count):
		var empty_pos = _get_random_empty_cell()
		if empty_pos != Vector2i(-1, -1):
			_spawn_item_at(empty_pos)

func _spawn_item_at(grid_pos: Vector2i) -> void:
	var world_pos = _grid_to_world(grid_pos)
	var item = item_scene.instantiate()
	item.position = world_pos
	item.snap_to_grid = true
	item.grid_size = Vector2(CELL_SIZE, CELL_SIZE)
	
	# Connect to item signals (dragged and dropped from MergeItem)
	item.dragged.connect(_on_item_dragged)
	item.dropped.connect(_on_item_dropped)
	
	add_child(item)
	items.append(item)
	
	if board.has_method("set_tile"):
		board.set_tile(grid_pos, 2)

func _clear_items() -> void:
	for item in items:
		if is_instance_valid(item):
			item.queue_free()
	items.clear()

func _get_random_empty_cell() -> Vector2i:
	if not board.has_method("get_empty_positions"):
		return Vector2i(-1, -1)
	
	var empty_cells = board.get_empty_positions()
	if empty_cells.is_empty():
		return Vector2i(-1, -1)
	
	return empty_cells[randi() % empty_cells.size()]

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		GRID_OFFSET.x + grid_pos.x * CELL_SIZE + CELL_SIZE / 2,
		GRID_OFFSET.y + grid_pos.y * CELL_SIZE + CELL_SIZE / 2
	)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int((world_pos.x - GRID_OFFSET.x) / CELL_SIZE),
		int((world_pos.y - GRID_OFFSET.y) / CELL_SIZE)
	)

func _on_item_dragged(item: Node) -> void:
	item.z_index = 100

func _on_item_dropped(item: Node, target: Node) -> void:
	item.z_index = 0
	# Note: MergeItem internally calls board.merge() or board.swap() in _end_drag()
	# This callback is for additional game-level handling if needed
	
	# Update move count after merge/swap
	move_count += 1
	_update_ui()
	_check_game_over()

func _on_tile_spawned(pos: Vector2i, value: int) -> void:
	_spawn_item_at(pos)
	_check_game_over()

func _on_tile_merged(pos: Vector2i, value: int, merged_from: Array) -> void:
	# Award coins based on merged tier
	var tier = _value_to_tier(value)
	if MERGE_COIN_REWARDS.has(tier):
		var reward = MERGE_COIN_REWARDS[tier]
		GameManager.add_coins(reward)
	_update_ui()

func _value_to_tier(value: int) -> int:
	# Convert 2048-style value to tier (2=1, 4=2, 8=3, 16=4, etc.)
	var tier = 0
	var v = value
	while v > 1:
		v /= 2
		tier += 1
	return tier

func _on_board_changed() -> void:
	_update_ui()

func _on_game_won() -> void:
	is_game_active = false
	if ui.has_method("show_victory"):
		ui.show_victory()
	GameManager.victory()

func _on_no_moves() -> void:
	_handle_game_over()

func _check_game_over() -> void:
	if not board.has_method("is_full"):
		return
	if board.is_full() and not board.has_possible_merges():
		_handle_game_over()

func _handle_game_over() -> void:
	is_game_active = false
	if ui.has_method("show_game_over"):
		ui.show_game_over(board.score if board.has_method("score") else 0)
	GameManager.game_over()

func _on_watch_ad() -> void:
	# Award +50 coins via AdManager
	GameManager.add_coins(50)

func _on_restart() -> void:
	_clear_items()
	_start_new_game()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_pause() -> void:
	if is_game_active:
		GameManager.pause_game()
		get_tree().paused = true
	else:
		GameManager.resume_game()
		get_tree().paused = false

func _update_ui() -> void:
	if ui.has_method("update_score"):
		var score = 0
		if board.has_method("score"):
			score = board.score
		ui.update_score(score)
	
	if ui.has_method("update_moves"):
		ui.update_moves(move_count)
	
	if ui.has_method("update_level"):
		ui.update_level(GameManager.current_level)
	
	if ui.has_method("update_coins"):
		ui.update_coins(GameManager.coins)

func restore_game_state() -> void:
	pass

func save_current_state() -> Dictionary:
	return {
		"move_count": move_count,
		"items": items.size()
	}