extends SceneTree
## Regression for local preview pixels and glyph metrics during world translation.
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

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var group := stage.create_text_node("Moving group", Vector2.ZERO, false)
	var child := stage.create_text_node("Member", Vector2(100, 100), false)
	child.container = group
	var other := stage.create_text_node("Stationary group", Vector2(1500, 0), false)
	var other_child := stage.create_text_node("Other member", Vector2(1600, 100), false)
	other_child.container = other
	stage.select_ids(PackedStringArray())
	stage.camera.set_process(false)
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
	# Isolate equal world translation from the mover's independent propagation.
	stage.get_node("EntityLayerMover").set_physics_process(false)
	for object in [group, child, other, other_child]:
		object.freeze = true
	var overview = stage.group_overview
	var group_id := group.get_instance_id()
	var other_id := other.get_instance_id()
	check(overview._native_previews.has(group_id) and overview._native_previews.has(other_id), "Both framed groups have previews")
	if not overview._native_previews.has(group_id) or not overview._native_previews.has(other_id):
		view.queue_free()
		await process_frame
		quit(1)
		return
	var image: Sprite2D = overview._native_previews[group_id].image
	var other_image: Sprite2D = overview._native_previews[other_id].image
	var content: Array = overview._native_previews[group_id].content_key.duplicate(true)
	var other_bounds: Rect2 = overview._entity_rects[other_id]
	var original_position := image.position
	var detail = stage.get_node("TextDetail")
	var thresholds: Array = detail._thresholds.duplicate()
	var delta := Vector2(64, 32)
	group.move_without_inertia(group.global_position + delta)
	child.move_without_inertia(child.global_position + delta)
	await settle()
	check(overview._native_previews[group_id].image == image, "Equal group translation reuses the existing preview")
	check(overview._native_previews[group_id].content_key == content, "Equal translation preserves local copied content")
	check(image.position.is_equal_approx(original_position + delta), "Reused preview follows the current world bounds")
	check(overview._native_previews[other_id].image == other_image and overview._entity_rects[other_id] == other_bounds, "Unrelated preview and bounds remain unchanged")
	check(detail._thresholds == thresholds, "World translation preserves glyph thresholds")
	child.move_without_inertia(child.global_position + Vector2(32, 0))
	await settle()
	check(overview._native_previews[group_id].image != image, "Relative member movement invalidates copied pixels")
	check(overview._native_previews[other_id].image == other_image, "Relative movement retains unrelated copied pixels")
	image = overview._native_previews[group_id].image
	child.text = "Changed member content"
	await settle()
	check(overview._native_previews[group_id].image != image, "Text edits invalidate cached miniature content")
	var previous: Array = detail._thresholds.duplicate()
	child.font_size = 48
	await settle()
	check(detail._thresholds != previous, "Font edits update glyph thresholds")
	child.container = other
	await settle()
	check(overview._preview_parents.get(child.get_instance_id(), 0) == other_id, "Reparenting updates cached preview topology")
	view.queue_free()
	await process_frame
	print("OVERVIEW_LOCAL_TRANSLATION: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
