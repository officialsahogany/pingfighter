extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const PhysiqueTrainingCatalog := preload(
	"res://scripts/characters/physique_training_catalog.gd"
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
const TowerAscentTrainingOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd"
)
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const LanguageSettings := preload(
	"res://scripts/core/language_settings.gd"
)

var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	"training"
)


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "smasher"
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeUnlockStore:
	extends RefCounted

	var allowed_ids: Array[String] = []

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return allowed_ids.is_empty() or allowed_ids.has(content_id)


class FakeRuntimePerkCatalog:
	extends RefCounted

	var choice_calls := 0

	func get_choices(
		_character_type: String,
		runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = RuntimePerkCatalog.BASE_CHOICE_COUNT,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		choice_calls += 1
		return [
			_build_choice("mugong_alpha", "청류심법", runtime_levels),
			_build_choice("mugong_beta", "철벽심법", runtime_levels),
			_build_choice("mugong_gamma", "비연심법", runtime_levels),
		]

	func _build_choice(choice_id: String, display_name: String, levels: Dictionary) -> Dictionary:
		var current_level := int(levels.get(choice_id, 0))
		return {
			"id": choice_id,
			"name": display_name,
			"description": "%s %d단계 효과" % [display_name, current_level + 1],
			"descriptions": {
				1: "%s 1단계 효과" % display_name,
				2: "%s 2단계 효과" % display_name,
				3: "%s 3단계 효과" % display_name,
				4: "%s 4단계 효과" % display_name,
				5: "%s 5단계 효과" % display_name,
			},
			"current_level": current_level,
			"next_level": current_level + 1,
			"max_level": 5,
		}


class FakeRuntimePerkState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var training_counts: Dictionary = {}
	var apply_calls := 0
	var restore_calls := 0
	var allow_apply := true
	var saturated_ids: Array[String] = []

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

	func is_physique_training_saturated(training_id: String, _registry: Object = null) -> bool:
		return saturated_ids.has(training_id)

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
	_verify_no_storage_offer_repeated_choice_cost_curve_and_snapshot()
	_verify_storage_offer_keeps_nonstorage_training_repeatable()
	_verify_finite_maximum_rejection_is_no_op()
	_verify_unlimited_physique_level_contract()
	_verify_saturated_fallback_and_candidate_shortage_boundary()
	_verify_insufficient_muhon_and_grant_rejection_are_no_ops()
	_verify_training_subtitle_locales()
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


func _verify_no_storage_offer_repeated_choice_cost_curve_and_snapshot() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var runtime_state := FakeRuntimePerkState.new()
	var perk_catalog := FakeRuntimePerkCatalog.new()
	var unlock_store := FakeUnlockStore.new()
	unlock_store.allowed_ids.assign([
		"physique_dash_distance",
		"physique_move_speed",
		"physique_paddle_size",
		"physique_max_gauge",
	])
	var registry := _build_registry(runtime_state, perk_catalog, unlock_store)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "training-contract",
		"map_seed": 42,
		"node_modal_kind": "training",
		"run_state": {"muhon": 30, "gold": 0, "chance_gems": 3},
		"registry": registry,
	}), "training fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "training", owner), "training fixture must reach training only after route serve and map arrival")
	var generated := flow.get_generated_training_offers()
	_expect(generated.size() == 1, "one training visit must generate one node-owned offer")
	var offer: Dictionary = generated[0]
	var stat_choices: Array = offer.get("stat_choices", [])
	_expect(stat_choices.size() == 4, "training must present exactly four training cards")
	_expect(
		not _choice_ids(stat_choices).has("physique_storage"),
		"the no-storage fixture must seal repeated training without the storage-only gate"
	)
	_expect((offer.get("mugong_choices", []) as Array).is_empty(), "training must present zero Mugong cards")
	for choice_value in stat_choices:
		_expect(
			choice_value is Dictionary
			and bool((choice_value as Dictionary).get("is_physique_training", false)),
			"every training offer card must come from the physique training catalog"
		)
	var actions: Array = flow.get_node_modal_view_model().get("actions", [])
	_expect(actions.size() == 5, "training modal must expose four training cards plus the shared end-work action")
	_expect(perk_catalog.choice_calls == 0, "training must never query the Mugong choice catalog")

	var stat_action := _find_unlimited_stat_action(actions)
	_expect(not stat_action.is_empty(), "training modal must expose a repeatable training action")
	var choice_id := str(stat_action.get("payload", {}).get("choice_id", ""))
	var initial_choice: Dictionary = stat_action.get("payload", {}).get("choice", {})
	_expect(str(initial_choice.get("level_text", "")) == "Lv.0", "repeatable training must show its live level before purchase")

	var stat_index := _find_action_index(actions, str(stat_action.get("id", "")))
	var stat_rect: Rect2 = (flow.get_node_modal_view_model().get("action_rects", []) as Array)[stat_index]
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = stat_rect.position + Vector2(2.0, 2.0)
	flow.handle_input(press)
	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = press.position
	flow.handle_input(release)
	_expect(bool(flow.get_training_timing_debug_state().get("running", false)), "one mouse press plus release must open exactly one timing gauge")
	_expect(runtime_state.apply_calls == 0, "opening the timing gauge must not commit a training step")
	flow.handle_input(press)
	_expect(runtime_state.apply_calls == 1 and flow.get_training_history().size() == 1, "one timing-stop click must commit exactly one training step")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 29, "one resolved timing judgment must debit exactly one Muhon")

	for purchase_index in range(2, 7):
		var repeated_result := flow.execute_node_action(
			str(stat_action.get("id", "")),
			"training-contract:stat-%d" % purchase_index
		)
		_expect(bool(repeated_result.get("accepted", false)) and bool(repeated_result.get("applied", false)), "same training card purchase %d must commit" % purchase_index)
	var refreshed_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var refreshed_stat := _find_action_by_id(refreshed_actions, str(stat_action.get("id", "")))
	var refreshed_choice: Dictionary = refreshed_stat.get("payload", {}).get("choice", {})
	_expect(bool(refreshed_stat.get("enabled", false)), "repeatable training must remain enabled after six purchases")
	_expect(str(refreshed_choice.get("level_text", "")) == "Lv.6", "training card must refresh to the live level after six purchases")
	_expect(runtime_state.apply_calls == 6 and int(runtime_state.training_counts.get(choice_id, 0)) == 6, "six repeated purchases must apply exactly six training levels")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 18, "six repeated training purchases must debit costs 1, 1, 2, 2, 3, and 3")
	var history: Array[Dictionary] = flow.get_training_history()
	_expect(
		history.size() == 6
		and int(history[0].get("cost", -1)) == 1
		and int(history[1].get("cost", -1)) == 1
		and int(history[2].get("cost", -1)) == 2
		and int(history[3].get("cost", -1)) == 2
		and int(history[4].get("cost", -1)) == 3
		and int(history[5].get("cost", -1)) == 3,
		"training cost must advance as 1, 1, 2, 2, 3, 3 after successful training"
	)

	var duplicate := flow.execute_node_action(str(stat_action.get("id", "")), "training-contract:stat-6")
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("applied", true)), "duplicate node_resolution_id must remain an accepted no-op before grant")
	_expect(runtime_state.apply_calls == 6 and int(flow.get_run_state_snapshot().get("muhon", -1)) == 18, "duplicate transaction must neither grant nor debit")

	var first_training_node_id := str(flow.get("_current_node_id"))
	flow.debug_advance_to_route_aim()
	_expect(
		_advance_route_to_training_node_modal(flow, owner),
		"seed 42 must serve through map transition into its adjacent second training node; first=%s phase=%s wind=%s targets=%s"
		% [first_training_node_id, flow.get_phase_name(), flow.get_route_wind_model(), flow.get_route_aim_targets()]
	)
	var second_training_node_id := str(flow.get("_current_node_id"))
	_expect(
		not first_training_node_id.is_empty()
		and second_training_node_id != first_training_node_id,
		"the reset leg must use two distinct production node ids"
	)
	var second_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var second_stat := _find_unlimited_stat_action(second_actions)
	var second_result := flow.execute_node_action(
		str(second_stat.get("id", "")),
		"training-contract:second-node-first"
	)
	_expect(
		bool(second_result.get("applied", false))
		and int(flow.get_training_history().back().get("cost", -1)) == 1,
		"the first success after production arrival at the next training node must reset to cost 1"
	)
	_expect(
		int(flow.get_run_state_snapshot().get("muhon", -1)) == 17
		and flow.get_training_history().size() == 7,
		"the second training node must debit only its reset cost and append one history record"
	)

	var all_generated := flow.get_generated_training_offers()
	var snapshot := flow.export_persistable_snapshot()
	_expect((snapshot.get("generated_training_offers", []) as Array).size() == 2, "both training-node offers must be part of the stable run snapshot")
	_expect((snapshot.get("training_history", []) as Array).size() == 7, "all repeated and next-node transactions must be part of the run snapshot")
	_expect((snapshot.get("build_state", {}) as Dictionary).has("runtime_perk_snapshot"), "runtime perk build state must use its existing save codec")
	var restored_runtime := FakeRuntimePerkState.new()
	var restored_catalog := FakeRuntimePerkCatalog.new()
	var restored_registry := _build_registry(restored_runtime, restored_catalog)
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot, Callable(), FakeOwner.new(), restored_registry), "stable training snapshot must restore")
	_expect(restored_catalog.choice_calls == 0, "restoring a training node must not query or reroll Mugong choices")
	_expect(var_to_bytes(restored.get_generated_training_offers()) == var_to_bytes(all_generated), "restored training offers must match byte-for-byte")
	_expect(restored_runtime.restore_calls == 1 and restored_runtime.apply_calls == 0, "restore must use the runtime-perk save codec without replaying grants")
	_expect(_sum_dictionary_int_values(restored_runtime.training_counts) == 7, "restore must keep all seven training levels across both production node visits")
	_finish_flow(flow, owner)
	_finish_flow(restored, null)


func _verify_storage_offer_keeps_nonstorage_training_repeatable() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var runtime_state := FakeRuntimePerkState.new()
	var unlock_store := FakeUnlockStore.new()
	unlock_store.allowed_ids.assign([
		"physique_storage",
		"physique_dash_distance",
		"physique_move_speed",
		"physique_paddle_size",
	])
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "training-storage-run-contract",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "training",
		"run_state": {"muhon": 20},
		"registry": _build_registry(runtime_state, FakeRuntimePerkCatalog.new(), unlock_store),
	}), "storage-offer fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "training", owner), "storage-offer fixture must arrive at training")
	var opening_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var storage_action := _find_action_by_id(
		opening_actions,
		"training_stat:physique_storage"
	)
	var nonstorage_actions := _find_nonstorage_training_actions(opening_actions)
	_expect(not storage_action.is_empty(), "storage-offer fixture must expose the storage card")
	_expect(nonstorage_actions.size() == 3, "storage-offer fixture must expose three non-storage cards")
	var first_action: Dictionary = (
		nonstorage_actions[0] if nonstorage_actions.size() > 0 else {}
	)
	var different_action: Dictionary = (
		nonstorage_actions[1] if nonstorage_actions.size() > 1 else {}
	)
	var first_result := flow.execute_node_action(
		str(first_action.get("id", "")),
		"training-storage-run:first"
	)
	_expect(
		bool(first_result.get("applied", false))
		and int(first_result.get("training", {}).get("cost", -1)) == 1,
		"the first non-storage training in a storage offer must commit for one Muhon"
	)
	var after_first_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	_expect(
		_count_enabled_training_actions(after_first_actions) == 4,
		"one arbitrary success must leave every affordable storage-offer card enabled"
	)
	var second_result := flow.execute_node_action(
		str(different_action.get("id", "")),
		"training-storage-run:different"
	)
	_expect(
		bool(second_result.get("applied", false))
		and int(second_result.get("training", {}).get("cost", -1)) == 1,
		"remaining Muhon must allow a different training after the first success"
	)
	var repeated_result := flow.execute_node_action(
		str(first_action.get("id", "")),
		"training-storage-run:repeat"
	)
	_expect(
		bool(repeated_result.get("applied", false))
		and int(repeated_result.get("training", {}).get("cost", -1)) == 2,
		"remaining Muhon must allow the same training to repeat at the next arithmetic cost"
	)
	var pre_storage_history: Array[Dictionary] = flow.get_training_history()
	_expect(
		pre_storage_history.size() == 3
		and int(pre_storage_history[0].get("cost", -1)) == 1
		and int(pre_storage_history[1].get("cost", -1)) == 1
		and int(pre_storage_history[2].get("cost", -1)) == 2,
		"storage-offer successes must advance the shared 1, 1, 2 cost curve"
	)
	var storage_result := flow.execute_node_action(
		str(storage_action.get("id", "")),
		"training-storage-run:storage"
	)
	_expect(
		bool(storage_result.get("applied", false))
		and int(storage_result.get("training", {}).get("cost", -1)) == 2,
		"storage training must remain available until its one run-wide use commits"
	)
	var after_storage_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var storage_after_use := _find_action_by_id(
		after_storage_actions,
		"training_stat:physique_storage"
	)
	_expect(
		not bool(storage_after_use.get("enabled", true))
		and str(storage_after_use.get("disabled_reason", ""))
		== "training_storage_run_limit",
		"only the storage card must disable after its run-wide use"
	)
	_expect(
		_count_enabled_training_actions(after_storage_actions) == 3,
		"using storage must leave all three non-storage cards enabled"
	)
	var prepared_rejection: Dictionary = flow.call(
		"_prepare_training_timing_action",
		"training_stat:physique_storage",
		"training-storage-run:prepared-block"
	)
	_expect(
		not bool(prepared_rejection.get("prepared", true))
		and str(prepared_rejection.get("reason", ""))
		== "training_storage_run_limit",
		"the timing prepare path must reject a stale second storage-card use"
	)
	var balance_before_storage_rejection := int(
		flow.get_run_state_snapshot().get("muhon", -1)
	)
	var storage_rejection := flow.execute_node_action(
		"training_stat:physique_storage",
		"training-storage-run:execute-block"
	)
	_expect(
		str(storage_rejection.get("reason", "")) == "training_storage_run_limit",
		"direct execution must reject only a second storage-card use"
	)
	_expect(
		runtime_state.apply_calls == 4
		and flow.get_training_history().size() == 4
		and int(flow.get_run_state_snapshot().get("muhon", -1))
		== balance_before_storage_rejection,
		"a rejected second storage use must not grant, debit, or append history"
	)
	var after_storage_repeat := flow.execute_node_action(
		str(first_action.get("id", "")),
		"training-storage-run:after-storage"
	)
	_expect(
		bool(after_storage_repeat.get("applied", false))
		and int(after_storage_repeat.get("training", {}).get("cost", -1)) == 3
		and int(flow.get_run_state_snapshot().get("muhon", -1)) == 11,
		"non-storage training must continue after storage at the fifth-success cost"
	)
	var snapshot := flow.export_persistable_snapshot()
	var restored_runtime := FakeRuntimePerkState.new()
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(
		snapshot,
		Callable(),
		FakeOwner.new(),
		_build_registry(restored_runtime, FakeRuntimePerkCatalog.new(), unlock_store)
	), "storage-run snapshot must restore")
	var restored_actions: Array = restored.get_node_modal_view_model().get("actions", [])
	var restored_storage := _find_action_by_id(
		restored_actions,
		"training_stat:physique_storage"
	)
	_expect(
		not bool(restored_storage.get("enabled", true))
		and str(restored_storage.get("disabled_reason", ""))
		== "training_storage_run_limit"
		and _count_enabled_training_actions(restored_actions) == 3,
		"snapshot restore must preserve only the run-wide storage-card gate"
	)
	var legacy_snapshot := snapshot.duplicate(true)
	var legacy_offer: Dictionary = (
		(legacy_snapshot.get("generated_training_offers", []) as Array)[0] as Dictionary
	).duplicate(true)
	var legacy_choices: Array[Dictionary] = []
	var storage_choice: Dictionary = {}
	for choice_value: Variant in legacy_offer.get("stat_choices", []):
		if not (choice_value is Dictionary):
			continue
		var legacy_choice: Dictionary = choice_value
		if str(legacy_choice.get("id", "")) == "physique_storage":
			storage_choice = legacy_choice.duplicate(true)
		else:
			legacy_choices.append(legacy_choice.duplicate(true))
	var physique_catalog := PhysiqueTrainingCatalog.new()
	legacy_choices.append(physique_catalog.build_card("physique_max_gauge", 0))
	legacy_choices.append(physique_catalog.build_card("physique_hit_gauge", 0))
	legacy_choices.append(storage_choice)
	legacy_offer["offer_version"] = TowerAscentTrainingOfferBuilder.MIXED_REWARD_OFFER_VERSION
	legacy_offer["stat_choices"] = legacy_choices
	legacy_snapshot["generated_training_offers"] = [legacy_offer]
	var legacy_restored := TowerAscentFlowOwner.new()
	_expect(legacy_restored.restore_snapshot(
		legacy_snapshot,
		Callable(),
		FakeOwner.new(),
		_build_registry(FakeRuntimePerkState.new(), FakeRuntimePerkCatalog.new(), unlock_store)
	), "legacy six-card storage-offer snapshot must restore")
	var migrated_offers := legacy_restored.get_generated_training_offers()
	var migrated_offer: Dictionary = migrated_offers[0] if migrated_offers.size() == 1 else {}
	_expect(
		str(migrated_offer.get("offer_version", ""))
		== TowerAscentTrainingOfferBuilder.TRAINING_OFFER_VERSION
		and str(migrated_offer.get("migration", "")) == "legacy_v2_four_card"
		and (migrated_offer.get("stat_choices", []) as Array).size() == 4
		and _choice_ids(migrated_offer.get("stat_choices", [])).has("physique_storage"),
		"legacy v2 six-card offer must migrate without rerolling away its storage presence"
	)
	var legacy_actions: Array = legacy_restored.get_node_modal_view_model().get("actions", [])
	var legacy_storage := _find_action_by_id(
		legacy_actions,
		"training_stat:physique_storage"
	)
	_expect(
		not bool(legacy_storage.get("enabled", true))
		and str(legacy_storage.get("disabled_reason", ""))
		== "training_storage_run_limit"
		and _count_enabled_training_actions(legacy_actions) == 3,
		"legacy offer migration must keep only the previously used storage card blocked"
	)
	_finish_flow(flow, owner)
	_finish_flow(restored, null)
	_finish_flow(legacy_restored, null)


func _verify_finite_maximum_rejection_is_no_op() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var runtime_state := FakeRuntimePerkState.new()
	runtime_state.training_counts["physique_storage"] = 4
	var unlock_store := FakeUnlockStore.new()
	unlock_store.allowed_ids.assign([
		"physique_storage",
		"physique_dash_distance",
		"physique_move_speed",
		"physique_paddle_size",
	])
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "training-maximum",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "training",
		"run_state": {"muhon": 10},
		"registry": _build_registry(runtime_state, FakeRuntimePerkCatalog.new(), unlock_store),
	}), "finite-maximum fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "training", owner), "finite-maximum fixture must arrive at training")
	var action_id := "training_stat:physique_storage"
	var before := _find_action_by_id(flow.get_node_modal_view_model().get("actions", []), action_id)
	_expect(str(before.get("payload", {}).get("choice", {}).get("level_text", "")) == "4/5", "finite training must expose the pre-maximum level")
	var final_purchase := flow.execute_node_action(action_id, "training-maximum:final")
	_expect(bool(final_purchase.get("accepted", false)) and bool(final_purchase.get("applied", false)), "finite training final level must commit")
	var maximum_action := _find_action_by_id(flow.get_node_modal_view_model().get("actions", []), action_id)
	_expect(not bool(maximum_action.get("enabled", true)), "storage training must disable after its run-wide use")
	_expect(str(maximum_action.get("disabled_reason", "")) == "training_storage_run_limit", "the storage-only run gate must take precedence after the successful final level")
	_expect(str(maximum_action.get("payload", {}).get("choice", {}).get("level_text", "")) == "5/5", "finite training maximum card must show current and maximum")
	var muhon_before_rejection := int(flow.get_run_state_snapshot().get("muhon", -1))
	var rejected := flow.execute_node_action(action_id, "training-maximum:blocked")
	_expect(str(rejected.get("reason", "")) == "training_storage_run_limit", "direct execution must reject a second storage use in the same run")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == muhon_before_rejection and runtime_state.apply_calls == 1, "finite-maximum rejection must not grant or debit")
	_finish_flow(flow, owner)


func _verify_unlimited_physique_level_contract() -> void:
	var catalog := PhysiqueTrainingCatalog.new()
	var builder := TowerAscentTrainingOfferBuilder.new()
	var runtime_state := FakeRuntimePerkState.new()
	for training_id in [
		"physique_dash_distance",
		"physique_move_speed",
		"physique_paddle_size",
		"physique_max_gauge",
		"physique_hit_gauge",
	]:
		_expect(int(catalog.get_max_count(training_id)) == -1, "%s must retain the canonical unlimited max_count" % training_id)
		runtime_state.training_counts[training_id] = 7
		var projected: Dictionary = builder.build_live_choice_projection(
			"stat",
			catalog.build_card(training_id, 7),
			runtime_state
		)
		_expect(str(projected.get("level_text", "")) == "Lv.7", "%s must show current level only" % training_id)
		_expect(not str(projected.get("level_text", "")).contains("/"), "%s must not invent a maximum label" % training_id)
		_expect(not builder.is_live_choice_at_maximum("stat", projected, runtime_state), "%s must remain repeatable without a canonical maximum" % training_id)
	var storage_id := "physique_storage"
	runtime_state.training_counts[storage_id] = 2
	var storage_projection: Dictionary = builder.build_live_choice_projection(
		"stat",
		catalog.build_card(storage_id, 2),
		runtime_state
	)
	_expect(str(storage_projection.get("level_text", "")) == "2/5", "finite storage training must show current and canonical maximum")


func _verify_saturated_fallback_and_candidate_shortage_boundary() -> void:
	var builder := TowerAscentTrainingOfferBuilder.new()
	var runtime_state := FakeRuntimePerkState.new()
	var saturated_store := FakeUnlockStore.new()
	saturated_store.allowed_ids.assign([
		"physique_storage",
		"physique_dash_distance",
		"physique_move_speed",
		"physique_paddle_size",
	])
	runtime_state.training_counts["physique_storage"] = 5
	runtime_state.saturated_ids.append("physique_storage")
	var saturated_offer: Dictionary = builder.build_offer(
		"training-saturated-fill",
		17,
		FakeOwner.new(),
		_build_registry(runtime_state, FakeRuntimePerkCatalog.new(), saturated_store),
		TowerAscentTrainingOfferBuilder.OFFER_KIND_TRAINING
	)
	var saturated_choices: Array = saturated_offer.get("stat_choices", [])
	_expect(bool(saturated_offer.get("accepted", false)), "one saturated training must not collapse a four-card storefront")
	_expect(saturated_choices.size() == 4, "saturated fallback must preserve exactly four cards")
	_expect(_choice_ids(saturated_choices).has("physique_storage"), "saturated fallback must retain the disabled finite training card when it is needed to fill four slots")

	var shortage_store := FakeUnlockStore.new()
	shortage_store.allowed_ids.assign([
		"physique_dash_distance",
		"physique_move_speed",
		"physique_paddle_size",
	])
	var shortage_offer: Dictionary = builder.build_offer(
		"training-shortage",
		17,
		FakeOwner.new(),
		_build_registry(FakeRuntimePerkState.new(), FakeRuntimePerkCatalog.new(), shortage_store),
		TowerAscentTrainingOfferBuilder.OFFER_KIND_TRAINING
	)
	_expect(not bool(shortage_offer.get("accepted", true)), "fewer than four unlocked trainings must fail closed instead of showing a partial storefront")
	_expect(str(shortage_offer.get("reason", "")) == "insufficient_training_candidates", "candidate shortage must expose its distinct reason")
	_expect(int(shortage_offer.get("candidate_count", -1)) == 3, "candidate shortage must report the three available training cards")


func _verify_insufficient_muhon_and_grant_rejection_are_no_ops() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var poor_runtime := FakeRuntimePerkState.new()
	var poor_flow := TowerAscentFlowOwner.new()
	var poor_owner := FakeOwner.new()
	_expect(poor_flow.begin_vertical_slice(poor_owner, Callable(), {
		"run_id": "training-poor",
		"map_seed": _initial_route_seed,
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
		"map_seed": _initial_route_seed,
		"node_modal_kind": "training",
		"run_state": {"muhon": 30},
		"registry": _build_registry(rejected_runtime, FakeRuntimePerkCatalog.new()),
	}), "grant-rejection fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(rejected_flow, "training", rejected_owner), "grant-rejection fixture must arrive at training")
	var rejected_action := _find_action_with_prefix(rejected_flow.get_node_modal_view_model().get("actions", []), "training_stat:")
	var rejected_result := rejected_flow.execute_node_action(str(rejected_action.get("id", "")), "training-rejected:attempt")
	_expect(str(rejected_result.get("reason", "")) == "effect_rejected", "runtime grant rejection must surface before payment")
	_expect(int(rejected_flow.get_run_state_snapshot().get("muhon", -1)) == 30 and rejected_flow.get_training_history().is_empty(), "failed runtime grant must not debit or emit transaction history")
	_finish_flow(rejected_flow, rejected_owner)


func _verify_training_subtitle_locales() -> void:
	var expected := {
		LanguageSettings.LANGUAGE_KOREAN: "무혼을 다듬어 몸을 수련합니다.",
		LanguageSettings.LANGUAGE_ENGLISH: "Refine your body through focused training.",
		LanguageSettings.LANGUAGE_CHINESE: "锤炼体魄，精进根基。",
		LanguageSettings.LANGUAGE_JAPANESE: "身体を鍛え、基礎を磨きます。",
		LanguageSettings.LANGUAGE_SPANISH: "Fortalece el cuerpo mediante el entrenamiento.",
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Fortaleça o corpo por meio do treinamento.",
		LanguageSettings.LANGUAGE_RUSSIAN: "Закаляйте тело упорными тренировками.",
	}
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var subtitle := TowerAscentNodeModalLocalization.node_description("training")
		_expect(subtitle == str(expected.get(locale, "")), "%s training subtitle must use its registered locale copy" % locale)
		_expect(not subtitle.contains("—"), "%s training subtitle must not contain an em dash" % locale)
	LanguageSettings.set_test_locale_override("")


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
	var tuning_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_tuning.gd")
	_expect(flow_source.find("apply_choice") >= 0 and flow_source.find("build_unlock_save_snapshot") >= 0, "training must reuse the existing runtime perk grant and save boundaries")
	_expect(builder_source.find("OFFER_KIND_TRAINING") >= 0 and builder_source.find("OFFER_KIND_MIXED_REWARD") >= 0, "shared builder consumers must declare training-only versus mixed reward intent")
	_expect(builder_source.contains('TRAINING_OFFER_VERSION := "tower_training_offer_v3"') and builder_source.contains('MIXED_REWARD_OFFER_VERSION := "tower_training_offer_v2"'), "training migration must not advance the shared Z16 mixed-reward version")
	_expect(builder_source.find("TRAINING_CARD_COUNT := 4") >= 0 and builder_source.find("PhysiqueTrainingCatalog") >= 0, "training must use four cards from the physique catalog")
	_expect(flow_source.find("TowerAscentTrainingOfferBuilder.OFFER_KIND_TRAINING") >= 0, "production training flow must request the training-only builder lane")
	_expect(flow_source.find('var prefix := "training_stat:"') >= 0 and flow_source.find('"training_mugong:"') < 0, "training execution must accept only stat action ids")
	_expect(tuning_source.contains("TEMP_PHASE_C_TRAINING_STAT_BASE_COST := 1"), "training cost must retain its Tower tuning base")
	_expect(tuning_source.contains("TEMP_PHASE_C_TRAINING_STAT_COST_STEP_SUCCESSES := 2"), "training cost must advance every two successes")
	_expect(
		flow_source.contains("_is_storage_training_used_this_run")
		and flow_source.contains("training_storage_run_limit"),
		"display, prepare, and execution paths must share the storage-only run gate"
	)
	_expect(
		not flow_source.contains("_is_training_visit_complete")
		and not flow_source.contains("training_visit_complete"),
		"the defective whole-visit completion concept must stay removed"
	)


func _build_registry(
	runtime_state: Object,
	perk_catalog: Object,
	unlock_store: Object = null
) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": perk_catalog,
		TowerAscentUnlockFilter.STORE_KEY: (
			unlock_store
			if unlock_store != null
			else FakeUnlockStore.new()
		),
	}
	return registry


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")).begins_with(prefix):
			return action_value as Dictionary
	return {}


func _find_action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")) == action_id:
			return action_value as Dictionary
	return {}


func _find_unlimited_stat_action(actions: Array) -> Dictionary:
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		var choice: Dictionary = action.get("payload", {}).get("choice", {})
		if (
			str(action.get("id", "")).begins_with("training_stat:")
			and int(choice.get("training_max_count", 0)) < 0
		):
			return action
	return {}


func _find_nonstorage_training_actions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		var action_id := str(action.get("id", ""))
		if (
			action_id.begins_with("training_stat:")
			and action_id != "training_stat:physique_storage"
		):
			result.append(action)
	return result


func _count_enabled_training_actions(actions: Array) -> int:
	var result := 0
	for action_value in actions:
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("id", "")).begins_with("training_stat:")
			and bool((action_value as Dictionary).get("enabled", false))
		):
			result += 1
	return result


func _choice_ids(choices: Array) -> Array[String]:
	var result: Array[String] = []
	for choice_value in choices:
		if choice_value is Dictionary:
			result.append(str((choice_value as Dictionary).get("id", "")))
	return result


func _sum_dictionary_int_values(values: Dictionary) -> int:
	var total := 0
	for value: Variant in values.values():
		total += int(value)
	return total


func _advance_route_to_training_node_modal(flow: Object, owner: Object) -> bool:
	if flow == null or flow.get_phase_name() != "ROUTE_AIM":
		return false
	var target_index := -1
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == "training":
			target_index = index
			break
	if target_index < 0:
		return false
	var route_runtime: Object = flow.get("_route_serve_runtime")
	if (
		route_runtime == null
		or not bool(route_runtime.begin(
			owner,
			flow.get("_active_registry"),
			TowerAscentRouteWindPolicy.calm_model()
		).get("accepted", false))
	):
		return false
	flow.debug_launch_at_target(target_index)
	for _flight_step in range(120):
		flow.update_selective(0.1, owner)
		if flow.get_phase_name() == "MAP_TRANSITION":
			break
	if flow.get_phase_name() != "MAP_TRANSITION":
		return false
	for _transition_step in range(80):
		flow.update_selective(0.1, owner)
		if flow.get_phase_name() == "NODE_MODAL":
			break
	return (
		flow.get_phase_name() == "NODE_MODAL"
		and flow.get_node_modal_kind() == "training"
	)


func _find_action_index(actions: Array, action_id: String) -> int:
	for index in range(actions.size()):
		if actions[index] is Dictionary and str((actions[index] as Dictionary).get("id", "")) == action_id:
			return index
	return -1


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
