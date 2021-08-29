class_name LayoutLogicalBlock
extends Resource

var blockname
var section
var occupied: bool
var train: LayoutTrain
var index: int
var node

func _init(p_name, p_index):
	blockname = p_name
	index = p_index
	node = LayoutNode.new(self, blockname)

func set_section(p_section):
	section = p_section

func set_occupied(p_occupied, p_train=null):
	occupied = p_occupied
	train = p_train
	section.set_track_attributes("block", blockname)

func get_route_to(blockname):
	return node.calculate_routes()[blockname]

func collect_segments():
	return section.get_next_segments()
