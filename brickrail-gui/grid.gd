extends Node2D

export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var hover_cell = null

var dragging_view = false
var dragging_view_reference = null
var dragging_view_camera_reference = null

signal grid_view_changed(p_pretty_tracks)

func setup_grid():
	for i in range(nx):
		LayoutInfo.cells.append([])
		for j in range(ny):
			LayoutInfo.cells[i].append(LayoutCell.new(i, j))
			add_child(LayoutInfo.cells[i][j])
			connect("grid_view_changed", LayoutInfo.cells[i][j], "_on_grid_view_changed")
			LayoutInfo.cells[i][j].connect("track_selected", self, "_on_cell_track_selected")

func _ready():
	LayoutInfo.grid = self
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
	var mpos_cell = mpos-LayoutInfo.cells[i][j].position
	if event is InputEventMouseMotion:
		process_mouse_motion(event, i, j, mpos_cell)
	if event is InputEventMouseButton:
		process_mouse_button(event, i, j, mpos_cell)

func process_mouse_motion(event, i, j, mpos_cell):
	if dragging_view:
		$Camera2D.position = $Camera2D.zoom*(dragging_view_reference-event.position) + dragging_view_camera_reference

	if hover_cell != null && hover_cell != LayoutInfo.cells[i][j]:
		hover_cell.stop_hover()
	hover_cell = LayoutInfo.cells[i][j]
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
	
	if event.button_index == BUTTON_LEFT:
		if not event.pressed:
			LayoutInfo.drawing_track = false
			LayoutInfo.drag_select = false

	LayoutInfo.cells[i][j].process_mouse_button(event, mpos_cell)
