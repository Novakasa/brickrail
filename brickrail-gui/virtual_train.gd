tool

class_name VirtualTrain
extends Node2D

var route_pos = 0.0
var track_pos = 0.0
var velocity = 0.0
var acceleration = 1.5
var deceleration = 3.0
var hover=false
var selected=false
var dirtrack
var turn=null
var length = 0.0
var size = Vector2(0.3,0.2)
var facing: int = 1
var max_velocity = 3.0
var slow_velocity = 0.5

var state = "stopped"

export(Color) var color
export(Color) var accent_color
export(Color) var hover_color
export(Color) var selected_color

signal hover()
signal stop_hover()
signal clicked(event)
signal marker(marker)

func _ready():
	_on_settings_colors_changed()
	Settings.connect("colors_changed", self, "_on_settings_colors_changed")

func _on_settings_colors_changed():
	color = Settings.colors["secondary"]*1.5
	selected_color = Settings.colors["tertiary"]

func has_point(pos):
	var spacing = LayoutInfo.spacing
	var wsize = size*spacing
	wsize.x = wsize.x + wsize.y
	var hitbox = Rect2(-wsize*0.5, wsize)
	return hitbox.has_point(pos)

func set_facing(p_facing):
	prints("setting facing:", p_facing)
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

func start():
	set_state("started")

func slow():
	set_state("slow")

func stop():
	set_state("stopped")

func flip_heading():
	if state!="stopped":
		push_error("can't flip heading while state is " + state)
		return
	var prev_pos = track_pos
	set_dirtrack(dirtrack.get_next(turn).get_opposite())
	track_pos = length-prev_pos
	set_facing(facing*-1)

func set_state(p_state):
	state = p_state

func _process(delta):
	if state=="started":
		velocity = min(velocity+acceleration*delta, max_velocity)
	if state=="slow":
		if velocity<slow_velocity:
			velocity = min(velocity+acceleration*delta, slow_velocity)
		else:
			velocity = max(velocity-deceleration*delta, slow_velocity)
	if state=="stopped":
		velocity = max(velocity-2*deceleration*delta, 0.0)
	
	track_pos = track_pos + velocity*delta
	update_position()

func update_position():
	while track_pos > length:
		track_pos -= length
		set_dirtrack(dirtrack.get_next(turn))
	var interpolation = dirtrack.interpolate(track_pos, turn)
	position = dirtrack.to_world(interpolation.position)
	rotation = interpolation.rotation

func set_selected(p_selected):
	selected = p_selected
	update()

func set_hover(p_hover):
	hover = p_hover
	update()

func set_dirtrack(p_dirtrack):
	var track = p_dirtrack.track
	dirtrack = p_dirtrack
	turn = dirtrack.get_next_turn()
	length = dirtrack.get_connection_length(turn)
	position = LayoutInfo.spacing*(Vector2(track.x_idx, track.y_idx) + track.get_center())
	rotation = dirtrack.get_rotation()
	track_pos = 0.0
	if dirtrack.track.sensor!=null:
		dirtrack.track.sensor.trigger(null)

func _init():
	pass

func _draw():
	var wsize = size*LayoutInfo.spacing
	var col = color
	if selected:
		col = selected_color
	if hover:
		col = col*1.5
	draw_rect(Rect2(-wsize*0.5, wsize), col)
	draw_circle(0.5*Vector2(wsize.x,0.0), wsize.y*0.5, col)
	draw_circle(-0.5*Vector2(wsize.x,0.0), wsize.y*0.5, col)
	draw_circle(0.5*Vector2(facing*wsize.x,0.0), wsize.y*0.5*0.8, accent_color)
	var tri_start_x = 0.5*(wsize.x+wsize.y*1.3)
	var tri_delta_y = 0.3*wsize.y
	var tri_end_x = tri_start_x+tri_delta_y
	draw_colored_polygon([Vector2(tri_start_x,-tri_delta_y), Vector2(tri_end_x,0.0), Vector2(tri_start_x, tri_delta_y)], col)
