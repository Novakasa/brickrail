extends Node2D

export var spacing = 64.0
export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var cells = []
var hover_cell = null

func setup_grid():
	for i in range(nx):
		cells.append([])
		for j in range(ny):
			cells[i].append(LayoutCell.new(i, j, spacing))
			add_child(cells[i][j])

func _ready():
	setup_grid()

func _draw():
	
	for i in range(nx+1):
		var start = Vector2(i*spacing, 0.0)
		var end = Vector2(i*spacing, ny*spacing)
		draw_line(start, end, grid_line_color, grid_line_width, true)
	
	for j in range(ny+1):
		var start = Vector2(0.0, j*spacing)
		var end = Vector2(nx*spacing, j*spacing)
		draw_line(start, end, grid_line_color, grid_line_width, true)

func _input(event):
	if event is InputEventMouse:
		var mpos = event.position
		var i = int(mpos.x/spacing)
		var j = int(mpos.y/spacing)
		if not (i>0 and i<nx and j>0 and j<ny):
			return
		var mpos_cell = mpos-cells[i][j].position
		if event is InputEventMouseMotion:
			if hover_cell != null:
				hover_cell.stop_hover()
			hover_cell = cells[i][j]
			hover_cell.hover_at(mpos_cell)
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			get_tree().set_input_as_handled()
			var track = cells[i][j].create_track_at(mpos_cell)
			cells[i][j].add_track(track)

