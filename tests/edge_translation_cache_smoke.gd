extends SceneTree
## Run only through the authorized Godot MCP regression runner.
class GeometryProbe:
	extends LineEdge
	var geometry_builds := 0

	func _update_collision_shape(points: PackedVector2Array) -> void:
		geometry_builds += 1
		super._update_collision_shape(points)


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func edge_between(stage: Stage, source: Entity, target: Entity, identifier: String) -> LineEdge:
	var edge := StageObjectRegistry.get_scene("line_edge").instantiate() as LineEdge
	edge.set_script(GeometryProbe)
	edge.id = identifier
	edge.source = source
	edge.target = target
	edge.text = identifier
	stage.add_child(edge)
	stage.apply_object_preferences(edge)
	return edge


func path_distance(point: Vector2, edge: LineEdge) -> float:
	var distance := INF
	for index in range(edge.line.points.size() - 1):
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(
			point, edge.line.to_global(edge.line.points[index]), edge.line.to_global(edge.line.points[index + 1]))))
	return distance


func check_pair(forward: LineEdge, reverse: LineEdge) -> void:
	# Pair consolidation is an independent optional feature. Exercise its
	# compatibility when present without making this cache depend on it.
	if not forward.has_method("reciprocal_peer"):
		return
	check(int(forward.line.visible) + int(reverse.line.visible) == 1, "Reciprocal pair keeps one visible shaft")
	check(forward.arrow_head.visible and reverse.arrow_head.visible, "Reciprocal pair keeps both endpoint arrows")
	check(forward.line.points.size() > 1 and reverse.line.points.size() > 1, "Both reciprocal paths have samples")
	# Adaptive tessellation may choose different subdivisions in reverse.
	# Compare the actual paths instead of assuming identical vertex counts.
	var maximum := 0.0
	for pair in [[forward, reverse], [reverse, forward]]:
		for point in pair[0].line.points:
			maximum = maxf(maximum, path_distance(pair[0].line.to_global(point), pair[1]))
	check(maximum < 0.1, "Reciprocal shafts share the world path: maximum=%s" % maximum)


func _run() -> void:
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	stage.camera.zoom = Vector2.ONE * 0.8
	stage.camera.target_zoom = stage.camera.zoom
	var a := stage.create_text_node("A", Vector2(-240, 100), false)
	var b := stage.create_text_node("B", Vector2(240, -100), false)
	var unrelated := stage.create_text_node("Third object", Vector2(2000, 2000), false)
	# Instrumentation keeps the same persistent identity as its production base.
	StageObjectRegistry._type_for(a)
	StageObjectRegistry._type_by_script[GeometryProbe] = "line_edge"
	var forward := edge_between(stage, a, b, "translation_forward")
	var reverse := edge_between(stage, b, a, "translation_reverse")
	await frames(10)
	check_pair(forward, reverse)
	var tracked := {}
	for edge in [forward, reverse]:
		tracked[edge] = {
			"builds": edge.get("geometry_builds"),
			"points": edge.line.points.duplicate(),
			"segments": (edge.collision_shape.shape as ConcavePolygonShape2D).segments.duplicate(),
			"curve_first": edge._caption_curve.get_point_position(0),
			"caption": edge.to_global(edge.caption_position(0.5)),
			"tip": edge.arrow_head.global_position,
			"pose": edge.transform,
			"world_points": edge._shaft_points.duplicate(),
			"collision_first": edge.collision_shape.to_global((edge.collision_shape.shape as ConcavePolygonShape2D).segments[0]),
		}
	stage.history.begin_transaction()
	var displacement := Vector2(64, -32)
	a.position += displacement
	b.position += displacement
	await frames(8)
	for edge in [forward, reverse]:
		var before: Dictionary = tracked[edge]
		check(edge.get("geometry_builds") == before.builds, "Common translation does not rebuild collision or curve")
		check(edge.line.points == before.points, "Common translation reuses native shaft vertices")
		check((edge.collision_shape.shape as ConcavePolygonShape2D).segments == before.segments, "Common translation reuses local picking segments")
		check(edge._caption_curve.get_point_position(0) == before.curve_first, "Common translation keeps caption baking")
		check(edge.to_global(edge.caption_position(0.5)).is_equal_approx(before.caption + displacement), "Caption world position translates")
		check(edge.arrow_head.global_position.is_equal_approx(before.tip + displacement), "Arrow world position translates")
		check(edge.transform == before.pose, "Presentation changes do not alter persistent edge pose")
		check(edge._shaft_points == Transform2D(0.0, displacement) * before.world_points, "World-point interface remains current")
		for index in mini(edge.line.points.size(), edge._shaft_points.size()):
			check(edge.line.to_global(edge.line.points[index]).is_equal_approx(edge._shaft_points[index]), "Shaft and world samples agree")
		var segments: PackedVector2Array = (edge.collision_shape.shape as ConcavePolygonShape2D).segments
		if not segments.is_empty():
			check(edge.collision_shape.to_global(segments[0]).is_equal_approx(before.collision_first + displacement), "Picking segment follows translated shaft")
	check_pair(forward, reverse)
	stage.history.commit(false)
	await stage.history.undo()
	await frames(8)
	for edge in [forward, reverse]:
		check(edge.arrow_head.global_position.is_equal_approx(tracked[edge].tip), "Undo restores translated arrow")
		check(edge.to_global(edge.caption_position(0.5)).is_equal_approx(tracked[edge].caption), "Undo restores caption path")
	await stage.history.redo()
	await frames(8)
	check_pair(forward, reverse)
	var count: int = forward.get("geometry_builds")
	unrelated.position += Vector2(80, 60)
	await frames(6)
	check(forward.get("geometry_builds") == count, "Unrelated third object does not affect endpoint-only routing")
	b.position += Vector2(80, 120)
	await frames(8)
	check(forward.get("geometry_builds") > count, "Boundary movement rebuilds the curve")
	check_pair(forward, reverse)
	count = forward.get("geometry_builds")
	a.fixed_width = a.get_visual_rect().size.x + 70.0
	await frames(8)
	check(forward.get("geometry_builds") > count, "Endpoint size changes rebuild the curve")
	stage.camera.zoom = Vector2.ONE * 2.0
	stage.camera.target_zoom = stage.camera.zoom
	await frames(8)
	check_pair(forward, reverse)
	reverse.show_arrow = false
	await frames(6)
	check(not reverse.arrow_head.visible and forward.arrow_head.visible, "Arrow settings remain independently editable")
	stage.queue_free()
	await process_frame
	print("EDGE_TRANSLATION_CACHE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
