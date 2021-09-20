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
var expect_marker = null
var expect_behaviour = null

var allow_sensor_advance = true
var prev_sensor_track = null
var next_sensor_track = null
var next_sensor_distance = 0.0

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

func update_next_sensor_info():
	var distance
	var itertrack
	if prev_sensor_track == null:
		distance = length - track_pos
		itertrack = dirtrack.get_next()
	else:
		itertrack = prev_sensor_track.get_next()
		distance = next_sensor_distance + prev_sensor_track.get_connection_length()
	while itertrack.track.sensor==null:
		var next_turn = itertrack.get_next_turn()
		if next_turn == null:
			next_sensor_track = null
			next_sensor_distance = 0.0
			return
		distance += itertrack.get_connection_length(next_turn)
		itertrack = itertrack.get_next(next_turn)
	next_sensor_track = itertrack
	next_sensor_distance = distance

func advance_to_next_sensor_track():
	advance_position(next_sensor_distance)
	pass_sensor(next_sensor_track.track.sensor)
	prev_sensor_track = next_sensor_track
	next_sensor_track = null

func set_expect_marker(colorname, behaviour):
	expect_marker = colorname
	expect_behaviour = behaviour

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
	
	var distance_modulation = 1.0
	if not allow_sensor_advance:
		distance_modulation = min(next_sensor_distance/1.0, 1.0)
		# if distance_modulation < 1.0:
		# 	distance_modulation = 0.0
	var delta_pos = velocity*delta*distance_modulation
	advance_position(delta_pos)

func advance_position(delta_pos):
	track_pos += delta_pos
	next_sensor_distance -= delta_pos
	wrap_dirtrack()
	update_position()

func wrap_dirtrack():
	while track_pos > length:
		track_pos -= length
		set_dirtrack(dirtrack.get_next(turn))
		if dirtrack == next_sensor_track and allow_sensor_advance:
			var sensor = dirtrack.track.sensor
			pass_sensor(sensor)

func pass_sensor(sensor):
	if expect_marker != null:
		assert(sensor.get_colorname() == expect_marker)
		if expect_behaviour == "stop":
			stop()
		if expect_behaviour == "slow":
			slow()
		if expect_behaviour == "flip_heading":
			flip_heading()
	if allow_sensor_advance:
		sensor.trigger(null)

func update_position():
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
