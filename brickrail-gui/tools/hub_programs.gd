
extends Node

var hashes = {}

const CHUNK_SIZE = 1024

func hash_file(path):
	var ctx = HashingContext.new()
	var file = File.new()
	# Start a SHA-256 context.
	ctx.start(HashingContext.HASH_SHA256)
	# Check that file exists.
	if not file.file_exists(path):
		Logger.error("file to hash not found!!")
		return null
	# Open the file to hash.
	return file.get_sha256(path)

func _ready():
	
	var program_path
	if OS.has_feature("standalone"):
		if OS.get_name() == "Windows":
			program_path = OS.get_executable_path().get_base_dir() + "ble-server-windows/hub_programs"
		else:
			program_path = OS.get_executable_path().get_base_dir() + "ble-server-linux/hub_programs"
	else:
		program_path = ProjectSettings.globalize_path("res://") + "../ble-server/hub_programs/"
	print(program_path)
	
	hashes["smart_train"] = hash_file(program_path + "smart_train.py")
	hashes["layout_controller"] = hash_file(program_path + "layout_controller.py")
	print(hashes)
