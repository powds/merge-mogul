extends Node

## Vault Manager - Scene Reference
## This file provides a reference implementation of the vault system.
## The actual autoload singleton is at: res://scripts/autoload/vault_manager.gd

## For use as a scene-based vault controller.
## Attach this script to a Control node in your vault UI scene.

signal pin_entered(pin: String)
signal vault_ui_unlocked()
signal vault_ui_locked()

const PIN_MIN_LENGTH := 4
const PIN_MAX_LENGTH := 6

@export var auto_lock_timeout: float = 60.0

var _current_pin_input: String = ""
var _is_setting_new_pin: bool = false
var _is_setting_decoy_pin: bool = false
var _confirm_pin: String = ""

func _ready() -> void:
	_connect_signals()

func _connect_signals() -> void:
	if VaultManager:
		VaultManager.vault_unlocked.connect(_on_vault_unlocked)
		VaultManager.vault_locked.connect(_on_vault_locked)
		VaultManager.lockout_started.connect(_on_lockout_started)
		VaultManager.lockout_ended.connect(_on_lockout_ended)
		VaultManager.wrong_pin_attempt.connect(_on_wrong_pin_attempt)
		VaultManager.pin_changed_success.connect(_on_pin_changed_success)

func append_digit(digit: int) -> void:
	if _current_pin_input.length() < PIN_MAX_LENGTH:
		_current_pin_input += str(digit)
		_check_pin_complete()

func append_digit_string(digit_str: String) -> void:
	if digit_str.is_valid_int() and _current_pin_input.length() < PIN_MAX_LENGTH:
		_current_pin_input += digit_str
		_check_pin_complete()

func backspace() -> void:
	if _current_pin_input.length() > 0:
		_current_pin_input = _current_pin_input.substr(0, _current_pin_input.length() - 1)

func clear_input() -> void:
	_current_pin_input = ""

func _check_pin_complete() -> void:
	if _current_pin_input.length() >= PIN_MIN_LENGTH:
		pin_entered.emit(_current_pin_input)

func submit_pin() -> bool:
	if VaultManager and _current_pin_input.length() >= PIN_MIN_LENGTH:
		var success := VaultManager.verify_pin(_current_pin_input)
		_current_pin_input = ""
		return success
	_current_pin_input = ""
	return false

func get_input_length() -> int:
	return _current_pin_input.length()

func get_masked_input() -> String:
	return "*".repeat(_current_pin_input.length())

func is_unlocked() -> bool:
	if VaultManager:
		return VaultManager.is_unlocked()
	return false

func is_decoy_unlocked() -> bool:
	if VaultManager:
		return VaultManager.is_decoy_unlocked()
	return false

func setup_new_pin() -> void:
	_is_setting_new_pin = true
	_confirm_pin = ""
	_current_pin_input = ""

func setup_decoy_pin() -> void:
	_is_setting_decoy_pin = true
	_confirm_pin = ""
	_current_pin_input = ""

func cancel_pin_setup() -> void:
	_is_setting_new_pin = false
	_is_setting_decoy_pin = false
	_confirm_pin = ""
	_current_pin_input = ""

func _on_vault_unlocked(is_decoy: bool) -> void:
	vault_ui_unlocked.emit()

func _on_vault_locked() -> void:
	vault_ui_locked.emit()
	_current_pin_input = ""

func _on_lockout_started(seconds_remaining: int) -> void:
	pass

func _on_lockout_ended() -> void:
	pass

func _on_wrong_pin_attempt(attempts_remaining: int) -> void:
	_current_pin_input = ""

func _on_pin_changed_success() -> void:
	_is_setting_new_pin = false
	_is_setting_decoy_pin = false
	_confirm_pin = ""
	_current_pin_input = ""
