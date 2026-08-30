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
	var runtime_perk_levels: Dictionary = {}
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
		"foreign_skill": {"korean": "타 클래스 초식"},
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
		"unlock_foreign": _choice(
			"unlock_foreign",
			"Foreign Chosik",
			"foreign_skill",
			"viper"
		),
	}

	static func _choice(
		perk_id: String,
		display_name: String,
		skill_id: String,
		character_type: String = "smasher"
	) -> Dictionary:
		return {
			"id": perk_id,
			"name": display_name,
			"unlocks_skill": skill_id,
			"character_restriction": character_type,
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
	var sync_owner_calls := 0
	var force_snapshot_failure := false
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
		if force_snapshot_failure:
			return {}
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

	func _sync_owner(owner: Object) -> void:
		sync_owner_calls += 1
		if owner != null:
			owner.set("runtime_perk_levels", runtime_skill_levels.duplicate(true))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	_verify_class_only_two_offer_visit_lock_and_snapshot()
	_verify_offer_pool_exhaustion()
	_verify_full_slot_swap_cancel_confirm_and_rollback()
	_verify_insufficient_muhon_is_a_no_op()
	_verify_flag_off_is_untouched()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()

	if _failures.is_empty():
		print("tower_fallen_monk_n1_seal: class_only=1 cards=2 visit_pick_limit=1 cost=4 pool=1/0 runtime_swap=1 rollback=1 restore_lock=1 authority_rng_unchanged=1 generation=0")
		print("tower_ascent_fallen_monk_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_class_only_two_offer_visit_lock_and_snapshot() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-n1-contract",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40, "gold": 0, "chance_gems": 3},
		"registry": fixture.registry,
	}), "N1 monk fixture must enter through the real tower flow")
	var arrival := _advance_to_fallen_modal_with_rng_seal(flow, owner)
	_expect(bool(arrival.get("arrived", false)), "N1 monk fixture must reach the monk through production arrival")
	_expect(
		var_to_bytes(arrival.get("rng_before", {}))
		== var_to_bytes(arrival.get("rng_after", {})),
		"monk offer generation must leave authoritative gameplay RNG byte-identical"
	)
	var offers := flow.get_generated_fallen_monk_offers()
	var choices: Array = offers[0].get("choices", []) if offers.size() == 1 else []
	_expect(offers.size() == 1, "one monk visit must own one deterministic offer")
	_expect(choices.size() == 2, "one monk visit must present exactly two Chosik cards")
	_expect(
		offers.size() == 1 and int(offers[0].get("offer_generation", -1)) == 0,
		"first monk visit must persist deterministic generation zero"
	)
	var class_only := true
	for choice_value in choices:
		if not (choice_value is Dictionary):
			class_only = false
			continue
		var choice := choice_value as Dictionary
		class_only = (
			class_only
			and str(choice.get("character_restriction", "")) == "smasher"
			and not str(choice.get("unlocks_skill", "")).is_empty()
			and str(choice.get("id", "")) != "unlock_foreign"
		)
	_expect(class_only, "all monk offers must be unowned Chosik for the active class")
	var repeated_fixture := _build_fixture()
	var repeated_owner := FakeOwner.new()
	var repeated_flow := TowerAscentFlowOwner.new()
	_expect(repeated_flow.begin_vertical_slice(repeated_owner, Callable(), {
		"run_id": "fallen-monk-n1-contract-repeat",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40, "gold": 0, "chance_gems": 3},
		"registry": repeated_fixture.registry,
	}), "same-seed monk fixture must open")
	var repeated_arrival := _advance_to_fallen_modal_with_rng_seal(
		repeated_flow,
		repeated_owner
	)
	_expect(bool(repeated_arrival.get("arrived", false)), "same-seed monk fixture must arrive")
	_expect(
		var_to_bytes(repeated_flow.get_generated_fallen_monk_offers())
		== var_to_bytes(offers),
		"fresh generation with the same map seed and generation must be byte-identical"
	)
	_finish_flow(repeated_flow, repeated_owner)
	var actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var acquire_actions: Array[Dictionary] = []
	for action_value in actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")).begins_with("fallen_monk:acquire:"):
			acquire_actions.append(action_value as Dictionary)
	_expect(acquire_actions.size() == 2, "the two offered cards must be the only learn actions")
	_expect(_find_action_with_prefix(actions, "fallen_monk:mugong:").is_empty(), "the reworked monk must not offer Mugong")
	_expect(_find_action_with_prefix(actions, "fallen_monk:remove:").is_empty(), "the reworked monk must not offer removal")
	_expect(_find_action_with_prefix(actions, "fallen_monk:swap:").is_empty(), "full-slot replacement must not be preselected on the storefront")
	for action in acquire_actions:
		_expect(str(action.get("cost_text", "")).contains("4"), "each monk card must display the canonical four-Muhon price")
	var first_action := acquire_actions[0] if not acquire_actions.is_empty() else {}
	var second_action := acquire_actions[1] if acquire_actions.size() > 1 else {}
	var result := flow.execute_node_action(
		str(first_action.get("id", "")),
		"fallen-monk-n1-contract:pick"
	)
	_expect(bool(result.get("accepted", false)) and bool(result.get("applied", false)), "one open-slot Chosik pick must commit")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 36, "one Chosik pick must debit exactly four Muhon")
	_expect(flow.get_fallen_monk_history().size() == 1, "the visit must append exactly one Chosik record")
	var second_result := flow.execute_node_action(
		str(second_action.get("id", "")),
		"fallen-monk-n1-contract:second-pick"
	)
	_expect(not bool(second_result.get("accepted", true)), "a second card must be rejected after the first visit pick")
	_expect(
		flow.get_fallen_monk_history().size() == 1
		and int(flow.get_run_state_snapshot().get("muhon", -1)) == 36,
		"a rejected second pick must neither append history nor debit again"
	)
	var snapshot := flow.export_persistable_snapshot()
	var restored_fixture := _build_fixture()
	var restored := TowerAscentFlowOwner.new()
	var restored_owner := FakeOwner.new()
	_expect(restored.restore_snapshot(snapshot, Callable(), restored_owner, restored_fixture.registry), "completed monk snapshot must restore")
	_expect(
		restored_fixture.runtime_state.sync_owner_calls == 1
		and restored_owner.runtime_perk_levels
			== restored_fixture.runtime_state.runtime_skill_levels,
		"restore must publish the raw runtime-perk levels to the owner exactly once"
	)
	_expect(var_to_bytes(restored.get_generated_fallen_monk_offers()) == var_to_bytes(offers), "restored monk offers must not reroll")
	_expect(restored.get_fallen_monk_history().size() == 1, "restored monk visit lock must retain one record")
	var restored_actions: Array = restored.get_node_modal_view_model().get("actions", [])
	_expect(
		_find_action_with_prefix(restored_actions, "fallen_monk:").is_empty(),
		"restored completed visit must keep every offered card locked"
	)
	var restored_retry := restored.execute_node_action(
		str(second_action.get("id", "")),
		"fallen-monk-n1-contract:restored-second-pick"
	)
	_expect(
		not bool(restored_retry.get("accepted", true))
		and restored.get_fallen_monk_history().size() == 1
		and int(restored.get_run_state_snapshot().get("muhon", -1)) == 36,
		"restored visit lock must reject direct execution without debit or history"
	)
	_finish_flow(flow, owner)
	_finish_flow(restored, null)


func _verify_offer_pool_exhaustion() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	for remaining_count in [1, 0]:
		var fixture := _build_fixture()
		var owned_count := 4 - int(remaining_count)
		for index in range(owned_count):
			fixture.runtime_state.runtime_skill_levels[
				["unlock_alpha", "unlock_beta", "unlock_gamma", "unlock_delta"][index]
			] = 1
		var owner := FakeOwner.new()
		var flow := TowerAscentFlowOwner.new()
		_expect(flow.begin_vertical_slice(owner, Callable(), {
			"run_id": "fallen-monk-pool-%d" % remaining_count,
			"map_seed": _initial_route_seed,
			"node_modal_kind": "fallen_monk",
			"run_state": {"muhon": 40},
			"registry": fixture.registry,
		}), "pool exhaustion fixture must open")
		_expect(
			TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner),
			"pool exhaustion fixture must reach the monk"
		)
		var offers := flow.get_generated_fallen_monk_offers()
		var choices: Array = offers[0].get("choices", []) if offers.size() == 1 else []
		var actions: Array = flow.get_node_modal_view_model().get("actions", [])
		_expect(offers.size() == 1, "a depleted class pool must retain one stable offer record")
		var acquire_actions: Array[Dictionary] = []
		for action_value in actions:
			if (
				action_value is Dictionary
				and str((action_value as Dictionary).get("id", "")).begins_with(
					"fallen_monk:acquire:"
				)
			):
				acquire_actions.append(action_value as Dictionary)
		_expect(
			choices.size() == remaining_count and acquire_actions.size() == remaining_count,
			"a depleted class pool must degrade to %d cards and actions" % remaining_count
		)
		_finish_flow(flow, owner)


func _verify_full_slot_swap_cancel_confirm_and_rollback() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	fixture.skill_config.equipped_skills = ["base_skill", "beta_skill"]
	fixture.runtime_state.runtime_skill_levels = {"unlock_beta": 1}
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-runtime-swap",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40},
		"registry": fixture.registry,
	}), "full-slot fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner), "full-slot fixture must reach the monk")
	var action := _find_action_with_prefix(flow.get_node_modal_view_model().get("actions", []), "fallen_monk:acquire:")
	var original_levels: Dictionary = fixture.runtime_state.runtime_skill_levels.duplicate(true)
	var original_equipped: Array = fixture.skill_config.equipped_skills.duplicate()
	var opened := flow.execute_node_action(str(action.get("id", "")), "fallen-monk-runtime-swap:cancel")
	_expect(bool(opened.get("accepted", false)) and not bool(opened.get("applied", true)), "a full-slot pick must open the standard pending swap without committing")
	_expect(flow.has_pending_guardian_spring_chosik_swap() and fixture.runtime_state.has_pending_unlock_swap(), "the existing tower swap overlay facade must own the pending replacement")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 40 and flow.get_fallen_monk_history().is_empty(), "opening replacement must not debit or append history")
	_expect(fixture.runtime_state.cancel_pending_unlock_swap(owner), "standard swap cancel must clear the runtime modal")
	flow.update_selective(0.0, owner)
	_expect(not flow.has_pending_guardian_spring_chosik_swap(), "production update must resolve the cancelled node transaction")
	_expect(fixture.runtime_state.runtime_skill_levels == original_levels and fixture.skill_config.equipped_skills == original_equipped, "cancel must restore runtime and equipped Chosik")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 40 and flow.get_fallen_monk_history().is_empty(), "cancel must preserve Muhon and history")

	action = _find_action_with_prefix(flow.get_node_modal_view_model().get("actions", []), "fallen_monk:acquire:")
	opened = flow.execute_node_action(str(action.get("id", "")), "fallen-monk-runtime-swap:confirm")
	_expect(bool(opened.get("accepted", false)) and fixture.runtime_state.has_pending_unlock_swap(), "the same visit must remain selectable after cancel")
	fixture.runtime_state.move_unlock_swap_selection(1)
	var pending: Dictionary = fixture.runtime_state.get_pending_unlock_swap()
	var new_choice_id := str(pending.get("choice_id", ""))
	var new_skill_id := str(pending.get("unlocks_skill", ""))
	_expect(fixture.runtime_state.confirm_pending_unlock_swap(owner, fixture.registry), "standard swap confirmation must replace the selected old Chosik")
	flow.update_selective(0.0, owner)
	_expect(not flow.has_pending_guardian_spring_chosik_swap(), "production update must commit the confirmed replacement")
	_expect(flow.get_fallen_monk_history().size() == 1 and int(flow.get_run_state_snapshot().get("muhon", -1)) == 36, "confirmed replacement must append once and debit four")
	_expect(fixture.skill_config.equipped_skills.has(new_skill_id) and not fixture.skill_config.equipped_skills.has("beta_skill"), "replacement must follow the selected reverse mapping")
	_expect(int(fixture.runtime_state.runtime_skill_levels.get(new_choice_id, 0)) == 1 and not fixture.runtime_state.runtime_skill_levels.has("unlock_beta"), "replacement must remove the displaced unlock and own the selected Chosik")
	_finish_flow(flow, owner)

	var rollback_fixture := _build_fixture()
	rollback_fixture.skill_config.equipped_skills = ["base_skill", "beta_skill"]
	rollback_fixture.runtime_state.runtime_skill_levels = {"unlock_beta": 1}
	var rollback_owner := FakeOwner.new()
	var rollback_flow := TowerAscentFlowOwner.new()
	_expect(rollback_flow.begin_vertical_slice(rollback_owner, Callable(), {
		"run_id": "fallen-monk-runtime-swap-rollback",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 40},
		"registry": rollback_fixture.registry,
	}), "rollback fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(rollback_flow, "fallen_monk", rollback_owner), "rollback fixture must reach the monk")
	var rollback_action := _find_action_with_prefix(rollback_flow.get_node_modal_view_model().get("actions", []), "fallen_monk:acquire:")
	rollback_flow.execute_node_action(str(rollback_action.get("id", "")), "fallen-monk-runtime-swap-rollback:pick")
	rollback_fixture.runtime_state.move_unlock_swap_selection(1)
	_expect(rollback_fixture.runtime_state.confirm_pending_unlock_swap(rollback_owner, rollback_fixture.registry), "rollback fixture must first confirm runtime replacement")
	rollback_fixture.runtime_state.force_snapshot_failure = true
	rollback_flow.update_selective(0.0, rollback_owner)
	_expect(rollback_fixture.runtime_state.runtime_skill_levels == {"unlock_beta": 1} and rollback_fixture.skill_config.equipped_skills == ["base_skill", "beta_skill"], "commit postcondition failure must roll back both replacement legs")
	_expect(int(rollback_flow.get_run_state_snapshot().get("muhon", -1)) == 40 and rollback_flow.get_fallen_monk_history().is_empty(), "failed confirmed replacement must not debit or append history")
	_expect(
		not rollback_flow.has_pending_guardian_spring_chosik_swap()
		and not rollback_fixture.runtime_state.has_pending_unlock_swap(),
		"failed confirmed replacement must leave no orphan node or runtime swap owner"
	)
	_finish_flow(rollback_flow, rollback_owner)


func _verify_insufficient_muhon_is_a_no_op() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var fixture := _build_fixture()
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "fallen-monk-poor",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "fallen_monk",
		"run_state": {"muhon": 3},
		"registry": fixture.registry,
	}), "insufficient-Muhon fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "fallen_monk", owner), "insufficient-Muhon fixture must arrive at the monk")
	var action := _find_action_with_prefix(
		flow.get_node_modal_view_model().get("actions", []),
		"fallen_monk:acquire:"
	)
	_expect(not bool(action.get("enabled", true)), "insufficient Muhon must disable acquisition")
	var reason := str(action.get("unavailable_reason", ""))
	_expect(reason.contains("4") and reason.contains("1"), "disabled acquisition must show required Muhon and exact shortfall")
	var result := flow.execute_node_action(str(action.get("id", "")), "fallen-monk-poor:attempt")
	_expect(not bool(result.get("accepted", true)), "insufficient Muhon must reject direct execution before transaction")
	_expect(int(flow.get_run_state_snapshot().get("muhon", -1)) == 3 and fixture.runtime_state.apply_calls == 0 and flow.get_fallen_monk_history().is_empty(), "insufficient Muhon must issue no debit, grant, or history")
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
	var tuning_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_tuning.gd"
	)
	var reward_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd"
	)
	_expect(source.find("RuntimePerkUnlockSwapFlow") >= 0, "monk node must reuse the existing Chosik swap owner")
	_expect(source.find("apply_choice") >= 0 and source.find("has_pending_unlock_swap") >= 0, "acquire and full-slot selection must use existing runtime state entry points")
	_expect(source.find("confirm_pending_unlock_swap") < 0, "the node must not pre-confirm a replacement before the player chooses")
	_expect(source.find("RandomNumberGenerator.new()") >= 0 and source.find(".shuffle()") < 0, "offer generation must use an isolated RNG without advancing gameplay randomness")
	_expect(
		source.find("_gameplay_rng_state") < 0
		and source.find("roll_from_gameplay_state") < 0,
		"monk offer generation must not read or write the authoritative gameplay RNG owner"
	)
	_expect(source.find("offer_generation") >= 0, "monk deterministic seed and snapshot must carry offer generation")
	_expect(source.find(".pop_") < 0, "Chosik replacement must preserve reverse mapping instead of popping live arrays")
	_expect(tuning_source.count("const CHOSIK_SELECTION_MUHON_COST") == 1, "one tuning owner must define the canonical Chosik selection cost")
	_expect(source.find("TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST") >= 0, "monk selection must only read the shared cost")
	_expect(reward_source.find("TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST") >= 0, "reward-pick Chosik must only read the shared cost")
	_expect(reward_source.find("TEMP_CHOSIK_COST") < 0, "reward-pick must not retain its old local Chosik price")
	_expect(tuning_source.find("TEMP_PHASE_C_MONK_CHOSIK_ACQUIRE_COST") < 0 and tuning_source.find("TEMP_PHASE_C_MONK_CHOSIK_SWAP_COST") < 0, "old split monk price owners must be removed")
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


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for action_value in actions:
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("id", "")).begins_with(prefix)
		):
			return action_value as Dictionary
	return {}


func _advance_to_fallen_modal_with_rng_seal(flow: Object, owner: Object) -> Dictionary:
	if flow == null or str(flow.get_phase_name()) != "ROUTE_AIM":
		return {"arrived": false}
	var target_index := -1
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == "fallen_monk":
			target_index = index
			break
	if target_index < 0:
		return {"arrived": false}
	flow.debug_launch_at_target(target_index)
	flow.update_selective(
		TowerAscentNodeArrivalTestFixture.REFERENCE_FLIGHT_SECONDS
		* TowerAscentNodeArrivalTestFixture.REFERENCE_SERVE_SPEED_PER_SECOND
		/ maxf(1.0, TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND),
		owner
	)
	if str(flow.get_phase_name()) != "MAP_TRANSITION":
		return {"arrived": false}
	var before_snapshot: Dictionary = flow.export_persistable_snapshot()
	var rng_before: Dictionary = before_snapshot.get("gameplay_rng_state", {}).duplicate(true)
	flow.update_selective(1.0, owner)
	var after_snapshot: Dictionary = flow.export_persistable_snapshot()
	var rng_after: Dictionary = after_snapshot.get("gameplay_rng_state", {}).duplicate(true)
	return {
		"arrived": (
			str(flow.get_phase_name()) == "NODE_MODAL"
			and str(flow.get_node_modal_kind()) == "fallen_monk"
		),
		"rng_before": rng_before,
		"rng_after": rng_after,
	}


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
