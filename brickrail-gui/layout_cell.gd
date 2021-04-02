class_name LayoutCell
extends Node2D

var x_idx
var y_idx
var spacing
var tracks = []

func _init(p_x_idx, p_y_idx, p_spacing):
	x_idx = p_x_idx
	y_idx = p_y_idx
	spacing = p_spacing
	
	position = Vector2(x_idx, y_idx)*spacing
