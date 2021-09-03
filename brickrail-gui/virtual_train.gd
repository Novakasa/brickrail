tool

class_name VirtualTrain
extends Node2D

var route_position = 0.0
var velocity = 0.0
var acceleration = 0.1
var hover=false
var selected=false
var dirtrack
var size = Vector2(0.3,0.2)
var facing: int = 1

export(Color) var color
export(Color) var accent_color
export(Color) var hover_color
export(Color) var selected_color

signal hover()
signal stop_hover()
signal clicked(event)
signal marker(marker)

func has_point(pos):
	var spacing = LayoutInfo.spacing
	var wsize = size*spacing
	wsize.x = wsize.x + wsize.y
	var hitbox = Rect2(-wsize*0.5, wsize)
	return hitbox.has_point(pos)

func set_facing(p_facing):
	facing = p_facing
	update()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if not event.button_index in [BUTTON_LEFT, BUTTON_RIGHT]:
			return
		if has_point(get_local_mouse_position()):
			get_tree().set_input_as_handled()
			emit_signal("clicked", event)
	if event is InputEventMouseMotion:
		if has_point(get_local_mouse_position()):
			if not LayoutInfo.get_hover_lock():
				LayoutInfo.grid.stop_hover()
				get_tree().set_input_as_handled()
			emit_signal("hover")

func set_selected(p_selected):
	selected = p_selected
	update()

func set_hover(p_hover):
	hover = p_hover
	update()

func set_dirtrack(p_dirtrack):
	var track = p_dirtrack.track
	dirtrack = p_dirtrack
	position = LayoutInfo.spacing*(Vector2(track.x_idx, track.y_idx) + track.get_center())
	rotation = dirtrack.get_rotation()

func _init():
	pass

func _draw():
	var wsize = size*LayoutInfo.spacing
	var col = color
	if selected:
		col = selected_color
	if hover:
		col = hover_color
	draw_rect(Rect2(-wsize*0.5, wsize), col)
	draw_circle(0.5*Vector2(wsize.x,0.0), wsize.y*0.5, col)
	draw_circle(-0.5*Vector2(wsize.x,0.0), wsize.y*0.5, col)
	draw_circle(0.5*Vector2(facing*wsize.x,0.0), wsize.y*0.5*0.8, accent_color)
	var tri_start_x = 0.5*(wsize.x+wsize.y*1.3)
	var tri_delta_y = 0.3*wsize.y
	var tri_end_x = tri_start_x+tri_delta_y
	draw_colored_polygon([Vector2(tri_start_x,-tri_delta_y), Vector2(tri_end_x,0.0), Vector2(tri_start_x, tri_delta_y)], col)
