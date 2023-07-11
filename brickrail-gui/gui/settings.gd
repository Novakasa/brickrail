@tool
extends Node

var render_mode = "dynamic"
@onready var layout_path = ProjectSettings.globalize_path("user://")

var classic_colors = {
	"background": Color("161614"),
	"surface": Color("292929"),
	"primary": Color("E0A72E"),
	"secondary": Color("5C942E"),
	"tertiary": Color("91140F"),
	"white": Color("EEEEEE")}

var bubblegum_colors = {
	"background": Color("ff152022"),
	"surface": Color("ff0f1213"),
	"primary": Color("ff3ab8ba"),
	"secondary": Color("ffba56ec"),
	"tertiary": Color("ff954dff"),
	"white": Color("ffeeeeee")}

var presets = {}
var default_presets = []

var color_preset = "custom"
var colors = {}

var hub_program_hashes = {}
var hub_io_hub_hashes = {}

var layout_train_positions = {}

signal render_mode_changed(mode)
signal colors_changed()
signal color_presets_changed()

func _ready():
	colors = bubblegum_colors.duplicate()
	presets["bubblegum"] = bubblegum_colors.duplicate()
	presets["classic"] = classic_colors.duplicate()
	presets["custom"] = bubblegum_colors.duplicate()
	default_presets = presets.keys()
	read_configfile()
	var _err = connect("colors_changed", Callable(self, "update_clear_color"))
	update_clear_color()
	
func update_clear_color():
	RenderingServer.set_default_clear_color(colors["background"])

func set_color(cname, color):
	if color_preset != "custom":
		presets["custom"] = colors.duplicate()
		set_color_preset("custom")
	colors[cname] = color
	emit_signal("colors_changed")

func set_color_preset(presetname):
	assert(presetname in presets)
	color_preset = presetname
	colors = presets[color_preset].duplicate()
	emit_signal("color_presets_changed")
	emit_signal("colors_changed")

func add_color_preset(presetname):
	presets[presetname] = colors.duplicate()
	set_color_preset(presetname)

func remove_color_preset(presetname):
	assert(presetname in presets)
	assert(not presetname in default_presets)
	if presetname == color_preset:
		set_color_preset("custom")
	presets.erase(presetname)
	emit_signal("color_presets_changed")

func set_render_mode(mode):
	render_mode = mode
	emit_signal("render_mode_changed", render_mode)

func save_configfile():
	var data = {}
	data["colors"] = {}
	for colorname in colors:
		data.colors[colorname] = colors[colorname].to_html()
	
	data["presets"] = {}
	for presetname in presets:
		data.presets[presetname] = {}
		for colorname in presets[presetname]:
			data.presets[presetname][colorname] = presets[presetname][colorname].to_html()
	
	data["color_preset"] = color_preset
	data["render_mode"] = render_mode
	data["layout_path"] = layout_path
	data["hub_program_hashes"] = hub_program_hashes
	data["hub_io_hub_hashes"] = hub_io_hub_hashes
	data["layout_train_positions"] = layout_train_positions
	var jsonstr = JSON.stringify(data, "\t")
	var configfil = File.new()
	configfil.open("user://config.json", File.WRITE)
	configfil.store_string(jsonstr)
	configfil.close()

func read_configfile():
	var dir = DirAccess.new()
	var _err = dir.open("user://")
	var exists = dir.file_exists("config.json")
	if not exists:
		emit_signal("render_mode_changed")
		emit_signal("colors_changed")
		return
	var configfil = File.new()
	configfil.open("user://config.json", File.READ)
	var jsonstr = configfil.get_as_text()
	configfil.close()
	
	var test_json_conv = JSON.new()
	test_json_conv.parse(jsonstr).result
	var data = test_json_conv.get_data()
	
	for colorname in data.colors:
		colors[colorname] = Color(data.colors[colorname])
	render_mode = data.render_mode
	if "layout_path" in data:
		layout_path = data.layout_path
	
	if "presets" in data:
		for presetname in data.presets:
			presets[presetname] = {}
			for colorname in data.presets[presetname]:
				presets[presetname][colorname] = Color(data.presets[presetname][colorname])
	
	if "color_preset" in data:
		color_preset = data.color_preset
	
	if "hub_program_hashes" in data:
		hub_program_hashes = data.hub_program_hashes.duplicate()
	if "hub_io_hub_hashes" in data:
		hub_io_hub_hashes = data.hub_io_hub_hashes.duplicate()
	
	if "layout_train_positions" in data:
		layout_train_positions = data.layout_train_positions.duplicate()
	
	emit_signal("render_mode_changed")
	emit_signal("colors_changed")
