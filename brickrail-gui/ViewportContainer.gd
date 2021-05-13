extends ViewportContainer

func _gui_input(event):
	$Viewport/Layout/Grid.process_input(event)
