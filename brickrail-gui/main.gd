extends Control

export(NodePath) var project


func _on_AddTrain_pressed():
	get_node(project).add_train("test", null)


func _on_ConnectTrain_pressed():
	get_node(project).trains["test"].ble_connect()


func _on_RunTrain_pressed():
	get_node(project).trains["test"].ble_run()


func _on_StartTrain_pressed():
	get_node(project).trains["test"].ble_start()


func _on_StopTrain_pressed():
	get_node(project).trains["test"].ble_stop()
