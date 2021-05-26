extends VBoxContainer

var track

func set_track(p_track):
	track = p_track
	track.connect("unselected", self, "_on_track_unselected")

func _on_track_unselected():
	queue_free()


func _on_RemoveButton_pressed():
	track.remove()
