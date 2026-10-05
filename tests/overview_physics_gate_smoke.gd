extends SceneTree
## Actual overview membership owns the native physics-space gate.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 8:
		await physics_frame
		await process_frame

func in_space(entity: Entity, space: RID) -> bool:
	return PhysicsServer2D.body_get_space(entity.get_rid()) == space

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var group := stage.create_text_node("Root group", Vector2.ZERO, false)
	var nested := stage.create_text_node("Nested group", Vector2(100, 100), false)
	var member := stage.create_text_node("Hidden member", Vector2(200, 200), false)
	nested.container = group
	member.container = nested
	stage.select_ids(PackedStringArray())
	stage.camera.set_process(false)
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
	var overview = stage.group_overview
	var space: RID = stage.get_world_2d().space
	check(overview._active.has(group.get_instance_id()), "Low zoom displays the root overview")
	check(in_space(group, space), "The displayed root remains the whole-group collision body")
	check(overview.is_hidden(nested) and overview.is_hidden(member), "Nested internals are covered by the root preview")
	check(in_space(nested, RID()) and in_space(member, RID()), "Covered nested bodies leave the physics space")
	var arriving := stage.create_text_node("Arriving member", Vector2(300, 200), false)
	arriving.container = group
	overview.register_loading_object(arriving)
	check(overview.is_hidden(arriving) and in_space(arriving, RID()), "Progressive-load gating detaches an arriving hidden body immediately")
	stage.camera.zoom = Vector2.ONE * 8.0
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
	check(not overview.is_hidden(nested) and not overview.is_hidden(member), "Zooming in restores the native members")
	check(in_space(nested, space) and in_space(member, space) and in_space(arriving, space), "Expanded members return to the current world space")
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
	check(in_space(member, RID()), "A later collapse detaches the restored member again")
	overview.get_parent().remove_child(overview)
	check(in_space(nested, space) and in_space(member, space) and in_space(arriving, space), "Overview teardown restores every hidden member")
	overview.free()
	view.queue_free()
	await process_frame
	print("OVERVIEW_PHYSICS_GATE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
