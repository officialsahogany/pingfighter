extends SceneTree

const TailGeometry := preload("res://scripts/stages/stage3/stage3_tail_whip_geometry.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_curve_generation()
	_verify_collision_window_and_sample_budget()
	if _failures.is_empty():
		print("stage3_tail_whip_geometry_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_curve_generation() -> void:
	var center := Vector2(380.0, 375.0)
	var target := center + Vector2(100.0, 0.0)
	var points := TailGeometry.build_points(0.45, target, center, 1000)
	_expect(points.size() == TailGeometry.TAIL_POINT_COUNT, "tail curve should preserve the 24-point runtime budget")
	_expect(points[0].is_equal_approx(center), "tail curve should remain rooted at the boss center")
	_expect(points[points.size() - 1].is_equal_approx(center + Vector2(50.0, 0.0)), "half-power extension should reach half the target distance")
	var repeated := TailGeometry.build_points(0.45, target, center, 1000)
	_expect(points == repeated, "same inputs and injected clock should generate the same curve")
	var recovery_a := TailGeometry.build_points(0.80, target, center, 0)
	var recovery_b := TailGeometry.build_points(0.80, target, center, 1000)
	_expect(not recovery_a[8].is_equal_approx(recovery_b[8]), "recovery wave should respond to the injected animation clock")


func _verify_collision_window_and_sample_budget() -> void:
	var center := Vector2(380.0, 375.0)
	var points := TailGeometry.build_points(0.45, center + Vector2(120.0, 0.0), center, 0)
	var middle_point := points[points.size() / 2]
	_expect(TailGeometry.hits_ball(0.45, middle_point, points), "ball inside the middle tail segment should collide during the hit window")
	_expect(not TailGeometry.hits_ball(0.10, middle_point, points), "early coil phase should not collide")
	_expect(not TailGeometry.hits_ball(0.90, middle_point, points), "late recovery phase should not collide")
	var sampled_points: Array[Vector2] = []
	for _index in range(TailGeometry.TAIL_POINT_COUNT):
		sampled_points.append(Vector2.ZERO)
	sampled_points[sampled_points.size() - 1] = Vector2(1000.0, 1000.0)
	_expect(not TailGeometry.hits_ball(0.45, Vector2(1000.0, 1000.0), sampled_points), "collision query should stay bounded to the middle tail sample range")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
