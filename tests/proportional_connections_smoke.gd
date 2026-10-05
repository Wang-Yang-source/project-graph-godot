extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var from_rect := Rect2(Vector2.ZERO, Vector2(120, 80))
	var to_rect := Rect2(Vector2(1000, 600), Vector2(180, 100))
	var anchors := PackedVector2Array([Vector2(1, 0.5), Vector2(0.5, 0), Vector2.RIGHT, Vector2.UP])
	var forward := LineEdge.connection_curve(from_rect, to_rect, anchors, 64)
	var scaled := LineEdge.connection_curve(Rect2(from_rect.position * 4, from_rect.size * 4), Rect2(to_rect.position * 4, to_rect.size * 4), anchors, 64)
	var reverse_anchors := PackedVector2Array([anchors[1], anchors[0], anchors[3], anchors[2]])
	var reverse := LineEdge.connection_curve(to_rect, from_rect, reverse_anchors, 64)
	for index in forward.size():
		check(scaled[index].distance_to(forward[index] * 4) < 0.01, "Curve shape scales with node spacing")
		check(reverse[reverse.size() - 1 - index].distance_to(forward[index]) < 0.01, "Curve geometry is independent of edge direction")
	check((forward[1] - forward[0]).normalized().dot(anchors[2]) > 0.98, "Source tangent follows the node outline normal")
	check((forward[forward.size()-2] - forward[forward.size()-1]).normalized().dot(anchors[3]) > 0.98, "Target tangent follows the node outline normal")
	for offset in [Vector2(135, 0), Vector2(140, 20), Vector2(400, 120), Vector2(1800, 360)]:
		var target := Rect2(offset, from_rect.size)
		var ports := LineEdge.connection_uvs(from_rect, target)
		var curve := LineEdge.connection_curve(from_rect, target, ports, 64)
		var direction := (curve[curve.size()-1] - curve[0]).normalized()
		for index in range(1, curve.size()):
			check((curve[index]-curve[index-1]).dot(direction) >= -0.01, "Close and distant connections do not fold back")
	print("PROPORTIONAL_CONNECTIONS: ", "PASS" if failures.is_empty() else failures.size())
	quit(0 if failures.is_empty() else 1)
