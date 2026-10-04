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


func settle() -> void:
	for frame in 8:
		await physics_frame
		await process_frame


func zoom_to(stage: Stage, value: float) -> void:
	stage.camera.position = Vector2.ZERO
	stage.camera.target_position = Vector2.ZERO
	stage.camera.zoom = Vector2.ONE * value
	stage.camera.target_zoom = stage.camera.zoom
	await settle()


func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	GraphPreferences.set_value("theme", "mocha", false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var backing := ColorRect.new()
	backing.color = Palette.color(false, "surface.canvas")
	backing.size = Vector2(view.size)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(backing)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var node := stage.create_text_node("透明文本 Transparent", Vector2.ZERO, false)
	node.freeze = true
	# A wide document permits tiny zooms without hitting the document navigation floor.
	stage.create_text_node("Extent", Vector2(-10000, -10000), false).freeze = true
	stage.create_text_node("Extent", Vector2(10000, 10000), false).freeze = true
	stage.apply_theme(false)
	await zoom_to(stage, 1.0)
	var bounds := node.get_visual_rect()
	var saved := JSON.stringify(StageObjectRegistry.capture(stage).objects)
	check(node.display_fill_color() == Color.TRANSPARENT, "Normal text nodes have no backing")
	check(node.label.get_theme_color("font_color") == Color("#cdd6f4"), "Default text uses Mocha Text")
	var style := Corners.source(node.label.get_theme_stylebox("normal"))
	check(style.border_color == Color("#585b70") and style.border_width_left == 2, "Mocha Surface2 and master world border width")
	await zoom_to(stage, 4.9 / node.font_size)
	check(node.label.visible_characters == 0, "Master hides text below five screen pixels")
	check(node.display_fill_color() == Color(Color("#585b70"), 0.2), "Tiny transparent text receives twenty-percent Surface2")
	check(node.get_visual_rect() == bounds, "Tiny fill does not move or resize the node")
	check(JSON.stringify(StageObjectRegistry.capture(stage).objects) == saved, "Zoom preserves serialized colors and geometry")
	await zoom_to(stage, 5.1 / node.font_size)
	check(node.label.visible_characters == -1 and node.display_fill_color() == Color.TRANSPARENT, "Zooming in restores text and transparent backing")
	node.fill_color = Color(Color("#89b4fa"), 0.35)
	await zoom_to(stage, 4.9 / node.font_size)
	check(node.display_fill_color() == node.fill_color, "Custom translucent alpha is preserved even below threshold")
	check(node.label.get_theme_color("font_color") == Color("#cdd6f4"), "Translucent fill retains theme text")
	node.fill_color = Color.WHITE
	await settle()
	var foreground := node.label.get_theme_color("font_color")
	check(foreground.srgb_to_linear().get_luminance() < 0.1, "Opaque white fill receives readable dark text")
	node.fill_color = Color.TRANSPARENT
	await zoom_to(stage, 1.0)
	node.enter_edit_mode()
	await settle()
	check(node.text_edit.get_theme_color("font_color") == Color("#cdd6f4"), "Editor matches displayed Mocha text")
	check(node.text_edit.get_theme_color("caret_color") == Color("#cdd6f4"), "Caret matches theme text")
	node.exit_edit_mode(false)
	stage.select_ids(PackedStringArray())
	var member := stage.create_text_node("成员", Vector2(80, 80), false)
	member.freeze = true
	member.container = node
	stage.select_ids(PackedStringArray())
	await settle()
	await zoom_to(stage, 0.1)
	if stage.group_overview._summaries.has(node.get_instance_id()):
		var summary: Panel = stage.group_overview._summaries[node.get_instance_id()]
		check(summary.get_node("Title").get_theme_color("font_color") == node.display_text_color(false), "Overview uses the same theme text rule")
	else:
		check(false, "Group overview activates for theme verification")
	stage.apply_theme(true)
	await settle()
	check(node.label.get_theme_color("font_color") == Palette.color(true, "canvas.node.text"), "Existing light theme remains supported")
	if DisplayServer.get_name() != "headless":
		await zoom_to(stage, 1.0)
		stage.apply_theme(false)
		await settle()
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("/tmp/pg-master-text-colors.png")
	await zoom_to(stage, 0.1)
	var late := stage.create_text_node("新节点", Vector2(-300, 0), false)
	late.freeze = true
	await settle()
	check(late.label.visible_characters == 0 and is_equal_approx(late.display_fill_color().a, 0.2), "New nodes inherit tiny fill and text state")
	stage.get_node("TextDetail").queue_free()
	await settle()
	check(late.label.visible_characters == -1 and late.display_fill_color() == Color.TRANSPARENT, "Removing detail manager restores text and backing")
	view.queue_free()
	await process_frame
	print("MASTER_TEXT_COLORS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
