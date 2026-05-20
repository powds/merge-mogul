extends Control

## Vault Settings Panel
## Handles PIN change, auto-lock, max slots configuration

signal back_requested()
signal pin_change_requested()

@onready var auto_lock_spinbox: SpinBox = $Panel/VBoxContainer/SecuritySection/AutoLock/AutoLockSpinBox
@onready var max_slots_spinbox: SpinBox = $Panel/VBoxContainer/StorageSection/MaxSlots/MaxSlotsSpinBox
@onready var back_button: Button = $Panel/VBoxContainer/BackButton
@onready var change_pin_btn: Button = $Panel/VBoxContainer/SecuritySection/ChangePin/ChangePinBtn

var _settings_loaded: bool = false

func _ready() -> void:
	_load_settings()
	_setup_connections()

func _setup_connections() -> void:
	back_button.pressed.connect(_on_back_pressed)
	change_pin_btn.pressed.connect(_on_change_pin_pressed)
	auto_lock_spinbox.value_changed.connect(_on_auto_lock_changed)
	max_slots_spinbox.value_changed.connect(_on_max_slots_changed)

func _load_settings() -> void:
	if Settings:
		auto_lock_spinbox.value = Settings.get("vault.auto_lock_timeout", 60.0)
		max_slots_spinbox.value = Settings.get("vault.max_slots", 20.0)
	_settings_loaded = true

func _save_settings() -> void:
	if Settings:
		Settings.set("vault.auto_lock_timeout", auto_lock_spinbox.value)
		Settings.set("vault.max_slots", max_slots_spinbox.value)

func show_settings() -> void:
	visible = true
	if not _settings_loaded:
		_load_settings()

func hide_settings() -> void:
	visible = false

func _on_back_pressed() -> void:
	_save_settings()
	back_requested.emit()

func _on_change_pin_pressed() -> void:
	pin_change_requested.emit()

func _on_auto_lock_changed(value: float) -> void:
	if _settings_loaded:
		_save_settings()

func _on_max_slots_changed(value: float) -> void:
	if _settings_loaded:
		_save_settings()