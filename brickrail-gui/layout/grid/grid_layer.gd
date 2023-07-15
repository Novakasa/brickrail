
class_name GridLayer
extends Node2D

var bounds

signal size_changed()

func _ready():
	bounds = null
	var _err
	_err = connect("size_changed", Callable(self, "update"))
	_err = LayoutInfo.connect("layout_mode_changed", Callable(self, "_on_layout_mode_changed"))
	_err = Settings.connect("colors_changed", Callable(self, "_on_settings_colors_changed"))

func _on_settings_colors_changed():
	queue_redraw()

func _on_layout_mode_changed(_mode):
	queue_redraw()

func add_cell(cell: LayoutCell):
	add_child(cell)
	var _err = cell.connect("tracks_changed", Callable(self, "_on_cell_tracks_changed").bind(cell))

func _on_cell_tracks_changed(cell):
	if len(cell.tracks)>0:
		if bounds == null:
			bounds = Rect2(cell.position, Vector2() + Vector2(1.0, 1.0)*LayoutInfo.spacing)
			return
		bounds = bounds.expand(cell.position + Vector2(1.0, 1.0)*LayoutInfo.spacing)
		bounds = bounds.expand(cell.position)
	else:
		bounds = null
		for _cell in get_children():
			if not _cell is LayoutCell:
				continue
			if len(_cell.tracks)>0:
				if bounds == null:
					bounds = Rect2(_cell.position, Vector2() + Vector2(1.0, 1.0)*LayoutInfo.spacing)
				bounds = bounds.expand(_cell.position)
				bounds = bounds.expand(_cell.position + Vector2(1.0, 1.0)*LayoutInfo.spacing)
	emit_signal("size_changed")

func get_size():
	if bounds == null:
		return Vector2(5.0, 5.0)*LayoutInfo.spacing
	return bounds.size

func get_pos():
	if bounds == null:
		return Vector2()
	return bounds.position

func has_point(point):
	if bounds == null:
		return Rect2(get_pos(), get_size()).grow(LayoutInfo.spacing*0.0).has_point(point)
	return bounds.grow(LayoutInfo.spacing*0.0).has_point(point)

func _draw():
	if LayoutInfo.layout_mode == "control":
		return
	var spacing = LayoutInfo.spacing
	var pos = get_pos()
	var end = pos + get_size()
	
	var x = pos.x
	while x < end.x + spacing*0.5:
		draw_line(Vector2(x, pos.y), Vector2(x, end.y), Settings.colors["surface"], 0.1*spacing)
		x += spacing
	
	var y = pos.y
	while y < end.y + spacing*0.5:
		draw_line(Vector2(pos.x, y), Vector2(end.x, y), Settings.colors["surface"], 0.1*spacing)
		y += spacing
