extends Node

var spacing = 64.0
var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
var pretty_tracks = true
var slot_index = {"N": 0, "E": 1, "S": 2, "W": 3}
var slot_positions = {"N": Vector2(0.5,0), "S": Vector2(0.5,1), "E": Vector2(1,0.5), "W": Vector2(0,0.5)}

var input_mode = "select"
var selection = null

signal input_mode_changed(mode)
signal selected(obj)

func set_input_mode(mode):
	input_mode = mode
	emit_signal("input_mode_changed", mode)

func select(obj):
	if selection != null:
		selection.disconnect("tree_exiting", self, "_on_selection_tree_exiting")
		selection.unselect()
	selection = obj
	obj.connect("tree_exiting", self, "_on_selection_tree_exiting")
	emit_signal("selected", obj)

func _on_selection_tree_exiting():
	selection.unselect()
	selection = null
