class_name LayoutSection
extends Node

var tracks = []
var selected = false
var hover = false

var start_slot = null
var stop_slot = null

signal selected
signal unselected

var LayoutSectionInspector = preload("res://layout_section_inspector.tscn")

func add_track(track):
	tracks.append(track)
	if selected:
		track.visual_select()

func select():
	LayoutInfo.select(self)
	selected = true
	for track in tracks:
		track.visual_select()
	emit_signal("selected")
	
func unselect():
	selected = false
	for track in tracks:
		track.visual_unselect()
	emit_signal("unselected")

func get_inspector():
	var inspector = LayoutSectionInspector.instance()
	inspector.set_section(self)
	return inspector
