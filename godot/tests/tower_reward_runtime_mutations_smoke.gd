extends SceneTree

const CharacterInfoOverlayStatsPresenter := preload(
	"res://scripts/hud/character_info_overlay_stats_presenter.gd"
)
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveStatQuerySurface := preload(
	"res://scripts/characters/runtime_perk_effective_stat_query_surface.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}


	func get_instance(key: String) -> Object:
		return instances.get(key, null)


	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"starting_dash_tokens": 1,
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_pos": Vector2(302.5, 700.0),
	}


	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)


	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeDashState:
	extends RefCounted

	var reset_calls := 0
	var last_reset_full := -1


	func reset_full(max_tokens: int) -> void:
		reset_calls += 1
		last_reset_full = max_tokens


class FakeCapacityState:
	extends RefCounted


	func get_tower_bag_expansion_count() -> int:
		return 2


	func get_perk_fusion_active_item_slot_bonus() -> int:
		return 3


	func get_physique_training_bonus(stat_key: String) -> float:
		return 1.0 if stat_key == "active_item_slot_bonus" else 0.0


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_bag_persistence_reset_capacity_and_breakdown()
	_verify_ordinary_replacement_and_failed_apply_rollback()
	_verify_dash_cell_replacement_and_effect_resync()
	_verify_fusion_replacement_and_combined_snapshot_restore()
	_verify_meridian_limit_drop_rejection()
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)

	if _failures.is_empty():
		print("tower_reward_runtime_mutations_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_bag_persistence_reset_capacity_and_breakdown() -> void:
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {"common_swiftness": 2}
	var levels_before: Dictionary = state.runtime_skill_levels.duplicate(true)
	_expect(state.get_tower_bag_expansion_count() == 0, "a fresh run should have no tower bag expansion")
	_expect(state.grant_tower_bag_expansion(2), "tower bag grant should accept a positive amount")
	_expect(not state.grant_tower_bag_expansion(0), "tower bag grant should reject a zero amount")
	_expect(state.runtime_skill_levels == levels_before, "tower bag expansion must not create a runtime perk level")
	_expect(state.get_tower_bag_expansion_count() == 2, "tower bag expansion should retain the exact grant count")
	_expect(state.get_active_item_slot_capacity(3) == 5, "canonical active-item capacity should include tower bag expansion")

	var save_snapshot: Dictionary = state.build_unlock_save_snapshot()
	_expect(int(save_snapshot.get("version", 0)) == 3, "unlock save snapshot should advance to v3")
	_expect(int(save_snapshot.get("tower_bag_expansion_count", -1)) == 2, "v3 save should persist tower bag expansion")
	var runtime_snapshot: Dictionary = state.get_snapshot()
	_expect(int(runtime_snapshot.get("tower_bag_expansion_count", -1)) == 2, "runtime snapshot should expose tower bag expansion")

	var restored: Object = RuntimePerkState.new()
	var restore_result: Dictionary = restored.apply_unlock_save_snapshot(save_snapshot)
	_expect(bool(restore_result.get("restored", false)), "v3 unlock save should restore")
	_expect(restored.get_tower_bag_expansion_count() == 2, "v3 unlock save should restore bag count")
	_expect(restored.get_active_item_slot_capacity(3) == 5, "restored bag count should reach active-item capacity")

	var legacy_result: Dictionary = restored.apply_unlock_save_snapshot({
		"version": 2,
		"runtime_skill_levels": {"common_swiftness": 1},
	})
	_expect(bool(legacy_result.get("restored", false)), "legacy v2 unlock save should still restore")
	_expect(restored.get_tower_bag_expansion_count() == 0, "legacy save without a bag key should default to zero")
	restored.grant_tower_bag_expansion()
	restored.reset()
	_expect(restored.get_tower_bag_expansion_count() == 0, "new-run reset should clear tower bag expansion")

	var capacity_surface: Object = RuntimePerkEffectiveStatQuerySurface.new()
	_expect(
		capacity_surface.get_active_item_slot_capacity(null, FakeCapacityState.new(), 3) == 9,
		"canonical capacity surface should compose base + bag + fusion + physique bonuses"
	)
	var breakdown: Array = CharacterInfoOverlayStatsPresenter.active_item_slot_breakdown(state, null, 3)
	var bag_entry: Dictionary = _find_entry(breakdown, "icon_id", "tower_bag_expansion")
	_expect(not bag_entry.is_empty(), "active-item capacity breakdown should list tower bag expansion")
	_expect(str(bag_entry.get("text", "")) == "+2", "tower bag breakdown should show its exact additive count")


func _verify_ordinary_replacement_and_failed_apply_rollback() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"common_swiftness": 2,
		"common_bulk_up": 1,
		"item_luck": 1,
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
	}
	var registry: Object = _registry_for(state, catalog)
	var target := {
		"target_kind": "perk",
		"target_id": "common_swiftness",
		"slot_cell_index": 0,
	}
	var choice: Dictionary = _choice(catalog, "item_recycle")
	# Apply must reacquire canonical data by id instead of trusting caller flags.
	choice["is_physique_training"] = true
	var plan: Dictionary = state.build_tower_reward_mugong_replacement_plan(
		target,
		choice,
		catalog,
		registry
	)
	_expect(bool(plan.get("accepted", false)), "a full-slot ordinary replacement plan should be accepted")
	_expect(int(plan.get("target_raw_level", 0)) == 2, "ordinary plan should capture the authoritative raw level")
	var owner := FakeOwner.new()
	var apply_result: Dictionary = state.apply_tower_reward_mugong_replacement(
		target,
		choice,
		owner,
		registry,
		catalog
	)
	_expect(bool(apply_result.get("applied", false)), "ordinary replacement should apply atomically")
	_expect(not state.runtime_skill_levels.has("common_swiftness"), "ordinary replacement should erase the whole owned perk")
	_expect(int(state.runtime_skill_levels.get("item_recycle", 0)) == 1, "ordinary replacement should acquire the selected new perk")
	var owner_levels: Dictionary = owner.values.get("runtime_perk_effective_levels", {}) as Dictionary
	_expect(
		not owner_levels.has("common_swiftness") and int(owner_levels.get("item_recycle", 0)) == 1,
		"ordinary replacement should resync owner effects from the final atomic state"
	)
	var final_status: Dictionary = apply_result.get("final_slot_status", {}) as Dictionary
	_expect(
		int(final_status.get("count", -1)) == 6 and int(final_status.get("limit", 0)) == 6,
		"ordinary replacement should preserve the exact 6/6 slot occupancy"
	)

	var rollback_state: Object = RuntimePerkState.new()
	rollback_state.runtime_skill_levels = {
		"common_swiftness": 2,
		"common_bulk_up": 1,
		"item_luck": 1,
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
	}
	rollback_state.grant_tower_bag_expansion(2)
	var rollback_registry: Object = _registry_for(rollback_state, catalog)
	var before_snapshot: Dictionary = rollback_state.build_tower_reward_mutation_snapshot()
	var rejected: Dictionary = rollback_state.apply_tower_reward_mugong_replacement(
		target,
		_choice(catalog, "item_recycle"),
		null,
		rollback_registry,
		catalog,
		Callable(self, "_reject_replacement_choice")
	)
	_expect(not bool(rejected.get("accepted", true)), "a rejected replacement apply should fail closed")
	_expect(str(rejected.get("blocked_reason", "")) == "replacement_choice_rejected", "failed replacement should report the apply rejection")
	_expect(bool((rejected.get("rollback", {}) as Dictionary).get("restored", false)), "failed replacement should self-rollback")
	var after_snapshot: Dictionary = rollback_state.build_tower_reward_mutation_snapshot()
	_expect(
		_unlock_semantics(after_snapshot) == _unlock_semantics(before_snapshot),
		"failed replacement rollback should restore levels, training, and bag expansion"
	)
	_expect(
		_fusion_semantics(after_snapshot) == _fusion_semantics(before_snapshot),
		"failed replacement rollback should restore the fusion snapshot"
	)


func _verify_dash_cell_replacement_and_effect_resync() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"dash_amplification": 3,
		"common_swiftness": 1,
		"common_bulk_up": 1,
		"item_luck": 1,
	}
	var dash_state := FakeDashState.new()
	var registry: Object = _registry_for(state, catalog, dash_state)
	var choice: Dictionary = _choice(catalog, "item_recycle")
	var target := {
		"target_kind": "perk",
		"target_id": "dash_amplification",
		"slot_cell_index": 1,
	}
	var invalid_plan: Dictionary = state.build_tower_reward_mugong_replacement_plan(
		{
			"target_kind": "perk",
			"target_id": "dash_amplification",
			"slot_cell_index": 3,
		},
		choice,
		catalog,
		registry
	)
	_expect(str(invalid_plan.get("blocked_reason", "")) == "invalid_dash_replacement_cell", "dash target should reject a stale cell index")
	_expect(int(state.runtime_skill_levels.get("dash_amplification", 0)) == 3, "invalid dash plan must not mutate state")

	var owner := FakeOwner.new()
	var result: Dictionary = state.apply_tower_reward_mugong_replacement(
		target,
		choice,
		owner,
		registry,
		catalog
	)
	_expect(bool(result.get("applied", false)), "dash replacement should apply atomically")
	_expect(int(state.runtime_skill_levels.get("dash_amplification", 0)) == 2, "dash replacement should decrement exactly one raw cell")
	_expect(int(state.runtime_skill_levels.get("item_recycle", 0)) == 1, "dash replacement should acquire the selected new perk")
	_expect(dash_state.reset_calls == 1, "dash replacement should explicitly resync dash capacity once")
	_expect(dash_state.last_reset_full == 3, "dash resync should use one base token plus the remaining two cells")


func _verify_fusion_replacement_and_combined_snapshot_restore() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 3,
		"common_bulk_up": 5,
		"dash_lightweight": 5,
		"dash_module_control": 5,
		"common_swiftness": 1,
		"dash_jump": 1,
		"item_recycle": 1,
		"item_caffeine": 1,
	}
	state.grant_tower_bag_expansion(2)
	var first_record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["core_stabilize"]},
		catalog
	)
	var second_record: Dictionary = state.commit_perk_fusion(
		["dash_lightweight", "dash_module_control"],
		{"outcome": "success"},
		catalog
	)
	_expect(not first_record.is_empty() and not second_record.is_empty(), "two-fusion fixture should commit both canonical records")
	var registry: Object = _registry_for(state, catalog)
	var before_snapshot: Dictionary = state.build_tower_reward_mutation_snapshot()
	var before_fusion: Dictionary = state.get_perk_fusion_snapshot()
	var first_id: String = str(first_record.get("fusion_id", ""))
	var second_id: String = str(second_record.get("fusion_id", ""))
	var result: Dictionary = state.apply_tower_reward_mugong_replacement(
		{
			"target_kind": "fusion",
			"target_id": first_id,
			"slot_cell_index": 0,
		},
		_choice(catalog, "item_gauge_mastery"),
		null,
		registry,
		catalog
	)
	_expect(bool(result.get("applied", false)), "fusion replacement should apply atomically")
	_expect(not state.runtime_skill_levels.has("item_luck"), "fusion replacement should erase its first source")
	_expect(not state.runtime_skill_levels.has("common_bulk_up"), "fusion replacement should erase its second source")
	_expect(int(state.runtime_skill_levels.get("dash_lightweight", 0)) == 5, "fusion replacement should retain other fusion sources")
	_expect(int(state.runtime_skill_levels.get("dash_module_control", 0)) == 5, "fusion replacement should retain the other composite")
	_expect(int(state.runtime_skill_levels.get("item_gauge_mastery", 0)) == 1, "fusion replacement should acquire the selected new perk")
	var after_fusion: Dictionary = state.get_perk_fusion_snapshot()
	var after_records: Array = after_fusion.get("records", []) as Array
	_expect(after_records.size() == 1, "fusion replacement should remove exactly one composite record")
	_expect(
		after_records.size() == 1 and str((after_records[0] as Dictionary).get("fusion_id", "")) == second_id,
		"fusion replacement should preserve the untargeted composite record"
	)
	_expect(
		int(after_fusion.get("next_fusion_index", -1)) == int(before_fusion.get("next_fusion_index", -2)),
		"fusion replacement should preserve the next fusion id allocator"
	)
	_expect(
		bool(after_fusion.get("next_fusion_core_stabilize", false)) == bool(before_fusion.get("next_fusion_core_stabilize", true)),
		"fusion replacement should preserve the armed core-stabilize token"
	)
	var final_status: Dictionary = result.get("final_slot_status", {}) as Dictionary
	_expect(int(final_status.get("count", -1)) == 6, "fusion replacement should preserve the exact occupied-slot count")

	var restore_result: Dictionary = state.restore_tower_reward_mutation_snapshot(
		before_snapshot,
		null,
		registry,
		catalog
	)
	_expect(bool(restore_result.get("restored", false)), "combined unlock+fusion snapshot should restore")
	var restored_snapshot: Dictionary = state.build_tower_reward_mutation_snapshot()
	_expect(
		_unlock_semantics(restored_snapshot) == _unlock_semantics(before_snapshot),
		"combined restore should recover all raw levels, training, and bag state"
	)
	_expect(
		_fusion_semantics(restored_snapshot) == _fusion_semantics(before_snapshot),
		"combined restore should recover both composites, allocator, and token flags"
	)


func _verify_meridian_limit_drop_rejection() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 3,
		"common_bulk_up": 5,
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"common_swiftness": 1,
		"item_recycle": 1,
		"item_caffeine": 1,
	}
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["meridian_expand"]},
		catalog
	)
	_expect(not record.is_empty(), "meridian fixture should commit its sole expansion composite")
	var registry: Object = _registry_for(state, catalog)
	var status: Dictionary = catalog.get_perk_slot_status(state.runtime_skill_levels, registry)
	_expect(
		int(status.get("count", -1)) == 7 and int(status.get("limit", 0)) == 7,
		"sole-meridian rejection fixture should begin at exactly 7/7"
	)
	var before_snapshot: Dictionary = state.build_tower_reward_mutation_snapshot()
	var target := {
		"target_kind": "fusion",
		"target_id": str(record.get("fusion_id", "")),
		"slot_cell_index": 0,
	}
	var choice: Dictionary = _choice(catalog, "item_gauge_mastery")
	var plan: Dictionary = state.build_tower_reward_mugong_replacement_plan(
		target,
		choice,
		catalog,
		registry
	)
	_expect(not bool(plan.get("accepted", true)), "sole-meridian 7/7 replacement plan should reject")
	_expect(str(plan.get("blocked_reason", "")) == "replacement_drops_slot_limit", "sole-meridian rejection should name the limit drop")
	var apply_result: Dictionary = state.apply_tower_reward_mugong_replacement(
		target,
		choice,
		null,
		registry,
		catalog
	)
	_expect(not bool(apply_result.get("accepted", true)), "sole-meridian apply should reject before mutation")
	var after_snapshot: Dictionary = state.build_tower_reward_mutation_snapshot()
	_expect(_unlock_semantics(after_snapshot) == _unlock_semantics(before_snapshot), "sole-meridian rejection should preserve raw state")
	_expect(_fusion_semantics(after_snapshot) == _fusion_semantics(before_snapshot), "sole-meridian rejection should preserve its composite")


func _registry_for(state: Object, catalog: Object, dash_state: Object = null) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": state,
		"runtime_perk_catalog": catalog,
	}
	if dash_state != null:
		registry.instances["smasher_dash_state"] = dash_state
	return registry


func _choice(catalog: Object, choice_id: String) -> Dictionary:
	var choice: Dictionary = catalog.get_perk_data(choice_id)
	choice["id"] = choice_id
	return choice


func _reject_replacement_choice(
	_runtime_state: Object,
	_canonical_choice: Dictionary,
	_owner: Object,
	_registry: Object
) -> bool:
	return false


func _find_entry(entries: Array, key: String, expected: String) -> Dictionary:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get(key, "")) == expected:
			return (entry_value as Dictionary).duplicate(true)
	return {}


func _unlock_semantics(mutation_snapshot: Dictionary) -> Dictionary:
	var unlock_snapshot: Dictionary = mutation_snapshot.get("unlock_save", {}) as Dictionary
	var training_snapshot: Dictionary = unlock_snapshot.get("physique_training", {}) as Dictionary
	return {
		"runtime_skill_levels": (unlock_snapshot.get("runtime_skill_levels", {}) as Dictionary).duplicate(true),
		# Restore revisions are monotonic invalidation tokens, not player state.
		"physique_training": {
			"acquired_counts": (training_snapshot.get("acquired_counts", {}) as Dictionary).duplicate(true),
			"applied_counts": (training_snapshot.get("applied_counts", {}) as Dictionary).duplicate(true),
			"total_acquired_count": int(training_snapshot.get("total_acquired_count", 0)),
			"eligible_screen_count_before_dice_exhaustion": int(training_snapshot.get("eligible_screen_count_before_dice_exhaustion", 0)),
			"eligible_screen_count_after_dice_exhaustion": int(training_snapshot.get("eligible_screen_count_after_dice_exhaustion", 0)),
		},
		"tower_bag_expansion_count": int(unlock_snapshot.get("tower_bag_expansion_count", 0)),
	}


func _fusion_semantics(mutation_snapshot: Dictionary) -> Dictionary:
	var fusion_snapshot: Dictionary = mutation_snapshot.get("perk_fusion", {}) as Dictionary
	return {
		"records": (fusion_snapshot.get("records", []) as Array).duplicate(true),
		"next_fusion_index": int(fusion_snapshot.get("next_fusion_index", 0)),
		"next_fusion_core_stabilize": bool(fusion_snapshot.get("next_fusion_core_stabilize", false)),
		"next_fusion_dual_catalyst": bool(fusion_snapshot.get("next_fusion_dual_catalyst", false)),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
