class_name GraphDocument
extends RefCounted
## Complete native records; node lifecycle never determines membership.
const Codec = preload("res://src/storage/project_document.gd")
var revision := 0
var _document := {"schema":1, "objects":[], "camera":{}}
var _assets := {}
var _records := {}
var _children := {}
var _topics := {}
var _incident := {}
var _memberships := {}

func replace_snapshot(snapshot: Dictionary, camera: Dictionary = {}) -> Dictionary:
	var decoded := Codec.from_snapshot(snapshot, camera)
	if not decoded.ok:
		return decoded
	return replace_document(decoded.document, decoded.assets)

func replace_document(document: Dictionary, assets: Dictionary) -> Dictionary:
	for identifier in assets:
		if not identifier is String or identifier.length() != 64 or not identifier.is_valid_hex_number(false):
			return Codec.failure("资产 ID 无效")
		var value: Variant = assets[identifier]
		if not value is PackedByteArray and not value is Codec.Blob:
			return Codec.failure("资产值必须是字节或已验证的文件块句柄")
	var checked := Codec.validate(document, assets.keys())
	if not checked.ok:
		return checked
	_document = document.duplicate(true)
	_assets = assets.duplicate(true)
	revision += 1
	_rebuild_indexes()
	return {"ok":true}

func native_document() -> Dictionary:
	return _document.duplicate(true)

func snapshot() -> Dictionary:
	return Codec.to_snapshot(_document, _assets)

func asset_values() -> Dictionary:
	return _assets.duplicate(true)

func ids() -> PackedStringArray:
	return PackedStringArray(_records.keys())

func record(identifier: String) -> Dictionary:
	return _records.get(identifier, {}).duplicate(true)

func children(identifier: String) -> PackedStringArray:
	return PackedStringArray(_children.get(identifier, []))

func topics(identifier: String) -> PackedStringArray:
	return PackedStringArray(_topics.get(identifier, []))

func incident_edges(identifier: String) -> PackedStringArray:
	return PackedStringArray(_incident.get(identifier, []))

func memberships(identifier: String) -> PackedStringArray:
	return PackedStringArray(_memberships.get(identifier, []))

## Validate the entire candidate before changing records or relationship indexes.
## before/after pairs support optimistic transactions, inverse undo and redo.
func apply_transaction(changes: Array) -> Dictionary:
	var candidate := _document.duplicate(true)
	var replacement := _records.duplicate(true)
	var touched := {}
	var appended: Array = []
	for change in changes:
		if not change is Dictionary or not change.has("before") or not change.has("after"):
			return Codec.failure("事务必须包含 before 和 after")
		var before: Variant = change.before
		var after: Variant = change.after
		if before != null and not before is Dictionary or after != null and not after is Dictionary:
			return Codec.failure("事务记录类型无效")
		if before == null and after == null:
			return Codec.failure("事务没有对象")
		var identifier: Variant = before.get("id") if before != null else after.get("id")
		if not identifier is String or touched.has(identifier):
			return Codec.failure("事务对象 ID 无效或重复")
		if after != null and after.get("id") != identifier:
			return Codec.failure("事务不能更改对象 ID")
		var current: Variant = _records.get(identifier)
		if current != before:
			return Codec.failure("事务基线已变化")
		touched[identifier] = true
		if after == null:
			replacement.erase(identifier)
		else:
			replacement[identifier] = after.duplicate(true)
			if before == null:
				appended.append(identifier)
	candidate.objects = []
	for previous in _document.objects:
		if replacement.has(previous.id):
			candidate.objects.append(replacement[previous.id])
	for identifier in appended:
		candidate.objects.append(replacement[identifier])
	var checked := Codec.validate(candidate, _assets.keys())
	if not checked.ok:
		return checked
	if candidate == _document:
		return {"ok":true, "changed":false}
	_document = candidate
	revision += 1
	_rebuild_indexes()
	return {"ok":true, "changed":true}

func _append(index: Dictionary, key: String, value: String) -> void:
	if not index.has(key):
		index[key] = []
	if not index[key].has(value):
		index[key].append(value)

func _rebuild_indexes() -> void:
	_records.clear()
	_children.clear()
	_topics.clear()
	_incident.clear()
	_memberships.clear()
	for value in _document.objects:
		_records[value.id] = value
		for relation in ["container", "topic_parent"]:
			if value.references.has(relation):
				_append(_children if relation == "container" else _topics, value.references[relation], value.id)
		if value.type == "line_edge":
			for relation in ["source", "target"]:
				_append(_incident, value.references[relation], value.id)
		if value.type == "venn_region":
			for member in value.properties.get("member_ids", []):
				_append(_memberships, member, value.id)


## Merge only instantiated views. Missing uninstantiated records remain in the
## document; only a previously tracked view that disappeared means deletion.
func reconcile_views(view_snapshot: Dictionary, tracked_ids: PackedStringArray) -> Dictionary:
	if not view_snapshot.get("objects") is Array:
		return Codec.failure("视图缺少对象记录")
	var replacement := {}
	for value in view_snapshot.objects:
		if not value is Dictionary or not value.get("properties") is Dictionary:
			return Codec.failure("视图记录无效")
		var identifier: Variant = JSON.to_native(value.properties.get("id"))
		if not identifier is String or identifier.is_empty() or replacement.has(identifier):
			return Codec.failure("视图 ID 为空或重复")
		replacement[identifier] = value
	var snapshot_data := snapshot()
	var objects := []
	var deleted := {}
	for identifier in tracked_ids:
		if not replacement.has(identifier):
			deleted[identifier] = true
	for previous in snapshot_data.objects:
		var identifier: String = JSON.to_native(previous.properties.id)
		if deleted.has(identifier):
			continue
		objects.append(replacement.get(identifier, previous))
		replacement.erase(identifier)
	for value in replacement.values():
		objects.append(value)
	snapshot_data.objects = objects
	var decoded := Codec.from_snapshot(snapshot_data, _document.camera)
	if not decoded.ok:
		return decoded
	if decoded.document == _document:
		return {"ok": true, "changed": false}
	var result := replace_document(decoded.document, decoded.assets)
	result["changed"] = result.ok
	return result

## Container membership is independent of which descendants have live views.
func move_subtrees(root_ids: PackedStringArray, displacement: Vector2) -> Dictionary:
	if not displacement.is_finite():
		return Codec.failure("位移数值无效")
	var chosen := {}
	var queue := Array(root_ids)
	var cursor := 0
	while cursor < queue.size():
		var identifier: String = queue[cursor]
		cursor += 1
		if not _records.has(identifier):
			return Codec.failure("移动对象不存在")
		if chosen.has(identifier):
			continue
		chosen[identifier] = true
		queue.append_array(Array(children(identifier)))
	var changes := []
	for identifier in chosen:
		var before := record(identifier)
		var after := before.duplicate(true)
		after.transform.position += displacement
		changes.append({"before": before, "after": after})
	return apply_transaction(changes)

## Delete complete container subtrees and endpoint edges in one model transaction.
## Preserving contents reparents children to the nearest surviving ancestor.
func remove_ids(identifiers: PackedStringArray, preserve_contents := false) -> Dictionary:
	var removed := {}
	var queue := Array(identifiers)
	var cursor := 0
	while cursor < queue.size():
		var identifier: String = queue[cursor]
		cursor += 1
		if not _records.has(identifier):
			return Codec.failure("删除对象不存在")
		if removed.has(identifier):
			continue
		removed[identifier] = true
		if not preserve_contents:
			queue.append_array(Array(children(identifier)))
		queue.append_array(Array(incident_edges(identifier)))
	var changes := []
	for before in _document.objects:
		if removed.has(before.id):
			changes.append({"before": before, "after": null})
			continue
		var after: Dictionary = before.duplicate(true)
		if removed.has(after.references.get("topic_parent", "")):
			after.references.erase("topic_parent")
			after.properties["topic_parent"] = null
		if preserve_contents and removed.has(after.references.get("container", "")):
			var owner: String = after.references.container
			while removed.has(owner):
				owner = str(_records[owner].references.get("container", ""))
			if owner.is_empty():
				after.references.erase("container")
				after.properties["container"] = null
			else:
				after.references.container = owner
		if after.type == "venn_region":
			var members := PackedStringArray()
			for identifier in after.properties.get("member_ids", PackedStringArray()):
				if not removed.has(identifier):
					members.append(identifier)
			if members.size() < 2:
				changes.append({"before": before, "after": null})
				continue
			after.properties.member_ids = members
		if before != after:
			changes.append({"before": before, "after": after})
	return apply_transaction(changes)

func find_text(query: String) -> PackedStringArray:
	var found := PackedStringArray()
	if query.is_empty():
		return found
	for value in _document.objects:
		if str(value.properties.get("text", "")).findn(query) >= 0:
			found.append(value.id)
	return found

func object_counts() -> Vector2i:
	var counts := Vector2i.ZERO
	for value in _document.objects:
		if Codec.ENTITY_TYPES.has(value.type):
			counts.x += 1
		elif value.type in ["line_edge", "venn_region"]:
			counts.y += 1
	return counts

## Copy containment descendants and internal relationships without creating views.
func selection_ids(identifiers: PackedStringArray) -> PackedStringArray:
	var selected := {}
	var queue := Array(identifiers)
	var cursor := 0
	while cursor < queue.size():
		var identifier: String = queue[cursor]
		cursor += 1
		if selected.has(identifier) or not _records.has(identifier):
			continue
		selected[identifier] = true
		queue.append_array(Array(children(identifier)))
	for value in _document.objects:
		if value.type == "line_edge" and selected.has(value.references.source) and selected.has(value.references.target):
			selected[value.id] = true
		elif value.type == "venn_region":
			var members: Variant = value.properties.get("member_ids", [])
			var complete: bool = members.size() >= 2
			for identifier in members:
				complete = complete and selected.has(identifier)
			if complete:
				selected[value.id] = true
	var ordered := PackedStringArray()
	for value in _document.objects:
		if selected.has(value.id):
			ordered.append(value.id)
	return ordered

func selection_snapshot(identifiers: PackedStringArray) -> Dictionary:
	var selected := selection_ids(identifiers)
	var subset := {"objects": [], "camera": {}}
	for value in _document.objects:
		if selected.has(value.id):
			subset.objects.append(value)
	return Codec.to_snapshot(subset, _assets)
