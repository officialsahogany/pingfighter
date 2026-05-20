extends SceneTree

const ActorResultApplier := preload("res://scripts/core/battle_scene_actor_update_result_applier.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const FIREARM_SKILLS := [
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
	"bazooka",
	"ak47",
	"commando_pistol",
]

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeOwner:
	extends RefCounted

	var gameplay_frame_counter := 0
	var player_pos := Vector2(100.0, 650.0)
	var player_speed := 0.0
	var special_gauge := 500.0
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_impact_boost := 1.0
	var player_collision_cooldown := 0.0
	var runtime_perk_gold := 0


class FakeRuntimePerkState:
	extends RefCounted

	var gold := 0
	var awarded := 0

	func award_gold(amount: int) -> int:
		awarded += amount
		gold += amount
		return gold


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_config_policy_matches_python_reference()
	_verify_supply_drop_awards_once_through_common_path()
	_verify_zero_gold_commando_actions_do_not_award()

	if _failures.is_empty():
		print("commando_skill_gold_policy_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_config_policy_matches_python_reference() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	_expect(skill_config.get_skill_gold_reward("supply_drop") == 96, "supply_drop should keep Python cooldown-based skill gold")
	_expect(skill_config.calculate_skill_gold_reward("supply_drop") == 96, "compat reward helper should mirror get_skill_gold_reward")
	_expect(skill_config.get_skill_gold_reward("emergency_supply") == 0, "emergency_supply should not award skill gold")
	for skill_name in FIREARM_SKILLS:
		_expect(skill_config.get_skill_gold_reward(str(skill_name)) == 0, "%s should not award skill-use gold" % str(skill_name))

	skill_config.set_runtime_cooldown_multiplier(0.25)
	skill_config.set_item_cooldown_multiplier(0.5)
	_expect(is_equal_approx(skill_config.get_cooldown_seconds("supply_drop"), 5.0), "cooldown multipliers should still affect runtime cooldown")
	_expect(skill_config.get_skill_gold_reward("supply_drop") == 96, "skill gold should use base cooldown, not modified cooldown")

	var snapshot: Dictionary = skill_config.get_snapshot()
	var rewards: Dictionary = snapshot.get("skill_gold_rewards", {})
	_expect(int(rewards.get("supply_drop", 0)) == 96, "snapshot should expose supply_drop skill gold")
	_expect(int(rewards.get("emergency_supply", -1)) == 0, "snapshot should expose zero emergency_supply skill gold")


func _verify_supply_drop_awards_once_through_common_path() -> void:
	var setup: Dictionary = _build_controller_setup()
	var controller: Object = setup.get("controller", null)
	var input_reader: Object = setup.get("input_reader", null)
	var skill_state: Object = setup.get("skill_state", null)
	var skill_config: Object = setup.get("skill_config", null)
	input_reader.snapshot = {
		"down_pressed": true,
		"action_pressed": false,
	}

	var result: Dictionary = controller.update(
		1.0,
		7,
		Vector2(100.0, 650.0),
		0.0,
		_base_player_config(),
		setup.get("deps", {})
	)
	_expect(bool(result.get("skill_gold_award", 0) == 96), "supply_drop should emit one common skill_gold_award")
	_expect(not result.has("runtime_perk_gold"), "supply_drop should not directly write runtime_perk_gold")
	_expect(is_equal_approx(float(result.get("special_gauge", 0.0)), 150.0), "supply_drop should spend its configured gauge cost")
	_expect(
		skill_state.get_configured_cooldown_remaining("supply_drop", Time.get_ticks_msec(), skill_config) > 0.0,
		"supply_drop activation should trigger its configured cooldown"
	)

	var owner := FakeOwner.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime_perk_state
	var applier: Object = ActorResultApplier.new()
	applier.apply_player_result(owner, registry, result)
	_expect(runtime_perk_state.awarded == 96, "common applier should award supply_drop gold exactly once")
	_expect(owner.runtime_perk_gold == 96, "owner runtime perk gold should reflect the one common award")


func _verify_zero_gold_commando_actions_do_not_award() -> void:
	var setup: Dictionary = _build_controller_setup()
	var skill_config: Object = setup.get("skill_config", null)
	var weapon_controller: Object = setup.get("weapon_controller", null)
	var input_reader: Object = setup.get("input_reader", null)
	var controller: Object = setup.get("controller", null)
	var deps: Dictionary = setup.get("deps", {})

	_expect(bool(skill_config.unlock_and_equip_skill("bazooka")), "test setup should equip bazooka skill")
	weapon_controller.sync_equipped_permanent(skill_config)
	weapon_controller.prepare_stage_start(1, true)
	_expect(bool(weapon_controller.set_current_weapon("bazooka")), "test setup should select bazooka")
	deps["commando_firearm_runtime"] = CommandoFirearmRuntime.new()
	input_reader.snapshot = {
		"action_pressed": true,
	}

	var result: Dictionary = controller.update(
		0.1,
		12,
		Vector2(100.0, 650.0),
		0.0,
		_base_player_config(),
		deps
	)
	_expect(not result.has("skill_gold_award") or int(result.get("skill_gold_award", 0)) == 0, "permanent firearm fire should not award skill gold")
	_expect(not result.has("runtime_perk_gold"), "permanent firearm fire should not directly write runtime_perk_gold")

	var owner := FakeOwner.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime_perk_state
	var applier: Object = ActorResultApplier.new()
	applier.apply_player_result(owner, registry, result)
	_expect(runtime_perk_state.awarded == 0, "zero-gold firearm action should not call the common gold award")
	_expect(owner.runtime_perk_gold == 0, "zero-gold firearm action should leave owner gold unchanged")


func _build_controller_setup() -> Dictionary:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var input_reader := FakeInputReader.new()
	var deps := {
		"input_reader": input_reader,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"commando_supply_drop_state": supply_state,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [
			{"type": "field_item", "item_id": "gauge_charge"},
		],
	}
	return {
		"controller": CommandoPlayerController.new(),
		"input_reader": input_reader,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"supply_state": supply_state,
		"weapon_controller": weapon_controller,
		"deps": deps,
	}


func _base_player_config() -> Dictionary:
	return {
		"special_gauge": 500.0,
		"current_stage": 1,
		"paddle_width": 88.0,
		"paddle_height": 40.0,
		"paddle_speed": 6.0,
		"paddle_max_speed": 10.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(360.0, 300.0),
		"ball_vel": Vector2.ZERO,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
