extends SceneTree
## Full content walks are driven by local changes, not every world translation.
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

func _run() -> void:
	GraphPreferences._loaded = true
	GraphPreferences._config = ConfigFile.new()
	GraphPreferences.set_value("physics", false, false)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	root.add_child(view)
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	view.add_child(stage)
	var group := stage.create_text_node("Moving group", Vector2.ZERO, false)
	var members: Array[TextNode] = []
	for index in 12:
		var member := stage.create_text_node("Member " + str(index), Vector2(100 + 50 * index, 100), false)
		member.container = group
		members.append(member)
	var other := stage.create_text_node("Unrelated group", Vector2(2000, 0), false)
	var other_child := stage.create_text_node("Unrelated child", Vector2(2100, 100), false)
	other_child.container = other
	var edge: LineEdge = StageObjectRegistry.get_scene("line_edge").instantiate()
	edge.source = members[0]
	edge.target = members[1]
	stage.add_child(edge)
	stage.select_ids(PackedStringArray())
	stage.camera.set_process(false)
	stage.camera.zoom = Vector2.ONE * .02
	stage.camera.target_zoom = stage.camera.zoom
	stage.camera.force_update_scroll()
	await settle()
	stage.get_node("EntityLayerMover").set_physics_process(false)
	stage.get_node("EntityLayerMover").set_process(false)
	var overview = stage.group_overview
	var group_id := group.get_instance_id()
	var other_id := other.get_instance_id()
	check(overview._native_previews.has(group_id) and overview._native_previews.has(other_id), "Both fixtures have native previews")
	if not overview._native_previews.has(group_id) or not overview._native_previews.has(other_id):
		view.queue_free()
		await process_frame
		quit(1)
		return
	var notices := [0]
	members[0].persistent_content_changed.connect(func(): notices[0] += 1)
	for member in members:
		member._rigid_follow_owner = group
	var image: Sprite2D = overview._native_previews[group_id].image
	var other_image: Sprite2D = overview._native_previews[other_id].image
	var anchor: Array = overview._native_previews[group_id].content_key.duplicate(true)
	var checks: int = overview._native_content_member_checks
	var walks: int = overview._native_content_walks
	# Alternate root-first/member-first publication, including fractional poses.
	for index in 6:
		var delta := Vector2(3.17 + float(index) * .033, -1.37)
		if index % 2 == 0:
			group.global_position += delta
		for member in members:
			member.global_position += delta
		if index % 2 != 0:
			group.global_position += delta
		await settle()
	check(notices[0] == 0, "Transform notifications emit no persistent content change")
	check(overview._native_content_walks == walks and overview._native_content_member_checks == checks, "Common translation performs zero full content/member walks")
	check(overview._native_previews[group_id].image == image and overview._native_previews[group_id].content_key == anchor, "Translation reuses the image and keeps its original content anchor")
	check(overview._native_previews[other_id].image == other_image, "Unrelated preview is never rebuilt by another group's movement")
	# An owner alone is insufficient proof: move one member relative to its root.
	members[0].global_position += Vector2(2, 0)
	await settle()
	check(overview._native_previews[group_id].image != image and overview._native_content_walks > walks, "Actual relative motion invalidates despite a shared follow owner")
	image = overview._native_previews[group_id].image
	members[0].text = "Edited hidden member"
	await settle()
	check(notices[0] > 0 and overview._native_previews[group_id].image != image, "Persistent text content emits and refreshes the hidden preview")
	image = overview._native_previews[group_id].image
	check(overview.is_hidden(edge), "The edge fixture is hidden before its property edit")
	edge.show_arrow = not edge.show_arrow
	await settle()
	check(overview._native_previews[group_id].image != image, "A hidden edge setter refreshes without relying on its stopped process")
	image = overview._native_previews[group_id].image
	edge.source_uv = Vector2(.25, .75)
	await settle()
	check(overview._native_previews[group_id].image != image, "Hidden edge UV edits invalidate copied content")
	image = overview._native_previews[group_id].image
	edge.target = members[3]
	await settle()
	check(overview._native_previews[group_id].image != image, "Endpoint topology edits invalidate copied content")
	image = overview._native_previews[group_id].image
	members[1].label.add_theme_color_override("font_color", Color.RED)
	await settle()
	check(overview._native_previews[group_id].image != image, "Direct local label theme changes invalidate copied pixels")
	image = overview._native_previews[group_id].image
	group.global_position += Vector2(16, 0)
	await settle()
	check(overview._native_previews[group_id].image != image, "Root-only movement cannot reuse stationary member pixels")
	for member in members:
		member._rigid_follow_owner = null
	members[2].container = other
	await settle()
	check(overview._preview_parents.get(members[2].get_instance_id(), 0) == other_id, "Reparenting updates preview ownership")
	check(overview._native_previews[other_id].image != other_image, "Topology changes refresh the receiving group's pixels")
	var topology_before: int = stage.topology_revision
	image = overview._native_previews[group_id].image
	members[4].topic_parent = members[3]
	await settle()
	check(stage.topology_revision > topology_before, "Logical parent edits publish a topology revision")
	check(overview._preview_parents.get(members[4].get_instance_id(), 0) == members[3].get_instance_id(), "Existing nodes update their logical preview parent immediately")
	check(overview._native_previews[group_id].image != image, "Logical reparenting refreshes preview ownership and content")
	view.queue_free()
	await process_frame
	print("OVERVIEW_CONTENT_EVENTS: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
