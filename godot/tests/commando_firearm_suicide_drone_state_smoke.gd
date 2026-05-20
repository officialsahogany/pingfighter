extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_suicide_drone_state()
	_verify_runtime_delegates_suicide_drone_state()

	if _failures.is_empty():
		print("commando_firearm_suicide_drone_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_suicide_drone_state() -> void:
	var profile := {
		"max_speed": 14.0,
		"acceleration": 1.2,
		"radius": 24.0,
		"life_frames": 3600.0,
		"impact_radius": 40.0,
		"explosion_radius": 150.0,
	}
	var projectile: Dictionary = CommandoFirearmSuicideDroneState.build_projectile(
		profile,
		Vector2(100.0, 200.0),
		Vector2(380.0, 80.0),
		7,
		Vector2(100.0, 230.0),
		Vector2(48.0, 48.0),
		14.0,
		1.2,
		3600.0,
		6.0,
		18.0
	)
	_expect(str(projectile.get("weapon_id", "")) == "suicide_drone", "projectile payload should tag suicide drone weapon")
	_expect(str(projectile.get("kind", "")) == "drone", "projectile payload should use drone kind")
	_expect(bool(projectile.get("manual_control", false)), "projectile payload should be manual-control")
	_expect(projectile.get("pos", Vector2.ZERO) == Vector2(100.0, 200.0), "projectile payload should preserve origin")
	_expect(is_equal_approx(float(projectile.get("grace_timer_frames", 0.0)), 6.0), "projectile payload should seed grace frames")

	var steered: Dictionary = CommandoFirearmSuicideDroneState.apply_input(
		projectile,
		Vector2.RIGHT,
		1.2,
		14.0,
		18.0,
		2.0
	)
	var steered_velocity: Vector2 = steered.get("velocity", Vector2.ZERO) as Vector2
	_expect(steered_velocity == Vector2(1.2, 0.0), "input state should accelerate by configured amount")
	_expect(is_equal_approx(float(steered.get("rotor_speed", 0.0)), 20.4), "input state should scale rotor speed from velocity")

	var decayed: Dictionary = CommandoFirearmSuicideDroneState.apply_input(
		steered,
		Vector2.ZERO,
		1.2,
		14.0,
		18.0,
		2.0
	)
	_expect(is_equal_approx((decayed.get("velocity", Vector2.ZERO) as Vector2).x, 1.08), "empty input should decay velocity")

	var advanced: Dictionary = CommandoFirearmSuicideDroneState.advance_active_projectile(
		steered,
		1.0,
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0),
		18.0
	)
	_expect(is_equal_approx(float(advanced.get("grace_timer_frames", 0.0)), 5.0), "advance state should decrement grace frames")
	_expect(is_equal_approx(float(advanced.get("rotor_angle", 0.0)), 20.4), "advance state should rotate by rotor speed")
	var clamped: Dictionary = CommandoFirearmSuicideDroneState.clamp_projectile(
		{"pos": Vector2(-10.0, 800.0), "size": Vector2(48.0, 48.0)},
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0)
	)
	_expect(clamped.get("pos", Vector2.ZERO) == Vector2(24.0, 726.0), "clamp state should keep drone inside field bounds")

	var homing_velocity: Vector2 = CommandoFirearmSuicideDroneState.get_homing_velocity(
		Vector2(100.0, 100.0),
		{"manual_control": false, "speed": 10.0, "velocity": Vector2.UP * 10.0},
		Vector2(200.0, 100.0),
		1.0
	)
	_expect(homing_velocity.x > 0.0 and homing_velocity.y < 0.0, "homing velocity should blend current velocity toward target")
	_expect(bool(CommandoFirearmSuicideDroneState.build_fire_result({}, 4, 4, 6.0, 500.0).get("fired", false)), "fire result should expose fired flag")
	_expect(str(CommandoFirearmSuicideDroneState.build_fire_failed_result(500.0, "cooldown", 90.0).get("failure_reason", "")) == "cooldown", "fire failed result should expose failure reason")
	_expect(bool(CommandoFirearmSuicideDroneState.build_active_input_result(steered, 500.0).get("drone_active", false)), "active input result should expose active flag")
	_expect(bool(CommandoFirearmSuicideDroneState.build_detonation_result("manual", Vector2(1.0, 2.0), false, 90.0).get("commando_suicide_drone_detonated", false)), "detonation result should expose detonation flag")


func _verify_runtime_delegates_suicide_drone_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var profile := runtime._get_weapon_profile("suicide_drone")
	var projectile: Dictionary = runtime._build_suicide_drone_projectile(
		profile,
		Vector2(100.0, 200.0),
		{"boss_pos": Vector2(330.0, 60.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0},
		7
	)
	_expect(str(projectile.get("weapon_id", "")) == "suicide_drone", "runtime projectile payload wrapper should delegate")
	var steered: Dictionary = runtime._get_suicide_drone_input_projectile_state(Vector2.RIGHT, projectile)
	_expect(is_equal_approx((steered.get("velocity", Vector2.ZERO) as Vector2).x, 1.2), "runtime input state wrapper should delegate")
	var fire_result: Dictionary = runtime._build_suicide_drone_fire_result({}, 4, 500.0)
	_expect(int(fire_result.get("ammo_current", -1)) == 3, "runtime fire-result wrapper should delegate")
	var active_result: Dictionary = runtime._build_suicide_drone_active_input_result(steered, 500.0)
	_expect(active_result.get("drone_pos", Vector2.ZERO) == Vector2(100.0, 200.0), "runtime active-result wrapper should delegate")
	var detonation_result: Dictionary = runtime._build_suicide_drone_detonation_result("manual", Vector2(5.0, 6.0), false)
	_expect(str(detonation_result.get("commando_suicide_drone_reason", "")) == "manual", "runtime detonation-result wrapper should delegate")
	var clamped_projectile := {"pos": Vector2(-10.0, 800.0), "size": Vector2(48.0, 48.0)}
	runtime._clamp_suicide_drone_projectile(clamped_projectile)
	_expect(clamped_projectile.get("pos", Vector2.ZERO) == Vector2(24.0, 726.0), "runtime clamp wrapper should delegate")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
