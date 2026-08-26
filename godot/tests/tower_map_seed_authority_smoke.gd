extends SceneTree

const BattleTowerMapOverlayInputRouter := preload(
	"res://scripts/core/battle_tower_map_overlay_input_router.gd"
)
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)

const AUTHORITY_RUN_ID := "tower-map-seed-authority-m-shortcut"

var _failures: Array[String] = []
var _leg_count := 0


class FakeOwner:
	extends Node

	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var redraw_calls := 0

	func request_battle_redraw() -> void:
		redraw_calls += 1


class FakeModalRuntime:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var selection_state: Object = get_root().get_node_or_null("GameSelectionState")
	_expect(
		selection_state != null and selection_state.has_method("debug_set_tower_map_seed"),
		"production GameSelectionState autoload must expose the Tower map-seed authority"
	)
	if selection_state == null or not selection_state.has_method("debug_set_tower_map_seed"):
		_finish()
		return
	var previous_selection: Dictionary = selection_state.get_selection()
	var previous_seed := int(previous_selection.get("tower_map_seed", 0))
	var previous_available := bool(previous_selection.get("tower_map_seed_available", false))
	_verify_m_shortcut_inherits_selection_seed(selection_state)
	_verify_prepared_seed_mismatch_fails_without_mutation(selection_state)
	_verify_seed_zero_is_valid(selection_state)
	_verify_missing_seed_authority_fails_closed(selection_state)
	_verify_rejected_m_shortcut_cannot_bypass_on_second_press(selection_state)
	selection_state.call("debug_set_tower_map_seed", previous_seed, previous_available)
	_expect(_leg_count == 5, "all five map-seed authority legs must execute")
	_finish()


func _verify_m_shortcut_inherits_selection_seed(selection_state: Object) -> void:
	_leg_count += 1
	var flow := TowerAscentFlowOwner.new()
	var authoritative_seed := 1998965459
	selection_state.call("debug_set_tower_map_seed", authoritative_seed)
	var registry := TowerAscentBossRegistry.new()
	var seeded_slots := registry.get_seeded_floor_slots(1, authoritative_seed)
	_expect(not seeded_slots.is_empty(), "authority fixture must resolve a seeded Floor 1 gate")
	if seeded_slots.is_empty():
		return
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = str(seeded_slots[0].get("variant", ""))
	get_root().add_child(owner)
	var run_state: Object = flow.get("_run_state")
	_expect(
		run_state != null and bool(run_state.call("begin", AUTHORITY_RUN_ID, {}, [], {})),
		"counterproof fixture must establish a deterministic pre-map run id"
	)
	var module_registry := FakeRegistry.new()
	module_registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeModalRuntime.new(),
	}
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_M
	var input_router := BattleTowerMapOverlayInputRouter.new()
	_expect(
		input_router.handle_open_shortcut(event, owner, module_registry),
		"production M shortcut must open the Tower map overlay"
	)
	_expect(
		flow.prepare_vertical_slice_combat(owner, {
			"current_stage": 1,
			"map_seed": authoritative_seed,
		}),
		"a later prepare carrying the authoritative seed must remain idempotent"
	)
	_expect(
		flow.get_map_seed() == authoritative_seed,
		"M shortcut graph must retain GameSelectionState.tower_map_seed instead of the derived fallback"
	)
	var expected_flow := TowerAscentFlowOwner.new()
	_expect(
		expected_flow.prepare_vertical_slice_combat(owner, {
			"run_id": "tower-map-seed-authority-explicit",
			"current_stage": 1,
			"map_seed": authoritative_seed,
		}),
		"explicit authority fixture must prepare"
	)
	_expect(
		var_to_bytes(flow.get_graph_nodes()) == var_to_bytes(expected_flow.get_graph_nodes()),
		"M shortcut graph must equal the graph generated directly from the authoritative seed"
	)
	flow.close_map_overlay()
	flow.call("_finish_map_overlay_close")
	owner.free()


func _verify_prepared_seed_mismatch_fails_without_mutation(selection_state: Object) -> void:
	_leg_count += 1
	selection_state.call("debug_set_tower_map_seed", 0)
	var seed := 734521
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	var slots := TowerAscentBossRegistry.new().get_seeded_floor_slots(1, seed)
	if not slots.is_empty():
		owner.stage1_boss_variant = str(slots[0].get("variant", ""))
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "tower-map-seed-prepared-contract",
		"current_stage": 1,
		"map_seed": seed,
	}), "prepared-seed fixture must prepare once")
	var graph_before := var_to_bytes(flow.get_graph_nodes())
	var current_node_before := flow.get_current_node_id()
	var journal_before := var_to_bytes(flow.export_pending_reward_journal())
	var mismatch_accepted := flow.prepare_vertical_slice_combat(owner, {
		"current_stage": 1,
		"map_seed": seed + 1,
	})
	var mismatch_status: Dictionary = flow.get_last_prepare_status()
	_expect(
		not mismatch_accepted
		and not bool(mismatch_status.get("accepted", true))
		and str(mismatch_status.get("reason", "")) == "prepared_map_seed_mismatch",
		"real prepare must reject a different requested seed"
	)
	_expect(flow.get_map_seed() == seed, "seed mismatch rejection must preserve the prepared seed")
	_expect(
		var_to_bytes(flow.get_graph_nodes()) == graph_before,
		"seed mismatch rejection must preserve every prepared graph node"
	)
	_expect(
		flow.get_current_node_id() == current_node_before,
		"seed mismatch rejection must preserve the current node"
	)
	_expect(
		var_to_bytes(flow.export_pending_reward_journal()) == journal_before,
		"seed mismatch rejection must preserve the pending reward journal"
	)


func _verify_seed_zero_is_valid(selection_state: Object) -> void:
	_leg_count += 1
	selection_state.call("debug_set_tower_map_seed", 0)
	var flow := TowerAscentFlowOwner.new()
	var slots := TowerAscentBossRegistry.new().get_seeded_floor_slots(1, 0)
	_expect(not slots.is_empty(), "seed-zero fixture must resolve a generated Floor 1 gate")
	if slots.is_empty():
		return
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = str(slots[0].get("variant", ""))
	get_root().add_child(owner)
	var accepted := flow.prepare_vertical_slice_combat(
		owner,
		{"run_id": "tower-map-seed-zero-valid", "current_stage": 1}
	)
	_expect(
		accepted and flow.get_map_seed() == 0 and not flow.get_graph_nodes().is_empty(),
		"explicit seed zero must prepare a generated Tower graph"
	)
	owner.free()


func _verify_missing_seed_authority_fails_closed(selection_state: Object) -> void:
	_leg_count += 1
	selection_state.call("debug_set_tower_map_seed", 0, false)
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	get_root().add_child(owner)
	var accepted := flow.prepare_vertical_slice_combat(
		owner,
		{"run_id": "tower-map-seed-authority-missing", "current_stage": 1}
	)
	var status: Dictionary = flow.get_last_prepare_status()
	_expect(
		not accepted
		and str(status.get("reason", "")) == "missing_authoritative_map_seed",
		"a fresh Tower run without context or selection authority must fail closed"
	)
	_expect(flow.get_graph_nodes().is_empty(), "missing authority must not materialize a graph")
	owner.free()


func _verify_rejected_m_shortcut_cannot_bypass_on_second_press(selection_state: Object) -> void:
	_leg_count += 1
	var seed := 229
	selection_state.call("debug_set_tower_map_seed", seed)
	var slots := TowerAscentBossRegistry.new().get_seeded_floor_slots(1, seed)
	_expect(not slots.is_empty(), "repeated-M fixture must resolve a seeded Floor 1 gate")
	if slots.is_empty():
		return
	var expected_variant := str(slots[0].get("variant", ""))
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = "gaksi" if expected_variant != "gaksi" else "podo"
	get_root().add_child(owner)
	var flow := TowerAscentFlowOwner.new()
	var module_registry := FakeRegistry.new()
	module_registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeModalRuntime.new(),
	}
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_M
	var input_router := BattleTowerMapOverlayInputRouter.new()
	for press_index in range(2):
		_expect(
			not input_router.handle_open_shortcut(event, owner, module_registry),
			"mismatched opening identity must reject M press %d" % (press_index + 1)
		)
		_expect(
			flow.get_graph_nodes().is_empty()
			and str(flow.get_last_prepare_status().get("reason", ""))
				== "opening_boss_identity_mismatch",
			"M press %d rejection must clear materialized graph state" % (press_index + 1)
		)
	owner.free()


func _finish() -> void:
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_seed_authority_smoke: legs=%d" % _leg_count)
		print("tower_map_seed_authority_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
