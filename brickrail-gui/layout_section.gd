class_name LayoutSection
extends Node

var tracks = []
var directed_tracks = []
var selected = false
var hover = false

signal selected
signal unselected

var LayoutSectionInspector = preload("res://layout_section_inspector.tscn")
var ThisClass = get_script()

func serialize():
	var result = {}
	var track_data = []
	for track in tracks:
		track_data.append(track.serialize(true))
	result["tracks"] = track_data
	return result

func load(struct):
	for track_data in struct["tracks"]:
		var track = LayoutInfo.get_track_from_struct(track_data)
		add_track(track)

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

func collect_segment(directed_track=null):
	if directed_track == null:
		assert(len(tracks)==1)
		directed_track = directed_tracks[0]
	else:
		assert(len(tracks)==0)
		add_track(directed_track)
	var iter_track = directed_track.get_next()
	while iter_track != null:
		if iter_track in directed_tracks:
			break
		add_track(iter_track)
		iter_track = iter_track.get_next()

func add_track(track):
	if track is DirectedLayoutTrack:
		track = track.track

	if len(tracks)>0:
		var last_track = tracks[-1]
		var prev_slot = track.get_connected_slot(last_track)
		if prev_slot == null:
			push_error("[LayoutSegment] track to add is not connected to last track!")
			assert(false)
		if len(tracks) > 1:
			if prev_slot != track.get_neighbour_slot(get_stop_slot()):
				push_error("[LayoutSegment] track to add is not connected in correct slot!")
				assert(false)
		
		directed_tracks.append(track.get_directed_from(prev_slot))
		
		if len(tracks) == 1:
			var track0 = tracks[0]
			directed_tracks[0] = track0.get_directed_to(track0.get_neighbour_slot(prev_slot))
	else:
		directed_tracks.append(DirectedLayoutTrack.new(track, track.slot0))
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
	return directed_tracks[0].prev_slot

func get_stop_slot():
	return directed_tracks[-1].next_slot

func select():
	LayoutInfo.select(self)
	selected = true
	set_track_attributes("selected", true)
	emit_signal("selected")

func unset_track_attributes(key):
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
