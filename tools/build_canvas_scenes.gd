extends SceneTree
## Compile authored scenes into lightweight runtime scenes using native APIs.
func _initialize() -> void:
	var items := [
		["res://src/stage_object/entity/text_node/text_node.tscn", "TextEdit",
			"res://src/stage_object/entity/text_node/text_editor.res", "res://src/stage_object/entity/text_node/text_node.res"],
		["res://src/stage_object/association/line_edge/line_edge.tscn", "Caption/Editor",
			"res://src/stage_object/association/line_edge/caption_editor.res", "res://src/stage_object/association/line_edge/line_edge.res"]]
	for item in items:
		var root: Node = load(item[0]).instantiate()
		var editor: Node = root.get_node(item[1])
		for node in [editor] + editor.find_children("*", "", true, false):
			for signal_info in node.get_signal_list():
				for connection in node.get_signal_connection_list(signal_info.name):
					var target = connection.callable.get_object()
					if target is Node and target != editor and not editor.is_ancestor_of(target):
						node.disconnect(signal_info.name, connection.callable)
		editor.get_parent().remove_child(editor)
		editor.owner = null
		for child in editor.find_children("*", "", true, false):
			if child.owner != null:
				child.owner = editor
		var editor_scene := PackedScene.new()
		if editor_scene.pack(editor) != OK or ResourceSaver.save(editor_scene, item[2]) != OK:
			quit(1)
			return
		editor.free()
		root.scene_file_path = ""
		var runtime_scene := PackedScene.new()
		if runtime_scene.pack(root) != OK or ResourceSaver.save(runtime_scene, item[3]) != OK:
			quit(1)
			return
		var probe: Node = runtime_scene.instantiate()
		if probe.get_node_or_null(item[1]) != null:
			push_error("Runtime scene still contains eager editor")
			quit(1)
			return
		print("CANVAS_SCENE ", item[3], " nodes=", runtime_scene.get_state().get_node_count())
		probe.free()
		root.free()
	quit()
