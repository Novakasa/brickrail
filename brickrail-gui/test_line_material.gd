tool
extends Node2D

func _draw():
	
	
	var points = PoolVector2Array([Vector2(100,0), Vector2(100,100),Vector2(150,150),Vector2(200,250)])
	draw_polyline(points, Color.white, 20, true)
