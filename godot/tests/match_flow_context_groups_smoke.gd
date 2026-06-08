extends SceneTree

const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")

var _failures: Array[String] = []


class FakeStageRouter:
	extends RefCounted

	func get_instance(registry: Object, current_stage: int, role: String) -> Object:
		if current_stage == 2 and role == "stage_background":
			return registry.get_instance("stage2_pillar_background")
		return null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		for key in [
			"match_score_state",
			"round_flow_state",
			"scoreboard_state",
			"game_audio",
			"match_score_event_controller",
			"match_scoreboard_flow_controller",
			"match_round_restart_controller",
			"match_reset_controller",
			"orb_hud_state",
			"active_item_hud_state",
			"active_item_runtime",
			"mythic_item_runtime",
			"treasure_hunt_runtime",
			"smasher_skill_state",
			"viper_skill_state",
			"smasher_drive_input_state",
			"smasher_plasma_state",
			"smasher_recovery_state",
			"smasher_cleanse_state",
			"smasher_warp_gate_state",
			"smasher_wheel_state",
			"smasher_magnum_grip_state",
			"smasher_dash_spirit_state",
			"smasher_shield_kiting_state",
			"monkey_blessing_delivery_state",
			"runtime_perk_state",
			"smasher_skill_config",
			"viper_skill_config",
			"viper_skill_runtime",
			"smasher_dash_state",
			"stage1_dalji_whip_skill_state",
			"stage1_dalji_spinning_top_skill_state",
			"stage1_dalji_boss_skill_cooldown_state",
			"stage1_balloon_event",
			"stage2_boss_skill_state",
			"stage1_pillar_background",
			"stage2_pillar_background",
			"commando_skill_state",
			"commando_skill_config",
			"commando_emergency_supply_state",
			"commando_reload_delivery_state",
			"commando_firearm_runtime",
			"commando_supply_drop_state",
			"optimus_energy_state",
			"blacksmith_skill_state",
			"blacksmith_skill_config",
			"blacksmith_thor_shield_state",
			"laurel_leaf_shield_state",
			"status_effect_state",
		]:
			instances[key] = RefCounted.new()
		instances["stage_runtime_router"] = FakeStageRouter.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var context: Object = BattleUpdateMatchFlowContext.new()

	var deps: Dictionary = context.build_deps(registry, 2)
	_expect(deps.get("score_state", null) == registry.instances["match_score_state"], "match state deps should include score state")
	_expect(deps.get("match_reset_controller", null) == registry.instances["match_reset_controller"], "match controller deps should include reset controller")
	_expect(deps.get("active_item_runtime", null) == registry.instances["active_item_runtime"], "item deps should include active item runtime")
	_expect(deps.get("mythic_item_runtime", null) == registry.instances["mythic_item_runtime"], "item deps should include mythic runtime")
	_expect(deps.get("orb_hud_state", null) == registry.instances["orb_hud_state"], "item/HUD deps should include orb HUD")
	_expect(deps.get("skill_state", null) == registry.instances["smasher_skill_state"], "skill deps should keep legacy skill_state")
	_expect(deps.get("skill_states", []).size() == 5, "skill deps should include registered skill states")
	_expect(deps.get("skill_configs", []).size() == 4, "skill deps should include skill configs")
	_expect(deps.get("skill_runtimes", []).size() == 4, "skill deps should include skill runtimes")
	_expect(deps.get("commando_reload_delivery_state", null) == registry.instances["commando_reload_delivery_state"], "skill deps should include Commando reload delivery state")
	_expect(deps.get("dash_state", null) == registry.instances["smasher_dash_state"], "skill deps should include dash state")
	_expect(deps.get("stage_background", null) == registry.instances["stage2_pillar_background"], "stage deps should use router stage background")
	_expect(deps.get("stage2_boss_skill_state", null) == registry.instances["stage2_boss_skill_state"], "stage deps should include Stage 2 boss skill state")

	var fallback_deps: Dictionary = context.build_deps(registry, 99)
	_expect(fallback_deps.get("stage_background", null) == registry.instances["stage1_pillar_background"], "stage deps should fall back to Stage 1 background")
	_expect(registry.requested_keys.has("stage_runtime_router"), "stage deps should query stage runtime router")

	if _failures.is_empty():
		print("match_flow_context_groups_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
