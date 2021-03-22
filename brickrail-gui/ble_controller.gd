class_name BLEController
extends Node

var hubs = {}

func _ready():
	$BLECommunicator.connect("data_received", self, "_on_data_received")

func add_hub(hub):
	hubs[hub.name] = hub
	hub.connect("ble_command", self, "_on_hub_command")

func _on_data_received(data):
	if data.hub != null:
		hubs[data.hub]._on_data_received(data)

func _on_hub_command(hub, command, args, return_id):
	$BLECommunicator.send_command(hub, command, args, return_id)

