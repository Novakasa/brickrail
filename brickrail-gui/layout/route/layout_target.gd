
class_name LayoutTarget
extends Reference

var sensor_dirtracks = {"enter": null, "in": null, "leave": null}

func set_sensor_dirtrack(key, dirtrack):
	assert(dirtrack.get_sensor() != null)
	sensor_dirtracks[key] = dirtrack
