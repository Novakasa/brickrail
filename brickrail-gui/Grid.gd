extends Node2D

export var spacing = 64.0
export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var cells = []
var hover_cell = null
var drawing_track = false
var direction = 0
var drawing_last = null
var drawing_last2 = null
var drawing_last_track = null

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
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_PERIOD:
			direction += 1
			while direction>3:
				direction-=4
		
		if event.scancode == KEY_COMMA:
			direction -= 1
			while direction<0:
				direction+=4
	
	if event is InputEventMouse:
		var mpos = event.position
		var i = int(mpos.x/spacing)
		var j = int(mpos.y/spacing)
		if not (i>=0 and i<nx and j>=0 and j<ny):
			return
		var mpos_cell = mpos-cells[i][j].position
		if event is InputEventMouseMotion:
			if hover_cell != null:
				hover_cell.stop_hover()
			if drawing_track:
				if not cells[i][j] == drawing_last:
					if cells[i][j] == drawing_last2:
						drawing_last2 = null
					if drawing_last2 != null:
						var slot0 = drawing_last.get_slot_to_cell(drawing_last2)
						var slot1 = drawing_last.get_slot_to_cell(cells[i][j])
						if slot1 == null or slot0 == null:
							drawing_last = cells[i][j]
							drawing_last2 = null
							return
						var track = drawing_last.create_track(slot0, slot1)
						drawing_last.add_track(track)
						drawing_last_track = track
					drawing_last2 = drawing_last
					drawing_last = cells[i][j]
			else:
				hover_cell = cells[i][j]
				hover_cell.hover_at(mpos_cell, direction)
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
			get_tree().set_input_as_handled()
			var track = cells[i][j].create_track_at(mpos_cell, direction)
			cells[i][j].add_track(track)
			drawing_last = cells[i][j]
			drawing_last2 = null
			drawing_track = true
			
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
			drawing_track = false
