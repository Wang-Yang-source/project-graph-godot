extends SceneTree
var failures: Array[String] = []
var inspected := 0
func _initialize():
	call_deferred("_run")
func _run():
	var fixture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			fixture = argument.trim_prefix("--fixture=")
	if fixture.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Pass --fixture=<tutorial document> and use a graphical renderer.")
		quit(2)
		return
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	GraphPreferences.set_value("effects", false, false)
	Engine.max_fps = 120
	root.size = Vector2i(1280, 800)
	var stage = load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	await process_frame
	if not await stage.load_from_file(fixture):
		quit(2)
		return
	var region := Rect2()
	for object in stage.stage_objects():
		if object is TextNode and "连线更改目标" in object.text:
			region = object.aabb
			break
	if not region.has_area():
		push_error("Fixture lacks the reported tutorial section.")
		quit(2)
		return
	var edges: Array[LineEdge] = []
	for object in stage.stage_objects():
		if object is LineEdge and is_instance_valid(object.source) and is_instance_valid(object.target):
			var color: Color = object.display_stroke_color()
			if color.g > color.r * 1.5 and color.g > color.b * 1.5 and region.has_point(object.source.aabb.get_center()) and region.has_point(object.target.aabb.get_center()):
				edges.append(object)
	if edges.is_empty():
		push_error("Fixture lacks green edges in the reported section.")
		quit(2)
		return
	stage.camera.position = region.get_center()
	stage.camera.target_position = stage.camera.position
	var fit := minf(1000.0 / region.size.x, 650.0 / region.size.y)
	for frame in 180:
		stage.camera.target_zoom = Vector2.ONE * fit * (0.5 + 0.45 * sin(frame * 0.19))
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 30 and frame % 3 != 0:
			continue
		var image := root.get_texture().get_image()
		# Viewport readback includes stretch scaling, but excludes window letterboxing.
		var display := root.get_final_transform()
		display.origin = Vector2.ZERO
		var canvas := display * stage.get_viewport().get_canvas_transform()
		var rect := (canvas * region).intersection(Rect2(Vector2.ZERO, image.get_size()))
		var corridors: Array[PackedVector2Array] = []
		for edge in edges:
			corridors.append(canvas * edge._shaft_points)
		var outside := 0
		for y in range(maxi(0, floori(rect.position.y)), mini(image.get_height(), ceili(rect.end.y))):
			for x in range(maxi(0, floori(rect.position.x)), mini(image.get_width(), ceili(rect.end.x))):
				var color := image.get_pixel(x, y)
				if color.g < .12 or color.g < color.r * 1.5 or color.g < color.b * 1.5:
					continue
				var point := Vector2(x + .5, y + .5)
				var nearest := INF
				for corridor in corridors:
					for segment in range(corridor.size() - 1):
						nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, corridor[segment], corridor[segment + 1])))
				if nearest > 6.0:
					outside += 1
		inspected += 1
		# Six screen pixels allow arrowheads, native AA and low-resolution
		# miniature sampling; the reported blobs cover hundreds of pixels.
		if outside > 20:
			image.save_png("/tmp/pg-zoom-artifact-failure.png")
			failures.append("frame %d: %d green pixels outside stroke corridors" % [frame, outside])
			break
		if frame == 177:
			image.save_png("/tmp/pg-zoom-artifact-pass.png")
	stage.queue_free()
	for frame in 10:
		await process_frame
	print("TUTORIAL_ZOOM_ARTIFACTS: ", "PASS" if failures.is_empty() else failures, " inspected=", inspected, " renderer=", RenderingServer.get_current_rendering_method())
	quit(0 if failures.is_empty() else 1)
