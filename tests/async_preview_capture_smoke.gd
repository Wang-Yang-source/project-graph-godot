extends SceneTree
const Capture = preload("res://src/stage/preview_texture_capture.gd")
var failures: Array[String] = []
var captured: Image
var main_thread := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _complete(image: Image) -> void:
	check(OS.get_thread_caller_id() == main_thread, "Completion must run on the main thread")
	captured = image

func _run() -> void:
	main_thread = OS.get_thread_caller_id()
	var view := SubViewport.new()
	view.size = Vector2i(128, 64)
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(view)
	var panel := ColorRect.new()
	panel.size = Vector2(64, 64)
	panel.color = Color(0.8, 0.2, 0.1, 0.5)
	view.add_child(panel)
	await RenderingServer.frame_post_draw
	var expected := view.get_texture().get_image()
	Capture.capture(view, _complete)
	var started := Time.get_ticks_msec()
	while captured == null and Time.get_ticks_msec() - started < 3000:
		await process_frame
	check(captured != null and not captured.is_empty(), "Capture must finish without blocking frame processing")
	if captured != null and not captured.is_empty():
		check(captured.get_size() == expected.get_size() and captured.has_mipmaps(), "Capture must preserve dimensions and provide mipmaps")
		check(captured.get_pixel(32, 32).is_equal_approx(expected.get_pixel(32, 32)), "Colors and alpha must match native capture")
		check(captured.get_pixel(96, 32).is_equal_approx(expected.get_pixel(96, 32)), "Transparent pixels must be preserved")
	view.queue_free()
	await process_frame
	print("ASYNC_PREVIEW_CAPTURE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
