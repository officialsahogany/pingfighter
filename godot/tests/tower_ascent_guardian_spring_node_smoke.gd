extends SceneTree

const CharacterInfoOverlayLingpetSnapshotBuilder := preload(
	"res://scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd"
)
const GuardianCodexStore := preload(
	"res://scripts/lingpet/guardian_codex_store.gd"
)
const GuardianEggAccessPolicy := preload(
	"res://scripts/lingpet/guardian_egg_access_policy.gd"
)
const LingpetEggRuntime := preload(
	"res://scripts/lingpet/lingpet_egg_runtime.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const SmasherSkillConfig := preload(
	"res://scripts/characters/smasher_skill_config.gd"
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

const CODEX_PATH := "user://tower_ascent_guardian_spring_smoke.cfg"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "smasher"
	var redraw_requests := 0
	var tower_ascent_soul_summoning_owned := false
	var tower_ascent_sealed_guardians: Array = []
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_slots: Array = []
	var ringpet_slots: Array = []
	var lingpet_active_slot_index := -1
	var ringpet_active_slot_index := -1

	func request_battle_redraw() -> void:
		redraw_requests += 1

	func set_tower_ascent_guardian_projection(
		sealed_guardians: Array,
		soul_summoning_owned: bool
	) -> void:
		tower_ascent_sealed_guardians = sealed_guardians.duplicate(true)
		tower_ascent_soul_summoning_owned = soul_summoning_owned


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
	var enhance_calls := 0
	var activate_calls := 0
	var absorb_calls := 0
	var restore_calls := 0
	var last_rng_was_isolated := false
	var fail_next_enhance := false

	func build_save_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func apply_save_snapshot(value: Dictionary, owner: Object = null, _registry: Object = null) -> Dictionary:
		restore_calls += 1
		snapshot = value.duplicate(true)
		_publish_owner(owner)
		return {"restored": true, "state": str(snapshot.get("state", "none"))}

	func build_guardian_enhance_live_candidates(_owner: Object = null) -> Array:
		if str(snapshot.get("state", "")) != "companion":
			return []
		return [{"type": "duration", "label": "지속시간 강화", "weight": 1.0}]

	func deploy_soul_summon_egg(_owner: Object, _registry: Object = null) -> Dictionary:
		return {"dropped": false, "skipped_reason": "sealed_fixture_has_no_field_drop"}

	func apply_guardian_enhance_random_roll(
		candidates: Array,
		_owner: Object = null,
		_registry: Object = null,
		_source: String = "perk",
		rng_override: RandomNumberGenerator = null
	) -> Dictionary:
		enhance_calls += 1
		last_rng_was_isolated = rng_override != null
		if fail_next_enhance:
			fail_next_enhance = false
			return {"accepted": false, "reason": "forced_enhance_failure"}
		return {
			"accepted": not candidates.is_empty(),
			"applied_candidate": candidates[0] if not candidates.is_empty() else {},
		}

	func activate_tower_sealed_guardian(
		pet_id: String,
		owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		activate_calls += 1
		var previous_pet_id := str(snapshot.get("pet_id", ""))
		snapshot["state"] = "companion"
		snapshot["pet_id"] = pet_id
		snapshot["owned_pet_ids"] = [pet_id]
		snapshot["collected_pet_ids"] = [pet_id]
		snapshot["battle_slot_pet_ids"] = [pet_id]
		snapshot["lingpet_slots"] = [pet_id]
		_publish_owner(owner)
		return {
			"accepted": true,
			"previous_pet_id": previous_pet_id,
			"pet_id": pet_id,
		}

	func absorb_tower_sealed_guardian(
		pet_id: String,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		absorb_calls += 1
		return {"accepted": str(snapshot.get("state", "")) == "companion", "absorbed_pet_id": pet_id}

	func _publish_owner(owner: Object) -> void:
		if not (owner is FakeOwner):
			return
		var target := owner as FakeOwner
		var companion := str(snapshot.get("state", "")) == "companion"
		target.lingpet_id = str(snapshot.get("pet_id", "")) if companion else ""
		target.lingpet_state = "companion" if companion else "none"
		target.ringpet_state = target.lingpet_state
		target.lingpet_slots = (snapshot.get("lingpet_slots", []) as Array).duplicate()
		target.ringpet_slots = target.lingpet_slots.duplicate()
		target.lingpet_active_slot_index = 0 if companion else -1
		target.ringpet_active_slot_index = target.lingpet_active_slot_index


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeTowerRevealFlow:
	extends RefCounted

	var calls := 0

	func record_guardian_identity_reveal(pet_id: String, _registry: Object = null) -> Dictionary:
		calls += 1
		return {
			"accepted": true,
			"handled": true,
			"tower_sealed": true,
			"pet_id": pet_id,
		}


func _initialize() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_real_flow_transactions_snapshot_and_display_only_tabs()
	_verify_insufficient_muhon_and_effect_failure_are_no_ops()
	_verify_actual_egg_reveal_routes_to_tower_owner()
	_verify_flag_off_is_untouched()
	_verify_source_contracts()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	call_deferred("_finish_test_after_resource_release")


func _finish_test_after_resource_release() -> void:
	# Reaching the real spring now prewarms its bitmap background. Give the
	# renderer two idle frames to release those test-only texture RIDs before
	# SceneTree shutdown so the production-path fixture stays classifier-clean.
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("tower_ascent_guardian_spring_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_real_flow_transactions_snapshot_and_display_only_tabs() -> void:
	var fixture := _build_fixture()
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = flow
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "guardian-spring-contract",
		"map_seed": 2,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 20, "gold": 0, "chance_gems": 3},
		"registry": fixture.registry,
	}), "guardian spring must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "guardian_spring", owner), "guardian spring must open only after route serve and map arrival")
	var soul_action := _find_action(
		flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:soul_summoning"
	)
	_expect(not soul_action.is_empty() and bool(soul_action.get("enabled", false)), "first visit must offer free Soul Summoning Art")
	var soul_result := flow.execute_node_action(
		"guardian_spring:soul_summoning",
		"guardian-spring:soul"
	)
	_expect(bool(soul_result.get("accepted", false)) and bool(soul_result.get("applied", false)), "Soul Summoning acquisition must commit")
	_expect(flow.has_soul_summoning() and owner.tower_ascent_soul_summoning_owned, "Soul Summoning must be run-owned and projected to the battle owner")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 20, "first Soul Summoning acquisition must be free")
	_expect(GuardianEggAccessPolicy.has_egg_access(owner, fixture.registry), "tower Soul Summoning must open the existing egg access policy")
	var same_visit_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	_expect(
		not same_visit_actions.is_empty() and not bool((same_visit_actions[0] as Dictionary).get("enabled", true)),
		"first visit must not expose later guardian operations in the same node"
	)

	var snapshot := flow.export_persistable_snapshot()
	var later_node_id := str((snapshot.get("route_target_ids", []) as Array)[0])
	snapshot["current_node_id"] = later_node_id
	var later_owner := FakeOwner.new()
	var later_flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = later_flow
	_expect(later_flow.restore_snapshot(snapshot, Callable(), later_owner, fixture.registry), "later spring visit must restore the run snapshot without rerolling guardian state")
	var reveal_lunabi := later_flow.record_guardian_identity_reveal("lunabi", fixture.registry)
	var reveal_maribo := later_flow.record_guardian_identity_reveal("maribo", fixture.registry)
	_expect(bool(reveal_lunabi.get("tower_sealed", false)) and bool(reveal_maribo.get("tower_sealed", false)), "revealed guardian identities must route into sealed run storage")
	_expect(fixture.codex.has_first_seen("lunabi") and fixture.codex.has_first_seen("maribo"), "identity reveal must commit both guardians to the persistent codex immediately")
	_expect(later_owner.lingpet_slots.is_empty() and later_owner.lingpet_id.is_empty(), "sealed guardians must not register a live slot or companion identity")
	var panel_snapshot := CharacterInfoOverlayLingpetSnapshotBuilder.build_panel_snapshot(
		later_owner,
		Callable(self, "_safe_owner_get"),
		3
	)
	var tabs: Array = panel_snapshot.get("slot_tabs", [])
	_expect(tabs.size() == 2 and tabs.all(func(entry: Variant) -> bool: return entry is Dictionary and bool((entry as Dictionary).get("sealed", false))), "sealed guardians must appear as display-only character-info tabs")

	var swap_action := _find_action_with_prefix(
		later_flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:swap:lunabi"
	)
	_expect(not swap_action.is_empty() and bool(swap_action.get("enabled", false)), "a sealed guardian must expose a free spring swap")
	var swap_result := later_flow.execute_node_action(
		str(swap_action.get("id", "")),
		"guardian-spring:swap-lunabi"
	)
	_expect(bool(swap_result.get("applied", false)) and fixture.runtime.activate_calls == 1, "swap must use the live guardian runtime exactly once")
	_expect(int(later_flow.get_run_state_snapshot().get("muhon", -1)) == 20, "guardian swap must remain free")
	var duplicate_swap := later_flow.execute_node_action(
		str(swap_action.get("id", "")),
		"guardian-spring:swap-lunabi"
	)
	_expect(bool(duplicate_swap.get("accepted", false)) and not bool(duplicate_swap.get("applied", true)) and fixture.runtime.activate_calls == 1, "duplicate node resolution must not reactivate or charge")

	var enhance_action := _find_action_with_prefix(
		later_flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:enhance:"
	)
	var enhance_result := later_flow.execute_node_action(
		str(enhance_action.get("id", "")),
		"guardian-spring:enhance-1"
	)
	_expect(bool(enhance_result.get("applied", false)), "enhance must commit through the node transaction")
	_expect(int(later_flow.get_run_state_snapshot().get("muhon", -1)) == 18, "enhance must debit the unified two-Muhon spring price")
	_expect(fixture.runtime.enhance_calls == 1 and fixture.runtime.last_rng_was_isolated, "enhance must reuse the runtime with an isolated deterministic RNG")

	var absorb_action := _find_action_with_prefix(
		later_flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:absorb:maribo"
	)
	var absorb_result := later_flow.execute_node_action(
		str(absorb_action.get("id", "")),
		"guardian-spring:absorb-maribo"
	)
	_expect(bool(absorb_result.get("applied", false)) and fixture.runtime.absorb_calls == 1, "absorb must use the existing guardian enhancement path")
	_expect((later_flow.get_guardian_state().get("sealed_guardians", []) as Array).is_empty(), "processed sealed guardians must leave sealed storage")

	var committed_snapshot := later_flow.export_persistable_snapshot()
	var committed_guardian_state := committed_snapshot.get("guardian_state", {}) as Dictionary
	var committed_runtime_snapshot := committed_guardian_state.get("runtime_snapshot", {}) as Dictionary
	_expect(not committed_runtime_snapshot.is_empty(), "guardian live state must be carried by the tower snapshot")
	var restored_fixture := _build_fixture()
	var restored_flow := TowerAscentFlowOwner.new()
	restored_fixture.registry.instances["tower_ascent_flow_owner"] = restored_flow
	_expect(restored_flow.restore_snapshot(committed_snapshot, Callable(), FakeOwner.new(), restored_fixture.registry), "guardian snapshot must restore through the live runtime")
	_expect(restored_fixture.runtime.restore_calls >= 1 and restored_flow.get_guardian_spring_history().size() == 4, "restore must preserve acquisition, swap, enhance, and absorb history")
	fixture.codex.clear()
	_finish_flow(flow, owner)
	_finish_flow(later_flow, later_owner)
	_finish_flow(restored_flow, null)
	fixture.registry.instances.clear()
	restored_fixture.registry.instances.clear()


func _verify_insufficient_muhon_and_effect_failure_are_no_ops() -> void:
	var fixture := _build_fixture()
	fixture.runtime.snapshot["state"] = "companion"
	fixture.runtime.snapshot["pet_id"] = "lunabi"
	fixture.runtime.snapshot["lingpet_slots"] = ["lunabi"]
	fixture.runtime.snapshot["battle_slot_pet_ids"] = ["lunabi"]
	var owner := FakeOwner.new()
	fixture.runtime._publish_owner(owner)
	var flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = flow
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "guardian-spring-poor",
		"map_seed": 2,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 1},
		"registry": fixture.registry,
	}), "poor guardian spring fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "guardian_spring", owner), "poor guardian spring fixture must arrive at the spring")
	flow.execute_node_action("guardian_spring:soul_summoning", "guardian-spring-poor:soul")
	var snapshot := flow.export_persistable_snapshot()
	snapshot["current_node_id"] = str((snapshot.get("route_target_ids", []) as Array)[0])
	var later := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = later
	_expect(later.restore_snapshot(snapshot, Callable(), owner, fixture.registry), "poor later visit must restore")
	var action := _find_action_with_prefix(later.get_node_modal_view_model().get("actions", []), "guardian_spring:enhance:")
	_expect(not bool(action.get("enabled", true)), "one Muhon must disable a two-Muhon enhancement")
	_expect(str(action.get("unavailable_reason", "")).contains("2") and str(action.get("unavailable_reason", "")).contains("1 부족"), "disabled enhance must show required amount and exact shortfall")
	var rejected := later.execute_node_action(str(action.get("id", "")), "guardian-spring-poor:enhance")
	_expect(not bool(rejected.get("accepted", true)) and fixture.runtime.enhance_calls == 0 and int(later.get_run_state_snapshot().get("muhon", -1)) == 1, "insufficient Muhon must issue no runtime effect or transaction")
	_finish_flow(flow, owner)
	_finish_flow(later, owner)
	fixture.registry.instances.clear()
	fixture.codex.clear()


func _verify_actual_egg_reveal_routes_to_tower_owner() -> void:
	var tower_flow := FakeTowerRevealFlow.new()
	var registry := FakeRegistry.new()
	registry.instances["tower_ascent_flow_owner"] = tower_flow
	var runtime := LingpetEggRuntime.new()
	var result_value: Variant = runtime.call("_record_guardian_discovery_at_reveal", "lunabi", registry)
	_expect(result_value is Dictionary and bool((result_value as Dictionary).get("tower_sealed", false)), "actual egg runtime reveal entry must accept the tower sealed route")
	_expect(tower_flow.calls == 1, "actual egg reveal must call the tower flow owner exactly once")


func _verify_flag_off_is_untouched() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var fixture := _build_fixture()
	var flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = flow
	_expect(not flow.begin_vertical_slice(FakeOwner.new(), Callable(), {
		"run_id": "guardian-spring-off",
		"node_modal_kind": "guardian_spring",
		"registry": fixture.registry,
	}), "flag OFF must not enter the guardian spring")
	_expect(not flow.has_soul_summoning() and fixture.runtime.activate_calls == 0 and fixture.runtime.enhance_calls == 0, "flag OFF must not grant access or touch guardian runtime")
	fixture.registry.instances.clear()
	fixture.codex.clear()
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _verify_source_contracts() -> void:
	var spring_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
	)
	var egg_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/hud/character_info_overlay_lingpet_presenter.gd"
	)
	_expect(spring_source.find("GuardianCodexDiscoveryRecorder.record_identity_reveal") >= 0, "spring reveal must use the Phase A persistent codex owner")
	_expect(spring_source.find("activate_tower_sealed_guardian") >= 0 and spring_source.find("absorb_tower_sealed_guardian") >= 0, "spring operations must call the live guardian runtime seams")
	_expect(spring_source.find("RandomNumberGenerator.new()") >= 0 and spring_source.find("plaza_") < 0, "spring enhance must isolate RNG and never reuse plaza payment")
	_expect(egg_source.find("_finish_tower_sealed_hatch") >= 0 and egg_source.find("tower_sealed") >= 0, "main and item egg reveal paths must branch to sealed storage")
	_expect(presenter_source.find("if not is_sealed:") >= 0, "sealed character-info tabs must never register clickable live-slot rects")


func _build_fixture() -> Dictionary:
	var codex := GuardianCodexStore.new()
	codex.set_save_path(CODEX_PATH)
	codex.clear()
	var runtime := FakeLingpetRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"guardian_codex_store": codex,
		"lingpet_egg_runtime": runtime,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_state": RuntimePerkState.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
	}
	return {"codex": codex, "runtime": runtime, "registry": registry}


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == action_id:
			return raw_action as Dictionary
	return {}


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")).begins_with(prefix):
			return raw_action as Dictionary
	return {}


func _safe_owner_get(target: Object, key: String, fallback: Variant) -> Variant:
	var value: Variant = target.get(key)
	return fallback if value == null else value


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
