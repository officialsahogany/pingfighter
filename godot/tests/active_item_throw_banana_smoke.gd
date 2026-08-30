extends SceneTree

const ActiveItemThrowBanana := preload("res://scripts/items/active_item_throw_banana.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(340.0, 25.0)
	var boss_vel := 3.0


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_banana_throw() -> void:
		calls.append("play_banana_throw")

	func play_banana_slip() -> void:
		calls.append("play_banana_slip")


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var runtime_perk_state: Object = null

	func _init(runtime_perk_state_value: Object = null) -> void:
		runtime_perk_state = runtime_perk_state_value

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


class FakePerkState:
	extends RefCounted

	var runtime_skill_levels := {"banana_master": 1}

	func get_runtime_skill_level(perk_id: String) -> int:
		return int(runtime_skill_levels.get(perk_id, 0))


func _init() -> void:
	_verify_helper_spawns_banana_projectile()
	_verify_banana_master_spawns_two_with_one_feedback_pair()
	_verify_banana_master_throw_and_landing_do_not_advance_global_rng()
	_verify_controller_windup_release_delegates_banana()
	_verify_bottom_launch_survives_fractional_frame()
	_verify_projectile_lands_banana()
	_verify_projectile_lands_at_target_x_without_left_overshoot()
	_verify_landed_banana_triggers_slip_and_particles()
	_verify_particle_and_slip_decay()

	if _failures.is_empty():
		print("active_item_throw_banana_n2_seal: banana_master=1 projectiles=2 helper_calls=1 audio_pair_calls=1 authority_rng_throw_landing_unchanged=1 burst_rng_independent=1")
		print("active_item_throw_banana_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_banana_projectile() -> void:
	var helper: Object = ActiveItemThrowBanana.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(377.5, controller.BANANA_LAND_Y),
	}

	helper.throw_banana(controller, FakeOwner.new(), pending_throw, registry)

	_expect(controller.get_banana_projectiles().size() == 1, "banana helper should append one projectile")
	var projectile: Dictionary = controller.get_banana_projectiles()[0]
	_expect(_get_vector2(projectile, "position") == Vector2(377.5, 695.0), "banana helper should preserve legacy start center")
	_expect(is_equal_approx(_get_vector2(projectile, "velocity").y, -controller.BANANA_THROW_SPEED_PER_FRAME), "banana helper should launch upward")
	_expect(_get_vector2(projectile, "target_position") == Vector2(377.5, controller.BANANA_LAND_Y), "banana helper should remember target landing point")
	_expect(_get_array(projectile, "trail").size() == 1, "banana helper should seed projectile trail")
	_expect(registry.audio.calls == ["play_throw", "play_banana_throw"], "banana helper should play throw audio pair")


func _verify_banana_master_spawns_two_with_one_feedback_pair() -> void:
	var helper: Object = ActiveItemThrowBanana.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new(FakePerkState.new())
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(330.0, controller.BANANA_LAND_Y),
	}

	helper.throw_banana(controller, FakeOwner.new(), pending_throw, registry)

	var projectiles: Array = controller.get_banana_projectiles()
	_expect(projectiles.size() == 2, "Banana Master must append exactly two projectiles from one throw release")
	_expect(registry.audio.calls == ["play_throw", "play_banana_throw"], "two Banana Master projectiles must keep one throw feedback pair")
	if projectiles.size() < 2:
		return
	_expect(
		_get_vector2(projectiles[0], "target_position")
		!= _get_vector2(projectiles[1], "target_position"),
		"Banana Master projectiles must remain independently visible instead of occupying one identical trajectory"
	)


func _verify_banana_master_throw_and_landing_do_not_advance_global_rng() -> void:
	const TEST_SEED := 0x2B4E414E
	seed(TEST_SEED)
	var expected_next := randf()
	seed(TEST_SEED)
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakePerkState.new())
	ActiveItemThrowBanana.new().throw_banana(
		controller,
		owner,
		{
			"start_position": Vector2(377.5, 695.0),
			"target_position": Vector2(380.0, controller.BANANA_LAND_Y),
		},
		registry
	)
	for _frame in range(80):
		controller._update_bananas(owner, registry, 1.0 / 60.0)
		if controller.get_banana_projectiles().is_empty() and controller.get_landed_bananas().is_empty():
			break
	_expect(controller.get_banana_projectiles().is_empty(), "Banana Master RNG seal must run through both projectile landings")
	_expect(controller.get_landed_bananas().is_empty(), "Banana Master RNG seal must run through both slip collisions")
	_expect(
		controller.get_banana_particles().size()
		== controller.BANANA_BURST_PARTICLE_COUNT * 2,
		"both Banana Master landings must create independent capped burst particles"
	)
	_expect(
		is_equal_approx(randf(), expected_next),
		"Banana Master throw, landing, and burst presentation must not advance the global gameplay RNG"
	)


func _verify_controller_windup_release_delegates_banana() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new(FakePerkState.new())
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "banana",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(377.5, controller.BANANA_LAND_Y),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), registry)

	_expect(controller.get_pending_throws().is_empty(), "banana windup release should clear pending queue")
	_expect(controller.get_banana_projectiles().size() == 2, "production windup release must route Banana Master into exactly two projectiles")
	_expect(registry.audio.calls == ["play_throw", "play_banana_throw"], "production Banana Master windup must keep one throw audio pair")


func _verify_bottom_launch_survives_fractional_frame() -> void:
	var helper: Object = ActiveItemThrowBanana.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(300.0, 700.0)
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 725.0),
		"target_position": Vector2(390.0, controller.BANANA_LAND_Y),
	}

	helper.throw_banana(controller, owner, pending_throw, registry)
	var start_pos: Vector2 = _get_vector2(controller.get_banana_projectiles()[0], "position")

	controller._update_banana_projectiles(registry, 0.25)

	_expect(controller.get_banana_projectiles().size() == 1, "bottom-launched banana should not be culled before it visibly rises")
	_expect(controller.get_landed_bananas().is_empty(), "bottom-launched banana should not instantly become a landed banana")
	if controller.get_banana_projectiles().is_empty():
		return
	var banana: Dictionary = controller.get_banana_projectiles()[0]
	var pos: Vector2 = _get_vector2(banana, "position")
	_expect(pos.y < start_pos.y, "bottom-launched banana should move upward during the first fractional frame")
	_expect(pos.y < controller.FIELD_HEIGHT, "bottom-launched banana should remain inside the visible playfield")


func _verify_projectile_lands_banana() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var projectiles: Array[Dictionary] = [{
		"position": Vector2(380.0, controller.BANANA_LAND_Y + 1.0),
		"velocity": Vector2(0.0, -2.0),
		"rotation_degrees": 0.0,
		"rotation_speed": 11.0,
		"trail": [Vector2(380.0, controller.BANANA_LAND_Y + 1.0)],
	}]
	controller.banana_projectiles = projectiles

	controller._update_banana_projectiles(registry, 1.0)

	_expect(controller.get_banana_projectiles().is_empty(), "banana projectile should be removed after landing")
	_expect(controller.get_landed_bananas().size() == 1, "banana projectile should create landed banana")
	var landed: Dictionary = controller.get_landed_bananas()[0]
	_expect(_get_vector2(landed, "position") == Vector2(380.0, controller.BANANA_LAND_Y), "landed banana should clamp to land y")
	_expect(is_equal_approx(float(landed.get("timer_frames", 0.0)), controller.BANANA_LAND_DURATION_FRAMES), "landed banana should start full duration")


func _verify_projectile_lands_at_target_x_without_left_overshoot() -> void:
	var helper: Object = ActiveItemThrowBanana.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var target_x := 330.0
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(target_x, controller.BANANA_LAND_Y),
	}

	helper.throw_banana(controller, FakeOwner.new(), pending_throw, registry)

	for _i in range(80):
		controller._update_banana_projectiles(registry, 1.0)
		if controller.get_banana_projectiles().is_empty():
			break

	_expect(controller.get_banana_projectiles().is_empty(), "targeted banana projectile should eventually land")
	_expect(controller.get_landed_bananas().size() == 1, "targeted banana projectile should create one landed banana")
	var landed: Dictionary = controller.get_landed_bananas()[0]
	var landed_pos: Vector2 = _get_vector2(landed, "position")
	_expect(is_equal_approx(landed_pos.x, target_x), "banana should land at target x instead of drifting into the left background")
	_expect(is_equal_approx(landed_pos.y, controller.BANANA_LAND_Y), "targeted banana should land on banana land y")


func _verify_landed_banana_triggers_slip_and_particles() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var landed: Array[Dictionary] = [{
		"position": Vector2(380.0, controller.BANANA_LAND_Y),
		"timer_frames": controller.BANANA_LAND_DURATION_FRAMES,
		"max_timer_frames": controller.BANANA_LAND_DURATION_FRAMES,
		"slip_triggered": false,
	}]
	controller.landed_bananas = landed

	controller._update_landed_bananas(FakeOwner.new(), registry, 1.0)

	_expect(controller.get_landed_bananas().is_empty(), "triggered landed banana should be consumed")
	_expect(is_equal_approx(controller.banana_boss_slip_timer_frames, controller.BANANA_SLIP_DURATION_FRAMES), "banana slip should latch full duration")
	_expect(is_equal_approx(controller.banana_boss_slip_direction, 1.0), "banana slip should use boss velocity direction")
	_expect(controller.get_banana_particles().size() == controller.BANANA_BURST_PARTICLE_COUNT, "banana slip should spawn burst particles")
	_expect(controller.BANANA_BURST_PARTICLE_COUNT <= 6, "banana slip burst should stay within the runtime particle budget")
	_expect(registry.audio.calls == ["play_banana_slip"], "banana slip should play slip audio")


func _verify_particle_and_slip_decay() -> void:
	var controller: Object = ActiveItemThrowController.new()
	controller._spawn_banana_burst_particles(Vector2(380.0, controller.BANANA_LAND_Y))
	var first_particle: Dictionary = controller.get_banana_particles()[0]
	var first_life: float = float(first_particle.get("life_frames", 0.0))

	controller._update_banana_particles(1.0 / 60.0)

	_expect(controller.get_banana_particles().size() == controller.BANANA_BURST_PARTICLE_COUNT, "fresh banana particles should remain after one frame")
	_expect(controller.get_banana_particles().size() <= controller.BANANA_PARTICLE_CAP, "banana particles should stay under the draw/update cap")
	_expect(float(controller.get_banana_particles()[0].get("life_frames", 0.0)) < first_life, "banana particles should age")

	controller.banana_boss_slip_timer_frames = 2.0
	controller.banana_boss_slip_direction = -1.0
	controller._update_banana_boss_slip(1.0 / 60.0)

	_expect(is_equal_approx(controller.banana_boss_slip_timer_frames, 1.0), "banana slip timer should decay by one frame")
	_expect(is_equal_approx(controller.banana_boss_slip_direction, -1.0), "banana slip direction should remain while timer is active")


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
