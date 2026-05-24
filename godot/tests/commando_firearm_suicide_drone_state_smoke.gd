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


class FakeActiveItemRuntime:
	extends RefCounted

	var molotov_fire_zone_calls: Array = []

	func trigger_molotov_fire_zone(
		center: Vector2,
		_owner: Object = null,
		_registry: Object = null,
		play_feedback_audio: bool = true
	) -> void:
		molotov_fire_zone_calls.append({
			"center": center,
			"play_feedback_audio": play_feedback_audio,
		})


class FakeImpactEffects:
	extends RefCounted

	var particles: Array = []

	func spawn_hit_particles(pos: Vector2, color: Color, velocity: Vector2, intensity: float, speed: float) -> void:
		particles.append({
			"pos": pos,
			"color": color,
			"velocity": velocity,
			"intensity": intensity,
			"speed": speed,
		})


class FakeFeedback:
	extends RefCounted

	var calls: Array = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		calls.append({"amount": amount, "intensity": intensity})


class FakeBallEffects:
	extends RefCounted

	var pulses: Array = []

	func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float, kind: String) -> void:
		pulses.append({
			"pos": pos,
			"velocity": velocity,
			"intensity": intensity,
			"kind": kind,
		})


class FakeAudio:
	extends RefCounted

	var impact_calls: Array[String] = []
	var stop_calls := 0

	func play_commando_suicide_drone_explosion() -> void:
		impact_calls.append("suicide_drone_explosion")

	func stop_commando_suicide_drone_loop() -> void:
		stop_calls += 1


class FakeRuntimeOwner:
	extends RefCounted

	var suicide_drone_cooldown_frames := 0.0
	var boss_hits: Array = []
	var lingering_calls: Array = []

	func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
		boss_hits.append({
			"projectile": projectile,
			"context": context,
			"deps": deps,
		})

	func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
		lingering_calls.append({
			"weapon_id": weapon_id,
			"projectile": projectile,
			"context": context,
		})
		return {"source": "fake_lingering"}


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
	var appended_projectiles: Array = []
	var appended_flashes: Array = []
	var appended: Dictionary = CommandoFirearmSuicideDroneState.append_spawn_effects(
		appended_projectiles,
		appended_flashes,
		{"player_pos": Vector2(100.0, 680.0), "boss_pos": Vector2(330.0, 60.0)},
		profile,
		17,
		760.0,
		750.0,
		Vector2(48.0, 48.0),
		14.0,
		1.2,
		3600.0,
		6.0,
		18.0,
		4,
		3
	)
	_expect(appended_projectiles.size() == 1, "spawn append helper should append one suicide-drone projectile")
	_expect(appended_flashes.size() == 1, "spawn append helper should append one suicide-drone muzzle flash")
	_expect(int(appended.get("id", 0)) == 17, "spawn append helper should preserve the runtime shot id")

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
	_expect(
		CommandoFirearmSuicideDroneState.resolve_runtime_collision(
			{"manual_control": false, "pos": Vector2(100.0, 100.0)},
			1.0,
			{},
			Vector2(760.0, 750.0),
			Vector2(48.0, 48.0),
			18.0,
			760.0
		).is_empty(),
		"runtime collision helper should ignore non-manual projectiles"
	)
	var grace_collision: Dictionary = CommandoFirearmSuicideDroneState.resolve_runtime_collision(
		projectile,
		1.0,
		{"ball_pos": Vector2(100.0, 200.0)},
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0),
		18.0,
		760.0
	)
	_expect(str(grace_collision.get("reason", "pending")) == "", "runtime collision helper should wait out grace frames")
	var ball_collision_projectile: Dictionary = projectile.duplicate(true)
	ball_collision_projectile["grace_timer_frames"] = 0.0
	ball_collision_projectile["pos"] = Vector2(100.0, 200.0)
	var ball_collision: Dictionary = CommandoFirearmSuicideDroneState.resolve_runtime_collision(
		ball_collision_projectile,
		1.0,
		{"ball_pos": Vector2(100.0, 200.0), "ball_size": 28.6},
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0),
		18.0,
		760.0
	)
	_expect(str(ball_collision.get("reason", "")) == "ball_hit", "runtime collision helper should report ball contact")
	var boss_collision_projectile: Dictionary = projectile.duplicate(true)
	boss_collision_projectile["grace_timer_frames"] = 0.0
	boss_collision_projectile["pos"] = Vector2(350.0, 70.0)
	var boss_collision: Dictionary = CommandoFirearmSuicideDroneState.resolve_runtime_collision(
		boss_collision_projectile,
		1.0,
		{"ball_active": false, "boss_pos": Vector2(330.0, 50.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0},
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0),
		18.0,
		760.0
	)
	_expect(str(boss_collision.get("reason", "")) == "boss_hit", "runtime collision helper should report boss body contact")
	var wall_collision_projectile: Dictionary = projectile.duplicate(true)
	wall_collision_projectile["grace_timer_frames"] = 0.0
	wall_collision_projectile["pos"] = Vector2(100.0, 20.0)
	var wall_collision: Dictionary = CommandoFirearmSuicideDroneState.resolve_runtime_collision(
		wall_collision_projectile,
		1.0,
		{"ball_active": false, "boss_pos": Vector2(330.0, 50.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0},
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0),
		18.0,
		760.0
	)
	_expect(str(wall_collision.get("reason", "")) == "boss_back_wall", "runtime collision helper should report top-wall contact")
	var expired_collision_projectile: Dictionary = projectile.duplicate(true)
	expired_collision_projectile["grace_timer_frames"] = 0.0
	expired_collision_projectile["life_frames"] = 0.0
	expired_collision_projectile["pos"] = Vector2(100.0, 300.0)
	var expired_collision: Dictionary = CommandoFirearmSuicideDroneState.resolve_runtime_collision(
		expired_collision_projectile,
		1.0,
		{"ball_active": false, "boss_pos": Vector2(330.0, 50.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0},
		Vector2(760.0, 750.0),
		Vector2(48.0, 48.0),
		18.0,
		760.0
	)
	_expect(str(expired_collision.get("reason", "")) == "expired", "runtime collision helper should report expired drones")
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
	var detonation_flashes: Array = []
	CommandoFirearmSuicideDroneState.append_runtime_detonation_flash(
		detonation_flashes,
		projectile,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		24.0,
		3
	)
	_expect(detonation_flashes.size() == 1, "detonation flash helper should append one impact flash")
	_expect(str((detonation_flashes[0] as Dictionary).get("weapon_id", "")) == "suicide_drone", "detonation flash helper should preserve suicide-drone weapon id")
	var boss_context := {
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var boss_blast_projectile: Dictionary = projectile.duplicate(true)
	boss_blast_projectile["pos"] = Vector2(350.0, 70.0)
	_expect(
		CommandoFirearmSuicideDroneState.explosion_hits_runtime_boss(
			boss_blast_projectile,
			boss_context,
			CommandoFirearmRuntime.WEAPON_PROFILES,
			CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
			CommandoFirearmRuntime.FIELD_WIDTH
		),
		"runtime explosion helper should detect boss overlap"
	)
	var miss_projectile: Dictionary = projectile.duplicate(true)
	miss_projectile["pos"] = Vector2(20.0, 700.0)
	_expect(
		not CommandoFirearmSuicideDroneState.explosion_hits_runtime_boss(
			miss_projectile,
			boss_context,
			CommandoFirearmRuntime.WEAPON_PROFILES,
			CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
			CommandoFirearmRuntime.FIELD_WIDTH
		),
		"runtime explosion helper should reject distant blasts"
	)
	var impact_effects := FakeImpactEffects.new()
	var feedback := FakeFeedback.new()
	var ball_effects := FakeBallEffects.new()
	var audio := FakeAudio.new()
	CommandoFirearmSuicideDroneState.dispatch_miss_detonation_feedback(
		projectile,
		{
			"impact_effects": impact_effects,
			"feedback": feedback,
			"ball_effects": ball_effects,
			"audio": audio,
		},
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID
	)
	_expect(impact_effects.particles.size() == 1, "miss detonation helper should spawn impact particles")
	_expect(feedback.calls.size() == 1, "miss detonation helper should trigger hit feedback")
	_expect(ball_effects.pulses.size() == 1, "miss detonation helper should register a ball-hit pulse")
	_expect(audio.impact_calls == ["suicide_drone_explosion"], "miss detonation helper should play suicide-drone impact audio")
	var runtime_detonation: Dictionary = CommandoFirearmSuicideDroneState.build_runtime_detonation_result(
		"ball_hit",
		Vector2(3.0, 4.0),
		false,
		90.0,
		projectile,
		{"ball_vel": Vector2(0.0, -9.0), "ball_base_speed": 8.0},
		3.0,
		12.0
	)
	_expect(bool(runtime_detonation.get("commando_suicide_drone_detonated", false)), "runtime detonation result should preserve base detonation flag")
	_expect(bool(runtime_detonation.get("commando_suicide_drone_ball_boosted", false)), "runtime detonation result should merge ball boost metadata for ball hits")
	var detonation_owner := FakeRuntimeOwner.new()
	var detonation_impact_effects := FakeImpactEffects.new()
	var detonation_feedback := FakeFeedback.new()
	var detonation_ball_effects := FakeBallEffects.new()
	var detonation_audio := FakeAudio.new()
	var runtime_detonation_flashes: Array = []
	var miss_runtime_result: Dictionary = CommandoFirearmSuicideDroneState.detonate_runtime_projectile(
		runtime_detonation_flashes,
		detonation_owner,
		miss_projectile,
		"expired",
		boss_context,
		{
			"impact_effects": detonation_impact_effects,
			"feedback": detonation_feedback,
			"ball_effects": detonation_ball_effects,
			"audio": detonation_audio,
		},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.FIELD_WIDTH,
		90.0,
		3.0,
		12.0,
		24.0,
		4
	)
	_expect(not bool(miss_runtime_result.get("commando_suicide_drone_hit_boss", true)), "runtime detonation helper should report miss blasts")
	_expect(runtime_detonation_flashes.size() == 1, "runtime detonation helper should append a detonation flash")
	_expect(detonation_owner.lingering_calls.size() == 1, "runtime detonation helper should spawn miss lingering residue")
	_expect(is_equal_approx(detonation_owner.suicide_drone_cooldown_frames, 90.0), "runtime detonation helper should store cooldown on owner")
	_expect(detonation_impact_effects.particles.size() == 1, "runtime detonation helper should spawn miss particles")
	_expect(detonation_feedback.calls.size() == 1, "runtime detonation helper should trigger miss feedback")
	_expect(detonation_ball_effects.pulses.size() == 1, "runtime detonation helper should register miss ball pulse")
	_expect(detonation_audio.impact_calls == ["suicide_drone_explosion"], "runtime detonation helper should play explosion audio")
	_expect(detonation_audio.stop_calls == 1, "runtime detonation helper should stop suicide-drone loop audio")
	var boss_detonation_owner := FakeRuntimeOwner.new()
	var boss_runtime_result: Dictionary = CommandoFirearmSuicideDroneState.detonate_runtime_projectile(
		[],
		boss_detonation_owner,
		boss_blast_projectile,
		"boss_hit",
		boss_context,
		{},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.FIELD_WIDTH,
		90.0,
		3.0,
		12.0,
		24.0,
		4
	)
	_expect(bool(boss_runtime_result.get("commando_suicide_drone_hit_boss", false)), "runtime detonation helper should report boss-hit blasts")
	_expect(boss_detonation_owner.boss_hits.size() == 1, "runtime detonation helper should route boss-hit blasts through owner")
	var active_item_runtime := FakeActiveItemRuntime.new()
	var fire_zone_result: Dictionary = CommandoFirearmSuicideDroneState.trigger_active_item_fire_zone(
		{"pos": Vector2(11.0, 22.0)},
		{"active_item_runtime": active_item_runtime}
	)
	_expect(str(fire_zone_result.get("source", "")) == "active_item_molotov_fire_zone", "active-item fire-zone helper should expose the molotov source")
	_expect(active_item_runtime.molotov_fire_zone_calls.size() == 1, "active-item fire-zone helper should trigger one molotov zone")
	_expect((active_item_runtime.molotov_fire_zone_calls[0] as Dictionary).get("center", Vector2.ZERO) == Vector2(11.0, 22.0), "active-item fire-zone helper should use the projectile position")
	_expect(not bool((active_item_runtime.molotov_fire_zone_calls[0] as Dictionary).get("play_feedback_audio", true)), "active-item fire-zone helper should suppress duplicate molotov feedback audio")
	_expect(CommandoFirearmSuicideDroneState.trigger_active_item_fire_zone({"pos": Vector2(11.0, 22.0)}, {}).is_empty(), "active-item fire-zone helper should return empty without an active item runtime")


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

	var detonation_result: Dictionary = CommandoFirearmSuicideDroneState.detonate_runtime_projectile_at_index(
		runtime.projectiles,
		0,
		runtime.impact_flashes,
		runtime,
		steered,
		"manual",
		config,
		{},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.FIELD_WIDTH,
		CommandoFirearmRuntime.SUICIDE_DRONE_COOLDOWN_FRAMES,
		CommandoFirearmRuntime.SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
		CommandoFirearmRuntime.SUICIDE_DRONE_BALL_FAN_DEGREES,
		24.0,
		CommandoFirearmRuntime.FLASH_LIMIT
	)
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
	_expect(not runtime_source.contains("func _spawn_suicide_drone("), "runtime should not keep suicide-drone spawn append bridge")
	_expect(not runtime_source.contains("func _apply_suicide_drone_input_to_projectile("), "runtime should not keep suicide-drone input mutation bridge")
	_expect(not runtime_source.contains("func _get_suicide_drone_input_projectile_state("), "runtime should not keep suicide-drone input-state bridge")
	_expect(not runtime_source.contains("func _build_suicide_drone_detonation_result("), "runtime should not keep suicide-drone detonation-result bridge")
	_expect(not runtime_source.contains("func _get_drone_velocity("), "runtime should not keep suicide-drone homing velocity bridge")
	_expect(not runtime_source.contains("func _clamp_suicide_drone_projectile("), "runtime should not keep suicide-drone clamp bridge")
	_expect(not runtime_source.contains("func _spawn_suicide_drone_fire_zone("), "runtime should not keep suicide-drone fire-zone bridge")
	_expect(not runtime_source.contains("func _resolve_suicide_drone_collision("), "runtime should not keep suicide-drone collision bridge")
	_expect(not runtime_source.contains("func _detonate_suicide_drone_at_index("), "runtime should not keep suicide-drone detonation-at-index bridge")
	_expect(not runtime_source.contains("CommandoFirearmSuicideDroneGeometry"), "runtime should not directly depend on suicide-drone geometry")
	_expect(runtime_source.contains("CommandoFirearmSuicideDroneState.resolve_runtime_collision_at_index"), "runtime should delegate suicide-drone collision reason resolution to state owner")
	_expect(runtime_source.contains("CommandoFirearmSuicideDroneState.detonate_runtime_projectile_at_index"), "runtime should delegate suicide-drone detonation orchestration to state owner")
	_expect(not runtime_source.contains("CommandoFirearmSuicideDroneState.append_runtime_detonation_flash"), "runtime should not call lower-level suicide-drone detonation flash append directly")
	_expect(not runtime_source.contains("CommandoFirearmSuicideDroneState.explosion_hits_runtime_boss"), "runtime should not call lower-level suicide-drone explosion boss tests directly")
	_expect(not runtime_source.contains("CommandoFirearmSuicideDroneState.dispatch_miss_detonation_feedback"), "runtime should not call lower-level suicide-drone miss feedback directly")
	_expect(not runtime_source.contains("CommandoFirearmSuicideDroneState.build_runtime_detonation_result"), "runtime should not assemble suicide-drone detonation results directly")
	_expect(not runtime_source.contains("CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result"), "runtime should not build suicide-drone ball boost results inline")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
