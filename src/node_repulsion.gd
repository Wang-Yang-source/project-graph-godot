extends Node2D

## Compatibility node for existing scene references; automatic physical layout is retired.
@export var target_root: Node
@export_range(1.0, 128.0) var influence_distance := 16.0
@export_range(1.0, 2000.0) var acceleration := 120.0
@export_range(1.0, 600.0) var maximum_speed := 24.0
@export_range(1.0, 48.0) var minimum_gap := 4.0
@export_range(1.0, 30.0) var contact_frequency := 12.0
@export_range(0.5, 2.0) var contact_damping := 0.85
@export_range(0.0, 600.0) var attraction_acceleration := 180.0
@export_range(0.0, 200.0) var attraction_speed := 80.0
@export_range(32.0, 600.0) var attraction_distance := 160.0


func _ready() -> void:
	if target_root == null:
		target_root = get_parent()
	set_physics_process(false)


func begin_local_edit(_objects: Array, _pin_drivers := true) -> void:
	pass


func begin_global_layout() -> void:
	pass


func stop_motion(_keep_scope := false) -> void:
	pass


func has_pending_motion() -> bool:
	return false
