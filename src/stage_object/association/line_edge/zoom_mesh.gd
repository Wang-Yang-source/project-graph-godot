extends MeshInstance2D
static var _materials := {}
var _key: Array = []

func update_stroke(points: PackedVector2Array, stroke: float, minimum_scale: float, display_scale: float) -> void:
	var envelope := stroke + 2.0 / maxf(minimum_scale, .001)
	var material_key := Vector3(stroke, envelope, display_scale)
	if not _materials.has(material_key):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/stage_object/association/line_edge/zoom_mesh.gdshader")
		mat.set_shader_parameter("stroke_width", stroke)
		mat.set_shader_parameter("envelope_width", envelope)
		mat.set_shader_parameter("pixel_scale", display_scale)
		if _materials.size() >= 128:
			_materials.clear()
		_materials[material_key] = mat
	material = _materials[material_key]
	var key := [points, envelope]
	if key == _key:
		return
	_key = key
	if points.size() < 2:
		mesh = null
		return
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in points.size():
		var incoming := (points[index] - points[maxi(0, index - 1)]).normalized()
		var outgoing := (points[mini(points.size() - 1, index + 1)] - points[index]).normalized()
		if incoming == Vector2.ZERO:
			incoming = outgoing
		if outgoing == Vector2.ZERO:
			outgoing = incoming
		var normal := (incoming + outgoing).normalized().orthogonal()
		var denominator := maxf(absf(normal.dot(outgoing.orthogonal())), .25)
		var miter := normal / denominator
		vertices.append(points[index] - miter * envelope * .5)
		vertices.append(points[index] + miter * envelope * .5)
		uvs.append(-miter)
		uvs.append(miter + Vector2(100, 0))
		if index > 0:
			var end := index * 2
			indices.append_array(PackedInt32Array([end-2,end-1,end,end-1,end+1,end]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	mesh = result
