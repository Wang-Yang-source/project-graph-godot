extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in 6:
		await process_frame

func check_title(group: TextNode, context: String) -> void:
	check(group._container_active, context + ": group is active")
	check(is_equal_approx(group.label.size.x, group.container_panel.size.x), context + ": title spans frame width")
	var title_center := group.label.global_position.x + group.label.size.x * 0.5
	var frame_center := group.container_panel.global_position.x + group.container_panel.size.x * 0.5
	check(is_equal_approx(title_center, frame_center), context + ": title stays horizontally centered")
	check(group.label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, context + ": text alignment is centered")
	check(group.label.position.is_equal_approx(group.container_panel.position), context + ": title stays at frame top")

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1100, 700)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	await settle()
	var group := stage.create_text_node("Hello", Vector2.ZERO, false)
	var member := stage.create_text_node("Hello, Waya!", Vector2(100, 120), false)
	var second := stage.create_text_node("...", Vector2(100, 270), false)
	member.container = group
	second.container = group
	var edge := stage.connect_entities(member, second)
	check(edge != null, "Fixture has an internal connection")
	await settle()
	check_title(group, "created")
	var before := StageObjectRegistry.capture(stage)
	group._apply_appearance()
	check_title(group, "immediately after style refresh")
	await settle()
	check_title(group, "settled after style refresh")
	check(StageObjectRegistry.capture(stage) == before, "Style refresh does not change document data")
	group.text = "Hello again"
	check_title(group, "text changed before movement")
	group.font_size = 30
	check_title(group, "font changed before movement")
	group.fixed_width = 500.0
	await settle()
	check_title(group, "fixed width changed")
	group._apply_appearance(true, true)
	check_title(group, "light theme")
	group._apply_appearance(true, false)
	check_title(group, "dark theme")
	group.enter_edit_mode()
	await settle()
	group.exit_edit_mode(false)
	await settle()
	check_title(group, "editing canceled")
	group.set_loading_container_rect(group.aabb)
	group._apply_appearance()
	check_title(group, "loading bounds and style refresh")
	var old_position := group.global_position
	group.move_without_inertia(old_position + Vector2(80, 40))
	await settle()
	check_title(group, "moved")
	if DisplayServer.get_name() != "headless":
		stage.camera.zoom = Vector2.ONE
		stage.camera.target_zoom = stage.camera.zoom
		stage.camera.global_position = group.aabb.get_center()
		stage.camera.target_position = stage.camera.global_position
		await settle()
		await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().save_png("/tmp/pg-group-title-centered.png") == OK, "Visual capture saves")
	view.queue_free()
	await process_frame
	print("GROUP_TITLE_ALIGNMENT: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
