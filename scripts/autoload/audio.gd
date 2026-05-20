extends Node

## Audio autoload for sound effects.
## Handles loading and playing game sound effects via AudioStreamPlayer nodes.

const SFX_BUS := "SFX"

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 4

func _ready() -> void:
	for i in _pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)

	_players[0].stream = preload("res://assets/audio/sfx/ui_hover.ogg")
	_players[1].stream = preload("res://assets/audio/sfx/ui_click.ogg")
	_players[2].stream = preload("res://assets/audio/sfx/jump.ogg")
	_players[3].stream = preload("res://assets/audio/sfx/land.ogg")

func play(sfx_name: String, volume_db: float = 0.0) -> void:
	match sfx_name:
		"ui_hover":
			_play_index(0, volume_db)
		"ui_click":
			_play_index(1, volume_db)
		"jump":
			_play_index(2, volume_db)
		"land":
			_play_index(3, volume_db)

func _play_index(index: int, volume_db: float) -> void:
	if index < 0 or index >= _players.size():
		return
	var player := _players[index]
	player.volume_db = volume_db
	player.play()
