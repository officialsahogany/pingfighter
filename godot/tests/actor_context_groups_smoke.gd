extends SceneTree

const BattleUpdateActorContext := preload("res://scripts/core/battle_update_actor_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 2
	var ai_mode := "champion"
	var ball_active := true
	var player_pos := Vector2(200.0, 690.0)
	var ball_pos := Vector2(320.0, 410.0)
	var ball_vel := Vector2(7.0, -3.0)
	var ball_impact_boost := 1.25
	var ball_boost_decay_rate := 0.97
	var ball_min_boost := 0.65
	var selected_character_type := "viper"


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false

	func does_player_serve() -> bool:
		return true


class FakePowerState:
	extends RefCounted

	func is_parabola_active() -> bool:
		return true

	func get_combo_consumed() -> int:
		return 2


class FakeWhipState:
	extends RefCounted

	func get_ai_context() -> Dictionary:
		return {"whip_marker": true}


class FakeBossContextSource:
	extends RefCounted

	var marker: String

	func _init(next_marker: String) -> void:
		marker = next_marker

	func get_boss_ai_context() -> Dictionary:
		return {marker: true}


class FakeStage2SkillState:
	extends RefCounted

	var expected_background: Object

	func _init(background: Object) -> void:
		expected_background = background

	func get_boss_ai_context(stage_background: Object = null) -> Dictionary:
		return {
			"stage2_skill_marker": true,
			"stage2_background_ok": stage_background == expected_background,
		}


class FakeStageBackground:
	extends RefCounted

	func get_boss_ai_context() -> Dictionary:
		return {"stage_background_marker": true}


class FakeStageRouter:
	extends RefCounted

	func get_instance(registry: Object, current_stage: int, role: String) -> Object:
		if current_stage == 2 and role == "stage_background":
			return registry.get_instance("stage2_pillar_background")
		return null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		for key in [
			"smasher_input_reader",
			"viper_input_reader",
			"smasher_dash_state",
			"smasher_drive_input_state",
			"smasher_skill_state",
			"viper_skill_state",
			"smasher_skill_config",
			"viper_skill_config",
			"viper_skill_runtime",
			"viper_jetpack_state",
			"smasher_power_smash_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"player_movement_state",
			"smasher_combo_state",
			"runtime_perk_state",
			"orb_hud_state",
			"active_item_runtime",
			"round_flow_state",
			"game_audio",
			"battle_feedback_state",
			"mythic_item_runtime",
			"stage1_dalji_whip_skill_state",
			"stage2_pillar_background",
		]:
			instances[key] = RefCounted.new()
		instances["round_flow_state"] = FakeRoundState.new()
		instances["smasher_power_smash_state"] = FakePowerState.new()
		instances["stage1_dalji_whip_skill_state"] = FakeWhipState.new()
		instances["active_item_runtime"] = FakeBossContextSource.new("active_item_marker")
		instances["mythic_item_runtime"] = FakeBossContextSource.new("mythic_item_marker")
		instances["smasher_plasma_state"] = FakeBossContextSource.new("plasma_marker")
		instances["viper_skill_runtime"] = FakeBossContextSource.new("viper_marker")
		instances["stage2_pillar_background"] = FakeStageBackground.new()
		instances["stage2_boss_skill_state"] = FakeStage2SkillState.new(instances["stage2_pillar_background"])
		instances["stage_runtime_router"] = FakeStageRouter.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var context: Object = BattleUpdateActorContext.new()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()

	var smasher_config: Dictionary = context.build_player_control_config("smasher")
	var viper_config: Dictionary = context.build_player_control_config("viper")
	_expect(float(smasher_config.get("paddle_speed", 0.0)) == 6.0, "Smasher config should keep base speed")
	_expect(float(viper_config.get("paddle_speed", 0.0)) == 4.0, "Viper config should keep base speed")

	var smasher_deps: Dictionary = context.build_player_control_deps(registry, "smasher")
	_expect(smasher_deps.get("input_reader", null) == registry.instances["smasher_input_reader"], "Smasher deps should use Smasher input reader")
	_expect(smasher_deps.get("drive_input_state", null) == registry.instances["smasher_drive_input_state"], "Smasher deps should include Drive input")
	_expect(smasher_deps.get("combo_state", null) == registry.instances["smasher_combo_state"], "Smasher deps should include combo state")
	_expect(smasher_deps.get("viper_skill_runtime", null) == null, "Smasher deps should not include Viper runtime")
	_expect(smasher_deps.get("active_item_runtime", null) == registry.instances["active_item_runtime"], "Smasher deps should include active item runtime")

	var viper_deps: Dictionary = context.build_player_control_deps(registry, "viper")
	_expect(viper_deps.get("input_reader", null) == registry.instances["viper_input_reader"], "Viper deps should use Viper input reader")
	_expect(viper_deps.get("drive_input_state", null) == null, "Viper deps should not include Smasher Drive input")
	_expect(viper_deps.get("combo_state", null) == null, "Viper deps should not include Smasher combo state")
	_expect(viper_deps.get("viper_skill_runtime", null) == registry.instances["viper_skill_runtime"], "Viper deps should include Viper runtime")
	_expect(viper_deps.get("power_state", null) == null, "Viper deps should not include Smasher power state")

	var boss_context: Dictionary = context.build_boss_ai_context(owner, registry)
	_expect(int(boss_context.get("current_stage", 0)) == 2, "boss context should keep current stage")
	_expect(not bool(boss_context.get("waiting_for_serve", true)), "boss context should read round wait state")
	_expect(bool(boss_context.get("player_serves", false)), "boss context should read serving side")
	_expect(not bool(boss_context.get("power_smashing_parabola_active", false)), "Viper boss context should skip Smasher power state")
	_expect(int(boss_context.get("power_smashing_combo_consumed", 0)) == 0, "Viper boss context should expose zero power combo count")
	_expect(not bool(boss_context.get("whip_marker", false)), "Stage 2 boss context should skip Stage 1 whip AI context")
	_expect(bool(boss_context.get("active_item_marker", false)), "boss context should merge active item AI context")
	_expect(bool(boss_context.get("mythic_item_marker", false)), "boss context should merge mythic item AI context")
	_expect(not bool(boss_context.get("plasma_marker", false)), "Viper boss context should skip Smasher plasma AI context")
	_expect(bool(boss_context.get("stage2_skill_marker", false)), "boss context should merge Stage 2 skill AI context")
	_expect(bool(boss_context.get("stage2_background_ok", false)), "Stage 2 skill context should receive routed background")
	_expect(bool(boss_context.get("viper_marker", false)), "Viper boss context should merge Viper runtime AI context")

	owner.selected_character_type = "smasher"
	var smasher_boss_context: Dictionary = context.build_boss_ai_context(owner, registry)
	_expect(bool(smasher_boss_context.get("power_smashing_parabola_active", false)), "Smasher boss context should include power smash state")
	_expect(int(smasher_boss_context.get("power_smashing_combo_consumed", 0)) == 2, "Smasher boss context should include power combo count")
	_expect(bool(smasher_boss_context.get("plasma_marker", false)), "Smasher boss context should merge plasma AI context")
	_expect(not bool(smasher_boss_context.get("viper_marker", false)), "Smasher boss context should skip Viper runtime AI context")

	registry.instances.erase("stage2_boss_skill_state")
	var stage_fallback_context: Dictionary = context.build_boss_ai_context(owner, registry)
	_expect(bool(stage_fallback_context.get("stage_background_marker", false)), "Stage 2 boss context should fall back to background AI context")

	if _failures.is_empty():
		print("actor_context_groups_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
