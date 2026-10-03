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
	var a := stage.create_text_node("A", Vector2.ZERO, false)
	var b := stage.create_text_node("B", Vector2(0,90), false)
	var c := stage.create_text_node("C", Vector2(0,180), false)
	var d := stage.create_text_node("D", Vector2(0,270), false)
	var far := stage.create_text_node("Far", Vector2(4000,0), false)
	await settle()
	stage.history.clear()
	var before := StageObjectRegistry.capture(stage)
	var far_origin := far.position
	var c_origin := c.position
	var d_origin := d.position
	stage.history.begin_transaction()
	a.drag_controlled = true
	a._drag_target = Vector2(0,75)
	solver.begin_local_edit([a])
	for step in 120:
		await solve_once(solver)
		await physics_frame
	check(not a.aabb.intersects(b.aabb), "A and B finish separated")
	check(not b.aabb.intersects(c.aabb), "Pushing B cannot leave B overlapping C")
	check(not c.aabb.intersects(d.aabb), "Avoidance propagates beyond the second neighbour")
	check(c.position.distance_to(c_origin) > 1.0 and d.position.distance_to(d_origin) > 1.0, "Second and third neighbours actively make room")
	check(far.position.is_equal_approx(far_origin), "Contact chain does not rearrange remote nodes")
	a.drag_controlled = false
	stage.history._finish_commit()
	var after := StageObjectRegistry.capture(stage)
	check(stage.history._undo_stack.size() == 1, "Entire contact chain is one undo step")
	await stage.history.undo()
	await settle()
	check(StageObjectRegistry.capture(stage) == before, "Undo restores the entire contact chain")
	await stage.history.redo()
	await settle()
	check(StageObjectRegistry.capture(stage) == after, "Redo restores the separated contact chain")
	app.queue_free()
	await process_frame
	print("CHAIN_CONTACT: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
