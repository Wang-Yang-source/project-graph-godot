extends RefCounted
## Native visibility graph for ports which face away from the other endpoint.
## Only endpoint rectangles are obstacles; no document-wide routing solver.
static func route(from_rect: Rect2, to_rect: Rect2, start: Vector2, end: Vector2, normal: Vector2, end_normal: Vector2) -> PackedVector2Array:
	var clearance := 6.0
	var obstacles: Array[Rect2] = [from_rect.grow(clearance), to_rect.grow(clearance)]
	var exits := PackedVector2Array([_exit(obstacles[0],start,normal),_exit(obstacles[1],end,end_normal)])
	var graph := AStar2D.new()
	for i in 2:
		graph.add_point(i,exits[i])
	var candidates := exits.duplicate()
	for rect in obstacles:
		candidates.append_array(_corners(rect))
	for i in range(2,candidates.size()):
		graph.add_point(i,candidates[i])
	for i in candidates.size():
		for j in range(i+1,candidates.size()):
			if not _cuts(candidates[i],candidates[j],obstacles[0]) and not _cuts(candidates[i],candidates[j],obstacles[1]):
				graph.connect_points(i,j)
	var middle := graph.get_point_path(0,1)
	if middle.is_empty():
		return PackedVector2Array()
	var result := PackedVector2Array([start])
	result.append_array(middle)
	result.append(end)
	return result


static func _exit(rect: Rect2, point: Vector2, normal: Vector2) -> Vector2:
	var ray_end := point + normal.normalized() * (rect.size.length() * 2.0 + 1.0)
	var corners := _corners(rect)
	var farthest := point
	for i in 4:
		var hit: Variant = Geometry2D.segment_intersects_segment(point,ray_end,corners[i],corners[(i+1)%4])
		if hit != null and point.distance_squared_to(hit) > point.distance_squared_to(farthest):
			farthest = hit
	return farthest


static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


static func _cuts(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	# Boundary travel is permitted; entering the rectangle is not.
	var inner := rect.grow(-0.1)
	if inner.has_point(start) or inner.has_point(end):
		return true
	var corners := _corners(inner)
	for i in 4:
		if Geometry2D.segment_intersects_segment(start,end,corners[i],corners[(i+1)%4]) != null:
			return true
	return false
