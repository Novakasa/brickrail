extends Node2D

export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var hover_obj = null

var dragging_view = false
var dragging_view_reference = null
var dragging_view_camera_reference = null

onready var LayoutCell = preload("res://layout/grid/layout_cell.tscn")

func _on_layer_added(l):
	var layer = Node2D.new()
	layer.name = "layer" + str(l)
	add_child(layer)

func _on_layer_removed(l):
	var layer = get_layer(l)
	remove_child(layer)
	layer.queue_free()

func get_layer(l):
	return get_node("layer"+str(l))

func _on_cell_added(cell):
	var layer = get_layer(cell.l_idx)
	layer.add_child(cell)
	cell.connect("track_selected", self, "_on_cell_track_selected")

func _ready():
	
	var _err = LayoutInfo.connect("cell_added", self, "_on_cell_added")
	_err = LayoutInfo.connect("layer_removed", self, "_on_layer_removed")
	_err = LayoutInfo.connect("layer_added", self, "_on_layer_added")
	_err = LayoutInfo.connect("layout_mode_changed", self, "_on_layout_mode_changed")
	LayoutInfo.grid = self
	
	LayoutInfo.add_layer(0)
	LayoutInfo.set_layout_changed(false)

func _on_layout_mode_changed(_mode):
	update()

func _draw():
	if LayoutInfo.layout_mode == "control":
		return
	var spacing = LayoutInfo.spacing
	
	for i in range(nx+1):
		var start = Vector2(i*spacing, 0.0)
		var end = Vector2(i*spacing, ny*spacing)
		draw_line(start, end, Settings.colors["surface"]*0.8, 0.1*spacing, true)
	
	for j in range(ny+1):
		var start = Vector2(0.0, j*spacing)
		var end = Vector2(nx*spacing, j*spacing)
		draw_line(start, end, Settings.colors["surface"]*0.8, 0.1*spacing, true)

func _unhandled_input(event):
	process_input(event)

func process_input(event):
	
	if event is InputEventKey and event.pressed:
		process_key_input(event)
	
	if event is InputEventMouse:
		process_mouse_input(event)

func process_key_input(_event):
	pass

func process_mouse_input(event):
	var spacing = LayoutInfo.spacing
	var mpos = get_viewport_transform().affine_inverse()*event.position
	var i = int(mpos.x/spacing)
	var j = int(mpos.y/spacing)
	if not (i>=0 and i<nx and j>=0 and j<ny):
		return
	var mpos_cell = mpos-LayoutInfo.spacing*Vector2(i,j)
	if event is InputEventMouseMotion:
		process_mouse_motion(event, i, j, mpos_cell, mpos)
	if event is InputEventMouseButton:
		process_mouse_button(event, i, j, mpos_cell, mpos)

func process_mouse_motion(event, i, j, mpos_cell, mpos):
	var l = LayoutInfo.active_layer
	if dragging_view:
		$Camera2D.position = $Camera2D.zoom*(dragging_view_reference-event.position) + dragging_view_camera_reference
	
	for train in LayoutInfo.trains.values():
		if train.has_point(mpos):
			if train != hover_obj and hover_obj != null:
				hover_obj.stop_hover()
			set_hover_obj(train)
			train.hover_at(mpos)
			return
	
	var cell = LayoutInfo.get_cell(l, i, j)
	if cell != hover_obj and hover_obj != null:
		hover_obj.stop_hover()
	set_hover_obj(cell)
	cell.hover_at(mpos_cell)

func set_hover_obj(obj):
	if hover_obj != null:
		hover_obj.disconnect("removing", self, "_on_hover_obj_removing")
		hover_obj.stop_hover()
	hover_obj = obj
	if hover_obj != null:
		hover_obj.connect("removing", self, "_on_hover_obj_removing")

func _on_hover_obj_removing(_cell):
	hover_obj.disconnect("removing", self, "_on_hover_obj_removing")
	hover_obj = null

func stop_hover():
	if hover_obj != null:
		hover_obj.stop_hover()

func process_mouse_button(event, i, j, mpos_cell, mpos):
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
		if event.pressed:
			if LayoutInfo.drag_train:
				LayoutInfo.flip_drag_train_facing()
				return
	
	for train in LayoutInfo.trains.values():
		if train.has_point(mpos):
			if train.process_mouse_button(event, mpos):
				return true
	
	var l = LayoutInfo.active_layer
	LayoutInfo.get_cell(l, i, j).process_mouse_button(event, mpos_cell)
	
	# If we release the button outside of the grid, disable the hold modes.
	if not event.pressed:
		if event.button_index == BUTTON_LEFT:
			if LayoutInfo.drag_select:
				LayoutInfo.stop_drag_select()
		if event.button_index == BUTTON_RIGHT:
			if LayoutInfo.drawing_track:
				LayoutInfo.stop_draw_track()
			if LayoutInfo.drag_train:
				LayoutInfo.stop_drag_train()
