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
	GraphPreferences.set_value("physics", false, false)
	Engine.max_fps = 120
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var source := stage.create_text_node("Source", Vector2(-300, -40), false)
	var target := stage.create_text_node("Target", Vector2(300, 40), false)
	source.freeze = true
	target.freeze = true
	var edge := stage.connect_entities(source, target)
	stage.camera.zoom = Vector2.ONE * .45
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(.2).timeout
	if DisplayServer.get_name() != "headless":
		var probe := SubViewport.new()
		probe.size = Vector2i(512, 128)
		probe.transparent_bg = true
		probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(probe)
		var stroke := Line2D.new()
		stroke.points = PackedVector2Array([Vector2(20, 30), Vector2(490, 100)])
		stroke.width = 20.0
		stroke.texture = edge.line.texture
		stroke.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		stroke.material = LineEdge._screen_stroke_material(2.0, 20.0, 1.0)
		probe.add_child(stroke)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var pixels := probe.get_texture().get_image()
		var partial := 0
		var opaque := 0
		for y in pixels.get_height():
			for x in pixels.get_width():
				var alpha := pixels.get_pixel(x, y).a
				if alpha > .02 and alpha < .98:
					partial += 1
				elif alpha >= .98:
					opaque += 1
		check(partial > 100 and opaque > 100, "Live stroke shader retains an opaque core and fractional edge coverage")
		probe.queue_free()
	var saved := JSON.stringify(StageObjectRegistry.capture(stage).objects)
	var collision := (edge.collision_shape.shape as ConcavePolygonShape2D).segments
	var points := PackedVector2Array()
	var observed := false
	for frame in 40:
		stage.camera.target_zoom = Vector2.ONE * (.2 + .08 * sin(frame * .15))
		await process_frame
		if stage.camera._zoom_animation_active and edge.line.scale == Vector2.ONE:
			check(edge.line.material is ShaderMaterial, "Smooth zoom uses the stroke shader")
			if points.is_empty():
				points = edge.line.points
			else:
				check(points == edge.line.points, "Smooth zoom reuses the native shaft mesh points")
			observed = true
	check(observed, "Fixture exercises continuous zoom")
	stage.camera.target_zoom = stage.camera.zoom
	await create_timer(.2).timeout
	check(not stage.camera._zoom_animation_active, "Settled zoom leaves animation mode")
	check(edge.line.material == edge._base_line_material, "Settled zoom restores native textured strokes")
	check(absf(edge.line.get_global_transform_with_canvas().get_scale().x - 1.0) <= .045, "Restored stroke keeps screen-pixel sampling")
	check((edge.collision_shape.shape as ConcavePolygonShape2D).segments == collision, "Zoom preserves collision geometry")
	check(JSON.stringify(StageObjectRegistry.capture(stage).objects) == saved, "Zoom preserves persistent objects")
	stage.camera.target_zoom = stage.camera.zoom * .8
	await create_timer(.05).timeout
	root.set_meta("workspace_text_input", true)
	await create_timer(.2).timeout
	check(not stage.camera._zoom_animation_active and edge.line.material == edge._base_line_material, "Text editing restores native strokes")
	root.remove_meta("workspace_text_input")
	stage.camera.target_zoom = stage.camera.zoom
	# Free a shader-active edge while its delayed restoration is pending.
	stage.camera.target_zoom = stage.camera.zoom * .8
	await create_timer(.05).timeout
	stage.camera.target_zoom = stage.camera.zoom
	await process_frame
	edge.queue_free()
	await create_timer(.2).timeout
	view.queue_free()
	await process_frame
	print("ZOOM_STROKE_CACHE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
