extends Node2D

@export var grid_line_color: Color
@export var grid_line_width: float

var hover_obj = null

var dragging_view = false
var dragging_view_reference = null
var dragging_view_camera_reference = null

@onready var LayoutCell = preload("res://layout/grid/layout_cell.tscn")

func _on_layer_added(l):
	var layer = GridLayer.new()
	layer.name = "layer" + str(l)
	add_child(layer)
	var _err = layer.connect("size_changed", Callable(self, "_on_layer_size_changed").bind(layer))
	set_layer_positions()

func _on_layer_size_changed(layer):
	var prev_pos = layer.position
	set_layer_positions()
	$Camera2D.position += layer.position - prev_pos

func _on_layer_removed(l):
	var layer = get_layer(l)
	remove_child(layer)
	layer.disconnect("size_changed", Callable(self, "_on_layer_size_changed"))
	layer.queue_free()
	set_layer_positions()

func get_layer(l):
	return get_node("layer"+str(l))
	
func set_layer_visibility():
	for l in LayoutInfo.cells.keys():
		var layer = get_layer(l)
		if l == LayoutInfo.active_layer:
			layer.visible=true
		else:
			layer.visible=LayoutInfo.layers_unfolded

func set_layer_positions():
	var layer_pos = Vector2()
	for l in LayoutInfo.cells:
		var layer = get_layer(l)
		layer_pos.y -= layer.get_size().y+LayoutInfo.spacing*0.56
		layer.position = Vector2()
		if LayoutInfo.layers_unfolded:
			layer.position = layer_pos-layer.get_pos()
	LayoutInfo.emit_signal("layer_positions_changed")

func _on_cell_added(cell):
	var layer = get_layer(cell.l_idx)
	layer.add_cell(cell)

func _ready():
	
	var _err = LayoutInfo.connect("cell_added", Callable(self, "_on_cell_added"))
	_err = LayoutInfo.connect("layer_removed", Callable(self, "_on_layer_removed"))
	_err = LayoutInfo.connect("layer_added", Callable(self, "_on_layer_added"))
	_err = LayoutInfo.connect("active_layer_changed", Callable(self, "_on_active_layer_changed"))
	_err = LayoutInfo.connect("layers_unfolded_changed", Callable(self, "_on_layers_unfolded_changed"))
	LayoutInfo.grid = self
	
	LayoutInfo.add_layer(0)
	LayoutInfo.set_layout_changed(false)

func _on_active_layer_changed(l):
	set_layer_visibility()
	if l == null:
		return
	if LayoutInfo.layers_unfolded:
		$Camera2D.position = get_layer(l).position + get_layer(l).get_pos() - Vector2(1.0, 1.0)*LayoutInfo.spacing

func _on_layers_unfolded_changed(_dummy=null):
	var prev_pos = null
	if LayoutInfo.active_layer != null:
		prev_pos = get_layer(LayoutInfo.active_layer).position
	set_layer_positions()
	set_layer_visibility()
	if LayoutInfo.active_layer != null and prev_pos != null:
		var new_pos = get_layer(LayoutInfo.active_layer).position
		$Camera2D.position += new_pos - prev_pos

func _unhandled_input(event):
	process_input(event)

func process_input(event):
	
	if event is InputEventKey and event.pressed:
		process_key_input(event)
	
	if event is InputEventMouse:
		process_mouse_input(event)

func process_key_input(_event):
	pass

func get_input_layer(world_mouse):
	if not LayoutInfo.layers_unfolded:
		return LayoutInfo.active_layer
	if LayoutInfo.drawing_track:
		if LayoutInfo.drawing_last != null:
			return LayoutInfo.drawing_last.l_idx
		
	for l_idx in LayoutInfo.cells.keys():
		var layer = get_layer(l_idx)
		if layer.has_point(world_mouse - layer.position):
			return l_idx
	
	return null

func process_mouse_input(event):
	var spacing = LayoutInfo.spacing
	var mouse_world = get_viewport_transform().affine_inverse()*event.position
	var l = get_input_layer(mouse_world)
	var mpos = mouse_world
	if l != null:
		mpos -= get_layer(l).position

	var i = int(mpos.x/spacing)
	var j = int(mpos.y/spacing)
	if mpos.x<0.0:
		i -= 1
	if mpos.y<0.0:
		j -= 1
	var mpos_cell = mpos-LayoutInfo.spacing*Vector2(i,j)
	if event is InputEventMouseMotion:
		process_mouse_motion(event, l, i, j, mpos_cell, mpos, mouse_world)
	if event is InputEventMouseButton:
		process_mouse_button(event, l, i, j, mpos_cell, mpos, mouse_world)

func process_mouse_motion(event, l, i, j, mpos_cell, mpos, mouse_world):
	if dragging_view:
		$Camera2D.position = $Camera2D.zoom*(dragging_view_reference-event.position) + dragging_view_camera_reference
	if l == null:
		set_hover_obj(null)
		return
	
	for train in LayoutInfo.trains.values():
		if train.has_point(mouse_world):
			if train.virtual_train.l_idx != l and LayoutInfo.layers_unfolded:
				continue
			if train != hover_obj:
				set_hover_obj(train)
			train.hover_at(mpos)
			return
	
	var cell = LayoutInfo.get_cell(l, i, j)
	if cell != hover_obj:
		set_hover_obj(cell)
	cell.hover_at(mpos_cell)

func set_hover_obj(obj):
	if hover_obj != null:
		# prints("disconnecting signal from hover_obj", hover_obj)
		hover_obj.disconnect("removing", Callable(self, "_on_hover_obj_removing"))
		hover_obj.stop_hover()
	hover_obj = obj
	if hover_obj != null:
		# prints("connecting signal to hover_obj", hover_obj)
		hover_obj.connect("removing", Callable(self, "_on_hover_obj_removing"))

func _on_hover_obj_removing(_obj):
	# print("hover obj removing!")
	set_hover_obj(null)

func stop_hover():
	if hover_obj != null:
		hover_obj.stop_hover()

func start_drag_view(event):
	dragging_view = true
	dragging_view_reference = event.position
	dragging_view_camera_reference = $Camera2D.position

func stop_drag_view():
	dragging_view = false

func process_mouse_button(event, l, i, j, mpos_cell, _mpos, mouse_world):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		$Camera2D.position += event.position*0.05*$Camera2D.zoom
		$Camera2D.zoom*=0.95
		return
		
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		$Camera2D.zoom*=1.05
		$Camera2D.position -= event.position*0.05*$Camera2D.zoom
		return
	
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			start_drag_view(event)
			return
		else:
			if dragging_view:
				stop_drag_view()
				return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if LayoutInfo.drag_train:
				LayoutInfo.flip_drag_train_facing()
				return
	
	if l != null:
		for train in LayoutInfo.trains.values():
			if train.has_point(mouse_world):
				if train.process_mouse_button(event, mouse_world):
					return true
		
		if LayoutInfo.get_cell(l, i, j).process_mouse_button(event, mpos_cell):
			return true

	if not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if LayoutInfo.drag_select:
				LayoutInfo.stop_drag_select()
			if dragging_view:
				stop_drag_view()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if LayoutInfo.drawing_track:
				LayoutInfo.stop_draw_track()
			if LayoutInfo.drag_train:
				LayoutInfo.stop_drag_train()
	else:
		if event.button_index == MOUSE_BUTTON_LEFT:
			LayoutInfo.deselect()
			start_drag_view(event)
		
