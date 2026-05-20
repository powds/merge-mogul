extends Node

const SAVE_PATH := "user://save_data.json"

static func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % FileAccess.get_open_error())
		return false
	
	var json_string := JSON.stringify(data, "\t")
	file.store_line(json_string)
	file.close()
	return true

static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: %s" % FileAccess.get_open_error())
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse save JSON: %s" % json.get_error_message())
		return {}
	
	if json.data is Dictionary:
		return json.data
	return {}

static func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var err := DirAccess.remove_absolute(SAVE_PATH)
	if err != OK:
		push_error("Failed to delete save file: %s" % err)
		return false
	return true

static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
