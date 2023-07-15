
extends Node

var hashes = {}

const CHUNK_SIZE = 1024

func hash_file(path):
	if not FileAccess.file_exists(path):
		Logger.error("file to hash not found!!")
		return null
	return FileAccess.get_sha256(path)

func _ready():
	
	var program_path
	if OS.has_feature("standalone"):
		if OS.get_name() == "Windows":
			program_path = OS.get_executable_path().get_base_dir() + "/ble-server-windows/hub_programs/"
		else:
			program_path = OS.get_executable_path().get_base_dir() + "/ble-server-linux/hub_programs/"
	else:
		program_path = ProjectSettings.globalize_path("res://") + "../ble-server/hub_programs/"
	print(program_path)
	
	hashes["smart_train"] = hash_file(program_path + "smart_train.py")
	Logger.info("[HubPrograms] Program smart_train hash: %s" % [hashes["smart_train"]])
	hashes["layout_controller"] = hash_file(program_path + "layout_controller.py")
	Logger.info("[HubPrograms] Program layout_controller hash: %s" % [hashes["layout_controller"]])
	hashes["io_hub"] = hash_file(program_path + "io_hub_unfrozen.py")
	Logger.info("[HubPrograms] Program io_hub hash: %s" % [hashes["io_hub"]])
