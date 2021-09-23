extends VBoxContainer

func _ready():
	$BackgroundColor.color = Settings.colors["background"]
	$SurfaceColor.color = Settings.colors["surface"]
	$PrimaryColor.color = Settings.colors["primary"]
	$SecondaryColor.color = Settings.colors["secondary"]
	$TertiaryColor.color = Settings.colors["tertiary"]
	$WhiteColor.color = Settings.colors["white"]


func _on_BackgroundColor_color_changed(color):
	Settings.set_color("background", color)


func _on_SurfaceColor_color_changed(color):
	Settings.set_color("surface", color)


func _on_PrimaryColor_color_changed(color):
	Settings.set_color("primary", color)


func _on_SecondaryColor_color_changed(color):
	Settings.set_color("secondary", color)


func _on_TertiaryColor_color_changed(color):
	Settings.set_color("tertiary", color)


func _on_WhiteColor_color_changed(color):
	Settings.set_color("white", color)
