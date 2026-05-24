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
	var payload_projectile := {"old": true, "pos": Vector2.ZERO}
	CommandoFirearmProjectileMotionState.replace_projectile_payload(
		payload_projectile,
		{"pos": Vector2.ONE, "velocity": Vector2.RIGHT}
	)
	_expect(not payload_projectile.has("old"), "projectile payload helper should clear stale fields")
	_expect(payload_projectile.get("pos", Vector2.ZERO) == Vector2.ONE, "projectile payload helper should copy replacement positions")
	_expect(payload_projectile.get("velocity", Vector2.ZERO) == Vector2.RIGHT, "projectile payload helper should copy replacement velocities")
	CommandoFirearmProjectileMotionState.write_motion_fields(
		payload_projectile,
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		Vector2(5.0, 6.0)
	)
	_expect(payload_projectile.get("prev_pos", Vector2.ZERO) == Vector2(1.0, 2.0), "motion field helper should write prev_pos")
	_expect(payload_projectile.get("pos", Vector2.ZERO) == Vector2(3.0, 4.0), "motion field helper should write pos")
	_expect(payload_projectile.get("velocity", Vector2.ZERO) == Vector2(5.0, 6.0), "motion field helper should write velocity")
	payload_projectile["life_frames"] = 3.0
	CommandoFirearmProjectileMotionState.advance_life_timer(payload_projectile, 5.0)
	_expect(is_equal_approx(float(payload_projectile.get("life_frames", -1.0)), 0.0), "life timer helper should clamp at zero")
	payload_projectile["life_frames"] = 4.0
	CommandoFirearmProjectileMotionState.finalize_frame_motion(
		payload_projectile,
		Vector2(2.0, 3.0),
		Vector2(4.0, 5.0),
		Vector2(6.0, 7.0),
		1.5
	)
	_expect(payload_projectile.get("prev_pos", Vector2.ZERO) == Vector2(2.0, 3.0), "frame motion helper should write prev_pos")
	_expect(payload_projectile.get("pos", Vector2.ZERO) == Vector2(4.0, 5.0), "frame motion helper should write pos")
	_expect(payload_projectile.get("velocity", Vector2.ZERO) == Vector2(6.0, 7.0), "frame motion helper should write velocity")
	_expect(is_equal_approx(float(payload_projectile.get("life_frames", 0.0)), 2.5), "frame motion helper should advance life timers")

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

	var linear_result: Dictionary = CommandoFirearmProjectileMotionState.advance_linear_motion(
		{"gravity": 1.0},
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		2.0
	)
	_expect(linear_result.get("prev_pos", Vector2.ZERO) == Vector2(1.0, 2.0), "linear motion helper should preserve previous position")
	_expect(linear_result.get("pos", Vector2.ZERO) == Vector2(7.0, 14.0), "linear motion helper should apply gravity before advancing position")
	_expect(linear_result.get("velocity", Vector2.ZERO) == Vector2(3.0, 6.0), "linear motion helper should return gravity-adjusted velocity")

	var rope_projectile: Dictionary = CommandoFirearmProjectileMotionState.update_net_projectile_rope(
		{"rope_points": [Vector2.ZERO, Vector2.ONE], "rope_trail_limit": 2},
		Vector2(10.0, 20.0),
		Vector2(3.0, 4.0),
		4
	)
	_expect(rope_projectile.get("origin", Vector2.ZERO) == Vector2(3.0, 4.0), "net rope helper should preserve origin")
	_expect((rope_projectile.get("rope_points", []) as Array) == [Vector2.ONE, Vector2(10.0, 20.0)], "net rope helper should append and trim rope points")

	var runtime_motion_projectile := {
		"kind": "rocket",
		"weapon_id": "bazooka",
		"speed": 8.0,
		"velocity": Vector2.UP * 8.0,
		"pos": Vector2(100.0, 200.0),
		"life_frames": 12.0,
		"smoke_trail_limit": 2,
	}
	var runtime_motion_result: Dictionary = CommandoFirearmProjectileMotionState.advance_runtime_projectile_motion(
		runtime_motion_projectile,
		"rocket",
		"bazooka",
		false,
		{},
		{},
		1.0,
		Vector2(760.0, 750.0),
		10.0,
		1,
		0.85,
		0.8,
		20.0,
		4,
		Vector2(106.0, 82.0),
		Vector2(160.0, 160.0),
		12.0,
		4
	)
	var runtime_motion_payload: Dictionary = runtime_motion_result.get("projectile", {})
	_expect(not bool(runtime_motion_result.get("consumed", true)), "runtime motion helper should keep active projectiles")
	_expect((runtime_motion_payload.get("velocity", Vector2.ZERO) as Vector2).length() > 8.0, "runtime motion helper should delegate rocket acceleration")
	_expect(is_equal_approx(float(runtime_motion_payload.get("life_frames", 0.0)), 11.0), "runtime motion helper should finalize life timer")


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

	runtime.projectiles = [{
		"kind": "bullet",
		"weapon_id": "rifle",
		"gravity": 1.0,
		"velocity": Vector2(3.0, 4.0),
		"pos": Vector2(100.0, 100.0),
		"life_frames": 12.0,
	}]
	runtime._update_projectiles(2.0, {"width": 760.0, "height": 750.0}, {})
	var runtime_linear: Dictionary = runtime.projectiles[0]
	_expect(runtime_linear.get("prev_pos", Vector2.ZERO) == Vector2(100.0, 100.0), "runtime projectile update should preserve linear-motion prev_pos")
	_expect(runtime_linear.get("pos", Vector2.ZERO) == Vector2(106.0, 112.0), "runtime projectile update should delegate gravity-aware linear motion")
	_expect(runtime_linear.get("velocity", Vector2.ZERO) == Vector2(3.0, 6.0), "runtime projectile update should keep gravity-adjusted velocity")


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
	_expect(
		source.find("CommandoFirearmProjectileMotionState.advance_runtime_projectile_motion") >= 0,
		"runtime should delegate projectile frame motion to the owner"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
