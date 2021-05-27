extends VBoxContainer

var section = null

func set_section(obj):
	section = obj
	section.connect("unselected", self, "_on_section_unselected")

func _on_section_unselected():
	queue_free()
