extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 8:
		await physics_frame
		await process_frame

func group(stage: Stage, title: String, offset: Vector2) -> TextNode:
	var parent := stage.create_text_node(title, offset, false)
	var a := stage.create_text_node("A", offset + Vector2(50, 50), false)
	a.container = parent
	var b := stage.create_text_node("B", offset + Vector2(500, 50), false)
	b.container = parent
	stage.connect_entities(a, b)
	return parent

func image_for(stage: Stage, parent: TextNode) -> int:
	return stage.group_overview._native_previews[parent.get_instance_id()].image.get_instance_id()

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var first := group(stage, "First", Vector2.ZERO)
	var second := group(stage, "Second", Vector2(1500, 0))
	var unrelated := stage.create_text_node("Unrelated", Vector2(5000, 0), false)
	stage.select_ids(PackedStringArray())
	stage.camera.set_process(false)
	stage.camera.zoom = Vector2.ONE * .08
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
	var overview := stage.group_overview
	check(overview._native_previews.size() == 2, "Both groups have cached miniature bodies")
	if overview._native_previews.size() != 2:
		quit(1)
		return
	var first_image := image_for(stage, first)
	var second_image := image_for(stage, second)
	unrelated.move_without_inertia(Vector2(5010, 0))
	await settle()
	check(image_for(stage, first) == first_image and image_for(stage, second) == second_image, "Unrelated movement preserves both native caches")
	var member: TextNode
	var edge: LineEdge
	for object in stage.stage_objects():
		if object is TextNode and object.container == first:
			member = object
		elif object is LineEdge and object.source.container == first:
			edge = object
	member.move_without_inertia(member.global_position + Vector2(20, 0))
	await settle()
	check(image_for(stage, first) != first_image, "Member movement refreshes its own group")
	check(image_for(stage, second) == second_image, "Member movement does not refresh the other group")
	first_image = image_for(stage, first)
	member.fill_color = Color.RED
	await settle()
	check(image_for(stage, first) != first_image, "Member color changes refresh the miniature")
	first_image = image_for(stage, first)
	edge.stroke_color = Color.GREEN
	await settle()
	check(image_for(stage, first) != first_image, "Edge color changes refresh despite unchanged endpoint geometry")
	first_image = image_for(stage, first)
	var before := JSON.stringify(StageObjectRegistry.capture(stage).objects)
	await settle()
	check(image_for(stage, first) == first_image and image_for(stage, second) == second_image, "Idle groups retain cached bodies")
	check(JSON.stringify(StageObjectRegistry.capture(stage).objects) == before, "Preview updates preserve persistent data")
	view.queue_free()
	await settle()
	print("GROUP_PREVIEW_CONTENT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
