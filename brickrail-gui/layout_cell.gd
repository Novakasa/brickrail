class_name LayoutCell
extends Node2D

var x_idx
var y_idx
var tracks = {}
var hover = false
var hover_obj = null

var connection_matrix = [Vector3(), Vector3(), Vector3(), Vector3()]
var state_matrix_left = [Vector3(), Vector3(), Vector3(), Vector3()]
var state_matrix_center = [Vector3(), Vector3(), Vector3(), Vector3()]
var state_matrix_right = [Vector3(), Vector3(), Vector3(), Vector3()]
var state_matrix_none = [Vector3(), Vector3(), Vector3(), Vector3()]

onready var track_material = preload("res://layout_cell_shader.tres")

signal track_selected(cell, orientation)

func _init(p_x_idx, p_y_idx):
	x_idx = p_x_idx
	y_idx = p_y_idx
	
	position = Vector2(x_idx, y_idx)*LayoutInfo.spacing
	
func _ready():
	material = track_material.duplicate()
	material.set_shader_param("connections", transform_from_matrix(connection_matrix))
	material.set_shader_param("state_left", transform_from_matrix(state_matrix_left))
	material.set_shader_param("state_center", transform_from_matrix(state_matrix_center))
	material.set_shader_param("state_right", transform_from_matrix(state_matrix_right))
	material.set_shader_param("state_none", transform_from_matrix(state_matrix_none))
	material.set_shader_param("has_switch", false)
	_on_settings_colors_changed()
	Settings.connect("colors_changed", self, "_on_settings_colors_changed")

func _on_settings_colors_changed():
	material.set_shader_param("background", Settings.colors["background"])
	material.set_shader_param("grid_color", Settings.colors["surface"])
	material.set_shader_param("track_base", Settings.colors["white"])
	material.set_shader_param("track_inner", Settings.colors["surface"])
	material.set_shader_param("selected_color", Settings.colors["tertiary"])
	material.set_shader_param("block_color", Settings.colors["primary"])
	material.set_shader_param("switch_color", Settings.colors["primary"])
	material.set_shader_param("occupied_color", Settings.colors["tertiary"].darkened(0.3))

func hover_at(pos):
	
	if not hover:
		set_hover(true)
	
	if LayoutInfo.drawing_track:
		LayoutInfo.draw_track_hover_cell(self)
		if hover_obj != null:
			hover_obj.stop_hover()
			set_hover_obj(null)
		return
	
	if LayoutInfo.drag_select:
		LayoutInfo.drag_select_hover_cell(self)
		if hover_obj != null:
			hover_obj.stop_hover()
			set_hover_obj(null)
		return

	var normalized_pos = pos/LayoutInfo.spacing
	var hover_candidate = null
	hover_candidate = get_obj_at(normalized_pos)
	if hover_candidate != hover_obj and hover_obj != null:
		hover_obj.stop_hover()
	set_hover_obj(hover_candidate)
	if hover_obj != null:
		if hover:
			set_hover(false)
		hover_obj.hover(normalized_pos)

func set_hover_obj(obj):
	if hover_obj != null:
		hover_obj.disconnect("removing", self, "_on_hover_obj_removing")
	if obj!=null:
		obj.connect("removing", self, "_on_hover_obj_removing")
	hover_obj = obj

func _on_hover_obj_removing(id):
	set_hover_obj(null)

func stop_hover():
	if hover_obj != null:
		hover_obj.stop_hover()
		set_hover_obj(null)
		return
	
	set_hover(false)


func process_mouse_button(event, pos):
	var normalized_pos = pos/LayoutInfo.spacing
	
	var obj = get_obj_at(normalized_pos)
	if obj != null:
		obj.process_mouse_button(event, normalized_pos)
		return
	if event.button_index == BUTTON_LEFT:
		if event.pressed:
			if LayoutInfo.input_mode == "draw":
				LayoutInfo.init_draw_track(self)
				return

func get_obj_at(normalized_pos):
	var i = 0
	var closest_dist = LayoutInfo.spacing+1
	var closest_track = null
	for track in tracks.values():
		var dist = track.distance_to(normalized_pos)
		if dist<closest_dist:
			closest_track = track
			closest_dist = dist
	if closest_track == null:
		return null
	if closest_dist > 3*0.126:
		return null
	if closest_dist > 0.126 or LayoutInfo.drag_train:
		var block = closest_track.get_logical_block()
		if block == null:
			return null
		return block
	return closest_track

func create_track_at(pos, direction=null):
	var i = 0
	var closest_dist = LayoutInfo.spacing+1
	var closest_track = null
	var normalized_pos = pos/LayoutInfo.spacing
	for orientation in LayoutInfo.orientations:
		var track = LayoutTrack.new(orientation[0], orientation[1], x_idx, y_idx)
		if direction!= null:
			if track.get_direction()!=direction:
				continue
		var dist = track.distance_to(normalized_pos)
		if dist<closest_dist:
			closest_track = track
			closest_dist = dist
	return closest_track

func get_slot_to_cell(cell):
	if cell.x_idx == x_idx+1 and cell.y_idx == y_idx:
		return "E"
	if cell.x_idx == x_idx-1 and cell.y_idx == y_idx:
		return "W"
	if cell.x_idx == x_idx and cell.y_idx == y_idx+1:
		return "S"
	if cell.x_idx == x_idx and cell.y_idx == y_idx-1:
		return "N"
	return null

func get_turn_track_from(slot, turn):
	for track in tracks.values():
		if not slot in track.connections:
			continue
		if track.get_turn_from(slot) == turn:
			return track
	assert(false)
	
func create_track(slot0, slot1):
	var track = LayoutTrack.new(slot0, slot1, x_idx, y_idx)
	return track
	
func add_track(track):
	add_child(track)
	if track.get_orientation() in tracks:
		print("can't add track, same orientation already occupied!")
		return tracks[track.get_orientation()]
	tracks[track.get_orientation()] = track
	track.connect("connections_changed", self, "_on_track_connections_changed")
	track.connect("states_changed", self, "_on_track_states_changed")
	track.connect("switch_position_changed", self, "_on_track_connections_changed")
	track.connect("removing", self, "_on_track_removing")
	track.connect("selected", self, "_on_track_selected")
	# update()
	_on_track_connections_changed(track.get_orientation())
	return track

func _on_track_removing(orientation):
	var track = tracks[orientation]
	track.disconnect("connections_changed", self, "_on_track_connections_changed")
	track.disconnect("states_changed", self, "_on_track_states_changed")
	track.disconnect("switch_position_changed", self, "_on_track_connections_changed")
	track.disconnect("removing", self, "_on_track_removing")
	tracks.erase(orientation)
	if track == hover_obj:
		set_hover_obj(null)

	for to_slot in [track.slot0, track.slot1]:
		var from_slot = track.get_opposite_slot(to_slot)
		var to_slot_id = LayoutInfo.slot_index[to_slot]
		var from_slot_id = LayoutInfo.slot_index[from_slot]
		if to_slot_id == 3:
			to_slot_id = from_slot_id
		connection_matrix[from_slot_id][to_slot_id] = 0
		state_matrix_left[from_slot_id][to_slot_id] = 0
		state_matrix_right[from_slot_id][to_slot_id] = 0
		state_matrix_center[from_slot_id][to_slot_id] = 0
		state_matrix_none[from_slot_id][to_slot_id] = 0
		
	material.set_shader_param("state_left", transform_from_matrix(state_matrix_left))
	material.set_shader_param("state_center", transform_from_matrix(state_matrix_center))
	material.set_shader_param("state_right", transform_from_matrix(state_matrix_right))
	material.set_shader_param("state_none", transform_from_matrix(state_matrix_none))

func _on_track_selected(track):
	emit_signal("track_selected", self, track.get_orientation())

func clear():
	for track in tracks.values():
		track.remove()
		
func transform_from_matrix(matrix):
	return Transform(matrix[0], matrix[1], matrix[2], matrix[3])

func set_hover(p_hover):
	hover = p_hover
	update_state()

func update_state():
	material.set_shader_param("cell_hover", hover)

func _on_track_connections_changed(orientation):
	var has_switch = false
	for track in tracks.values():
		if track.has_switch() or track.borders_switch():
			has_switch=true
	material.set_shader_param("has_switch", has_switch)
	_on_track_states_changed(orientation)
	# update()

func _on_track_states_changed(orientation=null):
	var track = tracks[orientation]
	for to_slot in [track.slot0, track.slot1]:
		var from_slot = track.get_opposite_slot(to_slot)
		var to_slot_id = LayoutInfo.slot_index[to_slot]
		var from_slot_id = LayoutInfo.slot_index[from_slot]
		if to_slot_id == 3:
			to_slot_id = from_slot_id
		var states = track.get_shader_states(to_slot)
		
		state_matrix_left[from_slot_id][to_slot_id] = states["left"]
		state_matrix_right[from_slot_id][to_slot_id] = states["right"]
		state_matrix_center[from_slot_id][to_slot_id] = states["center"]
		state_matrix_none[from_slot_id][to_slot_id] = states["none"]
	
			
	material.set_shader_param("state_left", transform_from_matrix(state_matrix_left))
	material.set_shader_param("state_center", transform_from_matrix(state_matrix_center))
	material.set_shader_param("state_right", transform_from_matrix(state_matrix_right))
	material.set_shader_param("state_none", transform_from_matrix(state_matrix_none))

func _draw():
	var spacing = LayoutInfo.spacing
	draw_rect(Rect2(Vector2(0,0), Vector2(spacing, spacing)), Color.black)
	
	# for debugging interpolation, uncomment update() calls
	for track in tracks.values():
		for slot in track.connections:
			for turn in track.connections[slot]:
				# var params = track.get_interpolation_parameters(slot, turn)
				# if not is_equal_approx(params.radius, 0.0):
				# 	draw_circle(spacing*params.center, spacing*params.radius, Color.red)
				for t in [0.0, 0.1666, 0.333, 0.5, 0.666, 0.8333, 1.0]:
					var pos = track.interpolate_track_connection(track.connections[slot][turn], t, true)
					# var pos = track.interpolate_connection(slot, turn, t, true)
					draw_circle(spacing*pos, spacing*0.03, Color.white)
