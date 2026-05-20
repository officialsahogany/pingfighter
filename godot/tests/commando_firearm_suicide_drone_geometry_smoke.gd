extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSuicideDroneGeometry := preload("res://scripts/characters/commando_firearm_suicide_drone_geometry.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_suicide_drone_geometry()
	_verify_runtime_delegates_suicide_drone_geometry()

	if _failures.is_empty():
		print("commando_firearm_suicide_drone_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_suicide_drone_geometry() -> void:
	var drone_size := Vector2(48.0, 48.0)
	_expect(
		CommandoFirearmSuicideDroneGeometry.get_spawn_pos({}, 760.0, 750.0, drone_size) == Vector2(457.5, 650.0),
		"suicide drone default spawn position should preserve legacy player fallback geometry"
	)
	_expect(
		CommandoFirearmSuicideDroneGeometry.get_spawn_pos({"player_pos": Vector2(200.0, 500.0), "paddle_width": 120.0}, 760.0, 750.0, drone_size) == Vector2(260.0, 470.0),
		"suicide drone spawn position should anchor above the paddle center"
	)
	_expect(
		CommandoFirearmSuicideDroneGeometry.get_player_lock_pos({}, 760.0, 750.0) == Vector2(457.5, 705.0),
		"suicide drone default player-lock position should preserve legacy player fallback geometry"
	)
	_expect(
		CommandoFirearmSuicideDroneGeometry.get_player_lock_pos({"player_pos": Vector2(200.0, 500.0), "paddle_width": 120.0, "paddle_height": 40.0}, 760.0, 750.0) == Vector2(260.0, 520.0),
		"suicide drone player-lock position should anchor to the paddle center"
	)

	var projectile := {"pos": Vector2(100.0, 80.0), "size": drone_size}
	_expect(
		CommandoFirearmSuicideDroneGeometry.get_rect(projectile, drone_size) == Rect2(76.0, 56.0, 48.0, 48.0),
		"suicide drone rect should be centered on projectile position"
	)
	_expect(
		CommandoFirearmSuicideDroneGeometry.hits_ball(projectile, {"ball_pos": Vector2(120.0, 80.0), "ball_vel": Vector2.ZERO, "ball_size": 20.0}, drone_size),
		"suicide drone should hit overlapping active ball rect"
	)
	_expect(
		not CommandoFirearmSuicideDroneGeometry.hits_ball(projectile, {"ball_active": false, "ball_pos": Vector2(120.0, 80.0), "ball_size": 20.0}, drone_size),
		"inactive ball should not collide with suicide drone"
	)
	_expect(
		not CommandoFirearmSuicideDroneGeometry.hits_ball(projectile, {"ball_pos": Vector2(200.0, 80.0), "ball_size": 20.0}, drone_size),
		"non-overlapping ball should not collide with suicide drone"
	)
	_expect(
		CommandoFirearmSuicideDroneGeometry.hits_boss_rect(projectile, Rect2(110.0, 70.0, 60.0, 40.0), drone_size),
		"suicide drone should hit overlapping boss rect"
	)
	_expect(
		not CommandoFirearmSuicideDroneGeometry.hits_boss_rect(projectile, Rect2(180.0, 70.0, 60.0, 40.0), drone_size),
		"suicide drone should miss non-overlapping boss rect"
	)
	_expect(
		CommandoFirearmSuicideDroneGeometry.hits_top_wall({"pos": Vector2(80.0, 24.0), "size": drone_size}, drone_size),
		"suicide drone should hit top wall when its rect reaches y zero"
	)
	_expect(
		not CommandoFirearmSuicideDroneGeometry.hits_top_wall({"pos": Vector2(80.0, 25.0), "size": drone_size}, drone_size),
		"suicide drone should not hit top wall while fully below y zero"
	)


func _verify_runtime_delegates_suicide_drone_geometry() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var drone_size := Vector2(48.0, 48.0)
	var projectile := {"pos": Vector2(100.0, 80.0), "size": drone_size}
	_expect(runtime._get_suicide_drone_spawn_pos({}) == Vector2(457.5, 650.0), "runtime spawn-position wrapper should delegate")
	_expect(runtime._get_player_lock_pos({}) == Vector2(457.5, 705.0), "runtime player-lock wrapper should delegate")
	_expect(runtime._get_suicide_drone_rect(projectile) == Rect2(76.0, 56.0, 48.0, 48.0), "runtime rect wrapper should delegate")
	_expect(runtime._suicide_drone_hits_ball(projectile, {"ball_pos": Vector2(120.0, 80.0), "ball_size": 20.0}), "runtime ball-hit wrapper should delegate")
	_expect(runtime._suicide_drone_hits_boss(projectile, {"boss_pos": Vector2(100.0, 80.0), "boss_width": 60.0, "boss_height": 40.0}), "runtime boss-hit wrapper should delegate")
	_expect(runtime._suicide_drone_hits_top_wall({"pos": Vector2(80.0, 24.0), "size": drone_size}), "runtime top-wall wrapper should delegate")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
