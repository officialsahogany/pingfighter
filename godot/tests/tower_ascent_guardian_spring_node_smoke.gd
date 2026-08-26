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
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const CODEX_PATH := "user://tower_ascent_guardian_spring_smoke.cfg"

var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	"guardian_spring"
)


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

	func grant_and_activate_tower_spring_guardian(
		pet_id: String,
		owner: Object = null,
		_registry: Object = null,
		_rng_seed: int = 0
	) -> bool:
		snapshot["state"] = "companion"
		snapshot["pet_id"] = pet_id
		snapshot["owned_pet_ids"] = [pet_id]
		snapshot["lingpet_slots"] = [pet_id]
		snapshot["battle_slot_pet_ids"] = [pet_id]
		_publish_owner(owner)
		return true

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
			"tower_sealed": false,
			"pet_id": pet_id,
		}


func _initialize() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_real_flow_transactions_snapshot_and_display_only_tabs()
	_verify_insufficient_muhon_and_effect_failure_are_no_ops()
	_verify_auto_route_rng_matches_the_existing_exit()
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
		"map_seed": _initial_route_seed,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 20, "gold": 0, "chance_gems": 3},
		"registry": fixture.registry,
	}), "guardian spring must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "guardian_spring", owner), "guardian spring must open only after route serve and map arrival")
	var soul_action := _find_action(
		flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:palm"
	)
	_expect(not soul_action.is_empty() and bool(soul_action.get("enabled", false)), "first visit must offer the free palm action")
	var soul_result := flow.execute_node_action(
		"guardian_spring:palm",
		"guardian-spring:soul"
	)
	_expect(bool(soul_result.get("accepted", false)) and bool(soul_result.get("applied", false)), "Soul Summoning acquisition must commit")
	_expect(flow.has_soul_summoning() and owner.tower_ascent_soul_summoning_owned, "Soul Summoning must be run-owned and projected to the battle owner")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 20, "first Soul Summoning acquisition must be free")
	_expect(GuardianEggAccessPolicy.has_egg_access(owner, fixture.registry), "tower Soul Summoning must open the existing egg access policy")
	var same_visit_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var same_visit_first_picks: Array = same_visit_actions.filter(
		func(action_value: Variant) -> bool:
			return (
				action_value is Dictionary
				and str((action_value as Dictionary).get("payload", {}).get(
					"operation",
					""
				)) == "first_pick"
			)
	)
	var all_same_visit_picks_blind := true
	for action_value in same_visit_first_picks:
		var first_pick_action := action_value as Dictionary
		all_same_visit_picks_blind = (
			all_same_visit_picks_blind
			and bool(first_pick_action.get("payload", {}).get("choice", {}).get(
				"guardian_blind_preview",
				false
			))
		)
	_expect(
		same_visit_first_picks.size() == 3
		and all_same_visit_picks_blind,
		"palm completion must expose exactly three blind first-guardian cards in the same visit"
	)
	for _frame_index in range(12):
		flow.update_selective(0.10, owner)
	var unavailable_status := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_ACTION_UNAVAILABLE
	)
	_expect(
		flow.get_phase_name() == "NODE_MODAL"
		and str(flow.get_node_modal_view_model().get("status_text", "")) != unavailable_status,
		"first-pick pending must stay in the Spring modal without auto-route unavailable feedback beyond the hold budget"
	)
	_expect(flow.get_phase_name() == "NODE_MODAL", "same-visit first pick must retain the Spring modal")
	_expect(
		not bool(flow.call("_try_enter_route_aim_from_node_modal"))
		and flow.get_phase_name() == "NODE_MODAL",
		"Esc/end-work must not enter route aim while the mandatory first pick is pending"
	)
	var same_visit_first_pick: Dictionary = (
		same_visit_first_picks[0] as Dictionary
		if not same_visit_first_picks.is_empty()
		else {}
	)
	_expect(
		bool(same_visit_first_pick.get("payload", {}).get("choice", {}).get(
			"guardian_blind_preview", false
		)),
		"same-visit first-guardian choice must retain its blind preview contract"
	)
	flow.call("_confirm_node_modal_action", same_visit_first_pick)
	var post_pick_guardian_state: Dictionary = flow.get_guardian_state()
	_expect(
		not (post_pick_guardian_state.get("active_guardian", {}) as Dictionary).is_empty()
		and flow.get_guardian_spring_history().size() == 2,
		"the same Spring visit must commit one first-guardian choice"
	)
	var receipt: Dictionary = flow.get_node_modal_view_model().get("interaction_receipt", {})
	_expect(
		flow.get_phase_name() == "NODE_MODAL"
		and bool(receipt.get("success", false)),
		"first-pick success receipt must be drawable before route aim"
	)
	var post_pick_snapshot := flow.export_persistable_snapshot()
	flow.update_selective(0.10, owner)
	_expect(flow.get_phase_name() == "NODE_MODAL", "first-pick receipt must remain for at least one selective frame")
	flow.update_selective(0.36, owner)
	_expect(flow.get_phase_name() == "ROUTE_AIM", "first-pick receipt must then auto-enter route aim")
	var later_snapshot := post_pick_snapshot.duplicate(true)
	var later_route_targets: Array = later_snapshot.get("route_target_ids", [])
	_expect(not later_route_targets.is_empty(), "committed Spring snapshot must retain a later route target")
	if not later_route_targets.is_empty():
		later_snapshot["current_node_id"] = str(later_route_targets[0])
	var later_flow := TowerAscentFlowOwner.new()
	var later_owner := FakeOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = later_flow
	_expect(
		later_flow.restore_snapshot(
			later_snapshot,
			Callable(),
			later_owner,
			fixture.registry
		),
		"later spring visit must restore the run snapshot without rerolling guardian state"
	)
	_expect(
		later_flow.get_guardian_state() == post_pick_guardian_state
		and later_flow.get_guardian_spring_history() == flow.get_guardian_spring_history(),
		"fresh later flow restore must preserve the exact committed guardian state and history"
	)
	fixture.registry.instances.erase("guardian_codex_store")
	var failed_codex_reveal := later_flow.record_guardian_identity_reveal("lunabi", fixture.registry)
	_expect(not bool(failed_codex_reveal.get("accepted", true)), "missing codex store must fail independently")
	_expect(
		bool(later_flow.get_run_state_snapshot().get("prayer_locked", false)),
		"actual guardian acquisition must lock prayer even when codex persistence fails"
	)
	fixture.registry.instances["guardian_codex_store"] = fixture.codex
	var reveal_lunabi := later_flow.record_guardian_identity_reveal("lunabi", fixture.registry)
	var reveal_maribo := later_flow.record_guardian_identity_reveal("maribo", fixture.registry)
	_expect(not bool(reveal_lunabi.get("tower_sealed", true)) and not bool(reveal_maribo.get("tower_sealed", true)), "tower reveal must keep the existing overflow UI route active")
	_expect(fixture.codex.has_first_seen("lunabi") and fixture.codex.has_first_seen("maribo"), "identity reveal must commit both guardians to the persistent codex immediately")
	_expect((later_flow.get_guardian_state().get("sealed_guardians", []) as Array).is_empty(), "tower reveal must not create retired sealed-roster inventory")
	var panel_snapshot := CharacterInfoOverlayLingpetSnapshotBuilder.build_panel_snapshot(
		later_owner,
		Callable(self, "_safe_owner_get"),
		3
	)
	var tabs: Array = panel_snapshot.get("slot_tabs", [])
	var sealed_tabs := tabs.filter(func(tab_value: Variant) -> bool:
		return tab_value is Dictionary and bool((tab_value as Dictionary).get("sealed", false))
	)
	_expect(tabs.size() == 1, "one active guardian must create exactly one character-info tab")
	_expect(sealed_tabs.is_empty(), "retired sealed guardians must not create display-only character-info tabs")

	var committed_snapshot := post_pick_snapshot
	var legacy_guardian_state := committed_snapshot.get("guardian_state", {}) as Dictionary
	legacy_guardian_state["sealed_guardians"] = [{"pet_id": "mokrin"}]
	committed_snapshot["guardian_state"] = legacy_guardian_state
	var restored_fixture := _build_fixture()
	var restored_flow := TowerAscentFlowOwner.new()
	restored_fixture.registry.instances["tower_ascent_flow_owner"] = restored_flow
	_expect(restored_flow.restore_snapshot(committed_snapshot, Callable(), FakeOwner.new(), restored_fixture.registry), "legacy guardian snapshot must restore")
	_expect((restored_flow.get_guardian_state().get("sealed_guardians", []) as Array).is_empty(), "legacy sealed guardians must be discarded during restore migration")
	_expect(restored_flow.get_guardian_spring_history().size() == 2, "restore must preserve Soul Summoning and first-pick history while retiring sealed operations")
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
		"map_seed": _initial_route_seed,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 0},
		"registry": fixture.registry,
	}), "poor guardian spring fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "guardian_spring", owner), "poor guardian spring fixture must arrive at the spring")
	var snapshot := flow.export_persistable_snapshot()
	snapshot["current_node_id"] = str((snapshot.get("route_target_ids", []) as Array)[0])
	var later := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = later
	_expect(later.restore_snapshot(snapshot, Callable(), owner, fixture.registry), "poor later visit must restore")
	var action := _find_action_with_prefix(later.get_node_modal_view_model().get("actions", []), "guardian_spring:enhance:")
	_expect(not bool(action.get("enabled", true)), "zero Muhon must disable a one-Muhon enhancement")
	_expect(str(action.get("unavailable_reason", "")).contains("1") and str(action.get("unavailable_reason", "")).contains("1 부족"), "disabled enhance must show required amount and exact shortfall")
	var rejected := later.execute_node_action(str(action.get("id", "")), "guardian-spring-poor:enhance")
	_expect(not bool(rejected.get("accepted", true)) and fixture.runtime.enhance_calls == 0 and int(later.get_run_state_snapshot().get("muhon", -1)) == 0, "insufficient Muhon must issue no runtime effect or transaction")
	later.call("_confirm_node_modal_action", action)
	var disabled_status := str(later.get_node_modal_view_model().get("status_text", ""))
	_expect(
		not disabled_status.is_empty()
		and disabled_status != str(action.get("disabled_reason", ""))
		and disabled_status != "effect_rejected",
		"the disabled-card sync must expose localized copy instead of an internal reason"
	)
	_finish_flow(flow, owner)
	_finish_flow(later, owner)
	fixture.registry.instances.clear()
	fixture.codex.clear()

	var effect_fixture := _build_fixture()
	effect_fixture.runtime.snapshot["state"] = "companion"
	effect_fixture.runtime.snapshot["pet_id"] = "lunabi"
	effect_fixture.runtime.snapshot["lingpet_slots"] = ["lunabi"]
	effect_fixture.runtime.snapshot["battle_slot_pet_ids"] = ["lunabi"]
	effect_fixture.runtime.fail_next_enhance = true
	var effect_owner := FakeOwner.new()
	effect_fixture.runtime._publish_owner(effect_owner)
	var effect_flow := TowerAscentFlowOwner.new()
	effect_fixture.registry.instances["tower_ascent_flow_owner"] = effect_flow
	_expect(effect_flow.begin_vertical_slice(effect_owner, Callable(), {
		"run_id": "guardian-spring-effect-rejected",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 1},
		"registry": effect_fixture.registry,
	}), "effect-rejection fixture must open")
	_expect(
		TowerAscentNodeArrivalTestFixture.advance_to_node_modal(
			effect_flow,
			"guardian_spring",
			effect_owner
		),
		"effect-rejection fixture must arrive at the spring"
	)
	var enabled_enhance := _find_action_with_prefix(
		effect_flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:enhance:"
	)
	var effect_result := effect_flow.execute_node_action(
		str(enabled_enhance.get("id", "")),
		"guardian-spring:effect-rejected"
	)
	var effect_status := str(effect_flow.get_node_modal_view_model().get("status_text", ""))
	_expect(
		str(effect_result.get("reason", "")) == "effect_rejected"
		and not effect_status.is_empty()
		and effect_status != "effect_rejected"
		and effect_status != "forced_enhance_failure",
		"the execute-result sync must sanitize raw effect reasons in the actual modal view model"
	)
	_finish_flow(effect_flow, effect_owner)
	effect_fixture.registry.instances.clear()
	effect_fixture.codex.clear()


func _verify_auto_route_rng_matches_the_existing_exit() -> void:
	var fixture := _build_fixture()
	var source_owner := FakeOwner.new()
	var source_flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = source_flow
	_expect(source_flow.begin_vertical_slice(source_owner, Callable(), {
		"run_id": "guardian-spring-auto-route-parity",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 10},
		"registry": fixture.registry,
	}), "auto-route parity source must open")
	_expect(
		TowerAscentNodeArrivalTestFixture.advance_to_node_modal(
			source_flow,
			"guardian_spring",
			source_owner
		),
		"auto-route parity source must arrive at the spring"
	)
	var before_ritual := source_flow.export_persistable_snapshot()

	var manual_owner := FakeOwner.new()
	var manual_flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = manual_flow
	_expect(
		manual_flow.restore_snapshot(
			before_ritual,
			Callable(),
			manual_owner,
			fixture.registry
		),
		"manual-exit parity leg must restore"
	)
	var manual_prayer := _find_action_with_prefix(
		manual_flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:prayer:"
	)
	var manual_result := manual_flow.execute_node_action(str(manual_prayer.get("id", "")))
	_expect(bool(manual_result.get("applied", false)), "manual-exit parity prayer must commit")
	_expect(
		bool(manual_flow.call("_try_enter_route_aim_from_node_modal")),
		"manual parity leg must use the existing shared node-modal exit"
	)
	var manual_after := manual_flow.export_snapshot()

	var auto_owner := FakeOwner.new()
	var auto_flow := TowerAscentFlowOwner.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = auto_flow
	_expect(
		auto_flow.restore_snapshot(
			before_ritual,
			Callable(),
			auto_owner,
			fixture.registry
		),
		"auto-exit parity leg must restore"
	)
	var auto_prayer := _find_action_with_prefix(
		auto_flow.get_node_modal_view_model().get("actions", []),
		"guardian_spring:prayer:"
	)
	var auto_result := auto_flow.execute_node_action(str(auto_prayer.get("id", "")))
	_expect(
		str(auto_result.get("message", "")) == "모든 능력치가 3.0%p 상승했다!",
		"auto-route leg must publish the exact prayer receipt before leaving"
	)
	auto_flow.update_selective(0.10, auto_owner)
	_expect(
		auto_flow.get_phase_name() == "NODE_MODAL",
		"the auto route must leave the receipt drawable for at least one selective frame"
	)
	auto_flow.update_selective(0.36, auto_owner)
	_expect(auto_flow.get_phase_name() == "ROUTE_AIM", "the held receipt must auto-enter route aim")
	var auto_after := auto_flow.export_snapshot()
	_expect(
		auto_after.get("gameplay_rng_state", {}) == manual_after.get("gameplay_rng_state", {})
		and auto_flow.get_route_wind_roll_count() == manual_flow.get_route_wind_roll_count()
		and auto_flow.get_route_pickup_roll_count() == manual_flow.get_route_pickup_roll_count()
		and auto_flow.get_route_pickups() == manual_flow.get_route_pickups(),
		"auto and existing exits must advance wind, pickup, and gameplay RNG exactly once in the same order"
	)
	_expect(
		int(auto_flow.get_guardian_spring_presentation_debug_state().get(
			"forced_cleanup_count",
			-1
		)) == 0,
		"auto route must never close an active Spring ritual"
	)
	print("tower_ascent_guardian_spring_node_smoke: forced_cleanup_count=0 rng_parity=true")
	_finish_flow(source_flow, source_owner)
	_finish_flow(manual_flow, manual_owner)
	_finish_flow(auto_flow, auto_owner)
	fixture.registry.instances.clear()
	fixture.codex.clear()


func _verify_actual_egg_reveal_routes_to_tower_owner() -> void:
	var tower_flow := FakeTowerRevealFlow.new()
	var registry := FakeRegistry.new()
	registry.instances["tower_ascent_flow_owner"] = tower_flow
	var runtime := LingpetEggRuntime.new()
	var result_value: Variant = runtime.call("_record_guardian_discovery_at_reveal", "lunabi", registry)
	_expect(result_value is Dictionary and not bool((result_value as Dictionary).get("tower_sealed", true)), "actual egg runtime reveal entry must preserve the overflow route during Tower runs")
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
	_expect(not flow.has_soul_summoning() and fixture.runtime.enhance_calls == 0, "flag OFF must not grant access or touch guardian runtime")
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
	_expect(spring_source.find("OP_SWAP") < 0 and spring_source.find("OP_ABSORB") < 0, "retired sealed swap and absorb operations must be absent")
	_expect(spring_source.find("RandomNumberGenerator.new()") >= 0 and spring_source.find("plaza_") < 0, "spring enhance must isolate RNG and never reuse plaza payment")
	_expect(egg_source.find("_finish_tower_sealed_hatch") < 0 and egg_source.find("activate_tower_sealed_guardian") < 0 and egg_source.find("absorb_tower_sealed_guardian") < 0, "egg runtime must retire sealed storage seams")
	_expect(egg_source.find("begin_main_overflow") >= 0 and egg_source.find("_item_egg_absorb_router.route_absorbed_pet") >= 0, "main and item egg reveals must retain their existing overflow owners")
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
