extends SceneTree

const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const TowerAscentBossRegistry := preload("res://scripts/tower_ascent/tower_ascent_boss_registry.gd")
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerAscentFlowOwner := preload("res://scripts/tower_ascent/tower_ascent_flow_owner.gd")

var _failures: Array[String] = []
var _captured_encounter: Dictionary = {}


class FakeOwner:
	extends RefCounted
	var selection_state: Object
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var redraw_requests := 0

	func _init(value: Object) -> void:
		selection_state = value

	func get_node_or_null(path: NodePath) -> Object:
		return selection_state if str(path) == "/root/GameSelectionState" else null

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_arrival_routes_through_production_selector()
	_verify_shell_slot_uses_registered_standin()
	_verify_resolution_ids_are_unique_per_combat_node()
	_verify_run_progress_survives_two_combat_preparations()
	_verify_flag_off_preserves_legacy()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_boss_routing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_arrival_routes_through_production_selector() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var selection := GameSelectionState.new()
	var owner := FakeOwner.new(selection)
	var registry := FakeRegistry.new()
	registry.instances["battle_scene_match_event_driver"] = BattleSceneMatchEventDriver.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "routing-arrival",
		"map_seed": 45190,
		"current_stage": 1,
	}), "tower combat must prepare before route arrival")
	var target := _find_node_for_slot(flow, "floor_02_arachne")
	_expect(not target.is_empty(), "fixture seed must expose the Arachne route node")
	if target.is_empty():
		return
	flow.set("_active", true)
	flow.set("_finish_callback", Callable(self, "_capture_route"))
	flow.set("_selected_target_id", str(target.get("id", "")))
	flow.call("_complete_map_transition")
	_expect(str(_captured_encounter.get("boss_slot_id", "")) == "floor_02_arachne", "map arrival must emit the selected boss slot")
	BattleSceneMatchFlowDriver.new().call(
		"_finish_tower_boss_route",
		_captured_encounter,
		registry,
		owner,
		Callable()
	)
	_expect(owner.current_stage == 2, "routed Arachne arrival must select Stage 2 on the live battle owner")
	_expect(owner.stage_boss_variant == "arachne", "routed Arachne arrival must select the production Arachne variant")
	_expect(str(selection.get_selection().get("stage_boss_variant", "")) == "arachne", "tower route must inject through GameSelectionState rather than a parallel selector")
	selection.free()


func _verify_shell_slot_uses_registered_standin() -> void:
	var encounter := TowerAscentBossRegistry.new().resolve_battle_encounter("floor_04_shell_01")
	_expect(bool(encounter.get("fallback_used", false)), "shell boss slots must explicitly report stand-in fallback")
	_expect(int(encounter.get("stage", 0)) == 4 and str(encounter.get("boss_id", "")) == "ponk", "shell slot fallback must use the canonical stand-in table")


func _verify_resolution_ids_are_unique_per_combat_node() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.prepare_vertical_slice_combat(null, {
		"run_id": "unique-resolution",
		"map_seed": 45190,
		"current_stage": 1,
	}), "first combat traversal must prepare")
	var first_journal: Dictionary = flow.export_pending_reward_journal()
	var first_id := str((first_journal.get("pending_rewards", []) as Array)[0].get("node_resolution_id", ""))
	_expect(flow.begin_vertical_slice(null, Callable()), "first combat traversal must enter route selection")
	var next_combat := _find_first_other_combat_node(flow, flow.get_current_node_id())
	_expect(not next_combat.is_empty(), "unique-id fixture must find a distinct combat arrival")
	if next_combat.is_empty():
		return
	flow.set("_selected_target_id", str(next_combat.get("id", "")))
	flow.call("_complete_map_transition")
	_expect(flow.prepare_vertical_slice_combat(null), "second combat traversal in the same run must prepare")
	var second_journal: Dictionary = flow.export_pending_reward_journal()
	var second_id := str((second_journal.get("pending_rewards", []) as Array)[0].get("node_resolution_id", ""))
	_expect(first_id != second_id, "second combat in one run must receive a different node_resolution_id")
	_expect(second_id.find(str(next_combat.get("id", ""))) >= 0, "second resolution id must identify the arrived combat node")


func _verify_run_progress_survives_two_combat_preparations() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.prepare_vertical_slice_combat(null, {
		"run_id": "progress-reentry",
		"map_seed": 73191,
		"current_stage": 1,
		"run_state": {"gold": 19, "muhon": 23, "chance_gems": 2},
	}), "progress fixture first combat must prepare")
	_expect(flow.begin_vertical_slice(null, Callable()), "progress fixture first combat must enter route selection")
	var purchase_history: Array = flow.get("_purchase_history")
	purchase_history.append({"node_resolution_id": "progress-reentry:shop:purchase", "item_id": "fixture"})
	var generated_inventory: Array = flow.get("_generated_shop_inventory")
	generated_inventory.append({"node_id": "fixture-shop", "entries": [{"id": "fixture"}]})
	flow.set("_build_state", {"mugong": ["fixture_mugong"], "chosik": [], "active_items": [], "mythic": {}})
	flow.set("_gameplay_rng_state", {"seed": 90210, "state": 77123})
	var next_combat := _find_first_other_combat_node(flow, flow.get_current_node_id())
	_expect(not next_combat.is_empty(), "progress fixture must find a second combat")
	if next_combat.is_empty():
		return
	flow.set("_selected_target_id", str(next_combat.get("id", "")))
	flow.call("_complete_map_transition")
	_expect(flow.prepare_vertical_slice_combat(null), "progress fixture must traverse prepare a second time")
	var snapshot: Dictionary = flow.export_snapshot()
	_expect(str(snapshot.get("run_id", "")) == "progress-reentry", "second prepare must preserve run_id")
	_expect(snapshot.get("run_state", {}) == {"gold": 19, "muhon": 23, "chance_gems": 2}, "second prepare must preserve all run economy fields")
	_expect((snapshot.get("purchase_history", []) as Array).size() == 1, "second prepare must preserve purchase history")
	_expect((snapshot.get("generated_shop_inventory", []) as Array).size() == 1, "second prepare must preserve generated inventory")
	_expect((snapshot.get("build_state", {}) as Dictionary).get("mugong", []) == ["fixture_mugong"], "second prepare must preserve the run build")
	_expect(snapshot.get("gameplay_rng_state", {}) == {"seed": 90210, "state": 77123}, "second prepare must preserve gameplay RNG state")
	_expect(str(snapshot.get("current_node_id", "")) == str(next_combat.get("id", "")), "second prepare must preserve map position")


func _verify_flag_off_preserves_legacy() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(not TowerAscentFlowOwner.new().prepare_vertical_slice_combat(null, {"run_id": "routing-off"}), "flag OFF must leave legacy boss selection untouched")


func _find_node_for_slot(flow: Object, slot_id: String) -> Dictionary:
	for node in flow.get_graph_nodes():
		if str(node.get("boss_slot_id", "")) == slot_id:
			return node
	return {}


func _find_first_other_combat_node(flow: Object, excluded_id: String) -> Dictionary:
	for node in flow.get_graph_nodes():
		if (
			str(node.get("id", "")) != excluded_id
			and str(node.get("kind", "")) in ["boss", "combat", "enraged"]
		):
			return node
	return {}


func _capture_route(encounter: Dictionary) -> void:
	_captured_encounter = encounter.duplicate(true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
