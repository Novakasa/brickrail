extends HBoxContainer

var scroll_time = 0.0
var scroll_period = 1.0

func _ready():
	GuiApi.status_gui = self

func ready(message):
	$StatusLabel.text = message
	$ProgressScrollbar.visible=false

func process(message):
	$StatusLabel.text = message
	$ProgressScrollbar.visible=true
	scroll_time = 0.0

func _process(delta):
	if not $ProgressScrollbar.visible:
		return

	scroll_time += delta
	while scroll_time > scroll_period:
		scroll_time -= scroll_period
	
	var t = 0.5*(cos(scroll_time/scroll_period * 2*PI)+1.0)
	var bar = $ProgressScrollbar
	bar.value = lerp(bar.min_value, bar.max_value-bar.page, t)

