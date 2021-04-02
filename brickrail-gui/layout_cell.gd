class_name LayoutCell
extends Node2D

var x_idx
var y_idx
var spacing
var tracks = {}
var hover_track = null
var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]

func _init(p_x_idx, p_y_idx, p_spacing):
	x_idx = p_x_idx
	y_idx = p_y_idx
	spacing = p_spacing
	
	position = Vector2(x_idx, y_idx)*spacing

func hover_at(pos):
	hover_track = create_track_at(pos)
	update()

func stop_hover():
	hover_track = null
	update()

func create_track_at(pos):
	var i = 0
	var closest_dist = spacing+1
	var closest_track = null
	var normalized_pos = pos/spacing
	for orientation in orientations:
		var track = LayoutTrack.new(orientation[0], orientation[1])
		var dist = track.distance_to(normalized_pos)
		if dist<closest_dist:
			closest_track = track
			closest_dist = dist
	return closest_track
	
func add_track(track):
	if track.get_orientation() in tracks:
		print("can't add track, same orientation already occupied!")
	tracks[track.get_orientation()] = track
	update()

func _draw():
	for track in tracks.values():
		draw_line(track.pos0*spacing, track.pos1*spacing, Color.white, 4)
	
	if hover_track != null:
		draw_line(hover_track.pos0*spacing, hover_track.pos1*spacing, Color(0.4,0.4,0.4), 4)
