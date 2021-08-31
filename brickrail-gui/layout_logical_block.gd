class_name LayoutLogicalBlock
extends Resource

var blockname
var id
var section
var occupied: bool
var train: LayoutTrain
var index: int
var nodes = {}

func _init(p_name, p_index):
	blockname = p_name
	index = p_index
	id = blockname + "-" + str(index)
	for facing in [1, -1]:
		nodes[facing] = LayoutNode.new(self, id, facing, "block")

func set_section(p_section):
	section = p_section

func set_occupied(p_occupied, p_train=null):
	occupied = p_occupied
	train = p_train
	section.set_track_attributes("block", blockname)

func get_route_to(from_facing, node_id):
	var nodename	
	return nodes[from_facing].calculate_routes()[node_id]

func collect_edges(facing):
	var edges = []
	
	edges.append(LayoutEdge.new(nodes[facing], get_opposite_block().nodes[-1*facing], "flip", null))
	
	var node_obj = section.tracks[-1].get_node_obj()
	if node_obj != null:
		edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", null))
		return edges
	for next_section in section.get_next_segments():
		node_obj = next_section.tracks[-1].get_node_obj()
		if node_obj == null:
			continue
		edges.append(LayoutEdge.new(nodes[facing], node_obj.nodes[facing], "travel", next_section))
	return edges

func get_opposite_block():
	return LayoutInfo.blocks[blockname].logical_blocks[1-index]
