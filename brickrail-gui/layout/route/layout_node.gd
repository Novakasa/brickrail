class_name LayoutNode
extends Reference

var obj
var id
var edges = {}
var type
var facing
var sensors: LayoutNodeSensors

func _init(p_obj, p_id, p_facing, p_type):
	obj = p_obj
	id = p_id + "_" + ["<", ">"][(p_facing+1)/2]
	facing = p_facing
	type = p_type

func set_sensors(p_sensors):
	sensors = p_sensors

func get_sensors():
	return sensors

func collect_edges():
	# prints("collecting edges on", id)
	edges = {}
	for edge in obj.collect_edges(facing):
		edges[edge.to_node.id] = edge

func is_smaller_null(val1, val2):
	# null == infinity
	if val2 == null:
		return true
	if val1 == null:
		return false
	return val1<val2

func calculate_routes(reversing_behavior, trainname=null):
	#dijkstra algorithm
	
	var distances = {}
	var from_nodes = {}
	var unvisited: Array = LayoutInfo.nodes.keys()
	for iter_id in unvisited:
		distances[iter_id] = null # infinity
	distances[id] = 0.0
	var current_id = id
	
	while len(unvisited)>0:
		var mindist = null
		var minid = null
		for iter_id in unvisited:
			if is_smaller_null(distances[iter_id], mindist):
				mindist = distances[iter_id]
				minid = iter_id
		assert(not minid==null)
		if mindist == null:
			break
		current_id = minid

		var current_node = LayoutInfo.nodes[current_id]
		unvisited.erase(current_id)
		
		current_node.collect_edges()
		for neighbour_id in current_node.edges:
			var edge = current_node.edges[neighbour_id]

			if trainname != null:
				var edge_locked = edge.get_locked()
				if len(edge_locked)>0 and edge_locked != [trainname]:
					continue

			var new_dist = distances[current_id] + edge.weight

			if edge.type == "flip":
				if reversing_behavior=="penalty":
					new_dist += 5000
				if reversing_behavior=="off":
					continue

			if is_smaller_null(new_dist, distances[neighbour_id]):
				distances[neighbour_id] = new_dist
				from_nodes[neighbour_id] = current_id
				# prints("setting distance for",neighbour_id,new_dist, "from", current_id)

	var routes = {}
	for iter_id in LayoutInfo.nodes.keys():
		if not iter_id in from_nodes:
			routes[iter_id] = null
			continue
		var route = LayoutRoute.new()
		var iter_node = LayoutInfo.nodes[iter_id]
		while iter_node.id != id:
			var prev_node = LayoutInfo.nodes[from_nodes[iter_node.id]]
			route.add_prev_edge(prev_node.edges[iter_node.id])
			iter_node = prev_node
		route.setup_legs()
		routes[iter_id] = route
	return routes
