extends Node


export var websocket_url = "ws://localhost:64569"
var _client = WebSocketClient.new()

func _exit_tree():
	_client.disconnect_from_host()


func _ready():
	
	# OS.execute("cmd", ["start cmd /K"], false)
	$ble_process.start_process()

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
	_client.get_peer(1).put_packet("print('test command successful1!')".to_utf8())
	_client.get_peer(1).put_packet("print(project.hubs)".to_utf8())
	_client.get_peer(1).put_packet('ReturnData("test_return",project.hubs)'.to_utf8())
	

func _on_data():
	print("Got data from server: ", _client.get_peer(1).get_packet().get_string_from_utf8())

func _process(delta):
	_client.poll()
