class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var target_block
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
	virtual_train.visible=false
	LayoutInfo.connect("control_devices_changed", self, "_on_LayoutInfo_control_devices_changed")
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
	push_error("unexpected marker not aligned with next sensor")
	ble_train.stop()

func _on_LayoutInfo_control_devices_changed(control_devices):
	update_control_ble_train()

func is_end_of_leg():
	return block == route.get_current_leg().get_target_node().obj

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
	if route != null:
		if not route.highlighted:
			route.set_highlight()
	emit_signal("selected")

func unselect():
	selected=false
	virtual_train.set_selected(false)
	if route != null:
		if route.highlighted:
			route.clear_highlight()
	emit_signal("unselected")

func has_point(point):
	return virtual_train.has_point(point)

func hover_at(mpos):
	virtual_train.set_hover(true)
	if route != null:
		if not route.highlighted:
			route.set_highlight()

func stop_hover():
	virtual_train.set_hover(false)
	if route != null and not selected:
		if route.highlighted:
			route.clear_highlight()

func process_mouse_button(event, mpos):
	# prints("train:", trainname)
	if event.button_index == BUTTON_LEFT:
		if LayoutInfo.input_mode == "select":
			if not selected:
				select()
		if LayoutInfo.input_mode == "control":
			LayoutInfo.init_drag_train(self)

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

func try_advancing():
	if route.can_advance():
		if can_control_ble_train():
			ble_train.advance_route()
		virtual_train.advance_route()
		return

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

func set_route(p_route):
	if route != null:
		route.disconnect("target_entered", self, "_on_target_entered")
		route.disconnect("target_in", self, "_on_target_in")
		route.disconnect("completed", self, "_on_route_completed")
		route.disconnect("blocked", self, "_on_route_blocked")
		route.disconnect("stopped", self, "_on_route_stopped")
		route.disconnect("can_advance", self, "_on_route_can_advance")
		route.disconnect("facing_flipped", self, "_on_route_facing_flipped")
		route.set_trainname(null)
	route = p_route
	if route != null:
		route.connect("target_entered", self, "_on_target_entered")
		route.connect("target_in", self, "_on_target_in")
		route.connect("completed", self, "_on_route_completed")
		route.connect("blocked", self, "_on_route_blocked")
		route.connect("stopped", self, "_on_route_stopped")
		route.connect("can_advance", self, "_on_route_can_advance")
		route.connect("facing_flipped", self, "_on_route_facing_flipped")
		route.set_trainname(trainname)
		if can_control_ble_train():
			ble_train.set_route(route)
		virtual_train.set_route(route)
		if selected:
			route.set_highlight()

func _on_route_completed():
	set_route(null)
	if LayoutInfo.random_targets:
		wait_timer.start()
		yield(wait_timer, "timeout")
		if LayoutInfo.random_targets:
			find_random_route()

func _on_route_stopped():
	prints("blocked, committed=", committed)
	if not committed and not is_there_hope() and LayoutInfo.random_targets:
		print("no hope, new route!")
		find_random_route()

func _on_route_facing_flipped(p_facing):
	assert(p_facing != facing)
	facing = p_facing

func _on_route_can_advance():
	try_advancing()

func _on_target_entered(target_node):
	pass

func _on_target_in(target_node):
	set_current_block(target_node.obj, false)

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
	virtual_train.remove()
	set_route(null)
	set_current_block(null)
	emit_signal("removing", trainname)
	queue_free()

func get_inspector():
	var inspector = TrainInspector.instance()
	inspector.set_train(self)
	return inspector

func _process(_delta):
	wait_timer.wait_time = 1.0/LayoutInfo.time_scale
