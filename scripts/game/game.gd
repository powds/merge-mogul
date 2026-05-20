extends Node2D
## Main game scene that ties together board, items, and UI
## Manages game flow, drag-drop interactions, and coordinates all subsystems

# References to child nodes
@onready var board: Node = $Board
@onready var ui: CanvasLayer = $UI

# Particle system for merge effects
@onready var merge_particles: CPUParticles2D = $MergeParticles

# Game state
var move_count: int = 0
var is_game_active: bool = false

# Screen shake
var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
const SHAKE_DECAY: float = 0.9

# Item management
var item_scene: PackedScene = preload("res://scenes/game/item.tscn")
var items: Array[Node] = []

# Board config (must match board.gd GRID_SIZE)
const GRID_DIMENSION: int = 5
const CELL_SIZE: int = 64
const GRID_OFFSET: Vector2 = Vector2(128, 100)  # Matches Board node position in game.tscn

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

func _process(delta: float) -> void:
	# Update screen shake
	if shake_timer > 0:
		shake_timer -= delta
		var current_shake = shake_amount * (shake_timer / shake_duration)
		shake_offset = Vector2(
			randf() * current_shake * 2 - current_shake,
			randf() * current_shake * 2 - current_shake
		)
		if shake_timer <= 0:
			shake_offset = Vector2.ZERO
			shake_amount = 0.0

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
	if GameManager.current_state != GameManager.GameState.MENU:
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

func _spawn_item_at(grid_pos: Vector2i, value: int = 2) -> void:
	var world_pos = _grid_to_world(grid_pos)
	var item = item_scene.instantiate()
	item.position = world_pos
	item.snap_to_grid = true
	item.grid_size = Vector2(CELL_SIZE, CELL_SIZE)
	
	# Set tier based on value (2=0, 4=1, 8=2, etc.)
	item.tier = _value_to_tier(value)
	
	# Connect to item signals (dragged and dropped from MergeItem)
	item.dragged.connect(_on_item_dragged)
	item.dropped.connect(_on_item_dropped)
	
	add_child(item)
	items.append(item)
	
	if board.has_method("set_tile"):
		board.set_tile(grid_pos, value)

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

func _snap_item_to_grid(item: Node) -> void:
	var grid_pos = _world_to_grid(item.position)
	item.position = _grid_to_world(grid_pos)

func _smoothSnap(item: Node) -> void:
	"""Smooth snap animation for item to its grid position"""
	var target_pos = _grid_to_world(_world_to_grid(item.position))
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(item, "position", target_pos, 0.15)

func queue_free_item(item: Node) -> void:
	items.erase(item)
	item.queue_free()

func _award_merge_coins(tier: int) -> void:
	if MERGE_COIN_REWARDS.has(tier):
		var reward = MERGE_COIN_REWARDS[tier]
		GameManager.add_coins(reward)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int((world_pos.x - GRID_OFFSET.x) / CELL_SIZE),
		int((world_pos.y - GRID_OFFSET.y) / CELL_SIZE)
	)

func _spawn_merge_effect(world_pos: Vector2, tier: int) -> void:
	"""Spawn particle effect at merge location"""
	if not merge_particles:
		return
	
	# Configure particles based on tier
	var color = _get_tier_color(tier)
	merge_particles.modulate = color
	merge_particles.position = world_pos
	merge_particles.restart()

func _get_tier_color(tier: int) -> Color:
	"""Get color for tier (matches MergeItem.TIER_COLORS)"""
	var colors = [
		Color("#89CFF0"),  # 0 - Baby Blue
		Color("#7B68EE"),  # 1 - Medium Slate Blue
		Color("#00CED1"),  # 2 - Dark Turquoise
		Color("#32CD32"),  # 3 - Lime Green
		Color("#FFD700"),  # 4 - Gold
		Color("#FF6B35"),  # 5 - Orange Red
		Color("#9B59B6"),  # 6 - Purple
		Color("#FFD700")   # 7 - Gold
	]
	return colors[clampi(tier, 0, 7)]

func _trigger_screen_shake(intensity: float, duration: float) -> void:
	"""Trigger screen shake effect"""
	shake_amount = intensity
	shake_duration = duration
	shake_timer = duration

func _animate_level_up(item: Node) -> void:
	"""Animate item scale pulse on level up"""
	if not item.has_method("pulse_scale"):
		return
	
	# Create tween for scale animation
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(item, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Also flash white
	if item.has_method("flash_white"):
		item.flash_white()

func _on_item_dragged(item: Node) -> void:
	item.z_index = 100

func _on_item_dropped(item: Node, target: Node) -> void:
	item.z_index = 0
	
	# Get tier before potential merge/swap
	var item_tier = item.tier
	var target_tier = target.tier
	
	if item_tier == target_tier:
		# Same tier - attempt merge
		if board.has_method("merge") and board.merge(item, target):
			# Merge succeeded - update the surviving item's tier and remove consumed item
			# Note: board.merge() updates the grid and emits tile_merged signal
			# We update tier here since it's a visual property on the item
			var new_tier = item_tier + 1  # Tier increases by 1
			item.tier = new_tier
			
			# Get world position for effects (before snapping)
			var effect_pos = item.position
			
			_snap_item_to_grid(item)
			queue_free_item(target)
			
			# Trigger effects for merge
			_spawn_merge_effect(effect_pos, new_tier)
			_animate_level_up(item)
			
			# Screen shake for tier 4+ (big merges)
			if new_tier >= 4:
				_trigger_screen_shake(8.0, 0.3)
			elif new_tier >= 3:
				_trigger_screen_shake(4.0, 0.2)
			
			# Coins are awarded via _on_tile_merged signal handler
	else:
		# Different tier - swap positions
		if board.has_method("swap") and board.swap(item, target):
			# Smooth animation for swap
			_smoothSnap(item)
			_smoothSnap(target)
	
	# Update move count after merge/swap
	move_count += 1
	_update_ui()
	_check_game_over()

func _on_tile_spawned(pos: Vector2i, value: int) -> void:
	_spawn_item_at(pos, value)
	_check_game_over()

func _on_tile_merged(pos: Vector2i, value: int, merged_from: Array) -> void:
	# Award coins based on merged tier
	var tier = _value_to_tier(value)
	if MERGE_COIN_REWARDS.has(tier):
		var reward = MERGE_COIN_REWARDS[tier]
		GameManager.add_coins(reward)
	_update_ui()

func _value_to_tier(value: int) -> int:
	# Convert 2048-style value to tier (2=0, 4=1, 8=2, 16=3, etc.)
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
	# Show interstitial ad on game over
	AdManager.load_interstitial()

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
		ui.update_level(GameManager.level)
	
	if ui.has_method("update_coins"):
		ui.update_coins(GameManager.coins)

func restore_game_state() -> void:
	pass

func save_current_state() -> Dictionary:
	return {
		"move_count": move_count,
		"items": items.size()
	}