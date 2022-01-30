class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var target
var trainname
var facing: int = 1
var VirtualTrainScene = load("res://layout/train/virtual_train.tscn")
var selected=false
var fixed_facing=false
var next_sensor_track

var TrainInspector = preload("res://layout/train/layout_train_inspector.tscn")

signal removing(p_name)
signal selected()
signal unselected()

func _init(p_name):
	trainname = p_name
	name = "train_"+trainname
	virtual_train = VirtualTrainScene.instance()
	add_child(virtual_train)
	virtual_train.connect("hover", self, "_on_virtual_train_hover")
	virtual_train.connect("clicked", self, "_on_virtual_train_clicked")
	virtual_train.visible=false
	LayoutInfo.connect("control_devices_changed", self, "_on_LayoutInfo_control_devices_changed")
	LayoutInfo.connect("blocked_tracks_changed", self, "_on_LayoutInfo_blocked_tracks_changed")

func can_control_ble_train():
	return LayoutInfo.control_devices and ble_train != null and ble_train.hub.running

func set_ble_train(trainname):
	if ble_train != null:
		ble_train.disconnect("handled_marker", self, "_on_ble_train_handled_marker")
		ble_train.disconnect("unexpected_marker", self, "_on_ble_train_unexpected_marker")
	if trainname == null:
		ble_train = null
		return
	ble_train = Devices.trains[trainname]
	ble_train.connect("handled_marker", self, "_on_ble_train_handled_marker")
	ble_train.connect("unexpected_marker", self, "_on_ble_train_unexpected_marker")
	update_control_ble_train()

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

func _on_ble_train_handled_marker(colorname):
	assert(colorname==next_sensor_track.track.sensor.get_colorname())
	next_sensor_track.track.sensor.trigger()

func _on_ble_train_unexpected_marker(colorname):
	if ble_train.state == "stopped":
		return
	if colorname==next_sensor_track.track.sensor.get_colorname():
		if virtual_train.expect_behaviour == "stop":
			ble_train.stop()
		if virtual_train.expect_behaviour == "slow":
			ble_train.slow()
		if virtual_train.expect_behaviour == "flip_heading":
			ble_train.flip_heading()
		next_sensor_track.track.sensor.trigger()
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
	set_route(_route)
	try_advancing()

func try_advancing():
	if route.is_train_blocked(trainname):
		route.recalculate_route(fixed_facing, trainname)
	if not route.is_train_blocked(trainname):
		if route.advance_leg()==null: # final target arrived
			set_route(null)
		else:
			start_leg()

func set_route(p_route):
	if route != null:
		route.decrement_marks()
	route = p_route
	if route != null:
		route.increment_marks()

func start_leg():
	var leg = route.get_current_leg()
	if not is_leg_allowed(leg):
		set_route(null)
		return
	leg.lock_tracks(trainname)
	if leg.get_type() == "flip":
		flip_heading()
	else:
		leg.set_switches()
	set_target(leg.get_target().obj)
	
	set_next_sensor()
	
	start()
	
func set_expect_marker(marker, behaviour):
	virtual_train.set_expect_marker(marker, behaviour)
	if can_control_ble_train():
		ble_train.set_expect_marker(marker, behaviour)

func set_target(p_block):
	if target!=null:
		# prints("disconnecting target:", target.id)
		target.disconnect("train_entered", self, "_on_target_train_entered")
		target.disconnect("train_in", self, "_on_target_train_in")
	target = p_block
	if target != null:
		# prints("connecting target:", target.id)
		# connect signals deferred, so they don't get retriggered within this frame if it happens to be the same sensor as the one that triggered this method call
		target.call_deferred("connect", "train_entered", self, "_on_target_train_entered")
		target.call_deferred("connect", "train_in", self, "_on_target_train_in")

func set_next_sensor():
	if next_sensor_track != null:
		next_sensor_track.track.sensor.disconnect("triggered", self, "_on_next_sensor_triggered")

	virtual_train.update_next_sensor_info()
	next_sensor_track = virtual_train.next_sensor_track

	if next_sensor_track != null:
		next_sensor_track.track.sensor.connect("triggered", self, "_on_next_sensor_triggered")
		var next_colorname = next_sensor_track.track.sensor.get_colorname()
		
		if next_sensor_track == target.sensors["enter"]:
			if route.can_train_pass(trainname):
				set_expect_marker(next_colorname, "ignore")
			else:
				set_expect_marker(next_colorname, "slow")
		elif next_sensor_track == target.sensors["in"]:
			if route.can_train_pass(trainname) and not route.is_train_blocked(trainname):
				set_expect_marker(next_colorname, "ignore")
			else:
				set_expect_marker(next_colorname, "stop")

func is_leg_allowed(leg):
	var leg_locked = leg.get_locked()
	if len(leg_locked)>0 and leg_locked != [trainname]:
		return false
	return true

func _on_next_sensor_triggered(p_train):
	if p_train != null:
		assert(p_train==self)
	
	if not virtual_train.allow_sensor_advance:
		virtual_train.advance_to_next_sensor_track()
	
	if next_sensor_track == target.sensors["enter"]:
		_on_target_entered()
	
	if next_sensor_track == target.sensors["in"]:
		_on_target_in()
	
	elif target != null:
		set_next_sensor()
	else:
		next_sensor_track = null
		next_sensor_track.track.sensor.disconnect("triggered", self, "_on_next_sensor_triggered")
	
func _on_target_in():
	route.get_current_leg().unlock_tracks()
	set_current_block(target, false)
	set_target(null)
	try_advancing()
	LayoutInfo.emit_signal("blocked_tracks_changed", trainname)

func _on_target_entered():
	var passing = route.can_train_pass(trainname)
	if route.is_train_blocked(trainname):
		route.recalculate_route(fixed_facing, trainname)
		if passing and (not route.can_train_pass(trainname) or route.is_train_blocked(trainname)):
			slow()
			passing=false
	if passing:
		route.switch_and_lock_next(trainname)

func _on_target_train_entered(p_train):
	if p_train != null:
		assert(p_train==self)

func _on_target_train_in(p_train):
	if p_train != null:
		assert(p_train==self)

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
	if block != null:
		block.set_occupied(false, self)
	block = p_block
	if block != null:
		block.set_occupied(true, self)
		virtual_train.visible=true
		if teleport:
			virtual_train.set_dirtrack(block.sensors["in"])
	else:
		virtual_train.visible=false

func flip_heading():
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
	set_current_block(null)
	emit_signal("removing", trainname)
	queue_free()

func get_inspector():
	var inspector = TrainInspector.instance()
	inspector.set_train(self)
	return inspector
