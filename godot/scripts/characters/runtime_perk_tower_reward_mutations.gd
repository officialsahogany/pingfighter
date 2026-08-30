extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

const SNAPSHOT_VERSION := 1
const TARGET_KIND_PERK := "perk"
const TARGET_KIND_FUSION := "fusion"
const DASH_AMPLIFICATION_ID := "dash_amplification"


func build_mutation_snapshot(runtime_state: Object) -> Dictionary:
	if runtime_state == null or not runtime_state.has_method("build_unlock_save_snapshot"):
		return {}
	var unlock_value: Variant = runtime_state.call("build_unlock_save_snapshot")
	if not (unlock_value is Dictionary):
		return {}
	var fusion_snapshot: Dictionary = {}
	if runtime_state.has_method("get_perk_fusion_snapshot"):
		var fusion_value: Variant = runtime_state.call("get_perk_fusion_snapshot")
		if fusion_value is Dictionary:
			fusion_snapshot = (fusion_value as Dictionary).duplicate(true)
	return {
		"version": SNAPSHOT_VERSION,
		"unlock_save": (unlock_value as Dictionary).duplicate(true),
		"perk_fusion": fusion_snapshot,
		"dash_amplification_level": _raw_level(
			_get_runtime_levels(runtime_state),
			DASH_AMPLIFICATION_ID
		),
	}


func restore_mutation_snapshot_from_runtime_state(
	runtime_state: Object,
	snapshot: Dictionary,
	owner: Object = null,
	registry: Object = null,
	catalog: Object = null
) -> Dictionary:
	if runtime_state == null or snapshot.is_empty():
		return _rejected("invalid_mutation_snapshot")
	if not runtime_state.has_method("apply_unlock_save_snapshot"):
		return _rejected("missing_unlock_restore")
	var unlock_value: Variant = snapshot.get("unlock_save", null)
	if not (unlock_value is Dictionary):
		return _rejected("invalid_unlock_snapshot")
	var levels_before_restore: Dictionary = _get_runtime_levels(runtime_state)
	var dash_before_restore := _raw_level(levels_before_restore, DASH_AMPLIFICATION_ID)
	var unlock_result_value: Variant = runtime_state.call(
		"apply_unlock_save_snapshot",
		unlock_value as Dictionary,
		null,
		null
	)
	if not (
		unlock_result_value is Dictionary
		and bool((unlock_result_value as Dictionary).get("restored", false))
	):
		return _rejected("unlock_restore_failed")

	var resolved_catalog: Object = _resolve_catalog(catalog, registry)
	var fusion_snapshot: Dictionary = _dictionary(snapshot.get("perk_fusion", {}))
	var fusion_result: Dictionary = {}
	if runtime_state.has_method("restore_perk_fusion_snapshot"):
		var fusion_result_value: Variant = runtime_state.call(
			"restore_perk_fusion_snapshot",
			fusion_snapshot,
			resolved_catalog
		)
		if fusion_result_value is Dictionary:
			fusion_result = (fusion_result_value as Dictionary).duplicate(true)
		var expected_records := _array(fusion_snapshot.get("records", [])).size()
		if int(fusion_result.get("kept", -1)) != expected_records:
			return _rejected("fusion_restore_failed", {
				"expected_records": expected_records,
				"fusion_result": fusion_result,
			})
	elif not fusion_snapshot.is_empty() and not _array(
		fusion_snapshot.get("records", [])
	).is_empty():
		return _rejected("missing_fusion_restore")

	var restored_dash_level := _raw_level(
		_get_runtime_levels(runtime_state),
		DASH_AMPLIFICATION_ID
	)
	_sync_after_direct_mutation(
		runtime_state,
		owner,
		registry,
		dash_before_restore != restored_dash_level
	)
	return {
		"accepted": true,
		"restored": true,
		"unlock_result": (unlock_result_value as Dictionary).duplicate(true),
		"fusion_result": fusion_result,
	}


func build_replacement_plan_from_runtime_state(
	runtime_state: Object,
	target_token: Dictionary,
	new_choice: Dictionary,
	catalog: Object = null,
	slot_context: Object = null
) -> Dictionary:
	if runtime_state == null:
		return _rejected("missing_runtime_state")
	var resolved_catalog: Object = _resolve_catalog(catalog, slot_context)
	if resolved_catalog == null:
		return _rejected("missing_catalog")
	var levels: Dictionary = _get_runtime_levels(runtime_state)
	var choice_id := str(new_choice.get(
		"id",
		new_choice.get("perk_id", "")
	)).strip_edges()
	if choice_id.is_empty():
		return _rejected("invalid_replacement_choice")
	if _raw_level(levels, choice_id) > 0:
		return _rejected("replacement_choice_owned", {"choice_id": choice_id})
	var canonical_choice := _catalog_perk_data(resolved_catalog, choice_id)
	if canonical_choice.is_empty():
		return _rejected("missing_replacement_choice", {"choice_id": choice_id})
	canonical_choice["id"] = choice_id
	if (
		not RuntimePerkCatalog.is_slot_consuming_perk(canonical_choice)
		or RuntimePerkCatalog.get_slot_cost_for_level(canonical_choice, 1) != 1
	):
		return _rejected("replacement_choice_not_single_slot", {"choice_id": choice_id})

	var effective_slot_context: Object = slot_context if slot_context != null else runtime_state
	var apply_status := _catalog_slot_apply_status(
		resolved_catalog,
		canonical_choice,
		levels,
		effective_slot_context
	)
	if bool(apply_status.get("accepted", false)):
		return _rejected("replacement_not_required", {
			"choice_id": choice_id,
			"apply_status": apply_status,
		})
	if str(apply_status.get("blocked_reason", "")) != RuntimePerkCatalog.PERK_SLOT_LIMIT_BLOCKED_REASON:
		return _rejected("replacement_choice_blocked", {
			"choice_id": choice_id,
			"apply_status": apply_status,
		})

	var target_kind := str(target_token.get(
		"target_kind",
		target_token.get("type", "")
	)).strip_edges()
	var target_id := str(target_token.get(
		"target_id",
		target_token.get(
			"fusion_id",
			target_token.get(
				"_sort_id",
				target_token.get("perk_id", target_token.get("id", ""))
			)
		)
	)).strip_edges()
	if target_kind not in [TARGET_KIND_PERK, TARGET_KIND_FUSION] or target_id.is_empty():
		return _rejected("invalid_replacement_target")
	if target_id == choice_id:
		return _rejected("replacement_target_matches_choice")

	var projection := _runtime_projection(runtime_state, resolved_catalog)
	var projection_entry := _find_projection_entry(
		_array(projection.get("entries", [])),
		target_kind,
		target_id
	)
	if projection_entry.is_empty():
		return _rejected("stale_replacement_target", {
			"target_kind": target_kind,
			"target_id": target_id,
		})

	var fusion_snapshot := _runtime_fusion_snapshot(runtime_state)
	var slot_cell_index := int(target_token.get(
		"slot_cell_index",
		target_token.get("_slot_cell_index", 0)
	))
	var removed_perk_ids: Array[String] = []
	var target_raw_level := 0
	var drops_slot_limit := false
	if target_kind == TARGET_KIND_FUSION:
		var record := _find_fusion_record(fusion_snapshot, target_id)
		if record.is_empty():
			return _rejected("stale_fusion_target")
		var sources := _normalized_source_ids(record.get("sources", []))
		if sources.size() != 2:
			return _rejected("invalid_fusion_target")
		for source_id: String in sources:
			if _raw_level(levels, source_id) <= 0:
				return _rejected("stale_fusion_source", {"source_id": source_id})
			removed_perk_ids.append(source_id)
		drops_slot_limit = _fusion_target_drops_slot_limit(
			fusion_snapshot,
			target_id
		)
	else:
		var perk_id := str(projection_entry.get(
			"perk_id",
			projection_entry.get("id", "")
		)).strip_edges()
		if perk_id != target_id:
			return _rejected("stale_perk_target")
		target_raw_level = _raw_level(levels, perk_id)
		if target_raw_level <= 0:
			return _rejected("stale_perk_target")
		var target_slot_cost := int(projection_entry.get("slot_cost", 0))
		if perk_id == DASH_AMPLIFICATION_ID:
			if (
				target_slot_cost != target_raw_level
				or slot_cell_index < 0
				or slot_cell_index >= target_raw_level
			):
				return _rejected("invalid_dash_replacement_cell")
		elif target_slot_cost != 1 or slot_cell_index != 0:
			return _rejected("replacement_target_not_single_slot")
		removed_perk_ids.append(perk_id)

	var slot_status := _catalog_slot_status(
		resolved_catalog,
		levels,
		effective_slot_context
	)
	var current_slot_count := int(slot_status.get("count", 0))
	var current_slot_limit := int(slot_status.get("limit", 0))
	var post_slot_limit := current_slot_limit - (1 if drops_slot_limit else 0)
	if current_slot_count > post_slot_limit:
		return _rejected(
			"replacement_drops_slot_limit" if drops_slot_limit else "replacement_overoccupied",
			{
				"target_kind": target_kind,
				"target_id": target_id,
				"choice_id": choice_id,
				"current_slot_count": current_slot_count,
				"current_slot_limit": current_slot_limit,
				"post_slot_limit": post_slot_limit,
			}
		)

	return {
		"accepted": true,
		"target_kind": target_kind,
		"target_id": target_id,
		"choice_id": choice_id,
		"slot_cell_index": slot_cell_index,
		"target_raw_level": target_raw_level,
		"removed_perk_ids": removed_perk_ids,
		"removed_fusion_id": target_id if target_kind == TARGET_KIND_FUSION else "",
		"drops_slot_limit": drops_slot_limit,
		"current_slot_count": current_slot_count,
		"current_slot_limit": current_slot_limit,
		"post_slot_limit": post_slot_limit,
		"apply_status": apply_status,
		"state_signature": hash([
			levels,
			int(projection.get("fusion_revision", 0)),
			target_kind,
			target_id,
			slot_cell_index,
			choice_id,
		]),
	}


func apply_replacement_from_runtime_state(
	runtime_state: Object,
	target_token: Dictionary,
	new_choice: Dictionary,
	owner: Object,
	registry: Object,
	catalog: Object = null,
	apply_choice_override: Callable = Callable()
) -> Dictionary:
	var resolved_catalog := _resolve_catalog(catalog, registry)
	var slot_context: Object = registry if registry != null else runtime_state
	var plan := build_replacement_plan_from_runtime_state(
		runtime_state,
		target_token,
		new_choice,
		resolved_catalog,
		slot_context
	)
	if not bool(plan.get("accepted", false)):
		return plan
	var before_snapshot := build_mutation_snapshot(runtime_state)
	if before_snapshot.is_empty():
		return _rejected("snapshot_capture_failed")
	var removal_result := _apply_planned_removal(
		runtime_state,
		plan,
		resolved_catalog
	)
	if not bool(removal_result.get("accepted", false)):
		var removal_restore := restore_mutation_snapshot_from_runtime_state(
			runtime_state,
			before_snapshot,
			owner,
			registry,
			resolved_catalog
		)
		return _rejected(str(removal_result.get("blocked_reason", "replacement_removal_failed")), {
			"rollback": removal_restore,
		})
	var canonical_choice := _catalog_perk_data(
		resolved_catalog,
		str(plan.get("choice_id", ""))
	)
	canonical_choice["id"] = str(plan.get("choice_id", ""))
	var choice_applied := bool(apply_choice_override.call(
		runtime_state,
		canonical_choice,
		owner,
		registry
	)) if apply_choice_override.is_valid() else (
		runtime_state.has_method("apply_choice")
		and bool(runtime_state.call(
			"apply_choice",
			canonical_choice,
			owner,
			registry
		))
	)
	if not choice_applied:
		var rejected_restore := restore_mutation_snapshot_from_runtime_state(
			runtime_state,
			before_snapshot,
			owner,
			registry,
			resolved_catalog
		)
		return _rejected("replacement_choice_rejected", {"rollback": rejected_restore})

	var levels_after: Dictionary = _get_runtime_levels(runtime_state)
	var choice_id := str(plan.get("choice_id", ""))
	var final_status := _catalog_slot_status(
		resolved_catalog,
		levels_after,
		slot_context
	)
	var final_valid := (
		_raw_level(levels_after, choice_id) > 0
		and int(final_status.get("count", -1)) == int(plan.get("current_slot_count", -2))
		and int(final_status.get("count", 0)) <= int(final_status.get("limit", 0))
	)
	if not final_valid:
		var validation_restore := restore_mutation_snapshot_from_runtime_state(
			runtime_state,
			before_snapshot,
			owner,
			registry,
			resolved_catalog
		)
		return _rejected("replacement_postcondition_failed", {
			"final_status": final_status,
			"rollback": validation_restore,
		})

	if (
		str(plan.get("target_kind", "")) == TARGET_KIND_PERK
		and str(plan.get("target_id", "")) == DASH_AMPLIFICATION_ID
	):
		_sync_after_direct_mutation(runtime_state, owner, registry, true)
	var result := plan.duplicate(true)
	result["accepted"] = true
	result["applied"] = true
	result["final_slot_status"] = final_status
	result["removal"] = removal_result
	return result


# Taiji Elder owns candidate presentation and source visibility policy. This
# transaction layer owns only the revalidated exchange boundary: the caller
# supplies one visible ordinary source id and one id from this sorted eligible
# mythic list. Rejections remain mutation-free; a partial direct commit restores
# exact raw levels before any external consumer sync runs.
func build_taiji_elder_mythic_target_ids_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Array[String]:
	var result: Array[String] = []
	if runtime_state == null:
		return result
	var resolved_catalog := _resolve_catalog(catalog, registry)
	var levels := _get_runtime_levels(runtime_state)
	var character_type := _selected_character_type(owner)
	for target_value: Variant in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		var target_id := str(target_value).strip_edges()
		if target_id.is_empty() or _raw_level(levels, target_id) > 0:
			continue
		var canonical_value: Variant = RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.get(
			target_id,
			{}
		)
		if not (canonical_value is Dictionary):
			continue
		var canonical := canonical_value as Dictionary
		if not _is_perk_allowed_for_character(canonical, character_type):
			continue
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
			target_id
		):
			continue
		var catalog_data := _catalog_perk_data(resolved_catalog, target_id)
		if (
			catalog_data.is_empty()
			or str(catalog_data.get("rarity", "")).strip_edges().to_lower() != "mythic"
		):
			continue
		result.append(target_id)
	result.sort()
	return result


func build_taiji_elder_exchange_plan_from_runtime_state(
	runtime_state: Object,
	source_perk_id: String,
	target_mythic_id: String,
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Dictionary:
	if runtime_state == null:
		return _rejected("missing_runtime_state")
	var source_id := source_perk_id.strip_edges()
	var target_id := target_mythic_id.strip_edges()
	if source_id.is_empty():
		return _rejected("invalid_taiji_exchange_source")
	if target_id.is_empty() or source_id == target_id:
		return _rejected("invalid_taiji_exchange_target")
	var resolved_catalog := _resolve_catalog(catalog, registry)
	if resolved_catalog == null:
		return _rejected("missing_catalog")
	var levels := _get_runtime_levels(runtime_state)
	var source_raw_level := _raw_level(levels, source_id)
	if source_raw_level <= 0:
		return _rejected("taiji_exchange_source_not_owned", {"source_id": source_id})
	var source_data := _catalog_perk_data(resolved_catalog, source_id)
	if source_data.is_empty():
		return _rejected("taiji_exchange_source_not_ordinary", {"source_id": source_id})
	source_data["id"] = source_id
	if not _is_perk_allowed_for_character(
		source_data,
		_selected_character_type(owner)
	):
		return _rejected("taiji_exchange_source_character_incompatible", {
			"source_id": source_id,
		})
	if (
		RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(source_id)
		or RuntimePerkCatalog.ACQUISITION_ONLY_PERKS.has(source_id)
		or str(source_data.get("rarity", "")).strip_edges().to_lower() == "mythic"
		or str(source_data.get("tree", "")).strip_edges().to_lower() == "mythic"
		or RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(source_id)
		or source_id == RuntimePerkCatalog.SLOT_EXPANSION_PERK_ID
		or source_id.begins_with("physique_")
		or source_id in ["convert_to_gold", "mystic_dice"]
		or bool(RuntimePerkCatalog.LINGPET_GATED_CHOICE_IDS.get(source_id, false))
		or not str(source_data.get("unlocks_skill", "")).strip_edges().is_empty()
		or bool(source_data.get("is_instant", false))
		or bool(source_data.get("is_gold_conversion", false))
		or bool(source_data.get("is_physique_training", false))
		or bool(source_data.get("is_mystic_dice", false))
		or bool(source_data.get("is_perk_fusion", false))
		or bool(source_data.get("is_lingpet_guardian_enhance", false))
		or not RuntimePerkCatalog.is_slot_consuming_perk(source_data)
		or RuntimePerkCatalog.get_slot_cost_for_level(source_data, source_raw_level) <= 0
	):
		return _rejected("taiji_exchange_source_not_ordinary", {"source_id": source_id})
	var fusion_snapshot := _runtime_fusion_snapshot(runtime_state)
	if _fusion_snapshot_has_source(fusion_snapshot, source_id):
		return _rejected("taiji_exchange_source_fusion_hidden", {"source_id": source_id})

	var eligible_targets := build_taiji_elder_mythic_target_ids_from_runtime_state(
		runtime_state,
		owner,
		registry,
		resolved_catalog
	)
	if target_id not in eligible_targets:
		if not RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(target_id):
			return _rejected("taiji_exchange_target_not_canonical_mythic", {"target_id": target_id})
		if _raw_level(levels, target_id) > 0:
			return _rejected("taiji_exchange_target_owned", {"target_id": target_id})
		var target_definition: Dictionary = RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.get(
			target_id,
			{}
		)
		if not _is_perk_allowed_for_character(
			target_definition,
			_selected_character_type(owner)
		):
			return _rejected("taiji_exchange_target_character_incompatible", {"target_id": target_id})
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
			target_id
		):
			return _rejected("taiji_exchange_target_locked", {"target_id": target_id})
		return _rejected("taiji_exchange_target_unavailable", {"target_id": target_id})

	var target_choice := _catalog_perk_data(resolved_catalog, target_id)
	target_choice["id"] = target_id
	target_choice["current_level"] = 0
	target_choice["next_level"] = 1
	target_choice["source"] = "tower_taiji_elder_exchange"
	var projected_levels := levels.duplicate(true)
	_write_level(projected_levels, source_id, 0)
	var slot_context: Object = registry if registry != null else runtime_state
	var target_slot_status := _catalog_slot_apply_status(
		resolved_catalog,
		target_choice,
		projected_levels,
		slot_context
	)
	if not bool(target_slot_status.get("accepted", false)):
		return _rejected("taiji_exchange_target_slot_blocked", {
			"target_id": target_id,
			"slot_status": target_slot_status,
		})
	return {
		"accepted": true,
		"source_id": source_id,
		"source_raw_level": source_raw_level,
		"target_id": target_id,
		"target_level": 1,
		"target_choice": target_choice,
		"target_slot_status": target_slot_status,
		"state_signature": hash([
			levels,
			fusion_snapshot,
			source_id,
			target_id,
			_selected_character_type(owner),
		]),
	}


func apply_taiji_elder_exchange_from_runtime_state(
	runtime_state: Object,
	source_perk_id: String,
	target_mythic_id: String,
	owner: Object,
	registry: Object,
	catalog: Object = null,
	transaction_hooks: Dictionary = {}
) -> Dictionary:
	var resolved_catalog := _resolve_catalog(catalog, registry)
	var plan := build_taiji_elder_exchange_plan_from_runtime_state(
		runtime_state,
		source_perk_id,
		target_mythic_id,
		owner,
		registry,
		resolved_catalog
	)
	if not bool(plan.get("accepted", false)):
		return plan
	var before_snapshot := build_mutation_snapshot(runtime_state)
	if before_snapshot.is_empty():
		return _rejected("snapshot_capture_failed")
	var levels := _get_runtime_levels(runtime_state)
	var source_id := str(plan.get("source_id", ""))
	var target_id := str(plan.get("target_id", ""))
	var grant_invoked := false
	var choice_applied := false
	if not bool(transaction_hooks.get("force_grant_rejection", false)):
		grant_invoked = true
		# Taiji Elder owns a modal result hold, so its exact level-one mythic
		# grant must not enter generic acquisition presentation or Angel
		# Blessing's first-acquisition lifecycle. Focused counterproof hooks are
		# boolean failure gates only; no callback can enter an external owner.
		# Production commits the raw level below after every postcondition passes.
		choice_applied = true
	if not choice_applied:
		var rejected_restore := _restore_taiji_levels_exact(
			runtime_state,
			before_snapshot
		)
		return _rejected("taiji_exchange_choice_rejected", {
			"grant_invoked": grant_invoked,
			"rollback": rejected_restore,
		})

	var unlock_before: Dictionary = before_snapshot.get("unlock_save", {}) as Dictionary
	var expected_levels: Dictionary = (
		unlock_before.get("runtime_skill_levels", {}) as Dictionary
	).duplicate(true)
	_write_level(expected_levels, source_id, 0)
	_write_level(expected_levels, target_id, 1)
	var fusion_after := _runtime_fusion_snapshot(runtime_state)
	var final_slot_status := _catalog_slot_status(
		resolved_catalog,
		expected_levels,
		registry if registry != null else runtime_state
	)
	var final_valid := (
		not bool(transaction_hooks.get("force_postcondition_failure", false))
		and levels == (unlock_before.get("runtime_skill_levels", {}) as Dictionary)
		and fusion_after == _dictionary(before_snapshot.get("perk_fusion", {}))
		and _raw_level(expected_levels, source_id) == 0
		and _raw_level(expected_levels, target_id) == 1
		and int(final_slot_status.get("count", 0)) <= int(final_slot_status.get("limit", -1))
	)
	if not final_valid:
		var validation_restore := _restore_taiji_levels_exact(
			runtime_state,
			before_snapshot
		)
		return _rejected("taiji_exchange_postcondition_failed", {
			"grant_invoked": grant_invoked,
			"final_slot_status": final_slot_status,
			"rollback": validation_restore,
		})

	_write_level(levels, source_id, 0)
	_write_level(levels, target_id, 1)
	if bool(transaction_hooks.get("force_commit_failure", false)):
		_write_level(levels, target_id, 0)
	var levels_after := _get_runtime_levels(runtime_state).duplicate(true)
	if levels_after != expected_levels:
		var commit_restore := _restore_taiji_levels_exact(runtime_state, before_snapshot)
		return _rejected("taiji_exchange_commit_failed", {
			"grant_invoked": grant_invoked,
			"final_slot_status": final_slot_status,
			"rollback": commit_restore,
		})

	_sync_after_direct_mutation(
		runtime_state,
		owner,
		registry,
		source_id == DASH_AMPLIFICATION_ID
	)
	var result := plan.duplicate(true)
	result.erase("target_choice")
	result["accepted"] = true
	result["applied"] = true
	result["grant_invoked"] = grant_invoked
	result["grant_path"] = "taiji_exact_level_one"
	result["acquisition_side_effects_started"] = false
	result["final_slot_status"] = final_slot_status
	return result


func _restore_taiji_levels_exact(
	runtime_state: Object,
	before_snapshot: Dictionary
) -> Dictionary:
	var unlock_before: Dictionary = before_snapshot.get("unlock_save", {}) as Dictionary
	var before_levels_value: Variant = unlock_before.get("runtime_skill_levels", null)
	if not (before_levels_value is Dictionary):
		return _rejected("invalid_taiji_unlock_snapshot")
	var before_levels := (before_levels_value as Dictionary).duplicate(true)
	var levels := _get_runtime_levels(runtime_state)
	var levels_were_unchanged := levels == before_levels
	levels.clear()
	levels.merge(before_levels, true)
	var fusion_unchanged := (
		_runtime_fusion_snapshot(runtime_state)
		== _dictionary(before_snapshot.get("perk_fusion", {}))
	)
	var restored := levels == before_levels and fusion_unchanged
	return {
		"accepted": restored,
		"restored": restored,
		"mutation_free": levels_were_unchanged and fusion_unchanged,
		"unlock_byte_exact": levels == before_levels,
		"fusion_byte_exact": fusion_unchanged,
	}


func _apply_planned_removal(
	runtime_state: Object,
	plan: Dictionary,
	catalog: Object
) -> Dictionary:
	var levels := _get_runtime_levels(runtime_state)
	var target_kind := str(plan.get("target_kind", ""))
	var target_id := str(plan.get("target_id", ""))
	if target_kind == TARGET_KIND_PERK:
		var current_level := _raw_level(levels, target_id)
		if current_level <= 0:
			return _rejected("stale_perk_target")
		if target_id == DASH_AMPLIFICATION_ID:
			if current_level != int(plan.get("target_raw_level", -1)):
				return _rejected("stale_dash_replacement_cell")
			_write_level(levels, target_id, current_level - 1)
		else:
			_write_level(levels, target_id, 0)
		return {
			"accepted": true,
			"target_kind": target_kind,
			"target_id": target_id,
		}

	if target_kind != TARGET_KIND_FUSION:
		return _rejected("invalid_replacement_target")
	if not runtime_state.has_method("restore_perk_fusion_snapshot"):
		return _rejected("missing_fusion_restore")
	var fusion_snapshot := _runtime_fusion_snapshot(runtime_state)
	var records := _array(fusion_snapshot.get("records", []))
	var kept_records: Array = []
	var removed_record: Dictionary = {}
	for record_value: Variant in records:
		if not (record_value is Dictionary):
			continue
		var record := record_value as Dictionary
		if str(record.get("fusion_id", "")).strip_edges() == target_id:
			removed_record = record.duplicate(true)
			continue
		kept_records.append(record.duplicate(true))
	if removed_record.is_empty():
		return _rejected("stale_fusion_target")
	var source_ids := _normalized_source_ids(removed_record.get("sources", []))
	if source_ids.size() != 2:
		return _rejected("invalid_fusion_target")
	for source_id: String in source_ids:
		_write_level(levels, source_id, 0)
	var filtered_snapshot := fusion_snapshot.duplicate(true)
	filtered_snapshot["records"] = kept_records
	var restore_value: Variant = runtime_state.call(
		"restore_perk_fusion_snapshot",
		filtered_snapshot,
		catalog
	)
	var restore_result: Dictionary = (
		(restore_value as Dictionary).duplicate(true)
		if restore_value is Dictionary
		else {}
	)
	if int(restore_result.get("kept", -1)) != kept_records.size():
		return _rejected("fusion_filter_restore_failed", {
			"fusion_result": restore_result,
		})
	return {
		"accepted": true,
		"target_kind": target_kind,
		"target_id": target_id,
		"removed_sources": source_ids,
		"fusion_result": restore_result,
	}


func _sync_after_direct_mutation(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	dash_capacity_changed: bool
) -> void:
	if runtime_state == null or owner == null:
		return
	if runtime_state.has_method("_sync_owner"):
		runtime_state.call("_sync_owner", owner)
	if dash_capacity_changed and runtime_state.has_method("_apply_level_side_effect"):
		runtime_state.call(
			"_apply_level_side_effect",
			{"id": DASH_AMPLIFICATION_ID},
			owner,
			registry
		)
		return
	if runtime_state.has_method("_sync_runtime_perk_owner_effects"):
		runtime_state.call("_sync_runtime_perk_owner_effects", owner, registry)
	if runtime_state.has_method("_refresh_mythic_runtime_perk_consumers"):
		runtime_state.call("_refresh_mythic_runtime_perk_consumers", owner, registry)


func _fusion_target_drops_slot_limit(
	fusion_snapshot: Dictionary,
	target_fusion_id: String
) -> bool:
	if not PerkConversionFlags.is_enabled():
		return false
	var target_owns_expansion := false
	var retained_owns_expansion := false
	for record_value: Variant in _array(fusion_snapshot.get("records", [])):
		if not (record_value is Dictionary):
			continue
		var record := record_value as Dictionary
		if not _record_has_byproduct(
			record,
			RuntimePerkCatalog.FUSION_SLOT_EXPANSION_BYPRODUCT_ID
		):
			continue
		if str(record.get("fusion_id", "")).strip_edges() == target_fusion_id:
			target_owns_expansion = true
		else:
			retained_owns_expansion = true
	return target_owns_expansion and not retained_owns_expansion


func _record_has_byproduct(record: Dictionary, byproduct_id: String) -> bool:
	for value: Variant in _array(record.get("byproducts", [])):
		var resolved_id := str((value as Dictionary).get("id", "")) if value is Dictionary else str(value)
		if resolved_id.strip_edges() == byproduct_id:
			return true
	return false


func _find_projection_entry(
	entries: Array,
	target_kind: String,
	target_id: String
) -> Dictionary:
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var entry_type := str(entry.get("type", TARGET_KIND_PERK))
		if target_kind == TARGET_KIND_FUSION:
			if (
				entry_type == TARGET_KIND_FUSION
				and str(entry.get("fusion_id", entry.get("id", ""))).strip_edges() == target_id
			):
				return entry.duplicate(true)
			continue
		if (
			entry_type == TARGET_KIND_PERK
			and str(entry.get("perk_id", entry.get("id", ""))).strip_edges() == target_id
		):
			return entry.duplicate(true)
	return {}


func _find_fusion_record(snapshot: Dictionary, fusion_id: String) -> Dictionary:
	for record_value: Variant in _array(snapshot.get("records", [])):
		if (
			record_value is Dictionary
			and str((record_value as Dictionary).get("fusion_id", "")).strip_edges() == fusion_id
		):
			return (record_value as Dictionary).duplicate(true)
	return {}


func _normalized_source_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for source_value: Variant in _array(value):
		var source_id := str(source_value).strip_edges()
		if source_id.is_empty() or source_id in result:
			return []
		result.append(source_id)
	result.sort()
	return result


func _fusion_snapshot_has_source(snapshot: Dictionary, source_id: String) -> bool:
	for record_value: Variant in _array(snapshot.get("records", [])):
		if not (record_value is Dictionary):
			continue
		var record := record_value as Dictionary
		if source_id in _normalized_source_ids(record.get("sources", [])):
			return true
	return false


func _is_perk_allowed_for_character(
	perk_data: Dictionary,
	character_type: String
) -> bool:
	var restriction := str(
		perk_data.get("character_restriction", "")
	).strip_edges().to_lower()
	return restriction.is_empty() or restriction == character_type


func _selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	var resolved := str(value).strip_edges().to_lower() if value != null else ""
	return resolved if not resolved.is_empty() else "smasher"


func _runtime_projection(runtime_state: Object, catalog: Object) -> Dictionary:
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_display_projection"):
		return {}
	var value: Variant = runtime_state.call("get_perk_fusion_display_projection", catalog)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _runtime_fusion_snapshot(runtime_state: Object) -> Dictionary:
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_snapshot"):
		return {}
	var value: Variant = runtime_state.call("get_perk_fusion_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _catalog_perk_data(catalog: Object, perk_id: String) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_data"):
		return {}
	var value: Variant = catalog.call("get_perk_data", perk_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _catalog_slot_apply_status(
	catalog: Object,
	choice: Dictionary,
	levels: Dictionary,
	slot_context: Object
) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_slot_apply_status"):
		return {}
	var value: Variant = catalog.call(
		"get_perk_slot_apply_status",
		choice,
		levels,
		slot_context
	)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _catalog_slot_status(
	catalog: Object,
	levels: Dictionary,
	slot_context: Object
) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_slot_status"):
		return {}
	var value: Variant = catalog.call("get_perk_slot_status", levels, slot_context)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _resolve_catalog(catalog: Object, registry: Object = null) -> Object:
	if catalog != null and catalog.has_method("get_perk_data"):
		return catalog
	if registry != null:
		for method_name: String in ["get_cached_instance", "get_instance"]:
			if not registry.has_method(method_name):
				continue
			var value: Variant = registry.call(method_name, "runtime_perk_catalog")
			if value is Object and value != null:
				return value as Object
	return RuntimePerkCatalog.new()


func _get_runtime_levels(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get("runtime_skill_levels")
	return value as Dictionary if value is Dictionary else {}


func _raw_level(levels: Dictionary, perk_id: String) -> int:
	return maxi(
		maxi(0, int(levels.get(perk_id, 0))),
		maxi(0, int(levels.get(StringName(perk_id), 0)))
	)


func _write_level(levels: Dictionary, perk_id: String, level: int) -> void:
	levels.erase(perk_id)
	levels.erase(StringName(perk_id))
	if level > 0:
		levels[perk_id] = level


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _rejected(reason: String, details: Dictionary = {}) -> Dictionary:
	var result := details.duplicate(true)
	result["accepted"] = false
	result["applied"] = false
	result["blocked_reason"] = reason
	return result
