extends SceneTree

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)

var _failures: Array[String] = []


class BattleOwner:
	extends RefCounted

	var scene_state := BattleSceneState.new()
	var redraw_requests := 0

	func _init() -> void:
		scene_state.reset()
		scene_state.set_value("selected_character_type", "smasher")
		scene_state.set_value("current_stage", 1)

	func _get(property: StringName) -> Variant:
		var key := str(property)
		return scene_state.get_value(key) if scene_state.has_key(key) else null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true

	func request_battle_redraw() -> void:
		redraw_requests += 1

	func set_tower_ascent_guardian_projection(
		sealed_guardians: Array,
		soul_summoning_owned: bool
	) -> void:
		scene_state.set_value("tower_ascent_sealed_guardians", sealed_guardians.duplicate(true))
		scene_state.set_value("tower_ascent_soul_summoning_owned", soul_summoning_owned)


class FakeGuardianCodex:
	extends RefCounted


class FakeLingpetRuntime:
	extends RefCounted

	var snapshot := {
		"state": "none",
		"pet_id": "",
		"owned_pet_ids": [],
		"collected_pet_ids": [],
		"battle_slot_pet_ids": [],
		"lingpet_slots": [],
		"active_slot_index": 0,
		"guardian_run_state": {"pets": {}},
	}

	func build_save_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func apply_save_snapshot(
		value: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		snapshot = value.duplicate(true)
		return {"restored": true}

	func deploy_soul_summon_egg(_owner: Object, _registry: Object) -> Dictionary:
		return {"dropped": false, "skipped_reason": "sealed_fixture_has_no_field_drop"}


class Registry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _initialize() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_spring_grant_reaches_next_battle_chosik_slots()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_guardian_spring_chosik_bridge_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_spring_grant_reaches_next_battle_chosik_slots() -> void:
	var owner := BattleOwner.new()
	var registry := Registry.new()
	var runtime_state := RuntimePerkState.new()
	var runtime_catalog := RuntimePerkCatalog.new()
	var skill_config := SmasherSkillConfig.new()
	registry.instances = {
		"guardian_codex_store": FakeGuardianCodex.new(),
		"lingpet_egg_runtime": FakeLingpetRuntime.new(),
		"runtime_perk_catalog": runtime_catalog,
		"runtime_perk_state": runtime_state,
		"smasher_skill_config": skill_config,
	}
	var flow := TowerAscentFlowOwner.new()
	registry.instances["tower_ascent_flow_owner"] = flow
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "guardian-spring-chosik-bridge",
		"map_seed": 2,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 0, "gold": 0, "chance_gems": 3},
		"registry": registry,
	}), "seal fixture must enter the production Tower flow")
	_expect(
		TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "guardian_spring", owner),
		"seal fixture must arrive at the production guardian-spring modal"
	)
	var grant_result: Dictionary = flow.execute_node_action(
		"guardian_spring:soul_summoning",
		"guardian-spring-chosik-bridge:grant"
	)
	_expect(
		bool(grant_result.get("accepted", false)) and bool(grant_result.get("applied", false)),
		"guardian-spring acquisition must commit before leaving the node"
	)

	flow.debug_advance_to_route_aim()
	var combat_target := _find_battle_target(flow.get_route_aim_targets())
	_expect(not combat_target.is_empty(), "guardian spring must expose a next combat target")
	if not combat_target.is_empty():
		flow.call("_resolve_route_target", str(combat_target.get("id", "")))
		flow.call("_complete_map_transition")
	_expect(not flow.is_active(), "next combat entry must close the Tower map overlay")

	var battle_skill_context := Stage1PillarUiLayout.new().build_skill_orb_context({
		"selected_character_type": "smasher",
		"skill_config_snapshot": skill_config.get_snapshot(),
	}, null)
	var equipped_skills: Array = battle_skill_context.get("equipped_skills", [])
	_expect(
		equipped_skills.has(CommonSkillCatalog.SOUL_SUMMON_ART_ID),
		"guardian spring -> next battle entry -> production Chosik slots must contain Soul Summoning Art"
	)
	_expect(
		int(runtime_state.runtime_skill_levels.get(
			CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID,
			0
		)) == 1,
		"guardian spring must record the canonical unlock perk level"
	)
	_expect(
		int(runtime_state.runtime_skill_levels.get(CommonSkillCatalog.SOUL_SUMMON_ART_ID, 0)) == 1,
		"guardian spring must preserve the common active-skill runtime level bridge"
	)


func _find_battle_target(targets: Array) -> Dictionary:
	for target_value in targets:
		if not (target_value is Dictionary):
			continue
		var kind := str((target_value as Dictionary).get("kind", ""))
		if kind == "combat" or kind == "boss":
			return target_value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
