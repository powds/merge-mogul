extends Control

func _ready() -> void:
	# Connect button signals
	var play_btn = find_child("PlayButton", true, false)
	var settings_btn = find_child("SettingsButton", true, false)
	var achievements_btn = find_child("AchievementsButton", true, false)
	var quit_btn = find_child("QuitButton", true, false)
	
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if achievements_btn:
		achievements_btn.pressed.connect(_on_achievements_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	if has_node("/root/GameState"):
		GameState.set_state(GameState.STATE_PLAYING)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_settings_pressed() -> void:
	# Open settings scene instead of inline panel
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")

func _on_achievements_pressed() -> void:
	# Open achievements scene
	get_tree().change_scene_to_file("res://scenes/menus/achievements.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()