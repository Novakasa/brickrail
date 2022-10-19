class_name DirectedLayoutTrack
extends Reference

const STATE_SELECTED = 1
const STATE_HOVER = 2
const STATE_LOCKED = 4
const STATE_BLOCK = 8
const STATE_BLOCK_OCCUPIED = 16
const STATE_BLOCK_HOVER = 32
const STATE_BLOCK_SELECTED = 64
const STATE_BLOCK_PLUS = 2048
const STATE_BLOCK_MINUS = 4096
const STATE_CONNECTED = 128
const STATE_SWITCH = 256
const STATE_SWITCH_PRIORITY = 512
const STATE_ARROW = 1024
const STATE_MARK = 8192
const STATE_PORTAL = 16384
const STATE_STOPPER = 32768

var next_slot
var prev_slot
var next_pos
var prev_pos
var id
var prohibited
var portal
var sensor

var l_idx
var x_idx
var y_idx

var opposite

var connections = {}
var interpolation_params = {}
var switch = null
var metadata = {}
var default_meta = {"selected": false, "hover": false, "arrow": 0, "locked": null, "block": null, "mark": 0}
var hover = false

signal states_changed(next_slot)
signal switch_changed(next_slot)
signal sensor_changed(next_slot)
signal add_sensor_requested(p_sensor)
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
	portal=null
	sensor=null
	
	metadata = {"none": default_meta.duplicate()}

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
	else:
		if switch != null:
			switch.remove()
			switch = null

func set_sensor(p_sensor):
	sensor = p_sensor
	emit_signal("sensor_changed", next_slot)

func get_sensor():
	return sensor

func add_sensor(p_sensor):
	emit_signal("add_sensor_requested", p_sensor)

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

func _on_switch_position_changed(pos):
	emit_signal("states_changed", next_slot)
	emit_signal("switch_changed", next_slot)

func get_next_track(slot, segment=true):
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

func get_length_to(turn=null):
	if turn == null:
		turn = get_next_turn()
		if turn==null:
			return LayoutInfo.track_stopper_length
	var next = get_next(turn)
	var this_length = get_connection_length(turn)
	var opposite_turn = get_opposite().get_turn()
	var next_length = next.get_opposite().get_connection_length(opposite_turn)
	return this_length + next_length

func interpolate(pos, turn=null):
	if turn == null:
		var position = 0.5*(prev_pos+next_pos) + pos*get_tangent().normalized()
		var rotation = get_rotation()
		return {"position": position, "rotation": rotation}
	return interpolate_turn_connection(turn, pos)

func to_world(vec):
	return LayoutInfo.spacing*(Vector2(x_idx, y_idx)+vec)

func get_next_tracks():
	return connections.values()

func set_connection_attribute(turn, key, value, operation):
	if operation=="set":
		metadata[turn][key] = value
	elif operation=="increment":
		metadata[turn][key] += value
	else:
		push_error("invalid operation"+operation)
	emit_signal("states_changed", next_slot)

func set_track_connection_attribute(dirtrack, key, value, operation):
	var turn = connections.keys()[connections.values().find(dirtrack)]
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
	var switch = get_switch()
	if switch != null:
		return switch
	return get_next_block()

func get_locked(turn=null):
	if turn==null:
		turn = get_next_turn()
	var locked_trainname = metadata[turn]["locked"]
	if locked_trainname != null:
		return locked_trainname
	return null

func set_one_way(one_way):
	prohibited = false
	get_opposite().prohibited = one_way
	emit_signal("states_changed", next_slot)

func set_portal(p_portal):
	portal = p_portal
	emit_signal("states_changed", next_slot)

func create_portal_to(target):
	assert(portal==null)
	
	var new_portal = LayoutPortal.new(self, target)
	set_portal(new_portal)
	target.set_portal(new_portal)

func get_turn_angle(turn):
	var next_track = connections[turn]
	var angle = get_tangent().angle_to(next_track.get_tangent())
	while angle>PI:
		angle-=2*PI
	while angle<-PI:
		angle += 2*PI
	return angle
	
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

func interpolate_turn_connection(turn, t, normalized=false):
	var reverse_dirtrack = connections[turn].get_opposite()
	var reverse_turn = get_opposite().get_turn()
	var this_length = get_connection_length(turn)
	var reverse_length = reverse_dirtrack.get_connection_length(reverse_turn)
	var total_length = this_length + reverse_length
	var x = t
	if normalized:
		x = t*total_length
	# printt(total_length, this_length, reverse_length, x)
	if x<this_length:
		return interpolate_connection(turn, x, false)
	var result = reverse_dirtrack.interpolate_connection(reverse_turn, total_length-x, false)
	result["position"] += Vector2(reverse_dirtrack.x_idx-x_idx, reverse_dirtrack.y_idx-y_idx)
	result["rotation"] += PI
	return result

func interpolate_position_linear(t):
	if t>=1.0:
		return next_pos
	if t<=0.0:
		return prev_pos
	return prev_pos + (next_pos-prev_pos)*t

func hover(pos):
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

func get_shader_state(turn):
	var state = 0
	if metadata[turn]["block"] != null:
		state |= STATE_BLOCK
		var block = LayoutInfo.blocks[metadata[turn]["block"]]
		for logical_block in block.logical_blocks:
			if logical_block.hover:
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
		state |= STATE_CONNECTED
	if turn == "none" and len(connections)==0:
		state |= STATE_CONNECTED
		if portal == null:
			state |= STATE_STOPPER
		else:
			state |= STATE_PORTAL
	if turn != "none" and turn in connections:
		var opposite_switch = get_opposite_switch(turn)
		var opposite_turn = get_opposite().get_turn()
		if opposite_switch != null:
			if opposite_switch.selected:
				state |= STATE_SELECTED
			if opposite_switch.hover:
				state |= STATE_HOVER
			if opposite_turn == opposite_switch.get_position() and not opposite_switch.disabled:
				state |= STATE_SWITCH
		
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
	if metadata[turn]["arrow"]>0:
		state |= STATE_ARROW
	if metadata[turn]["locked"]!=null:
		state |= STATE_LOCKED
	if metadata[turn]["mark"]>0:
		state |= STATE_MARK
	if hover:
		state |= STATE_HOVER
		state |= STATE_ARROW
	if get_opposite().hover:
		state |= STATE_HOVER
	# if drawing_highlight:
	# 	state |= STATE_SELECTED TODO
	return state
