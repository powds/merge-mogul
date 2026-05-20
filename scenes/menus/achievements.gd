extends Control

## Achievement definitions
const ACHIEVEMENT_DEFS := {
	"first_merge": {"name": "First Merge", "desc": "Merge two items for the first time", "icon": "⭐"},
	"merge_10": {"name": "Apprentice Merger", "desc": "Perform 10 merges", "icon": "🌱"},
	"merge_50": {"name": "Skilled Combinist", "desc": "Perform 50 merges", "icon": "🌿"},
	"merge_100": {"name": "Master Merger", "desc": "Perform 100 merges", "icon": "🌳"},
	"merge_500": {"name": "Merge Mogul", "desc": "Perform 500 merges", "icon": "👑"},
	"reach_level_5": {"name": "Getting Started", "desc": "Reach level 5", "icon": "🔟"},
	"reach_level_10": {"name": "Rising Star", "desc": "Reach level 10", "icon": "⭐⭐"},
	"reach_level_20": {"name": "Expert Player", "desc": "Reach level 20", "icon": "🌟"},
	"reach_level_30": {"name": "Master Player", "desc": "Reach level 30", "icon": "💫"},
	"score_1000": {"name": "Point Collector", "desc": "Reach 1,000 points in a game", "icon": "💯"},
	"score_5000": {"name": "High Scorer", "desc": "Reach 5,000 points in a game", "icon": "🎯"},
	"score_10000": {"name": "Top Scorer", "desc": "Reach 10,000 points in a game", "icon": "🏆"},
	"play_5_games": {"name": "Regular Player", "desc": "Play 5 games", "icon": "🎮"},
	"play_25_games": {"name": "Dedicated Player", "desc": "Play 25 games", "icon": "🕹️"},
	"play_100_games": {"name": "True Gamer", "desc": "Play 100 games", "icon": "🎲"},
	"no_undo_10": {"name": "Confident Player", "desc": "Win 10 games without using undo", "icon": "💪"},
	"speed_merge": {"name": "Speed Demon", "desc": "Merge items 5 times within 10 seconds", "icon": "⚡"},
	"max_level_item": {"name": "Perfectionist", "desc": "Create a max-level item", "icon": "✨"},
	"combo_5": {"name": "Combo Master", "desc": "Create a 5-item combo", "icon": "🔥"},
	"earn_coins_100": {"name": "Coin Collector", "desc": "Earn 100 coins total", "icon": "🪙"},
	"earn_coins_1000": {"name": "Wealthy", "desc": "Earn 1,000 coins total", "icon": "💰"},
}

var unlocked_achievements: Array = []
var achievement_stats: Dictionary = {
	"merges": 0,
	"level": 0,
	"high_score": 0,
	"games_played": 0,
	"games_no_undo": 0,
	"speed_merges": 0,
	"max_item_level": 0,
	"max_combo": 0,
	"total_coins": 0,
}

## Emitted when an achievement is unlocked
signal achievement_unlocked(achievement_id: String)
## Emitted when any stat changes
signal stats_updated

func _ready() -> void:
	_load_progress()
	_update_display()
	
	# Connect back button
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

func _load_progress() -> void:
	var save_data := SaveSystem.load_game()
	if save_data.has("achievements"):
		unlocked_achievements = save_data["achievements"]
	if save_data.has("achievement_stats"):
		achievement_stats = save_data["achievement_stats"]

func _save_progress() -> void:
	var save_data := SaveSystem.load_game()
	save_data["achievements"] = unlocked_achievements
	save_data["achievement_stats"] = achievement_stats
	SaveSystem.save_game(save_data)

func _update_display() -> void:
	var list_container = find_child("AchievementList", true, false)
	var progress_label = find_child("ProgressLabel", true, false)
	
	if list_container == null or progress_label == null:
		return
	
	# Clear existing items (keep first child if it's a placeholder)
	for child in list_container.get_children():
		child.queue_free()
	
	# Create achievement items
	var total := ACHIEVEMENT_DEFS.size()
	var completed := 0
	
	for ach_id in ACHIEVEMENT_DEFS:
		var is_unlocked := ach_id in unlocked_achievements
		if is_unlocked:
			completed += 1
		
		var item := _create_achievement_item(ach_id, is_unlocked)
		list_container.add_child(item)
	
	progress_label.text = "%d / %d Completed" % [completed, total]

func _create_achievement_item(ach_id: String, is_unlocked: bool) -> HBoxContainer:
	var def := ACHIEVEMENT_DEFS[ach_id]
	
	var container := HBoxContainer.new()
	container.set("theme_override_constants/separation", 10)
	
	# Icon
	var icon_label := Label.new()
	icon_label.text = def["icon"]
	icon_label.custom_minimum_size = Vector2(40, 40)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	if not is_unlocked:
		icon_label.modulate = Color(0.3, 0.3, 0.3, 0.5)
	container.add_child(icon_label)
	
	# Info container
	var info_vbox := VBoxContainer.new()
	
	var name_label := Label.new()
	name_label.text = def["name"]
	name_label.add_theme_font_size_override("font_size", 16)
	if not is_unlocked:
		name_label.modulate = Color(0.5, 0.5, 0.5)
	info_vbox.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = def["desc"]
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	desc_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(desc_label)
	
	container.add_child(info_vbox)
	
	# Status
	var status_label := Label.new()
	if is_unlocked:
		status_label.text = "✓"
		status_label.modulate = Color(0.3, 1, 0.3)
	else:
		status_label.text = "🔒"
		status_label.modulate = Color(0.5, 0.5, 0.5)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(status_label)
	
	return container

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

## Check and unlock achievements based on current stats
func check_achievements() -> void:
	for ach_id in ACHIEVEMENT_DEFS:
		if ach_id in unlocked_achievements:
			continue
		
		if _is_achievement_unlocked(ach_id):
			_unlock_achievement(ach_id)

func _is_achievement_unlocked(ach_id: String) -> bool:
	match ach_id:
		"first_merge":
			return achievement_stats["merges"] >= 1
		"merge_10":
			return achievement_stats["merges"] >= 10
		"merge_50":
			return achievement_stats["merges"] >= 50
		"merge_100":
			return achievement_stats["merges"] >= 100
		"merge_500":
			return achievement_stats["merges"] >= 500
		"reach_level_5":
			return achievement_stats["level"] >= 5
		"reach_level_10":
			return achievement_stats["level"] >= 10
		"reach_level_20":
			return achievement_stats["level"] >= 20
		"reach_level_30":
			return achievement_stats["level"] >= 30
		"score_1000":
			return achievement_stats["high_score"] >= 1000
		"score_5000":
			return achievement_stats["high_score"] >= 5000
		"score_10000":
			return achievement_stats["high_score"] >= 10000
		"play_5_games":
			return achievement_stats["games_played"] >= 5
		"play_25_games":
			return achievement_stats["games_played"] >= 25
		"play_100_games":
			return achievement_stats["games_played"] >= 100
		"no_undo_10":
			return achievement_stats["games_no_undo"] >= 10
		"speed_merge":
			return achievement_stats["speed_merges"] >= 5
		"max_level_item":
			return achievement_stats["max_item_level"] >= 10
		"combo_5":
			return achievement_stats["max_combo"] >= 5
		"earn_coins_100":
			return achievement_stats["total_coins"] >= 100
		"earn_coins_1000":
			return achievement_stats["total_coins"] >= 1000
	return false

func _unlock_achievement(ach_id: String) -> void:
	if ach_id in unlocked_achievements:
		return
	
	unlocked_achievements.append(ach_id)
	_save_progress()
	_update_display()
	achievement_unlocked.emit(ach_id)
	
	# Show notification
	_show_unlock_notification(ach_id)

func _show_unlock_notification(ach_id: String) -> void:
	var def := ACHIEVEMENT_DEFS[ach_id]
	print("🏆 Achievement Unlocked: %s - %s" % [def["name"], def["desc"]])

## Called by game logic to update stats
func record_merge() -> void:
	achievement_stats["merges"] += 1
	stats_updated.emit()
	check_achievements()

func record_level(level: int) -> void:
	if level > achievement_stats["level"]:
		achievement_stats["level"] = level
	stats_updated.emit()
	check_achievements()

func record_score(score: int) -> void:
	if score > achievement_stats["high_score"]:
		achievement_stats["high_score"] = score
	stats_updated.emit()
	check_achievements()

func record_game_end(used_undo: bool = false) -> void:
	achievement_stats["games_played"] += 1
	if not used_undo:
		achievement_stats["games_no_undo"] += 1
	stats_updated.emit()
	check_achievements()

func record_speed_merge() -> void:
	achievement_stats["speed_merges"] += 1
	stats_updated.emit()
	check_achievements()

func record_max_item_level(level: int) -> void:
	if level > achievement_stats["max_item_level"]:
		achievement_stats["max_item_level"] = level
	stats_updated.emit()
	check_achievements()

func record_combo(size: int) -> void:
	if size > achievement_stats["max_combo"]:
		achievement_stats["max_combo"] = size
	stats_updated.emit()
	check_achievements()

func record_coins(amount: int) -> void:
	achievement_stats["total_coins"] += amount
	stats_updated.emit()
	check_achievements()