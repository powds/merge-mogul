extends CanvasLayer

signal watch_ad_requested
signal settings_requested
signal menu_requested

@onready var coin_value: Label = $TopHUD/HBoxContainer/ScorePanel/VBoxContainer/CoinValue
@onready var level_value: Label = $TopHUD/HBoxContainer/LevelPanel/VBoxContainer/LevelValue
@onready var moves_value: Label = $TopHUD/HBoxContainer/MovesPanel/VBoxContainer/MovesValue
@onready var xp_progress: ProgressBar = $TopHUD/HBoxContainer/XPPanel/VBoxContainer/XPProgressBar
@onready var combo_popup: Label = $ComboPopup
@onready var game_over_overlay: Panel = $GameOverOverlay
@onready var final_score_label: Label = $GameOverOverlay/VBoxContainer/FinalScoreLabel

var combo_timer: Timer

func _ready() -> void:
	combo_timer = Timer.new()
	combo_timer.wait_time = 1.5
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(combo_timer)

func update_coins(amount: int) -> void:
	coin_value.text = str(amount)

func update_level(level: int) -> void:
	level_value.text = str(level)

func update_moves(moves: int) -> void:
	moves_value.text = str(moves)

func update_xp(current: int, max_val: int) -> void:
	if max_val > 0:
		xp_progress.max_value = max_val
		xp_progress.value = current

func show_combo(multiplier: int) -> void:
	combo_popup.text = "COMBO x%s!" % multiplier
	combo_popup.visible = true
	combo_timer.start()

func _on_combo_timer_timeout() -> void:
	combo_popup.visible = false

func show_game_over(score: int) -> void:
	final_score_label.text = "Final Score: %s" % score
	game_over_overlay.visible = true

func show_victory() -> void:
	game_over_overlay.visible = true
	final_score_label.text = "Victory!"

func _on_pause_pressed() -> void:
	get_tree().paused = true

func _on_watch_ad_pressed() -> void:
	AdManager.show_rewarded()
	GameManager.add_coins(50)

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")