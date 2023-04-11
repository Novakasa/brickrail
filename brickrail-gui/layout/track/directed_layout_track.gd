class_name DirectedLayoutTrack
extends Reference

const STATE_SELECTED = 1
const STATE_HOVER = 2
const STATE_LOCKED_P = 4
const STATE_LOCKED_N = 8
const STATE_MARK_N = 16
const STATE_MARK_P = 32
const STATE_BLOCK_SELECTED = 64
const STATE_BLOCK_PLUS = 2048
const STATE_BLOCK_MINUS = 4096
const STATE_CONNECTED = 128
const STATE_SWITCH = 256
const STATE_SWITCH_PRIORITY = 512
const STATE_ARROW = 1024
const STATE_PORTAL = 16384
const STATE_STOPPER = 32768
const STATE_HIGHLIGHT = 65536
const STATE_BLOCK = 65536*2
const STATE_BLOCK_OCCUPIED = 65636*4
const STATE_BLOCK_HOVER = 8192

var next_slot
var prev_slot
var next_pos
var prev_pos
var id
var prohibited
var sensor
var sensor_speed = "cruise"

var l_idx
var x_idx
var y_idx

var opposite

var connections = {}
var interpolation_params = {}
var switch = null
var metadata = {}
var default_meta = {"selected": false,
					"hover": false,
					"arrow": 0,
					"locked": null,
					"locked+": 0,
					"locked-": 0,
					"mark+": 0,
					"mark-": 0,
					"block": null,
					"highlight": 0}
var hover = false

signal states_changed(next_slot)
signal switch_changed(next_slot)
signal sensor_changed(next_slot)
signal connections_changed(next_slot)
signal add_sensor_requested(p_sensor)
signal remove_sensor_requested()
signal remove_requested()

func _init(p_prev_slot, p_next_slot, id_base, p_l, p_x, p_y):
	x_idx = p_x
	y_idx = p_y
	l_idx = p_l
	next_slot = p_next_slot
	prev_slot = p_prev_slot
	id = id_base + "_>"+next_slot
	next_pos = LayoutInfo.slot_positions[next_slot]
	prev_pos = LayoutInfo.slot_positions[prev_slot]
	prohibited=false
	sensor=null
	
	metadata = {"none": default_meta.duplicate()}

func serialize(_reference=false):
	var result = {}
	result["l_idx"] = l_idx
	result["x_idx"] = x_idx
	result["y_idx"] = y_idx
	result["next_slot"] = next_slot
	result["orientation"] = get_orientation()
	return result

func _on_connected_track_switch_changed(_switch):
	emit_signal("states_changed", next_slot)

func get_rotation():
	return (next_pos-prev_pos).angle()

func get_tangent():
	return (next_pos-prev_pos).normalized()

func get_position():
	return LayoutInfo.spacing*Vector2(x_idx, y_idx)

func get_center():
	return (next_pos+prev_pos)*0.5

func get_turns():
	return connections.keys()

func remove():
	emit_signal("remove_requested")

func get_turn():
	var center_tangent = LayoutInfo.slot_positions[Tools.get_opposite_slot(prev_slot)] - prev_pos
	var turn_angle = center_tangent.angle_to(get_tangent())
	if turn_angle > PI:
		turn_angle -= 2*PI
	if is_equal_approx(turn_angle, 0.0):
		return "center"
	if turn_angle > 0.0:
		return "right"
	return "left"

func connect_dirtrack(turn, dirtrack):
	assert(not turn in connections)
	connections[turn] = dirtrack
	metadata[turn] = default_meta.duplicate()
	interpolation_params[turn] = get_interpolation_parameters(turn)
	
	dirtrack.get_opposite().connect("switch_changed", self, "_on_connected_switch_changed")
	
	# prints("added connection, turning:", turn)
	if len(connections)>1:
		update_switch()
	
	emit_signal("connections_changed", next_slot)

func disconnect_turn(turn):
	
	connections[turn].get_opposite().disconnect("switch_changed", self, "_on_connected_switch_changed")
	
	connections.erase(turn)
	interpolation_params.erase(turn)
	metadata.erase(turn)
	if len(connections) > 0:
		update_switch()
	emit_signal("connections_changed", next_slot)

func _on_connected_switch_changed(_switch):
	emit_signal("states_changed", next_slot)

func update_switch():
	if len(connections)>1:
		if switch != null:
			switch.remove()
			set_switch(null)
		var new_switch = LayoutInfo.create_switch(self)
		set_switch(new_switch)
		_on_switch_position_changed(switch.get_position())
		
		# notify opposite connecting tracks again, to update the has_switch flag in cell shader
		for dirtrack in connections.values():
			dirtrack.get_opposite().emit_signal("connections_changed", dirtrack.prev_slot)
	else:
		if switch != null:
			switch.remove()
			set_switch(null)

func set_sensor(p_sensor):
	sensor = p_sensor
	emit_signal("sensor_changed", next_slot)

func get_sensor():
	return sensor

func add_sensor(p_sensor):
	emit_signal("add_sensor_requested", p_sensor)

func remove_sensor():
	emit_signal("remove_sensor_requested")

func set_switch(p_switch):
	if switch != null:
		switch.disconnect("position_changed", self, "_on_switch_position_changed")
		switch.disconnect("state_changed", self, "_on_switch_state_changed")
	switch = p_switch
	if switch != null:
		switch.connect("position_changed", self, "_on_switch_position_changed")
		switch.connect("state_changed", self, "_on_switch_state_changed")
	emit_signal("switch_changed", switch)

func _on_switch_state_changed():
	emit_signal("states_changed", next_slot)
	emit_signal("switch_changed", next_slot)

func _on_switch_position_changed(_pos):
	emit_signal("states_changed", next_slot)
	emit_signal("switch_changed", next_slot)

func get_next_track(_slot, segment=true):
	if segment and switch != null:
			return null
	return null

func get_next_in_segment():
	if get_switch() != null or get_block() != null:
		return null
	return get_next()

func get_next(turn=null):
	if turn==null:
		turn = get_next_turn()
		if turn==null:
			return null
	return connections[turn]

func get_next_turn():
	if len(connections)==0:
		return null
	if len(connections)>1:
		return get_switch().get_position()
	return connections.keys()[0]

func get_turn_to(dirtrack):
	for turn in connections:
		if connections[turn] == dirtrack:
			return turn
	assert(false)

func get_length_to(turn=null):
	if turn == null:
		turn = get_next_turn()
		if turn==null:
			return LayoutInfo.track_stopper_length
	var next = get_next(turn)
	var this_length = get_connection_length(turn)
	var opposite_turn = next.get_opposite().get_turn_to(get_opposite())
	var next_length = next.get_opposite().get_connection_length(opposite_turn)
	return this_length + next_length

func interpolate_world(pos, turns = []):
	var turn = get_next_turn()
	if len(turns)>0:
		turn = turns[0]
	if turn == null or not turn in connections:
		return null
	var length = get_length_to(turn)
	if pos > length:
		return connections[turn].interpolate_world(pos-length, turns.slice(1, 10))
	return interpolate_turn_connection_world(turn, pos)

func to_world(vec):
	var layer_pos = LayoutInfo.grid.get_layer(l_idx).position
	return layer_pos + LayoutInfo.spacing*(Vector2(x_idx, y_idx)+vec)

func get_next_tracks():
	return connections.values()

func set_connection_attribute(turn, key, value, operation):
	if operation=="set":
		metadata[turn][key] = value
	elif operation=="increment":
		assert(key in metadata[turn])
		metadata[turn][key] += value
	else:
		push_error("invalid operation"+operation)
	emit_signal("states_changed", next_slot)

func set_track_connection_attribute(dirtrack, key, value, operation):
	var turn = connections.keys()[connections.values().find(dirtrack)]
	if has_portal():
		turn = "none"
	set_connection_attribute(turn, key, value, operation)

func get_switch():
	return switch

func get_opposite_switch(turn):
	return connections[turn].get_opposite().get_switch()

func get_opposite():
	return opposite

func set_opposite(p_opposite):
	opposite = p_opposite

func get_block():
	for turn in metadata:
		if metadata[turn]["block"]!=null:
			return LayoutInfo.blocks[metadata[turn]["block"]]

func get_logical_block():
	var block = get_block()
	if block == null:
		return null
	for logical_block in block.logical_blocks:
		if self in logical_block.section.tracks:
			return logical_block
	assert(false)

func get_next_block():
	if get_switch()!=null:
		return null
	var next_directed = get_next_tracks()
	if len(next_directed) == 0:
		return null
	assert(len(next_directed)==1)
	return next_directed[0].get_logical_block()

func get_orientation():
	var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
	if next_slot+prev_slot in orientations:
		return next_slot+prev_slot
	return prev_slot+next_slot

func get_node_obj():
	var switch_obj = get_switch()
	if switch_obj != null:
		return switch_obj
	return get_next_block()

func get_locked(turn=null):
	if turn==null:
		for turn in connections:
			var locked = get_locked(turn)
			if locked != null:
				return locked
		return null
	var locked_trainname = metadata[turn]["locked"]
	if locked_trainname != null:
		return locked_trainname
	return null

func set_one_way(one_way):
	prohibited = false
	get_opposite().prohibited = one_way
	emit_signal("states_changed", next_slot)
	LayoutInfo.set_layout_changed(true)

func set_sensor_speed(speed):
	sensor_speed = speed
	LayoutInfo.set_layout_changed(true)

func get_turn_angle(turn):
	var this_turn = get_turn()
	if this_turn == "center":
		if turn == "left":
			return -0.25*PI
		if turn == "center":
			return 0.0
		return 0.25*PI
	if this_turn == "left":
		if turn == "left":
			return -0.5*PI
		if turn == "center":
			return -0.25*PI
		return 0.0
	if turn == "left":
		return 0.0
	if turn == "center":
		return 0.25*PI
	return 0.5*PI
	
func get_turn_radius(angle):
	if is_equal_approx(angle, 0.0):
		return 0.0
	if is_equal_approx(abs(angle), 0.25*PI):
		return 0.5+0.25*sqrt(2.0)
	if is_equal_approx(abs(angle),PI*0.5):
		return 0.25*sqrt(2.0)
	push_error("[get_connection_radius] invalid angle to next track!")

func get_interpolation_parameters(turn):
	var angle = get_turn_angle(turn)
	var turn_sign = sign(angle)
	var neigbour_slot = Tools.get_opposite_slot(next_slot)

	var aligned_vector = next_pos-Tools.get_slot_pos(neigbour_slot)
	var tangent = get_tangent()
	var arc_start
	var straight_start
	if tangent.dot(aligned_vector)>0.99:
		arc_start = next_pos-aligned_vector*(0.25*sqrt(2))
		straight_start = 0.5*(next_pos+prev_pos)
	else:
		arc_start = 0.5*(next_pos+prev_pos)
		straight_start = arc_start
	var radius = get_turn_radius(angle)
	var center = arc_start + tangent.rotated(0.5*PI*turn_sign)*radius
	var start_angle = tangent.angle()-0.5*PI*turn_sign
	var stop_angle = start_angle + 0.5*angle
	var arc_length = abs(0.5*radius*angle)
	if is_equal_approx(radius, 0.0):
		arc_length = (next_pos-arc_start).length()
	var straight_length = (arc_start - straight_start).length()
	var connection_length = arc_length + straight_length
	
	return {"from_pos": prev_pos,
			"to_pos": next_pos,
			"center": center,
			"radius": radius,
			"start_angle": start_angle,
			"stop_angle": stop_angle,
			"angle": angle,
			"straight_start": straight_start,
			"arc_start": arc_start,
			"arc_length": arc_length,
			"straight_length": straight_length,
			"connection_length": connection_length}

func get_connection_length(turn=null):
	if turn == null:
		turn = get_next_turn()
	return interpolation_params[turn].connection_length

func interpolate_connection_world(turn, t, normalized=false):
	var result = interpolate_connection(turn, t, normalized)
	result.position *= LayoutInfo.spacing
	result.position += LayoutInfo.grid.get_layer(l_idx).position + LayoutInfo.spacing*(Vector2(x_idx, y_idx))
	return result

func interpolate_connection(turn, t, normalized=false):
	var params = interpolation_params[turn]
	var x = t
	if normalized:
		x = t*params.connection_length
	if x<0.0:
		var result = {}
		result["position"] = params.straight_start+x*(params.to_pos-params.from_pos).normalized()
		result["rotation"] = (params.to_pos-params.from_pos).angle()
		return result
	if is_equal_approx(params.radius, 0.0):
		var result = {}
		result["position"] = lerp(params.straight_start, params.to_pos, x/params.connection_length)
		result["rotation"] = (params.to_pos-params.from_pos).angle()
		return result
	if x<params.straight_length:
		var result = {}
		result["position"] = lerp(params.straight_start, params.arc_start, x/params.straight_length)
		result["rotation"] = (params.to_pos-params.from_pos).angle()
		return result
	var angle = lerp(params.start_angle, params.stop_angle, (x-params.straight_length)/params.arc_length)
	var result = {}
	result["position"] = params.center + params.radius*Vector2(1.0,0.0).rotated(angle)
	result["rotation"] = angle+0.5*PI*sign(params.angle)
	return result

func interpolate_turn_connection_world(turn, t, normalized=false):
	if turn == null:
		var position = 0.5*(prev_pos+next_pos) + t*get_tangent().normalized()
		var rotation = get_rotation()
		return {"position": position, "rotation": rotation}
	
	var reverse_dirtrack = connections[turn].get_opposite()
	var reverse_turn = reverse_dirtrack.get_turn_to(get_opposite())
	var this_length = get_connection_length(turn)
	var reverse_length = reverse_dirtrack.get_connection_length(reverse_turn)
	var total_length = this_length + reverse_length
	var x = t
	if normalized:
		x = t*total_length
	# printt(total_length, this_length, reverse_length, x)
	if x<this_length:
		return interpolate_connection_world(turn, x, false)
	var result = reverse_dirtrack.interpolate_connection_world(reverse_turn, total_length-x, false)
	result["rotation"] += PI
	return result

func set_hover(_pos):
	hover=true
	emit_signal("states_changed", next_slot)

func stop_hover():
	hover=false
	emit_signal("states_changed", next_slot)

func get_shader_states():
	var states = {"left": 0, "right": 0, "center": 0, "none": 0}
	for turn in metadata:
		states[turn] = get_shader_state(turn)
	return states

func connect_portal(dirtrack):
	var portal_turn = "center"
	var turn = get_turn()
	if turn == "left":
		portal_turn = "right"
	if turn == "right":
		portal_turn = "left"
	
	connect_dirtrack(portal_turn, dirtrack)

func is_continuous_to(dirtrack, turn=null):
	if l_idx != dirtrack.l_idx:
		return false
	if dirtrack.x_idx - x_idx != LayoutInfo.get_slot_x_idx_delta(next_slot):
		return false
	if dirtrack.y_idx - y_idx != LayoutInfo.get_slot_y_idx_delta(next_slot):
		return false
	if LayoutInfo.get_neighbour_slot(next_slot) != dirtrack.prev_slot:
		return false
	if turn != null and dirtrack.get_turn() != turn:
		return false
	return true

func has_portal():
	for turn in connections:
		if not is_continuous_to(connections[turn], turn):
			return true
	return false
	
func get_shader_state(turn):
	var state = 0
	if metadata[turn]["block"] != null:
		state |= STATE_BLOCK
		var block = LayoutInfo.blocks[metadata[turn]["block"]]
		for logical_block in block.logical_blocks:
			if logical_block._hover:
				state |= STATE_BLOCK_HOVER
				if logical_block.section.tracks[-1] == self:
					state |= [STATE_BLOCK_PLUS, STATE_BLOCK_MINUS][logical_block.index]
			if logical_block.selected:
				state |= STATE_BLOCK_SELECTED
				if logical_block.section.tracks[-1] == self:
					state |= [STATE_BLOCK_PLUS, STATE_BLOCK_MINUS][logical_block.index]
		if block.get_occupied():
			state |= STATE_BLOCK_OCCUPIED
	if turn in connections:
		if is_continuous_to(connections[turn], turn):
			state |= STATE_CONNECTED
	if turn == "none":
		if len(connections) == 0:
			state |= STATE_CONNECTED
			state |= STATE_STOPPER
		if has_portal():
			state |= STATE_PORTAL
			state |= STATE_CONNECTED
	if turn != "none" and turn in connections:
		var opposite_switch = get_opposite_switch(turn)
		var opposite_turn = get_opposite().get_turn()
		if opposite_switch != null:
			# prints(opposite_turn, opposite_switch.get_position())
			if opposite_switch.selected:
				state |= STATE_SELECTED
			if opposite_switch.hover:
				state |= STATE_HOVER
			if opposite_turn == opposite_switch.get_position() and not opposite_switch.disabled:
				state |= STATE_SWITCH
			# print(state & STATE_SWITCH)
		
		if switch != null:
			if switch.selected:
				state |= STATE_SELECTED
			if switch.hover:
				state |= STATE_HOVER
			if not switch.disabled and switch.get_position() == turn:
				state |= STATE_SWITCH
				state |= STATE_SWITCH_PRIORITY
	if get_opposite().prohibited:
		state |= STATE_ARROW
	if metadata[turn]["selected"]:
		state |= STATE_SELECTED
	if metadata[turn]["hover"]:
		state |= STATE_HOVER
	if metadata[turn]["highlight"]>0:
		state |= STATE_HIGHLIGHT
	if metadata[turn]["arrow"]>0:
		state |= STATE_ARROW
	if metadata[turn]["locked+"]>0:
		state |= STATE_LOCKED_P
	if metadata[turn]["locked-"]>0:
		state |= STATE_LOCKED_N
	if metadata[turn]["mark+"]>0:
		state |= STATE_MARK_P
	if metadata[turn]["mark-"]>0:
		state |= STATE_MARK_N
	if hover:
		state |= STATE_HOVER
		state |= STATE_ARROW
	if get_opposite().hover:
		state |= STATE_HOVER
	return state
