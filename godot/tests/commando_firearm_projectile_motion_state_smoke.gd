extends SceneTree

const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_projectile_motion_state()
	_verify_runtime_delegates_projectile_motion_state()
	_verify_removed_runtime_projectile_motion_bridges()

	if _failures.is_empty():
		print("commando_firearm_projectile_motion_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_projectile_motion_state() -> void:
	var bounce_result: Dictionary = CommandoFirearmProjectileMotionState.apply_pistol_side_wall_bounce(
		{"weapon_id": "commando_pistol", "wall_bounces": 0},
		Vector2(8.0, 100.0),
		Vector2(-5.0, 2.0),
		760.0,
		16.0,
		2,
		0.62
	)
	_expect(bool(bounce_result.get("bounced", false)), "pistol side-wall helper should bounce at the left margin")
	var bounced_projectile: Dictionary = bounce_result.get("projectile", {})
	_expect(bounced_projectile.get("pos", Vector2.ZERO) == Vector2(16.0, 100.0), "pistol bounce should clamp x to margin")
	_expect(is_equal_approx((bounced_projectile.get("velocity", Vector2.ZERO) as Vector2).x, 3.1), "pistol bounce should flip and damp velocity")
	_expect(int(bounced_projectile.get("wall_bounces", 0)) == 1, "pistol bounce should increment bounce count")
	_expect(
		not bool(CommandoFirearmProjectileMotionState.apply_pistol_side_wall_bounce({"wall_bounces": 2}, Vector2(8.0, 0.0), Vector2.LEFT, 760.0, 16.0, 2, 0.62).get("bounced", true)),
		"pistol side-wall helper should stop after max bounces"
	)

	var rocket_result: Dictionary = CommandoFirearmProjectileMotionState.update_rocket_motion(
		{"kind": "rocket", "speed": 8.0, "smoke_trail_limit": 2},
		Vector2(100.0, 200.0),
		Vector2.UP * 8.0,
		2.0,
		0.8,
		20.0,
		4
	)
	_expect(is_equal_approx((rocket_result.get("velocity", Vector2.ZERO) as Vector2).length(), 9.6), "rocket motion should accelerate by configured amount")
	var rocket_projectile: Dictionary = rocket_result.get("projectile", {})
	_expect((rocket_projectile.get("smoke_trail", []) as Array).size() == 1, "rocket motion should seed smoke trail")

	var rope_projectile: Dictionary = CommandoFirearmProjectileMotionState.update_net_projectile_rope(
		{"rope_points": [Vector2.ZERO, Vector2.ONE], "rope_trail_limit": 2},
		Vector2(10.0, 20.0),
		Vector2(3.0, 4.0),
		4
	)
	_expect(rope_projectile.get("origin", Vector2.ZERO) == Vector2(3.0, 4.0), "net rope helper should preserve origin")
	_expect((rope_projectile.get("rope_points", []) as Array) == [Vector2.ONE, Vector2(10.0, 20.0)], "net rope helper should append and trim rope points")


func _verify_runtime_delegates_projectile_motion_state() -> void:
	var runtime := CommandoFirearmRuntime.new()

	runtime.projectiles = [{
		"kind": "bullet",
		"weapon_id": "commando_pistol",
		"wall_bounces": 0,
		"velocity": Vector2(-5.0, 2.0),
		"pos": Vector2(13.0, 100.0),
		"life_frames": 12.0,
	}]
	runtime._update_projectiles(1.0, {"width": 760.0, "height": 750.0}, {})
	var runtime_pistol: Dictionary = runtime.projectiles[0]
	_expect(int(runtime_pistol.get("wall_bounces", 0)) == 1, "runtime projectile update should mutate pistol side-wall bounce count")
	_expect(runtime_pistol.get("pos", Vector2.ZERO) == Vector2(10.0, 102.0), "runtime projectile update should clamp pistol side-wall bounce position")
	_expect((runtime_pistol.get("velocity", Vector2.ZERO) as Vector2).x > 0.0, "runtime projectile update should flip pistol side-wall bounce velocity")

	runtime.projectiles = [{
		"kind": "rocket",
		"weapon_id": "bazooka",
		"speed": 8.0,
		"velocity": Vector2.UP * 8.0,
		"pos": Vector2(100.0, 200.0),
		"life_frames": 12.0,
		"smoke_trail_limit": 2,
	}]
	runtime._update_projectiles(1.0, {"width": 760.0, "height": 750.0}, {})
	var runtime_rocket: Dictionary = runtime.projectiles[0]
	_expect((runtime_rocket.get("velocity", Vector2.ZERO) as Vector2).length() > 8.0, "runtime projectile update should delegate rocket acceleration")
	_expect((runtime_rocket.get("smoke_trail", []) as Array).size() == 1, "runtime projectile update should mutate rocket smoke trail")

	runtime.projectiles = [{
		"kind": "net",
		"weapon_id": "net_gun",
		"velocity": Vector2.ZERO,
		"pos": Vector2(10.0, 20.0),
		"life_frames": 12.0,
		"rope_points": [Vector2.ZERO],
		"rope_trail_limit": 2,
	}]
	runtime._update_projectiles(1.0, {"player_pos": Vector2(300.0, 680.0)}, {})
	var runtime_net: Dictionary = runtime.projectiles[0]
	_expect((runtime_net.get("rope_points", []) as Array).size() == 2, "runtime projectile update should delegate net rope update")


func _verify_removed_runtime_projectile_motion_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_apply_pistol_side_wall_bounce",
		"_apply_stage2_pistol_rock_bounce",
		"_is_wall_bouncing_pistol",
		"_update_rocket_motion",
		"_update_net_projectile_rope",
	]:
		_expect(source.find("func %s(" % bridge_name) < 0, "runtime should not keep projectile motion bridge %s" % bridge_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
