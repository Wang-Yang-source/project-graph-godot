extends "res://tests/node_repulsion_smoke.gd"

func _run() -> void:
	GraphPreferences.set_value("physics", true, false)
	for ticks in [30.0,60.0,120.0]:
		fixture()
		var a := make_body(Vector2.ZERO)
		var b := make_body(Vector2(80,0))
		a.drag_controlled = true
		solver._physics_process(1.0 / ticks)
		var first_speed := b.linear_velocity.x
		check(first_speed > 0.0 and first_speed < 24.0 * ticks, "Contact starts with bounded spring acceleration instead of a one-frame position correction")
		check(a.linear_velocity.is_zero_approx(), "Spring preserves pointer control")
		b.linear_velocity = Vector2.ZERO
		b.position = Vector2(95,0)
		solver._physics_process(1.0 / ticks)
		check(b.linear_velocity.x < first_speed, "Shallower contact produces a weaker response")
		check(is_finite(b.linear_velocity.x), "Spring remains finite across physics rates")
		cleanup()
	print("SPRING_CONTACT: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
