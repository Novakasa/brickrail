class_name LayoutTrain
extends Node2D

var ble_train: BLETrain
var virtual_train: VirtualTrain
var route
var home_position = {}
var block
var blocked_by
var trainname
var facing: int = 1
var VirtualTrainScene = load("res://layout/train/virtual_train.tscn")
var selected=false
var reversing_behavior = "off"
var committed = true
var logging_module
var wait_time = 2.0

var TrainInspector = preload("res://layout/train/layout_train_inspector.tscn")

signal removing(p_name)
signal selected()
signal unselected()
signal ble_train_changed()
signal route_changed()
signal home_position_changed(home_pos_dict)

func _init(p_name):
	trainname = p_name
	logging_module = trainname
	name = "train_"+trainname
	virtual_train = VirtualTrain.new(trainname)
	add_child(virtual_train)
	virtual_train.visible=false
	var _err = virtual_train.connect("switched_layers", self, "_on_virtual_train_switched_layer")
	_err = LayoutInfo.connect("control_devices_changed", self, "_on_LayoutInfo_control_devices_changed")
	_err = LayoutInfo.connect("random_targets_set", self, "_on_LayoutInfo_random_targets_set")
	_err = LayoutInfo.connect("active_layer_changed",self, "_on_layer_info_changed")
	_err = LayoutInfo.connect("layers_unfolded_changed", self, "_on_layer_info_changed")
	blocked_by = null
	update_layer_visibility()

func _enter_tree():
	if LayoutInfo.random_targets:
		yield(get_tree().create_timer(wait_time/LayoutInfo.time_scale), "timeout")
		if LayoutInfo.random_targets:
			find_random_route(false)

func _on_layer_info_changed(_l_idx=null):
	update_layer_visibility()

func _on_virtual_train_switched_layer(p_l_idx):
	if selected:
		LayoutInfo.set_active_layer(p_l_idx)
	
	update_layer_visibility()

func update_layer_visibility():
	
	var l_idx = virtual_train.l_idx
	
	if l_idx != LayoutInfo.active_layer and not LayoutInfo.layers_unfolded:
		modulate = Color(1.0, 1.0, 1.0, 0.3)
	else:
		modulate = Color.white

func can_control_ble_train():
	return LayoutInfo.control_devices==2 and ble_train != null and ble_train.hub.running

func set_ble_train(p_trainname):
	if ble_train != null:
		ble_train.disconnect("sensor_advance", self, "_on_ble_train_sensor_advance")
		ble_train.disconnect("removing", self, "_on_ble_train_removing")
	if p_trainname == null:
		ble_train = null
		emit_signal("ble_train_changed")
		return
	ble_train = Devices.trains[p_trainname]
	var _err = ble_train.connect("sensor_advance", self, "_on_ble_train_sensor_advance")
	_err = ble_train.connect("removing", self, "_on_ble_train_removing")
	LayoutInfo.set_layout_changed(true)
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

func _on_ble_train_sensor_advance(_colorname):
	if can_control_ble_train():
		virtual_train.manual_sensor_advance()

func _on_ble_train_unexpected_marker(_colorname):
	Logger.info("[%s] ble_train unexpected marker triggered" % trainname)
	Logger.error("unexpected marker not aligned with next sensor")
	ble_train.stop()

func _on_LayoutInfo_control_devices_changed(_control_devices):
	update_control_ble_train()

func is_end_of_leg():
	return route.get_current_leg().is_complete()

func _on_LayoutInfo_random_targets_set(random_targets):
	if random_targets and route==null:
		find_random_route(false)

func update_control_ble_train():
	if can_control_ble_train():
		virtual_train.allow_sensor_advance=false
		ble_train.stop()
		if ble_train.heading != facing:
			ble_train.flip_heading()
	else:
		virtual_train.allow_sensor_advance=true
		if ble_train != null and ble_train.hub.running and Devices.get_ble_communicator().connected:
			ble_train.stop()
			ble_train.download_route(null)

func serialize():
	var struct = {}
	struct["name"] = trainname
	struct["facing"] = home_position.facing
	struct["reversing_behavior"] = reversing_behavior
	struct["color"] = virtual_train.color.to_html()
	struct["num_wagons"] = len(virtual_train.wagons)
	if block != null:
		struct["blockname"] = home_position.blockname
		struct["blockindex"] = home_position.index
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
	LayoutInfo.set_active_layer(virtual_train.l_idx)

func unselect():
	selected=false
	virtual_train.set_selected(false)
	if route != null:
		if route.highlighted:
			route.clear_highlight()
	emit_signal("unselected")

func has_point(point):
	return virtual_train.has_point(point)

func hover_at(_mpos):
	virtual_train.set_hover(true)
	if route != null:
		if not route.highlighted:
			route.set_highlight()

func stop_hover():
	virtual_train.set_hover(false)
	if route != null and not selected:
		if route.highlighted:
			route.clear_highlight()

func process_mouse_button(event, _mpos):
	if not event.pressed:
		return false
	if event.button_index == BUTTON_LEFT:
		if not selected:
			select()
			return true
	if event.button_index == BUTTON_RIGHT:
		if LayoutInfo.layout_mode == "control" and not LayoutInfo.control_enabled:
			return false
		LayoutInfo.init_drag_train(self)
		return true

func get_route_to(p_target, no_locked=true):
	var locked_trainname = trainname
	if not no_locked:
		locked_trainname = null
	return block.get_route_to(facing, p_target, reversing_behavior, locked_trainname)

func get_all_valid_routes(no_locked=true, target_facing=null):
	var locked_trainname = trainname
	if not no_locked:
		locked_trainname = null
	var routes = block.get_all_routes(facing, reversing_behavior, locked_trainname)
	var valid_routes = {}
	for node_id in routes:
		if routes[node_id] == null:
			continue
		if LayoutInfo.nodes[node_id].type!="block":
			continue
		if LayoutInfo.nodes[node_id].obj.blockname==block.blockname:
			continue
		if not LayoutInfo.nodes[node_id].obj.can_stop:
			continue
		if target_facing != null and target_facing != LayoutInfo.nodes[node_id].facing:
			continue
		valid_routes[node_id] = routes[node_id]
	return valid_routes

func find_random_route(no_blocked):
	Logger.info("[%s] finding new random route" % [logging_module])
	var target_facing = null
	if reversing_behavior == "penalty":
		target_facing = 1
		
	var valid_routes = get_all_valid_routes(no_blocked, target_facing)
	var valid_targets = valid_routes.keys()
	
	if len(valid_targets) == 0:
		Logger.info("[%s] couldn't find random route" % [logging_module])
		return false
	var random_target = valid_targets[randi()%len(valid_targets)]
	committed = false
	set_route(valid_routes[random_target])
	try_advancing()
	return true

func find_route(p_target, _no_locked=true):
	if route != null and not is_end_of_leg():
		GuiApi.show_error("Not at end of leg!")
		return
	if not LayoutInfo.nodes[p_target].obj.can_stop:
		GuiApi.show_error("Target is not flagged 'can stop'!")
		return
	var _route = get_route_to(p_target, true)
	if _route == null:
		_route = get_route_to(p_target, false)
		if _route == null:
			GuiApi.show_error("Route impossible or blocked by other train!")
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
	_on_route_stopped()

func escape_deadlock():
	Logger.debug("[%s] escape_deadlock called, blocked_by: %s" % [logging_module, blocked_by])
	# returns true if no deadlock present or some train found a new route, escaping the deadlock
	if route == null:
		return true
	if not is_end_of_leg():
		return true
	if blocked_by != null:
		if committed:
			return false
		Logger.debug("[%s] escape_deadlock, not commited, new route!" % [logging_module])
		return find_random_route(true)
	blocked_by = route.get_blocking_trains()
	for blocked_trainname in blocked_by:
		var train = LayoutInfo.trains[blocked_trainname]
		if train.escape_deadlock():
			blocked_by = null
			return true
	
	blocked_by = null
	if committed:
		return false
	Logger.debug("[%s] escape_deadlock, blocked trains can't relax, not commited, new route!" % [logging_module])
	return find_random_route(true)

func set_route(p_route):
	if route != null:
		route.disconnect("target_entered", self, "_on_target_entered")
		route.disconnect("target_in", self, "_on_target_in")
		route.disconnect("completed", self, "_on_route_completed")
		route.disconnect("stopped", self, "_on_route_stopped")
		route.disconnect("can_advance", self, "_on_route_can_advance")
		route.disconnect("facing_flipped", self, "_on_route_facing_flipped")
		route.set_trainname(null)
	route = p_route
	if route != null:
		route.connect("target_entered", self, "_on_target_entered")
		route.connect("target_in", self, "_on_target_in")
		route.connect("completed", self, "_on_route_completed")
		route.connect("stopped", self, "_on_route_stopped")
		route.connect("can_advance", self, "_on_route_can_advance")
		route.connect("facing_flipped", self, "_on_route_facing_flipped")
		route.set_trainname(trainname)
		if can_control_ble_train():
			ble_train.set_route(route)
		virtual_train.set_route(route)
		if selected:
			route.set_highlight()
	emit_signal("route_changed")

func cancel_route():
	Logger.info("[%s] Cancelling route" % [logging_module])
	assert(route != null)
	if is_end_of_leg():
		set_route(null)
		return
	route.set_passing(false)
	yield(route, "stopped")
	yield(get_tree(),"idle_frame") #wait for stopped signal to be handled
	set_route(null)

func _on_route_completed():
	Logger.info("[%s] Route completed" % [logging_module])
	set_route(null)
	if LayoutInfo.random_targets:
		Logger.info("[%s] Starting timer for next route" % [logging_module])
		yield(get_tree().create_timer(wait_time/LayoutInfo.time_scale), "timeout")
		if LayoutInfo.random_targets:
			find_random_route(false)

func _on_route_stopped():
	Logger.info("[%s] route stopped" % logging_module)
	if not route.passing:
		return
	if LayoutInfo.random_targets:
		yield(get_tree(), "idle_frame")
		if not escape_deadlock():
			Logger.error("[%s] Couldn't escape deadlock!" % logging_module)
			push_error("couldn't escape deadlock! " + trainname)

func _on_route_facing_flipped(p_facing):
	assert(p_facing != facing)
	facing = p_facing

func _on_route_can_advance():
	try_advancing()

func _on_target_entered(_target_node):
	pass

func _on_target_in(target_node):
	set_current_block(target_node.obj, false)

func get_current_pos_dict():
	var pos_dict = {}
	pos_dict["blockname"] = block.blockname
	pos_dict["index"] = block.index
	pos_dict["facing"] = facing
	return pos_dict

func set_as_home():
	set_home_position(get_current_pos_dict())

func set_home_position(home_pos_dict):
	home_position = home_pos_dict.duplicate()
	emit_signal("home_position_changed", home_position)
	LayoutInfo.set_layout_changed(true)

func reset_to_home_position():
	reset_to_position(home_position)
	
func reset_to_position(pos_dict):
	var logical_block = LayoutInfo.blocks[pos_dict.blockname].logical_blocks[pos_dict.index]
	set_facing(pos_dict.facing)
	set_current_block(logical_block, true)

func go_home():
	Logger.info("[%s] go_home()" % [logging_module])
	var logical_block = LayoutInfo.blocks[home_position.blockname].logical_blocks[home_position.index]
	var node_id = logical_block.nodes[home_position.facing].id
	find_route(node_id)

func set_current_block(p_block, teleport=true):
	if p_block != null:
		Logger.info("[%s] set_current_block(%s)" % [trainname, p_block.id])
	if block != null:
		block.set_occupied(false, self)
	block = p_block
	if block != null:
		assert(not block.occupied)
		block.set_occupied(true, self)
		virtual_train.visible=true
		if len(home_position) == 0:
			set_as_home()
		if teleport:
			virtual_train.set_dirtrack(block.get_train_spawn_dirtrack(facing), true)
	else:
		virtual_train.visible=false

func flip_heading():
	Logger.info("[%s] flip_heading()" % trainname)
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

func set_reversing_behavior(p_behavior):
	if reversing_behavior != p_behavior:
		LayoutInfo.set_layout_changed(true)
		reversing_behavior = p_behavior

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

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_F3:
				if selected and route != null and virtual_train.state != "stopped":
					virtual_train.manual_sensor_advance()
