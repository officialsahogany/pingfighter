extends SceneTree

const PlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const ActorUpdateDriver := preload("res://scripts/core/battle_scene_actor_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var gameplay_frame_counter := 3
	var selected_character_type := "smasher"
	var player_pos := Vector2(220.0, 640.0)
	var player_speed := 5.0
	var player_paddle_width := 180.0
	var player_paddle_height := 60.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_scale := 1.0
	var optimus_energy_initialized := false
	var special_gauge := 123.0
	var special_gauge_max := 600.0
	var ball_active := true
	var ball_pos := Vector2(315.0, 410.0)
	var ball_vel := Vector2(3.0, -4.0)
	var ball_size := 36.0
	var ball_impact_boost := 1.4
	var boss_pos := Vector2(345.0, 80.0)


class FakeMultiplier:
	extends RefCounted

	var multiplier := 1.0

	func _init(next_multiplier: float) -> void:
		multiplier = next_multiplier

	func get_player_speed_multiplier() -> float:
		return multiplier


class FakeOptimusEnergyState:
	extends RefCounted

	var prepare_calls := 0

	func prepare_owner_for_optimus(owner: Object) -> Dictionary:
		prepare_calls += 1
		owner.set("special_gauge", 500.0)
		owner.set("special_gauge_max", 500.0)
		return {
			"runtime_paddle_base_width": 296.0,
			"runtime_paddle_base_height": 147.0,
			"player_paddle_width": 296.0,
			"player_paddle_height": 147.0,
			"player_paddle_scale": 296.0 / 155.0,
			"optimus_energy_initialized": true,
		}


class FakeContextBuilder:
	extends RefCounted

	var config_character := ""
	var deps_character := ""

	func build_player_control_config(character_type: String = "smasher") -> Dictionary:
		config_character = character_type
		return {
			"paddle_width": 155.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 10.0,
			"paddle_accel": 2.0,
			"paddle_decel": 3.0,
			"paddle_turn_decel": 4.0,
		}

	func build_player_control_deps(_registry: Object, character_type: String = "smasher") -> Dictionary:
		deps_character = character_type
		return {}


class FakePlayerController:
	extends RefCounted

	var received_config: Dictionary = {}
	var calls := 0

	func update(
		_delta: float,
		_frame_counter: int,
		_player_pos: Vector2,
		_player_speed: float,
		config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		calls += 1
		received_config = config.duplicate()
		return {}


class FakeResultApplier:
	extends RefCounted

	var calls := 0

	func apply_player_result(_owner: Object, _registry: Object, _result: Dictionary) -> void:
		calls += 1

	func apply_boss_result(_owner: Object, _result: Dictionary) -> void:
		pass


class FakeTrackingConfigBuilder:
	extends RefCounted

	var calls := 0

	func build_config(_owner: Object, _registry: Object, _character_type: String, _context_builder: Object) -> Dictionary:
		calls += 1
		return {
			"custom_config": true,
			"paddle_speed": 42.0,
		}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_config_builder()
	_verify_optimus_config_prepares_energy()
	_verify_viper_skips_smasher_recovery()
	_verify_driver_uses_registered_config_builder()

	if _failures.is_empty():
		print("player_control_config_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_config_builder() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": FakeMultiplier.new(1.5),
		"smasher_recovery_state": FakeMultiplier.new(1.2),
		"active_item_runtime": FakeMultiplier.new(2.0),
		"lingpet_egg_runtime": FakeMultiplier.new(1.1),
		"mythic_item_runtime": FakeMultiplier.new(0.5),
	}
	var context_builder := FakeContextBuilder.new()
	var builder: Object = PlayerControlConfigBuilder.new()
	var config: Dictionary = builder.build_config(owner, registry, "smasher", context_builder)

	_expect(context_builder.config_character == "smasher", "config builder should request base config for character")
	_expect(str(config.get("selected_character_type", "")) == "smasher", "config builder should expose selected character type")
	_expect(float(config.get("paddle_width", 0.0)) == 180.0, "config builder should use live owner paddle width")
	_expect(float(config.get("paddle_height", 0.0)) == 60.0, "config builder should use live owner paddle height")
	_expect(float(config.get("player_floor_y", 0.0)) == 690.0, "config builder should derive floor from live paddle height")
	_expect(float(config.get("special_gauge", 0.0)) == 123.0, "config builder should copy special gauge")
	_expect(float(config.get("gauge_max", 0.0)) == 600.0, "config builder should copy max gauge")
	_expect(bool(config.get("ball_active", false)), "config builder should copy ball active flag")
	_expect(config.get("ball_pos", Vector2.ZERO) == Vector2(315.0, 410.0), "config builder should copy ball position")
	_expect(config.get("ball_vel", Vector2.ZERO) == Vector2(3.0, -4.0), "config builder should copy ball velocity")
	_expect_close(float(config.get("ball_size", 0.0)), 36.0, "config builder should copy live ball size for trajectory prediction")
	_expect(abs(float(config.get("ball_impact_boost", 0.0)) - 1.4) <= 0.001, "config builder should copy impact boost")
	_expect(config.get("boss_pos", Vector2.ZERO) == Vector2(345.0, 80.0), "config builder should copy boss position")
	_expect_close(float(config.get("boss_paddle_width", 0.0)), 100.0, "config builder should expose boss paddle width")
	_expect_close(float(config.get("boss_hitbox_height", 0.0)), 40.0, "config builder should expose boss hitbox height")
	_expect_close(float(config.get("boss_visual_center_y_offset", 0.0)), 25.0, "config builder should expose Stage 1 boss visual center offset")
	_expect(float(config.get("width", 0.0)) == 760.0 and float(config.get("height", 0.0)) == 750.0, "config builder should set playfield dimensions")
	_expect_close(float(config.get("paddle_speed", 0.0)), 11.88, "Smasher speed should include runtime, recovery, active, lingpet, and mythic multipliers")
	_expect_close(float(config.get("paddle_max_speed", 0.0)), 19.8, "Smasher max speed should include all speed multipliers")
	_expect_close(float(config.get("paddle_accel", 0.0)), 3.96, "Smasher acceleration should include all speed multipliers")
	_expect_close(float(config.get("paddle_decel", 0.0)), 5.94, "Smasher deceleration should include all speed multipliers")
	_expect_close(float(config.get("paddle_turn_decel", 0.0)), 7.92, "Smasher turn deceleration should include all speed multipliers")


func _verify_optimus_config_prepares_energy() -> void:
	var owner := FakeOwner.new()
	owner.selected_character_type = "optimus"
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0
	owner.player_pos = Vector2(302.5, 700.0)
	var optimus_energy_state := FakeOptimusEnergyState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"optimus_energy_state": optimus_energy_state,
	}
	var builder: Object = PlayerControlConfigBuilder.new()
	var context_builder := FakeContextBuilder.new()
	var config: Dictionary = builder.build_config(owner, registry, " IO ", context_builder)

	_expect(context_builder.config_character == "optimus", "Optimus alias should request normalized base config")
	_expect(str(config.get("selected_character_type", "")) == "optimus", "Optimus alias should expose normalized character type")
	_expect(optimus_energy_state.prepare_calls == 1, "Optimus config should prepare energy state")
	_expect_close(owner.player_paddle_width, 296.0, "Optimus config should apply energy paddle width to owner")
	_expect_close(owner.player_paddle_height, 147.0, "Optimus config should apply energy paddle height to owner")
	_expect_close(owner.runtime_paddle_base_width, 296.0, "Optimus config should apply runtime base width")
	_expect_close(owner.runtime_paddle_base_height, 147.0, "Optimus config should apply runtime base height")
	_expect_close(owner.player_pos.y + owner.player_paddle_height, 750.0, "Optimus config should floor-align prepared paddle")
	_expect_close(float(config.get("paddle_width", 0.0)), 296.0, "Optimus config should expose prepared paddle width")
	_expect_close(float(config.get("paddle_height", 0.0)), 147.0, "Optimus config should expose prepared paddle height")
	_expect_close(float(config.get("player_floor_y", 0.0)), 603.0, "Optimus config should derive floor from prepared height")
	_expect_close(float(config.get("special_gauge", 0.0)), 500.0, "Optimus config should expose initialized gauge")


func _verify_viper_skips_smasher_recovery() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": FakeMultiplier.new(1.5),
		"smasher_recovery_state": FakeMultiplier.new(10.0),
		"active_item_runtime": FakeMultiplier.new(2.0),
		"mythic_item_runtime": FakeMultiplier.new(0.5),
	}
	var builder: Object = PlayerControlConfigBuilder.new()
	var context_builder := FakeContextBuilder.new()
	var config: Dictionary = builder.build_config(owner, registry, " VIPER ", context_builder)
	_expect(context_builder.config_character == "viper", "Viper alias should request normalized base config")
	_expect(str(config.get("selected_character_type", "")) == "viper", "config builder should preserve non-Smasher character type")
	_expect_close(float(config.get("paddle_speed", 0.0)), 9.0, "Viper speed should skip Smasher recovery multiplier")


func _verify_driver_uses_registered_config_builder() -> void:
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var player_controller := FakePlayerController.new()
	var config_builder := FakeTrackingConfigBuilder.new()
	var result_applier := FakeResultApplier.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"battle_update_context": context_builder,
		"smasher_player_controller": player_controller,
		"battle_scene_player_control_config_builder": config_builder,
		"battle_scene_actor_update_result_applier": result_applier,
	}
	var driver: Object = ActorUpdateDriver.new()
	driver.update_player_control(owner, registry, 0.1)

	_expect(config_builder.calls == 1, "actor driver should route player config through registered builder")
	_expect(player_controller.calls == 1, "actor driver should call player controller")
	_expect(bool(player_controller.received_config.get("custom_config", false)), "player controller should receive registered builder config")
	_expect(result_applier.calls == 1, "actor driver should still apply controller result")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.001, message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
