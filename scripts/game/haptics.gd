extends Node

## Haptics feedback controller for Android vibration feedback.
## Provides different vibration patterns for game events.

## Vibration durations in milliseconds
const DURATION_SHORT_TICK := 20
const DURATION_MEDIUM_PULSE := 50
const DURATION_LONG_PATTERN := 100

## Whether haptics are enabled (can be toggled from settings)
var enabled: bool = true

func _ready() -> void:
	# Haptics available on Android and iOS
	pass

## Item pickup - short tick feedback
func item_pickup() -> void:
	if enabled and OS.has_feature("Android"):
		DisplayServer.vibrate_handheld(DURATION_SHORT_TICK)

## Item drop or merge - medium pulse feedback
func item_drop() -> void:
	if enabled and OS.has_feature("Android"):
		DisplayServer.vibrate_handheld(DURATION_MEDIUM_PULSE)

## Item merge - medium pulse (alias for item_drop)
func item_merge() -> void:
	item_drop()

## Level up - longer pattern feedback
func level_up() -> void:
	if enabled and OS.has_feature("Android"):
		DisplayServer.vibrate_handheld(DURATION_LONG_PATTERN)

## Button press - short tick feedback
func button_press() -> void:
	if enabled and OS.has_feature("Android"):
		DisplayServer.vibrate_handheld(DURATION_SHORT_TICK)

## Toggle haptics on/off
func set_enabled(value: bool) -> void:
	enabled = value

## Check if haptics are available on current platform
func is_available() -> bool:
	return OS.has_feature("Android")
