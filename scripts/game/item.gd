extends Area2D
class_name Item

signal picked_up(item: Item)
signal dropped(item: Item, success: bool)

@export var draggable: bool = true
@export var snap_to_grid: bool = false
@export var grid_size: Vector2 = Vector2(32, 32)

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	input_event.connect(_on_input_event)


func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if not draggable:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag()
			else:
				_end_drag()


func _start_drag() -> void:
	is_dragging = true
	original_position = global_position
	drag_offset = get_global_mouse_position() - global_position
	
	if sprite:
		sprite.modulate.a = 0.7
	
	picked_up.emit(self)


func _end_drag() -> void:
	is_dragging = false
	
	if sprite:
		sprite.modulate.a = 1.0
	
	var target_pos: Vector2 = global_position
	
	if snap_to_grid:
		target_pos = _snap_to_grid(target_pos)
	
	var collision_success: bool = _check_collision_at(target_pos)
	
	if collision_success:
		global_position = target_pos
		dropped.emit(self, true)
	else:
		global_position = original_position
		dropped.emit(self, false)


func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / grid_size.x) * grid_size.x,
		round(pos.y / grid_size.y) * grid_size.y
	)


func _check_collision_at(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	
	var results = space_state.intersect_point(query, 1)
	
	for result in results:
		if result["collider"] != self:
			return false
	
	return true


func _on_area_entered(area: Area2D) -> void:
	if is_dragging and area is Item:
		return
	
func get_bounds() -> Rect2:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape = collision_shape.shape as RectangleShape2D
		return Rect2(global_position - shape.size / 2, shape.size)
	return Rect2(global_position, Vector2.ZERO)