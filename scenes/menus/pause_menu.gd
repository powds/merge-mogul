extends Control

func _ready() -> void:
	var resume_btn = find_child("ResumeButton", true, false)
	var settings_btn = find_child("SettingsButton", true, false)
	var quit_btn = find_child("QuitButton", true, false)

	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.resume_game()
	hide()

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")

func _on_quit_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
