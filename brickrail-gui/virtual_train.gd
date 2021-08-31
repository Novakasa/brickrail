tool

class_name VirtualTrain
extends Node2D

var route_position = 0.0
var velocity = 0.0
var acceleration = 0.1
var hover=false
var selected=false
var dirtrack

export(Color) var color
export(Color) var accent_color

signal hover()
signal stop_hover()
signal clicked(event)
signal marker(marker)

func set_selected(p_selected):
	selected = p_selected
	update()

func set_dirtrack(p_dirtrack):
	var track = p_dirtrack.track
	dirtrack = p_dirtrack
	position = LayoutInfo.spacing*(Vector2(track.x_idx, track.y_idx) + track.get_center())
	rotation = dirtrack.get_rotation()

func _init():
	pass

func _draw():
	var spacing = LayoutInfo.spacing
	var size = spacing * Vector2(0.3,0.2)
	draw_rect(Rect2(-size*0.5, size), color)
	draw_circle(0.5*Vector2(size.x,0.0), size.y*0.5, color)
	draw_circle(-0.5*Vector2(size.x,0.0), size.y*0.5, color)
	draw_circle(0.5*Vector2(size.x,0.0), size.y*0.5*0.8, accent_color)
