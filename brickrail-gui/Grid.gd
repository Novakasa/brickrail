extends Node2D

export var spacing = 64.0
export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var cells = []

func setup_grid():
	for i in range(nx):
		cells.append([])
		for j in range(ny):
			cells[i].append(LayoutCell.new(i, j, spacing))

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
