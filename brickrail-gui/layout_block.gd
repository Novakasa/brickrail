tool

class_name LayoutBlock
extends Node2D

var logical_block_p
var logical_block_n
var size = Vector2(0.5, 0.25)
export(Color) var color
export(Font) var font

func setup(p_name):
	name = p_name
	
	logical_block_p = LayoutLogicalBlock.new(p_name + "+")
	logical_block_n = LayoutLogicalBlock.new(p_name + "-")

func set_section(p_section):
	
	logical_block_p.set_section(p_section)
	logical_block_n.set_section(p_section.flip())
	logical_block_n.section.set_track_attributes("block", name)
	
	var index = len(p_section.tracks)/2
	var track = p_section.tracks[index]
	var tangent = track.get_tangent()
	while tangent.angle()>PI/2:
		tangent = tangent.rotated(-PI)
	while tangent.angle()<-PI/2:
		tangent = tangent.rotated(PI)
	
	$scaler/Label.set_text(name)
	size = $scaler.scale*$scaler/Label.rect_size
	
	position = track.get_cell().position + LayoutInfo.spacing*track.get_center()
	position -= 0.5*size.y*tangent.rotated(PI*0.5)
	rotation = tangent.angle()

	update()

func _draw():
	size = $scaler.scale*$scaler/Label.rect_size
	# draw_rect(Rect2(-0.5*size, size), color)
	var i = 0
	var next
	var xpos = -size.x/2
	for ch in name:
		if i<len(name)-1:
			next = name[i+1]
		else:
			next = ""
		xpos += draw_char(font, Vector2(xpos,0.0),ch,next, Color.black)
		i += 1
		# xpos += size.x/len(name)
