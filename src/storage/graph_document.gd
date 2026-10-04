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
