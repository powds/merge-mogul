extends Control

## PIN Entry Screen
## Handles 4-6 digit PIN input with numpad

signal pin_submitted(pin: String)
signal pin_cleared()
signal back_requested()

const PIN_MIN := 4
const PIN_MAX := 6

@onready var pin_display: Label = $Panel/VBoxContainer/PinDisplay
@onready var error_label: Label = $Panel/VBoxContainer/ErrorLabel

var _current_pin: String = ""
var _is_locked: bool = false

func _ready() -> void:
	_connect_vault_signals()
	_update_display()

func _connect_vault_signals() -> void:
	if VaultManager:
		VaultManager.lockout_started.connect(_on_lockout_started)
		VaultManager.lockout_ended.connect(_on_lockout_ended)
		VaultManager.wrong_pin_attempt.connect(_on_wrong_pin)
		VaultManager.break_in_alert.connect(_on_break_in_alert)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			append_digit(str(event.keycode - KEY_0))
		elif event.keycode == KEY_BACKSPACE:
			backspace()
		elif event.keycode == KEY_ENTER:
			submit_pin()

func append_digit(digit: String) -> void:
	if _is_locked or _current_pin.length() >= PIN_MAX:
		return
	_current_pin += digit
	_update_display()
	_clear_error()
	if _current_pin.length() >= PIN_MIN:
		submit_pin()

func backspace() -> void:
	if _is_locked or _current_pin.is_empty():
		return
	_current_pin = _current_pin.substr(0, _current_pin.length() - 1)
	_update_display()

func clear_input() -> void:
	_current_pin = ""
	_update_display()

func submit_pin() -> void:
	if _is_locked:
		return
	if _current_pin.length() < PIN_MIN:
		_show_error("PIN too short (min %d digits)" % PIN_MIN)
		return
	pin_submitted.emit(_current_pin)
	_current_pin = ""
	_update_display()

func _update_display() -> void:
	var display := ""
	for i in range(PIN_MAX):
		if i < _current_pin.length():
			display += "*"
		else:
			display += "_"
		if i < PIN_MAX - 1:
			display += " "
	pin_display.text = display

func _show_error(msg: String) -> void:
	error_label.text = msg

func _clear_error() -> void:
	error_label.text = ""

func _on_btn_pressed(digit: String) -> void:
	append_digit(digit)

func _on_clear_pressed() -> void:
	clear_input()
	pin_cleared.emit()

func _on_back_pressed() -> void:
	backspace()

func _on_lockout_started(seconds: int) -> void:
	_is_locked = true
	_show_error("Locked for %ds" % seconds)
	clear_input()

func _on_lockout_ended() -> void:
	_is_locked = false
	_clear_error()

func _on_wrong_pin(attempts_remaining: int) -> void:
	_show_error("Wrong PIN! %d attempts left" % attempts_remaining)
	clear_input()

func _on_break_in_alert(timestamp: String, photo_path: String) -> void:
	_show_error("BREAK-IN DETECTED!")
	clear_input()