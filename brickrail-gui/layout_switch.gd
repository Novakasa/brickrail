
class_name LayoutSwitch
extends Button

var position_index = 0
var switch_positions
var ble_switch = null
var slot

signal position_changed(slot, pos)

func _init(p_slot, positions):
	text = "switch"
	connect("pressed", self, "toggle_switch")
	switch_positions = positions
	switch_positions.sort()
	slot = p_slot

func toggle_switch():
	position_index = (position_index+1) % len(switch_positions)
	switch(switch_positions[position_index])

func switch(pos):
	if ble_switch != null:
		ble_switch.switch(pos)
	else:
		position_index = switch_positions.find(pos)
		emit_signal("position_changed", slot, pos)

func get_position():
	return switch_positions[position_index]

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_M:
			toggle_switch()

func _on_ble_switch_position_changed(pos):
	position_index = switch_positions.find(pos)
	emit_signal("position_changed", slot, pos)

func set_ble_switch(p_switch):
	ble_switch = p_switch
	ble_switch.connect("on_position_changed", self, "_on_ble_switch_position_changed")

func _draw():
	# draw_circle(Vector2(10,10), 10, Color.red)
	pass
