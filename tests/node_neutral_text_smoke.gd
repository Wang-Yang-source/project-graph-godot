extends SceneTree
const Palette = preload("res://src/main/theme_palette.gd")
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

func check_color(node: TextNode, light: bool, context: String) -> void:
	var expected := Palette.neutral_text_color(node.display_background_color(light))
	var displayed := node.label.get_theme_color("font_color")
	check(displayed.is_equal_approx(expected), context + ": node text follows composited background")
	check(node.text_edit.get_theme_color("font_color").is_equal_approx(expected), context + ": editor uses same neutral color")
	var latex := node.label.get_node_or_null("LatexPreview") as CanvasItem
	if latex != null:
		check(latex.self_modulate.is_equal_approx(expected), context + ": LaTeX uses same neutral tint")
	check(is_equal_approx(displayed.r, displayed.g) and is_equal_approx(displayed.g, displayed.b), context + ": only neutral gray is rendered")
	check(is_equal_approx(displayed.a, 1.0), context + ": saved transparency does not fade text")
	var ink := displayed.srgb_to_linear().get_luminance()
	var backdrop := node.display_background_color(light).srgb_to_linear().get_luminance()
	var contrast := (maxf(ink, backdrop) + 0.05) / (minf(ink, backdrop) + 0.05)
	check(contrast >= 4.5, context + ": visible text has readable contrast")

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1000, 700)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	await settle()
	var nodes: Array[TextNode] = []
	var fills := [Color.TRANSPARENT, Color.WHITE, Color.BLACK, Color("#777777"), Color("#cdd6f4"), Color("#cba6f7"), Color(1, 0, 0, 0.4)]
	for index in fills.size():
		var node := stage.create_text_node("Readable text " + str(index), Vector2((index % 3) * 280 - 300, int(index / 3.0) * 140 - 100), false)
		node.fill_color = fills[index]
		node.text_color = Color("#cdd6f4") if index % 2 == 0 else Color(1, 0, 0, 0.2)
		nodes.append(node)
	var group := stage.create_text_node("Group", Vector2.ZERO, false)
	group.fill_color = Color(0, 0, 0, 0.6)
	var inner := stage.create_text_node("Nested translucent background", Vector2(0, 300), false)
	inner.fill_color = Color(1, 1, 1, 0.3)
	inner.text_color = Color("#89b4fa")
	inner.container = group
	nodes.append(group)
	nodes.append(inner)
	await settle()
	var before := StageObjectRegistry.capture(stage)
	for light in [true, false]:
		GraphPreferences.set_value("theme", "light" if light else "mocha", false)
		stage.apply_preferences()
		await settle()
		for node in nodes:
			node._apply_appearance(true, light)
			check_color(node, light, str(light) + " " + node.text)
		inner.enter_edit_mode()
		var expected := Palette.neutral_text_color(inner.display_background_color(light))
		check(inner.text_edit.get_theme_color("font_color").is_equal_approx(expected), "Editing retains automatic color")
		inner.exit_edit_mode(false)
		check_color(inner, light, "After cancel editing")
		if DisplayServer.get_name() != "headless":
			stage.camera.zoom = Vector2.ONE
			stage.camera.target_zoom = stage.camera.zoom
			stage.camera.global_position = Vector2(70, 140)
			stage.camera.target_position = stage.camera.global_position
			await settle()
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("/tmp/pg-neutral-node-text-" + str(light) + ".png")
	check(StageObjectRegistry.capture(stage) == before, "Automatic display colors do not rewrite saved document properties")
	view.queue_free()
	await process_frame
	print("NODE_NEUTRAL_TEXT: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
