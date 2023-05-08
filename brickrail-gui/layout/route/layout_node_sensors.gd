
class_name LayoutNodeSensors
extends Reference

var sensor_dirtracks = {"enter": null, "in": null, "leave": null}

func set_sensor_dirtrack(key, dirtrack):
	if sensor_dirtracks[key] != null:
		var _err = sensor_dirtracks[key].disconnect("sensor_changed", self, "_on_sensor_changed")
	if dirtrack != null:
		assert(dirtrack.get_sensor() != null)
		var _err = dirtrack.connect("sensor_changed", self, "_on_sensor_changed", [key])
	sensor_dirtracks[key] = dirtrack

func _on_sensor_changed(_slot, key):
	if sensor_dirtracks[key] == null:
		# REVISIT for some reason this is called when sensor was removed previously, no idea why
		return
	if sensor_dirtracks[key].get_sensor() == null:
		set_sensor_dirtrack(key, null)

func get_sensor_dirtrack_key(dirtrack):
	for key in sensor_dirtracks:
		if sensor_dirtracks[key] == dirtrack:
			return key
	return null
