class_name LayoutSection
extends Node

var tracks = []
var selected = false
var hover = false

signal selected
signal unselected

var LayoutSectionInspector = preload("res://layout_section_inspector.tscn")
var ThisClass = get_script()

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

func flip():
	var section = ThisClass.new()
	for i in range(len(tracks)-1, -1, -1):
		section.add_track(tracks[i])
	return section

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
		if len(tracks)>1:
			tracks[-2].set_track_connection_attribute(track, "selected", true)
			tracks[-2].set_connection_attribute(tracks[-2].get_connected_slot(track), "none", "selected", false)
			tracks[-2].set_track_connection_attribute(track, "selected", true)
			track.set_track_connection_attribute(tracks[-2], "selected", true)
			track.set_connection_attribute(get_stop_slot(), "none", "selected", true)
		else:
			tracks[0].set_connection_attribute(track.slot0, "none", "selected", true)
			tracks[-1].set_connection_attribute(track.slot1, "none", "selected", true)

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
	set_track_attributes("selected", true)
	emit_signal("selected")

func unset_track_attributes(key, value):
	set_track_attributes(key, null)

func set_track_attributes(key, value):
	if len(tracks)==0:
		return
	if len(tracks)==1:
		tracks[0].set_connection_attribute(tracks[0].slot0, "none", key, value)
		tracks[0].set_connection_attribute(tracks[0].slot1, "none", key, value)
		return
	var track0 = null
	for track1 in tracks:
		if track0 == null:
			track0 = track1
			continue
		track0.set_track_connection_attribute(track1, key, value)
		track1.set_track_connection_attribute(track0, key, value)
		track0 = track1
	
	tracks[0].set_connection_attribute(get_start_slot(), "none", key, value)
	tracks[-1].set_connection_attribute(get_stop_slot(), "none", key, value)
	
func unselect():
	selected = false
	set_track_attributes("selected", false)
	emit_signal("unselected")

func get_inspector():
	var inspector = LayoutSectionInspector.instance()
	inspector.set_section(self)
	return inspector
