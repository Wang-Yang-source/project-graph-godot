extends "res://src/entity_layer_mover.gd"
## Instrument real callbacks; inclusive microseconds, no manual replay.
var perf_totals := {}

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	perf_totals["_process"] = perf_totals.get("_process", 0) + Time.get_ticks_usec() - started

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._physics_process(delta)
	perf_totals["_physics_process"] = perf_totals.get("_physics_process", 0) + Time.get_ticks_usec() - started

func refresh_layout() -> void:
	var started := Time.get_ticks_usec()
	super.refresh_layout()
	perf_totals["refresh_layout"] = perf_totals.get("refresh_layout", 0) + Time.get_ticks_usec() - started
