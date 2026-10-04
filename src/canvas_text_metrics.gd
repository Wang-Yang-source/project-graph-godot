class_name CanvasTextMetrics
extends RefCounted
## One immutable font configuration and reusable native shaping results.
const FONT_PATH := "res://assets/fonts/canvas-msdf.res"
const CAPACITY := 4096
const LAYOUT_VERSION := 1
static var _font: FontVariation
static var _sizes := {}
static var _mutex := Mutex.new()
static var _fingerprint := ""

static func canvas_font() -> FontVariation:
	_mutex.lock()
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = load(FONT_PATH) as FontFile
		_font.variation_embolden = 0.0
		_font.set_cache_capacity(CAPACITY, CAPACITY)
	var result := _font
	_mutex.unlock()
	return result

static func measure(value: String, font: Font, point_size: int, line_spacing: int = 3) -> Vector2:
	var key := [font.get_instance_id(), value, point_size, line_spacing]
	_mutex.lock()
	if _sizes.has(key):
		var cached: Vector2 = _sizes[key]
		_mutex.unlock()
		return cached
	_mutex.unlock()
	var width := 0.0
	var height := floorf(font.get_height(point_size))
	var rows := value.split("\n")
	for row in rows:
		var shaped := font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
		width = maxf(width, shaped.x)
		height = maxf(height, shaped.y)
	var result := Vector2(ceilf(width), (ceilf(height) + line_spacing) * maxi(1, rows.size()))
	_mutex.lock()
	if _sizes.size() >= CAPACITY:
		_sizes.erase(_sizes.keys()[0])
	_sizes[key] = result
	_mutex.unlock()
	return result

static func fingerprint() -> String:
	_mutex.lock()
	if _fingerprint.is_empty():
		_fingerprint = str([LAYOUT_VERSION, FileAccess.get_sha256(FONT_PATH),
			Engine.get_version_info().hash, OS.get_name(), OS.get_locale(),
			TextServerManager.get_primary_interface().get_name()]).sha256_text()
	var result := _fingerprint
	_mutex.unlock()
	return result
