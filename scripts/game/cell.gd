extends Node2D

@onready var highlight: ColorRect = $Highlight

## Show highlight when item hovers over this cell
func show_highlight() -> void:
	highlight.visible = true

## Remove highlight when item stops hovering
func hide_highlight() -> void:
	highlight.visible = false
