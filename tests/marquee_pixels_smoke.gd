extends "res://tests/group_overview_smoke.gd"
func _run() -> void:
	root.size = Vector2i(1280, 800)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.get_node("UIOverlay/Welcome").hide()
	stage = app.tabs.get_current_stage()
	stage.set_process(false)
	stage.camera.set_process(false)
	stage.get_node("CanvasLayer/Grid").hide()
	var view := stage.get_viewport() as SubViewport
	view.transparent_bg = true
	var line := stage.get_node("SelectionOverlay/Marquee") as Line2D
	for zoom: float in [.02, .125, .25, .5, 1.0, 2.0, 3.0]:
		stage.camera.zoom = Vector2.ONE * zoom
		stage.camera.target_zoom = stage.camera.zoom
		stage.camera.position = Vector2(125, -90)
		stage.camera.force_update_scroll()
		for phase: float in [0.0, .25, .5, .75]:
			var start := Vector2(120, 110) + Vector2.ONE * phase
			var end := Vector2(420, 290) + Vector2.ONE * phase
			var container := view.get_parent() as Control
			var screen := container.get_global_transform_with_canvas() * (view.get_final_transform() * end)
			root.grab_focus()
			Input.warp_mouse(root.get_final_transform() * screen)
			var motion := InputEventMouseMotion.new()
			motion.position = end
			view.push_input(motion, true)
			for frame in 2:
				await process_frame
			stage._marquee_start = stage.get_canvas_transform().affine_inverse() * start
			stage._update_marquee()
			await RenderingServer.frame_post_draw
			var pixels := view.get_texture().get_image()
			check(line.closed and line.points.size() > 4, "Marquee uses the shared continuous corner outline")
			var corners := PackedVector2Array()
			for point in line.points:
				corners.append(view.get_final_transform() * line.get_global_transform_with_canvas() * point)
			var bounds := Rect2(corners[0], Vector2.ZERO)
			for point in corners:
				bounds = bounds.expand(point)
			check(bounds.position.distance_to(view.get_final_transform() * start) < 1.0 and bounds.end.distance_to(view.get_final_transform() * end) < 1.5, "Rounded marquee bounds follow the pointer in viewport pixels")
			check(not corners.has(view.get_final_transform() * start), "Marquee excludes the square corner")
			var world_rect := Rect2(stage._marquee_start, stage.get_global_mouse_position() - stage._marquee_start).abs()
			var expected := preload("res://src/main/continuous_corners.gd").outline(world_rect, preload("res://src/main/continuous_corners.gd").NODE)
			for index in expected.size():
				check(line.to_global(line.points[index]).distance_to(expected[index]) < 0.05, "Marquee matches node corner geometry")
			var missing := 0
			for side in corners.size():
				for step in [0.5]:
					var point := corners[side].lerp(corners[(side + 1) % corners.size()], step)
					var coverage := 0.0
					for x in range(maxi(0, floori(point.x) - 3), mini(pixels.get_width(), ceili(point.x) + 4)):
						for y in range(maxi(0, floori(point.y) - 3), mini(pixels.get_height(), ceili(point.y) + 4)):
							coverage = maxf(coverage, pixels.get_pixel(x,y).a)
					if coverage < .4:
						missing += 1
			check(missing == 0, "All four marquee edges remain visible: zoom=%s phase=%s missing=%s" % [zoom, phase, missing])
			if zoom == .125 and phase == .25:
				pixels.save_png("/tmp/pg-marquee-regression.png")
	stage._marquee_active = true
	stage._marquee_original_ids = PackedStringArray()
	stage.cancel_marquee_selection()
	check(not line.visible and line.points.is_empty(), "Cancel clears the temporary rectangle")
	app.queue_free()
	await process_frame
	print("MARQUEE_PIXELS: " + ("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
