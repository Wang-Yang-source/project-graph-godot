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
		overview._frame_scale = 1000.0
		overview._update_native_previews()
		var first_image: Sprite2D = overview._native_previews[ids[0]].image
		var second_image: Sprite2D = overview._native_previews[ids[1]].image
		var sampled_resolution: int = overview._native_resolutions[ids[0]]
		check(sampled_resolution > 0, "Close preview must have a sampled resolution")
		for sampling_scale in [0.00001, 1000.0, 0.00001]:
			overview._frame_scale = sampling_scale
			overview._update_native_previews()
			check(overview._native_previews[ids[0]].image == first_image, "Repeated zoom changes must retain the sampled preview")
			check(overview._native_previews[ids[1]].image == second_image, "Repeated zoom changes must retain independent group textures")
			check(overview._native_resolutions[ids[0]] == sampled_resolution, "Cached resolution must not oscillate with camera zoom")
		stage.mark_document_changed()
		overview._update_native_previews()
		check(overview._native_previews[ids[0]].image != first_image, "Document edits must still refresh the preview")
	stage.queue_free()
	await process_frame
	print("PREVIEW_ZOOM_CACHE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
