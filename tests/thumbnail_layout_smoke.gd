extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 10: await process_frame
func _run() -> void:
	GraphPreferences.set_value("welcome", false, false)
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200,900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	await process_frame
	var group := stage.create_text_node("父标题", Vector2.ZERO, false)
	var child := stage.create_text_node("键盘底部", Vector2.ZERO, false)
	child.container = group
	for position in [Vector2(-500,-100), Vector2(500,100)]:
		var leaf := stage.create_text_node("子主题", position, false)
		leaf.container = child
		leaf.freeze = true
	var unnamed := stage.create_text_node("", Vector2(3000,0), false)
	for position in [Vector2(2700,-100),Vector2(3300,100)]:
		var leaf := stage.create_text_node("内容", position, false)
		leaf.container = unnamed
		leaf.freeze = true
	group.freeze = true
	child.freeze = true
	unnamed.freeze = true
	stage.select_ids(PackedStringArray())
	await settle()
	var before := StageObjectRegistry.capture(stage)
	var overview := stage.group_overview
	stage.camera.target_zoom = Vector2.ONE * 0.05
	stage.camera.zoom = stage.camera.target_zoom
	await settle()
	check(not overview.is_active(unnamed), "Untitled groups retain detail instead of becoming empty enlarged thumbnails")
	for panel: Panel in overview._summaries.values():
		if not panel.visible: continue
		var title: Label = panel.get_node("Title")
		if title.visible:
			var title_rect := Rect2(title.position, title.size * title.scale)
			check(Rect2(Vector2.ZERO, panel.size).encloses(title_rect), "Thumbnail title stays inside its frame")
	for identifier in overview._summaries:
		if overview._preview_roots.has(identifier): continue
		var panel: Panel = overview._summaries[identifier]
		if not panel.visible: continue
		var rect := panel.get_global_transform() * Rect2(Vector2.ZERO,panel.size)
		for root_id in overview._preview_roots:
			var root_panel := overview._summaries.get(root_id) as Panel
			if root_panel == null or not root_panel.visible: continue
			var title: Label = root_panel.get_node("Title")
			if title.visible:
				check(not rect.intersects(title.get_global_transform() * Rect2(Vector2.ZERO,title.size)), "Child preview does not cover the root title")
	check(StageObjectRegistry.capture(stage) == before, "Thumbnail layout preserves persistent objects")
	var child_rect: Rect2 = overview._preview_display_rect(child.get_instance_id())
	var parent_rect: Rect2 = overview._group_rects[group.get_instance_id()]
	check(child_rect.size.x <= parent_rect.size.x * 0.4 + 0.001 and child_rect.size.y <= parent_rect.size.y * 0.35 + 0.001, "Nested thumbnail height respects its parent cap")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("/tmp/pg-thumbnail-layout.png")
	view.size_2d_override = Vector2i(600,450)
	view.size_2d_override_stretch = true
	stage.camera.target_zoom = Vector2.ONE * 0.025
	stage.camera.zoom = stage.camera.target_zoom
	await settle()
	check(overview.is_active(group), "High DPI retains named group previews")
	for panel: Panel in overview._summaries.values():
		if not panel.visible: continue
		var style := preload("res://src/main/continuous_corners.gd").source(panel.get_theme_stylebox("panel"))
		var pixel_transform := view.get_final_transform() * panel.get_global_transform_with_canvas()
		var core := style.border_width_left * pixel_transform.x.length()
		check(core <= 1.07, "Thumbnail border remains thin at high DPI")
	unnamed.text = "新标题"
	await settle()
	check(overview.is_active(unnamed), "Adding a title refreshes preview eligibility without zoom")
	unnamed.text = ""
	await settle()
	check(not overview.is_active(unnamed), "Removing a title restores unnamed group detail")
	stage.camera.target_zoom = Vector2.ONE * 2.0
	stage.camera.zoom = stage.camera.target_zoom
	await settle()
	check(overview._summaries.is_empty(), "Zooming in restores real detail")
	check(StageObjectRegistry.capture(stage) == before, "Preview round trip preserves layout")
	view.queue_free()
	await process_frame
	print("THUMBNAIL_LAYOUT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
