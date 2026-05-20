extends Control

## Main tab controller with 5 sections: Game, Files, Gallery, Apps, Vault

const GAME_SCENE = preload("res://scenes/game/game.tscn")
const FILES_SCENE = preload("res://scenes/utility/file_browser.tscn")
const GALLERY_SCENE = preload("res://scenes/utility/gallery.tscn")
const APPS_SCENE = preload("res://scenes/utility/apps_list.tscn")
const VAULT_SCENE = preload("res://scenes/vault/vault_main.tscn")

@onready var tab_buttons: HBoxContainer = $TabBar/TabButtons
@onready var content_container: Control = $ContentContainer

var tab_scenes: Array[PackedScene] = []
var tab_names: Array[String] = ["Game", "Files", "Gallery", "Apps", "Vault"]
var current_tab: int = 0
var loaded_tabs: Dictionary = {}


func _ready() -> void:
	tab_scenes = [GAME_SCENE, FILES_SCENE, GALLERY_SCENE, APPS_SCENE, VAULT_SCENE]
	
	# Connect tab button signals
	for i in range(tab_buttons.get_child_count()):
		var btn: Button = tab_buttons.get_child(i)
		btn.pressed.connect(_on_tab_button_pressed.bind(i))
	
	# Load the first tab
	switch_to_tab(0)


func _on_tab_button_pressed(index: int) -> void:
	switch_to_tab(index)


func switch_to_tab(index: int) -> void:
	if index < 0 or index >= tab_scenes.size():
		return
	
	# Unload current tab if exists
	if loaded_tabs.has(current_tab):
		var old_instance = loaded_tabs[current_tab]
		if is_instance_valid(old_instance):
			old_instance.queue_free()
		loaded_tabs.erase(current_tab)
	
	# Update button states
	for i in range(tab_buttons.get_child_count()):
		var btn: Button = tab_buttons.get_child(i)
		btn.remove_theme_stylebox_override("normal")
		if i == index:
			btn.add_theme_stylebox_override("normal", btn.get_theme_stylebox("pressed", "Button"))
		else:
			btn.add_theme_stylebox_override("normal", btn.get_theme_stylebox("hover", "Button"))
	
	current_tab = index
	
	# Load and show new tab
	var scene = tab_scenes[index]
	var instance = scene.instantiate()
	content_container.add_child(instance)
	loaded_tabs[index] = instance
	
	# Make sure Game tab is Node2D and gets proper viewport
	if instance is Node2D:
		instance.set_process(true)