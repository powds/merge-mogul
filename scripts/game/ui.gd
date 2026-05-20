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
@onready var score_popup_container: Node2D = $ScorePopupContainer
@onready var level_up_label: Label = $LevelUpLabel

var combo_timer: Timer
var _coin_display: int = 0
var _coin_target: int = 0
var _coin_tween: Tween
var _combo_scale_base: Vector2

func _ready() -> void:
	combo_timer = Timer.new()
	combo_timer.wait_time = 1.5
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(combo_timer)
	
	_combo_scale_base = combo_popup.scale
	combo_popup.scale = Vector2.ZERO
	
	# Connect to GameManager signals for live updates
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up.connect(_on_level_up)
	
	# Connect to AdManager signals
	AdManager.ad_loaded.connect(_on_ad_loaded)

func update_coins(amount: int) -> void:
	if _coin_tween and _coin_tween.is_valid():
		_coin_tween.kill()
	_coin_target = amount
	_coin_tween = create_tween()
	_coin_tween.set_ease(Tween.EASE_OUT)
	_coin_tween.set_trans(Tween.TRANS_QUAD)
	_coin_tween.tween_method(_tween_coin_update, _coin_display, amount, 0.5)
	_coin_tween.tween_callback(_on_coin_tween_complete)
	_coin_display = amount

func _tween_coin_update(value: float) -> void:
	_coin_display = int(value)
	coin_value.text = str(_coin_display)

func _on_coin_tween_complete() -> void:
	coin_value.text = str(_coin_target)

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
	combo_popup.scale = Vector2.ZERO
	combo_timer.start()
	
	var combo_tween := create_tween()
	combo_tween.set_ease(Tween.EASE_OUT)
	combo_tween.set_trans(Tween.TRANS_BACK)
	combo_tween.tween_property(combo_popup, "scale", _combo_scale_base * 1.2, 0.15)
	combo_tween.tween_property(combo_popup, "scale", _combo_scale_base, 0.1)

func hide_combo() -> void:
	var combo_tween := create_tween()
	combo_tween.set_ease(Tween.EASE_IN)
	combo_tween.set_trans(Tween.TRANS_QUAD)
	combo_tween.tween_property(combo_popup, "scale", Vector2.ZERO, 0.2)
	combo_tween.tween_callback(func(): combo_popup.visible = false)

func _on_combo_timer_timeout() -> void:
	hide_combo()

func show_score_popup(amount: int, world_position: Vector2) -> void:
	var popup := preload("res://scenes/game/score_popup.tscn").instantiate()
	score_popup_container.add_child(popup)
	popup.global_position = world_position
	popup.start(amount)

func show_level_up(new_level: int) -> void:
	level_up_label.text = "LEVEL %s!" % new_level
	level_up_label.visible = true
	level_up_label.modulate = Color(level_up_label.modulate, 0)
	level_up_label.scale = Vector2(0.5, 0.5)
	
	var level_up_tween := create_tween()
	level_up_tween.set_parallel(true)
	level_up_tween.set_ease(Tween.EASE_OUT)
	level_up_tween.set_trans(Tween.TRANS_BACK)
	level_up_tween.tween_property(level_up_label, "modulate", Color(level_up_label.modulate, 1), 0.3)
	level_up_tween.tween_property(level_up_label, "scale", Vector2(1.2, 1.2), 0.3)
	level_up_tween.chain().tween_property(level_up_label, "scale", Vector2(1.0, 1.0), 0.1)
	level_up_tween.chain().tween_property(level_up_label, "modulate", Color(level_up_label.modulate, 1), 0.8)
	level_up_tween.chain().tween_property(level_up_label, "modulate", Color(level_up_label.modulate, 0), 0.5)
	level_up_tween.tween_callback(func(): level_up_label.visible = false)

func _on_coins_changed(amount: int) -> void:
	update_coins(amount)

func _on_xp_changed(current: int, max_xp: int) -> void:
	update_xp(current, max_xp)

func _on_level_up(new_level: int) -> void:
	update_level(new_level)
	show_level_up(new_level)

func show_game_over(score: int) -> void:
	final_score_label.text = "Final Score: %s" % score
	game_over_overlay.visible = true

func show_victory() -> void:
	game_over_overlay.visible = true
	final_score_label.text = "Victory!"

func _on_pause_pressed() -> void:
	get_tree().paused = true

func _on_watch_ad_pressed() -> void:
	# Load and show rewarded ad for bonus coins
	AdManager.load_rewarded()

func _on_ad_loaded(type: int) -> void:
	if type == AdManager.AdType.REWARDED:
		AdManager.show_rewarded()

func _on_ad_rewarded(type: int, amount: int) -> void:
	if type == AdManager.AdType.REWARDED:
		GameManager.add_coins(amount)
	_show_ad_coins_gained(amount)

func _show_ad_coins_gained(amount: int) -> void:
	# Show feedback that coins were earned
	var label = Label.new()
	label.text = "+%d Coins!" % amount
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-50, -20)
	add_child(label)
	
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	await tween.finished
	label.queue_free()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")