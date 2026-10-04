extends "res://src/stage/stage.gd"
## Instrument real callbacks; inclusive microseconds, no manual replay.
var perf_totals := {}

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	perf_totals["_process"] = perf_totals.get("_process", 0) + Time.get_ticks_usec() - started
