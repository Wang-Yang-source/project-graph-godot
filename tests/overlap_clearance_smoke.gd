extends "res://tests/local_drag_physics_smoke.gd"

func _run() -> void:
	GraphPreferences.set_value("welcome", false, false)
	app = load("res://src/main/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	stage = app.tabs.get_current_stage()
	GraphPreferences.set_value("physics", true, false)
	var solver := stage.get_node("NodeRepulsion")
	solver.set_physics_process(false)
	var driver := stage.create_text_node("Driver", Vector2.ZERO, false)
	var neighbour := stage.create_text_node("Neighbour", Vector2(30, 0), false)
	var far := stage.create_text_node("Far", Vector2(4000, 0), false)
	await settle()
	stage.history.clear()
	var before := StageObjectRegistry.capture(stage)
	var far_position := far.position
	driver.drag_controlled = true
	driver._drag_target = driver.position
	stage.history.begin_transaction()
	solver.begin_local_edit([driver])
	for step in 60:
		await solve_once(solver)
		await physics_frame
	check(not driver.aabb.intersects(neighbour.aabb), "Deep overlap clears beyond the old sixteen-unit yield cap")
	check(driver.position.is_equal_approx(Vector2.ZERO), "Avoidance keeps the driver pinned")
	check(far.position.is_equal_approx(far_position), "Avoidance keeps distant nodes fixed")
	driver.drag_controlled = false
	stage.history._finish_commit()
	var after := StageObjectRegistry.capture(stage)
	check(stage.history._undo_stack.size() == 1, "Separation remains one history transaction")
	await stage.history.undo()
	await settle()
	check(StageObjectRegistry.capture(stage) == before, "Undo restores original overlap and positions")
	await stage.history.redo()
	await settle()
	check(StageObjectRegistry.capture(stage) == after, "Redo restores separated positions")
	# A dragged node must also clear a caption whose endpoints are outside the
	# small body-query radius. The caption remains owned by its edge.
	for object in stage.stage_objects():
		object.queue_free()
	await settle()
	var a := stage.create_text_node("Test01", Vector2(0,-150), false)
	var b := stage.create_text_node("Target", Vector2(0,150), false)
	var edge := stage.connect_entities(a,b)
	edge.text = "Dependency"
	await settle()
	var intruder := stage.create_text_node("...", edge.caption_rect().get_center() + Vector2(30,0), false)
	await settle()
	stage.history.clear()
	stage.history.begin_transaction()
	intruder.drag_controlled = true
	intruder._drag_target = intruder.position
	var intruder_position := intruder.position
	solver.begin_local_edit([intruder])
	for step in 60:
		await solve_once(solver)
		await physics_frame
		edge.refresh_for_physics()
	check(not edge.caption_rect().intersects(intruder.aabb), "Dragged node clears a caption even when endpoints lie beyond the query radius")
	check(intruder.position.is_equal_approx(intruder_position), "Caption clearance does not move the pointer driver")
	intruder.drag_controlled = false
	solver.stop_motion()
	app.queue_free()
	await process_frame
	print("OVERLAP_CLEARANCE: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
