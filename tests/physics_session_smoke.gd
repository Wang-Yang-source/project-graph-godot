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
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var a := stage.create_text_node("driver", Vector2.ZERO, false)
	var b := stage.create_text_node("contact", Vector2.ZERO, false)
	var far := stage.create_text_node("far", Vector2(5000, 0), false)
	stage.select_ids(PackedStringArray())
	for frame in 12:
		await physics_frame
	check(a.position == Vector2.ZERO and b.position == Vector2.ZERO, "Idle overlapping records must not drift")
	check(a.freeze and b.freeze and far.freeze, "Idle stage views are frozen")
	b.move_without_inertia(Vector2(200, 0))
	for frame in 8:
		await physics_frame
	var before := StageObjectRegistry.capture(stage)
	stage.history.begin_transaction()
	a._start_throw(Vector2(900, 0))
	var session := stage.get_node("PhysicsSession")
	check(session.active and not a.freeze, "Throw begins a native physics session")
	var started := Time.get_ticks_msec()
	while session.active and Time.get_ticks_msec() - started < 4000:
		await physics_frame
	check(not session.active, "Stable motion ends and releases the session")
	check(b.position.x > 202.0, "Swept native broadphase activates a future collision neighbor")
	check(far.position == Vector2(5000, 0) and far.freeze, "Distant unrelated records remain frozen")
	check(a.freeze and b.freeze and session._members.is_empty(), "Settled participants freeze and release membership")
	var after := StageObjectRegistry.capture(stage)
	stage.history.commit(false)
	await stage.history.undo()
	check(StageObjectRegistry.capture(stage) == before, "One undo restores the whole native collision transaction")
	await stage.history.redo()
	check(StageObjectRegistry.capture(stage) == after, "Redo restores the whole collision transaction")
	a._start_throw(Vector2(300, 0))
	session.end()
	check(not session.active and a.freeze and a.linear_velocity == Vector2.ZERO, "Cancellation releases motion and activation state")
	stage.queue_free()
	await process_frame
	print("PHYSICS_SESSION: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
