extends Label

func _ready():
	text = ProjectSettings.get_setting("global/version")
