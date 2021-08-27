tool

class_name LayoutBlock
extends Node2D

var logical_block_p
var logical_block_n
var size = Vector2(0.5, 0.25)
var section = null
var blockname
var hover = false
var selected = false
var logical_blocks = []
export(Color) var color
export(Font) var font

var LayoutBlockInspector = preload("res://layout_block_inspector.tscn")

signal removing(p_name)
signal selected()
signal unselected()

func setup(p_name):
	blockname = p_name
	name = blockname
	
	logical_blocks.append(LayoutLogicalBlock.new(p_name, 0))
	logical_blocks.append(LayoutLogicalBlock.new(p_name, 1))

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

func process_mouse_button(event, pos):
	if event.button_index == BUTTON_LEFT and event.pressed:
		if not selected:
			select()

func hover(pos):
	hover = true
	section.set_track_attributes("block", blockname)

func stop_hover():
	hover = false
	section.set_track_attributes("block", blockname)

func select():
	selected=true
	LayoutInfo.select(self)
	section.set_track_attributes("block", blockname)
	emit_signal("selected")

func unselect():
	selected=false
	section.set_track_attributes("block", blockname)
	emit_signal("unselected")

func set_section(p_section):
	
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
	
	position = track.get_cell().position + LayoutInfo.spacing*track.get_center()
	position -= 0.5*size.y*tangent.rotated(PI*0.5)
	rotation = tangent.angle()
	

	update()

func serialize():
	var result = {}
	result["name"] = blockname
	if section != null:
		result["section"] = section.serialize()
	return result

func get_inspector():
	var inspector = LayoutBlockInspector.instance()
	inspector.set_block(self)
	return inspector

func remove():
	if selected:
		unselect()
	section.unset_track_attributes("block")
	emit_signal("removing", blockname)
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
