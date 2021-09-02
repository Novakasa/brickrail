class_name LayoutTrain
extends Node2D

var ble_train
var virtual_train
var route
var block
var trainname
var facing: int = 1
var VirtualTrainScene = load("res://virtual_train.tscn")
var selected=false

var TrainInspector = preload("res://layout_train_inspector.tscn")

signal removing(p_name)
signal selected()
signal unselected()

func _init(p_name):
	trainname = p_name
	name = "train_"+trainname
	virtual_train = VirtualTrainScene.instance()
	add_child(virtual_train)
	virtual_train.connect("hover", self, "_on_virtual_train_hover")
	virtual_train.connect("clicked", self, "_on_virtual_train_clicked")
	virtual_train.visible=false

func select():
	selected=true
	LayoutInfo.select(self)
	virtual_train.set_selected(true)
	emit_signal("selected")

func unselect():
	selected=false
	virtual_train.set_selected(false)
	emit_signal("unselected")

func _on_virtual_train_hover():
	virtual_train.set_hover(true)

func stop_hover():
	virtual_train.set_hover(false)

func _on_virtual_train_clicked(event):
	# prints("train:", trainname)
	if event.button_index == BUTTON_LEFT:
		if not selected:
			select()
	
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
	queue_free()

func get_inspector():
	var inspector = TrainInspector.instance()
	inspector.set_train(self)
	return inspector
