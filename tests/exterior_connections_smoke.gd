extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func cuts(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	var inner := rect.grow(-0.1)
	if inner.has_point(start) or inner.has_point(end):
		return true
	var corners := PackedVector2Array([inner.position, Vector2(inner.end.x,inner.position.y),inner.end,Vector2(inner.position.x,inner.end.y)])
	for i in 4:
		if Geometry2D.segment_intersects_segment(start,end,corners[i],corners[(i+1)%4]) != null:
			return true
	return false
func _run() -> void:
	var a := Rect2(0,0,240,160)
	for offset in [Vector2(300,340),Vector2(-300,340),Vector2(0,340),Vector2(300,-340)]:
		var b := Rect2(offset,Vector2(340,160))
		var ports := PackedVector2Array([Vector2(0.5,0),Vector2(0.5,1),Vector2.UP,Vector2.DOWN])
		var path := LineEdge.connection_curve(a,b,ports,64)
		check(path[0].is_equal_approx(LineEdge.anchor(a,ports[0])), "Explicit source port remains attached")
		check(path[-1].is_equal_approx(LineEdge.anchor(b,ports[1])), "Explicit target port remains attached")
		for i in range(1,path.size()):
			check(not cuts(path[i-1],path[i],a) and not cuts(path[i-1],path[i],b), "Back-facing ports route outside both endpoint nodes")
		check((path[1]-path[0]).normalized().dot(Vector2.UP)>0.9,"Source leaves outward")
		check((path[-2]-path[-1]).normalized().dot(Vector2.DOWN)>0.9,"Target approaches from outside")
	print("EXTERIOR_CONNECTIONS: ", "PASS" if failures.is_empty() else failures.size())
	quit(0 if failures.is_empty() else 1)
