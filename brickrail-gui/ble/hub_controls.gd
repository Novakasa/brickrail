extends HBoxContainer

export(NodePath) var connect_button
export(NodePath) var run_button

var hub

func setup(p_hub):
	hub = p_hub
	hub.connect("connected", self, "_on_hub_connected")
	hub.connect("disconnected", self, "_on_hub_disconnected")
	hub.connect("connect_error", self, "_on_hub_connect_error")
	hub.connect("program_started", self, "_on_hub_program_started")
	hub.connect("program_stopped", self, "_on_hub_program_stopped")

func _on_run_button_pressed():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	if runbutton.text == "run":
		hub.run_program()
	if runbutton.text == "stop":
		hub.stop_program()
	runbutton.disabled=true
	connectbutton.disabled=true

func _on_connect_button_pressed():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	if connectbutton.text == "connect":
		hub.connect_hub()
	if connectbutton.text == "disconnect":
		hub.disconnect_hub()
	connectbutton.disabled=true
	runbutton.disabled=true

func _on_hub_connected():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	connectbutton.disabled=false
	runbutton.disabled=false
	connectbutton.text="disconnect"

func _on_hub_disconnected():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	connectbutton.disabled=false
	connectbutton.text="connect"
	runbutton.disabled=true

func _on_hub_connect_error(data):
	var button = get_node(connect_button)
	button.disabled=false
	button.text="connect"

func _on_hub_program_started():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	runbutton.text="stop"
	runbutton.disabled=false
	connectbutton.disabled=true

func _on_hub_program_stopped():
	var runbutton = get_node(run_button)
	var connectbutton = get_node(connect_button)
	runbutton.text="run"
	runbutton.disabled=false
	connectbutton.disabled=false
