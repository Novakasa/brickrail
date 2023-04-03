class_name LayoutLogicalBlock
extends Node

var blockname
var id
var section
var occupied: bool
var train: LayoutTrain
var index: int
var nodes = {}
var selected = false
var _hover = false
var can_stop = true
var can_flip = true

var LayoutBlockInspector = preload("res://layout/block/layout_block_inspector.tscn")

#warning-ignore:unused_signal
signal removing(blockname)
signal selected()
signal unselected()

func _init(p_name, p_index):
	blockname = p_name
	index = p_index
	id = blockname + "_" + ["+", "-"][index]
	for facing in [1, -1]:
		nodes[facing] = LayoutNode.new(self, id, facing, "block")
		nodes[facing].set_sensors(LayoutNodeSensors.new())

func set_section(p_section):
	if section != null:
		section.disconnect("sensor_changed", self, "_on_section_sensor_changed")
	section = p_section
	section.connect("sensor_changed", self, "_on_section_sensor_changed")
	find_sensors()

func _on_section_sensor_changed():
	find_sensors()

func add_prior_sensor_dirtrack(dirtrack):
	if dirtrack.get_sensor() == null:
		dirtrack.add_sensor(LayoutSensor.new())
	nodes[-1].sensors.set_sensor_dirtrack("enter", dirtrack)
	LayoutInfo.set_layout_changed(true)

func get_prior_sensor_dirtrack():
	return nodes[-1].sensors.sensor_dirtracks["enter"]

func find_sensors():
	var sensorlist = section.get_sensor_dirtracks()
	
	if len(sensorlist)<2:
		for facing in [-1, 1]:
			nodes[facing].sensors.set_sensor_dirtrack("enter", null)
			nodes[facing].sensors.set_sensor_dirtrack("in", null)
		return
	
	nodes[1].sensors.set_sensor_dirtrack("enter", sensorlist[0])
	nodes[1].sensors.set_sensor_dirtrack("in", sensorlist[-1])
	
	nodes[-1].sensors.set_sensor_dirtrack("in", sensorlist[0])
	nodes[-1].sensors.set_sensor_dirtrack("leave", sensorlist[-1])

func get_train_spawn_dirtrack(facing):
	if facing == 1:
		return section.tracks[-1]
	return section.tracks[0]

func set_occupied(p_occupied, p_train=null):
	occupied = p_occupied
	train = p_train
	# section.set_track_attributes("block", blockname)
	if occupied:
		section.set_track_attributes("locked", train.trainname, "<>")
	else:
		section.set_track_attributes("locked", null, "<>")

func get_all_routes(from_facing, fixed_facing, trainname):
	return nodes[from_facing].calculate_routes(fixed_facing, trainname)

func get_route_to(from_facing, node_id, fixed_facing, trainname):
	return nodes[from_facing].calculate_routes(fixed_facing, trainname)[node_id]

func collect_edges(facing):
	var edges = []
	
	if can_flip:
		edges.append(LayoutEdge.new(nodes[facing], get_opposite_block().nodes[-1*facing], "flip", null))
	
	var node_obj = section.tracks[-1].get_node_obj()
	if node_obj != null:
		edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", null))
		return edges
	for next_section in section.get_next_segments():
		node_obj = next_section.tracks[-1].get_node_obj()
		if node_obj == null:
			continue
		edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", next_section))
	return edges

func get_opposite_block():
	return LayoutInfo.blocks[blockname].logical_blocks[1-index]

func get_train():
	if not occupied:
		return null
	return train

func get_locked():
	var locked_train = get_train()
	if locked_train == null:
		locked_train = get_opposite_block().get_train()
	if locked_train == null:
		return null
	return locked_train.trainname

func get_inspector():
	var inspector = LayoutBlockInspector.instance()
	inspector.set_block(self)
	return inspector

func process_mouse_button(event, _pos):
	if event.button_index == BUTTON_LEFT:
		if event.pressed:
			if not selected:
				select()
	if event.button_index == BUTTON_RIGHT:
		if not event.pressed:
			if LayoutInfo.drag_train:
				var train_obj = LayoutInfo.dragged_train
				var end_facing = LayoutInfo.drag_virtual_train.facing
				if LayoutInfo.layout_mode == "control":
					var target = nodes[end_facing].id
					if not LayoutInfo.control_enabled:
						return
					train_obj.find_route(target)
				else:
					if end_facing != train_obj.facing:
						train_obj.flip_facing()
					train_obj.set_current_block(self)

func hover(_pos):
	_hover = true
	section.set_track_attributes("block", blockname)
	
	if LayoutInfo.drag_train:
		set_drag_virtual_train()

func set_drag_virtual_train():
	var spawn_track = get_train_spawn_dirtrack(LayoutInfo.drag_virtual_train.facing)
	var vtrain = LayoutInfo.drag_virtual_train
	vtrain.set_dirtrack(spawn_track)
	vtrain.get_parent().remove_child(vtrain)
	LayoutInfo.grid.get_layer(vtrain.l_idx).add_child(vtrain)
	vtrain.update_wagon_position()
	vtrain.visible=true
	LayoutInfo.drag_layout_block = self

func stop_hover():
	_hover = false
	section.set_track_attributes("block", blockname)

	if LayoutInfo.drag_train:
		LayoutInfo.drag_virtual_train.visible=false
		LayoutInfo.drag_layout_block = null

func select():
	selected=true
	LayoutInfo.select(self)
	section.set_track_attributes("block", blockname)
	emit_signal("selected")

func unselect():
	selected=false
	section.set_track_attributes("block", blockname)
	emit_signal("unselected")
