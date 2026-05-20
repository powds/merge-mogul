extends Node

## Audio autoload for sound effects.
## Handles loading and playing game sound effects via a pooled AudioStreamPlayer system.

const SFX_BUS := "SFX"
const AUDIO_DIR := "res://assets/audio/sfx/"

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 4
var _sfx_library: Dictionary = {}
var _stream_cache: Dictionary = {}
var _initialized: bool = false

func _ready() -> void:
	_load_sfx_library()
	_init_pool()
	_initialized = true

func _load_sfx_library() -> void:
	# Map friendly names to audio file paths
	_sfx_library = {
		"ui_click": AUDIO_DIR + "ui_click.ogg",
		"ui_hover": AUDIO_DIR + "ui_hover.ogg",
		"merge": AUDIO_DIR + "merge.ogg",
		"level_up": AUDIO_DIR + "level_up.ogg",
	}

func _init_pool() -> void:
	for i in _pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_apply_volume_from_settings()

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