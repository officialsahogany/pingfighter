extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "smasher"
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeRuntimePerkCatalog:
	extends RefCounted

	var choice_calls := 0

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = RuntimePerkCatalog.BASE_CHOICE_COUNT,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		choice_calls += 1
		return [
			{"id": "mugong_alpha", "name": "청류심법", "next_level": 1},
			{"id": "mugong_beta", "name": "철벽심법", "next_level": 1},
			{"id": "mugong_gamma", "name": "비연심법", "next_level": 1},
		]


class FakeRuntimePerkState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var training_counts: Dictionary = {}
	var apply_calls := 0
	var restore_calls := 0
	var allow_apply := true

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass

	func get_physique_training_count(training_id: String) -> int:
		return int(training_counts.get(training_id, 0))

	func get_physique_training_multiplier() -> float:
		return 1.0

	func is_physique_training_saturated(_training_id: String, _registry: Object = null) -> bool:
		return false

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_calls += 1
		if not allow_apply:
			return false
		var choice_id := str(choice.get("id", ""))
		if bool(choice.get("is_physique_training", false)):
			training_counts[choice_id] = int(training_counts.get(choice_id, 0)) + 1
		else:
			runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"physique_training": {"counts": training_counts.duplicate(true)},
		}

	func apply_unlock_save_snapshot(
		snapshot: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		restore_calls += 1
		var levels_value: Variant = snapshot.get("runtime_skill_levels", {})
		if not (levels_value is Dictionary):
			return {"restored": false}
		runtime_skill_levels = (levels_value as Dictionary).duplicate(true)
		var training_value: Variant = snapshot.get("physique_training", {})
		if training_value is Dictionary:
			var counts_value: Variant = (training_value as Dictionary).get("counts", {})
			if counts_value is Dictionary:
				training_counts = (counts_value as Dictionary).duplicate(true)
		return {"restored": true}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_choices_transactions_visit_limit_and_snapshot()
	_verify_insufficient_muhon_and_grant_rejection_are_no_ops()
	_verify_flag_off_is_untouched()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("tower_ascent_training_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_choices_transactions_visit_limit_and_snapshot() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var runtime_state := FakeRuntimePerkState.new()
	var perk_catalog := FakeRuntimePerkCatalog.new()
	var registry := _build_registry(runtime_state, perk_catalog)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "training-contract",
		"map_seed": 5,
		"node_modal_kind": "training",
		"run_state": {"muhon": 30, "gold": 0, "chance_gems": 3},
		"registry": registry,
	}), "training fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "training", owner), "training fixture must reach training only after route serve and map arrival")
	var generated := flow.get_generated_training_offers()
	_expect(generated.size() == 1, "one training visit must generate one node-owned offer")
	var offer: Dictionary = generated[0]
	_expect((offer.get("stat_choices", []) as Array).size() == RuntimePerkCatalog.BASE_CHOICE_COUNT, "stat training must reuse the existing three-choice count")
	_expect((offer.get("mugong_choices", []) as Array).size() == RuntimePerkCatalog.BASE_CHOICE_COUNT, "Mugong library must reuse the existing three-choice count")
	var actions: Array = flow.get_node_modal_view_model().get("actions", [])
	_expect(actions.size() == RuntimePerkCatalog.BASE_CHOICE_COUNT * 2 + 1, "training modal must expose both choice groups plus the shared end-work action")
	_expect(perk_catalog.choice_calls == 1, "training offers must be generated once per node visit")

	var stat_action := _find_action_with_prefix(actions, "training_stat:")
	var mugong_action := _find_action_with_prefix(actions, "training_mugong:")
	_expect(not stat_action.is_empty() and not mugong_action.is_empty(), "training modal must expose stat and Mugong actions")
	var stat_result := flow.execute_node_action(str(stat_action.get("id", "")), "training-contract:stat")
	_expect(bool(stat_result.get("accepted", false)) and bool(stat_result.get("applied", false)), "stat choice must commit through the node transaction")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 30 - TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST, "stat training must debit the unified one-Muhon price")
	_expect(runtime_state.apply_calls == 1 and runtime_state.training_counts.size() == 1, "stat training must reuse runtime_perk_state.apply_choice")

	var duplicate := flow.execute_node_action(str(mugong_action.get("id", "")), "training-contract:stat")
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("applied", true)), "duplicate node_resolution_id must be an accepted no-op before grant")
	_expect(runtime_state.apply_calls == 1 and int(flow.get_run_state_snapshot().get("muhon", -1)) == 29, "duplicate transaction must neither grant nor debit")

	var mugong_result := flow.execute_node_action(str(mugong_action.get("id", "")), "training-contract:mugong")
	_expect(bool(mugong_result.get("accepted", false)) and bool(mugong_result.get("applied", false)), "Mugong choice must commit through the existing grant path")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 27, "Mugong library must debit the unified two-Muhon price")
	_expect(runtime_state.apply_calls == 2 and runtime_state.runtime_skill_levels.size() == 1, "Mugong acquisition must be owned by runtime_perk_state.apply_choice")
	_expect(flow.get_training_history().size() == TowerAscentTuning.TEMP_PHASE_C_TRAINING_USES_PER_VISIT, "training history must own exactly the visit use cap")
	var exhausted_action := _find_unconsumed_training_action(flow.get_node_modal_view_model().get("actions", []))
	_expect(not exhausted_action.is_empty() and not bool(exhausted_action.get("enabled", true)), "all remaining training choices must disable after two uses")
	var exhausted_result := flow.execute_node_action(str(exhausted_action.get("id", "")), "training-contract:third")
	_expect(str(exhausted_result.get("reason", "")) == "training_visit_complete", "a third visit action must be rejected before transaction")
	_expect(runtime_state.apply_calls == 2 and int(flow.get_run_state_snapshot().get("muhon", -1)) == 27, "visit-limit rejection must not grant or debit")

	var snapshot := flow.export_persistable_snapshot()
	_expect((snapshot.get("generated_training_offers", []) as Array).size() == 1, "training offers must be part of the stable run snapshot")
	_expect((snapshot.get("training_history", []) as Array).size() == 2, "training transaction history must be part of the run snapshot")
	_expect((snapshot.get("build_state", {}) as Dictionary).has("runtime_perk_snapshot"), "runtime perk build state must use its existing save codec")
	var restored_runtime := FakeRuntimePerkState.new()
	var restored_catalog := FakeRuntimePerkCatalog.new()
	var restored_registry := _build_registry(restored_runtime, restored_catalog)
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot, Callable(), FakeOwner.new(), restored_registry), "stable training snapshot must restore")
	_expect(restored_catalog.choice_calls == 0, "restoring a training node must not reroll either choice group")
	_expect(var_to_bytes(restored.get_generated_training_offers()) == var_to_bytes(generated), "restored training offers must match byte-for-byte")
	_expect(restored_runtime.restore_calls == 1 and restored_runtime.runtime_skill_levels.size() == 1 and restored_runtime.training_counts.size() == 1, "restore must reuse runtime_perk_state's existing run-save codec")
	_finish_flow(flow, owner)
	_finish_flow(restored, null)


func _verify_insufficient_muhon_and_grant_rejection_are_no_ops() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var poor_runtime := FakeRuntimePerkState.new()
	var poor_flow := TowerAscentFlowOwner.new()
	var poor_owner := FakeOwner.new()
	_expect(poor_flow.begin_vertical_slice(poor_owner, Callable(), {
		"run_id": "training-poor",
		"map_seed": 5,
		"node_modal_kind": "training",
		"run_state": {"muhon": 0},
		"registry": _build_registry(poor_runtime, FakeRuntimePerkCatalog.new()),
	}), "insufficient-Muhon fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(poor_flow, "training", poor_owner), "insufficient-Muhon fixture must arrive at training")
	var poor_action := _find_action_with_prefix(poor_flow.get_node_modal_view_model().get("actions", []), "training_stat:")
	_expect(not bool(poor_action.get("enabled", true)), "insufficient Muhon must disable stat training")
	var reason := str(poor_action.get("unavailable_reason", ""))
	_expect(reason.contains("1"), "disabled stat training must show the one-Muhon requirement and shortfall")
	var poor_result := poor_flow.execute_node_action(str(poor_action.get("id", "")), "training-poor:attempt")
	_expect(not bool(poor_result.get("accepted", true)), "insufficient Muhon must reject direct execution")
	_expect(int(poor_flow.get_run_state_snapshot().get("muhon", -1)) == 0 and poor_runtime.apply_calls == 0 and poor_flow.get_training_history().is_empty(), "insufficient Muhon must emit no debit, grant, or transaction history")
	_finish_flow(poor_flow, poor_owner)

	var rejected_runtime := FakeRuntimePerkState.new()
	rejected_runtime.allow_apply = false
	var rejected_flow := TowerAscentFlowOwner.new()
	var rejected_owner := FakeOwner.new()
	_expect(rejected_flow.begin_vertical_slice(rejected_owner, Callable(), {
		"run_id": "training-rejected",
		"map_seed": 5,
		"node_modal_kind": "training",
		"run_state": {"muhon": 30},
		"registry": _build_registry(rejected_runtime, FakeRuntimePerkCatalog.new()),
	}), "grant-rejection fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(rejected_flow, "training", rejected_owner), "grant-rejection fixture must arrive at training")
	var rejected_action := _find_action_with_prefix(rejected_flow.get_node_modal_view_model().get("actions", []), "training_mugong:")
	var rejected_result := rejected_flow.execute_node_action(str(rejected_action.get("id", "")), "training-rejected:attempt")
	_expect(str(rejected_result.get("reason", "")) == "effect_rejected", "runtime grant rejection must surface before payment")
	_expect(int(rejected_flow.get_run_state_snapshot().get("muhon", -1)) == 30 and rejected_flow.get_training_history().is_empty(), "failed runtime grant must not debit or emit transaction history")
	_finish_flow(rejected_flow, rejected_owner)


func _verify_flag_off_is_untouched() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var runtime_state := FakeRuntimePerkState.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(FakeOwner.new(), Callable(), {
		"run_id": "training-off",
		"node_modal_kind": "training",
		"run_state": {"muhon": 30},
		"registry": _build_registry(runtime_state, FakeRuntimePerkCatalog.new()),
	}), "flag OFF must not enter the tower training node")
	_expect(flow.get_generated_training_offers().is_empty() and runtime_state.apply_calls == 0, "flag OFF must not generate offers or grant training")


func _verify_source_contract() -> void:
	var flow_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd")
	_expect(flow_source.find("apply_choice") >= 0 and flow_source.find("build_unlock_save_snapshot") >= 0, "training must reuse the existing runtime perk grant and save boundaries")
	_expect(builder_source.find("get_choices") >= 0 and builder_source.find("PhysiqueTrainingCatalog") >= 0, "training choices must consume existing Mugong and physique catalogs")
	_expect(builder_source.find("BASE_CHOICE_COUNT") >= 0, "choice count must reuse the existing catalog constant")


func _build_registry(runtime_state: Object, perk_catalog: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": perk_catalog,
		TowerAscentUnlockFilter.STORE_KEY: FakeUnlockStore.new(),
	}
	return registry


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")).begins_with(prefix):
			return action_value as Dictionary
	return {}


func _find_unconsumed_training_action(actions: Array) -> Dictionary:
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		if str(action.get("id", "")).begins_with("training_") and str(action.get("unavailable_reason", "")).contains("이번 방문"):
			return action
	return {}


func _finish_flow(flow: Object, owner: Object) -> void:
	if flow == null or not flow.is_active():
		return
	if flow.get_phase_name() == "NODE_MODAL":
		flow.debug_advance_to_route_aim()
	if flow.get_phase_name() == "ROUTE_AIM":
		flow.debug_launch_at_target(0)
		flow.update_selective(1.5, owner)
	if flow.get_phase_name() == "MAP_TRANSITION":
		flow.update_selective(1.0, owner)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
