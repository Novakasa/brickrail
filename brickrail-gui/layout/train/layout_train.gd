class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var target
var blocked_by
var trainname
var facing: int = 1
var VirtualTrainScene = load("res://layout/train/virtual_train.tscn")
var selected=false
var fixed_facing=false
var next_sensor_track
var wait_timer: Timer
var committed = true
var logging_module

var TrainInspector = preload("res://layout/train/layout_train_inspector.tscn")

signal removing(p_name)
signal selected()
signal unselected()
signal ble_train_changed()

func _init(p_name):
	trainname = p_name
	logging_module = trainname
	name = "train_"+trainname
	virtual_train = VirtualTrainScene.instance()
	virtual_train.trainname = trainname
	virtual_train.logging_module = "virtual-"+trainname
	add_child(virtual_train)
	virtual_train.connect("hover", self, "_on_virtual_train_hover")
	virtual_train.connect("clicked", self, "_on_virtual_train_clicked")
	virtual_train.visible=false
	LayoutInfo.connect("control_devices_changed", self, "_on_LayoutInfo_control_devices_changed")
	LayoutInfo.connect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")
	LayoutInfo.connect("random_targets_set", self, "_on_LayoutInfo_random_targets_set")
	wait_timer = Timer.new()
	add_child(wait_timer)
	blocked_by = null

func _enter_tree():
	if LayoutInfo.random_targets:
		wait_timer.wait_time = 1.0/LayoutInfo.time_scale
		wait_timer.start()
		yield(get_tree().create_timer(wait_timer.wait_time/LayoutInfo.time_scale), "timeout")
		if LayoutInfo.random_targets:
			find_random_route()

func can_control_ble_train():
	return LayoutInfo.control_devices and ble_train != null and ble_train.hub.running

func set_ble_train(trainname):
	if ble_train != null:
		ble_train.disconnect("handled_marker", self, "_on_ble_train_handled_marker")
		ble_train.disconnect("unexpected_marker", self, "_on_ble_train_unexpected_marker")
		ble_train.disconnect("removing", self, "_on_ble_train_removing")
	if trainname == null:
		ble_train = null
		emit_signal("ble_train_changed")
		return
	ble_train = Devices.trains[trainname]
	ble_train.connect("handled_marker", self, "_on_ble_train_handled_marker")
	ble_train.connect("unexpected_marker", self, "_on_ble_train_unexpected_marker")
	ble_train.connect("removing", self, "_on_ble_train_removing")
	update_control_ble_train()
	emit_signal("ble_train_changed")

func slow():
	virtual_train.slow()
	if can_control_ble_train():
		ble_train.slow()

func stop():
	virtual_train.stop()
	if can_control_ble_train():
		ble_train.stop()

func start():
	virtual_train.start()
	if can_control_ble_train():
		ble_train.start()

func _on_ble_train_removing(_name):
	set_ble_train(null)

func _on_ble_train_handled_marker(colorname):
	assert(colorname==next_sensor_track.get_sensor().get_colorname())
	next_sensor_track.get_sensor().trigger()

func _on_ble_train_unexpected_marker(colorname):
	Logger.verbose("ble_train unexpected marker triggered", logging_module)
	if ble_train.state == "stopped":
		return
	if colorname==next_sensor_track.get_sensor().get_colorname():
		if virtual_train.expect_behaviour == "stop":
			ble_train.stop()
		if virtual_train.expect_behaviour == "slow":
			ble_train.slow()
		if virtual_train.expect_behaviour == "flip_heading":
			ble_train.flip_heading()
		next_sensor_track.get_sensor().trigger()
	else:
		push_error("unexpected marker not aligned with next sensor")
		ble_train.stop()
		ble_train.hub.rpc("queue_dump_buffers", [])

func _on_LayoutInfo_control_devices_changed(control_devices):
	update_control_ble_train()

func is_end_of_leg():
	return block == route.get_current_leg().get_target().obj

func _on_LayoutInfo_blocked_tracks_changed(p_trainname):
	if p_trainname == trainname:
		return
	if route == null:
		return
	if is_end_of_leg():
		try_advancing()

func _on_LayoutInfo_random_targets_set(random_targets):
	if random_targets and route==null:
		find_random_route()

func update_control_ble_train():
	if can_control_ble_train():
		virtual_train.allow_sensor_advance=false
	else:
		virtual_train.allow_sensor_advance=true
		if ble_train != null and ble_train.hub.running:
			ble_train.stop()

func serialize():
	var struct = {}
	struct["name"] = trainname
	struct["facing"] = facing
	struct["fixed_facing"] = fixed_facing
	if block != null:
		struct["blockname"] = block.blockname
		struct["blockindex"] = block.index
	if ble_train != null:
		struct["ble_train"] = ble_train.name
	return struct

func select():
	selected=true
	LayoutInfo.select(self)
	virtual_train.set_selected(true)
	emit_signal("selected")

func unselect():
	selected=false
	virtual_train.set_selected(false)
	emit_signal("unselected")

func _on_virtual_train_hover():
	virtual_train.set_hover(true)

func get_route_to(p_target, no_locked=true):
	var locked_trainname = trainname
	if not no_locked:
		locked_trainname = null
	return block.get_route_to(facing, p_target, fixed_facing, locked_trainname)

func get_all_valid_routes(no_locked=true):
	var locked_trainname = trainname
	if not no_locked:
		locked_trainname = null
	var routes = block.get_all_routes(facing, fixed_facing, locked_trainname)
	var valid_routes = {}
	for node_id in routes:
		if routes[node_id] == null:
			continue
		if LayoutInfo.nodes[node_id].type!="block":
			continue
		if LayoutInfo.nodes[node_id].obj.blockname==block.blockname:
			continue
		valid_routes[node_id] = routes[node_id]
	return valid_routes

func find_random_route():
	var valid_routes = get_all_valid_routes(true)
	var valid_targets = valid_routes.keys()
	
	if len(valid_targets) == 0:
		valid_routes = get_all_valid_routes(false)
		valid_targets = valid_routes.keys()
	if len(valid_targets) == 0:
		push_error("no route available")
		return
	var random_target = valid_targets[randi()%len(valid_targets)]
	committed = false
	set_route(valid_routes[random_target])
	try_advancing()

func find_route(p_target, no_locked=true):
	if route != null and not is_end_of_leg():
		push_error("Not at end of leg!")
		return
	var _route = get_route_to(p_target, true)
	if _route == null:
		_route = get_route_to(p_target, false)
		if _route == null:
			push_error("no route to target")
			return
	committed = true
	set_route(_route)
	try_advancing()

func is_there_hope():
	if route == null:
		return true
	if not is_end_of_leg():
		return true
	if blocked_by != null:
		return false
	blocked_by = route.get_blocking_trains()
	for blocked_trainname in blocked_by:
		if blocked_trainname == trainname:
			continue
		var train = LayoutInfo.trains[blocked_trainname]
		if train.is_there_hope():
			blocked_by = null
			return true
	blocked_by = null
	return false

func try_advancing():
	Logger.verbose("try_advancing()", logging_module)
	if route.is_train_blocked(trainname):
		Logger.verbose("recalculating route", logging_module)
		route.recalculate_route(fixed_facing, trainname)
	if not route.is_train_blocked(trainname):
		if route.advance_leg()==null: # final target arrived
			Logger.verbose("final target arrived", logging_module)
			set_route(null)
			if LayoutInfo.random_targets:
				wait_timer.start()
				yield(wait_timer, "timeout")
				if LayoutInfo.random_targets:
					find_random_route()
		else:
			start_leg()
		return
	var hope = is_there_hope()
	if not hope:
		if LayoutInfo.random_targets and not committed:
			Logger.verbose("no hope for route, finding new one", logging_module)
			find_random_route() #FIXME: chance of infinite recursion 

func set_route(p_route):
	if route != null:
		route.decrement_marks()
	route = p_route
	if route != null:
		route.increment_marks()

func start_leg():
	Logger.verbose("start_leg()", logging_module)
	var leg = route.get_current_leg()
	Logger.verbose("from: "+leg.get_from().id, logging_module)
	Logger.verbose("to: "+leg.get_target().id, logging_module)
	Logger.verbose("leg type: "+leg.get_type(), logging_module)
	if not is_leg_allowed(leg):
		Logger.verbose("current leg not allowed, cancelling route", logging_module)
		set_route(null)
		return
	Logger.verbose("locking tracks", logging_module)
	leg.lock_tracks(trainname)
	if leg.get_type() == "flip":
		flip_heading()
		try_passing()
	else:
		Logger.verbose("setting switches", logging_module)
		leg.set_switches()
	set_target(leg.get_target().obj)
	
	set_next_sensor()
	
	start()
	Logger.verbose("start_leg() done", logging_module)
	
func set_expect_marker(marker, behaviour):
	Logger.verbose("set_expect_marker('"+marker+"', '"+behaviour+"')", logging_module)
	virtual_train.set_expect_marker(marker, behaviour)
	if can_control_ble_train():
		ble_train.set_expect_marker(marker, behaviour)

func set_target(p_block):
	target = p_block

func get_target_sensor_dirtrack(key):
	return target.nodes[facing].target.sensor_dirtracks[key]

func get_block_sensor_dirtrack(key):
	return block.nodes[facing].target.sensor_dirtracks[key]

func set_next_sensor():
	Logger.verbose("set_next_sensor()", trainname)
	if next_sensor_track != null:
		next_sensor_track.get_sensor().disconnect("triggered", self, "_on_next_sensor_triggered")
	
	virtual_train.update_next_sensor_info()
	next_sensor_track = virtual_train.next_sensor_track
	Logger.verbose("next_sensor_track: "+next_sensor_track.id, trainname)

	if next_sensor_track != null:
		next_sensor_track.get_sensor().connect("triggered", self, "_on_next_sensor_triggered")
		var next_colorname = next_sensor_track.get_sensor().get_colorname()
		
		if next_sensor_track == get_target_sensor_dirtrack("enter"):
			Logger.verbose("next sensor is target enter", trainname)
			if route.can_train_pass(trainname):
				set_expect_marker(next_colorname, "ignore")
				return
			set_expect_marker(next_colorname, "slow")
			return
		if next_sensor_track == get_target_sensor_dirtrack("in"):
			Logger.verbose("next sensor is target in", trainname)
			if route.can_train_pass(trainname) and not route.is_train_blocked(trainname):
				set_expect_marker(next_colorname, "ignore")
				return
			set_expect_marker(next_colorname, "stop")
			return
		Logger.verbose("next sensor will be ignored", trainname)
		set_expect_marker(next_colorname, "ignore")

func is_leg_allowed(leg):
	var leg_locked = leg.get_locked()
	if len(leg_locked)>0 and leg_locked != [trainname]:
		return false
	return true

func _on_next_sensor_triggered(p_train):
	Logger.verbose("next sensor triggered", trainname)
	if p_train != null:
		assert(p_train==self)
	
	if not virtual_train.allow_sensor_advance:
		virtual_train.advance_to_next_sensor_track()
	
	if next_sensor_track == get_target_sensor_dirtrack("enter"):
		Logger.verbose("triggered sensor is target enter", trainname)
		_on_target_entered()
	
	if next_sensor_track == get_target_sensor_dirtrack("in"):
		Logger.verbose("triggered sensor is target in", trainname)
		_on_target_in()
	
	elif target != null:
		set_next_sensor()
	else:
		next_sensor_track = null
		next_sensor_track.get_sensor().disconnect("triggered", self, "_on_next_sensor_triggered")
	
func _on_target_in():
	Logger.verbose("_on_target_in()", logging_module)
	Logger.verbose("unlocking tracks", logging_module)
	route.get_current_leg().unlock_tracks()
	set_current_block(target, false)
	set_target(null)
	try_advancing()
	LayoutInfo.emit_signal("blocked_tracks_changed", trainname)

func _on_target_entered():
	Logger.verbose("_on_target_entered()", logging_module)
	try_passing()

func try_passing():
	Logger.verbose("try_passing()", logging_module)
	var passing = route.can_train_pass(trainname)
	if route.is_train_blocked(trainname):
		Logger.verbose("route.is_train_blocked() true, recalculating route", logging_module)
		route.recalculate_route(fixed_facing, trainname)
		if passing and (not route.can_train_pass(trainname) or route.is_train_blocked(trainname)):
			Logger.verbose("still cannot pass, slowing!", logging_module)
			slow()
			passing=false
	if passing:
		Logger.verbose("passing, switch and lock tracks", logging_module)
		route.switch_and_lock_next(trainname)

func stop_hover():
	virtual_train.set_hover(false)

func _on_virtual_train_clicked(event):
	# prints("train:", trainname)
	if event.button_index == BUTTON_LEFT:
		if LayoutInfo.input_mode == "select":
			if not selected:
				select()
		if LayoutInfo.input_mode == "control":
			LayoutInfo.init_drag_train(self)
	
func set_current_block(p_block, teleport=true):
	if p_block != null:
		Logger.verbose("set_current_block("+p_block.id+")", logging_module)
	if block != null:
		block.set_occupied(false, self)
	block = p_block
	if block != null:
		block.set_occupied(true, self)
		virtual_train.visible=true
		if teleport:
			virtual_train.set_dirtrack(block.get_train_spawn_dirtrack(facing))
	else:
		virtual_train.visible=false

func flip_heading():
	Logger.verbose("flip_heading()", logging_module)
	virtual_train.flip_heading()
	if can_control_ble_train():
		ble_train.flip_heading()
	flip_facing()

func flip_facing():
	facing *= -1
	virtual_train.set_facing(facing)

func set_facing(p_facing):
	facing = p_facing
	virtual_train.set_facing(facing)

func remove():
	unselect()
	virtual_train.set_process(false)
	set_current_block(null)
	emit_signal("removing", trainname)
	queue_free()

func get_inspector():
	var inspector = TrainInspector.instance()
	inspector.set_train(self)
	return inspector

func _process(_delta):
	wait_timer.wait_time = 1.0/LayoutInfo.time_scale
