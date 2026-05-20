extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowDynamite := preload("res://scripts/items/active_item_throw_dynamite.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []
	var stopped_fuses: Array = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_dynamite_fuse() -> Variant:
		calls.append("play_dynamite_fuse")
		return "fuse-token"

	func stop_dynamite_fuse(fuse_player: Variant) -> void:
		calls.append("stop_dynamite_fuse")
		stopped_fuses.append(fuse_player)

	func play_dynamite_explosion() -> void:
		calls.append("play_dynamite_explosion")

	func play_grenade_explosion() -> void:
		calls.append("play_grenade_explosion")


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "battle_feedback_state":
			return feedback
		return null


func _init() -> void:
	_verify_helper_spawns_dynamite_projectile()
	_verify_controller_windup_release_delegates_dynamite()
	_verify_projectile_lands_as_placed_dynamite()
	_verify_projectile_places_at_target_x_without_left_overshoot()
	_verify_placed_dynamite_explodes_and_updates_boss_effect()
	_verify_dynamite_boss_effect_uses_boss_center()
	_verify_round_end_detonates_counting_dynamite()
	_verify_explosion_update_lifecycle()

	if _failures.is_empty():
		print("active_item_throw_dynamite_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_dynamite_projectile() -> void:
	var helper: Object = ActiveItemThrowDynamite.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(390.0, controller.DYNAMITE_LAND_Y),
	}

	helper.throw_dynamite(controller, owner, pending_throw, registry)

	_expect(controller.get_dynamites().size() == 1, "dynamite helper should append one projectile")
	var dynamite: Dictionary = controller.get_dynamites()[0]
	_expect(_get_vector2(dynamite, "position") == Vector2(377.5, 695.0), "dynamite helper should preserve legacy start center")
	_expect(is_equal_approx(abs(_get_vector2(dynamite, "velocity").y), controller.DYNAMITE_THROW_SPEED_PER_FRAME), "dynamite helper should launch upward with controller speed")
	_expect(_get_vector2(dynamite, "target_position") == Vector2(390.0, controller.DYNAMITE_LAND_Y), "dynamite helper should remember target placement point")
	_expect(_get_array(dynamite, "trail").size() == 1, "dynamite helper should seed a projectile trail")
	_expect(registry.audio.calls == ["play_throw"], "dynamite helper should play throw audio")


func _verify_controller_windup_release_delegates_dynamite() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "dynamite",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(390.0, controller.DYNAMITE_LAND_Y),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), registry)

	_expect(controller.get_pending_throws().is_empty(), "dynamite windup release should clear pending queue")
	_expect(controller.get_dynamites().size() == 1, "dynamite windup release should spawn projectile")
	_expect(registry.audio.calls == ["play_throw"], "dynamite windup release should play throw audio")


func _verify_projectile_lands_as_placed_dynamite() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var dynamites: Array[Dictionary] = [{
		"position": Vector2(390.0, controller.DYNAMITE_LAND_Y - 1.0),
		"velocity": Vector2.ZERO,
		"rotation_degrees": 0.0,
		"rotation_speed": 10.0,
		"trail": [Vector2(390.0, controller.DYNAMITE_LAND_Y - 1.0)],
	}]
	controller.dynamites = dynamites

	controller._update_dynamite_projectiles(registry, 1.0)

	_expect(controller.get_dynamites().is_empty(), "landed projectile should be removed")
	_expect(controller.get_placed_dynamites().size() == 1, "landed projectile should become placed dynamite")
	var placed: Dictionary = controller.get_placed_dynamites()[0]
	_expect(is_equal_approx(float(placed.get("countdown_frames", 0.0)), controller.DYNAMITE_COUNTDOWN_FRAMES), "placed dynamite should start full countdown")
	_expect(registry.audio.calls == ["play_dynamite_fuse"], "placed dynamite should start fuse audio")


func _verify_projectile_places_at_target_x_without_left_overshoot() -> void:
	var helper: Object = ActiveItemThrowDynamite.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var target_x := 330.0
	var pending_throw := {
		"start_position": Vector2(377.5, 695.0),
		"target_position": Vector2(target_x, controller.DYNAMITE_LAND_Y),
	}

	helper.throw_dynamite(controller, owner, pending_throw, registry)

	for _i in range(90):
		controller._update_dynamite_projectiles(registry, 1.0)
		if controller.get_dynamites().is_empty():
			break

	_expect(controller.get_dynamites().is_empty(), "targeted dynamite projectile should eventually place")
	_expect(controller.get_placed_dynamites().size() == 1, "targeted dynamite projectile should create one placed dynamite")
	var placed: Dictionary = controller.get_placed_dynamites()[0]
	var placed_pos: Vector2 = _get_vector2(placed, "position")
	_expect(is_equal_approx(placed_pos.x, target_x), "dynamite should place at target x instead of drifting into the left background")
	_expect(placed_pos.y >= controller.DYNAMITE_PLACED_MIN_Y and placed_pos.y <= controller.DYNAMITE_PLACED_MAX_Y, "targeted dynamite should keep its normal placed y range")


func _verify_placed_dynamite_explodes_and_updates_boss_effect() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var placed_dynamites: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"countdown_frames": 1.0,
		"max_countdown_frames": controller.DYNAMITE_COUNTDOWN_FRAMES,
		"pulse_timer": 0.0,
		"nudge_vx": 0.0,
		"wobble_angle": 0.0,
		"wobble_vel": 0.0,
		"fuse_player": "fuse-token",
	}]
	controller.placed_dynamites = placed_dynamites

	controller._update_placed_dynamites(owner, registry, 2.0)

	_expect(controller.get_placed_dynamites().is_empty(), "expired placed dynamite should be removed")
	_expect(controller.get_dynamite_explosions().size() == 1, "expired placed dynamite should create explosion")
	var explosion: Dictionary = controller.get_dynamite_explosions()[0]
	_expect(_get_array(explosion, "particles").size() == controller.DYNAMITE_EXPLOSION_FIRE_PARTICLE_COUNT, "explosion should seed fire particles")
	_expect(_get_array(explosion, "sparks").size() == controller.DYNAMITE_EXPLOSION_SPARK_COUNT, "explosion should seed sparks")
	_expect(_get_array(explosion, "smoke_clouds").size() == controller.DYNAMITE_EXPLOSION_SMOKE_CLOUD_COUNT, "explosion should seed smoke clouds")
	_expect(controller.grenade_boss_stun_timer_frames >= controller.DYNAMITE_BOSS_STUN_FRAMES, "dynamite explosion should apply boss stun")
	_expect(controller.grenade_boss_knockback_timer_frames >= controller.DYNAMITE_BOSS_KNOCKBACK_FRAMES, "dynamite explosion should apply boss knockback")
	_expect(registry.audio.calls == ["stop_dynamite_fuse", "play_dynamite_explosion"], "explosion should stop fuse then play explosion audio")
	_expect(registry.audio.stopped_fuses == ["fuse-token"], "explosion should stop the original fuse player")
	_expect(registry.feedback.shakes.size() == 1, "explosion should request screen shake")


func _verify_dynamite_boss_effect_uses_boss_center() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(350.0, 55.0)
	var registry := FakeRegistry.new()

	controller._trigger_dynamite_explosion(owner, registry, Vector2(40.0, 75.0))

	_expect(controller.get_dynamite_explosions().size() == 1, "edge-only dynamite should still create explosion visuals")
	_expect(controller.grenade_boss_stun_timer_frames <= 0.0, "edge-only dynamite should not stun when the boss center is outside radius")
	_expect(controller.grenade_boss_knockback_timer_frames <= 0.0, "edge-only dynamite should not knock back when the boss center is outside radius")


func _verify_round_end_detonates_counting_dynamite() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var placed_dynamites: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"countdown_frames": controller.DYNAMITE_COUNTDOWN_FRAMES * 0.5,
		"max_countdown_frames": controller.DYNAMITE_COUNTDOWN_FRAMES,
		"pulse_timer": 0.0,
		"nudge_vx": 0.0,
		"wobble_angle": 0.0,
		"wobble_vel": 0.0,
		"fuse_player": "round-end-fuse-token",
	}]
	controller.placed_dynamites = placed_dynamites

	var detonated_count: int = controller.detonate_placed_dynamites_on_round_end(owner, registry)

	_expect(detonated_count == 1, "round end should detonate one counting dynamite")
	_expect(controller.get_placed_dynamites().is_empty(), "round-end detonation should remove placed dynamites")
	_expect(controller.get_dynamite_explosions().size() == 1, "round-end detonation should create explosion")
	_expect(registry.audio.calls == ["stop_dynamite_fuse", "play_dynamite_explosion"], "round-end detonation should stop fuse then play explosion")
	_expect(registry.audio.stopped_fuses == ["round-end-fuse-token"], "round-end detonation should stop the counting fuse token")


func _verify_explosion_update_lifecycle() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	controller._trigger_dynamite_explosion(owner, registry, Vector2(380.0, 75.0))
	var timer_before: float = float(controller.get_dynamite_explosions()[0].get("timer_frames", 0.0))

	controller._update_dynamite_explosions(1.0 / 60.0)

	_expect(controller.get_dynamite_explosions().size() == 1, "fresh explosion should remain alive after one frame")
	var explosion: Dictionary = controller.get_dynamite_explosions()[0]
	_expect(float(explosion.get("timer_frames", 0.0)) < timer_before, "explosion timer should tick down")
	_expect(float(explosion.get("shockwave_radius", 0.0)) > 0.0, "explosion shockwave should expand")
	_expect(float(explosion.get("progress", 0.0)) > 0.0, "explosion progress should increase")


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
