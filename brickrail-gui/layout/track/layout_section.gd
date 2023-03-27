class_name LayoutSection
extends Reference

var tracks = []
var selected = false
var hover = false

signal selected
signal unselected
signal track_added(track)
signal sensor_changed()

var LayoutSectionInspector = preload("res://layout/track/layout_section_inspector.tscn")

func serialize():
	var result = {}
	var track_data = []
	for track in tracks:
		track_data.append(track.serialize(true))
	result["tracks"] = track_data
	return result

func load(struct):
	for track_data in struct["tracks"]:
		if LayoutInfo.is_struct_dirtrack(track_data):
			var dirtrack = LayoutInfo.get_dirtrack_from_struct(track_data)
			add_dirtrack(dirtrack)
		else:
			var track = LayoutInfo.get_track_from_struct(track_data)
			add_track(track)

func can_add_track(track):
	if len(tracks)>0:
		if track is DirectedLayoutTrack:
			return track in tracks[-1].get_next_tracks()
		
		for dirtrack in track.get_dirtracks():
			if dirtrack in tracks[-1].get_next_tracks():
				return true
		return false
	return true

func copy():
	var section = get_script().new()
	for track in tracks:
		section.add_track(track)
	return section

func flip():
	var section = get_script().new()
	for i in range(len(tracks)-1, -1, -1):
		# print(i)
		section.add_track(tracks[i].get_opposite())
	
	var j = len(tracks)-1
	for track in tracks:
		var other = section.tracks[j]
		printt(track.id, other.id)
		j-=1
	assert(section.tracks[0].get_opposite() == tracks[-1])
	assert(section.tracks[-1].get_opposite() == tracks[0])
	return section

func append(section):
	if len(tracks)>0:
		# assert(section.tracks[0] in tracks[-1].get_next_tracks())
		pass
	for track in section.tracks:
		add_dirtrack(track)

func collect_segment(directed_track=null):
	if directed_track == null:
		assert(len(tracks)==1)
		directed_track = tracks[0]
	else:
		assert(len(tracks)==0)
		add_track(directed_track)
	var iter_track = directed_track.get_next_in_segment()
	while iter_track != null:
		if iter_track in tracks:
			break
		if iter_track.prohibited:
			break
		add_track(iter_track)
		iter_track = iter_track.get_next_in_segment()

func add_track(track):
	if selected:
		set_track_attributes("selected", false)
		set_track_attributes("arrow", -1, ">", "increment")

	if track is DirectedLayoutTrack:
		add_dirtrack(track)
		return

	if len(tracks)==0:
		add_dirtrack(track.get_dirtracks()[0])
		return

	for dirtrack in track.get_dirtracks():
		if dirtrack in tracks[-1].get_next_tracks():
			add_dirtrack(dirtrack)
			return
	
	assert(len(tracks)==1)
	
	tracks[0] = tracks[0].get_opposite()
	add_track(track)

func add_dirtrack(dirtrack):
	if len(tracks)>0 and false:
		assert(dirtrack in tracks[-1].get_next_tracks() or dirtrack == tracks[-1].get_opposite())
	
	tracks.append(dirtrack)
	
	if not dirtrack.is_connected("sensor_changed", self, "_on_track_sensor_changed"):
		dirtrack.connect("sensor_changed", self, "_on_track_sensor_changed")
	
	if selected:
		set_track_attributes("selected", true)
		set_track_attributes("arrow", 1, ">", "increment")
	
	emit_signal("track_added", tracks[-1])

func _on_track_sensor_changed(_slot):
	emit_signal("sensor_changed")

func get_sensor_dirtracks():
	var sensorlist = []
	for dirtrack in tracks:
		var sensor = dirtrack.get_sensor()
		if sensor != null:
			sensorlist.append(dirtrack)
	return sensorlist

func get_track_index(track):
	if track is DirectedLayoutTrack:
		return tracks.find(track)
	else:
		for slot in track.get_orientation():
			var dirtrack = track.get_directed_to(slot)
			if dirtrack in tracks:
				return tracks.find(dirtrack)
	return null

func get_start_slot():
	return tracks[0].prev_slot

func get_stop_slot():
	return tracks[-1].next_slot

func select():
	LayoutInfo.select(self)
	selected = true
	set_track_attributes("selected", true)
	set_track_attributes("arrow", 1, ">", "increment")
	emit_signal("selected")

func unset_track_attributes(key):
	set_track_attributes(key, null)

func set_track_attributes(key, value, direction="<>", operation="set"):
	if len(tracks)==0:
		return
	if len(tracks)==1:
		if "<" in direction:
			tracks[0].get_opposite().set_connection_attribute("none", key, value, operation)
		if ">" in direction:
			tracks[0].set_connection_attribute("none", key, value, operation)
		return
	var track0 = null
	for track1 in tracks:
		if track0 == null:
			track0 = track1
			continue
		if ">" in direction:
			track0.set_track_connection_attribute(track1, key, value, operation)
		if "<" in direction:
			track1.get_opposite().set_track_connection_attribute(track0, key, value, operation)
		track0 = track1
	
	if "<" in direction:
		tracks[0].get_opposite().set_connection_attribute("none", key, value, operation)
	if ">" in direction:
		tracks[-1].set_connection_attribute("none", key, value, operation)
	
func unselect():
	selected = false
	set_track_attributes("selected", false)
	set_track_attributes("arrow", -1, ">", "increment")
	emit_signal("unselected")

func get_inspector():
	var inspector = LayoutSectionInspector.instance()
	inspector.set_section(self)
	return inspector

func get_next_segments():
	var segments = []
	for track in tracks[-1].get_next_tracks():
		if track.prohibited:
			continue
		var segment = get_script().new()
		segment.collect_segment(track)
		segments.append(segment)
	return segments

func get_locked():
	var locked = []
	for track in tracks:
		var cell = LayoutInfo.get_cell(track.l_idx, track.x_idx, track.y_idx)
		for coll_track in cell.get_colliding_tracks(track.get_orientation()):
			for locked_train in coll_track.get_locked():
				if not locked_train in locked:
					locked.append(locked_train)
	return locked

func has_switch():
	for track in tracks:
		if track.get_switch()!=null:
			return true
		if track.get_opposite().get_switch()!=null:
			return true
	return false

func has_block():
	for track in tracks:
		if track.get_block() != null:
			return true
	return false

func has_connections():
	if len(tracks[-1].connections) == 0:
		return false
	if len(tracks[0].get_opposite().connections) == 0:
		return false
	return true

func is_connected_to(dirtrack):
	if dirtrack in tracks[-1].connections.values():
		return true
	if dirtrack in tracks[0].get_opposite().connections.values():
		return true
	return false

func get_block_blocked_reason():
	if not len(tracks)>1:
		return "Can't create block on sections with length < 2"
	if has_switch():
		return "Can't create block on sections with switches"
	if has_block():
		return "Can't create block on sections with other blocks"
	if not has_connections():
		return "Can't create block on sections with no connections"
	return null
