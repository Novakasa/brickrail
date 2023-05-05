extends Label

func _ready():
	text = ProjectSettings.get_setting("global/version")
	Logger.info("Brickrail version: %s" % text)
