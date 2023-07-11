class_name BLECommunicator
extends Node


@export var websocket_url = "ws://localhost:64569"
var _client = WebSocketPeer.new()
var process
var connected = false
var status = "disconnected"
var busy = false
var expect_close = false
var logging_module = "BLEProcess"

signal message_received(message)
signal connected_signal()
signal status_changed()

func _ready():
	_client.connect("connection_closed", Callable(self, "_closed"))
	_client.connect("connection_error", Callable(self, "_closed"))
	_client.connect("connection_established", Callable(self, "_connected"))
	_client.connect("data_received", Callable(self, "_on_data"))
	
	var _err = connect("status_changed", Callable(self, "_on_status_changed"))

func _on_status_changed():
	if busy:
		GuiApi.show_info("[BLE Server] %s..." % status)
	else:
		GuiApi.show_info("[BLE Server] %s" % status)

func start_and_connect_to_process():
	busy = true
	status = "starting process"
	emit_signal("status_changed")
	process = BLEProcess.new()
	add_child(process)
	await process.start_process().completed
	
	status = "connecting"
	emit_signal("status_changed")

	var err = _client.connect_to_url(websocket_url)
	if err != OK:
		Logger.error("[%s] Connect error: '%s'" % [logging_module])
		set_process(false)
		GuiApi.show_error("Unable to initialize connection to BLE Server python process!")
	
	var timer = get_tree().create_timer(5.0)
	var result = await Await.first_signal_objs([timer, self], ["timeout", "connected"])
	if result == timer:
		status = "Not connected to BLE Server"
		var more_info = "Timeout trying to connect to BLE Server python process.\nThis could mean that the BLEServer executable is not accessible.\n\nDid you extract the Brickrail release properly?\nThe ble-server directory should be in the same folder as the Brickrail-gui executable."
		GuiApi.show_error("Timeout trying to connect to BLE Server python process!", more_info)
		busy = false
		emit_signal("status_changed")

func disconnect_and_kill_process():
	status = "disconnecting"
	busy = true
	expect_close = true
	emit_signal("status_changed")
	_client.disconnect_from_host()
	Logger.info("[%s] Waiting for connection to ble-server closed" % logging_module)
	await _client.connection_closed
	Logger.info("[%s] closed!" % logging_module)
	await get_tree().create_timer(1.0).timeout
	process.kill()

func _closed(was_clean = false):
	Logger.info("[%s] Closed, clean: %s" % [logging_module, was_clean])
	if not expect_close:
		var more_info = "BLE Server was disconnected for some reason.\nIt could have crashed, or the terminal window was closed.\n\nYou can try restarting the BLE Server by pressing 'Connect BLE Server'\nin the hub panel."
		GuiApi.show_error("Disconnected from BLE Server python process unexpectedly!", more_info)
	expect_close = false
	connected=false
	busy = false
	status = "disconnected"
	emit_signal("status_changed")

func _connected(proto = ""):
	Logger.info("[%s] Connected with protocol: '%s'" % [logging_module, proto])
	# send_command(null, "hub_demo", [], null)
	connected=true
	busy = false
	expect_close = false
	status = "connected"
	emit_signal("connected")
	emit_signal("status_changed")

func send_message(message):
	if not connected:
		await _client.connection_established
	await get_tree().idle_frame
	Logger.info("[%s] sending to BLEServer: '%s'" % [logging_module, message])
	_client.get_peer(1).put_packet(message.to_utf8_buffer())

func _on_data():
	var msg = _client.get_peer(1).get_packet().get_string_from_utf8()
	Logger.info("[%s] reseived from BLEServer: '%s'" % [logging_module, msg])
	emit_signal("message_received", msg)

func _process(_delta):
	_client.poll()

func clean_exit_coroutine():
	if not connected:
		await get_tree().idle_frame
		return
	await disconnect_and_kill_process()
