extends Node
## Utility file browser with SAF (Storage Access Framework) support.
## Provides file operations: browse, read, cut/copy/paste/delete, create folders, file info.

signal files_updated(entries: Array)
signal operation_completed(success: bool, message: String)
signal current_path_changed(path: String)

enum ClipboardAction { NONE, CUT, COPY }

const SETTINGS_SAF_TREE_URI := "saf_tree_uri"
const SETTINGS_SAF_PERSISTED_URIS := "saf_persisted_uris"

var _current_uri: String = ""
var _current_path: String = "/"
var _clipboard: Dictionary = { "action": ClipboardAction.NONE, "source_uri": "", "entries": [] }
var _is_saf_mode: bool = false

## Get file info dictionary
static func get_file_info(path: String, uri: String = "") -> Dictionary:
	var info: Dictionary = {
		"name": "",
		"path": path,
		"uri": uri,
		"size": 0,
		"modified_time": 0.0,
		"is_directory": false,
		"extension": "",
		"exists": false
	}
	
	if uri != "" and _is_android():
		info["exists"] = _check_uri_exists(uri)
		if info["exists"]:
			info["name"] = _get_uri_display_name(uri)
			info["size"] = _get_uri_size(uri)
			info["modified_time"] = _get_uri_modified_time(uri)
			info["is_directory"] = _is_uri_directory(uri)
			info["extension"] = _get_extension(info["name"])
	elif path != "":
		var f = FileAccess.file_exists(path)
		info["exists"] = f
		if f:
			info["name"] = path.get_file()
			info["size"] = FileAccess.get_file_as_bytes(path).size()
			info["modified_time"] = FileAccess.get_modified_time(path)
			info["is_directory"] = DirAccess.dir_exists_absolute(path)
			info["extension"] = _get_extension(info["name"])
		else:
			info["is_directory"] = DirAccess.dir_exists_absolute(path)
			if info["is_directory"]:
				info["exists"] = true
				info["name"] = path.get_file()
				info["modified_time"] = FileAccess.get_modified_time(path)
	
	return info

## List entries in a directory
func list_directory(dir_path: String, dir_uri: String = "") -> Array:
	var entries: Array = []
	
	if dir_uri != "" and _is_saf_mode:
		entries = _list_saf_directory(dir_uri)
	elif _is_android() and is_android_saf_uri(dir_path):
		entries = _list_saf_directory(dir_path)
	else:
		entries = _list_local_directory(dir_path)
	
	files_updated.emit(entries)
	return entries

func _list_local_directory(dir_path: String) -> Array:
	var entries: Array = []
	var da: DirAccess = DirAccess.open(dir_path)
	
	if da == null:
		operation_completed.emit(false, "Cannot open directory: %s" % dir_path)
		return entries
	
	da.include_hidden = true
	da.include_accessories = false
	
	var dirs: Array = []
	var files: Array = []
	
	da.list_dir_begin()
	var file_name: String = da.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = da.get_next()
			continue
		
		var full_path: String = dir_path.path_join(file_name)
		var info: Dictionary = get_file_info(full_path)
		
		if info["is_directory"]:
			dirs.append(info)
		else:
			files.append(info)
		
		file_name = da.get_next()
	
	da.list_dir_end()
	
	dirs.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	files.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	
	entries.append_array(dirs)
	entries.append_array(files)
	return entries

func _list_saf_directory(dir_uri: String) -> Array:
	var entries: Array = []
	if not _is_android():
		return entries
	
	var document_file = _get_document_file_for_uri(dir_uri)
	if document_file == null:
		return entries
	
	var children = document_file.list_files()
	for child in children:
		var info: Dictionary = {
			"name": child.getName(),
			"path": "",
			"uri": child.getUri().to_string(),
			"size": child.length(),
			"modified_time": child.lastModified(),
			"is_directory": child.isDirectory(),
			"extension": _get_extension(child.getName()),
			"exists": true
		}
		entries.append(info)
	
	entries.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	return entries

## Navigate to a directory
func navigate_to(path: String, uri: String = "") -> bool:
	if uri != "" and _is_saf_mode:
		_current_uri = uri
		_current_path = path
	elif _is_android() and is_android_saf_uri(path):
		_current_uri = path
		_current_path = "/"
		_is_saf_mode = true
	else:
		if not DirAccess.dir_exists_absolute(path):
			operation_completed.emit(false, "Directory does not exist: %s" % path)
			return false
		_current_path = path
		_current_uri = ""
		_is_saf_mode = false
	
	current_path_changed.emit(get_current_display_path())
	list_directory(get_current_display_path(), _current_uri if _is_saf_mode else "")
	return true

## Navigate up one directory
func navigate_up() -> bool:
	if _is_saf_mode:
		return _navigate_up_saf()
	else:
		return _navigate_up_local()

func _navigate_up_local() -> bool:
	if _current_path == "/" or _current_path == "":
		return false
	var parent: String = _current_path.get_base_dir()
	if parent == "":
		parent = "/"
	return navigate_to(parent)

func _navigate_up_saf() -> bool:
	if not _is_android() or _current_uri == "":
		return navigate_up()
	var document_file = _get_document_file_for_uri(_current_uri)
	if document_file == null:
		return false
	var parent = document_file.getParentFile()
	if parent == null:
		return false
	_current_uri = parent.getUri().to_string()
	_current_path = "/"
	current_path_changed.emit(get_current_display_path())
	list_directory(_current_uri, _current_uri if _is_saf_mode else "")
	return true

## Get current display path
func get_current_display_path() -> String:
	if _is_saf_mode and _current_uri != "":
		return _get_uri_display_name(_current_uri)
	return _current_path

## Cut files
func cut(entries: Array) -> void:
	_clipboard = { "action": ClipboardAction.CUT, "source_uri": _current_uri, "entries": entries.duplicate(true) }
	operation_completed.emit(true, "Files ready to cut")

## Copy files
func copy(entries: Array) -> void:
	_clipboard = { "action": ClipboardAction.COPY, "source_uri": _current_uri, "entries": entries.duplicate(true) }
	operation_completed.emit(true, "Files ready to copy")

## Paste files
func paste() -> void:
	if _clipboard["action"] == ClipboardAction.NONE:
		operation_completed.emit(false, "Nothing to paste")
		return
	
	if _is_saf_mode:
		_paste_saf()
	else:
		_paste_local()

func _paste_local() -> void:
	if _clipboard["action"] == ClipboardAction.CUT:
		for entry in _clipboard["entries"]:
			var src: String = entry["path"]
			var dst: String = _current_path.path_join(src.get_file())
			if _move_file_local(src, dst):
				operation_completed.emit(true, "Files moved successfully")
			else:
				operation_completed.emit(false, "Failed to move: %s" % src)
	elif _clipboard["action"] == ClipboardAction.COPY:
		for entry in _clipboard["entries"]:
			var src: String = entry["path"]
			var dst: String = _current_path.path_join(src.get_file())
			if _copy_file_local(src, dst):
				operation_completed.emit(true, "Files copied successfully")
			else:
				operation_completed.emit(false, "Failed to copy: %s" % src)
	
	_clipboard = { "action": ClipboardAction.NONE, "source_uri": "", "entries": [] }
	list_directory(_current_path)

func _paste_saf() -> void:
	if not _is_android():
		operation_completed.emit(false, "SAF not supported on this platform")
		return
	
	for entry in _clipboard["entries"]:
		var src_uri: String = entry["uri"]
		var name: String = entry["name"]
		var dest_uri: String = _current_uri
		
		if _clipboard["action"] == ClipboardAction.COPY:
			if _copy_file_saf(src_uri, dest_uri, name):
				operation_completed.emit(true, "Files copied successfully")
			else:
				operation_completed.emit(false, "Failed to copy: %s" % name)
		elif _clipboard["action"] == ClipboardAction.CUT:
			if _move_file_saf(src_uri, dest_uri, name):
				operation_completed.emit(true, "Files moved successfully")
			else:
				operation_completed.emit(false, "Failed to move: %s" % name)
	
	_clipboard = { "action": ClipboardAction.NONE, "source_uri": "", "entries": [] }
	list_directory(_current_uri if _is_saf_mode else "", _current_uri if _is_saf_mode else "")

## Delete files
func delete(entries: Array) -> void:
	var success_count: int = 0
	var fail_count: int = 0
	
	for entry in entries:
		if _is_saf_mode:
			if _delete_file_saf(entry["uri"]):
				success_count += 1
			else:
				fail_count += 1
		else:
			if _delete_file_local(entry["path"]):
				success_count += 1
			else:
				fail_count += 1
	
	if fail_count == 0:
		operation_completed.emit(true, "Deleted %d files" % success_count)
	else:
		operation_completed.emit(false, "Deleted %d, failed %d" % [success_count, fail_count])
	
	list_directory(_current_path if not _is_saf_mode else "", _current_uri if _is_saf_mode else "")

## Create a new folder
func create_folder(name: String) -> bool:
	if name == "" or "/" in name or "\\" in name:
		operation_completed.emit(false, "Invalid folder name")
		return false
	
	if _is_saf_mode:
		var success = _create_folder_saf(_current_uri, name)
		if success:
			operation_completed.emit(true, "Folder created: %s" % name)
		else:
			operation_completed.emit(false, "Failed to create folder")
		list_directory(_current_uri, _current_uri if _is_saf_mode else "")
		return success
	else:
		var folder_path: String = _current_path.path_join(name)
		var da: DirAccess = DirAccess.open(_current_path)
		if da == null:
			operation_completed.emit(false, "Cannot access directory")
			return false
		
		if da.make_dir(name) == OK:
			operation_completed.emit(true, "Folder created: %s" % name)
			list_directory(_current_path)
			return true
		else:
			operation_completed.emit(false, "Failed to create folder: %s" % name)
			return false

## Read file contents as text
func read_file_text(path: String, uri: String = "") -> String:
	if uri != "" and _is_saf_mode:
		return _read_saf_file_text(uri)
	elif _is_android() and is_android_saf_uri(path):
		return _read_saf_file_text(path)
	elif FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			operation_completed.emit(false, "Cannot read file: %s" % path)
			return ""
		var content: String = f.get_as_text()
		f.close()
		return content
	else:
		operation_completed.emit(false, "File not found: %s" % path)
		return ""

## Read file contents as bytes
func read_file_bytes(path: String, uri: String = "") -> PackedByteArray:
	if uri != "" and _is_saf_mode:
		return _read_saf_file_bytes(uri)
	elif _is_android() and is_android_saf_uri(path):
		return _read_saf_file_bytes(path)
	elif FileAccess.file_exists(path):
		return FileAccess.get_file_as_bytes(path)
	else:
		operation_completed.emit(false, "File not found: %s" % path)
		return PackedByteArray()

## Rename file or folder
func rename(entry: Dictionary, new_name: String) -> bool:
	if new_name == "" or "/" in new_name or "\\" in new_name or ":" in new_name:
		operation_completed.emit(false, "Invalid name")
		return false
	
	if _is_saf_mode:
		var success = _rename_saf(entry["uri"], new_name)
		if success:
			operation_completed.emit(true, "Renamed to: %s" % new_name)
		else:
			operation_completed.emit(false, "Failed to rename")
		list_directory(_current_uri, _current_uri if _is_saf_mode else "")
		return success
	else:
		var old_path: String = entry["path"]
		var parent_dir: String = old_path.get_base_dir()
		var new_path: String = parent_dir.path_join(new_name)
		var da: DirAccess = DirAccess.open(parent_dir)
		if da == null:
			operation_completed.emit(false, "Cannot access directory")
			return false
		
		var err: Error = da.rename(old_path.get_file(), new_name)
		if err == OK:
			operation_completed.emit(true, "Renamed to: %s" % new_name)
			list_directory(_current_path)
			return true
		else:
			operation_completed.emit(false, "Failed to rename: %s" % err)
			return false

## Initialize SAF with a tree URI (call after user picks directory)
func init_saf(tree_uri: String) -> bool:
	if not _is_android():
		return false
	_current_uri = tree_uri
	_is_saf_mode = true
	_current_path = "/"
	current_path_changed.emit(get_current_display_path())
	_persist_saf_uri(tree_uri)
	return true

## Check if running on Android
static func _is_android() -> bool:
	return OS.get_name() == "Android"

## Check if path is an Android SAF URI
static func is_android_saf_uri(path: String) -> bool:
	return path.begins_with("content://")

## Get clipboard state
func has_clipboard() -> bool:
	return _clipboard["action"] != ClipboardAction.NONE

func get_clipboard_action() -> int:
	return _clipboard["action"]

func clear_clipboard() -> void:
	_clipboard = { "action": ClipboardAction.NONE, "source_uri": "", "entries": [] }

## --- Local file operations ---
func _move_file_local(src: String, dst: String) -> bool:
	var da: DirAccess = DirAccess.open(src.get_base_dir())
	if da == null:
		return false
	return da.rename(src.get_file(), dst) == OK

func _copy_file_local(src: String, dst: String) -> bool:
	var src_file: FileAccess = FileAccess.open(src, FileAccess.READ)
	if src_file == null:
		return false
	var dst_file: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	if dst_file == null:
		src_file.close()
		return false
	dst_file.store_buffer(src_file.get_buffer(src_file.get_length()))
	src_file.close()
	dst_file.close()
	return true

func _delete_file_local(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		var da: DirAccess = DirAccess.open(path)
		if da == null:
			return false
		return da.remove(path) == OK
	elif FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return false

## --- SAF operations (Android only) ---
func _get_document_file_for_uri(uri: String):
	if not _is_android():
		return null
	return Engine.get_singleton(" SAF ").getDocumentFile(uri)

func _check_uri_exists(uri: String) -> bool:
	if not _is_android():
		return false
	var doc = _get_document_file_for_uri(uri)
	return doc != null

func _get_uri_display_name(uri: String) -> String:
	if not _is_android():
		return uri
	var doc = _get_document_file_for_uri(uri)
	if doc != null:
		return doc.getName()
	return uri

func _get_uri_size(uri: String) -> int:
	if not _is_android():
		return 0
	var doc = _get_document_file_for_uri(uri)
	if doc != null:
		return doc.length()
	return 0

func _get_uri_modified_time(uri: String) -> float:
	if not _is_android():
		return 0.0
	var doc = _get_document_file_for_uri(uri)
	if doc != null:
		return doc.lastModified() / 1000.0
	return 0.0

func _is_uri_directory(uri: String) -> bool:
	if not _is_android():
		return false
	var doc = _get_document_file_for_uri(uri)
	if doc != null:
		return doc.isDirectory()
	return false

func _copy_file_saf(source_uri: String, dest_parent_uri: String, name: String) -> bool:
	if not _is_android():
		return false
	return Engine.get_singleton(" SAF ").copyFile(source_uri, dest_parent_uri, name)

func _move_file_saf(source_uri: String, dest_parent_uri: String, name: String) -> bool:
	if not _is_android():
		return false
	return Engine.get_singleton(" SAF ").moveFile(source_uri, dest_parent_uri, name)

func _delete_file_saf(uri: String) -> bool:
	if not _is_android():
		return false
	return Engine.get_singleton(" SAF ").deleteFile(uri)

func _create_folder_saf(parent_uri: String, name: String) -> bool:
	if not _is_android():
		return false
	return Engine.get_singleton(" SAF ").createDirectory(parent_uri, name)

func _rename_saf(uri: String, new_name: String) -> bool:
	if not _is_android():
		return false
	return Engine.get_singleton(" SAF ").renameFile(uri, new_name)

func _read_saf_file_text(uri: String) -> String:
	if not _is_android():
		return ""
	return Engine.get_singleton(" SAF ").readTextFile(uri)

func _read_saf_file_bytes(uri: String) -> PackedByteArray:
	if not _is_android():
		return PackedByteArray()
	return Engine.get_singleton(" SAF ").readBytesFile(uri)

func _persist_saf_uri(tree_uri: String) -> void:
	if not _is_android():
		return
	Engine.get_singleton(" SAF ").persistUri(tree_uri)

## --- Utility ---
static func _get_extension(file_name: String) -> String:
	var dot_pos: int = file_name.rfind(".")
	if dot_pos >= 0:
		return file_name.substr(dot_pos + 1).to_lower()
	return ""
