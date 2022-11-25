
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
var slow_velocity = 1.0
var expect_marker = null
var expect_behaviour = null
var trainname
var logging_module

var allow_sensor_advance = true
var prev_sensor_track = null
var next_sensor_track = null
var next_sensor_distance = 0.0

var state = "stopped"

var wagons = []
var opposite_turn_history = []

export(Color) var color
export(Color) var accent_color
export(Color) var hover_color
export(Color) var selected_color = Color.black

signal hover()
signal stop_hover()
signal clicked(event)
signal marker(marker)

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
	var spacing = LayoutInfo.spacing
	var wsize = size*spacing
	wsize.x = wsize.x + wsize.y
	var hitbox = Rect2(-wsize*0.5, wsize)
	return hitbox.has_point(pos)

func set_facing(p_facing):
	facing = p_facing
	update_wagon_visuals()

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
	prev_sensor_track = next_sensor_track
	if prev_sensor_track == null:
		if track_pos<0.0:
			itertrack = dirtrack
		else:
			itertrack = dirtrack.get_next()
		distance = length - track_pos
	else:
		distance = next_sensor_distance + prev_sensor_track.get_connection_length()
		itertrack = prev_sensor_track.get_next()
	while itertrack.get_sensor()==null:
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
	pass_sensor(next_sensor_track.get_sensor())

func set_expect_marker(colorname, behaviour):
	expect_marker = colorname
	expect_behaviour = behaviour

func start():
	Logger.verbose("start()", logging_module)
	set_state("started")

func slow():
	Logger.verbose("slow()", logging_module)
	set_state("slow")

func stop():
	Logger.verbose("stop()", logging_module)
	set_state("stopped")

func flip_heading():
	Logger.verbose("flip_heading()", logging_module)
	if state!="stopped":
		push_error("can't flip heading while state is " + state)
		return
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
	var delta_pos = velocity*delta*distance_modulation
	advance_position(delta_pos)

func advance_position(delta_pos):
	var prev_pos = track_pos
	track_pos += delta_pos
	next_sensor_distance -= delta_pos
	wrap_dirtrack()
	if prev_pos<0.0 and track_pos>0.0:
		if dirtrack == next_sensor_track and allow_sensor_advance:
			var sensor = dirtrack.get_sensor()
			pass_sensor(sensor)
	update_position()

func wrap_dirtrack():
	while track_pos > length:
		track_pos -= length
		set_dirtrack(dirtrack.get_next(turn))
		var next_dirtrack = dirtrack.get_next(turn)
		var opposite_turn = next_dirtrack.get_opposite().get_turn_to(dirtrack.get_opposite())
		opposite_turn_history.push_front(opposite_turn)
		if len(opposite_turn_history)>10:
			opposite_turn_history.pop_back()
		# print(opposite_turn_history)
		if dirtrack == next_sensor_track and allow_sensor_advance:
			var sensor = dirtrack.get_sensor()
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

func set_dirtrack(p_dirtrack):
	dirtrack = p_dirtrack
	turn = dirtrack.get_next_turn()
	length = dirtrack.get_length_to(turn)
	position = dirtrack.get_position()+LayoutInfo.spacing*dirtrack.get_center()
	rotation = dirtrack.get_rotation()
