tool

class_name LayoutBlock
extends Node2D

var size = Vector2(0.5, 0.25)
var section = null
var blockname
var hover = false
var selected = false
var logical_blocks = []
export(Color) var color
export(Font) var font
var hover_block = null

signal removing(p_name)
signal selected()
signal unselected()

func setup(p_name):
	blockname = p_name
	name = blockname
	
	logical_blocks.append(LayoutLogicalBlock.new(p_name, 0))
	logical_blocks.append(LayoutLogicalBlock.new(p_name, 1))
	add_child(logical_blocks[0])
	add_child(logical_blocks[1])

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
	p_section.set_track_attributes("block", blockname)
	section = p_section
	
	var index = len(p_section.tracks)/2
	var track = p_section.tracks[index]
	var tangent = track.get_tangent()
	while tangent.angle()>PI/2:
		tangent = tangent.rotated(-PI)
	while tangent.angle()<-PI/2:
		tangent = tangent.rotated(PI)
	
	$scaler/Label.set_text(blockname)
	size = $scaler.scale*$scaler/Label.rect_size
	
	position = track.get_position() + LayoutInfo.spacing*track.get_center()
	position -= 0.5*size.y*tangent.rotated(PI*0.5)
	rotation = tangent.angle()

	update()

func serialize():
	var result = {}
	result["name"] = blockname
	if section != null:
		result["section"] = section.serialize()
	return result

func remove():
	for logical_block in logical_blocks:
		if logical_block.selected:
			logical_block.unselect()
	section.set_track_attributes("block", null)
	emit_signal("removing", blockname)
	for logical_block in logical_blocks:
		logical_block.emit_signal("removing", blockname)
	queue_free()

func _draw():
	size = $scaler.scale*$scaler/Label.rect_size
	# draw_rect(Rect2(-0.5*size, size), color)
	var i = 0
	var next
	var xpos = -size.x/2
	for ch in blockname:
		if i<len(blockname)-1:
			next = blockname[i+1]
		else:
			next = ""
		xpos += draw_char(font, Vector2(xpos,0.0),ch,next, Color.black)
		i += 1
		# xpos += size.x/len(name)
