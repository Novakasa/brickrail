class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var target
var trainname
var facing: int = 1
var VirtualTrainScene = load("res://virtual_train.tscn")
var selected=false
var fixed_facing=false
var next_sensor_track

var TrainInspector = preload("res://layout_train_inspector.tscn")

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

func can_control_ble_train():
	return LayoutInfo.control_devices and ble_train != null and ble_train.hub.running

func set_ble_train(trainname):
	if ble_train != null:
		ble_train.disconnect("handled_marker", self, "_on_ble_train_handled_marker")
	if trainname == null:
		ble_train = null
		return
	ble_train = Devices.trains[trainname]
	ble_train.connect("handled_marker", self, "_on_ble_train_handled_marker")
	update_control_ble_train()

func _on_ble_train_handled_marker(colorname):
	assert(colorname==next_sensor_track.track.sensor.get_colorname())
	next_sensor_track.track.sensor.trigger()

func _on_LayoutInfo_control_devices_changed(control_devices):
	update_control_ble_train()

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

func find_route(target):
	var route = block.get_route_to(facing, target, fixed_facing)
	if route == null:
		push_error("no route to selected target "+target)
	else:
		set_route(route)
		start_leg()

func set_route(p_route):
	route = p_route

func start_leg():
	var leg = route.get_current_leg()
	if leg.get_type() == "flip":
		flip_heading()
	else:
		leg.set_switches()
	set_target(leg.get_target().obj)
	
	set_next_sensor()
	
	virtual_train.start()
	if can_control_ble_train():
		ble_train.start()
	
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
			if route.get_next_leg()!=null and route.get_next_leg().get_type()=="travel":
				set_expect_marker(next_colorname, "ignore")
			else:
				set_expect_marker(next_colorname, "slow")
		elif next_sensor_track == target.sensors["in"]:
			if route.get_next_leg()!=null and route.get_next_leg().get_type()=="travel":
				route.get_next_leg().set_switches()
				set_expect_marker(next_colorname, "ignore")
			else:
				set_expect_marker(next_colorname, "stop")

func _on_next_sensor_triggered(p_train):
	if p_train != null:
		assert(p_train==self)
	
	if not virtual_train.allow_sensor_advance:
		virtual_train.advance_to_next_sensor_track()
	
	if next_sensor_track == target.sensors["in"]:
		set_current_block(target, false)
		set_target(null)
	
		if route.advance_leg()==null:
			set_route(null)
		else:
			start_leg()
	
	elif target != null:
		set_next_sensor()

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
	block.set_occupied(true, self)
	virtual_train.visible=true
	if teleport:
		virtual_train.set_dirtrack(block.sensors["in"])

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
	emit_signal("removing", trainname)
	queue_free()

func get_inspector():
	var inspector = TrainInspector.instance()
	inspector.set_train(self)
	return inspector
