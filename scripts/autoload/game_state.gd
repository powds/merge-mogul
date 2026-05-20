extends Node

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

var current_state: GameState = MENU

signal state_changed(new_state)

func set_state(new_state):
	current_state = new_state
	state_changed.emit(new_state)
