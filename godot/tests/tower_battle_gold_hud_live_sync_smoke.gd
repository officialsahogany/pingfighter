extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const Stage1PillarHudSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)

const EXPECTED_LEG_COUNT := 4

var _failures: Array[String] = []
var _leg_count := 0


class CachedOnlyRegistry:
	extends RefCounted

	var flow_owner: Object
	var cold_get_calls := 0

	func _init(value: Object) -> void:
		flow_owner = value

	func get_cached_instance(key: String) -> Object:
		return flow_owner if key == "tower_ascent_flow_owner" else null

	func get_instance(_key: String) -> Object:
		cold_get_calls += 1
		return null


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	PerkConversionFlags.debug_set_enabled(true)
	_verify_tower_battle_gold_routes_to_live_run_balance()
	_verify_pillar_and_shop_project_the_same_awarded_gold()
	_verify_muhon_collection_stays_intact()
	_verify_non_tower_campaign_keeps_runtime_gold()
	PerkConversionFlags.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(
		_leg_count == EXPECTED_LEG_COUNT,
		"gold live-sync seal leg count drifted: expected %d, got %d" % [
			EXPECTED_LEG_COUNT,
			_leg_count,
		]
	)
	if _failures.is_empty():
		print("tower_battle_gold_hud_live_sync_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_tower_battle_gold_routes_to_live_run_balance() -> void:
	var flow := _started_flow("tower-gold-live-sync", 0, 9)
	var registry := CachedOnlyRegistry.new(flow)
	var perk_state: Object = RuntimePerkState.new()
	var returned_total := int(perk_state.award_gold(25, {}, {"registry": registry}))
	perk_state.runtime_skill_levels = {"common_bulk_up": 5, "common_swiftness": 5}
	var fusion_record: Dictionary = perk_state.commit_perk_fusion(
		["common_bulk_up", "common_swiftness"],
		{"outcome": "byproduct", "byproducts": ["golden_trajectory"]},
		RuntimePerkCatalog.new()
	)
	var fusion_award := int(perk_state.award_perk_fusion_wall_bounce_gold(
		{},
		{"registry": registry}
	))
	var economy: Dictionary = flow.get_run_state_snapshot()
	_expect(not fusion_record.is_empty(), "tower golden-trajectory fixture should commit")
	_expect(fusion_award == 2, "tower golden trajectory should keep its exact wall-bounce award")
	_expect(int(economy.get("gold", -1)) == 27, "all tower battle gold entry points should increase run_state.gold immediately")
	_expect(perk_state.gold_from_perks == 0, "tower battle gold must not remain in plaza-bound runtime_perk_gold")
	_expect(returned_total == 0, "tower award caller projection should keep the non-run runtime gold total unchanged")
	_expect(registry.cold_get_calls == 0, "tower gold routing must use a cached-only flow-owner lookup")
	_leg_count += 1


func _verify_pillar_and_shop_project_the_same_awarded_gold() -> void:
	var flow := _started_flow("tower-gold-ui-alignment", 7, 12)
	var registry := CachedOnlyRegistry.new(flow)
	var perk_state: Object = RuntimePerkState.new()
	perk_state.award_gold(13, {}, {"registry": registry})
	var economy: Dictionary = flow.get_run_state_snapshot()
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var pillar_gold := int(drawer.call("_build_gold_hud_amount", {"runtime_perk_gold": 999}, registry))
	var modal := TowerAscentNodeModalState.new()
	modal.open("shop", "shop", economy, [])
	var modal_model: Dictionary = modal.build_view_model()
	_expect(pillar_gold == 20, "pillar HUD should follow the live tower gold award")
	_expect(int(modal_model.get("balances", {}).get("gold", -1)) == pillar_gold, "shop modal and pillar HUD must read the same run gold")
	_expect(str(modal_model.get("gold_text", "")).contains("20"), "shop modal should render the awarded run gold value")
	_expect(registry.cold_get_calls == 0, "pillar equality proof must not cold-create a module on the draw path")
	_leg_count += 1


func _verify_muhon_collection_stays_intact() -> void:
	var flow := _started_flow("tower-gold-muhon-negative", 4, 11)
	var registry := CachedOnlyRegistry.new(flow)
	var perk_state: Object = RuntimePerkState.new()
	perk_state.award_gold(6, {}, {"registry": registry})
	var after_gold: Dictionary = flow.get_run_state_snapshot()
	_expect(int(after_gold.get("gold", -1)) == 10, "tower gold award should preserve its exact increment")
	_expect(int(after_gold.get("muhon", -1)) == 11, "tower gold award must not alter Muhon")
	var muhon_result: Dictionary = flow.collect_muhon(3)
	var after_muhon: Dictionary = flow.get_run_state_snapshot()
	_expect(bool(muhon_result.get("accepted", false)), "existing tower Muhon collection should remain accepted")
	_expect(int(after_muhon.get("muhon", -1)) == 14, "existing tower Muhon collection should keep updating the run balance")
	_expect(int(after_muhon.get("gold", -1)) == 10, "Muhon collection must not alter the newly routed run gold")
	_leg_count += 1


func _verify_non_tower_campaign_keeps_runtime_gold() -> void:
	var flow: Object = TowerAscentFlowOwner.new()
	var registry := CachedOnlyRegistry.new(flow)
	var perk_state: Object = RuntimePerkState.new()
	perk_state.gold_from_perks = 5
	var returned_total := int(perk_state.award_gold(7, {}, {"registry": registry}))
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var pillar_gold := int(drawer.call("_build_gold_hud_amount", {"runtime_perk_gold": returned_total}, registry))
	_expect(flow.get_run_id().is_empty(), "non-tower gold must not create a tower run as a side effect")
	_expect(int(flow.get_run_state_snapshot().get("gold", -1)) == 0, "non-tower gold must not enter run_state.gold")
	_expect(returned_total == 12 and perk_state.gold_from_perks == 12, "non-tower campaign should preserve cumulative runtime_perk_gold")
	_expect(pillar_gold == 12, "non-tower campaign should preserve its prior runtime-gold HUD contribution")
	_expect(registry.cold_get_calls == 0, "non-tower routing and HUD projection must remain cached-only")
	_leg_count += 1


func _started_flow(run_id: String, gold: int, muhon: int) -> Object:
	var flow: Object = TowerAscentFlowOwner.new()
	var started := bool(flow.ensure_run_started(null, {
		"run_id": run_id,
		"run_state": {
			"gold": gold,
			"muhon": muhon,
			"chance_gems": 3,
		},
	}))
	_expect(started, "tower test fixture should start run %s" % run_id)
	return flow


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
