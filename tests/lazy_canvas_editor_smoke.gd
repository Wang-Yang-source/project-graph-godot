extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _run() -> void:
	var stage: Stage = load("res://src/stage/stage.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	var source := stage.create_text_node("节点", Vector2(-300, 0), false)
	var target := stage.create_text_node("目标", Vector2(300, 0), false)
	source.freeze = true
	target.freeze = true
	var edge: LineEdge = StageObjectRegistry.get_scene("line_edge").instantiate()
	edge.source = source
	edge.target = target
	edge.text = "关系"
	stage.add_child(edge)
	for i in 4:
		await process_frame
	var caption = edge.get_node("Caption")
	check(source._text_edit == null and target._text_edit == null and caption._editor == null, "Display does not instantiate editors")
	stage.history.clear()
	stage.finish_text_editing()
	stage.select_ids(PackedStringArray([source.id]))
	stage.is_dirty()
	stage.apply_theme(false)
	check(source._text_edit == null and target._text_edit == null and caption._editor == null, "History, selection and theme do not instantiate editors")
	var before := source.get_visual_rect()
	source.enter_edit_mode()
	await process_frame
	var editor := source.text_edit
	check(editor != null and editor.has_focus(), "First edit creates focused native editor")
	check(source.get_visual_rect().is_equal_approx(before), "Lazy edit preserves node geometry")
	source.exit_edit_mode(false)
	source.enter_edit_mode()
	check(source.text_edit == editor, "Editor reused for later edits")
	source.exit_edit_mode(false)
	check(target._text_edit == null, "Unedited sibling stays lightweight")
	edge.enter_edit_mode()
	await process_frame
	var caption_editor = caption.editor
	check(caption_editor != null, "Caption editor created on demand")
	edge.exit_edit_mode(false)
	edge.enter_edit_mode()
	check(caption.editor == caption_editor, "Caption editor reused")
	edge.exit_edit_mode(false)
	stage.queue_free()
	await process_frame
	check(not is_instance_valid(editor) and not is_instance_valid(caption_editor), "Lazy editors released with objects")
	print("LAZY_CANVAS_EDITOR: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
