
class_name LayoutBlock
extends Node2D

var logical_block_p
var logical_block_n

func _init(p_name):
	name = p_name
	
	logical_block_p = LayoutLogicalBlock.new(p_name + "+")
	logical_block_n = LayoutLogicalBlock.new(p_name + "-")

func set_section(p_section):
	
	logical_block_p.set_section(p_section)
	logical_block_n.set_section(p_section.flip())
	logical_block_n.section.set_track_attributes("block", name)
