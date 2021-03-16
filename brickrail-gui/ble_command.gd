class_name BLECommand

var hub
var funcname
var args
var return_id

func _init(p_hub, p_funcname, p_args, p_return_id):
	hub = p_hub
	funcname = p_funcname
	args = p_args
	return_id = p_return_id

func to_json():
	var data = {}
	data["hub"] = hub
	data["func"] = funcname
	data["args"] = args
	data["return_id"] = return_id
	return JSON.print(data)
