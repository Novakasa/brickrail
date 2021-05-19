extends Label

var switch

func get_drag_data(position):
	var preview = Label.new()
	preview.name = switch.name
	set_drag_preview(preview)
	print("dragging switch!")
	return switch
