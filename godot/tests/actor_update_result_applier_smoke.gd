extends SceneTree

const ActorResultApplier := preload("res://scripts/core/battle_scene_actor_update_result_applier.gd")
const ActorUpdateDriver := preload("res://scripts/core/battle_scene_actor_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var gameplay_frame_counter := 12
	var player_pos := Vector2(100.0, 650.0)
	var player_speed := 4.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_scale := 1.0
	var optimus_energy_initialized := false
	var optimus_energy_ratio := 1.0
	var optimus_paddle_scale := 1.0
	var optimus_speed_multiplier := 1.0
	var optimus_charge_active := false
	var optimus_charge_hold_seconds := 0.0
	var optimus_charge_hold_ratio := 0.0
	var optimus_charge_lock_seconds := 0.0
	var optimus_charge_movement_locked := false
	var selected_character_type := "smasher"
	var special_gauge := 10.0
	var special_gauge_max := 500.0
	var ball_active := true
	var ball_pos := Vector2(300.0, 400.0)
	var ball_vel := Vector2(2.0, -3.0)
	var ball_impact_boost := 1.0
	var boss_pos := Vector2(360.0, 80.0)
	var boss_vel := 0.0
	var player_collision_cooldown := 0.0
	var runtime_perk_gold := 5


class FakeRuntimePerkState:
	extends RefCounted

	var gold := 7
	var awarded := 0

	func award_gold(amount: int) -> int:
		awarded += amount
		gold += amount
		return gold


class FakeContextBuilder:
	extends RefCounted

	func build_player_control_config(_character_type: String) -> Dictionary:
		return {
			"paddle_width": 155.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 10.0,
			"paddle_accel": 1.0,
			"paddle_decel": 1.0,
			"paddle_turn_decel": 2.0,
		}

	func build_player_control_deps(_registry: Object, _character_type: String) -> Dictionary:
		return {}

	func build_boss_ai_context(_owner: Object, _registry: Object) -> Dictionary:
		return {"boss_context": true}


class FakePlayerController:
	extends RefCounted

	var calls := 0

	func update(
		_delta: float,
		_frame_counter: int,
		_player_pos: Vector2,
		_player_speed: float,
		_config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		calls += 1
		return {
			"frame_counter": 44,
			"player_pos": Vector2(222.0, 660.0),
			"player_speed": 8.5,
		}


class FakeBossAiState:
	extends RefCounted

	var calls := 0

	func update(_delta: float, _boss_pos: Vector2, _boss_vel: float, context: Dictionary) -> Dictionary:
		calls += 1
		return {
			"boss_pos": Vector2(410.0, 90.0),
			"boss_vel": 3.5,
			"context_seen": bool(context.get("boss_context", false)),
		}


class FakeTrackingApplier:
	extends RefCounted

	var player_calls := 0
	var boss_calls := 0

	func apply_player_result(owner: Object, _registry: Object, result: Dictionary) -> void:
		player_calls += 1
		owner.set("gameplay_frame_counter", int(result.get("frame_counter", -1)))

	func apply_boss_result(owner: Object, result: Dictionary) -> void:
		boss_calls += 1
		owner.set("boss_vel", float(result.get("boss_vel", -1.0)))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_player_apply()
	_verify_optimus_paddle_resize_preserves_floor()
	_verify_direct_gold_fallback()
	_verify_direct_boss_apply()
	_verify_driver_uses_registered_applier()

	if _failures.is_empty():
		print("actor_update_result_applier_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_player_apply() -> void:
	var owner := FakeOwner.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime_perk_state
	var applier: Object = ActorResultApplier.new()

	applier.apply_player_result(owner, registry, {
		"frame_counter": 21,
		"player_pos": Vector2(140.0, 620.0),
		"player_speed": 7.25,
		"special_gauge": 45.0,
		"ball_pos": Vector2(330.0, 390.0),
		"ball_vel": Vector2(-4.0, 5.0),
		"ball_impact_boost": 1.35,
		"player_collision_cooldown": 0.4,
		"skill_gold_award": 3,
	})

	_expect(owner.gameplay_frame_counter == 21, "player result should update frame counter")
	_expect(owner.player_pos == Vector2(140.0, 620.0), "player result should update player position")
	_expect(abs(owner.player_speed - 7.25) <= 0.001, "player result should update player speed")
	_expect(abs(owner.special_gauge - 45.0) <= 0.001, "player result should update special gauge")
	_expect(owner.ball_pos == Vector2(330.0, 390.0), "player result should update ball position")
	_expect(owner.ball_vel == Vector2(-4.0, 5.0), "player result should update ball velocity")
	_expect(abs(owner.ball_impact_boost - 1.35) <= 0.001, "player result should update ball impact boost")
	_expect(abs(owner.player_collision_cooldown - 0.4) <= 0.001, "player result should update collision cooldown")
	_expect(runtime_perk_state.awarded == 3 and owner.runtime_perk_gold == 10, "skill gold award should route through runtime perk state")

	applier.apply_player_result(owner, registry, {
		"player_pos": "invalid",
		"ball_pos": "invalid",
		"ball_vel": "invalid",
		"runtime_perk_gold": 14,
	})
	_expect(owner.player_pos == Vector2(140.0, 620.0), "invalid player position should not overwrite owner")
	_expect(owner.ball_pos == Vector2(330.0, 390.0), "invalid ball position should not overwrite owner")
	_expect(owner.ball_vel == Vector2(-4.0, 5.0), "invalid ball velocity should not overwrite owner")
	_expect(owner.runtime_perk_gold == 14, "explicit runtime perk gold should overwrite owner when non-negative")


func _verify_optimus_paddle_resize_preserves_floor() -> void:
	var owner := FakeOwner.new()
	var applier: Object = ActorResultApplier.new()
	owner.selected_character_type = "optimus"
	owner.player_pos = Vector2(120.0, 603.0)
	owner.player_paddle_width = 296.0
	owner.player_paddle_height = 147.0

	applier.apply_player_result(owner, FakeRegistry.new(), {
		"player_pos": Vector2(130.0, 603.0),
		"runtime_paddle_base_width": 240.0,
		"runtime_paddle_base_height": 119.189,
		"player_paddle_width": 240.0,
		"player_paddle_height": 119.189,
		"player_paddle_scale": 240.0 / 155.0,
		"optimus_energy_initialized": true,
		"optimus_energy_ratio": 0.0,
		"optimus_paddle_scale": 240.0 / 296.0,
		"optimus_speed_multiplier": 0.25,
		"optimus_charge_active": true,
		"optimus_charge_hold_seconds": 0.6,
		"optimus_charge_hold_ratio": 1.0,
		"optimus_charge_lock_seconds": 0.0,
		"optimus_charge_movement_locked": true,
	})

	_expect(is_equal_approx(owner.runtime_paddle_base_width, 240.0), "result applier should store Optimus runtime base width")
	_expect(is_equal_approx(owner.runtime_paddle_base_height, 119.189), "result applier should store Optimus runtime base height")
	_expect(is_equal_approx(owner.player_paddle_width, 240.0), "result applier should apply Optimus paddle width")
	_expect(is_equal_approx(owner.player_paddle_height, 119.189), "result applier should apply Optimus paddle height")
	_expect(is_equal_approx(owner.player_pos.y + owner.player_paddle_height, 750.0), "Optimus paddle resize should stay floor aligned")
	_expect(owner.optimus_energy_initialized, "result applier should mark Optimus energy initialized")
	_expect(is_equal_approx(owner.optimus_speed_multiplier, 0.25), "result applier should store Optimus speed multiplier")
	_expect(owner.optimus_charge_active and owner.optimus_charge_movement_locked, "result applier should store Optimus manual charge flags")
	_expect(is_equal_approx(owner.optimus_charge_hold_ratio, 1.0), "result applier should store Optimus manual charge hold ratio")


func _verify_direct_gold_fallback() -> void:
	var owner := FakeOwner.new()
	var applier: Object = ActorResultApplier.new()
	applier.apply_player_result(owner, FakeRegistry.new(), {"skill_gold_award": 4})
	_expect(owner.runtime_perk_gold == 9, "skill gold award should fall back to owner counter without runtime perk state")


func _verify_direct_boss_apply() -> void:
	var owner := FakeOwner.new()
	var applier: Object = ActorResultApplier.new()
	applier.apply_boss_result(owner, {
		"boss_pos": Vector2(500.0, 110.0),
		"boss_vel": -2.5,
	})
	_expect(owner.boss_pos == Vector2(500.0, 110.0), "boss result should update boss position")
	_expect(abs(owner.boss_vel + 2.5) <= 0.001, "boss result should update boss velocity")
	applier.apply_boss_result(owner, {"boss_pos": "invalid"})
	_expect(owner.boss_pos == Vector2(500.0, 110.0), "invalid boss position should not overwrite owner")


func _verify_driver_uses_registered_applier() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var player_controller := FakePlayerController.new()
	var boss_ai_state := FakeBossAiState.new()
	var tracking_applier := FakeTrackingApplier.new()
	registry.instances = {
		"battle_update_context": FakeContextBuilder.new(),
		"smasher_player_controller": player_controller,
		"boss_ai_state": boss_ai_state,
		"battle_scene_actor_update_result_applier": tracking_applier,
	}
	var driver: Object = ActorUpdateDriver.new()

	driver.update_player_control(owner, registry, 0.1)
	driver.update_boss_ai(owner, registry, 0.2)

	_expect(player_controller.calls == 1 and tracking_applier.player_calls == 1, "driver should route player result through registered applier")
	_expect(owner.gameplay_frame_counter == 44, "registered player applier should mutate owner")
	_expect(boss_ai_state.calls == 1 and tracking_applier.boss_calls == 1, "driver should route boss result through registered applier")
	_expect(abs(owner.boss_vel - 3.5) <= 0.001, "registered boss applier should mutate owner")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
