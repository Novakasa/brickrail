
class_name VirtualTrainWagon
extends Node2D

var color

func _draw():
	
	var size = Vector2(0.3,0.2)
	var wsize = size*LayoutInfo.spacing
	var col = color
	draw_rect(Rect2(-wsize*0.5, wsize), col)
	draw_circle(0.5*Vector2(wsize.x,0.0), wsize.y*0.5, col)
	draw_circle(-0.5*Vector2(wsize.x,0.0), wsize.y*0.5, col)
