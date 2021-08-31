class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var trainname
var facing: int = 1
var VirtualTrainScene = load("res://virtual_train.tscn")

signal removing(p_name)

func _init(p_name):
	trainname = p_name
	name = "train_"+trainname
	virtual_train = VirtualTrainScene.instance()
	add_child(virtual_train)
	virtual_train.connect("hover", self, "_on_virtual_train_hover")
	virtual_train.connect("hover", self, "_on_virtual_train_clicked")
	virtual_train.visible=false

func _on_virtual_train_hover():
	pass

func _on_virtual_train_clicked(event):
	pass
	
func set_current_block(p_block):
	if block != null:
		block.set_occupied(false, self)
	block = p_block
	block.set_occupied(true, self)
	virtual_train.visible=true
	virtual_train.set_dirtrack(block.sensors["in"])

func set_route(p_route):
	route = p_route

func flip_heading():
	facing *= -1
	set_current_block(block.get_opposite_block())

func remove():
	emit_signal("removing", trainname)
