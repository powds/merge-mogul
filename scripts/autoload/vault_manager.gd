extends Node

## Vault Manager Autoload
## Handles PIN authentication, vault state, and secure storage.

signal vault_unlocked(is_decoy: bool)
signal vault_locked()
signal lockout_started(seconds_remaining: int)
signal lockout_ended()
signal pin_changed_success()
signal wrong_pin_attempt(attempts_remaining: int)

enum State { LOCKED, UNLOCKED, LOCKOUT }

const CONFIG_PATH := "user://vault.cfg"
const PIN_MIN_LENGTH := 4
const PIN_MAX_LENGTH := 6
const MAX_WRONG_ATTEMPTS := 3
const LOCKOUT_DURATION := 30
const AUTO_LOCK_TIMEOUT := 60

var _state: State = State.LOCKED
var _pin_hash: String = ""
var _decoy_pin_hash: String = ""
var _wrong_attempts: int = 0
var _lockout_time_remaining: int = 0
var _auto_lock_timer: float = 0
var _is_decoy_unlocked: bool = false
var _is_backgrounded: bool = false

func _ready() -> void:
	_load_vault_config()
	_state = State.LOCKED
	_auto_lock_timer = AUTO_LOCK_TIMEOUT

func _process(delta: float) -> void:
	if _state == State.LOCKOUT:
		pass
	elif _state == State.UNLOCKED:
		_auto_lock_timer -= delta
		if _auto_lock_timer <= 0:
			lock_vault()

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_is_backgrounded = true
		if _state == State.UNLOCKED:
			lock_vault()
	elif what == Node.NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_is_backgrounded = false

func is_unlocked() -> bool:
	return _state == State.UNLOCKED

func is_decoy_unlocked() -> bool:
	return _is_decoy_unlocked

func get_state() -> State:
	return _state

func _load_vault_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	
	if err == OK:
		_pin_hash = config.get_value("vault", "pin_hash", "")
		_decoy_pin_hash = config.get_value("vault", "decoy_pin_hash", "")

func save_vault_config() -> void:
	var config := ConfigFile.new()
	
	config.set_value("vault", "pin_hash", _pin_hash)
	config.set_value("vault", "decoy_pin_hash", _decoy_pin_hash)
	
	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_error("Failed to save vault config: %s" % err)

func has_pin_set() -> bool:
	return _pin_hash != ""

func _hash_pin(pin: String) -> String:
	return pin.sha256_text()

func verify_pin(pin: String) -> bool:
	if _state == State.LOCKOUT:
		return false
	
	var pin_hash := _hash_pin(pin)
	
	if pin_hash == _pin_hash:
		_unlock_vault(false)
		return true
	elif pin_hash == _decoy_pin_hash:
		_unlock_vault(true)
		return true
	else:
		_handle_wrong_pin()
		return false

func _unlock_vault(is_decoy: bool) -> void:
	_state = State.UNLOCKED
	_is_decoy_unlocked = is_decoy
	_wrong_attempts = 0
	_auto_lock_timer = AUTO_LOCK_TIMEOUT
	vault_unlocked.emit(is_decoy)

func lock_vault() -> void:
	if _state != State.LOCKOUT:
		_state = State.LOCKED
		_is_decoy_unlocked = false
		_auto_lock_timer = AUTO_LOCK_TIMEOUT
		vault_locked.emit()

func _handle_wrong_pin() -> void:
	_wrong_attempts += 1
	
	if _wrong_attempts >= MAX_WRONG_ATTEMPTS:
		_start_lockout()
	else:
		var remaining := MAX_WRONG_ATTEMPTS - _wrong_attempts
		wrong_pin_attempt.emit(remaining)

func _start_lockout() -> void:
	_state = State.LOCKOUT
	_lockout_time_remaining = LOCKOUT_DURATION
	_wrong_attempts = 0
	lockout_started.emit(LOCKOUT_DURATION)
	_lockout_countdown()

func _lockout_countdown() -> void:
	while _lockout_time_remaining > 0:
		await get_tree().create_timer(1.0).timeout
		_lockout_time_remaining -= 1
		lockout_started.emit(_lockout_time_remaining)
	
	_state = State.LOCKED
	lockout_ended.emit()

func set_pin(new_pin: String, is_decoy: bool = false) -> bool:
	if new_pin.length() < PIN_MIN_LENGTH or new_pin.length() > PIN_MAX_LENGTH:
		return false
	
	if not new_pin.is_valid_int():
		return false
	
	var pin_hash := _hash_pin(new_pin)
	
	if is_decoy:
		_decoy_pin_hash = pin_hash
	else:
		_pin_hash = pin_hash
	
	save_vault_config()
	pin_changed_success.emit()
	return true

func remove_decoy_pin() -> void:
	_decoy_pin_hash = ""
	save_vault_config()

func get_lockout_time_remaining() -> int:
	return _lockout_time_remaining

func reset_auto_lock_timer() -> void:
	_auto_lock_timer = AUTO_LOCK_TIMEOUT
