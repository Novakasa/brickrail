
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
var l_idx = 0

var size = Vector2(0.3,0.2)
var facing: int = 1

var fast_velocity = 5.0
var cruise_velocity = 3.0
var slow_velocity = 1.0

var train_id
var logging_module

var route: LayoutRoute = null

var allow_sensor_advance = true
var prev_sensor_track = null
var next_sensor_track = null
var next_sensor_distance = 0.0

var seek_forward_timer = -1.0
var seek_forward_amount = 0.0
var seek_forward_dirtrack = null

var state = "stopped"

var wagons = []
var opposite_turn_history = []

@export var color: Color
@export var body_color: Color
@export var accent_color: Color
@export var hover_color: Color
@export var selected_color: Color = Color.BLACK

signal switched_layers(new_l_idx)

func seek_curve(t):
	# return t
	
	return t*t*(1.0-t) + (1.0-(1.0-t)*(1.0-t))*t
	
	# return 1.0-(1.0-t)*(1.0-t)

func get_seek_offset(delta):
	if seek_forward_timer < 0.0:
		return 0.0
	seek_forward_timer -= delta
	if seek_forward_timer < 0.0:
		# make sure to be after seek_dirtrack
		cleanup_seek()
		return 0.0
	var t = 1.0 - seek_forward_timer
	var curve_delta = seek_curve(t) - seek_curve(t - delta)
	return curve_delta*seek_forward_amount

func cleanup_seek():
	set_dirtrack(seek_forward_dirtrack, true)
	track_pos = 0.0
	update_next_sensor_distance()
	seek_forward_timer = -1.0

func _init(p_name):
	train_id = p_name
	logging_module = "virtual-" + train_id
	var _err = Settings.connect("colors_changed", Callable(self, "_on_settings_colors_changed"))
	
	add_wagons(4)
	
	_err = connect("visibility_changed", Callable(self, "_on_visibility_changed"))

func _ready():
	_on_settings_colors_changed()
	update_wagon_visuals()

func add_wagons(num_wagons):
	for wagon in wagons:
		remove_child(wagon)
		wagon.queue_free()
	wagons = []
	for _i in range(num_wagons):
		wagons.append(VirtualTrainWagon.new())
		add_child(wagons[-1])
		wagons[-1].set_body_color(body_color)
		wagons[-1].set_heading(0)
		wagons[-1].set_facing(0)

func set_num_wagons(num_wagons):
	add_wagons(num_wagons)
	if train_id != "drag-train":
		LayoutInfo.set_layout_changed(true)
	update_wagon_visuals()

func set_color(p_color):
	color = p_color
	for wagon in wagons:
		wagon.set_color(color)
	if train_id != "drag-train":
		LayoutInfo.set_layout_changed(true)

func remove():
	for wagon in wagons:
		wagon.queue_free()
	queue_free()

func _on_visibility_changed():
	for wagon in wagons:
		wagon.visible = visible

func _on_settings_colors_changed():
	body_color = Settings.colors["secondary"]*1.5
	selected_color = Settings.colors["tertiary"]
	update_wagon_visuals()

func has_point(pos):
	for wagon in wagons:
		if wagon.has_point(pos):
			return true
	return false

func set_facing(p_facing):
	facing = p_facing
	update_wagon_visuals()

func set_route(p_route):
	if route != null:
		route.disconnect("execute_behavior", Callable(self, "execute_behavior"))
	route = p_route
	if route != null:
		var _err = route.connect("execute_behavior", Callable(self, "execute_behavior"))

func advance_route():
	if seek_forward_timer >= 0.0:
		cleanup_seek()
	Logger.info("[%s] advancing!", logging_module)
	route.advance()
	update_next_sensor_info()

func update_next_sensor_info():
	prev_sensor_track = next_sensor_track
	next_sensor_track = route.get_next_sensor_track()
	update_next_sensor_distance()

func update_next_sensor_distance():
	if next_sensor_track == null:
		next_sensor_distance = 0.0
		return
	var itertrack = dirtrack.get_next()
	if track_pos < 0.0:
		itertrack = dirtrack
	var distance = length - track_pos
	Logger.debug("[%s] measuring distance to next sensor track: %s" % [logging_module, next_sensor_track.id])
	Logger.debug("[%s] starting at: %s" % [logging_module, itertrack.id])
	var i = 0
	while itertrack != next_sensor_track:
		if i>1000:
			GuiApi.show_error("Internal error, can't find next sensor track")
			assert(false, "can't find next sensor track")
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
	assert(state != "stopped", "sensor advance state == 'stopped'")
	if allow_sensor_advance:
		return
	var flips = route.next_sensor_flips()
	if flips:
		seek_forward_timer = -1.0
		set_dirtrack(next_sensor_track, true)
		track_pos = 0.0
	else:
		if seek_forward_timer >= 0.0:
			cleanup_seek()
		seek_forward_timer = 1.0
		seek_forward_amount = next_sensor_distance
		seek_forward_dirtrack = next_sensor_track
	pass_sensor(next_sensor_track)

func fast():
	Logger.info("[%s] fast()" % logging_module)
	set_state("fast")

func cruise():
	Logger.info("[%s] cruise()" % logging_module)
	set_state("cruise")

func slow():
	Logger.info("[%s] slow()" % logging_module)
	set_state("slow")

func stop():
	Logger.info("[%s] stop()" % logging_module)
	set_state("stopped")

func flip_heading():
	Logger.info("[%s] flip_heading()" % logging_module)
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
	if state == "fast":
		if velocity<fast_velocity:
			velocity = min(velocity+acceleration*delta, fast_velocity)
		else:
			velocity = max(velocity-deceleration*delta, fast_velocity)
	if state=="cruise":
		if velocity<cruise_velocity:
			velocity = min(velocity+acceleration*delta, cruise_velocity)
		else:
			velocity = max(velocity-deceleration*delta, cruise_velocity)
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
		if next_sensor_track != null:
			distance_modulation = min(next_sensor_distance/1.0, 1.0)
		distance_offset = get_seek_offset(delta*3)
	var delta_pos = velocity*delta*distance_modulation + distance_offset
	advance_position(delta_pos)

func advance_position(delta_pos):
	var prev_pos = track_pos
	assert(delta_pos>=0.0, "delta_pos < 0.0")
	track_pos += delta_pos
	next_sensor_distance -= delta_pos
	wrap_dirtrack()
	if prev_pos<0.0 and track_pos>0.0:
		if dirtrack.get_sensor() != null:
			if allow_sensor_advance:
				pass_sensor(dirtrack)
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
		if dirtrack == seek_forward_dirtrack:
			Logger.debug("[%s] resetting seek!" % [logging_module])
			seek_forward_timer = -1.0 # don't make seeking set dirtrack
		if dirtrack.get_sensor() != null:
			if allow_sensor_advance:
				pass_sensor(dirtrack)

func pass_sensor(sensor_dirtrack):
	Logger.info("[%s] pass sensor %s" % [logging_module, sensor_dirtrack.id])
	route.advance_sensor(sensor_dirtrack)
	
	update_next_sensor_info()

func execute_behavior(behavior: String):
	Logger.info("[%s] executing behavior: %s" % [logging_module, behavior])
	var parts = behavior.split("_")
	assert(len(parts)<=2, "len(parts) > 2")
	if parts[0] == "flip":
		flip_heading()
	if parts[-1] in ["stop", "slow", "cruise", "fast"]:
		call(parts[-1])

func update_position():
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
		
		if interpolation == null:
			wagon.visible = false
			wagon.position = Vector2(-1000.0, 0.0)
			continue
		
		wagon.visible = true
		wagon.position = interpolation.position
		wagon.rotation = interpolation.rotation + PI

func set_selected(p_selected):
	selected = p_selected
	update_wagon_visuals()

func set_hover(p_hover):
	hover = p_hover
	update_wagon_visuals()

func update_wagon_visuals():
	var wagon_color
	if selected:
		wagon_color = selected_color
	else:
		wagon_color = body_color
	if hover:
		wagon_color = wagon_color*1.7
	for wagon in wagons:
		wagon.set_body_color(wagon_color)
		wagon.set_facing(0)
		wagon.set_heading(0)
		wagon.set_color(color)
	
	wagons[0].set_facing(1)
	if facing == 1:
		wagons[0].set_heading(1)
		wagons[-1].set_heading(0)
	else:
		wagons[0].set_heading(0)
		wagons[-1].set_heading(-1)

func set_dirtrack(p_dirtrack, teleport=false):
	var prev_l_idx = l_idx
	dirtrack = p_dirtrack
	l_idx = dirtrack.l_idx
	if l_idx != prev_l_idx:
		emit_signal("switched_layers", l_idx)
	turn = dirtrack.get_next_turn()
	length = dirtrack.get_length_to(turn)
	if teleport:
		opposite_turn_history = []
		emit_signal("switched_layers", l_idx)
