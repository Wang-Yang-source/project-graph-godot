extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 10:
		await physics_frame
		await process_frame
func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	root.size = Vector2i(1200,900)
	var view := SubViewport.new()
	view.size = root.size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var group := stage.create_text_node("手动调整树形布局", Vector2.ZERO, false)
	var instruction := stage.create_text_node("按住Ctrl键\n鼠标放在绿色节点上\n滚动鼠标滚轮", Vector2(-900,0), false)
	instruction.container = group
	var number := stage.create_text_node("21", Vector2(900,0), false)
	number.container = group
	var coloured := stage.create_text_node("18", Vector2(900,350), false)
	coloured.fill_color = Color.GREEN
	coloured.container = group
	for object in [group,instruction,number,coloured]:
		object.freeze = true
	stage.select_ids(PackedStringArray())
	stage.camera.set_process(false)
	await settle()
	var before := StageObjectRegistry.capture(stage)
	var overview = stage.group_overview
	for zoom_value in [.3, .1, .04]:
		stage.camera.zoom = Vector2.ONE * zoom_value
		stage.camera.target_zoom = stage.camera.zoom
		stage.camera.position = group.aabb.get_center()
		stage.camera.force_update_scroll()
		await settle()
		check(overview.is_active(group), "Group enters overview at test scale")
		for object in [instruction,number,coloured]:
			check(overview._preview_display_rect(object.get_instance_id()).is_equal_approx(object.aabb), "Tiny node geometry is never inflated")
		for identifier in overview._summaries:
			var panel: Panel = overview._summaries[identifier]
			var title: Label = panel.get_node("Title")
			if not panel.visible or not title.visible:
				continue
			var title_rect := Rect2(title.position, title.size * title.scale)
			check(Rect2(Vector2.ZERO,panel.size).grow(.01).encloses(title_rect), "Title fits its own node or group header")
			var pixels := title.get_theme_font_size("font_size") * (view.get_final_transform() * title.get_global_transform_with_canvas()).get_scale().x
			check(pixels <= 24.01, "Digits stay below the physical font cap")
			if identifier == group.get_instance_id():
				check(title_rect.end.y <= panel.size.y * .21, "Group title stays in the header strip")
			if identifier == instruction.get_instance_id():
				check(title.text == instruction.text, "Instruction line breaks are preserved")
		check(StageObjectRegistry.capture(stage) == before, "Overview never rewrites the graph")
	view.queue_free()
	await process_frame
	print("THUMBNAIL_TITLE_FIT: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
