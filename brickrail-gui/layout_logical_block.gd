class_name LayoutLogicalBlock
extends Resource

var blockname
var id
var section
var occupied: bool
var train: LayoutTrain
var index: int
var nodes = {}
var sensors = {}
var selected = false
var hover = false

var LayoutBlockInspector = preload("res://layout_block_inspector.tscn")

signal removing(blockname)
signal selected()
signal unselected()

func _init(p_name, p_index):
	blockname = p_name
	index = p_index
	id = blockname + "_" + ["+", "-"][index]
	for facing in [1, -1]:
		nodes[facing] = LayoutNode.new(self, id, facing, "block")

func set_section(p_section):
	if section != null:
		section.disconnect("sensor_changed", self, "_on_section_sensor_changed")
	section = p_section
	section.connect("sensor_changed", self, "_on_section_sensor_changed")
	find_sensors()

func _on_section_sensor_changed(track):
	find_sensors()

func find_sensors():
	var sensorlist = section.get_sensor_tracks()
	
	sensors = {}
	if len(sensorlist)<2:
		return
	sensors["enter"] = sensorlist[0]
	sensors["in"] = sensorlist[-1]

func set_occupied(p_occupied, p_train=null):
	occupied = p_occupied
	train = p_train
	section.set_track_attributes("block", blockname)

func get_route_to(from_facing, node_id):
	return nodes[from_facing].calculate_routes()[node_id]

func collect_edges(facing):
	var edges = []
	
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

func get_inspector():
	var inspector = LayoutBlockInspector.instance()
	inspector.set_block(self)
	return inspector

func process_mouse_button(event, pos):
	if event.button_index == BUTTON_LEFT:
		if event.pressed:
			if not selected:
				select()
		if not event.pressed:
			if LayoutInfo.drag_train:
				var train = LayoutInfo.dragged_train
				var start_facing = train.facing
				var end_facing = LayoutInfo.drag_virtual_train.facing
				var target = nodes[end_facing].id
				var route = train.block.get_route_to(start_facing, target)
				if route == null:
					push_error("no route to selected target "+target)
				else:
					route.get_full_section().select()
				

func hover(pos):
	hover = true
	section.set_track_attributes("block", blockname)
	
	if LayoutInfo.drag_train:
		LayoutInfo.drag_virtual_train.set_dirtrack(sensors["in"])
		LayoutInfo.drag_virtual_train.visible=true

func stop_hover():
	hover = false
	section.set_track_attributes("block", blockname)

	if LayoutInfo.drag_train:
		LayoutInfo.drag_virtual_train.visible=false

func select():
	selected=true
	LayoutInfo.select(self)
	section.set_track_attributes("block", blockname)
	emit_signal("selected")

func unselect():
	selected=false
	section.set_track_attributes("block", blockname)
	emit_signal("unselected")
