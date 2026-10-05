extends SceneTree
const Capture = preload("res://src/stage/preview_texture_capture.gd")
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
	var overview := stage.group_overview
	var view := SubViewport.new()
	view.size = Vector2i(512, 512)
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	overview.add_child(view)
	var panel := ColorRect.new()
	panel.size = Vector2(512, 512)
	panel.color = Color.RED
	view.add_child(panel)
	await RenderingServer.frame_post_draw
	var image := Sprite2D.new()
	image.texture = view.get_texture()
	overview.add_child(image)
	var data := {"view":view, "image":image, "capture_pending":true}
	overview._complete_preview_capture(null, data)
	check(not view.is_queued_for_deletion() and image.texture != null, "Failed readback must preserve the rendered preview")
	data.capture_pending = true
	Capture.capture(view, overview._complete_preview_capture.bind(data))
	overview._release_native_preview(data)
	check(data.cancelled and not view.is_queued_for_deletion(), "Cancelled capture must retain its source until completion")
	var started := Time.get_ticks_msec()
	while data.capture_pending and Time.get_ticks_msec() - started < 3000:
		await process_frame
	check(not data.capture_pending, "Cancelled capture must drain")
	check(not is_instance_valid(view) or view.is_queued_for_deletion(), "Cancelled viewport must be released")
	check(not is_instance_valid(image) or image.is_queued_for_deletion(), "Cancelled image must not be replaced")
	stage.queue_free()
	await process_frame
	print("ASYNC_PREVIEW_LIFECYCLE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
