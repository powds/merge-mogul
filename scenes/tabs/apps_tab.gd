extends Control

# Apps Tab - Contains app launcher

func _ready() -> void:
	pass

func _enter_tree() -> void:
	visible = true

func _exit_tree() -> void:
	visible = false