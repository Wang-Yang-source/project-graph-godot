extends SceneTree
## Run only through the authorized Godot MCP regression runner.
class LayoutProbe:
	extends TextNode
	var fill_updates := 0
	var appearance_updates := 0

	func _update_fill_layer(members: Array[Entity]) -> void:
		fill_updates += 1
		super._update_fill_layer(members)

	func _apply_appearance(update_layout: bool = true, theme_light: Variant = null) -> void:
		appearance_updates += 1
		super._apply_appearance(update_layout, theme_light)


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


func _run() -> void:
	var stage := load("res://src/stage/stage.tscn").instantiate() as Stage
	root.add_child(stage)
	var group := StageObjectRegistry.get_scene("text_node").instantiate() as TextNode
	group.set_script(LayoutProbe)
	group.text = "Group"
	group.position = Vector2(50000, -30000)
	stage.add_child(group)
	stage.apply_object_preferences(group)
	var a := stage.create_text_node("A", group.position + Vector2(120, 80), false)
	var b := stage.create_text_node("B", group.position + Vector2(380, 120), false)
	a.container = group
	b.container = group
	var members: Array[Entity] = [a, b]
	await frames(10)
	group.update_container_layout(members)
	group.update_container_layout(members)
	var fills: int = group.get("fill_updates")
	var appearances: int = group.get("appearance_updates")
	var rect := group._container_rect
	for step in 20:
		var displacement := Vector2(12.5, -7.25)
		group.position += displacement
		a.position += displacement
		b.position += displacement
		group.update_container_layout(members)
	check(group.get("fill_updates") == fills, "Uniform translation skips fill hierarchy work")
	check(group.get("appearance_updates") == appearances, "Uniform translation skips theme/layout work")
	check(group._container_rect == rect, "Uniform translation preserves local container bounds")
	a.position += Vector2(24, 0)
	group.update_container_layout(members)
	check(group.get("fill_updates") > fills, "Relative member motion invalidates local layout")
	fills = group.get("fill_updates")
	# A real small relative move must not disappear behind floating tolerance.
	group.position = Vector2.ZERO
	a.position = Vector2(120, 80)
	b.position = Vector2(380, 120)
	group.update_container_layout(members)
	fills = group.get("fill_updates")
	a.position.x += 0.01
	group.update_container_layout(members)
	check(group.get("fill_updates") > fills, "Small visible relative motion invalidates")
	fills = group.get("fill_updates")
	a.rotation = 0.2
	group.update_container_layout(members)
	check(group.get("fill_updates") > fills, "Member basis changes invalidate")
	fills = group.get("fill_updates")
	b.fixed_width = b.get_visual_rect().size.x + 80
	await frames(6)
	group.update_container_layout(members)
	check(group.get("fill_updates") > fills, "Member resizing invalidates")
	fills = group.get("fill_updates")
	b.fill_color = Color("#112233")
	group.update_container_layout(members)
	check(group.get("fill_updates") > fills, "Member fill changes invalidate")
	fills = group.get("fill_updates")
	group.rotation = 0.1
	group.update_container_layout(members)
	check(group.get("fill_updates") > fills, "Container basis changes invalidate")
	fills = group.get("fill_updates")
	group.update_container_layout([a] as Array[Entity])
	check(group.get("fill_updates") > fills, "Membership changes invalidate")
	group.update_container_layout([] as Array[Entity])
	check(not group._container_active, "Removing the last member exits container mode")
	stage.queue_free()
	await process_frame
	print("CONTAINER_TRANSLATION_LAYOUT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
