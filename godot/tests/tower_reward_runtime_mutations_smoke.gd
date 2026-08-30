extends SceneTree

const CharacterInfoOverlayStatsPresenter := preload(
	"res://scripts/hud/character_info_overlay_stats_presenter.gd"
)
const AngelBlessingStageLifecycle := preload(
	"res://scripts/characters/runtime_perk_angel_blessing_stage_lifecycle.gd"
)
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveStatQuerySurface := preload(
	"res://scripts/characters/runtime_perk_effective_stat_query_surface.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

var _failures: Array[String] = []
class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}


	func get_instance(key: String) -> Object:
		return instances.get(key, null)


	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeUnlockStore:
	extends RefCounted

	var unlocked_ids: Dictionary = {}


	func is_unlocked(content_type: String, content_id: String) -> bool:
		return content_type == "runtime_perk" and bool(unlocked_ids.get(content_id, false))


class FakeOwner:
	extends RefCounted

	var runtime_level_sync_calls := 0
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
		if str(property) == "runtime_perk_levels":
			runtime_level_sync_calls += 1
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


class FakeMythicItemRuntime:
	extends RefCounted

	var start_calls := 0
	var refresh_calls := 0


	func start_acquisition_cinematic(
		_item_data: Dictionary,
		_pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		_target_player_center: Vector2 = Vector2.INF
	) -> bool:
		start_calls += 1
		return true


	func refresh_runtime_perk_scaling(_owner: Object = null, _registry: Object = null) -> void:
		refresh_calls += 1


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_bag_persistence_reset_capacity_and_breakdown()
	_verify_ordinary_replacement_and_failed_apply_rollback()
	_verify_dash_cell_replacement_and_effect_resync()
	_verify_fusion_replacement_and_combined_snapshot_restore()
	_verify_meridian_limit_drop_rejection()
	_verify_taiji_elder_atomic_exchange_and_rollback()
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


func _verify_taiji_elder_atomic_exchange_and_rollback() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var owner := FakeOwner.new()
	owner.values["current_stage"] = 4
	owner.values["arena_mode_enabled"] = false
	var unlock_store := FakeUnlockStore.new()
	unlock_store.unlocked_ids = {
		"angel_blessing": true,
		"baal_boots": true,
		"celestial_armor": true,
		"megingjord": true,
	}
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 3,
		"item_recycle": 1,
		"megingjord": 1,
	}
	var registry: Object = _registry_for(state, catalog)
	registry.instances["tower_ascent_unlock_store"] = unlock_store
	var success_mythic_runtime := FakeMythicItemRuntime.new()
	registry.instances["mythic_item_runtime"] = success_mythic_runtime
	registry.instances["smasher_skill_config"] = SmasherSkillConfig.new()
	registry.instances["smasher_skill_state"] = SmasherSkillState.new()
	var targets: Array[String] = state.build_taiji_elder_mythic_target_ids(
		owner,
		registry,
		catalog
	)
	_expect(
		targets == ["angel_blessing", "baal_boots", "celestial_armor"],
		"Taiji target ids should be sorted and include only unowned, unlocked, character-compatible canonical mythics"
	)
	var plan: Dictionary = state.build_taiji_elder_exchange_plan(
		"item_luck",
		"angel_blessing",
		owner,
		registry,
		catalog
	)
	_expect(bool(plan.get("accepted", false)), "Taiji exchange plan should accept an owned ordinary source and eligible mythic target")
	_expect(int(plan.get("source_raw_level", 0)) == 3, "Taiji plan should pin the whole source-card raw level")
	_expect(int(plan.get("target_level", 0)) == 1, "Taiji plan should pin the mythic target to level one")
	var success_angel_before := var_to_bytes(state.get_angel_blessing_acquisition_snapshot())
	var applied: Dictionary = state.apply_taiji_elder_exchange(
		"item_luck",
		"angel_blessing",
		owner,
		registry,
		catalog
	)
	_expect(bool(applied.get("applied", false)), "Taiji exchange should commit atomically")
	_expect(not state.runtime_skill_levels.has("item_luck"), "Taiji exchange should remove the entire ordinary source card")
	_expect(int(state.runtime_skill_levels.get("angel_blessing", 0)) == 1, "Taiji exchange should grant the offered mythic at level one")
	_expect(int(state.runtime_skill_levels.get("item_recycle", 0)) == 1, "Taiji exchange should preserve unrelated owned martial arts")
	_expect(owner.runtime_level_sync_calls == 1, "Taiji success should publish the committed raw levels to the owner exactly once")
	_expect((owner.values.get("runtime_perk_levels", {}) as Dictionary) == state.runtime_skill_levels, "Taiji success owner raw projection must exactly match the committed runtime state")
	_expect(success_mythic_runtime.start_calls == 0, "Taiji success must not start the generic mythic acquisition cinematic over its result hold")
	_expect(success_mythic_runtime.refresh_calls == 1, "Taiji success should refresh committed mythic consumers exactly once")
	_expect(var_to_bytes(state.get_angel_blessing_acquisition_snapshot()) == success_angel_before, "Taiji success must not queue the Angel Blessing acquisition lifecycle over its result hold")
	_expect(str(applied.get("grant_path", "")) == "taiji_exact_level_one", "Taiji success should report its side-effect-free exact level-one grant path")
	_expect(not bool(applied.get("acquisition_side_effects_started", true)), "Taiji success should seal that generic acquisition side effects remain deferred")
	owner.values["current_stage"] = 5
	var next_stage_angel: Dictionary = AngelBlessingStageLifecycle.new().on_ball_spawn_intro_finished(
		state,
		owner,
		registry,
		1,
		["move_speed"]
	)
	_expect(bool(next_stage_angel.get("rolled", false)), "Taiji-granted Angel Blessing raw ownership should activate through the next-stage intro lifecycle")
	_expect(int(next_stage_angel.get("active_stage", 0)) == 5, "the next-stage Angel lifecycle should bind to the new campaign stage")
	_expect(success_mythic_runtime.refresh_calls == 2, "next-stage Angel activation should add exactly one normal consumer refresh after the Taiji commit refresh")

	var rollback_state: Object = RuntimePerkState.new()
	rollback_state.runtime_skill_levels = {
		"item_luck": 4,
		"item_recycle": 2,
	}
	rollback_state.grant_tower_bag_expansion(2)
	var rollback_registry: Object = _registry_for(rollback_state, catalog)
	rollback_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var rejection_before: Dictionary = rollback_state.build_tower_reward_mutation_snapshot()
	var rejection_owner_sync_before := owner.runtime_level_sync_calls
	var rejected: Dictionary = rollback_state.apply_taiji_elder_exchange(
		"item_luck",
		"baal_boots",
		owner,
		rollback_registry,
		catalog,
		{"force_grant_rejection": true}
	)
	_expect(not bool(rejected.get("grant_invoked", true)), "Taiji rejection counterproof should stop before invoking the exact grant")
	_expect(str(rejected.get("blocked_reason", "")) == "taiji_exchange_choice_rejected", "Taiji exchange should report the injected precommit grant rejection")
	_expect(owner.runtime_level_sync_calls == rejection_owner_sync_before, "Taiji precommit grant rejection must not publish any owner raw projection")
	_expect(bool((rejected.get("rollback", {}) as Dictionary).get("mutation_free", false)), "Taiji grant rejection should remain mutation-free before commit")
	var rejection_after: Dictionary = rollback_state.build_tower_reward_mutation_snapshot()
	_expect(_unlock_semantics(rejection_after) == _unlock_semantics(rejection_before), "Taiji grant rejection should preserve all unlock state before commit")
	_expect(_fusion_semantics(rejection_after) == _fusion_semantics(rejection_before), "Taiji grant rejection should preserve fusion state")

	var postcondition_state: Object = RuntimePerkState.new()
	postcondition_state.runtime_skill_levels = {
		"item_luck": 4,
		"item_recycle": 2,
	}
	postcondition_state.grant_tower_bag_expansion(2)
	var postcondition_registry: Object = _registry_for(postcondition_state, catalog)
	postcondition_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var failed_mythic_runtime := FakeMythicItemRuntime.new()
	postcondition_registry.instances["mythic_item_runtime"] = failed_mythic_runtime
	var postcondition_before: Dictionary = postcondition_state.build_tower_reward_mutation_snapshot()
	var postcondition_angel_before := var_to_bytes(
		postcondition_state.get_angel_blessing_acquisition_snapshot()
	)
	var postcondition_owner_sync_before := owner.runtime_level_sync_calls
	var post_failed: Dictionary = postcondition_state.apply_taiji_elder_exchange(
		"item_luck",
		"angel_blessing",
		owner,
		postcondition_registry,
		catalog,
		{"force_postcondition_failure": true}
	)
	_expect(str(post_failed.get("blocked_reason", "")) == "taiji_exchange_postcondition_failed", "Taiji exchange should report postcondition failure")
	_expect(bool((post_failed.get("rollback", {}) as Dictionary).get("mutation_free", false)), "Taiji postcondition failure should remain mutation-free before commit")
	_expect(failed_mythic_runtime.start_calls == 0, "Taiji postcondition failure must not start a mythic cinematic before validation")
	_expect(failed_mythic_runtime.refresh_calls == 0, "Taiji postcondition failure must not refresh external mythic consumers before validation")
	_expect(owner.runtime_level_sync_calls == postcondition_owner_sync_before, "Taiji postcondition failure must not publish any owner raw projection")
	_expect(var_to_bytes(postcondition_state.get_angel_blessing_acquisition_snapshot()) == postcondition_angel_before, "Taiji postcondition failure must leave Angel Blessing acquisition state byte-identical")
	var postcondition_after: Dictionary = postcondition_state.build_tower_reward_mutation_snapshot()
	_expect(var_to_bytes(postcondition_after.get("unlock_save", {})) == var_to_bytes(postcondition_before.get("unlock_save", {})), "Taiji postcondition failure should preserve unlock state byte-identically")
	_expect(var_to_bytes(postcondition_after.get("perk_fusion", {})) == var_to_bytes(postcondition_before.get("perk_fusion", {})), "Taiji postcondition failure should preserve fusion state byte-identically")

	var commit_failure_state: Object = RuntimePerkState.new()
	commit_failure_state.runtime_skill_levels = {
		"dash_amplification": 3,
		"item_recycle": 2,
	}
	var commit_failure_dash := FakeDashState.new()
	var commit_failure_registry: Object = _registry_for(
		commit_failure_state,
		catalog,
		commit_failure_dash
	)
	commit_failure_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var commit_failure_mythic := FakeMythicItemRuntime.new()
	commit_failure_registry.instances["mythic_item_runtime"] = commit_failure_mythic
	var commit_failure_before: Dictionary = commit_failure_state.build_tower_reward_mutation_snapshot()
	var commit_failure_angel_before := var_to_bytes(
		commit_failure_state.get_angel_blessing_acquisition_snapshot()
	)
	var commit_failure_owner_sync_before := owner.runtime_level_sync_calls
	var commit_failed: Dictionary = commit_failure_state.apply_taiji_elder_exchange(
		"dash_amplification",
		"angel_blessing",
		owner,
		commit_failure_registry,
		catalog,
		{"force_commit_failure": true}
	)
	_expect(str(commit_failed.get("blocked_reason", "")) == "taiji_exchange_commit_failed", "Taiji partial-commit counterproof should fail at the exact commit boundary")
	var commit_rollback: Dictionary = commit_failed.get("rollback", {}) as Dictionary
	_expect(bool(commit_rollback.get("restored", false)) and not bool(commit_rollback.get("mutation_free", true)), "Taiji partial-commit failure should perform a real exact raw rollback")
	_expect(bool(commit_rollback.get("unlock_byte_exact", false)) and bool(commit_rollback.get("fusion_byte_exact", false)), "Taiji partial-commit rollback should seal exact unlock and fusion restoration")
	_expect(var_to_bytes(commit_failure_state.build_tower_reward_mutation_snapshot()) == var_to_bytes(commit_failure_before), "Taiji partial-commit rollback should restore the complete mutation snapshot byte-identically")
	_expect(var_to_bytes(commit_failure_state.get_angel_blessing_acquisition_snapshot()) == commit_failure_angel_before, "Taiji partial-commit rollback must leave Angel acquisition state byte-identical")
	_expect(commit_failure_dash.reset_calls == 0, "Taiji partial-commit rollback must not resync dash because no external commit effects ran")
	_expect(commit_failure_mythic.start_calls == 0 and commit_failure_mythic.refresh_calls == 0, "Taiji partial-commit rollback must leave mythic cinematic and consumers untouched")
	_expect(owner.runtime_level_sync_calls == commit_failure_owner_sync_before, "Taiji partial-commit rollback must not publish an owner raw projection")

	var fusion_state: Object = RuntimePerkState.new()
	fusion_state.runtime_skill_levels = {
		"item_luck": 3,
		"common_bulk_up": 5,
	}
	var fusion_record: Dictionary = fusion_state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "success"},
		catalog
	)
	_expect(not fusion_record.is_empty(), "Taiji fusion-hidden safety fixture should commit")
	var fusion_registry: Object = _registry_for(fusion_state, catalog)
	fusion_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var fusion_before: Dictionary = fusion_state.build_tower_reward_mutation_snapshot()
	var hidden_rejected: Dictionary = fusion_state.apply_taiji_elder_exchange(
		"item_luck",
		"baal_boots",
		owner,
		fusion_registry,
		catalog
	)
	_expect(str(hidden_rejected.get("blocked_reason", "")) == "taiji_exchange_source_fusion_hidden", "Taiji mutation boundary should fail closed if node candidate policy passes a fusion-hidden source")
	var fusion_after: Dictionary = fusion_state.build_tower_reward_mutation_snapshot()
	_expect(_unlock_semantics(fusion_after) == _unlock_semantics(fusion_before), "fusion-hidden source rejection should not mutate raw levels")
	_expect(_fusion_semantics(fusion_after) == _fusion_semantics(fusion_before), "fusion-hidden source rejection should not mutate fusion records")

	var wrong_character_state: Object = RuntimePerkState.new()
	wrong_character_state.runtime_skill_levels = {"jetpack_enhance": 2}
	var wrong_character_registry: Object = _registry_for(wrong_character_state, catalog)
	wrong_character_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var wrong_character_before: Dictionary = wrong_character_state.build_tower_reward_mutation_snapshot()
	var wrong_character: Dictionary = wrong_character_state.apply_taiji_elder_exchange(
		"jetpack_enhance",
		"baal_boots",
		owner,
		wrong_character_registry,
		catalog
	)
	_expect(str(wrong_character.get("blocked_reason", "")) == "taiji_exchange_source_character_incompatible", "direct Taiji exchange must reject a source restricted to another character")
	_expect(_unlock_semantics(wrong_character_state.build_tower_reward_mutation_snapshot()) == _unlock_semantics(wrong_character_before), "wrong-character source rejection must be mutation-free")

	var excluded_direct_sources: Array[Dictionary] = [
		{"id": "banana_master", "level": 1, "seal": "acquisition-only"},
		{"id": "common_swiftness", "level": 3, "seal": "training-migrated"},
		{"id": "common_expansion", "level": 2, "seal": "slot-expansion"},
	]
	for source_case: Dictionary in excluded_direct_sources:
		var excluded_state: Object = RuntimePerkState.new()
		var excluded_id := str(source_case.get("id", ""))
		excluded_state.runtime_skill_levels = {
			excluded_id: int(source_case.get("level", 1)),
		}
		var excluded_registry: Object = _registry_for(excluded_state, catalog)
		excluded_registry.instances["tower_ascent_unlock_store"] = unlock_store
		var excluded_before: Dictionary = excluded_state.build_tower_reward_mutation_snapshot()
		var excluded_result: Dictionary = excluded_state.apply_taiji_elder_exchange(
			excluded_id,
			"baal_boots",
			owner,
			excluded_registry,
			catalog
		)
		_expect(
			str(excluded_result.get("blocked_reason", "")) == "taiji_exchange_source_not_ordinary",
			"direct Taiji exchange must reject the %s source" % str(source_case.get("seal", "excluded"))
		)
		_expect(
			_unlock_semantics(excluded_state.build_tower_reward_mutation_snapshot()) == _unlock_semantics(excluded_before),
			"%s direct-source rejection must be mutation-free" % str(source_case.get("seal", "excluded"))
		)

	var dash_state: Object = RuntimePerkState.new()
	dash_state.runtime_skill_levels = {"dash_amplification": 3}
	var dash_runtime := FakeDashState.new()
	var dash_registry: Object = _registry_for(dash_state, catalog, dash_runtime)
	dash_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var dash_mythic_runtime := FakeMythicItemRuntime.new()
	dash_registry.instances["mythic_item_runtime"] = dash_mythic_runtime
	var dash_owner_sync_before := owner.runtime_level_sync_calls
	var dash_result: Dictionary = dash_state.apply_taiji_elder_exchange(
		"dash_amplification",
		"angel_blessing",
		owner,
		dash_registry,
		catalog
	)
	_expect(bool(dash_result.get("applied", false)), "Taiji exchange should accept a multi-level dash card")
	_expect(not dash_state.runtime_skill_levels.has("dash_amplification"), "Taiji exchange must remove every raw level of the designated dash card")
	_expect(int(dash_state.runtime_skill_levels.get("angel_blessing", 0)) == 1, "dash exchange must grant the mythic at level one")
	_expect(dash_runtime.reset_calls == 1 and dash_runtime.last_reset_full == 1, "successful whole-card dash removal must resync capacity to the one base token")
	_expect(dash_mythic_runtime.refresh_calls == 1, "dash-source Taiji success must still refresh the newly granted mythic consumer exactly once")
	_expect(owner.runtime_level_sync_calls == dash_owner_sync_before + 1, "dash-source Taiji success should publish owner raw levels exactly once")
	_expect((owner.values.get("runtime_perk_levels", {}) as Dictionary) == dash_state.runtime_skill_levels, "dash-source Taiji owner raw projection must match the final source-zero target-one state")

	var dash_rollback_state: Object = RuntimePerkState.new()
	dash_rollback_state.runtime_skill_levels = {"dash_amplification": 3}
	var dash_rollback_runtime := FakeDashState.new()
	var dash_rollback_registry: Object = _registry_for(
		dash_rollback_state,
		catalog,
		dash_rollback_runtime
	)
	dash_rollback_registry.instances["tower_ascent_unlock_store"] = unlock_store
	var dash_rollback_before: Dictionary = dash_rollback_state.build_tower_reward_mutation_snapshot()
	var dash_rejected: Dictionary = dash_rollback_state.apply_taiji_elder_exchange(
		"dash_amplification",
		"celestial_armor",
		owner,
		dash_rollback_registry,
		catalog,
		{"force_grant_rejection": true}
	)
	_expect(str(dash_rejected.get("blocked_reason", "")) == "taiji_exchange_choice_rejected", "dash rejection fixture must stop at the precommit grant gate")
	_expect(_unlock_semantics(dash_rollback_state.build_tower_reward_mutation_snapshot()) == _unlock_semantics(dash_rollback_before), "dash grant rejection must preserve all three raw levels")
	_expect(dash_rollback_runtime.reset_calls == 0, "precommit dash rejection must not touch external dash capacity before validation")
	print("tower_taiji_elder_atomic_exchange_seal: target_pool_sorted=1 unlocked=1 compatible=1 source_whole=1 target_lv1=1 grant_rejection_precommit=1 postcondition_precommit=1 partial_commit_rollback=1 fusion_hidden_rejected=1 source_character_rejected=1 acquisition_only_rejected=1 training_migrated_rejected=1 slot_expansion_rejected=1 owner_raw_sync_success_once=1 failure_owner_raw_sync=0 dash_whole=1 dash_resync=1 dash_owner_raw_sync_once=1 dash_mythic_refresh_once=1 dash_rejection_side_effects=0 cinematic_started=0 angel_acquisition_unchanged=1 angel_next_stage_active=1 mythic_refresh_success_once=1 failure_external_side_effects=0 unlock_byte_exact=1 fusion_byte_exact=1")


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
