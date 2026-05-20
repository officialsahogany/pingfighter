extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSupportAircraftGeometry := preload("res://scripts/characters/commando_firearm_support_aircraft_geometry.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_support_aircraft_geometry()
	_verify_runtime_delegates_support_aircraft_geometry()

	if _failures.is_empty():
		print("commando_firearm_support_aircraft_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_support_aircraft_geometry() -> void:
	var fallback_pos := Vector2(-140.0, 52.0)
	var collision_size := Vector2(160.0, 50.0)
	@warning_ignore("shadowed_variable_base_class")
	var call := {
		"aircraft_active": true,
		"aircraft_pos": Vector2(100.0, 50.0),
	}
	_expect(
		CommandoFirearmSupportAircraftGeometry.get_collision_rect(call, fallback_pos, collision_size) == Rect2(20.0, 25.0, 160.0, 50.0),
		"support aircraft collision rect should be centered on aircraft_pos"
	)
	_expect(
		CommandoFirearmSupportAircraftGeometry.get_collision_rect({"aircraft_pos": "bad"}, fallback_pos, collision_size) == Rect2(-220.0, 27.0, 160.0, 50.0),
		"support aircraft collision rect should use fallback position for invalid values"
	)
	_expect(
		CommandoFirearmSupportAircraftGeometry.ball_path_hits(call, Vector2(0.0, 50.0), Vector2(250.0, 50.0), 10.0, fallback_pos, collision_size),
		"ball path should hit when the segment crosses the grown aircraft rect"
	)
	_expect(
		CommandoFirearmSupportAircraftGeometry.ball_path_hits(call, Vector2(30.0, 30.0), Vector2(30.0, 30.0), 10.0, fallback_pos, collision_size),
		"ball path should hit when an endpoint starts inside the grown aircraft rect"
	)
	_expect(
		not CommandoFirearmSupportAircraftGeometry.ball_path_hits(call, Vector2(0.0, 140.0), Vector2(250.0, 140.0), 10.0, fallback_pos, collision_size),
		"ball path should miss when the segment stays outside the grown aircraft rect"
	)
	_expect(
		not CommandoFirearmSupportAircraftGeometry.ball_path_hits({"aircraft_active": false, "aircraft_pos": Vector2(100.0, 50.0)}, Vector2(0.0, 50.0), Vector2(250.0, 50.0), 10.0, fallback_pos, collision_size),
		"inactive aircraft should not collide with the ball path"
	)


func _verify_runtime_delegates_support_aircraft_geometry() -> void:
	var runtime := CommandoFirearmRuntime.new()
	@warning_ignore("shadowed_variable_base_class")
	var call := {
		"aircraft_active": true,
		"aircraft_pos": Vector2(100.0, 50.0),
	}
	_expect(runtime._get_support_aircraft_collision_rect(call) == Rect2(20.0, 25.0, 160.0, 50.0), "runtime collision rect wrapper should delegate")
	_expect(runtime._support_aircraft_ball_path_hits(call, Vector2(0.0, 50.0), Vector2(250.0, 50.0), 10.0), "runtime ball-path wrapper should delegate crossing hits")
	_expect(not runtime._support_aircraft_ball_path_hits(call, Vector2(0.0, 140.0), Vector2(250.0, 140.0), 10.0), "runtime ball-path wrapper should delegate misses")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
