extends VBoxContainer

func _ready():
	_on_settings_presets_changed()
	$GridContainer/RenderModeOption.select(["dynamic", "cached"].find(Settings.render_mode))
	var _err = Settings.connect("color_presets_changed", Callable(self, "_on_settings_presets_changed"))
	$PresetNameDialog.set_label("Preset name:")
	$PresetNameDialog.add_text_edit()
	$PresetNameDialog.add_action_button("cancel", "Cancel")
	$PresetNameDialog.add_action_button("OK", "OK")

func _on_settings_presets_changed():
	$BackgroundColor.color = Settings.colors["background"]
	$SurfaceColor.color = Settings.colors["surface"]
	$PrimaryColor.color = Settings.colors["primary"]
	$SecondaryColor.color = Settings.colors["secondary"]
	$TertiaryColor.color = Settings.colors["tertiary"]
	$WhiteColor.color = Settings.colors["white"]
	
	var presetnames = Settings.presets.keys()
	$GridContainer/PresetSelector.set_items(presetnames, presetnames)
	$GridContainer/PresetSelector.select_meta(Settings.color_preset)
	
	$GridContainer/PresetRemoveButton.disabled = Settings.color_preset in Settings.default_presets

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


func _on_RenderModeOption_item_selected(index):
	var render_mode = ["dynamic", "cached"][index]
	Settings.set_render_mode(render_mode)


func _on_PresetSelector_meta_selected(meta):
	Settings.set_color_preset(meta)


func _on_PresetAddButton_pressed():
	var action = await $PresetNameDialog.get_user_action_coroutine().completed
	if action == "cancel":
		return
	var presetname = $PresetNameDialog.line_edit.text
	Settings.add_color_preset(presetname)

func _on_PresetRemoveButton_pressed():
	Settings.remove_color_preset(Settings.color_preset)
