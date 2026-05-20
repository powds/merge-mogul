extends Control

@onready var settings_panel = $SettingsPanel
@onready var achievements_panel = $AchievementsPanel

func _ready():
	var play_btn = $VBoxContainer/PlayButton
	var settings_btn = $VBoxContainer/SettingsButton
	var achievements_btn = $VBoxContainer/AchievementsButton
	var quit_btn = $VBoxContainer/QuitButton
	
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	achievements_btn.pressed.connect(_on_achievements_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	if has_node("/root/GameState"):
		GameState.set_state(GameState.PLAYING)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_settings_pressed():
	if settings_panel:
		settings_panel.visible = true

func _on_achievements_pressed():
	if achievements_panel:
		achievements_panel.visible = true

func _on_quit_pressed():
	get_tree().quit()
