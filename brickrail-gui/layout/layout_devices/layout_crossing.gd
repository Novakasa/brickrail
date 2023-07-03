

class_name LayoutCrossing
extends Node2D

var motor1 = null
var motor2 = null

var track

var pos = "up"

func _init(p_track):
	track = p_track
	LayoutInfo.connect("blocked_tracks_changed", self, "_on_layout_blocked_tracks_changed")

func remove():
	queue_free()

func _on_layout_blocked_tracks_changed(_train):
	if len(track.get_locked()) > 0:
		if pos != "down":
			set_pos("down")
	else:
		if pos != "up":
			set_pos("up")

func toggle_pos():
	if pos == "up":
		set_pos("down")
	else:
		set_pos("up")

func set_pos(p_pos):
	if motor1 != null and LayoutInfo.control_devices != LayoutInfo.CONTROL_OFF:
		motor1.set_position(p_pos)
	if motor2 != null and LayoutInfo.control_devices != LayoutInfo.CONTROL_OFF:
		motor2.set_position(p_pos)
	pos = p_pos
	update()

func set_motor1(device):
	motor1 = device

func set_motor2(device):
	motor2 = device

func serialize():
	var struct = {}
	if motor1 != null:
		struct["motor1"] = motor1.serialize_reference()
	if motor2 != null:
		struct["motor2"] = motor2.serialize_reference()
	return struct

func load_struct(struct):
	if "motor1" in struct:
		var motorstruct = struct.motor1
		var controller = Devices.layout_controllers[motorstruct.controller]
		var motor = controller.devices[int(motorstruct.port)]
		if "storage" in motorstruct:
			for key in motorstruct.storage:
				motor.store_value(int(key), motorstruct.storage[key])
		set_motor1(motor)
	if "motor2" in struct:
		var motorstruct = struct.motor2
		var controller = Devices.layout_controllers[motorstruct.controller]
		var motor = controller.devices[int(motorstruct.port)]
		if "storage" in motorstruct:
			for key in motorstruct.storage:
				motor.store_value(int(key), motorstruct.storage[key])
		set_motor2(motor)

func _draw():
	var col = Settings.colors["white"]
	var width = LayoutInfo.spacing*0.05
	var spacing = LayoutInfo.spacing * 0.5
	var pivot1 = spacing*Vector2(-0.5, -0.5)
	var pivot2 = spacing*Vector2(0.5, 0.5)
	var angle = 0.0
	if pos == "up":
		angle = -PI*0.4
	var end1 = pivot1 + spacing*Vector2(1.0, 0.0).rotated(angle)
	var end2 = pivot2 + spacing*Vector2(-1.0, 0.0).rotated(angle)
	draw_line(pivot1, end1, col, width)
	draw_line(pivot2, end2, col, width)
	
