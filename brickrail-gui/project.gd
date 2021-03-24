extends Node2D

var trains: Dictionary

func _on_train_state_changed(name, state):
	pass

func add_train(name, address=null):
	var train = BLETrain.new(name, address)
	print(get_children()[0].name)
	get_node("BLEController").add_hub(train.hub)
	trains[name] = train

func commit_action(action):
	var train = trains[action.train]
	prints("[project] calling method", action.function, "on train", action.train, "with args", action.args)
	train.callv(action.function, action.args)
