extends Control
## Native viewport rendering at physical pixels, while editor geometry stays logical.
@onready var _canvas: SubViewportContainer = $Canvas
@onready var _view: SubViewport = $Canvas/SubViewport
var _sampling_key: Array = []

func _ready() -> void:
	resized.connect(sync_resolution)
	sync_resolution()

func _process(_delta: float) -> void:
	sync_resolution()

func sync_resolution() -> void:
	if not is_node_ready():
		return
	var logical := Vector2i(size.round()).max(Vector2i.ONE)
	var screen_transform := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var pixel_scale := screen_transform.get_scale().abs().max(Vector2.ONE)
	var pixels := Vector2i((Vector2(logical) * pixel_scale).ceil())
	var key := [logical, pixels]
	if key == _sampling_key:
		return
	_sampling_key = key
	_view.size_2d_override = logical
	_canvas.scale = Vector2(logical) / Vector2(pixels)
	_canvas.size = Vector2(pixels)
