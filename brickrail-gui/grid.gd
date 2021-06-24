extends Node2D

export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var cells = []
var hover_cell = null
var drawing_track = false
var drawing_last = null
var drawing_last2 = null
var drawing_last_track = null
var drawing_mode = null
var drawing_section = null
var removing_track = false
var dragging_view = false
var dragging_view_reference = null
var dragging_view_camera_reference = null

signal grid_view_changed(p_pretty_tracks)

func setup_grid():
	for i in range(nx):
		cells.append([])
		for j in range(ny):
			cells[i].append(LayoutCell.new(i, j))
			add_child(cells[i][j])
			connect("grid_view_changed", cells[i][j], "_on_grid_view_changed")
			cells[i][j].connect("track_selected", self, "_on_cell_track_selected")

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

func _ready():
	setup_grid()

func _draw():
	
	var spacing = LayoutInfo.spacing
	
	for i in range(nx+1):
		var start = Vector2(i*spacing, 0.0)
		var end = Vector2(i*spacing, ny*spacing)
		draw_line(start, end, grid_line_color, grid_line_width, true)
	
	for j in range(ny+1):
		var start = Vector2(0.0, j*spacing)
		var end = Vector2(nx*spacing, j*spacing)
		draw_line(start, end, grid_line_color, grid_line_width, true)

func draw_track(draw_cell):
	if drawing_mode == "create":
		draw_create_track(draw_cell)
	if drawing_mode == "section":
		draw_select(draw_cell)

func _on_cell_track_selected(cell, orientation):
	if drawing_track and drawing_mode == "section":
		assert(drawing_section == null)
		drawing_section = LayoutSection.new()
		drawing_section.select()
		drawing_section.connect("unselected", self, "_on_drawing_section_unselected")
		drawing_section.name="drawing_section"
		add_child(drawing_section)
		drawing_section.add_track(cell.tracks[orientation])
		drawing_last2 = drawing_last
		drawing_last = cell
	
func draw_create_track(draw_track):
	if draw_track == drawing_last2:
		drawing_last2 = null
		drawing_last_track = null
	if drawing_last2 != null:
		var slot0 = drawing_last.get_slot_to_cell(drawing_last2)
		var slot1 = drawing_last.get_slot_to_cell(draw_track)
		if slot1 == null or slot0 == null:
			drawing_last = draw_track
			drawing_last2 = null
			drawing_last_track = null
			return
		var track = drawing_last.create_track(slot0, slot1)
		if not track.get_orientation() in drawing_last.tracks:
			track = drawing_last.add_track(track)
		else:
			track = drawing_last.tracks[track.get_orientation()]
		if drawing_last_track != null:
			if track.can_connect_track(slot0, drawing_last_track):
				track.connect_track(slot0, drawing_last_track)
		drawing_last_track = track
	drawing_last2 = drawing_last
	drawing_last = draw_track

func draw_select(draw_cell):
	
	if drawing_last2 == null:
		drawing_last2 = drawing_last
		drawing_last = draw_cell
		return

	var slot0 = drawing_last.get_slot_to_cell(drawing_last2)
	var slot1 = drawing_last.get_slot_to_cell(draw_cell)
	
	if slot1 == null or slot0 == null or slot1 == slot0:
		if drawing_section == null:
			drawing_last2 = null
			drawing_last = draw_cell
		return
	
	var track = drawing_last.create_track(slot0, slot1)
	if track.get_orientation() in drawing_last.tracks:
		track = drawing_last.tracks[track.get_orientation()]
		if drawing_section == null:
			drawing_section = LayoutSection.new()
			drawing_section.select()
			drawing_section.connect("unselected", self, "_on_drawing_section_unselected")
			drawing_section.name="drawing_section"
			add_child(drawing_section)
		else:
			if not drawing_section.can_add_track(track):
				return
		drawing_section.add_track(track)
		drawing_last2 = drawing_last
		drawing_last = draw_cell
	elif drawing_section == null:
		drawing_last2 = drawing_last
		drawing_last = draw_cell

func _on_drawing_section_unselected():
	clear_drawing_section()

func clear_drawing_section():
	if drawing_section == null:
		return
	get_node("drawing_section").queue_free()
	drawing_section = null

func _unhandled_input(event):
	process_input(event)

func process_input(event):
	
	if event is InputEventKey and event.pressed:
		process_key_input(event)
	
	if event is InputEventMouse:
		process_mouse_input(event)

func process_key_input(event):
	pass

func process_mouse_input(event):
	var spacing = LayoutInfo.spacing
	var mpos = get_viewport_transform().affine_inverse()*event.position
	var i = int(mpos.x/spacing)
	var j = int(mpos.y/spacing)
	if not (i>=0 and i<nx and j>=0 and j<ny):
		return
	var mpos_cell = mpos-cells[i][j].position
	if event is InputEventMouseMotion:
		process_mouse_motion(event, i, j, mpos_cell)
	if event is InputEventMouseButton:
		process_mouse_button(event, i, j, mpos_cell)

func process_mouse_motion(event, i, j, mpos_cell):
	if removing_track:
		cells[i][j].clear()
	if dragging_view:
		$Camera2D.position = $Camera2D.zoom*(dragging_view_reference-event.position) + dragging_view_camera_reference
	if drawing_track:
		if not cells[i][j] == drawing_last:
			var line = bresenham_line(drawing_last.x_idx, drawing_last.y_idx, i, j)
			for p in line:
				draw_track(cells[p[0]][p[1]])

	if hover_cell != null && hover_cell != cells[i][j]:
		hover_cell.stop_hover()
	hover_cell = cells[i][j]
	hover_cell.hover_at(mpos_cell)

func process_mouse_button(event, i, j, mpos_cell):
	if event.button_index == BUTTON_WHEEL_UP:
		$Camera2D.position += event.position*0.05*$Camera2D.zoom	
		$Camera2D.zoom*=0.95
		return
		
	if event.button_index == BUTTON_WHEEL_DOWN:
		$Camera2D.zoom*=1.05
		$Camera2D.position -= event.position*0.05*$Camera2D.zoom
		return

	if event.button_index == BUTTON_LEFT:
		if event.pressed:
			if LayoutInfo.input_mode == "draw" or LayoutInfo.input_mode == "select":
				drawing_last = cells[i][j]
				drawing_last2 = null
				drawing_track = true
				drawing_last_track = null #track
				if LayoutInfo.input_mode == "draw":
					drawing_mode = "create"
				else:
					drawing_mode = "section"
					clear_drawing_section()
		else:
			if drawing_track:
				drawing_track = false
				return
	
	if event.button_index == BUTTON_RIGHT:
		if event.pressed:
			if LayoutInfo.input_mode == "draw":
				removing_track = true
				cells[i][j].clear()
				return
		else:
			if removing_track:
				removing_track = false
				return
	
	if event.button_index == BUTTON_MIDDLE:
		if event.pressed:
			dragging_view = true
			dragging_view_reference = event.position
			dragging_view_camera_reference = $Camera2D.position
			return
		else:
			if dragging_view:
				dragging_view = false
				return
	cells[i][j].process_mouse_button(event, mpos_cell)
