extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("effects", false, false)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	await process_frame
	var from := stage.create_text_node("From", Vector2(100, 100), false)
	var to := stage.create_text_node("To", Vector2(400, 300), false)
	var edge: LineEdge = StageObjectRegistry.get_scene("line_edge").instantiate()
	edge.source = from
	edge.target = to
	stage.add_child(edge)
	for frame in 4:
		await process_frame
	stage.camera._set_zoom_animation_active(false)
	edge._process(0.0)
	check(edge._zoom_mesh == null, "Idle edge must not allocate an unused zoom mesh")
	stage.camera._set_zoom_animation_active(true)
	edge._queue_refresh()
	edge._process(0.0)
	check(edge._zoom_mesh != null and edge._zoom_mesh.visible and edge._zoom_mesh.mesh != null, "Animated zoom must build and display the shader mesh")
	var mesh: Mesh = edge._zoom_mesh.mesh
	stage.camera._set_zoom_animation_active(false)
	to.move_without_inertia(to.global_position + Vector2(100, 50))
	to.force_update_transform()
	edge._queue_refresh()
	edge._process(0.0)
	check(edge._zoom_mesh.mesh == mesh and not edge._zoom_mesh.visible, "Moving at rest must preserve the unused mesh")
	check(edge.line.visible and not edge.line.points.is_empty(), "Moving at rest must update the native line")
	stage.camera._set_zoom_animation_active(true)
	edge._queue_refresh()
	edge._process(0.0)
	check(edge._zoom_mesh.mesh != mesh and edge._zoom_mesh.visible, "The next zoom must refresh changed endpoint geometry")
	stage.camera._set_zoom_animation_active(false)
	edge._queue_refresh()
	edge._process(0.0)
	check(edge.line.visible and not edge._zoom_mesh.visible, "Zoom completion must restore the native line")
	stage.queue_free()
	await process_frame
	print("LAZY_ZOOM_MESH: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
