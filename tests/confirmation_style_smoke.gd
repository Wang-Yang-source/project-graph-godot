extends SceneTree
const Palette = preload("res://src/main/theme_palette.gd")
const Corners = preload("res://src/main/continuous_corners.gd")
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
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("theme", "mocha", false)
	GraphPreferences.set_value("ui_scale", 100.0, false)
	root.size = Vector2i(1280, 800)
	var app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	for frame in 20:
		await process_frame
	app.get_node("UIOverlay/Welcome").hide()
	var dialog: ConfirmationDialog = app.get_node("UIOverlay/UnsavedDialog")
	var overlay := dialog.get_parent()
	var backdrop := overlay.get_node("ModalBackdrop") as ColorRect
	check(not backdrop.visible, "Backdrop starts hidden")
	var stage: Stage = app.tabs.get_current_stage()
	var container = app.tabs.tab_for_stage(stage)
	var count: int = app.tabs.get_tab_count()
	for light in [false, true]:
		app._apply_preferences("theme", "latte" if light else "mocha")
		app._on_close_requested(container)
		for frame in 15:
			await process_frame
		var frame := Corners.source(dialog.get_theme_stylebox("embedded_border"))
		check(frame != null and frame.bg_color == Palette.color(light, "surface.raised") and frame.bg_color.a == 1.0, "Dialog has opaque palette surface")
		check(frame.border_color == Palette.color(light, "border.default"), "Frame uses shared palette border")
		check(backdrop.visible and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Modal backdrop dims without taking native input")
		check(backdrop.get_rect().size.is_equal_approx(root.get_visible_rect().size), "Backdrop covers the root viewport")
		for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
			var box := Corners.source(button.get_theme_stylebox("normal"))
			check(box != null and box.corner_radius_top_left == 8, "Both actions share the control radius")
			check(button.size.y >= 40 and button.size.x >= 96, "Native dialog keeps consistent action dimensions")
		check(Corners.source(dialog.get_ok_button().get_theme_stylebox("normal")).bg_color == Palette.color(light, "accent.primary"), "Save stays the primary action")
		check(Corners.source(dialog.get_cancel_button().get_theme_stylebox("normal")).bg_color == Palette.color(light, "surface.hover"), "Secondary action uses Surface0")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pg-confirmation-" + ("latte" if light else "mocha") + ".png")
		dialog.hide()
		dialog.canceled.emit()
		await process_frame
		check(not backdrop.visible, "Cancel removes the backdrop")
		check(app.tabs.get_tab_count() == count and app._pending_close == null and not app._quitting, "Cancel preserves the document and resets close state")
		# Reopening must reuse one backdrop, including a second exclusive dialog.
		app.DialogTheme.apply_controls(dialog)
		var clear: ConfirmationDialog = app.get_node("UIOverlay/ConfirmClear")
		clear.popup_centered()
		await process_frame
		check(backdrop.visible, "Other confirmation uses the same backdrop")
		clear.hide()
		await process_frame
		check(not backdrop.visible and overlay.get_node("ModalBackdrop") == backdrop, "Closing confirmation leaves no stale dim layer")
	app.queue_free()
	await process_frame
	print("CONFIRMATION_STYLE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
