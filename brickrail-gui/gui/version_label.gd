extends Label

func _ready():
	
	
	var root_path
	if OS.has_feature("standalone"):
		var test_root_path = ProjectSettings.globalize_path("res://")
		prints("test_root_path", test_root_path)
		root_path = OS.get_executable_path().get_base_dir()
	else:
		root_path = ProjectSettings.globalize_path("res://") + "../"
	
	
	var vfile = File.new()
	vfile.open(root_path + "/version.txt", File.READ)
	var content = vfile.get_line()
	vfile.close()
	text = content
	Logger.info("Brickrail version: %s" % text)
