
class_name VirtualTrain
extends Node2D

var velocity = 0.0
var acceleration = 1.5
var deceleration = 3.0

var hover=false
var selected=false

var dirtrack
var turn=null
var length = 0.0
var track_pos = 0.0

var size = Vector2(0.3,0.2)
var facing: int = 1
var max_velocity = 3.0
var slow_velocity = 1.0

var trainname
var logging_module

var route: LayoutRoute = null

var allow_sensor_advance = true
var prev_sensor_track = null
var next_sensor_track = null
var next_sensor_distance = 0.0

var seek_forward_timer = -1.0
var seek_forward_amount = 0.0

var state = "stopped"

var wagons = []
var opposite_turn_history = []

export(Color) var color
export(Color) var accent_color
export(Color) var hover_color
export(Color) var selected_color = Color.black

signal marker(marker)

func seek_curve(t):
	# return t
	
	return t*t*(1.0-t) + (1.0-(1.0-t)*(1.0-t))*t
	
	return 1.0-(1.0-t)*(1.0-t)

func get_seek_offset(delta):
	if seek_forward_timer < 0.0:
		return 0.0
	seek_forward_timer -= delta
	var t = 1.0 - seek_forward_timer
	var curve_delta = seek_curve(t) - seek_curve(t - delta)
	return curve_delta*seek_forward_amount

func _ready():
	_on_settings_colors_changed()
	Settings.connect("colors_changed", self, "_on_settings_colors_changed")
	
	for i in range(4):
		wagons.append(VirtualTrainWagon.new())
		get_parent().call_deferred("add_child", wagons[-1])
		wagons[-1].set_color(color)
		wagons[-1].set_heading(0)
		wagons[-1].set_facing(0)
	
	update_wagon_visuals()
	
	connect("visibility_changed", self, "_on_visibility_changed")

func remove():
	for wagon in wagons:
		wagon.queue_free()
	queue_free()

func _on_visibility_changed():
	for wagon in wagons:
		wagon.visible = visible

func _on_settings_colors_changed():
	color = Settings.colors["primary"]*1.5
	selected_color = Settings.colors["tertiary"]

func has_point(pos):
	for wagon in wagons:
		if wagon.has_point(pos):
			return true
	return false

func set_facing(p_facing):
	facing = p_facing
	update_wagon_visuals()

func set_route(p_route):
	route = p_route

func advance_route():
	prints("virtual train advancing!", trainname)
	execute_behavior(route.advance())
	update_next_sensor_info()

func update_next_sensor_info():
	prev_sensor_track = next_sensor_track
	next_sensor_track = route.get_next_sensor_track()
	if next_sensor_track == null:
		next_sensor_distance = 0.0
		return
	var itertrack = dirtrack.get_next()
	if track_pos < 0.0:
		itertrack = dirtrack
	var distance = length - track_pos
	prints("measuring distance to next sensor track:", next_sensor_track.id)
	prints("starting at:", itertrack.id)
	var i = 0
	while itertrack != next_sensor_track:
		assert(i<1000)
		var next_turn = itertrack.get_next_turn()
		if next_turn == null:
			next_sensor_track = null
			next_sensor_distance = 0.0
			return
		distance += itertrack.get_length_to(next_turn)
		itertrack = itertrack.get_next(next_turn)
		i+=1
	next_sensor_distance = distance

func manual_sensor_advance():
	assert(state != "stopped")
	if allow_sensor_advance:
		return
	var flips = route.next_sensor_flips()
	prints("next sensor flips:", flips)
	if flips:
		advance_position(next_sensor_distance + 1.0)
	else:
		seek_forward_timer = 1.0
		seek_forward_amount = next_sensor_distance
	pass_sensor(next_sensor_track)

func cruise():
	Logger.verbose("cruise()", logging_module)
	set_state("started")

func slow():
	Logger.verbose("slow()", logging_module)
	set_state("slow")

func stop():
	Logger.verbose("stop()", logging_module)
	set_state("stopped")

func flip_heading():
	Logger.verbose("flip_heading()", logging_module)
	var prev_pos = track_pos
	if turn == null:
		set_dirtrack(dirtrack.get_opposite())
		track_pos = -prev_pos
	else:
		set_dirtrack(dirtrack.get_next(turn).get_opposite())
		track_pos = length-prev_pos
	set_facing(facing*-1)
	opposite_turn_history = []
	velocity = 0.0
	prev_sensor_track = null
	next_sensor_track = null
	next_sensor_distance = 0.0
	update_position()

func set_state(p_state):
	state = p_state

func _process(delta):
	delta *= LayoutInfo.time_scale
	update_velocity(delta)

func update_velocity(delta):
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
	var distance_offset = 0.0
	if not allow_sensor_advance:
		distance_modulation = min(next_sensor_distance/1.0, 1.0)
		distance_offset = get_seek_offset(delta*3)
	var delta_pos = velocity*delta*distance_modulation + distance_offset
	advance_position(delta_pos)

func advance_position(delta_pos):
	var prev_pos = track_pos
	track_pos += delta_pos
	next_sensor_distance -= delta_pos
	wrap_dirtrack()
	if prev_pos<0.0 and track_pos>0.0:
		if dirtrack.get_sensor() != null and allow_sensor_advance:
			pass_sensor(dirtrack)
	update_position()

func wrap_dirtrack():
	while track_pos > length:
		if not allow_sensor_advance:
			prints(next_sensor_distance, velocity)
		track_pos -= length
		set_dirtrack(dirtrack.get_next(turn))
		var next_dirtrack = dirtrack.get_next(turn)
		var opposite_turn = next_dirtrack.get_opposite().get_turn_to(dirtrack.get_opposite())
		opposite_turn_history.push_front(opposite_turn)
		if len(opposite_turn_history)>10:
			opposite_turn_history.pop_back()
		# print(opposite_turn_history)
		if dirtrack.get_sensor() != null and allow_sensor_advance:
			pass_sensor(dirtrack)

func pass_sensor(sensor_dirtrack):
	prints("virtual train pass sensor", sensor_dirtrack.id, trainname)
	execute_behavior(route.advance_sensor(sensor_dirtrack))
	
	update_next_sensor_info()

func execute_behavior(behavior):
	prints("virtual train executing:", behavior, trainname)
	if behavior == "ignore":
		return
	if behavior == "cruise":
		cruise()
	if behavior == "slow":
		slow()
	if behavior == "stop":
		stop()
	if behavior == "flip_cruise":
		flip_heading()
		cruise()
	if behavior == "flip_slow":
		flip_heading()
		slow()

func update_position():
	var interpolation = dirtrack.interpolate(track_pos, turn)
	position = dirtrack.to_world(interpolation.position)
	rotation = interpolation.rotation
	
	update_wagon_position()

func update_wagon_position():
	for i in range(len(wagons)):
		var wagon = wagons[i]
		var wagon_pos = 0.52*i
		var interpolation
		var wagon_dirtrack
		if facing>0:
			wagon_pos += (length - track_pos)
			wagon_dirtrack = dirtrack.get_next(turn).get_opposite()
			interpolation = wagon_dirtrack.interpolate_world(wagon_pos, opposite_turn_history)
		else:
			wagon_pos += track_pos
			interpolation = dirtrack.interpolate_world(wagon_pos)
			
		wagon.position = interpolation.position
		wagon.rotation = interpolation.rotation + PI

func set_selected(p_selected):
	selected = p_selected
	prints("selected", selected, selected_color, color)
	update_wagon_visuals()

func set_hover(p_hover):
	hover = p_hover
	update_wagon_visuals()

func update_wagon_visuals():
	var wagon_color
	if selected:
		wagon_color = selected_color
	else:
		wagon_color = color
	if hover:
		wagon_color = wagon_color*1.7
	for wagon in wagons:
		wagon.set_color(wagon_color)
		wagon.set_facing(0)
		wagon.set_heading(0)
	
	wagons[0].set_facing(1)
	if facing == 1:
		wagons[0].set_heading(1)
		wagons[-1].set_heading(0)
	else:
		wagons[0].set_heading(0)
		wagons[-1].set_heading(-1)

func set_dirtrack(p_dirtrack, teleport=false):
	dirtrack = p_dirtrack
	turn = dirtrack.get_next_turn()
	length = dirtrack.get_length_to(turn)
	position = dirtrack.get_position()+LayoutInfo.spacing*dirtrack.get_center()
	rotation = dirtrack.get_rotation()
