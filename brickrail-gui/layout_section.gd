class_name LayoutSection
extends Node

var tracks = []
var selected = false
var hover = false

signal selected
signal unselected

var LayoutSectionInspector = preload("res://layout_section_inspector.tscn")

func can_add_track(track):
	if len(tracks)>0:
		var last_track = tracks[-1]
		var connected_slot = last_track.get_connected_slot(track)
		if connected_slot == null:
			return false
		if len(tracks) > 1:
			if connected_slot != get_stop_slot():
				return false
	return true

func add_track(track):
	if len(tracks)>0:
		var last_track = tracks[-1]
		var connected_slot = last_track.get_connected_slot(track)
		if connected_slot == null:
			push_error("[LayoutSegment] track to add is not connected to last track!")
			return
		if len(tracks) > 1:
			if connected_slot != get_stop_slot():
				push_error("[LayoutSegment] track to add is not connected in correct slot!")
				return
	tracks.append(track)
	
	if selected:
		track.visual_select()

func get_start_slot():
	if len(tracks) < 2:
		return null
	var last_track = tracks[0]
	var last_track2 = tracks[1]
	var connected_slot = last_track.get_connected_slot(last_track2)
	return last_track.get_opposite_slot(connected_slot)

func get_stop_slot():
	if len(tracks) < 2:
		return null
	var last_track = tracks[-1]
	var last_track2 = tracks[-2]
	var connected_slot = last_track.get_connected_slot(last_track2)
	return last_track.get_opposite_slot(connected_slot)

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
