class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var trainname
var orientation: int = 1

signal removing(p_name)

func _init(p_name):
	trainname = p_name
	name = "train_"+trainname
	
func set_current_block(p_block):
	block = p_block
	block.set_occupied(true, self)

func flip_heading():
	orientation *= -1
	set_current_block(block.get_opposite_block())

func remove():
	emit_signal("removing", trainname)
