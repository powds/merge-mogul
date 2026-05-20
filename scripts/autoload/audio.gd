extends Node

## Audio autoload for sound effects.
## Handles loading and playing game sound effects via a pooled AudioStreamPlayer system.

const SFX_BUS := "SFX"
const AUDIO_DIR := "res://assets/audio/sfx/"

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 4
var _sfx_library: Dictionary = {}
var _volume_db: float = 0.0

func _ready() -> void:
	_load_sfx_library()
	_init_pool()

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
		player.volume_db = _volume_db
		add_child(player)
		_players.append(player)

func play(sfx_name: String) -> void:
	if not _sfx_library.has(sfx_name):
		push_warning("Audio: unknown sfx " + sfx_name)
		return

	var path = _sfx_library[sfx_name]
	var stream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Audio: failed to load " + path)
		return

	# Find an available player (one that's not playing)
	var player = _get_available_player()
	if player == null:
		# All players busy, use the first one (loop)
		player = _players[0]

	player.stream = stream
	player.play()

func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.is_playing():
			return player
	return null

func set_volume(volume_db: float) -> void:
	_volume_db = volume_db
	for player in _players:
		player.volume_db = volume_db