extends Node

## User preferences and settings autoload.
## Persists user settings to config file and provides access to them throughout the game.

const CONFIG_PATH := "user://settings.cfg"

## Settings values
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false
var fullscreen: bool = true
var vsync: bool = true
var show_fps: bool = false
var show_touch_controls: bool = true

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", master_volume)
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
		master_muted = config.get_value("audio", "master_muted", master_muted)
		music_muted = config.get_value("audio", "music_muted", music_muted)
		sfx_muted = config.get_value("audio", "sfx_muted", sfx_muted)
		
		fullscreen = config.get_value("display", "fullscreen", fullscreen)
		vsync = config.get_value("display", "vsync", vsync)
		show_fps = config.get_value("display", "show_fps", show_fps)
		show_touch_controls = config.get_value("display", "show_touch_controls", show_touch_controls)
		
		_apply_display_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "master_muted", master_muted)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "show_fps", show_fps)
	config.set_value("display", "show_touch_controls", show_touch_controls)
	
	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_error("Failed to save settings: %s" % err)

func _apply_display_settings() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_audio_settings() -> void:
	if Audio:
		Audio.apply_volume_from_settings()

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display_settings()
	save_settings()

func toggle_fullscreen() -> void:
	fullscreen = !fullscreen
	_apply_display_settings()
	save_settings()

func toggle_vsync() -> void:
	vsync = !vsync
	_apply_display_settings()

func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	master_muted = false
	music_muted = false
	sfx_muted = false
	fullscreen = true
	vsync = true
	show_fps = false
	show_touch_controls = true
	_apply_display_settings()
	save_settings()