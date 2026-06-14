extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowSoap := preload("res://scripts/items/active_item_throw_soap.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(340.0, 25.0)


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_soap_throw() -> void:
		calls.append("play_soap_throw")

	func play_soap_land() -> void:
		calls.append("play_soap_land")

	func play_soap_slip() -> void:
		calls.append("play_soap_slip")


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_helper_spawns_soap_projectile()
	_verify_controller_windup_release_delegates_soap()
	_verify_bottom_launch_survives_fractional_frame()
	_verify_projectile_lands_soap()
	_verify_projectile_lands_at_target_x_without_left_overshoot()
	_verify_landed_soap_triggers_debuff_and_particles()
	_verify_particles_foam_and_debuff_decay()

	if _failures.is_empty():
		print("active_item_throw_soap_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_soap_projectile() -> void:
	var helper: Object = ActiveItemThrowSoap.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(377.5, controller.SOAP_LAND_Y),
	}

	helper.throw_soap(controller, FakeOwner.new(), pending_throw, registry)

	_expect(controller.get_soap_projectiles().size() == 1, "soap helper should append one projectile")
	var projectile: Dictionary = controller.get_soap_projectiles()[0]
	_expect(_get_vector2(projectile, "position") == Vector2(377.5, 695.0), "soap helper should preserve legacy start center")
	_expect(is_equal_approx(_get_vector2(projectile, "velocity").y, -controller.SOAP_THROW_SPEED_PER_FRAME), "soap helper should launch upward")
	_expect(_get_vector2(projectile, "target_position") == Vector2(377.5, controller.SOAP_LAND_Y), "soap helper should remember target landing point")
	_expect(_get_array(projectile, "trail").size() == 1, "soap helper should seed projectile trail")
	_expect(registry.audio.calls == ["play_throw", "play_soap_throw"], "soap helper should play throw audio pair")


func _verify_controller_windup_release_delegates_soap() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "soap",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(377.5, controller.SOAP_LAND_Y),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), registry)

	_expect(controller.get_pending_throws().is_empty(), "soap windup release should clear pending queue")
	_expect(controller.get_soap_projectiles().size() == 1, "soap windup release should spawn projectile")
	_expect(registry.audio.calls == ["play_throw", "play_soap_throw"], "soap windup release should play throw audio pair")


func _verify_bottom_launch_survives_fractional_frame() -> void:
	var helper: Object = ActiveItemThrowSoap.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(300.0, 700.0)
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 725.0),
		"target_position": Vector2(390.0, controller.SOAP_LAND_Y),
	}

	helper.throw_soap(controller, owner, pending_throw, registry)
	var start_pos: Vector2 = _get_vector2(controller.get_soap_projectiles()[0], "position")

	controller._update_soap_projectiles(registry, 0.25)

	_expect(controller.get_soap_projectiles().size() == 1, "bottom-launched soap should not be culled before it visibly rises")
	_expect(controller.get_landed_soaps().is_empty(), "bottom-launched soap should not instantly become a landed soap")
	if controller.get_soap_projectiles().is_empty():
		return
	var soap: Dictionary = controller.get_soap_projectiles()[0]
	var pos: Vector2 = _get_vector2(soap, "position")
	_expect(pos.y < start_pos.y, "bottom-launched soap should move upward during the first fractional frame")
	_expect(pos.y < controller.FIELD_HEIGHT, "bottom-launched soap should remain inside the visible playfield")


func _verify_projectile_lands_soap() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var projectiles: Array[Dictionary] = [{
		"position": Vector2(380.0, controller.SOAP_LAND_Y + 1.0),
		"velocity": Vector2(0.0, -2.0),
		"rotation_degrees": 0.0,
		"rotation_speed": 7.0,
		"trail": [Vector2(380.0, controller.SOAP_LAND_Y + 1.0)],
	}]
	controller.soap_projectiles = projectiles

	controller._update_soap_projectiles(registry, 1.0)

	_expect(controller.get_soap_projectiles().is_empty(), "soap projectile should be removed after landing")
	_expect(controller.get_landed_soaps().size() == 1, "soap projectile should create landed soap")
	var landed: Dictionary = controller.get_landed_soaps()[0]
	_expect(_get_vector2(landed, "position") == Vector2(380.0, controller.SOAP_LAND_Y), "landed soap should clamp to land y")
	_expect(is_equal_approx(float(landed.get("timer_frames", 0.0)), controller.SOAP_LAND_DURATION_FRAMES), "landed soap should start full duration")
	_expect(registry.audio.calls == ["play_soap_land"], "soap landing should play landing audio")


func _verify_projectile_lands_at_target_x_without_left_overshoot() -> void:
	var helper: Object = ActiveItemThrowSoap.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var target_x := 330.0
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(target_x, controller.SOAP_LAND_Y),
	}

	helper.throw_soap(controller, FakeOwner.new(), pending_throw, registry)

	for _i in range(80):
		controller._update_soap_projectiles(registry, 1.0)
		if controller.get_soap_projectiles().is_empty():
			break

	_expect(controller.get_soap_projectiles().is_empty(), "targeted soap projectile should eventually land")
	_expect(controller.get_landed_soaps().size() == 1, "targeted soap projectile should create one landed soap")
	var landed: Dictionary = controller.get_landed_soaps()[0]
	var landed_pos: Vector2 = _get_vector2(landed, "position")
	_expect(is_equal_approx(landed_pos.x, target_x), "soap should land at target x instead of drifting into the left background")
	_expect(is_equal_approx(landed_pos.y, controller.SOAP_LAND_Y), "targeted soap should land on soap land y")


func _verify_landed_soap_triggers_debuff_and_particles() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var landed: Array[Dictionary] = [{
		"position": Vector2(380.0, controller.SOAP_LAND_Y),
		"timer_frames": controller.SOAP_LAND_DURATION_FRAMES,
		"max_timer_frames": controller.SOAP_LAND_DURATION_FRAMES,
		"triggered": false,
		"wobble_phase": 0.0,
	}]
	controller.landed_soaps = landed
	controller.soap_foam_spawn_timer_frames = 5.0

	controller._update_landed_soaps(FakeOwner.new(), registry, 1.0)

	_expect(controller.get_landed_soaps().is_empty(), "triggered landed soap should be consumed")
	_expect(is_equal_approx(controller.soap_boss_slip_timer_frames, controller.SOAP_DEBUFF_DURATION_FRAMES), "soap debuff should latch full duration")
	_expect(is_equal_approx(controller.soap_foam_spawn_timer_frames, 0.0), "soap debuff should reset foam timer")
	_expect(controller.get_soap_particles().size() == controller.SOAP_BURST_PARTICLE_COUNT, "soap debuff should spawn burst particles")
	_expect(registry.audio.calls == ["play_soap_slip"], "soap debuff should play slip audio")


func _verify_particles_foam_and_debuff_decay() -> void:
	var controller: Object = ActiveItemThrowController.new()
	controller._spawn_soap_burst_particles(Vector2(380.0, controller.SOAP_LAND_Y))
	var first_particle: Dictionary = controller.get_soap_particles()[0]
	var first_age: float = float(first_particle.get("age", 0.0))

	controller._update_soap_particles(1.0 / 60.0)

	_expect(controller.get_soap_particles().size() == controller.SOAP_BURST_PARTICLE_COUNT, "fresh soap particles should remain after one frame")
	_expect(float(controller.get_soap_particles()[0].get("age", 0.0)) > first_age, "soap particles should age")

	controller.soap_boss_slip_timer_frames = 10.0
	controller.soap_foam_spawn_timer_frames = controller.SOAP_FOAM_SPAWN_INTERVAL_FRAMES - 1.0
	controller._update_soap_boss_slip(FakeOwner.new(), 1.0 / 60.0)

	_expect(is_equal_approx(controller.soap_boss_slip_timer_frames, 9.0), "soap debuff timer should decay by one frame")
	_expect(controller.get_soap_foam_trails().size() == 1, "soap debuff should spawn a foam trail on interval")
	var foam: Dictionary = controller.get_soap_foam_trails()[0]
	var foam_life: float = float(foam.get("life_frames", 0.0))
	controller._update_soap_foam_trails(1.0 / 60.0)
	_expect(float(controller.get_soap_foam_trails()[0].get("life_frames", 0.0)) < foam_life, "soap foam trails should age")


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
