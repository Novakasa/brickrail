extends VBoxContainer

var train = null

func set_train(obj):
	train = obj
	train.connect("unselected", self, "_on_train_unselected")

func _on_train_unselected():
	queue_free()


func _on_FlipHeading_pressed():
	train.flip_heading()


func _on_FlipFacing_pressed():
	train.flip_facing()


func _on_Start_pressed():
	train.start()


func _on_Stop_pressed():
	train.virtual_train.stop()


func _on_Slow_pressed():
	train.virtual_train.slow()
