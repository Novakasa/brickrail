class_name LayoutLogicalBlock
extends Resource

var blockname
var routes = {}
var section
var occupied: bool
var train: LayoutTrain
var index: int

func _init(p_name, p_index):
	blockname = p_name
	index = p_index

func set_section(p_section):
	section = p_section

func set_occupied(p_occupied, p_train=null):
	occupied = p_occupied
	train = p_train
	section.set_track_attributes("block", blockname)
