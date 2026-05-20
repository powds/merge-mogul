extends Node

## Game state constants
const STATE_MENU := 0
const STATE_PLAYING := 1
const STATE_PAUSED := 2
const STATE_GAME_OVER := 3
const STATE_VICTORY := 4

var current_state = STATE_MENU

signal state_changed(new_state)

func set_state(new_state):
	current_state = new_state
	state_changed.emit(new_state)
