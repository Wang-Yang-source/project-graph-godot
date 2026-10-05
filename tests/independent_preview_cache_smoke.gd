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
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	await process_frame
	for position in [Vector2(100, 100), Vector2(14000, 10000)]:
		var group := stage.create_text_node("Group", position, false)
		var child := stage.create_text_node("Content", position + Vector2(100, 100), false)
		child.container = group
	stage.select_ids(PackedStringArray())
	for frame in 8:
		await process_frame
	stage.camera.zoom = Vector2.ONE * 0.02
	stage.camera.target_zoom = stage.camera.zoom
	for frame in 8:
		await process_frame
	var overview := stage.group_overview
	check(overview._native_previews.size() == 2, "Both groups must have a miniature")
	if overview._native_previews.size() == 2:
		var ids: Array = overview._native_previews.keys()
		var first_image: Sprite2D = overview._native_previews[ids[0]].image
		var second_image: Sprite2D = overview._native_previews[ids[1]].image
		overview._native_resolutions[ids[0]] *= 2
		overview._update_native_previews()
		check(overview._native_previews[ids[0]].image != first_image, "Changed resolution must rebuild its group")
		check(overview._native_previews[ids[1]].image == second_image, "Other group must retain its image and texture")
		overview._native_preview_key.clear()
		overview._update_native_previews()
		check(overview._native_previews[ids[1]].image == second_image, "Unchanged content must survive refresh")
		stage.mark_document_changed()
		overview._update_native_previews()
		check(overview._native_previews[ids[1]].image != second_image, "Document edits must still invalidate cached content")
	stage.queue_free()
	await process_frame
	print("INDEPENDENT_PREVIEW_CACHE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
