extends SceneTree
const Model = preload("res://src/storage/graph_document.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func node(identifier: String, references: Dictionary = {}) -> Dictionary:
	return {"id":identifier,"type":"text_node","properties":{"text":identifier},"references":references,
		"assets":{},"transform":{"position":Vector2.ZERO,"rotation":0.0,"scale":Vector2.ONE}}
func _run() -> void:
	var model := Model.new()
	var a := node("a")
	var b := node("b", {"container":"a","topic_parent":"a"})
	var edge := node("edge", {"source":"a","target":"b"})
	edge.type = "line_edge"
	var source := {"schema":1,"camera":{},"objects":[a,b,edge]}
	check(model.replace_document(source, {}).ok, "Complete document validates without scene nodes")
	source.objects.clear()
	check(model.ids().size() == 3, "Input aliases do not mutate model")
	check(model.children("a") == PackedStringArray(["b"]), "Container index")
	check(model.topics("a") == PackedStringArray(["b"]), "Topic index")
	check(model.incident_edges("a") == PackedStringArray(["edge"]), "Endpoint reverse index")
	var c := node("c", {"container":"a"})
	check(model.apply_transaction([{"before":null,"after":c}]).ok, "Creation with references is atomic")
	check(model.ids().size() == 4 and model.children("a").has("c"), "New records append and enter relationship indexes")
	check(model.apply_transaction([{"before":c,"after":null}]).ok, "Created record can be undone without materializing it")
	check(not model.replace_document(model.native_document(), {"invalid":RID()}).ok, "Runtime asset values rejected")
	var before := model.record("b")
	var after := before.duplicate(true)
	after.properties.text = "edited while never materialized"
	after.transform.position = Vector2(150, -20)
	check(model.apply_transaction([{"before":before,"after":after}]).ok, "Unmaterialized object transaction")
	after.properties.text = "external alias"
	check(model.record("b").properties.text == "edited while never materialized", "Transaction input ownership")
	var edited := model.record("b")
	var baseline := model.native_document()
	var revision := model.revision
	check(not model.apply_transaction([{"before":model.record("a"),"after":null}]).ok, "Dangling container and edge deletion rejected")
	check(model.native_document() == baseline and model.revision == revision, "Failed transaction is atomic")
	check(not model.apply_transaction([{"before":before,"after":edited}]).ok, "Stale before rejected")
	check(model.apply_transaction([{"before":edited,"after":before}]).ok, "Inverse transaction restores data")
	check(model.record("b") == before, "Undo values preserved")
	var other := Model.new()
	check(other.replace_snapshot(model.snapshot()).ok and other.native_document() == model.native_document(), "Never materialized records survive snapshot adapter")
	check(model.apply_transaction([{"before":model.record("edge"),"after":null},
		{"before":model.record("b"),"after":null},{"before":model.record("a"),"after":null}]).ok, "Complete cascade transaction")
	check(model.ids().is_empty() and model.incident_edges("a").is_empty(), "Deletion updates all indexes")
	print("GRAPH_DOCUMENT: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
