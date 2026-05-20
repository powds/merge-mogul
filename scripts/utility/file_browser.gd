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
func get_file_info(path: String, uri: String = "") -> Dictionary:
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

## Browse for a directory (SAF tree picker entry point)
func browse_directory() -> bool:
	if _is_android():
		# Trigger Android SAF directory picker
		# The actual picker would be triggered via Java callback
		# For now, emit signal to request directory selection UI
		current_path_changed.emit("SAF picker requested")
		return true
	else:
		# On desktop, just navigate to user home
		return navigate_to(OS.get_data_dir())

## List entries in a directory
func list_directory(dir_path: String, dir_uri: String = "") -> Array:
	var entries: Array = []
	
	# Determine if we're in SAF mode based on URI presence or path type
	var use_saf = _is_saf_mode
	if dir_uri != "":
		use_saf = true
	elif _is_android() and is_android_saf_uri(dir_path):
		use_saf = true
	
	if use_saf:
		var target_uri = dir_uri if dir_uri != "" else (_current_uri if _is_saf_mode else "")
		if target_uri != "":
			entries = _list_saf_directory(target_uri)
		else:
			# Fall back to local
			entries = _list_local_directory(dir_path)
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
	# Use JNI bridge to get DocumentFile via ContentResolver
	var jni_env = _get_jni_environment()
	if not jni_env:
		return null
	# Call Java method to get DocumentFile from tree URI
	var SAF_class = jni_env.find_class("com.godot SAF ".replace(" ", ""))
	# Actually use JavaSingletonBridge for proper JNI access
	return _get_document_file_via_jni(uri)

func _get_jni_environment():
	# Use the same JNI approach as app_launcher and gallery
	if Engine.has_singleton("JavaSingletonBridge"):
		return Engine.get_singleton("JavaSingletonBridge").get_jni_environment()
	return null

func _get_context():
	if Engine.has_singleton("JavaSingletonBridge"):
		return Engine.get_singleton("JavaSingletonBridge").get_context()
	return null

func _get_document_file_via_jni(tree_uri: String):
	# Get DocumentFile using SAF via JNI
	var jni_env = _get_jni_environment()
	var android_context = _get_context()
	if not jni_env or not android_context:
		return null
	
	# Use DocumentsContract to get tree DocumentFile
	var documents_contract_class = jni_env.find_class("android.provider.DocumentsContract")
	var tree_uri_class = jni_env.find_class("android.net.Uri")
	
	# Build tree URI and get document file
	var tree_uri_obj = jni_env.call_static_method(tree_uri_class, "parse", tree_uri)
	var document_file_class = jni_env.find_class("android.content.DocumentFile")
	
	# Call DocumentFile.fromUri(context, uri)
	var from_uri_method = document_file_class.get_method("fromUri", "(Landroid/content/Context;Landroid/net/Uri;)Landroid/content/DocumentFile;")
	var doc_file = jni_env.call_method(android_context, "getContentResolver", "Landroid/content/ContentResolver;")
	var result = jni_env.call_method(doc_file, "acquireContentProviderClient", tree_uri, "Landroid/net/Uri;")
	
	# Simplified: just try to get DocumentFile from SAF singleton if available
	if Engine.has_singleton(" SAF "):
		return Engine.get_singleton(" SAF ").getDocumentFile(tree_uri)
	return null

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
	# Use JNI to perform copy via DocumentFile API
	return _saf_copy_or_move_file(source_uri, dest_parent_uri, name, false)

func _move_file_saf(source_uri: String, dest_parent_uri: String, name: String) -> bool:
	if not _is_android():
		return false
	return _saf_copy_or_move_file(source_uri, dest_parent_uri, name, true)

func _saf_copy_or_move_file(source_uri: String, dest_parent_uri: String, name: String, is_move: bool) -> bool:
	# Get DocumentFile for source and destination
	var jni_env = _get_jni_environment()
	if not jni_env:
		return false
	
	# Find android.net.Uri class and parse URIs
	var uri_class = jni_env.find_class("android.net.Uri")
	var source_uri_obj = jni_env.call_static_method(uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;", source_uri)
	var dest_uri_obj = jni_env.call_static_method(uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;", dest_parent_uri)
	
	# Get DocumentFile classes and methods
	var doc_file_class = jni_env.find_class("android.content.DocumentFile")
	
	# For copy/move, we need to use the ContentResolver to open input/output streams
	# and copy the data. This is a simplified implementation.
	var android_context = _get_context()
	if not android_context:
		return false
	
	var content_resolver = jni_env.call_method(android_context, "getContentResolver", "()Landroid/content/ContentResolver;")
	if not content_resolver:
		return false
	
	# Open input stream
	var open_input_method_sig = "(Landroid/net/Uri;)Ljava/io/InputStream;"
	var input_stream = jni_env.call_method(content_resolver, "openInputStream", open_input_method_sig, source_uri_obj)
	
	if not input_stream:
		return false
	
	# Get output stream for destination
	var dest_doc_file = _get_document_file_for_uri(dest_parent_uri)
	if not dest_doc_file:
		return false
	
	# Create file in destination directory
	var create_file_method = doc_file_class.get_method("createFile", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/DocumentFile;")
	var mime_type = _get_mime_type(name)
	var new_file = jni_env.call_method(dest_doc_file, "createFile", create_file_method, mime_type, name)
	
	if not new_file:
		# Try with generic mime type
		create_file_method = doc_file_class.get_method("createFile", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/DocumentFile;")
		new_file = jni_env.call_method(dest_doc_file, "createFile", create_file_method, "application/octet-stream", name)
	
	if not new_file:
		return false
	
	# Get output URI from new file
	var new_file_uri = jni_env.call_method(new_file, "getUri", "()Landroid/net/Uri;")
	var output_stream = jni_env.call_method(content_resolver, "openOutputStream", "(Landroid/net/Uri;)Ljava/io/OutputStream;", new_file_uri)
	
	if not output_stream:
		return false
	
	# Copy data from input to output
	var buffer_size = 8192
	var bytes_copied = _copy_stream_data(jni_env, input_stream, output_stream, buffer_size)
	
	# Close streams
	jni_env.call_method(input_stream, "close", "()V")
	jni_env.call_method(output_stream, "close", "()V")
	
	if is_move:
		# Delete source file after successful copy
		_delete_saf_file_by_uri(source_uri)
	
	return bytes_copied > 0

func _copy_stream_data(jni_env, input_stream, output_stream, buffer_size: int) -> int:
	# Read from input and write to output
	var total_bytes := 0
	var buffer = jni_env.new_byte_array(buffer_size)
	
	var read_method = jni_env.get_method_id(input_stream, "read", "([B)I")
	var write_method = jni_env.get_method_id(output_stream, "write", "([B)V")
	
	var bytes_read = jni_env.call_method(input_stream, "read", read_method, buffer)
	while bytes_read > 0:
		jni_env.call_method(output_stream, "write", write_method, buffer)
		total_bytes += bytes_read
		bytes_read = jni_env.call_method(input_stream, "read", read_method, buffer)
	
	return total_bytes

func _get_mime_type(file_name: String) -> String:
	var ext = file_name.get_extension().to_lower()
	match ext:
		"jpg", "jpeg":
			return "image/jpeg"
		"png":
			return "image/png"
		"gif":
			return "image/gif"
		"webp":
			return "image/webp"
		"mp4":
			return "video/mp4"
		"txt":
			return "text/plain"
		"pdf":
			return "application/pdf"
		"doc", "docx":
			return "application/msword"
		_:
			return "application/octet-stream"

func _delete_file_saf(uri: String) -> bool:
	if not _is_android():
		return false
	return _delete_saf_file_by_uri(uri)

func _delete_saf_file_by_uri(uri: String) -> bool:
	# Use ContentResolver to delete the document
	var jni_env = _get_jni_environment()
	if not jni_env:
		return false
	
	var android_context = _get_context()
	if not android_context:
		return false
	
	var uri_class = jni_env.find_class("android.net.Uri")
	var uri_obj = jni_env.call_static_method(uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;", uri)
	
	var content_resolver = jni_env.call_method(android_context, "getContentResolver", "()Landroid/content/ContentResolver;")
	
	# Use delete method on ContentResolver
	var delete_result = jni_env.call_method(content_resolver, "delete", "(Landroid/net/Uri;Ljava/lang/String;[Ljava/lang/String;)I", uri_obj, null, null)
	
	return delete_result > 0

func _create_folder_saf(parent_uri: String, name: String) -> bool:
	if not _is_android():
		return false
	
	var jni_env = _get_jni_environment()
	if not jni_env:
		return false
	
	var android_context = _get_context()
	if not android_context:
		return false
	
	# Get parent DocumentFile
	var parent_doc = _get_document_file_for_uri(parent_uri)
	if not parent_doc:
		return false
	
	# Call createDirectory on the DocumentFile
	var doc_file_class = jni_env.find_class("android.content.DocumentFile")
	var create_dir_method = doc_file_class.get_method("createDirectory", "(Ljava/lang/String;)Landroid/content/DocumentFile;")
	
	var new_dir = jni_env.call_method(parent_doc, "createDirectory", create_dir_method, name)
	return new_dir != null

func _rename_saf(uri: String, new_name: String) -> bool:
	if not _is_android():
		return false
	
	# Rename is not directly supported by DocumentFile API
	# We need to use a different approach - rename typically requires
	# moving the file to a new name in the same parent directory
	var jni_env = _get_jni_environment()
	if not jni_env:
		return false
	
	# Get the document file for the URI
	var doc_file = _get_document_file_for_uri(uri)
	if not doc_file:
		return false
	
	# Get parent and create a new file with the new name, then delete old
	var doc_file_class = jni_env.find_class("android.content.DocumentFile")
	var get_parent_method = doc_file_class.get_method("getParentFile", "()Landroid/content/DocumentFile;")
	var parent_doc = jni_env.call_method(doc_file, "getParentFile", get_parent_method)
	
	if not parent_doc:
		return false
	
	# Get the current file name to determine mime type
	var get_name_method = doc_file_class.get_method("getName", "()Ljava/lang/String;")
	var old_name = jni_env.call_method(doc_file, "getName", get_name_method)
	var mime_type = _get_mime_type(str(old_name))
	
	# Create new file with new name
	var create_file_method = doc_file_class.get_method("createFile", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/DocumentFile;")
	var new_file = jni_env.call_method(parent_doc, "createFile", create_file_method, mime_type, new_name)
	
	if not new_file:
		return false
	
	# Copy content from old to new
	var source_doc_uri = jni_env.call_method(doc_file, "getUri", "()Landroid/net/Uri;")
	var new_doc_uri = jni_env.call_method(new_file, "getUri", "()Landroid/net/Uri;")
	
	if _copy_content_between_uris(source_doc_uri, new_doc_uri):
		# Delete original file
		jni_env.call_method(doc_file, "delete", "()Z")
		return true
	
	return false

func _copy_content_between_uris(source_uri, dest_uri) -> bool:
	var jni_env = _get_jni_environment()
	if not jni_env:
		return false
	
	var android_context = _get_context()
	if not android_context:
		return false
	
	var content_resolver = jni_env.call_method(android_context, "getContentResolver", "()Landroid/content/ContentResolver;")
	
	# Open input stream
	var input_stream = jni_env.call_method(content_resolver, "openInputStream", "(Landroid/net/Uri;)Ljava/io/InputStream;", source_uri)
	if not input_stream:
		return false
	
	# Open output stream
	var output_stream = jni_env.call_method(content_resolver, "openOutputStream", "(Landroid/net/Uri;)Ljava/io/OutputStream;", dest_uri)
	if not output_stream:
		jni_env.call_method(input_stream, "close", "()V")
		return false
	
	# Copy data
	var buffer_size = 8192
	var bytes_copied = _copy_stream_data(jni_env, input_stream, output_stream, buffer_size)
	
	jni_env.call_method(input_stream, "close", "()V")
	jni_env.call_method(output_stream, "close", "()V")
	
	return bytes_copied > 0

func _read_saf_file_text(uri: String) -> String:
	if not _is_android():
		return ""
	
	var bytes = _read_saf_file_bytes(uri)
	if bytes.size() == 0:
		return ""
	
	var text = ""
	text = bytes.get_string_from_utf8()
	return text

func _read_saf_file_bytes(uri: String) -> PackedByteArray:
	if not _is_android():
		return PackedByteArray()
	
	var jni_env = _get_jni_environment()
	if not jni_env:
		return PackedByteArray()
	
	var android_context = _get_context()
	if not android_context:
		return PackedByteArray()
	
	var uri_class = jni_env.find_class("android.net.Uri")
	var uri_obj = jni_env.call_static_method(uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;", uri)
	
	var content_resolver = jni_env.call_method(android_context, "getContentResolver", "()Landroid/content/ContentResolver;")
	var input_stream = jni_env.call_method(content_resolver, "openInputStream", "(Landroid/net/Uri;)Ljava/io/InputStream;", uri_obj)
	
	if not input_stream:
		return PackedByteArray()
	
	# Read all bytes from stream
	var bytes_result = PackedByteArray()
	var buffer_size = 8192
	var buffer = jni_env.new_byte_array(buffer_size)
	var read_method = jni_env.get_method_id(input_stream, "read", "([B)I")
	
	var bytes_read = jni_env.call_method(input_stream, "read", read_method, buffer)
	while bytes_read > 0:
		# Append buffer to result
		for i in range(bytes_read):
			bytes_result.append(jni_env.byte_array_get(buffer, i))
		bytes_read = jni_env.call_method(input_stream, "read", read_method, buffer)
	
	jni_env.call_method(input_stream, "close", "()V")
	
	return bytes_result

func _persist_saf_uri(tree_uri: String) -> void:
	if not _is_android():
		return
	# Persist URI permissions for SAF access
	# This should be called after user grants directory access via SAF picker
	var jni_env = _get_jni_environment()
	if not jni_env:
		return
	
	# Use SharedPreferences or ContentResolver to persist the tree URI
	var android_context = _get_context()
	if not android_context:
		return
	
	# Get SharedPreferences and persist the tree URI
	var shared_prefs = android_context.getSharedPreferences("saf_prefs", 0)
	var edit = shared_prefs.edit()
	edit.putString(SETTINGS_SAF_TREE_URI, tree_uri)
	edit.apply()
	
	# Also try to take persistable permission using ContentResolver
	var uri_class = jni_env.find_class("android.net.Uri")
	var uri_obj = jni_env.call_static_method(uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;", tree_uri)
	var content_resolver = android_context.getContentResolver()
	
	# Take persistable permission
	var take_method_sig = "(Landroid/net/Uri;I)V"
	content_resolver.takePersistableUriPermission(uri_obj, 1)  # Intent.FLAG_GRANT_READ_URI_PERMISSION | FLAG_GRANT_WRITE_URI_permission

## --- File Preview Generation ---
## Generate a preview/thumbnail for a file
func generate_file_preview(entry: Dictionary, max_size: Vector2i = Vector2i(128, 128)) -> ImageTexture:
	var texture := ImageTexture.new()
	var img := Image.new()
	
	var file_path = entry.get("path", "")
	var file_uri = entry.get("uri", "")
	var file_name = entry.get("name", "")
	var is_dir = entry.get("is_directory", false)
	
	if is_dir:
		# Create folder icon placeholder
		img.create(max_size.x, max_size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.3, 0.1))
		texture.set_image(img)
		return texture
	
	var ext = _get_extension(file_name).to_lower()
	
	# Handle SAF URIs on Android
	if file_uri != "" and _is_android() and is_android_saf_uri(file_uri):
		var preview_bytes = _read_saf_file_bytes(file_uri)
		if preview_bytes.size() > 0:
			img = Image.new()
			var err = img.save_png_to_buffer()  # This won't work directly
			# Instead, load from bytes if possible
			if ext in ["jpg", "jpeg", "png", "webp", "bmp", "gif"]:
				err = img.load_png_from_buffer(preview_bytes) if ext == "png" else img.load_jpg_from_buffer(preview_bytes)
				if err != OK:
					img = _create_placeholder_image(max_size, ext)
			else:
				img = _create_placeholder_image(max_size, ext)
		else:
			img = _create_placeholder_image(max_size, ext)
	else:
		# Local file
		if FileAccess.file_exists(file_path):
			if ext in ["jpg", "jpeg", "png", "webp", "bmp", "gif"]:
				var err = img.load(file_path)
				if err != OK:
					img = _create_placeholder_image(max_size, ext)
			else:
				img = _create_placeholder_image(max_size, ext)
		else:
			img = _create_placeholder_image(max_size, ext)
	
	# Resize to thumbnail
	var _interp := Image.INTERPOLATION_BILINEAR
	img.resize(max_size.x, max_size.y, _interp)
	texture.set_image(img)
	return texture

func _create_placeholder_image(max_size: Vector2i, extension: String) -> Image:
	var img := Image.create(max_size.x, max_size.y, false, Image.FORMAT_RGBA8)
	
	# Choose color based on file type
	var color := Color(0.4, 0.4, 0.4)
	match extension:
		"jpg", "jpeg", "png", "gif", "webp", "bmp":
			color = Color(0.2, 0.5, 0.2)  # Green for images
		"mp4", "avi", "mkv", "mov", "webm":
			color = Color(0.2, 0.2, 0.5)  # Blue for videos
		"mp3", "wav", "ogg", "flac":
			color = Color(0.5, 0.2, 0.5)  # Purple for audio
		"txt", "doc", "docx", "pdf":
			color = Color(0.5, 0.3, 0.2)  # Orange for documents
	
	img.fill(color)
	
	# Draw a simple icon shape
	var center = Vector2i(max_size.x / 2, max_size.y / 2)
	var icon_size = min(max_size.x, max_size.y) / 4
	img.fill_rect(Rect2i(center - Vector2i(icon_size, icon_size) / 2, Vector2i(icon_size, icon_size)), Color(1, 1, 1, 0.5))
	
	return img

## --- Utility ---
static func _get_extension(file_name: String) -> String:
	var dot_pos: int = file_name.rfind(".")
	if dot_pos >= 0:
		return file_name.substr(dot_pos + 1).to_lower()
	return ""
