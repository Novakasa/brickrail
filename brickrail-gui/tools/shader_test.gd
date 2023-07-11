@tool
extends Node2D

@export var size: Vector2: set = set_size

func set_size(p_size):
	size = p_size
	update()

func _draw():
	draw_rect(Rect2(Vector2(), size), Color.BLACK)
