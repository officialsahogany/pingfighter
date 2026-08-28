extends SceneTree

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
const TowerAscentPerkCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	"fallen_monk"
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

	var locked_ids: Dictionary = {}

	func set_unlocked(content_id: String, unlocked: bool) -> void:
		if unlocked:
			locked_ids.erase(content_id)
		else:
			locked_ids[content_id] = true

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return not locked_ids.has(content_id)


class FakeSkillConfig:
	extends RefCounted

	var equipped_skills: Array = ["base_skill"]
	var max_slots := 2
	var known_skills := {
		"base_skill": {"korean": "기본 초식"},
		"alpha_skill": {"korean": "청류 초식"},
		"beta_skill": {"korean": "철벽 초식"},
		"gamma_skill": {"korean": "비연 초식"},
		"delta_skill": {"korean": "월광 초식"},
	}

	func get_snapshot() -> Dictionary:
		return {"equipped_skills": equipped_skills.duplicate()}

	func get_skill_data(skill_id: String) -> Dictionary:
		var value: Variant = known_skills.get(skill_id, {})
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}

	func is_skill_equipped(skill_id: String) -> bool:
		return equipped_skills.has(skill_id)

	func is_shared_slot_full() -> bool:
		return equipped_skills.size() >= max_slots

	func get_shared_slot_swap_candidates(skill_id: String) -> Array:
		if not known_skills.has(skill_id) or equipped_skills.has(skill_id):
			return []
		return equipped_skills.duplicate()

	func unlock_and_equip_skill(skill_id: String) -> bool:
		if not known_skills.has(skill_id):
			return false
		if equipped_skills.has(skill_id):
			return true
		if is_shared_slot_full():
			return false
		equipped_skills.append(skill_id)
		return true

	func unequip_skill(skill_id: String) -> bool:
		if not equipped_skills.has(skill_id):
			return false
		equipped_skills.erase(skill_id)
		return true


class FakeRuntimePerkCatalog:
	extends RefCounted

	var all_calls := 0
	var data := {
		"mugong_alpha": _mugong("mugong_alpha", "Mugong Alpha"),
		"mugong_beta": _mugong("mugong_beta", "Mugong Beta"),
		"mugong_gamma": _mugong("mugong_gamma", "Mugong Gamma"),
		"mugong_locked": _mugong("mugong_locked", "Locked Mugong"),
		"unlock_alpha": _choice("unlock_alpha", "청류 비급", "alpha_skill"),
		"unlock_beta": _choice("unlock_beta", "철벽 비급", "beta_skill"),
		"unlock_gamma": _choice("unlock_gamma", "비연 비급", "gamma_skill"),
		"unlock_delta": _choice("unlock_delta", "월광 비급", "delta_skill"),
	}

	static func _choice(perk_id: String, display_name: String, skill_id: String) -> Dictionary:
		return {
			"id": perk_id,
			"name": display_name,
			"unlocks_skill": skill_id,
			"character_restriction": "smasher",
			"max_level": 1,
		}

	static func _mugong(perk_id: String, display_name: String) -> Dictionary:
		return {
			"id": perk_id,
			"name": display_name,
			"character_restriction": "smasher",
			"max_level": 5,
		}

	func get_all_perk_data() -> Dictionary:
		all_calls += 1
		return data.duplicate(true)

	func get_perk_data(perk_id: String) -> Dictionary:
		var value: Variant = data.get(perk_id, {})
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}

	func count_owned_slot_perks(runtime_levels: Dictionary, _slot_context: Object = null) -> int:
		var count := 0
		for level_value in runtime_levels.values():
			if int(level_value) > 0:
				count += 1
		return count

	func get_perk_slot_limit(_runtime_levels: Dictionary, _slot_context: Object = null) -> int:
		return 6

	func get_perk_slot_apply_status(
		perk_data: Dictionary,
		runtime_levels: Dictionary,
		slot_context: Object = null,
		target_level: int = -1
	) -> Dictionary:
		var perk_id := str(perk_data.get("id", ""))
		var current_level := int(runtime_levels.get(perk_id, 0))
		var next_level := target_level if target_level >= 0 else current_level + 1
		var slot_free := not str(perk_data.get("unlocks_skill", "")).is_empty()
		var extra_slots := 0 if slot_free or current_level > 0 or next_level <= 0 else 1
		var count := count_owned_slot_perks(runtime_levels, slot_context)
		var accepted := extra_slots == 0 or count + extra_slots <= 6
		return {
			"accepted": accepted,
			"blocked_reason": "" if accepted else RuntimePerkCatalog.PERK_SLOT_LIMIT_BLOCKED_REASON,
			"extra_slots": extra_slots,
			"occupied_slots": count,
			"slot_limit": 6,
		}


class FakeRuntimePerkState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var pending_swap: Dictionary = {}
	var selected_swap_index := 0
	var apply_calls := 0
	var confirm_calls := 0
	var cancel_calls := 0
	var restore_calls := 0
	var force_confirm_failure := false
	var skill_config: FakeSkillConfig
	var catalog: FakeRuntimePerkCatalog

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass

	func apply_choice(choice: Dictionary, _owner: Object, registry: Object) -> bool:
		var perk_id := str(choice.get("id", ""))
		var unlocked_skill := str(choice.get("unlocks_skill", ""))
		if perk_id.is_empty():
			return false
		var status: Dictionary = catalog.get_perk_slot_apply_status(
			choice,
			runtime_skill_levels,
			registry
		)
		if not bool(status.get("accepted", false)):
			return false
		apply_calls += 1
		if unlocked_skill.is_empty():
			runtime_skill_levels[perk_id] = int(runtime_skill_levels.get(perk_id, 0)) + 1
			return true
		if skill_config.is_shared_slot_full():
			var candidates: Array[Dictionary] = []
			for skill_value in skill_config.get_shared_slot_swap_candidates(unlocked_skill):
				var skill_id := str(skill_value)
				candidates.append({
					"skill_id": skill_id,
					"name": str(skill_config.get_skill_data(skill_id).get("korean", skill_id)),
				})
			pending_swap = {
				"choice": choice.duplicate(true),
				"choice_id": perk_id,
				"unlocks_skill": unlocked_skill,
				"candidates": candidates,
			}
			selected_swap_index = 0
			return false
		if not skill_config.unlock_and_equip_skill(unlocked_skill):
			return false
		runtime_skill_levels[perk_id] = 1
		return true

	func has_pending_unlock_swap() -> bool:
		return not pending_swap.is_empty()

	func get_pending_unlock_swap() -> Dictionary:
		return pending_swap.duplicate(true)

	func move_unlock_swap_selection(delta_index: int) -> void:
		var candidates: Array = pending_swap.get("candidates", [])
		if not candidates.is_empty():
			selected_swap_index = posmod(selected_swap_index + delta_index, candidates.size())

	func confirm_pending_unlock_swap(_owner: Object, _registry: Object) -> bool:
		if pending_swap.is_empty():
			return false
		if force_confirm_failure:
			return false
		var candidates: Array = pending_swap.get("candidates", [])
		if candidates.is_empty():
			return false
		var removed_skill := str((candidates[selected_swap_index] as Dictionary).get("skill_id", ""))
		var unlocked_skill := str(pending_swap.get("unlocks_skill", ""))
		if not skill_config.unequip_skill(removed_skill):
			return false
		if not skill_config.unlock_and_equip_skill(unlocked_skill):
			skill_config.unlock_and_equip_skill(removed_skill)
			return false
		for perk_id_value in runtime_skill_levels.keys():
			var perk_id := str(perk_id_value)
			if str(catalog.get_perk_data(perk_id).get("unlocks_skill", "")) == removed_skill:
				runtime_skill_levels.erase(perk_id)
				break
		runtime_skill_levels[str(pending_swap.get("choice_id", ""))] = 1
		pending_swap.clear()
		confirm_calls += 1
		return true

	func cancel_pending_unlock_swap(_owner: Object = null) -> bool:
		if pending_swap.is_empty():
			return false
		pending_swap.clear()
		cancel_calls += 1
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {
			"version": 1,
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
		}

	func apply_unlock_save_snapshot(
		snapshot: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		var levels_value: Variant = snapshot.get("runtime_skill_levels", null)
		if not (levels_value is Dictionary):
			return {"restored": false}
		runtime_skill_levels = (levels_value as Dictionary).duplicate(true)
		restore_calls += 1
		return {"restored": true}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	_verify_shared_candidate_policy_filters_locked_mugong()
	_verify_acquire_swap_remove_transactions_and_snapshot()
	_verify_swap_rejection_rolls_back_without_payment()
	_verify_insufficient_muhon_is_a_no_op()
	_verify_mugong_slot_budget_rechecks_fixed_offer()
	_verify_six_of_six_chosik_uses_swap_gate()
	_verify_flag_off_is_untouched()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()

	if _failures.is_empty():
		print("tower_ascent_fallen_monk_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shared_candidate_policy_filters_locked_mugong() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	(fixture.unlock_store as FakeUnlockStore).set_unlocked("mugong_locked", false)
	var locked_data := (fixture.catalog as FakeRuntimePerkCatalog).get_perk_data(
		"mugong_locked"
	)
	var policy := TowerAscentPerkCandidatePolicy.new()
	_expect(
		not policy.is_mugong_candidate(
			locked_data,
			{},
			"smasher",
			fixture.registry
		),
		"shared candidate policy must reject a locked Mugong"
	)


func _verify_acquire_swap_remove_transactions_and_snapshot() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	(fixture.unlock_store as FakeUnlockStore).set_unlocked("mugong_locked", false)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-contract",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40, "gold": 0, "chance_gems": 3},
		"registry": fixture.registry,
	}), "fallen-monk fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner), "fallen-monk fixture must reach the monk only after route serve and map arrival")
	var offers := flow.get_generated_fallen_monk_offers()
	_expect(offers.size() == 1, "one monk visit must own one generated offer")
	_expect((offers[0].get("choices", []) as Array).size() == 6, "monk storefront must present exactly six Mugong and Chosik cards")
	_expect(
		not _choice_ids(offers[0].get("choices", [])).has("mugong_locked"),
		"monk Mugong offers must pass the shared unlock filter"
	)
	_expect(fixture.catalog.all_calls == 1, "monk offer must generate once per node")
	var acquire_action := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:acquire:"
	)
	_expect(not acquire_action.is_empty(), "an open Chosik slot must expose acquisition")
	var acquire_id := "fallen-monk-contract:acquire"
	var acquire_result := flow.execute_node_action(str(acquire_action.get("id", "")), acquire_id)
	_expect(bool(acquire_result.get("accepted", false)) and bool(acquire_result.get("applied", false)), "acquisition must commit through the node transaction")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 37, "acquisition must debit the unified three-Muhon price")
	_expect(fixture.runtime_state.apply_calls == 1 and fixture.skill_config.equipped_skills.size() == 2, "acquisition must reuse runtime_perk_state.apply_choice")

	var acquired_skill := str((acquire_result.get("record", {}) as Dictionary).get("unlocked_skill", ""))
	var swap_action := _find_swap_action_for_removed_skill(
		flow.get_node_modal_view_model().get("actions", []),
		acquired_skill
	)
	_expect(not swap_action.is_empty(), "a full Chosik slot must expose the existing swap candidates")
	var duplicate := flow.execute_node_action(str(swap_action.get("id", "")), acquire_id)
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("applied", true)), "same node_resolution_id must be an accepted no-op before swap effect")
	_expect(fixture.runtime_state.apply_calls == 1 and int(flow.get_run_state_snapshot().get("muhon", -1)) == 37, "duplicate resolution must neither swap nor debit")

	var swap_result := flow.execute_node_action(
		str(swap_action.get("id", "")),
		"fallen-monk-contract:swap"
	)
	_expect(bool(swap_result.get("accepted", false)) and bool(swap_result.get("applied", false)), "swap must commit through the existing pending-swap flow")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 33, "swap must debit the unified four-Muhon price")
	_expect(fixture.runtime_state.apply_calls == 2 and fixture.runtime_state.confirm_calls == 1, "swap must call apply_choice then confirm_pending_unlock_swap")
	var remaining_swap := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:swap:"
	)
	_expect(not remaining_swap.is_empty() and bool(remaining_swap.get("enabled", false)), "another stocked Chosik must remain purchasable without a visit cap")

	var remove_action := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:remove:"
	)
	_expect(not remove_action.is_empty(), "an acquired equipped Chosik must expose removal")
	var remove_result := flow.execute_node_action(
		str(remove_action.get("id", "")),
		"fallen-monk-contract:remove"
	)
	_expect(bool(remove_result.get("accepted", false)) and bool(remove_result.get("applied", false)), "remove must commit atomically")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 28, "remove must debit the unified five-Muhon price and stay more expensive than acquisition")
	_expect(fixture.runtime_state.runtime_skill_levels.is_empty() and fixture.skill_config.equipped_skills == ["base_skill"], "remove must clear both equipped Chosik and its runtime unlock")
	_expect(flow.get_fallen_monk_history().size() == 3, "visit history must own one acquisition, one swap, and one removal")
	var remaining_acquire := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:acquire:"
	)
	_expect(not remaining_acquire.is_empty() and bool(remaining_acquire.get("enabled", false)), "another stocked acquisition must remain available without a visit cap")

	var snapshot := flow.export_persistable_snapshot()
	_expect((snapshot.get("generated_fallen_monk_offers", []) as Array).size() == 1, "monk offer must be in the stable run snapshot")
	_expect((snapshot.get("fallen_monk_history", []) as Array).size() == 3, "monk transaction history must be in the stable run snapshot")
	_expect(not (snapshot.get("fallen_monk_runtime_snapshot", {}) as Dictionary).is_empty(), "runtime unlock snapshot must be persisted")
	_expect(not (snapshot.get("fallen_monk_skill_config_snapshot", {}) as Dictionary).is_empty(), "equipped Chosik snapshot must be persisted")

	var restored_fixture := _build_fixture()
	restored_fixture.runtime_state.runtime_skill_levels = {"stale_unlock": 1}
	restored_fixture.skill_config.equipped_skills = ["base_skill", "delta_skill"]
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot, Callable(), FakeOwner.new(), restored_fixture.registry), "stable monk snapshot must restore")
	_expect(restored_fixture.catalog.all_calls == 0, "restoring a monk node must not reroll its offers")
	_expect(var_to_bytes(restored.get_generated_fallen_monk_offers()) == var_to_bytes(offers), "restored monk offers must match byte-for-byte")
	_expect(restored_fixture.runtime_state.restore_calls >= 1 and restored_fixture.runtime_state.runtime_skill_levels.is_empty(), "restore must apply the saved runtime unlock state")
	_expect(restored_fixture.skill_config.equipped_skills == ["base_skill"], "restore must apply the saved equipped Chosik state")
	_finish_flow(flow, owner)
	_finish_flow(restored, null)


func _verify_swap_rejection_rolls_back_without_payment() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-rollback",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40},
		"registry": fixture.registry,
	}), "swap-rollback fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner), "swap-rollback fixture must arrive at the monk")
	var acquire_action := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:acquire:"
	)
	var acquire_result := flow.execute_node_action(
		str(acquire_action.get("id", "")),
		"fallen-monk-rollback:acquire"
	)
	var acquired_skill := str((acquire_result.get("record", {}) as Dictionary).get("unlocked_skill", ""))
	var levels_before: Dictionary = fixture.runtime_state.runtime_skill_levels.duplicate(true)
	var equipped_before: Array = fixture.skill_config.equipped_skills.duplicate()
	fixture.runtime_state.force_confirm_failure = true
	var swap_action := _find_swap_action_for_removed_skill(
		flow.get_node_modal_view_model().get("actions", []),
		acquired_skill
	)
	var rejected := flow.execute_node_action(
		str(swap_action.get("id", "")),
		"fallen-monk-rollback:swap"
	)
	_expect(str(rejected.get("reason", "")) == "effect_rejected", "failed existing swap confirmation must reject before payment")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 37, "failed swap must not debit Muhon")
	_expect(fixture.runtime_state.runtime_skill_levels == levels_before and fixture.skill_config.equipped_skills == equipped_before, "failed swap must restore runtime unlocks and equipped Chosik")
	_expect(not fixture.runtime_state.has_pending_unlock_swap() and fixture.runtime_state.cancel_calls == 1, "failed swap must clear the pending existing swap")
	_expect(flow.get_fallen_monk_history().size() == 1, "failed swap must not append transaction history")
	_finish_flow(flow, owner)


func _verify_insufficient_muhon_is_a_no_op() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-poor",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 2},
		"registry": fixture.registry,
	}), "insufficient-Muhon fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner), "insufficient-Muhon fixture must arrive at the monk")
	var action := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:acquire:"
	)
	_expect(not bool(action.get("enabled", true)), "insufficient Muhon must disable acquisition")
	var reason := str(action.get("unavailable_reason", ""))
	_expect(reason.contains("3") and reason.contains("1"), "disabled acquisition must show required Muhon and exact shortfall")
	var result := flow.execute_node_action(str(action.get("id", "")), "fallen-monk-poor:attempt")
	_expect(not bool(result.get("accepted", true)), "insufficient Muhon must reject direct execution before transaction")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 2 and fixture.runtime_state.apply_calls == 0 and flow.get_fallen_monk_history().is_empty(), "insufficient Muhon must issue no debit, grant, or history")
	_finish_flow(flow, owner)


func _verify_mugong_slot_budget_rechecks_fixed_offer() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	fixture.runtime_state.runtime_skill_levels = {
		"owned_slot_1": 1,
		"owned_slot_2": 1,
		"owned_slot_3": 1,
		"owned_slot_4": 1,
		"owned_slot_5": 1,
	}
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-slot-budget",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40},
		"registry": fixture.registry,
	}), "slot-budget monk fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner), "slot-budget monk fixture must arrive at the fixed storefront")
	var initial_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var mugong_actions: Array[Dictionary] = []
	for action_value in initial_actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")).begins_with("fallen_monk:mugong:"):
			mugong_actions.append(action_value as Dictionary)
	_expect(mugong_actions.size() >= 2, "fixed monk offer must retain multiple Mugong cards for the recheck leg")
	for action in mugong_actions:
		_expect(bool(action.get("enabled", false)), "each fixed Mugong card must begin enabled at 5/6")
	var first_action := mugong_actions[0]
	var first_result := flow.execute_node_action(
		str(first_action.get("id", "")),
		"fallen-monk-slot-budget:first"
	)
	_expect(bool(first_result.get("accepted", false)) and bool(first_result.get("applied", false)), "first Mugong purchase must fill the sixth slot")
	_expect(fixture.catalog.count_owned_slot_perks(fixture.runtime_state.runtime_skill_levels, fixture.registry) == 6, "first fixed-offer purchase must end at 6/6")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 38, "first Mugong purchase must debit exactly once")
	var refreshed_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var blocked_action := {}
	for action_value in refreshed_actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")).begins_with("fallen_monk:mugong:"):
			blocked_action = action_value as Dictionary
			break
	_expect(not blocked_action.is_empty(), "remaining fixed Mugong card must stay visible after one purchase")
	_expect(not bool(blocked_action.get("enabled", true)), "remaining fixed Mugong card must disable after the board reaches 6/6")
	_expect(str(blocked_action.get("disabled_reason", "")) == RuntimePerkCatalog.PERK_SLOT_LIMIT_BLOCKED_REASON, "disabled monk card must expose the shared slot-limit reason")
	_expect(not str(blocked_action.get("unavailable_reason", "")).is_empty(), "disabled monk card must expose a player-facing slot-limit message")
	var apply_calls_before: int = int(fixture.runtime_state.apply_calls)
	var blocked_result := flow.execute_node_action(
		str(blocked_action.get("id", "")),
		"fallen-monk-slot-budget:blocked"
	)
	_expect(not bool(blocked_result.get("accepted", true)) and str(blocked_result.get("reason", "")) == RuntimePerkCatalog.PERK_SLOT_LIMIT_BLOCKED_REASON, "direct fixed-offer execution must reject with the shared slot-limit reason")
	_expect(fixture.runtime_state.apply_calls == apply_calls_before and int(flow.get_run_state_snapshot().get("muhon", -1)) == 38, "blocked fixed-offer execution must issue no apply or debit")
	_finish_flow(flow, owner)


func _verify_six_of_six_chosik_uses_swap_gate() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	fixture.skill_config.max_slots = 6
	fixture.skill_config.equipped_skills = [
		"base_skill",
		"owned_skill_2",
		"owned_skill_3",
		"owned_skill_4",
		"owned_skill_5",
		"vision_skill_6",
	]
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-six-of-six",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40},
		"registry": fixture.registry,
	}), "six-of-six monk fixture must open")
	_expect(
		TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner),
		"six-of-six monk fixture must arrive at the monk"
	)
	var actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var swap_action := _find_action_with_prefix(actions, "fallen_monk:swap:")
	var acquire_action := _find_action_with_prefix(actions, "fallen_monk:acquire:")
	print(
		"[ChosikSlotTrimTrace] phase=fallen_monk_gate equipped=%d max_slots=%d swap=%s acquire=%s"
		% [
			fixture.skill_config.equipped_skills.size(),
			fixture.skill_config.max_slots,
			str(not swap_action.is_empty()),
			str(not acquire_action.is_empty()),
		]
	)
	_expect(not swap_action.is_empty(), "a Heavenly Cape 6/6 loadout must expose the Fallen Monk swap route")
	_expect(acquire_action.is_empty(), "a Heavenly Cape 6/6 loadout must not bypass replacement with direct acquisition")
	_finish_flow(flow, owner)


func _verify_flag_off_is_untouched() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var fixture := _build_fixture()
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(FakeOwner.new(), Callable(), {
		"run_id": "fallen-monk-off",
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40},
		"registry": fixture.registry,
	}), "flag OFF must not enter the tower monk node")
	_expect(flow.get_generated_fallen_monk_offers().is_empty() and fixture.runtime_state.apply_calls == 0, "flag OFF must not generate offers or touch Chosik state")


func _verify_source_contract() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_fallen_monk_node.gd"
	)
	_expect(source.find("RuntimePerkUnlockSwapFlow") >= 0, "monk node must reuse the existing Chosik swap owner")
	_expect(source.find("apply_choice") >= 0 and source.find("confirm_pending_unlock_swap") >= 0, "acquire and swap must use existing runtime state entry points")
	_expect(source.find("remove_runtime_unlock_for_skill") >= 0, "remove must reuse the existing unlock cleanup path")
	_expect(source.find("RandomNumberGenerator.new()") >= 0 and source.find(".shuffle()") < 0, "offer generation must use an isolated RNG without advancing gameplay randomness")
	_expect(source.find("get_perk_slot_apply_status") >= 0 and source.find("PERK_SLOT_LIMIT_BLOCKED_REASON") >= 0, "monk actions must recheck the shared apply-side slot gate")
	_expect(source.find("plaza_") < 0 and source.find("perform_academy") < 0, "monk node must not reuse persistent plaza payment or the academy stub")


func _build_fixture() -> Dictionary:
	var skill_config := FakeSkillConfig.new()
	var catalog := FakeRuntimePerkCatalog.new()
	var runtime_state := FakeRuntimePerkState.new()
	runtime_state.skill_config = skill_config
	runtime_state.catalog = catalog
	var registry := FakeRegistry.new()
	var unlock_store := FakeUnlockStore.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": skill_config,
		TowerAscentUnlockFilter.STORE_KEY: unlock_store,
	}
	return {
		"skill_config": skill_config,
		"catalog": catalog,
		"runtime_state": runtime_state,
		"unlock_store": unlock_store,
		"registry": registry,
	}


func _choice_ids(choices: Array) -> Array[String]:
	var result: Array[String] = []
	for choice_value in choices:
		if choice_value is Dictionary:
			result.append(str((choice_value as Dictionary).get("id", "")))
	return result


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for action_value in actions:
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("id", "")).begins_with(prefix)
		):
			return action_value as Dictionary
	return {}


func _find_swap_action_for_removed_skill(actions: Array, removed_skill: String) -> Dictionary:
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		var payload_value: Variant = action.get("payload", {})
		if (
			str(action.get("id", "")).begins_with("fallen_monk:swap:")
			and payload_value is Dictionary
			and str((payload_value as Dictionary).get("removed_skill", "")) == removed_skill
		):
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
