extends Node

## Global game state manager autoload.
## Tracks coins, level, XP, and game state across all scenes.
## Uses SaveSystem for persistence.

# Signals
signal game_state_changed(state: int)
signal coins_changed(amount: int)
signal xp_changed(current: int, max_xp: int)
signal level_up(new_level: int)

# Enums
enum GameState { MENU, PLAYING, PAUSED }

# Persistent state
var current_state = GameState.MENU:
	set(value):
		current_state = value
		game_state_changed.emit(value)

var coins: int = 0:
	set(value):
		coins = value
		coins_changed.emit(coins)

var level: int = 1
var current_xp: int = 0:
	set(value):
		current_xp = value
		xp_changed.emit(current_xp, xp_to_next_level())

# XP curve constants
const XP_BASE: int = 100
const XP_MULTIPLIER: float = 1.5

func _ready() -> void:
	_load_game()

## Returns XP required to reach the next level
func xp_to_next_level() -> int:
	return int(XP_BASE * pow(XP_MULTIPLIER, level - 1))

func _check_level_up() -> void:
	while current_xp >= xp_to_next_level():
		current_xp -= xp_to_next_level()
		level += 1
		level_up.emit(level)

# Game state methods
func start_game() -> void:
	current_state = GameState.PLAYING

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING

func reset_game() -> void:
	current_state = GameState.MENU
	coins = 0
	level = 1
	current_xp = 0

# Coin helpers
func add_coins(amount: int) -> void:
	coins += amount

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		return true
	return false

# XP helpers
func add_xp(amount: int) -> void:
	current_xp += amount
	_check_level_up()

# Persistence using SaveSystem
func _load_game() -> void:
	var data := SaveSystem.load_game()
	if data.is_empty():
		return
	coins = data.get("coins", 0)
	level = data.get("level", 1)
	current_xp = data.get("current_xp", 0)
	_check_level_up()

func save_game() -> void:
	var data := {
		"coins": coins,
		"level": level,
		"current_xp": current_xp
	}
	SaveSystem.save_game(data)
