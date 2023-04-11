
class_name LayoutCell
extends Node2D

var l_idx
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
var drawing_highlight = false


var _redraw=false

var track_material = preload("res://layout/grid/layout_cell_shader2.tres")

signal track_selected(cell, orientation)
signal removing(cell)
signal tracks_changed()

func setup(p_l_idx, p_x_idx, p_y_idx):
	l_idx = p_l_idx
	x_idx = p_x_idx
	y_idx = p_y_idx
	
	position = Vector2(x_idx, y_idx)*LayoutInfo.spacing

func remove():
	# print("removing cell")
	emit_signal("removing", self)
	# print("removing cell2")
	queue_free()
	
func _enter_tree():
	$RenderCache.scale = Vector2(1,1)*LayoutInfo.spacing / 64
	$RenderDynamic.scale = Vector2(1,1)*LayoutInfo.spacing / 64
	$RenderCacheViewport/Render.material = track_material.duplicate()
	$RenderDynamic.material = $RenderCacheViewport/Render.material
	set_shader_param("connections", transform_from_matrix(connection_matrix))
	set_shader_param("state_left", transform_from_matrix(state_matrix_left))
	set_shader_param("state_center", transform_from_matrix(state_matrix_center))
	set_shader_param("state_right", transform_from_matrix(state_matrix_right))
	set_shader_param("state_none", transform_from_matrix(state_matrix_none))
	set_shader_param("has_switch", false)
	_on_settings_colors_changed()
	var _err = Settings.connect("colors_changed", self, "_on_settings_colors_changed")
	_err = Settings.connect("render_mode_changed", self, "_on_settings_render_mode_changed")
	_err = LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")
	_on_layout_mode_changed(LayoutInfo.layout_mode)
	_on_settings_render_mode_changed(Settings.render_mode)
	_err = get_tree().connect("idle_frame", self, "_on_idle_frame")

func _on_idle_frame():
	if _redraw:
		_redraw=false
		# prints("redrawing cell at", x_idx, y_idx)
		$RenderCacheViewport.set_update_mode(Viewport.UPDATE_ONCE)

func _on_settings_render_mode_changed(mode):
	if mode == "dynamic":
		$RenderDynamic.visible=true
		$RenderCache.visible=false
	if mode == "cached":
		$RenderDynamic.visible=false
		$RenderCache.visible=true
		# $RenderDynamic.texture.size = Vector2(LayoutInfo.spacing, LayoutInfo.spacing)
		_redraw=true

func _on_layout_mode_changed(mode):
	if mode == "edit":
		# set_shader_param("grid_color", Settings.colors["surface"])
		set_shader_param("background", Color(0.0, 0.0, 0.0, 0.0))
	if mode == "control":
		# set_shader_param("grid_color", Settings.colors["background"])
		set_shader_param("background", Color(0.0, 0.0, 0.0, 0.0))

func _on_settings_colors_changed():
	# set_shader_param("background", Settings.colors["background"])
	# set_shader_param("background", Color(0.0, 0.0, 0.0, 0.0))
	set_shader_param("background_drawing_highlight", Settings.colors["tertiary"].linear_interpolate(Settings.colors["background"], 0.8))
		# set_shader_param("grid_color", Color(0.0, 0.0, 0.0, 0.0))
	set_shader_param("track_base", Settings.colors["white"])
	set_shader_param("track_inner", Settings.colors["surface"])
	set_shader_param("selected_color", Settings.colors["tertiary"])
	set_shader_param("block_color", Settings.colors["primary"])
	set_shader_param("switch_color", Settings.colors["primary"])
	set_shader_param("occupied_color", Settings.colors["secondary"])
	set_shader_param("arrow_color", Settings.colors["white"])
	set_shader_param("mark_color", Settings.colors["primary"].darkened(0.5))

func hover_at(pos):
	
	if not hover and LayoutInfo.layout_mode == "edit":
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
		if hover_obj.has_signal("removing"):
			hover_obj.disconnect("removing", self, "_on_hover_obj_removing")
	if obj!=null:
		if obj.has_signal("removing"):
			obj.connect("removing", self, "_on_hover_obj_removing")
	hover_obj = obj

func _on_hover_obj_removing(_id):
	set_hover_obj(null)

func stop_hover():
	if hover_obj != null:
		hover_obj.stop_hover()
		set_hover_obj(null)
		return
	
	set_hover(false)
	
	# if len(tracks) == 0:
	# 	remove()
	check_remove()

func check_remove():
	if len(tracks)>0:
		return
	if hover:
		return
	if drawing_highlight:
		return
	if self == LayoutInfo.drawing_last:
		return
	if self == LayoutInfo.drawing_last2:
		return
	remove()

func process_mouse_button(event, pos):
	var normalized_pos = pos/LayoutInfo.spacing
	
	var obj = get_obj_at(normalized_pos)
	if obj != null:
		obj.process_mouse_button(event, normalized_pos)
		return
	if event.button_index == BUTTON_RIGHT:
		if event.pressed:
			if LayoutInfo.layout_mode == "edit":
				LayoutInfo.init_draw_track(self)
				return

func get_obj_at(normalized_pos):
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
	var closest_dist = LayoutInfo.spacing+1
	var closest_track = null
	var normalized_pos = pos/LayoutInfo.spacing
	for orientation in LayoutInfo.orientations:
		var track = LayoutTrack.new(orientation[0], orientation[1], l_idx, x_idx, y_idx)
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

func get_neighbors():
	var neighbors = []
	neighbors.append(LayoutInfo.get_cell(l_idx, x_idx-1, y_idx))
	neighbors.append(LayoutInfo.get_cell(l_idx, x_idx, y_idx-1))
	neighbors.append(LayoutInfo.get_cell(l_idx, x_idx+1, y_idx))
	neighbors.append(LayoutInfo.get_cell(l_idx, x_idx, y_idx+1))
	return neighbors

func get_turn_track_from(slot, turn):
	for track in tracks.values():
		if not slot in track.directed_tracks:
			continue
		if track.get_turn_from(slot) == turn:
			return track
	assert(false)
	
func create_track(slot0, slot1):
	var track = LayoutTrack.new(slot0, slot1, l_idx, x_idx, y_idx)
	return track
	
func add_track(track):
	add_child(track)
	if track.get_orientation() in tracks:
		print("can't add track, same orientation already occupied!")
		return tracks[track.get_orientation()]
	tracks[track.get_orientation()] = track
	track.connect("connections_changed", self, "_on_track_connections_changed")
	track.connect("states_changed", self, "_on_track_states_changed")
	track.connect("removing", self, "_on_track_removing")
	# update()
	_on_track_connections_changed(track.get_orientation())
	LayoutInfo.set_layout_changed(true)
	emit_signal("tracks_changed")
	return track

func _on_track_removing(orientation):
	var track = tracks[orientation]
	track.disconnect("connections_changed", self, "_on_track_connections_changed")
	track.disconnect("states_changed", self, "_on_track_states_changed")
	track.disconnect("removing", self, "_on_track_removing")
	tracks.erase(orientation)
	if track == hover_obj:
		set_hover_obj(null)
	emit_signal("tracks_changed")

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
		
	set_shader_param("state_left", transform_from_matrix(state_matrix_left))
	set_shader_param("state_center", transform_from_matrix(state_matrix_center))
	set_shader_param("state_right", transform_from_matrix(state_matrix_right))
	set_shader_param("state_none", transform_from_matrix(state_matrix_none))

func _on_track_selected(track):
	emit_signal("track_selected", self, track.get_orientation())

func get_colliding_tracks(orientation):
	assert(orientation in tracks)
	var coll_tracks = []
	for track in tracks.values():
		if track.collides_with(tracks[orientation]):
			coll_tracks.append(track)
	return coll_tracks

func clear():
	for track in tracks.values():
		track.remove()
		
func transform_from_matrix(matrix):
	return Transform(matrix[0], matrix[1], matrix[2], matrix[3])

func set_hover(p_hover):
	hover = p_hover
	update_state()

func set_drawing_highlight(highlight):
	drawing_highlight = highlight
	update_state()
	
	check_remove()

func update_state():
	set_shader_param("cell_hover", hover)
	set_shader_param("cell_drawing_highlight", drawing_highlight)

func _on_track_connections_changed(orientation):
	var has_switch = false
	for track in tracks.values():
		if track.has_switch() or track.borders_switch():
			has_switch=true
	set_shader_param("has_switch", has_switch)
	_on_track_states_changed(orientation)
	LayoutInfo.set_layout_changed(true)
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
	
			
	set_shader_param("state_left", transform_from_matrix(state_matrix_left))
	set_shader_param("state_center", transform_from_matrix(state_matrix_center))
	set_shader_param("state_right", transform_from_matrix(state_matrix_right))
	set_shader_param("state_none", transform_from_matrix(state_matrix_none))

func set_shader_param(key, value):
	if Settings.render_mode == "cached":
		$RenderCacheViewport/Render.material.set_shader_param(key, value)
		_redraw=true
	if Settings.render_mode == "dynamic":
		$RenderDynamic.material.set_shader_param(key, value)
	# $RenderCacheViewport.update_worlds()

func _draw():
	# for debugging
	draw_circle(Vector2(0.5,0.5)*LayoutInfo.spacing, LayoutInfo.spacing*0.1, Color.black)
