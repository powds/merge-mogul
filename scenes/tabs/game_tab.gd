extends Control

# Game Tab - Main game view when Game tab is selected
# Contains board, items, UI

func _ready() -> void:
	pass

func _enter_tree() -> void:
	visible = true

func _exit_tree() -> void:
	visible = false