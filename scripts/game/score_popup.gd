extends Panel

@onready var value_label: Label = $ValueLabel

var _tween: Tween
var _amount: int = 0

func _ready() -> void:
	pass

func start(amount: int) -> void:
	_amount = amount
	value_label.text = "+%s" % amount
	
	var start_pos := global_position
	var mid_offset := Vector2(0, -60)
	var end_offset := Vector2(0, -120)
	
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "global_position", start_pos + mid_offset, 0.4)
	_tween.chain().tween_property(self, "global_position", start_pos + end_offset, 0.4)
	_tween.tween_property(self, "modulate", Color(modulate, 1), 0.5)
	_tween.chain().tween_property(self, "modulate", Color(modulate, 0), 0.3)
	_tween.tween_callback(queue_free)
