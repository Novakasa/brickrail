extends Panel

var train setget set_train
export(NodePath) var train_label

signal train_action(train, action)

func set_train(p_train):
	train = p_train
	get_node(train_label).text = train

func _on_run_button_pressed():
	var action = TrainCommand.new(train, "run_program", [])
	emit_signal("train_action", action)

func _on_connect_button_pressed():
	var action = TrainCommand.new(train, "connect_hub", [])
	print("connection action signal sent!")
	emit_signal("train_action", action)

func _on_start_button_pressed():
	var action = TrainCommand.new(train, "start", [])
	emit_signal("train_action", action)

func _on_stop_button_pressed():
	var action = TrainCommand.new(train, "stop", [])
	emit_signal("train_action", action)
