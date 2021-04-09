tool
extends Node2D

export(Vector2) var size setget set_size

func set_size(p_size):
	size = p_size
	update()

func _draw():
	draw_rect(Rect2(Vector2(), size), Color.black)
