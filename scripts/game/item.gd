extends Node2D
class_name MergeItem

# Signals
signal dragged(item: MergeItem)
signal dropped(item: MergeItem, target: MergeItem)
signal clicked(item: MergeItem)
signal merged_with(other_item: MergeItem)

# Tier names: 0=Idea, 1=Prototype, 2=Startup, 3=Small Business, 4=Company, 5=Corporation, 6=Mega Corp, 7=Billionaire
const TIER_NAMES: Array[String] = [
	"Idea",
	"Prototype", 
	"Startup",
	"Small Business",
	"Company",
	"Corporation",
	"Mega Corp",
	"Billionaire"
]

const TIER_COLORS: Array[Color] = [
	Color("#89CFF0"),  # Baby Blue - Idea
	Color("#7B68EE"),  # Medium Slate Blue - Prototype
	Color("#00CED1"),  # Dark Turquoise - Startup
	Color("#32CD32"),  # Lime Green - Small Business
	Color("#FFD700"),  # Gold - Company
	Color("#FF6B35"),  # Orange Red - Corporation
	Color("#9B59B6"),  # Purple - Mega Corp
	Color("#FFD700")   # Gold with shimmer - Billionaire
]

const TIER_SHAPES: Array[int] = [
	0,  # Circle - Idea
	1,  # Triangle - Prototype
	2,  # Square - Startup
	3,  # Pentagon - Small Business
	4,  # Hexagon - Company
	5,  # Star - Corporation
	6,  # Octagon - Mega Corp
	7   # Diamond - Billionaire
]

# Export properties
@export var tier: int = 0:
	set(value):
		tier = clampi(value, 0, 7)
		queue_redraw()

@export var board_path: NodePath = "^../Board"

# State
var is_dragging: bool = false
var is_hovered: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var current_scale: Vector2 = Vector2.ONE

# Grid snapping properties
var snap_to_grid: bool = false
var grid_size: Vector2 = Vector2(64, 64)

# References
var board: Node = null

# Grid position tracking
var grid_position: Vector2i:
	get:
		if board and board.has_method("world_to_grid"):
			return board.world_to_grid(global_position)
		return Vector2i(-1, -1)

func _ready() -> void:
	original_position = global_position
	if not board_path.is_empty():
		board = get_node(board_path)
	else:
		board = get_parent()
	
	# Scale animation properties
	current_scale = Vector2.ONE

func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset
	
	# Subtle pulse animation when not dragging
	if not is_dragging and not is_hovered:
		var pulse = sin(Time.get_ticks_msec() / 500.0) * 0.03
		scale = current_scale * (1.0 + pulse)

func _draw() -> void:
	var tier_color = TIER_COLORS[tier]
	var shape_type = TIER_SHAPES[tier]
	var base_size = 28.0
	
	# Draw glow when hovered
	if is_hovered and not is_dragging:
		draw_circle(Vector2.ZERO, base_size + 8, Color(tier_color, 0.3))
	
	# Draw item background
	draw_shape(Vector2.ZERO, base_size, tier_color, shape_type, 1.0)
	
	# Draw tier number
	var font = ThemeDB.fallback_font
	var text = str(tier + 1)  # Display 1-8 instead of 0-7
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, -text_size / 2 + Vector2(0, 6), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func draw_shape(center: Vector2, size: float, color: Color, shape_type: int, alpha: float) -> void:
	match shape_type:
		0:  # Circle
			draw_circle(center, size, Color(color, alpha))
		1:  # Triangle
			var points = [
				center + Vector2(0, -size),
				center + Vector2(size * 0.866, size * 0.5),
				center + Vector2(-size * 0.866, size * 0.5)
			]
			draw_colored_polygon(points, Color(color, alpha))
		2:  # Square
			var rect = Rect2(center - Vector2(size, size), Vector2(size * 2, size * 2))
			draw_rect(rect, Color(color, alpha))
		3:  # Pentagon
			var points = []
			for i in range(5):
				var angle = -PI / 2 + i * TAU / 5
				points.append(center + Vector2(cos(angle), sin(angle)) * size)
			draw_colored_polygon(points, Color(color, alpha))
		4:  # Hexagon
			var points = []
			for i in range(6):
				var angle = i * TAU / 6
				points.append(center + Vector2(cos(angle), sin(angle)) * size)
			draw_colored_polygon(points, Color(color, alpha))
		5:  # Star
			var points = []
			for i in range(10):
				var angle = -PI / 2 + i * TAU / 10
				var r = size if i % 2 == 0 else size * 0.5
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, Color(color, alpha))
		6:  # Octagon
			var points = []
			for i in range(8):
				var angle = i * TAU / 8
				points.append(center + Vector2(cos(angle), sin(angle)) * size)
			draw_colored_polygon(points, Color(color, alpha))
		7:  # Diamond
			var points = [
				center + Vector2(0, -size),
				center + Vector2(size, 0),
				center + Vector2(0, size),
				center + Vector2(-size, 0)
			]
			draw_colored_polygon(points, Color(color, alpha))

func _on_hitbox_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag()
				clicked.emit(self)
			else:
				_end_drag()

func _on_hitbox_mouse_entered() -> void:
	is_hovered = true
	current_scale = Vector2.ONE * 1.1
	queue_redraw()

func _on_hitbox_mouse_exited() -> void:
	is_hovered = false
	current_scale = Vector2.ONE
	queue_redraw()

func _start_drag() -> void:
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	z_index = 100
	
	# Scale up when dragging
	current_scale = Vector2.ONE * 1.15

func _end_drag() -> void:
	if is_dragging:
		is_dragging = false
		z_index = 0
		current_scale = Vector2.ONE
		dragged.emit(self)
		
		var target = _find_target_item()
		if target:
			dropped.emit(self, target)
			
			if target.tier == tier:
				# Same tier - attempt merge
				if board and board.has_method("merge"):
					if board.merge(self, target):
						# Successful merge: this item moves to target's grid position
						var target_pos = target.grid_position
						target.queue_free()  # Remove merged target item
						global_position = board.grid_to_world(target_pos)
						_snap_to_grid_position()
			else:
				# Different tier - attempt swap
				if board and board.has_method("swap"):
					if board.swap(self, target):
						# Successful swap: both items snap to their new grid positions
						var my_grid_pos = self.grid_position
						var target_grid_pos = target.grid_position
						self.global_position = board.grid_to_world(target_grid_pos)
						target.global_position = board.grid_to_world(my_grid_pos)
						_snap_to_grid_position()
						target._snap_to_grid_position()
		else:
			# No target - just snap to grid at current position
			_snap_to_grid_position()

func _find_target_item() -> MergeItem:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	
	var results = space_state.intersect_point(query, 10)
	
	for result in results:
		var collider = result["collider"]
		if collider is Area2D:
			var parent = collider.get_parent()
			if parent is MergeItem and parent != self:
				return parent
	return null

func can_merge_with(other: MergeItem) -> bool:
	return other.tier == tier

func get_tier_name() -> String:
	return TIER_NAMES[tier]

func get_tier_color() -> Color:
	return TIER_COLORS[tier]

func _snap_to_grid_position() -> void:
	# Use board's grid_to_world if available, otherwise compute directly
	var grid_pos = grid_position
	if grid_pos.x >= 0 and grid_pos.y >= 0:
		if board and board.has_method("grid_to_world"):
			global_position = board.grid_to_world(grid_pos)
		else:
			global_position = Vector2(grid_pos.x * grid_size.x + grid_size.x / 2, grid_pos.y * grid_size.y + grid_size.y / 2)

func pulse_scale() -> void:
	"""Trigger a scale pulse animation"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

var _flash_tween: Tween = null
func flash_white() -> void:
	"""Flash white briefly on merge"""
	_flash_tween = create_tween()
	# Flash effect handled via modulate
	var original_modulate = Color.WHITE
	modulate = Color.WHITE
	_flash_tween.tween_property(self, "modulate", original_modulate, 0.2)
