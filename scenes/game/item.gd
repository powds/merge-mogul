extends Node2D
class_name MergeItem

signal dragged(item: MergeItem)
signal dropped(item: MergeItem, target: MergeItem)
signal clicked(item: MergeItem)

@export var item_type: int = 1
@export var merge_level: int = 1

var is_dragging: bool = false
var is_hovered: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	original_position = global_position

func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

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
	queue_redraw()

func _on_hitbox_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func _start_drag() -> void:
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	z_index = 100

func _end_drag() -> void:
	if is_dragging:
		is_dragging = false
		z_index = 0
		dragged.emit(self)
		
		var target = _find_merge_target()
		if target:
			dropped.emit(self, target)

func _find_merge_target() -> MergeItem:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	
	var results = space_state.intersect_point(query, 10)
	
	for result in results:
		var collider = result["collider"]
		if collider is Area2D:
			var parent = collider.get_parent()
			if parent is MergeItem and parent != self:
				if parent.item_type == item_type and parent.merge_level == merge_level:
					return parent
	return null

func can_merge_with(other: MergeItem) -> bool:
	return other.item_type == item_type and other.merge_level == merge_level

func _draw() -> void:
	if is_hovered and not is_dragging:
		draw_arc(Vector2.ZERO, 40, 0, TAU, 32, Color("#FFFFFF30"), 2.0)