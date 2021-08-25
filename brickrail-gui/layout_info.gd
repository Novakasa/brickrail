tool
extends Node

var grid = null

var cells = []
var blocks = {}

var BlockScene = preload("res://layout_block.tscn")

var spacing = 1024.0
var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
var pretty_tracks = true
var slot_index = {"N": 0, "E": 1, "S": 2, "W": 3}
var slot_positions = {"N": Vector2(0.5,0), "S": Vector2(0.5,1), "E": Vector2(1,0.5), "W": Vector2(0,0.5)}

var input_mode = "select"
var selection = null

var drawing_track = false
var drawing_last = null
var drawing_last2 = null
var drawing_last_track = null
var drawing_mode = null

var drag_select = false
var drag_selection = null

signal input_mode_changed(mode)
signal selected(obj)

func serialize():
	var result = {}
	result["nx"] = len(cells)
	result["ny"] = len(cells[0])
	
	var tracks = []
	for row in cells:
		for cell in row:
			for track in cell.tracks.values():
				tracks.append(track.serialize())
	
	result["tracks"] = tracks
	return result

func clear():
	unselect()
	for blockname in blocks:
		blocks[blockname].queue_free()
		blocks.erase(blockname)
	for row in cells:
		for cell in row:
			for track in cell.tracks.values():
				track.remove()

func load(struct):
	clear()
	
	for track in struct.tracks:
		var i = track.x_idx
		var j = track.y_idx
		var track_obj = cells[i][j].create_track(track.slot0, track.slot1)
		cells[i][j].add_track(track_obj)
	
	for track in struct.tracks:
		var i = track.x_idx
		var j = track.y_idx
		var orientation = track.slot0 + track.slot1
		var track_obj = cells[i][j].tracks[orientation]
		track_obj.load_connections(track.connections)

func create_block(p_name, section):
	var block = BlockScene.instance()
	block.setup(p_name)
	blocks[p_name] = block
	block.set_section(section)
	grid.add_child(block)

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_Q:
				set_input_mode("control")
			if event.scancode == KEY_W:
				set_input_mode("select")
			if event.scancode == KEY_E:
				set_input_mode("draw")
			
			if event.scancode == KEY_DELETE:
				if selection is LayoutSection:
					var tracks = Array(selection.tracks)
					selection.unselect()
					for track in tracks:
						track.remove()
					

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

func set_input_mode(mode):
	input_mode = mode
	emit_signal("input_mode_changed", mode)

func unselect():
	if selection != null:
		selection.unselect()
	

func select(obj):
	unselect()
	selection = obj
	obj.connect("tree_exiting", self, "_on_selection_tree_exiting")
	obj.connect("unselected", self, "_on_selection_unselected")
	emit_signal("selected", obj)

func _on_selection_tree_exiting():
	selection.unselect()

func _on_selection_unselected():
	selection.disconnect("tree_exiting", self, "_on_selection_tree_exiting")
	selection.disconnect("unselected", self, "_on_selection_unselected")
	selection = null

func _on_drawing_last_track_removing(orientation):
	drawing_last_track.disconnect("removing", self, "_on_drawing_last_track_removing")
	drawing_last_track = null

func set_drawing_last_track(track):
	if drawing_last_track != null:
		drawing_last_track.disconnect("removing", self, "_on_drawing_last_track_removing")
	if track != null:
		track.connect("removing", self, "_on_drawing_last_track_removing")
	drawing_last_track = track

func init_draw_track(cell):
	drawing_track = true
	drawing_last = cell
	drawing_last2 = null
	set_drawing_last_track(null)

func init_connected_draw_track(track):
	var cell = cells[track.x_idx][track.y_idx]
	init_draw_track(cell)
	set_drawing_last_track(track)

func init_drag_select(track):
	drag_selection = LayoutSection.new()
	drag_selection.select()
	drag_selection.add_track(track)
	drag_select = true
	drawing_last = cells[track.x_idx][track.y_idx]
	drawing_last2 = null
	set_drawing_last_track(null)

func draw_track_hover_cell(cell):
	if not cell == drawing_last:
		var line = bresenham_line(drawing_last.x_idx, drawing_last.y_idx, cell.x_idx, cell.y_idx)
		for p in line:
			draw_track_add_cell(cells[p[0]][p[1]])
	
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

func drag_select_hover_cell(cell):
	if not cell == drawing_last:
		var line = bresenham_line(drawing_last.x_idx, drawing_last.y_idx, cell.x_idx, cell.y_idx)
		for p in line:
			draw_select(cells[p[0]][p[1]])

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
		track = drawing_last.tracks[track.get_orientation()]
		if drag_selection == null:
			drag_selection = LayoutSection.new()
			drag_selection.select()
			drag_selection.connect("unselected", self, "_on_drawing_section_unselected")
			drag_selection.name="drag_selection"
			add_child(drag_selection)
		else:
			if not drag_selection.can_add_track(track):
				return
		drag_selection.add_track(track)
		drawing_last2 = drawing_last
		drawing_last = draw_cell
	elif drag_selection == null:
		drawing_last2 = drawing_last
		drawing_last = draw_cell
