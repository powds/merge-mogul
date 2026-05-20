extends Node

## Audio autoload for sound effects and music.
## Handles loading and playing game sound effects via a pooled AudioStreamPlayer system.
## Also manages background music playback with looping support.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 4
var _sfx_library: Dictionary = {}
var _stream_cache: Dictionary = {}
var _initialized: bool = false

# Music player
var _music_player: AudioStreamPlayer
var _current_music: String = ""
var _music_volume: float = 1.0

func _ready() -> void:
	_load_sfx_library()
	_init_pool()
	_init_music_player()
	_initialized = true

func _load_sfx_library() -> void:
	# Map friendly names to audio file paths
	_sfx_library = {
		"ui_click": SFX_DIR + "ui_click.ogg",
		"ui_hover": SFX_DIR + "ui_hover.ogg",
		"merge": SFX_DIR + "merge.ogg",
		"level_up": SFX_DIR + "level_up.ogg",
	}

func _init_pool() -> void:
	for i in _pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	apply_volume_from_settings()

func _get_cached_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	
	if not ResourceLoader.exists(path):
		return null
	
	var stream = load(path)
	if stream:
		_stream_cache[path] = stream
	return stream

func play(sfx_name: String) -> void:
	if not _sfx_library.has(sfx_name):
		push_warning("Audio: unknown sfx " + sfx_name)
		return

	var path = _sfx_library[sfx_name]
	var stream = _get_cached_stream(path)
	if stream == null:
		push_warning("Audio: failed to load " + path)
		return

	# Find an available player (one that's not playing)
	var player = _get_available_player()
	if player == null:
		# All players busy, stop the oldest and reuse
		player = _players[0]
		player.stop()

	player.stream = stream
	player.play()

func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.is_playing():
			return player
	return null

func _init_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = 0
	add_child(_music_player)

func play_music(music_name: String, fade_duration: float = 0.5) -> void:
	var path = MUSIC_DIR + music_name + ".ogg"
	
	if not ResourceLoader.exists(path):
		push_warning("Audio: music file not found " + path)
		return
	
	var stream = load(path)
	if stream == null:
		push_warning("Audio: failed to load music " + path)
		return
	
	_current_music = music_name
	_music_player.stream = stream
	_music_player.stream.loop = true
	_music_player.play()

func stop_music(fade_duration: float = 0.5) -> void:
	_music_player.stop()
	_current_music = ""

func set_music_volume(volume: float) -> void:
	_music_volume = clamp(volume, 0.0, 1.0)
	_apply_music_volume()

func _apply_music_volume() -> void:
	if _music_player:
		var vol_linear = _music_volume
		# Apply master volume from settings if available
		if Settings:
			vol_linear *= Settings.master_volume if Settings.master_muted == false else 0.0
		_music_player.volume_db = linear_to_db(vol_linear) if vol_linear > 0 else -80.0

func apply_volume_from_settings() -> void:
	if not _initialized:
		return

	var master_vol := Settings.master_volume if Settings.master_muted == false else 0.0
	var sfx_vol := Settings.sfx_volume if Settings.sfx_muted == false else 0.0
	
	# Combine master and sfx volume (in dB)
	var combined_vol_linear = master_vol * sfx_vol
	var volume_db := linear_to_db(combined_vol_linear) if combined_vol_linear > 0 else -80.0
	
	for player in _players:
		player.volume_db = volume_db
	
	_apply_music_volume()