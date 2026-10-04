extends SceneTree
## Native query regression; run only through the authorized MCP runner.
class QueryProbe:
	extends "res://src/stage/physics_session.gd"
	var observations: Dictionary = {}
	var native_candidates: Dictionary = {}
	var hull_invalidations := 0
	var diagnostic_query: PhysicsShapeQueryParameters2D
	var diagnostic_hits: Array = []
	func _physics_process(delta: float) -> void:
		if diagnostic_query != null:
			diagnostic_hits = target_root.get_world_2d().direct_space_state.intersect_shape(diagnostic_query, 256)
			diagnostic_query = null
		super._physics_process(delta)
	func invalidate_contact_bounds(changed_body: Entity = null) -> void:
		hull_invalidations += int(changed_body != null)
		super.invalidate_contact_bounds(changed_body)
	func _query_exclusions(body: Entity, shared: Array[RID]) -> Array[RID]:
		var result := super._query_exclusions(body, shared)
		observations[body.id] = result.duplicate()
		if Engine.is_in_physics_frame():
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = _shape
			query.transform = Transform2D(0, body.aabb.get_center())
			query.exclude = result
			var seen: Array = native_candidates.get(body.id, [])
			for hit in target_root.get_world_2d().direct_space_state.intersect_shape(query, 256):
				if hit.collider is Entity and not seen.has(hit.collider.id):
					seen.append(hit.collider.id)
			native_candidates[body.id] = seen
		return result

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
		await create_timer(0.0).timeout

func place_beside(body: TextNode, other: TextNode) -> void:
	var visual := other.get_visual_rect()
	# Container layout can change the anchor while test entities are reparented.
	other.global_position = Vector2(body.aabb.end.x - 20.0 - visual.position.x,
		body.aabb.get_center().y - visual.get_center().y)

func diagnostic(body: TextNode) -> Dictionary:
	var shape := body.get_node("PhysicsOutline") as CollisionShape2D
	var polygon := shape.shape as ConvexPolygonShape2D
	return {"id":body.id,"max_contacts_reported":body.max_contacts_reported,
		"contact_monitor":body.contact_monitor,"freeze_mode":body.freeze_mode,
		"outline_points":polygon.points.size() if polygon != null else 0}

func _run() -> void:
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	stage.camera.zoom = Vector2.ONE
	stage.camera.target_zoom = Vector2.ONE
	var enclosing := stage.create_text_node("Enclosing", Vector2(100, 100), false)
	var child := stage.create_text_node("Child", Vector2(250, 180), false)
	child.container = enclosing
	var outsider := stage.create_text_node("Outsider", Vector2(1600, 1600), false)
	await frames(8)
	print("NATIVE_CONTACT_REPORT_DIAGNOSTIC: ", [diagnostic(enclosing), diagnostic(child), diagnostic(outsider)])
	var session := stage.get_node("PhysicsSession")
	session.set_script(QueryProbe)
	session._ready()
	var shared: Array[RID] = [child.get_rid(), outsider.get_rid()]
	var local: Array[RID] = session._query_exclusions(child, shared)
	check(local.has(enclosing.get_rid()), "Ancestor enters the child's native query exclusions")
	check(not shared.has(enclosing.get_rid()), "Ancestor exclusions never mutate the shared list")
	check(not session._query_exclusions(outsider, shared).has(enclosing.get_rid()),
		"Other drivers retain the same ancestor as a valid external contact")
	place_beside(enclosing, outsider)
	session.begin([child, outsider])
	await frames(1)
	check(session.observations.has(child.id) and session.observations[child.id].has(enclosing.get_rid()),
		"Actual child native query excludes its ancestor before solving")
	check(session.observations.has(outsider.id) and not session.observations[outsider.id].has(enclosing.get_rid()),
		"Actual external native query keeps unrelated enclosing body eligible")
	check(session._members.has(enclosing), "An unrelated driver activates the enclosing body's external contact")
	session.end()
	# A stationary driver can cache unchanged bounds while a new object enters.
	var driver := stage.create_text_node("Stationary", Vector2(-2400, 1800), false)
	await frames(6)
	driver._drag_target = driver.global_position
	driver.drag_controlled = true
	await frames(4)
	var driver_origin := driver.global_position
	var revision := stage.topology_revision
	var newcomer := stage.create_text_node("New external", Vector2(5000, 5000), false)
	place_beside(driver, newcomer)
	await frames(4)
	var probe := PhysicsShapeQueryParameters2D.new()
	var probe_shape := RectangleShape2D.new()
	probe_shape.size = driver.aabb.grow(8).size
	probe.shape = probe_shape
	probe.transform = Transform2D(0, driver.aabb.get_center())
	probe.exclude = [driver.get_rid()]
	session.diagnostic_query = probe
	await frames(2)
	check(stage.topology_revision != revision, "Creating an external body changes topology")
	check(session.native_candidates.get(driver.id, []).has(newcomer.id), "New external hull actually intersects a native driver query")
	check(session._members.has(newcomer), "Topology invalidates stationary bounds and discovers the new external body")
	check(driver._drag_target.is_equal_approx(driver_origin), "New contact discovery retains the stationary drag target")
	driver.drag_controlled = false
	session.end()
	var hull_notifications: int = session.hull_invalidations
	driver.global_position += Vector2(11, 13)
	await frames(3)
	check(session.hull_invalidations == hull_notifications, "Common translation never invalidates native hull contact bounds")
	driver.fixed_width = driver.get_visual_rect().size.x + 80
	await frames(3)
	check(session.hull_invalidations > hull_notifications, "Actual native hull resize invalidates stationary contact discovery")
	# A detached descendant must immediately stop being excluded as a follower.
	session.begin([enclosing])
	check(session._follower_rids.has(child.get_rid()), "A fixed descendant is initially excluded")
	child.container = null
	enclosing._drag_target = enclosing.global_position
	enclosing.drag_controlled = true
	await frames(4)
	place_beside(enclosing, child)
	# Standalone relocation is not a topology change; force the driver to query
	# only to verify the pruned follower is eligible after the detach has settled.
	session.invalidate_contact_bounds()
	await frames(2)
	check(not session._follower_rids.has(child.get_rid()), "Topology prunes the former follower RID")
	check(child._rigid_follow_owner == null, "Reparenting clears temporary follower ownership")
	var former_probe := PhysicsShapeQueryParameters2D.new()
	var former_shape := RectangleShape2D.new()
	former_shape.size = enclosing.aabb.grow(8).size
	former_probe.shape = former_shape
	former_probe.transform = Transform2D(0, enclosing.aabb.get_center())
	former_probe.exclude = [enclosing.get_rid()]
	session.diagnostic_query = former_probe
	await frames(2)
	check(session.native_candidates.get(enclosing.id, []).has(child.id), "Former follower actually intersects the external native query after detach")
	check(session._members.has(child), "Former follower is now an eligible external contact")
	session.end()
	stage.queue_free()
	await process_frame
	print("CONTACT_QUERY_EXCLUSIONS: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
