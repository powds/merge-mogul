extends CanvasLayer
## UI overlay for the game scene
## Handles HUD display, popups, and user input

signal restart_pressed()
signal menu_pressed()
signal pause_pressed()

# UI node references
@onready var top_hud: Panel = $TopHUD
@onready var score_value: Label = $TopHUD/HBoxContainer/ScorePanel/VBoxContainer/ScoreValue
@onready var moves_value: Label = $TopHUD/HBoxContainer/MovesPanel/VBoxContainer/MovesValue
@onready var level_value: Label = $TopHUD/HBoxContainer/LevelPanel/VBoxContainer/LevelValue
@onready var combo_popup: Label = $ComboPopup
@onready var game_over_overlay: Panel = $GameOverOverlay

var score: int = 0
var moves: int = 0
var level: int = 1

func _ready() -> void:
	# Connect button signals
	var pause_btn = $TopHUD/HBoxContainer/PauseButton
	var menu_btn = $TopHUD/HBoxContainer/MenuButton
	var restart_btn = $GameOverOverlay/VBoxContainer/RestartButton
	var main_menu_btn = $GameOverOverlay/VBoxContainer/MainMenuButton
	
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	
	_update_display()

func _on_pause_pressed() -> void:
	pause_pressed.emit()

func _on_menu_pressed() -> void:
	menu_pressed.emit()

func _on_restart_pressed() -> void:
	game_over_overlay.visible = false
	restart_pressed.emit()

func _on_main_menu_pressed() -> void:
	menu_pressed.emit()

func update_score(new_score: int) -> void:
	score = new_score
	_update_display()

func update_moves(new_moves: int) -> void:
	moves = new_moves
	_update_display()

func update_level(new_level: int) -> void:
	level = new_level
	_update_display()

func _update_display() -> void:
	if score_value:
		score_value.text = str(score)
	if moves_value:
		moves_value.text = str(moves)
	if level_value:
		level_value.text = str(level)

func show_combo(text: String = "COMBO!") -> void:
	if combo_popup:
		combo_popup.text = text
		combo_popup.visible = true
		
		# Create tween for popup animation
		var tween = create_tween()
		tween.tween_property(combo_popup, "position:y", combo_popup.position.y - 50, 0.5)
		tween.tween_interval(0.5)
		tween.tween_callback(_hide_combo)

func _hide_combo() -> void:
	if combo_popup:
		combo_popup.visible = false

func show_game_over() -> void:
	if game_over_overlay:
		var final_score_label = $GameOverOverlay/VBoxContainer/FinalScoreLabel
		if final_score_label:
			final_score_label.text = "Final Score: " + str(score)
		game_over_overlay.visible = true

func show_victory() -> void:
	if game_over_overlay:
		var label = $GameOverOverlay/VBoxContainer/GameOverLabel
		if label:
			label.text = "YOU WIN!"
		var final_score_label = $GameOverOverlay/VBoxContainer/FinalScoreLabel
		if final_score_label:
			final_score_label.text = "Final Score: " + str(score)
		game_over_overlay.visible = true