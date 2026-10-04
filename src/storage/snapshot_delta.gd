extends RefCounted
## Project snapshots: retain changed records and explicit object order only.
static func between(before: Dictionary, after: Dictionary) -> Dictionary:
	var a := _index(before)
	var b := _index(after)
	if not a.ok or not b.ok:
		return {"ok":false, "error":"快照对象身份无效"}
	var changes := []
	for identifier in a.records:
		var old: Dictionary = a.records[identifier]
		var new: Variant = b.records.get(identifier)
		if old != new:
			changes.append({"id":identifier, "before":old.duplicate(true),
				"after":new.duplicate(true) if new != null else null})
	for identifier in b.records:
		if not a.records.has(identifier):
			changes.append({"id":identifier, "before":null, "after":b.records[identifier].duplicate(true)})
	var before_meta := before.duplicate()
	var after_meta := after.duplicate()
	before_meta.erase("objects")
	after_meta.erase("objects")
	return {"ok":true, "changes":changes, "before_order":a.order, "after_order":b.order,
		"before_metadata":before_meta.duplicate(true), "after_metadata":after_meta.duplicate(true)}

static func apply(current: Dictionary, delta: Dictionary, forward: bool) -> Dictionary:
	var indexed := _index(current)
	if not indexed.ok:
		return indexed
	var expected := "before" if forward else "after"
	var desired := "after" if forward else "before"
	var records: Dictionary = indexed.records.duplicate()
	for change in delta.changes:
		if records.get(change.id) != change[expected]:
			return {"ok":false, "error":"历史记录基线已变化"}
		if change[desired] == null:
			records.erase(change.id)
		else:
			records[change.id] = change[desired].duplicate(true)
	var objects := []
	for identifier in delta[desired + "_order"]:
		if not records.has(identifier):
			return {"ok":false, "error":"历史记录顺序引用缺失"}
		objects.append(records[identifier])
	if objects.size() != records.size():
		return {"ok":false, "error":"历史记录顺序不完整"}
	var snapshot: Dictionary = delta[desired + "_metadata"].duplicate(true)
	snapshot["objects"] = objects
	return {"ok":true, "snapshot":snapshot}

static func _index(snapshot: Dictionary) -> Dictionary:
	if not snapshot.get("objects") is Array:
		return {"ok":false, "error":"快照没有对象数组"}
	var records := {}
	var order := PackedStringArray()
	for record in snapshot.objects:
		if not record is Dictionary or not record.get("properties") is Dictionary:
			return {"ok":false, "error":"快照记录无效"}
		var identifier: Variant = JSON.to_native(record.properties.get("id"))
		if not identifier is String or identifier.is_empty() or records.has(identifier):
			return {"ok":false, "error":"快照 ID 无效或重复"}
		records[identifier] = record
		order.append(identifier)
	return {"ok":true, "records":records, "order":order}
