class_name BLECommunicator
extends Node


export var websocket_url = "ws://localhost:64569"
var _client = WebSocketClient.new()
var process
var connected = false
var status = "disconnected"
var busy = false

signal message_received(message)
signal connected()
signal status_changed()

func _ready():
	_client.connect("connection_closed", self, "_closed")
	_client.connect("connection_error", self, "_closed")
	_client.connect("connection_established", self, "_connected")
	_client.connect("data_received", self, "_on_data")

func start_and_connect_to_process():
	busy = true
	status = "starting process"
	emit_signal("status_changed")
	process = BLEProcess.new()
	add_child(process)
	yield(process.start_process(), "completed")
	
	status = "connecting"
	emit_signal("status_changed")

	var err = _client.connect_to_url(websocket_url)
	if err != OK:
		print("Unable to connect")
		set_process(false)
		GuiApi.show_error("Unable to initialize connection to BLE Server python process!")
	
	var timer = get_tree().create_timer(5.0)
	var result = yield(Await.first_signal_objs([timer, self], ["timeout", "connected"]), "completed")
	print(result)
	if result == timer:
		status = "Not connected to BLE Server"
		GuiApi.show_error("Timeout trying to connect to BLE Server python process!")
		busy = false
		emit_signal("status_changed")

func disconnect_and_kill_process():
	status = "disconnecting"
	busy = true
	emit_signal("status_changed")
	_client.disconnect_from_host()
	print("waiting for connection to ble-server closed")
	yield(_client, "connection_closed")
	print("closed!")
	yield(get_tree().create_timer(1.0), "timeout")
	process.kill()

func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	if not was_clean:
		GuiApi.show_error("Disconnected from BLE Server python process (uncleanly)!")
	connected=false
	busy = false
	status = "disconnected"
	emit_signal("status_changed")

func _connected(proto = ""):
	print("Connected with protocol: ", proto)
	# send_command(null, "hub_demo", [], null)
	connected=true
	busy = false
	status = "connected"
	emit_signal("connected")
	emit_signal("status_changed")

func send_message(message):
	if not connected:
		yield(_client, "connection_established")
	yield(get_tree(), "idle_frame")
	_client.get_peer(1).put_packet(message.to_utf8())

func _on_data():
	var msg = _client.get_peer(1).get_packet().get_string_from_utf8()
	emit_signal("message_received", msg)

func _process(_delta):
	_client.poll()

func clean_exit_coroutine():
	if not connected:
		yield(get_tree(), "idle_frame")
		return
	yield(disconnect_and_kill_process(), "completed")
