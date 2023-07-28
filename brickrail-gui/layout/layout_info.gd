tool
extends Node

var grid = null

var cells = {}
var blocks = {}
var trains = {}
var switches = {}

var sensors = Array()

var nodes = {}

var BlockScene = preload("res://layout/block/layout_block.tscn")
onready var LayoutCell = preload("res://layout/grid/layout_cell.tscn")

const CONTROL_OFF = 0
const CONTROL_SWITCHES = 1
const CONTROL_ALL = 2

var active_layer = 0
var layers_unfolded = false

var spacing = 1024.0
var track_stopper_length = 0.6
var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
var pretty_tracks = true
var slot_index = {"N": 0, "E": 1, "S": 2, "W": 3}
var slot_positions = {"N": Vector2(0.5,0), "S": Vector2(0.5,1), "E": Vector2(1,0.5), "W": Vector2(0,0.5)}

var layout_mode = "edit"
var selection = null
var control_devices: int = CONTROL_OFF
var control_enabled = true

var drawing_track = false
var drawing_last = null
var drawing_last2 = null
var drawing_last_track = null
var drawing_mode = null

var drag_select = false
var drag_selection = null
var drag_select_highlighted = []

var drag_train = false
var dragged_train = null
var drag_virtual_train = null
var drag_layout_block = null

var portal_dirtrack = null
var portal_target = null

var random_targets = false
var time_scale = 1.0

var layout_file = null
var layout_changed = false

signal layout_mode_changed(mode)
signal selected(obj)
signal control_devices_changed(control_mode)
#warning-ignore:unused_signal
signal blocked_tracks_changed(train_id)
signal random_targets_set(rand_target)
signal layers_changed()
signal layer_added(l)
signal layer_removed(l)
signal active_layer_changed(l)
signal layers_unfolded_changed(mode)
#warning-ignore:unused_signal
signal layer_positions_changed()
signal cell_added(cell)
signal trains_running(running)
#warning-ignore:unused_signal
signal sensors_changed()

func set_layout_changed(value):
	pass
	yield(get_tree(), "idle_frame")
	layout_changed = value
	# prints("layout changed", value)
	GuiApi.status_gui.get_node("LayoutChangedLabel").visible=value

func get_cell(l, i, j):
	assert(l in cells)
	if not i in cells[l]:
		cells[l][i] = {}
	if not j in cells[l][i]:
		var cell = LayoutCell.instance()
		cells[l][i][j] = cell
		cell.setup(l, i, j)
		cell.connect("removing", self, "_on_cell_removing")
		emit_signal("cell_added", cell)

	return cells[l][i][j]

func _on_cell_removing(cell):
	cell.disconnect("removing", self, "_on_cell_removing")
	cells[cell.l_idx][cell.x_idx].erase(cell.y_idx)

func add_layer(l):
	assert(not l in cells)
	cells[l] = {}
	
	set_layout_changed(true)
	emit_signal("layer_added", l)
	emit_signal("layers_changed")
	set_active_layer(l)

func remove_layer(l):
	assert(l in cells)
	
	for column in cells[l].values():
		for cell in column.values():
			for track in cell.tracks.values():
				track.remove()
			cell.remove()
	if active_layer == l:
		set_active_layer(null)
	cells.erase(l)
	
	set_layout_changed(true)
	
	emit_signal("layer_removed", l)
	emit_signal("layers_changed")

func set_active_layer(l):
	active_layer = l
	emit_signal("active_layer_changed", l)

func set_layers_unfolded(val):
	layers_unfolded = val
	emit_signal("layers_unfolded_changed", val)

func serialize():
	var result = {}
	
	var tracks = []
	for layer in cells:
		for column in cells[layer].values():
			for cell in column.values():
				if cell == null:
					continue
				for track in cell.tracks.values():
					tracks.append(track.serialize())
	
	var blockdata = []
	for block in blocks.values():
		blockdata.append(block.serialize())
	
	var traindata = []
	for train in trains.values():
		traindata.append(train.serialize())

	result["tracks"] = tracks
	result["blocks"] = blockdata
	result["trains"] = traindata
	
	return result

func clear():
	unselect()
	for train in trains.values():
		train.remove()
	for block in blocks.values():
		block.remove()
	for layer in cells.keys():
		remove_layer(layer)
	
	add_layer(0)

func load(struct):
	clear()
	
	for track in struct.tracks:
		var l = 0
		if "l_idx" in track:
			l = int(track.l_idx)
		if not l in cells:
			add_layer(l)
		var i = int(track.x_idx)
		var j = int(track.y_idx)
		var slot0 = track.connections.keys()[0]
		var slot1 = track.connections.keys()[1]
		var track_obj = get_cell(l, i, j).create_track(slot0, slot1)
		get_cell(l, i, j).add_track(track_obj)
	
	for track in struct.tracks:
		var l = 0
		if "l_idx" in track:
			l = int(track.l_idx)
		var i = int(track.x_idx)
		var j = int(track.y_idx)
		var slot0 = track.connections.keys()[0]
		var slot1 = track.connections.keys()[1]
		var orientation = slot0 + slot1
		var track_obj = get_cell(l, i, j).tracks[orientation]
		track_obj.load_connections(track.connections)
		if "portals" in track:
			track_obj.load_portals(track.portals)
		if "switches" in track:
			track_obj.load_switches(track.switches)
		if "sensor" in track:
			track_obj.load_sensor(track.sensor)
			if "speeds" in track.sensor:
				for slot in track.sensor.speeds:
					track_obj.directed_tracks[slot].sensor_speed = track.sensor.speeds[slot]
		if "crossing" in track:
			track_obj.add_crossing()
			track_obj.crossing.load_struct(track.crossing)
		if "prohibited_slot" in track:
			track_obj.directed_tracks[track.prohibited_slot].get_opposite().set_one_way(true)
		if "facing_filter" in track:
			for slot in track.facing_filter:
				track_obj.directed_tracks[slot].facing_filter = int(track.facing_filter[slot])
	
	if "blocks" in struct:
		for block_data in struct.blocks:
			var section = LayoutSection.new()
			section.load(block_data.section)
			var block = create_block(block_data.name, section)
			if "block_name" in block_data:
				block.set_name(block_data.block_name)
			if "prior_sensors" in block_data:
				for index in block_data.prior_sensors:
					var prior_sensor_dirtrack = get_dirtrack_from_struct(block_data.prior_sensors[index])
					block.logical_blocks[int(index)].add_prior_sensor_dirtrack(prior_sensor_dirtrack)
			if "can_stop" in block_data:
				for index in block_data.can_stop:
					block.logical_blocks[int(index)].can_stop = block_data.can_stop[index]
			if "can_flip" in block_data:
				for index in block_data.can_flip:
					block.logical_blocks[int(index)].can_flip = block_data.can_flip[index]
			if "random_target" in block_data:
				for index in block_data.random_target:
					block.logical_blocks[int(index)].set_random_target(block_data.random_target[index])
			if "wait_time" in block_data:
				for index in block_data.wait_time:
					block.logical_blocks[int(index)].set_wait_time(block_data.wait_time[index])
	
	if "trains" in struct:
		for train_data in struct.trains:
			var train = create_train(train_data.name)
			if "train_name" in train_data:
				train.set_name(train_data.train_name)
			if "fixed_facing" in train_data:
				var behavior = "on"
				if train_data.fixed_facing:
					behavior = "off"
				train.set_reversing_behavior(behavior)
			if "reversing_behavior" in train_data:
				train.set_reversing_behavior(train_data.reversing_behavior)
			if "random_targets" in train_data:
				train.set_random_targets(train_data.random_targets)
			
			if "blockname" in train_data:
				train_data["block_id"] = train_data["blockname"]

			var home_pos_dict = {}
			home_pos_dict["block_id"] = train_data.block_id
			home_pos_dict["index"] = train_data.blockindex
			home_pos_dict["facing"] = int(train_data.facing)
			train.set_home_position(home_pos_dict)
			train.reset_to_home_position()
			
			if "ble_train" in train_data:
				train.set_ble_train(train_data.ble_train)
			if "color" in train_data:
				train.virtual_train.set_color(Color(train_data.color))
			if "num_wagons" in train_data:
				train.virtual_train.set_num_wagons(int(train_data.num_wagons))

func store_train_positions():
	Logger.info("[LayoutInfo] storing train positions for file %s..." % layout_file)
	if layout_file == null:
		return
	Settings.layout_train_positions[layout_file] = {}
	for train_id in trains:
		var train = trains[train_id]
		var pos_dict = train.get_current_pos_dict()
		Settings.layout_train_positions[layout_file][train_id] = pos_dict
		Logger.info("[LayoutInfo] storing position for train %s: %s" % [train_id, pos_dict])

func restore_train_positions():
	Logger.info("[LayoutInfo] restoring train positions for file %s..." % layout_file)
	if layout_file == null:
		return
	if not layout_file in Settings.layout_train_positions:
		return
	
	# do the move in two passes, since first all trains need to set block==null to
	# avoid moving to already occupied position
	for train_id in trains:
		if not train_id in Settings.layout_train_positions[layout_file]:
			continue
		var loc_dict = Settings.layout_train_positions[layout_file][train_id].duplicate()
		if "blockname" in loc_dict:
			loc_dict["block_id"] = loc_dict["blockname"]
		if not loc_dict.block_id in blocks:
			continue
		trains[train_id].set_current_block(null)
	for train_id in trains:
		if not train_id in Settings.layout_train_positions[layout_file]:
			continue
		var loc_dict = Settings.layout_train_positions[layout_file][train_id].duplicate()
		if "blockname" in loc_dict:
			loc_dict["block_id"] = loc_dict["blockname"]
		if not loc_dict.block_id in blocks:
			continue
		Logger.info("[LayoutInfo] restoring position for train %s: %s" % [train_id, loc_dict])
		trains[train_id].reset_to_position(loc_dict)

func get_hover_lock():
	if drag_select or drawing_track:
		return true
	if grid.dragging_view:
		return true
	return false

func get_track_from_struct(struct):
	var l = 0
	if "l_idx" in struct:
		l = int(struct.l_idx)
	var i = int(struct.x_idx)
	var j = int(struct.y_idx)
	var orientation
	if "orientation" in struct:
		orientation = struct.orientation
	else:
		orientation = struct["slot0"] + struct["slot1"]
	return get_cell(l, i, j).tracks[orientation]

func is_struct_dirtrack(struct):
	return "next_slot" in  struct

func get_dirtrack_from_struct(struct):
	var track = get_track_from_struct(struct)
	return track.get_directed_to(struct.next_slot)

func create_block(p_name, section):
	assert(not p_name in blocks)
	var block = BlockScene.instance()
	block.setup(p_name)
	blocks[p_name] = block
	block.set_section(section)
	grid.get_layer(section.tracks[0].l_idx).add_child(block)
	block.connect("removing", self, "_on_block_removing")
	
	for logical_block in block.logical_blocks:
		for node in logical_block.nodes.values():
			nodes[node.id] = node
	
	set_layout_changed(true)
	return block

func _on_block_removing(p_name):
	for logical_block in blocks[p_name].logical_blocks:
		for node in logical_block.nodes.values():
			nodes.erase(node.id)
	blocks[p_name].disconnect("removing", self, "_on_block_removing")
	blocks.erase(p_name)
	set_layout_changed(true)

func create_train(p_name):
	assert(not p_name in trains)
	var train = LayoutTrain.new(p_name)
	grid.add_child(train)
	trains[p_name] = train
	train.connect("removing", self, "_on_train_removing")
	train.connect("route_changed", self, "_on_train_route_changed")
	set_layout_changed(true)
	return train

func _on_train_removing(p_name):
	trains[p_name].disconnect("removing", self, "_on_train_removing")
	trains[p_name].disconnect("route_changed", self, "_on_train_route_changed")
	set_layout_changed(true)
	trains.erase(p_name)

func _on_train_route_changed():
	for train in trains.values():
		if train.route != null:
			emit_signal("trains_running", true)
			return
	emit_signal("trains_running", false)

func create_switch(directed_track):
	var switch = LayoutSwitch.new(directed_track)
	assert(not switch.id in switches)
	switches[switch.id] = switch
	switch.connect("removing", self, "_on_switch_removing")
	
	for node in switch.nodes.values():
		nodes[node.id] = node
	
	return switch

func _on_switch_removing(id):
	for node in switches[id].nodes.values():
		nodes.erase(node.id)
	
	switches[id].disconnect("removing", self, "_on_switch_removing")
	switches.erase(id)

func set_control_devices(p_control_devices):
	control_devices = p_control_devices
	Logger.info("[LayoutInfo] control devices changed: %s" % control_devices)
	emit_signal("control_devices_changed", control_devices)

func set_random_targets(p_random_targets):
	random_targets = p_random_targets
	Logger.info("[LayoutInfo] control devices changed: %s" % random_targets)
	emit_signal("random_targets_set", p_random_targets)

func blocks_depend_on(dirtrack):
	for block in blocks.values():
		if block.depends_on(dirtrack):
			return true
	return false

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_SPACE:
				emergency_stop()
			if event.scancode == KEY_Q:
				set_layout_mode("edit")
			if event.scancode == KEY_W:
				set_layout_mode("control")
			
			if event.scancode == KEY_DELETE and layout_mode == "edit":
				if selection is LayoutSection:
					var dirtracks = Array(selection.tracks)
					selection.unselect()
					if len(dirtracks) == 1:
						var next = dirtracks[0].get_next()
						if next == null:
							next = dirtracks[0].get_opposite().get_next()
						if next != null:
							drag_selection = LayoutSection.new()
							drag_selection.add_track(next)
							drag_selection.select()
					for dirtrack in dirtracks:
						if dirtrack.get_block() != null:
							continue
						if blocks_depend_on(dirtrack):
							continue
						dirtrack.remove()
				
				if selection is LayoutLogicalBlock:
					if selection.occupied or selection.get_opposite_block().occupied:
						return
					blocks[selection.block_id].remove()
				
				if selection is LayoutTrain:
					selection.remove()
				

func bresenham_line(startx, starty, stopx, stopy):
	if startx == stopx and starty == stopy:
		return [[startx, starty]]
	var points = []
	var deltax = stopx-startx
	var deltay = stopy-starty
	var px = startx
	var py = starty
	
	if deltax == 0:
		while py!=stopy:
			py+=int(sign(deltay))
			points.append([px,py])
		return points
	
	var ybyx = float(deltay)/float(deltax)
	var dist = 0.0
	
	while px!=stopx:
		px+=int(sign(deltax))
		dist += ybyx*sign(deltax)
		points.append([px, py])
		while abs(dist)>0.5:
			py += int(sign(dist))
			dist -= sign(dist)
			points.append([px, py])
	return points

func set_layout_mode(mode):
	layout_mode = mode
	if mode != "control":
		set_random_targets(false)
	emit_signal("layout_mode_changed", mode)

func unselect():
	if selection != null:
		selection.unselect()

func select(obj):
	Logger.info("[LayoutInfo] selecting: %s" % obj)
	unselect()
	selection = obj
	obj.connect("unselected", self, "_on_selection_unselected")
	emit_signal("selected", obj)

func _on_selection_unselected():
	selection.disconnect("unselected", self, "_on_selection_unselected")
	selection = null

func _on_drawing_last_track_removing(_orientation):
	drawing_last_track.disconnect("removing", self, "_on_drawing_last_track_removing")
	drawing_last_track = null

func set_drawing_last_track(track):
	if drawing_last_track != null:
		drawing_last_track.set_drawing_highlight(false)
		drawing_last_track.disconnect("removing", self, "_on_drawing_last_track_removing")
	if track != null:
		track.connect("removing", self, "_on_drawing_last_track_removing")
		track.set_drawing_highlight(true)
	drawing_last_track = track

func init_draw_track(cell):
	drawing_track = true
	drawing_last = cell
	drawing_last2 = null
	set_drawing_last_track(null)
	unselect()

func stop_draw_track():
	drawing_track = false
	set_drawing_last_track(null)
	if drawing_last == null:
		return
	for neighbor in drawing_last.get_neighbors():
		neighbor.set_drawing_highlight(false)

func init_connected_draw_track(track):
	var cell = get_cell(track.l_idx, track.x_idx, track.y_idx)
	init_draw_track(cell)
	set_drawing_last_track(track)

func init_drag_select(track, slot):
	drag_selection = LayoutSection.new()
	drag_selection.add_track(track.get_directed_to(slot))
	drag_select = true
	drawing_last = get_cell(track.l_idx, track.x_idx, track.y_idx)
	drawing_last2 = null
	set_drawing_last_track(null)
	drag_selection.select()

func init_drag_train(train):
	drag_train = true
	dragged_train = train
	drag_virtual_train = VirtualTrain.new("drag-train")
	drag_virtual_train.set_color(train.virtual_train.color)
	drag_virtual_train.set_num_wagons(len(train.virtual_train.wagons))
	grid.add_child(drag_virtual_train)
	drag_virtual_train.set_process_unhandled_input(false)
	drag_virtual_train.set_process(false)
	drag_virtual_train.set_facing(dragged_train.facing)
	drag_virtual_train.visible=false
	drag_layout_block = null

func stop_drag_train():
	if drag_train:
		drag_train = false
		drag_virtual_train.remove()
		dragged_train = null
		drag_layout_block = null

func flip_drag_train_facing():
	drag_virtual_train.set_facing(drag_virtual_train.facing*-1)
	if drag_layout_block != null:
		drag_layout_block.set_drag_virtual_train()

func stop_drag_select():
	drag_select = false
	for cell in drag_select_highlighted:
		cell.set_drawing_highlight(false)
	drag_select_highlighted = []

func draw_track_hover_cell(cell):
	if not cell == drawing_last:
		var line = bresenham_line(drawing_last.x_idx, drawing_last.y_idx, cell.x_idx, cell.y_idx)
		for p in line:
			var iter_cell = get_cell(cell.l_idx, p[0], p[1])
			draw_track_add_cell(iter_cell)
	
func draw_track_add_cell(draw_cell):
	if draw_cell == drawing_last2:
		drawing_last2 = null
		set_drawing_last_track(null)
	if drawing_last2 != null:
		var slot0 = drawing_last.get_slot_to_cell(drawing_last2)
		var slot1 = drawing_last.get_slot_to_cell(draw_cell)
		if slot1 == null or slot0 == null:
			drawing_last = draw_cell
			drawing_last2 = null
			set_drawing_last_track(null)
			return
		var track = drawing_last.create_track(slot0, slot1)
		if not track.get_orientation() in drawing_last.tracks:
			track = drawing_last.add_track(track)
		else:
			track = drawing_last.tracks[track.get_orientation()]
		if drawing_last_track != null:
			if track.can_connect_track(slot0, drawing_last_track):
				track.connect_track(slot0, drawing_last_track)
		set_drawing_last_track(track)
	drawing_last2 = drawing_last
	drawing_last = draw_cell
	for neighbor in drawing_last2.get_neighbors():
		neighbor.set_drawing_highlight(false)
	for neighbor in drawing_last.get_neighbors():
		if neighbor == drawing_last2:
			continue
		neighbor.set_drawing_highlight(true)

func drag_select_hover_cell(cell):
	if not cell == drawing_last:
		for iter_cell in drag_select_highlighted:
			iter_cell.set_drawing_highlight(false)
		drag_select_highlighted = []
		drag_select_highlighted.append(drawing_last)
		drawing_last.set_drawing_highlight(true)
		var line = bresenham_line(drawing_last.x_idx, drawing_last.y_idx, cell.x_idx, cell.y_idx)
		for p in line:
			var iter_cell = get_cell(cell.l_idx, p[0], p[1])
			iter_cell.set_drawing_highlight(true)
			drag_select_highlighted.append(iter_cell)
			draw_select(iter_cell)

func draw_select(draw_cell):
	
	if drawing_last2 == null:
		drawing_last2 = drawing_last
		drawing_last = draw_cell
		return

	var slot0 = drawing_last.get_slot_to_cell(drawing_last2)
	var slot1 = drawing_last.get_slot_to_cell(draw_cell)
	
	if slot1 == null or slot0 == null or slot1 == slot0:
		if drag_selection == null:
			drawing_last2 = null
			drawing_last = draw_cell
		return
	
	var track = drawing_last.create_track(slot0, slot1)
	if track.get_orientation() in drawing_last.tracks:
		track = drawing_last.tracks[track.get_orientation()].get_directed_to(slot1)
		if not drag_selection.can_add_track(track):
			if drag_selection.flip().can_add_track(track):
				drag_selection = drag_selection.flip()
				drag_selection.select()
			else:
				return
		drag_selection.add_track(track)
		drawing_last2 = drawing_last
		drawing_last = draw_cell
	elif drag_selection == null:
		drawing_last2 = drawing_last
		drawing_last = draw_cell

func set_portal_dirtrack(dirtrack):
	portal_dirtrack = dirtrack
	if portal_target != null:
		attempt_portal()

func set_portal_target(track):
	portal_target = track
	if portal_dirtrack != null:
		attempt_portal()

func attempt_portal():
	if len(portal_dirtrack.connections)>0:
		push_error("portal start dirtrack already has connection!")
		return
	if len(portal_target.get_opposite().connections)>0:
		if len(portal_target.connections)>0:
			push_error("portal target dirtrack already has connection!")
			return
		else:
			portal_target = portal_target.get_opposite()
	
	portal_dirtrack.connect_portal(portal_target)
	portal_target.get_opposite().connect_portal(portal_dirtrack.get_opposite())
	
	set_layout_mode("edit")
	portal_dirtrack = null
	portal_target = null

func stop_all_trains():
	GuiApi.show_info("Stopping routes...")
	Logger.info("[LayoutInfo] Stopping all trains")
	set_random_targets(false)
	for train in trains.values():
		if train.route != null:
			train.cancel_route()

func emergency_stop():
	Logger.info("[LayoutInfo] Emergency stop")
	GuiApi.show_warning("Emergency stop!")
	set_control_devices(CONTROL_OFF)
	if Devices.get_ble_controller().get_node("BLECommunicator").connected:
		for ble_train in Devices.trains.values():
			if ble_train.hub.running:
				ble_train.stop()
	stop_all_trains()

func get_neighbour_slot(slot):
	if slot == "N":
		return "S"
	if slot == "S":
		return "N"
	if slot == "E":
		return "W"
	if slot == "W":
		return "E"

func get_slot_x_idx_delta(slot):
	if slot == "E":
		return 1
	if slot == "W":
		return -1
	return 0

func get_slot_y_idx_delta(slot):
	if slot == "N":
		return -1
	if slot == "S":
		return 1
	return 0
