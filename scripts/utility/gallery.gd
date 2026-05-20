extends Control

## Gallery for utility tab - displays images and videos from device storage.
## Supports MediaStore queries, thumbnail generation, and native file opening.

signal media_opened(path: String)
signal media_deleted(path: String)
signal closed

const THUMBNAIL_SIZE := 128
const SUPPORTED_IMAGE_EXTENSIONS := ["jpg", "jpeg", "png", "webp", "bmp", "gif"]
const SUPPORTED_VIDEO_EXTENSIONS := ["mp4", "webm", "avi", "mkv", "mov"]

var _media_files: Array[Dictionary] = []
var _current_index: int = 0
var _thumbnail_size: Vector2i = Vector2i(THUMBNAIL_SIZE, THUMBNAIL_SIZE)
var _is_fullscreen: bool = false
var _thumbnail_cache: Dictionary = {}

@onready var background := $Background
@onready var title_label := $Background/VBoxContainer/Header/TitleLabel
@onready var counter_label := $Background/VBoxContainer/Header/CounterLabel
@onready var texture_rect := $Background/VBoxContainer/CenterContainer/TextureRect
@onready var prev_button := $Background/VBoxContainer/NavigationContainer/PrevButton
@onready var next_button := $Background/VBoxContainer/NavigationContainer/NextButton
@onready var thumbnail_strip := $Background/VBoxContainer/NavigationContainer/ThumbnailStrip
@onready var close_button := $Background/VBoxContainer/Footer/CloseButton
@onready var fullscreen_button := $Background/VBoxContainer/Footer/FullscreenButton

func _ready() -> void:
	_refresh_media()
	_update_display()

func _refresh_media() -> void:
	_media_files.clear()
	_clear_thumbnails()
	_query_media_store()
	_update_thumbnail_strip()
	_update_display()

func _query_media_store() -> void:
	## Query images and videos from MediaStore.
	## MediaStore content:// URIs require special handling on Android.
	
	# Query images
	var image_uri_query := {
		"source": "MediaStore.Images",
		"sort_by": "date_added",
		"sort_descending": true
	}
	
	# Query videos
	var video_uri_query := {
		"source": "MediaStore.Video",
		"sort_by": "date_added",
		"sort_descending": true
	}
	
	# Use Android MediaStore query via ProjectSettings
	if DisplayServer.has_feature(DisplayServer.FEATURE_ANDROID):
		_query_android_media(image_uri_query, "image")
		_query_android_media(video_uri_query, "video")
	else:
		# Desktop fallback: scan user://media or user://Pictures
		_scan_directory("user://", SUPPORTED_IMAGE_EXTENSIONS + SUPPORTED_VIDEO_EXTENSIONS)

func _query_android_media(query: Dictionary, media_type: String) -> void:
	## Query MediaStore on Android using JNI.
	var jni_env = JavaSingletonBridge.get_jni_environment()
	if not jni_env:
		push_error("Failed to get JNI environment for MediaStore query")
		return
	
	var android_context = JavaSingletonBridge.get_context()
	if not android_context:
		push_error("Failed to get Android context for MediaStore query")
		return
	
	# Get ContentResolver from context
	var content_resolver = android_context.getContentResolver()
	if not content_resolver:
		push_error("Failed to get ContentResolver")
		return
	
	# Build MediaStore query URI based on media type
	var uri := ""
	var projection := PackedStringArray()
	
	if media_type == "image":
		uri = "android.provider.MediaStore$Images$Media$EXTERNAL_CONTENT_URI"
		projection = ["_id", "_data", "_display_name", "date_added", "mime_type", "size"]
	else:
		uri = "android.provider.MediaStore$Video$Media$EXTERNAL_CONTENT_URI"
		projection = ["_id", "_data", "_display_name", "date_added", "mime_type", "duration", "size"]
	
	# Execute query through ContentResolver
	var cursor = content_resolver.query(uri, projection, null, null, "date_added DESC")
	
	if not cursor:
		push_warning("MediaStore query returned no results for: " + media_type)
		return
	
	# Process cursor results
	var id_col := cursor.getColumnIndex("_id")
	var data_col := cursor.getColumnIndex("_data")
	var name_col := cursor.getColumnIndex("_display_name")
	var date_col := cursor.getColumnIndex("date_added")
	var mime_col := cursor.getColumnIndex("mime_type")
	var size_col := cursor.getColumnIndex("size")
	
	var jni_env_raw = jni_env
	var cursor_count = cursor.getCount()
	
	for i in range(cursor_count):
		if cursor.moveToPosition(i):
			var file_path := ""
			if data_col >= 0:
				var data_val = cursor.getString(data_col)
				if data_val:
					file_path = str(data_val)
			
			if file_path == "" or not _file_exists(file_path):
				continue
			
			var file_name := ""
			if name_col >= 0:
				var name_val = cursor.getString(name_col)
				if name_val:
					file_name = str(name_val)
			
			var file_date := 0
			if date_col >= 0:
				file_date = cursor.getInt(date_col)
			
			var file_size := 0
			if size_col >= 0:
				file_size = cursor.getInt(size_col)
			
			_media_files.append({
				"path": file_path,
				"name": file_name,
				"type": media_type,
				"size": file_size,
				"date": file_date
			})
	
	cursor.close()


func _file_exists(path: String) -> bool:
	## Check if a file exists at the given path.
	# Use DirAccess to check file existence
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	return dir.file_exists(path)

func _scan_directory(path: String, extensions: Array[String]) -> void:
	## Fallback scanner for desktop platforms.
	var dir := DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			pass  # Optionally recurse
		else:
			var ext := file_name.get_extension().to_lower()
			if extensions.has(ext):
				var file_path := path.path_join(file_name)
				var is_video := SUPPORTED_VIDEO_EXTENSIONS.has(ext)
				_media_files.append({
					"path": file_path,
					"name": file_name,
					"type": "video" if is_video else "image",
					"size": 0,  # Would need FileAccess to get size
					"date": 0
				})
		file_name = dir.get_next()
	dir.list_dir_end()

func _clear_thumbnails() -> void:
	for child in thumbnail_strip.get_children():
		child.queue_free()
	_thumbnail_cache.clear()

func _update_thumbnail_strip() -> void:
	_clear_thumbnails()
	
	for i in _media_files.size():
		var thumb := _create_thumbnail_button(i)
		thumbnail_strip.add_child(thumb)

func _create_thumbnail_button(index: int) -> Button:
	var media := _media_files[index]
	var button := Button.new()
	button.custom_minimum_size = Vector2(_thumbnail_size)
	button.expand_icon = true
	button.alignment = Button.ALIGNMENT_CENTER
	
	var icon := _get_thumbnail_for_index(index)
	button.icon = icon
	
	button.pressed.connect(func(): _on_thumbnail_clicked(index))
	
	return button

func _get_thumbnail_for_index(index: int) -> ImageTexture:
	## Get or generate thumbnail for media at index.
	if index in _thumbnail_cache:
		return _thumbnail_cache[index]
	
	var media := _media_files[index]
	var thumb := _generate_thumbnail(media)
	var tex := ImageTexture.create_from_image(thumb)
	_thumbnail_cache[index] = tex
	return tex

func _generate_thumbnail(media: Dictionary) -> Image:
	## Generate thumbnail for a media file.
	var img := Image.new()
	var path := media["path"]
	
	if media["type"] == "image":
		var err := img.load(path)
		if err != OK:
			img.fill(Color(0.2, 0.2, 0.2))
	else:
		# For videos, create placeholder thumbnail
		img.create(_thumbnail_size.x, _thumbnail_size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.1, 0.1, 0.3))
		
		# Draw play icon indicator
		var play_color := Color(1, 1, 1, 0.8)
		var center := Vector2i(_thumbnail_size.x / 2, _thumbnail_size.y / 2)
		var size := Vector2i(_thumbnail_size.x / 4, _thumbnail_size.y / 4)
		img.fill_rect(Rect2i(center - size / 2, size), play_color)
	
	# Scale down to thumbnail size
	img.resize(_thumbnail_size.x, _thumbnail_size.y, Image.INTERPOLATION_BILINEAR)
	return img

func _update_display() -> void:
	if _media_files.is_empty():
		title_label.text = "Gallery (Empty)"
		counter_label.text = "0 / 0"
		texture_rect.texture = null
		prev_button.disabled = true
		next_button.disabled = true
		return
	
	title_label.text = "Gallery"
	counter_label.text = "%d / %d" % [_current_index + 1, _media_files.size()]
	
	var media := _media_files[_current_index]
	var texture := _get_full_texture(media)
	texture_rect.texture = texture
	
	prev_button.disabled = _current_index <= 0
	next_button.disabled = _current_index >= _media_files.size() - 1
	
	# Update thumbnail selection highlight
	for i in thumbnail_strip.get_children():
		i.disabled = false

func _get_full_texture(media: Dictionary) -> ImageTexture:
	## Load full resolution image/video thumbnail for display.
	if media["type"] == "image":
		var img := Image.new()
		var err := img.load(media["path"])
		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			return tex
	
	# Video placeholder
	var img := Image.new()
	img.create(640, 480, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.3))
	var tex := ImageTexture.create_from_image(img)
	return tex

func _on_thumbnail_clicked(index: int) -> void:
	_current_index = index
	_update_display()

func _on_prev_pressed() -> void:
	if _current_index > 0:
		_current_index -= 1
		_update_display()

func _on_next_pressed() -> void:
	if _current_index < _media_files.size() - 1:
		_current_index += 1
		_update_display()

func _on_close_pressed() -> void:
	closed.emit()
	hide()

func _on_fullscreen_pressed() -> void:
	_toggle_fullscreen()

func _toggle_fullscreen() -> void:
	_is_fullscreen = !_is_fullscreen
	if _is_fullscreen:
		fullscreen_button.text = "Exit Fullscreen"
	else:
		fullscreen_button.text = "Fullscreen"
	# Toggle fullscreen mode - in a real implementation this would
	# switch the TextureRect to cover the entire screen
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if _is_fullscreen else TextureRect.EXPAND_OVERRIDE_SIZE

func open_file(path: String) -> void:
	## Open a file with the system native viewer.
	if DisplayServer.has_feature(DisplayServer.FEATURE_ANDROID):
		_open_file_android(path)
	else:
		_open_file_desktop(path)
	
	media_opened.emit(path)

func _open_file_android(path: String) -> void:
	## Open file using Android Intent system.
	## Requires JNI bridge or Godot's OS.shell_open on supported versions.
	OS.shell_open(path)

func _open_file_desktop(path: String) -> void:
	## Open file with desktop default application.
	OS.shell_open(path)

func delete_file(path: String) -> bool:
	## Delete a media file from storage.
	## Returns true if successful.
	
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	
	var err := dir.remove(path)
	if err != OK:
		push_error("Failed to delete file: %s" % path)
		return false
	
	# Refresh media list
	var index := _media_files.find(func(m): return m["path"] == path)
	if index != -1:
		_media_files.remove_at(index)
		if _current_index >= _media_files.size():
			_current_index = max(0, _media_files.size() - 1)
	
	_update_thumbnail_strip()
	_update_display()
	media_deleted.emit(path)
	return true

func refresh() -> void:
	_refresh_media()