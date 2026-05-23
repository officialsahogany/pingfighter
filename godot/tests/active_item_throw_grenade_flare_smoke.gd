extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowGrenadeFlare := preload("res://scripts/items/active_item_throw_grenade_flare.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_grenade_explosion() -> void:
		calls.append("play_grenade_explosion")

	func play_flashbomb() -> void:
		calls.append("play_flashbomb")


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var stage2_state: Object = null

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "battle_feedback_state":
			return feedback
		if key == "stage2_boss_skill_state":
			return stage2_state
		return null


class FakeStage2State:
	extends RefCounted

	func is_boss_status_immune() -> bool:
		return true


func _init() -> void:
	_verify_helper_spawns_grenade_and_flare()
	_verify_helper_owns_grenade_flare_impact_status()
	_verify_radial_boss_effects_use_boss_center()
	_verify_radial_effects_clamp_away_from_pillars()
	_verify_controller_grenade_update_delegates_explosion()
	_verify_controller_flare_update_delegates_flash()

	if _failures.is_empty():
		print("active_item_throw_grenade_flare_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_grenade_and_flare() -> void:
	var helper: Object = ActiveItemThrowGrenadeFlare.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 705.0),
		"target_position": Vector2(380.0, 75.0),
	}

	helper.throw_grenade(controller, owner, pending_throw, registry)
	_expect(controller.get_grenades().size() == 1, "grenade helper should append one projectile")
	var grenade: Dictionary = controller.get_grenades()[0]
	_expect(_get_vector2(grenade, "position") == Vector2(377.5, 705.0), "grenade helper should preserve legacy start center")
	_expect(_get_vector2(grenade, "target_position") == Vector2(380.0, 75.0), "grenade helper should preserve target")
	_expect(
		is_equal_approx(_get_vector2(grenade, "velocity").length(), controller.GRENADE_SPEED_PER_FRAME),
		"grenade helper should launch with controller speed"
	)
	_expect(registry.audio.calls == ["play_throw"], "grenade helper should play throw audio")

	helper.throw_flare(controller, owner, pending_throw, registry)
	_expect(controller.get_flares().size() == 1, "flare helper should append one projectile")
	var flare: Dictionary = controller.get_flares()[0]
	_expect(_get_vector2(flare, "position") == Vector2(377.5, 705.0), "flare helper should preserve legacy start center")
	_expect(_get_vector2(flare, "target_position") == Vector2(380.0, 75.0), "flare helper should preserve target")
	_expect(
		is_equal_approx(_get_vector2(flare, "velocity").length(), controller.FLARE_SPEED_PER_FRAME),
		"flare helper should launch with controller speed"
	)
	_expect(not bool(flare.get("arrived", true)), "flare helper should start in flight")
	_expect(not bool(flare.get("exploded", true)), "flare helper should start unexploded")
	_expect(registry.audio.calls == ["play_throw", "play_throw"], "flare helper should play throw audio")


func _verify_helper_owns_grenade_flare_impact_status() -> void:
	var helper: Object = ActiveItemThrowGrenadeFlare.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	helper.trigger_grenade_explosion(controller, owner, registry, Vector2(380.0, 75.0))

	_expect(controller.get_explosion_zones().size() == 1, "grenade helper should create explosion zone")
	_expect(is_equal_approx(controller.grenade_boss_stun_timer_frames, controller.GRENADE_BOSS_STUN_FRAMES), "grenade helper should apply boss stun")
	_expect(is_equal_approx(controller.grenade_boss_knockback_timer_frames, controller.GRENADE_BOSS_KNOCKBACK_FRAMES), "grenade helper should apply boss knockback")
	_expect(is_equal_approx(controller.grenade_boss_knockback_vel, controller.GRENADE_BOSS_KNOCKBACK_POWER), "grenade helper should apply knockback direction")
	_expect(registry.audio.calls == ["play_grenade_explosion"], "grenade helper should play explosion audio")
	_expect(
		registry.feedback.shakes == [Vector2(controller.GRENADE_SCREEN_SHAKE_AMOUNT, controller.GRENADE_SCREEN_SHAKE_INTENSITY)],
		"grenade helper should request Python-parity explosion shake"
	)
	_expect(
		is_equal_approx(controller.GRENADE_SCREEN_SHAKE_AMOUNT, 40.0 / 30.0),
		"grenade explosion shake should preserve the original 40-frame decay"
	)
	_expect(
		is_equal_approx(controller.GRENADE_SCREEN_SHAKE_AMOUNT * controller.GRENADE_SCREEN_SHAKE_INTENSITY, 12.0),
		"grenade explosion shake should start near the original 12px horizontal offset"
	)

	helper.update_explosion_zones(controller, 1.0 / 60.0)
	_expect(
		is_equal_approx(float(controller.get_explosion_zones()[0].get("duration_frames", 0.0)), controller.GRENADE_EXPLOSION_DURATION_FRAMES - 1.0),
		"grenade helper should age explosion zones"
	)
	helper.update_grenade_boss_effect(controller, 1.0 / 60.0)
	_expect(
		is_equal_approx(controller.grenade_boss_stun_timer_frames, controller.GRENADE_BOSS_STUN_FRAMES - 1.0),
		"grenade helper should decay stun timer"
	)

	helper.trigger_flare_flash(controller, owner, registry, Vector2(380.0, 75.0))

	_expect(controller.get_flare_zones().size() == 1, "flare helper should create flash zone")
	_expect(is_equal_approx(controller.flare_boss_confused_timer_frames, controller.FLARE_BOSS_CONFUSION_FRAMES), "flare helper should apply confusion")
	_expect(registry.audio.calls == ["play_grenade_explosion", "play_flashbomb"], "flare helper should play flash audio")
	helper.update_flare_zones(controller, 1.0 / 60.0)
	_expect(
		is_equal_approx(float(controller.get_flare_zones()[0].get("duration_frames", 0.0)), controller.FLARE_ZONE_DURATION_FRAMES - 1.0),
		"flare helper should age flash zones"
	)
	helper.update_flare_boss_confusion(controller, 1.0 / 60.0)
	_expect(
		is_equal_approx(controller.flare_boss_confused_timer_frames, controller.FLARE_BOSS_CONFUSION_FRAMES - 1.0),
		"flare helper should decay confusion timer"
	)

	registry.stage2_state = FakeStage2State.new()
	helper.clear_boss_disable_effects_if_stage2_speed_defense(controller, registry)

	_expect(controller.grenade_boss_stun_timer_frames <= 0.0, "grenade helper should clear stun for stage2 speed defense")
	_expect(controller.grenade_boss_knockback_timer_frames <= 0.0, "grenade helper should clear knockback timer for stage2 speed defense")
	_expect(abs(controller.grenade_boss_knockback_vel) <= 0.01, "grenade helper should clear knockback velocity for stage2 speed defense")
	_expect(controller.flare_boss_confused_timer_frames <= 0.0, "grenade helper should clear flare confusion for stage2 speed defense")


func _verify_radial_boss_effects_use_boss_center() -> void:
	var helper: Object = ActiveItemThrowGrenadeFlare.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(350.0, 55.0)

	var grenade_controller: Object = ActiveItemThrowController.new()
	var grenade_registry := FakeRegistry.new()
	helper.trigger_grenade_explosion(grenade_controller, owner, grenade_registry, Vector2(200.0, 75.0))
	_expect(grenade_controller.get_explosion_zones().size() == 1, "edge-only grenade should still create its explosion zone")
	_expect(grenade_controller.grenade_boss_stun_timer_frames <= 0.0, "edge-only grenade should not stun when the boss center is outside radius")
	_expect(grenade_controller.grenade_boss_knockback_timer_frames <= 0.0, "edge-only grenade should not knock back when the boss center is outside radius")

	var flare_controller: Object = ActiveItemThrowController.new()
	var flare_registry := FakeRegistry.new()
	helper.trigger_flare_flash(flare_controller, owner, flare_registry, Vector2(210.0, 75.0))
	_expect(flare_controller.get_flare_zones().size() == 1, "edge-only flare should still create its flash zone")
	_expect(flare_controller.flare_boss_confused_timer_frames <= 0.0, "edge-only flare should not confuse when the boss center is outside radius")


func _verify_radial_effects_clamp_away_from_pillars() -> void:
	var helper: Object = ActiveItemThrowGrenadeFlare.new()
	var owner := FakeOwner.new()

	var grenade_controller: Object = ActiveItemThrowController.new()
	var grenade_registry := FakeRegistry.new()
	helper.trigger_grenade_explosion(grenade_controller, owner, grenade_registry, Vector2(8.0, 75.0))
	_expect(grenade_controller.get_explosion_zones().size() == 1, "left-edge grenade should create one explosion zone")
	_expect(
		_get_vector2(grenade_controller.get_explosion_zones()[0], "position").x == grenade_controller.GRENADE_EXPLOSION_RADIUS,
		"left-edge grenade explosion should keep its full blast inside the playfield"
	)

	var flare_controller: Object = ActiveItemThrowController.new()
	var flare_registry := FakeRegistry.new()
	helper.trigger_flare_flash(flare_controller, owner, flare_registry, Vector2(8.0, 75.0))
	_expect(flare_controller.get_flare_zones().size() == 1, "left-edge flare should create one flash zone")
	_expect(
		_get_vector2(flare_controller.get_flare_zones()[0], "position").x == flare_controller.FLARE_RADIUS,
		"left-edge flare flash should keep its full glow inside the playfield"
	)


func _verify_controller_grenade_update_delegates_explosion() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var grenades: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"velocity": Vector2.ZERO,
		"target_position": Vector2(380.0, 75.0),
		"rotation_degrees": 0.0,
		"trail": [Vector2(380.0, 75.0)],
	}]
	controller.grenades = grenades

	controller._update_grenades(owner, registry, 1.0 / 60.0)

	_expect(controller.get_grenades().is_empty(), "grenade update should remove exploded projectile")
	_expect(controller.get_explosion_zones().size() == 1, "grenade update should trigger explosion zone")
	_expect(controller.grenade_boss_stun_timer_frames > 0.0, "grenade update should apply boss stun")
	_expect(controller.grenade_boss_knockback_timer_frames > 0.0, "grenade update should apply boss knockback")
	_expect(registry.audio.calls == ["play_grenade_explosion"], "grenade update should play explosion audio")
	_expect(registry.feedback.shakes.size() == 1, "grenade update should request screen shake")


func _verify_controller_flare_update_delegates_flash() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var flares: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"velocity": Vector2.ZERO,
		"target_position": Vector2(380.0, 75.0),
		"rotation_degrees": 0.0,
		"timer_frames": controller.FLARE_ARMED_DELAY_FRAMES,
		"exploded": false,
		"arrived": true,
		"trail": [Vector2(380.0, 75.0)],
	}]
	controller.flares = flares

	controller._update_flares(owner, registry, 1.0 / 60.0)

	_expect(controller.get_flares().is_empty(), "flare update should remove flashed projectile")
	_expect(controller.get_flare_zones().size() == 1, "flare update should trigger flash zone")
	_expect(controller.flare_boss_confused_timer_frames > 0.0, "flare update should apply boss confusion")
	_expect(registry.audio.calls == ["play_flashbomb"], "flare update should play flash audio")


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
