extends Node2D

var trains: Dictionary

signal data_received(key,data)

func _on_data_received(key, data):
	prints("[project] received data", key, data)
	emit_signal("data_received", key, data)

func _on_train_state_changed(name, state):
	pass

func add_train(name, address=null):
	var train = BLETrain.new(name, address)
	print(get_children()[0].name)
	get_node("BLEController").add_hub(train.hub)
	trains[name] = train

func commit_action(action):
	var obj
	if action.train == null:
		obj = self
	else:
		obj = trains[action.train]
	prints("[project] calling method", action.function, "on train", action.train, "with args", action.args)
	obj.callv(action.function, action.args)

func find_device():
	get_node("BLEController").send_command(null, "find_device", [], "find_device_address")
