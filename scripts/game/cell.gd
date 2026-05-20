extends Node2D

@onready var highlight: ColorRect = $Highlight

## Show highlight when item hovers over this cell
func highlight() -> void:
	highlight.visible = true

## Remove highlight when item stops hovering
func clear() -> void:
	highlight.visible = false
