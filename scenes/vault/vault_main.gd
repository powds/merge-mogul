extends Control

## Vault Main View
## Displays file list in the vault, handles settings and navigation

signal item_selected(uuid: String)
signal settings_requested()
signal back_requested()
signal add_item_requested()

@onready var items_grid: GridContainer = $Panel/VBoxContainer/VaultContent/ItemsGrid
@onready var gold_label: Label = $Panel/VBoxContainer/Footer/GoldLabel
@onready var settings_btn: Button = $Panel/VBoxContainer/Header/SettingsBtn
@onready var back_button: Button = $Panel/VBoxContainer/Footer/BackButton
@onready var add_item_btn: Button = $Panel/VBoxContainer/Footer/AddItemBtn

var _vault_items: Array = []
var _is_unlocked: bool = false

func _ready() -> void:
	_connect_signals()
	_setup_buttons()

func _connect_signals() -> void:
	if VaultManager:
		VaultManager.vault_unlocked.connect(_on_vault_unlocked)
		VaultManager.vault_locked.connect(_on_vault_locked)

func _setup_buttons() -> void:
	settings_btn.pressed.connect(_on_settings_pressed)
	back_button.pressed.connect(_on_back_pressed)
	add_item_btn.pressed.connect(_on_add_item_pressed)

func show_vault() -> void:
	visible = true
	_is_unlocked = VaultManager.is_unlocked() if VaultManager else false
	_update_ui()

func hide_vault() -> void:
	visible = false

func _update_ui() -> void:
	if _is_unlocked:
		_show_unlocked_state()
	else:
		_show_locked_state()

func _show_unlocked_state() -> void:
	add_item_btn.disabled = false
	_refresh_items()

func _show_locked_state() -> void:
	add_item_btn.disabled = true
	_clear_items()

func _refresh_items() -> void:
	_clear_items()
	# In a full implementation, load items from VaultStorage
	# For now, show placeholder
	gold_label.text = "Vault Contents"

func _clear_items() -> void:
	for child in items_grid.get_children():
		child.queue_free()

func _on_vault_unlocked(is_decoy: bool) -> void:
	_is_unlocked = true
	_update_ui()

func _on_vault_locked() -> void:
	_is_unlocked = false
	_update_ui()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_add_item_pressed() -> void:
	add_item_requested.emit()