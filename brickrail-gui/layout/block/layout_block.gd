tool

class_name LayoutBlock
extends Node2D

var size = Vector2(0.5, 0.25)
var section = null
var block_id
var block_name
var hover = false
var selected = false
var logical_blocks = []
export(Color) var color
export(Font) var font
var hover_block = null

signal removing(p_block_id)

func setup(p_block_id):
	block_id = p_block_id
	block_name = p_block_id
	name = block_id
	
	logical_blocks.append(LayoutLogicalBlock.new(p_block_id, 0))
	logical_blocks.append(LayoutLogicalBlock.new(p_block_id, 1))
	add_child(logical_blocks[0])
	add_child(logical_blocks[1])

func get_name():
	return block_name

func set_name(p_name):
	var old_name = block_name
	block_name = p_name
	if old_name != block_name:
		LayoutInfo.set_layout_changed(true)

func get_occupied():
	for logical_block in logical_blocks:
		if logical_block.occupied:
			return true
	return false

func get_train():
	for logical_block in logical_blocks:
		if logical_block.occupied:
			return logical_block.train
	return null

func set_section(p_section):
	
	if len(p_section.get_sensor_dirtracks()) == 0:
		p_section.tracks[0].add_sensor(LayoutSensor.new())
		p_section.tracks[-1].add_sensor(LayoutSensor.new())
	
	logical_blocks[0].set_section(p_section)
	logical_blocks[1].set_section(p_section.flip())
	p_section.set_track_attributes("block", block_id)
	section = p_section
	
	#warning-ignore:integer_division
	var index = len(p_section.tracks)/2
	var track = p_section.tracks[index]
	var tangent = track.get_tangent()
	while tangent.angle()>PI/2:
		tangent = tangent.rotated(-PI)
	while tangent.angle()<-PI/2:
		tangent = tangent.rotated(PI)
	
	$scaler/Label.set_text(block_id)
	size = $scaler.scale*$scaler/Label.rect_size
	
	position = track.get_position() + LayoutInfo.spacing*track.get_center()
	position -= 0.5*size.y*tangent.rotated(PI*0.5)
	rotation = tangent.angle()

	update()

func depends_on(dirtrack):
	if section.is_connected_to(dirtrack):
		return true
	if section.is_connected_to(dirtrack.get_opposite()):
		return true
	return false

func serialize():
	var result = {}
	result["block_name"] = block_name
	if section != null:
		result["section"] = section.serialize()
	var sensors = {}
	var can_stop = {}
	var can_flip = {}
	var random_target = {}
	var wait_time = {}
	for block_index in [0,1]:
		var prior_dirtrack = logical_blocks[block_index].get_prior_sensor_dirtrack()
		if prior_dirtrack != null:
			sensors[block_index] = prior_dirtrack.serialize(true)
		can_stop[block_index] = logical_blocks[block_index].can_stop
		can_flip[block_index] = logical_blocks[block_index].can_flip
		random_target[block_index] = logical_blocks[block_index].random_target
		wait_time[block_index] = logical_blocks[block_index].wait_time
		
	result["prior_sensors"] = sensors
	result["can_stop"] = can_stop
	result["can_flip"] = can_flip
	result["random_target"] = random_target
	result["wait_time"] = wait_time
	return result

func remove():
	for logical_block in logical_blocks:
		if logical_block.selected:
			logical_block.unselect()
	section.set_track_attributes("block", null)
	emit_signal("removing", block_id)
	for logical_block in logical_blocks:
		logical_block.emit_signal("removing", block_id)
	queue_free()

func _draw():
	return
