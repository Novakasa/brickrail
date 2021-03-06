class_name BLEController
extends Node

var hubs = {}

signal data_received(key, data)

func _ready():
	$BLECommunicator.connect("message_received", self, "_on_message_received")

func add_hub(hub):
	send_command(null, "add_hub", [hub.name, hub.program, hub.address], null)
	hubs[hub.name] = hub
	hub.connect("ble_command", self, "_on_hub_command")
	hub.connect("name_changed", self, "_on_hub_name_changed")

func _on_hub_name_changed(hubname, new_hubname):
	rename_hub(hubname, new_hubname)

func rename_hub(p_name, p_new_name):
	var hub = hubs[p_name]
	hubs.erase(p_name)
	hubs[p_new_name] = hub
	send_command(null, "rename_hub", [p_name, p_new_name], null)

func _on_message_received(message):
	var obj = JSON.parse(message).result
	prints("[BLEController] message parsed obj:", obj)
	var key = obj.key
	var hubname = obj.hub
	if hubname != null:
		hubs[hubname]._on_data_received(key, obj.data)
		return
	emit_signal("data_received", key, obj.data)

func send_command(hub, funcname, args, return_key):
	var command = BLECommand.new(hub, funcname, args, return_key)
	$BLECommunicator.send_message(command.to_json())

func _on_hub_command(hub, command, args, return_key):
	send_command(hub, command, args, return_key)

