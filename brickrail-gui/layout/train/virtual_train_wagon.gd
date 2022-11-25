
class_name VirtualTrainWagon
extends Node2D

var color = Color.black

func _init():
	material = load("res://layout/train/wagon_shader.tres").duplicate()

func set_color(color):
	material.set_shader_param("body_color", color)

func set_heading(heading):
	material.set_shader_param("heading", heading)

func set_facing(facing):
	material.set_shader_param("facing", facing)

func _draw():
	
	var size = Vector2(0.7,0.7)
	var wsize = size*LayoutInfo.spacing
	var col = color
	draw_rect(Rect2(-wsize*0.5, wsize), col)
