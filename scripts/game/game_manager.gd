extends Node
## Game state, coins, and level XP manager
## Autoload singleton: GameManager

# Signals
signal game_state_changed(state: int)
signal coins_changed(amount: int)
signal xp_changed(current: int, max: int)
signal level_up(new_level: int)

# Enums
enum GameState { IDLE, PLAYING, PAUSED, GAME_OVER, VICTORY }

# State
var current_state: GameState = GameState.IDLE:
	set(value):
		current_state = value
		game_state_changed.emit(value)

var coins: int = 0:
	set(value):
		coins = value
		coins_changed.emit(coins)

var current_level: int = 1
var current_xp: int = 0:
	set(value):
		current_xp = value
		_check_level_up()
		xp_changed.emit(current_xp, xp_to_next_level())

# XP curve
const XP_BASE: int = 100
const XP_MULTIPLIER: float = 1.5

func _ready() -> void:
	load_game()

func xp_to_next_level() -> int:
	return int(XP_BASE * pow(XP_MULTIPLIER, current_level - 1))

func _check_level_up() -> void:
	while current_xp >= xp_to_next_level():
		current_xp -= xp_to_next_level()
		current_level += 1
		level_up.emit(current_level)

# State helpers
func start_game() -> void:
	current_state = GameState.PLAYING

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING

func game_over() -> void:
	current_state = GameState.GAME_OVER
	save_game()

func victory() -> void:
	current_state = GameState.VICTORY
	save_game()

func reset_run() -> void:
	coins = 0
	current_xp = 0
	current_level = 1
	current_state = GameState.IDLE

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

# Persistence
func save_game() -> void:
	var data = {
		"coins": coins,
		"current_level": current_level,
		"current_xp": current_xp
	}
	var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_game() -> void:
	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data:
			coins = data.get("coins", 0)
			current_level = data.get("current_level", 1)
			current_xp = data.get("current_xp", 0)
