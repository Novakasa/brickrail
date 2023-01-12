class_name BLECommunicator
extends Node


export var websocket_url = "ws://localhost:64569"
var _client = WebSocketClient.new()

signal message_received(message)

func _exit_tree():
	_client.disconnect_from_host()

func _ready():
	
	# OS.execute("cmd", ["start cmd /K"], false)
	var process = load("res://ble/ble_process.gd").new()
	process.start_process()

	_client.connect("connection_closed", self, "_closed")
	_client.connect("connection_error", self, "_closed")
	_client.connect("connection_established", self, "_connected")
	_client.connect("data_received", self, "_on_data")

	var err = _client.connect_to_url(websocket_url)
	if err != OK:
		print("Unable to connect")
		set_process(false)

func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	set_process(false)

func _connected(proto = ""):
	print("Connected with protocol: ", proto)
	# send_command(null, "hub_demo", [], null)

func send_message(message):
	_client.get_peer(1).put_packet(message.to_utf8())

func _on_data():
	var msg = _client.get_peer(1).get_packet().get_string_from_utf8()
	print("Got data from server: ", msg)
	emit_signal("message_received", msg)

func _process(_delta):
	_client.poll()
