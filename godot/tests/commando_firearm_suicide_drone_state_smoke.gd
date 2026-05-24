extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")

var _failures: Array[String] = []


class FakeWeaponController:
	var ammo_current := 4

	func consume_current_weapon_ammo(amount: int) -> bool:
		if ammo_current < amount:
			return false
		ammo_current -= amount
		return true

	func get_current_weapon_data() -> Dictionary:
		return {
			"ammo_current": ammo_current,
			"ammo_max": 4,
			"can_fire": ammo_current > 0,
		}


func _init() -> void:
	_verify_direct_suicide_drone_state()
	_verify_runtime_delegates_suicide_drone_state()
	_verify_removed_runtime_active_projectile_bridges()

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
	_expect(CommandoFirearmSuicideDroneState.is_projectile({"weapon_id": "suicide_drone", "kind": "drone"}), "projectile predicate should accept live suicide drones")
	_expect(not CommandoFirearmSuicideDroneState.is_projectile({"weapon_id": "suicide_drone", "kind": "rocket"}), "projectile predicate should reject non-drone kinds")
	var active_projectiles := [
		{"weapon_id": "bazooka", "kind": "rocket"},
		{"weapon_id": "suicide_drone", "kind": "drone"},
	]
	_expect(CommandoFirearmSuicideDroneState.get_active_projectile_index(active_projectiles) == 1, "active projectile lookup should return the matching index")
	_expect(CommandoFirearmSuicideDroneState.has_active_projectile(active_projectiles), "active projectile helper should report active drones")
	_expect(CommandoFirearmSuicideDroneState.get_active_projectile_index([{"weapon_id": "suicide_drone", "kind": "rocket"}]) == -1, "active projectile lookup should reject non-drone kinds")
	_expect(bool(CommandoFirearmSuicideDroneState.build_detonation_result("manual", Vector2(1.0, 2.0), false, 90.0).get("commando_suicide_drone_detonated", false)), "detonation result should expose detonation flag")


func _verify_runtime_delegates_suicide_drone_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var config := {
		"player_pos": Vector2(100.0, 680.0),
		"boss_pos": Vector2(330.0, 60.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var weapon_controller := FakeWeaponController.new()
	var fire_result: Dictionary = runtime._update_suicide_drone_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		config,
		{"commando_weapon_controller": weapon_controller},
		{"ammo_current": 4, "can_fire": true},
		1000
	)
	_expect(bool(fire_result.get("fired", false)), "runtime fire path should expose fired suicide drone result")
	_expect(int(fire_result.get("ammo_current", -1)) == 3, "runtime fire path should decrement suicide drone ammo")
	_expect(runtime.projectiles.size() == 1, "runtime fire path should append suicide drone projectile")
	var projectile: Dictionary = runtime.projectiles[0]
	_expect(str(projectile.get("weapon_id", "")) == "suicide_drone", "runtime fire path should build suicide drone projectile")

	var blocked_runtime := CommandoFirearmRuntime.new()
	blocked_runtime.suicide_drone_cooldown_frames = 19.0
	var blocked_result: Dictionary = blocked_runtime._update_suicide_drone_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		config,
		{},
		{"ammo_current": 4, "can_fire": true},
		1000
	)
	_expect(str(blocked_result.get("failure_reason", "")) == "suicide_drone_cooldown", "runtime failure path should preserve suicide-drone failure reason")
	_expect(is_equal_approx(float(blocked_result.get("cooldown_frames", 0.0)), 19.0), "runtime failure path should preserve suicide-drone cooldown timer")

	var active_result: Dictionary = runtime._update_active_suicide_drone_input({"right_pressed": true}, 500.0, config, {})
	_expect(bool(active_result.get("drone_active", false)), "runtime active input path should expose active flag")
	var steered: Dictionary = runtime.projectiles[0]
	_expect((steered.get("velocity", Vector2.ZERO) as Vector2).x > 0.0, "runtime active input path should steer the drone projectile")

	var detonation_result: Dictionary = runtime._detonate_suicide_drone_at_index(0, steered, "manual", config, {})
	_expect(str(detonation_result.get("commando_suicide_drone_reason", "")) == "manual", "runtime detonation path should expose detonation reason")
	var clamped_projectile := {"pos": Vector2(-10.0, 800.0), "size": Vector2(48.0, 48.0)}
	clamped_projectile = CommandoFirearmSuicideDroneState.clamp_projectile(
		clamped_projectile,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.SUICIDE_DRONE_SIZE
	)
	_expect(clamped_projectile.get("pos", Vector2.ZERO) == Vector2(24.0, 726.0), "clamp owner should preserve runtime drone bounds")


func _verify_removed_runtime_active_projectile_bridges() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _has_active_suicide_drone_projectile("), "runtime should not keep active suicide-drone predicate bridge")
	_expect(not runtime_source.contains("func _get_active_suicide_drone_index("), "runtime should not keep active suicide-drone lookup bridge")
	_expect(not runtime_source.contains("func _is_suicide_drone_projectile("), "runtime should not keep suicide-drone projectile predicate bridge")
	_expect(not runtime_source.contains("func _build_suicide_drone_fire_result("), "runtime should not keep suicide-drone fire-result bridge")
	_expect(not runtime_source.contains("func _suicide_drone_fire_failed("), "runtime should not keep suicide-drone fire-failed bridge")
	_expect(not runtime_source.contains("func _build_suicide_drone_active_input_result("), "runtime should not keep suicide-drone active-input bridge")
	_expect(not runtime_source.contains("func _build_suicide_drone_projectile("), "runtime should not keep suicide-drone projectile build bridge")
	_expect(not runtime_source.contains("func _apply_suicide_drone_input_to_projectile("), "runtime should not keep suicide-drone input mutation bridge")
	_expect(not runtime_source.contains("func _get_suicide_drone_input_projectile_state("), "runtime should not keep suicide-drone input-state bridge")
	_expect(not runtime_source.contains("func _build_suicide_drone_detonation_result("), "runtime should not keep suicide-drone detonation-result bridge")
	_expect(not runtime_source.contains("func _get_drone_velocity("), "runtime should not keep suicide-drone homing velocity bridge")
	_expect(not runtime_source.contains("func _clamp_suicide_drone_projectile("), "runtime should not keep suicide-drone clamp bridge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
