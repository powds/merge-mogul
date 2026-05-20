extends Control

## Main entry point - manages game state transitions

func _ready() -> void:
	# Start with main menu
	show_main_menu()

func show_main_menu() -> void:
	var menu = preload("res://scenes/menus/main_menu.tscn").instantiate()
	add_child(menu)
	menu.play_pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	# Load and show game scene
	var game = preload("res://scenes/game/game.tscn").instantiate()
	add_child(game)
