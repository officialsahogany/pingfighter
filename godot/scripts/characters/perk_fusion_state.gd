extends RefCounted

const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")

# Serialized record schema (v1):
# {
#   "fusion_id": String, "sources": Array[String] (exactly two, sorted),
#   "outcome": String, "option_penalties": Dictionary,
#   "deleted_options": Dictionary, "byproducts": Array,
#   "byproduct_payloads": Dictionary,
#   "slot_reduction": 1,
# }
const RECORD_SCHEMA_VERSION := 1
const RECORD_SOURCE_COUNT := 2
const SLOT_REDUCTION_PER_RECORD := 1
const FUSION_ID_PREFIX := "fusion_"

const RESTORED_SOURCE_ALIASES := {
	"spiked_helmet": "bulletproof_hat",
}

# 은퇴 상승무공은 커밋·복원 양쪽에서 레코드로부터 제거한다. 구 세이브 레코드가
# 효과 없는 표시 항목을 계속 실어 오는 것을 막는 자가 치유 경로다.
const RETIRED_BYPRODUCT_IDS: Array[String] = ["sleeve_cosmos"]

const RESTORED_OPTION_ALIASES := {
	"bulletproof_hat": {"stun_resist_pct": "posture_correction_pct"},
	"spiked_helmet": {"knockback_resist_pct": "posture_correction_pct"},
}

var _records: Array[Dictionary] = []
var _next_fusion_index := 0
var _revision := 0
var _next_fusion_core_stabilize := false
var _next_fusion_dual_catalyst := false
var _fusion_catalog := PerkFusionCatalog.new()


func reset() -> void:
	_records.clear()
	_next_fusion_index = 0
	_next_fusion_core_stabilize = false
	_next_fusion_dual_catalyst = false
	_revision += 1


func get_all_records() -> Array[Dictionary]:
	return _records.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": RECORD_SCHEMA_VERSION,
		"records": _records.duplicate(true),
		"next_fusion_index": _next_fusion_index,
		"fusion_revision": _revision,
		"next_fusion_core_stabilize": _next_fusion_core_stabilize,
		"next_fusion_dual_catalyst": _next_fusion_dual_catalyst,
	}


func get_revision() -> int:
	return _revision


func get_next_fusion_index() -> int:
	return _next_fusion_index


func get_next_fusion_token_snapshot() -> Dictionary:
	return {
		"core_stabilize_armed": _next_fusion_core_stabilize,
		"dual_catalyst_armed": _next_fusion_dual_catalyst,
	}


func is_core_stabilize_armed() -> bool:
	return _next_fusion_core_stabilize


func is_dual_catalyst_armed() -> bool:
	return _next_fusion_dual_catalyst


func get_owned_byproduct_ids() -> Array[String]:
	var owned: Array[String] = []
	for record: Dictionary in _records:
		for value: Variant in _array_or_empty(record.get("byproducts", [])):
			var byproduct_id := str(value).strip_edges()
			if not byproduct_id.is_empty() and byproduct_id not in owned:
				owned.append(byproduct_id)
	owned.sort()
	return owned


func get_slot_reduction_count() -> int:
	return _records.size() * SLOT_REDUCTION_PER_RECORD


func get_slot_reduction() -> int:
	return get_slot_reduction_count()


func get_fused_source_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	for record: Dictionary in _records:
		var sources: Array = record.get("sources", []) as Array
		for source_value: Variant in sources:
			lookup[str(source_value)] = str(record.get("fusion_id", ""))
	return lookup


func is_source_fused(perk_id: String) -> bool:
	return get_fused_source_lookup().has(perk_id)


func get_record_for_source(perk_id: String) -> Dictionary:
	var record := _get_record_ref_for_source(perk_id)
	return record.duplicate(true) if not record.is_empty() else {}


func _get_record_ref_for_source(perk_id: String) -> Dictionary:
	for record: Dictionary in _records:
		var sources: Array = record.get("sources", []) as Array
		if perk_id in sources:
			return record
	return {}


func apply_option_value(perk_id: String, option_key: String, base_value: float) -> float:
	var clean_perk_id: String = perk_id.strip_edges()
	var clean_option_key: String = option_key.strip_edges()
	if clean_perk_id.is_empty() or clean_option_key.is_empty():
		return base_value
	# Hot stat queries only read the committed record. Keep the public accessor
	# copy-safe, but avoid a deep copy for every physics-tick option lookup.
	var record: Dictionary = _get_record_ref_for_source(clean_perk_id)
	if record.is_empty():
		return base_value
	if _is_option_deleted(record, clean_perk_id, clean_option_key):
		return 0.0

	var penalties: Dictionary = _dictionary_or_empty(record.get("option_penalties", {}))
	var source_penalties: Dictionary = _dictionary_or_empty(
		_get_string_key_value(penalties, clean_perk_id)
	)
	var entry: Variant = _get_string_key_value(source_penalties, clean_option_key)
	if entry is Dictionary:
		var adjustment: Dictionary = entry as Dictionary
		# Keep the committed before->after values as the immutable S4 log, but
		# re-run integer quantization against the live effective-level value. A
		# fixed commit-time integer would drift outside the promised 10-30% range
		# when crowns/rings/other level bonuses grow the source later.
		if str(adjustment.get("value_kind", "")) == "int":
			var magnitude := float(adjustment.get("nominal_pct", 0.0)) / 100.0
			if magnitude <= 0.0:
				magnitude = absf(float(adjustment.get("multiplier", 1.0)) - 1.0)
			var quantized: Dictionary
			if str(adjustment.get("polarity", "forward")) == "reverse":
				quantized = PerkFusionOutcomeRules.apply_reverse_integer_penalty(
					int(round(base_value)),
					magnitude
				)
			else:
				quantized = PerkFusionOutcomeRules.apply_forward_integer_penalty(
					int(round(base_value)),
					magnitude
				)
			if bool(quantized.get("applied", false)):
				return float(quantized.get("value", int(round(base_value))))
			return base_value
		if adjustment.has("multiplier"):
			return base_value * float(adjustment.get("multiplier", 1.0))
		if adjustment.has("adjusted_value"):
			return float(adjustment.get("adjusted_value", base_value))
	return base_value


func apply_skill_bonus(perk_id: String, base_value: float) -> float:
	return apply_option_value(perk_id, "runtime_skill_bonus", base_value)


func get_effective_level_bonus(perk_id: String) -> int:
	var clean_perk_id: String = perk_id.strip_edges()
	if clean_perk_id.is_empty():
		return 0
	var bonus := 0
	for record: Dictionary in _records:
		var sources: Array = record.get("sources", []) as Array
		if clean_perk_id not in sources:
			continue
		var byproducts: Array = record.get("byproducts", []) as Array
		if "limit_break" not in byproducts:
			continue
		var payloads: Dictionary = _dictionary_or_empty(record.get("byproduct_payloads", {}))
		var limit_break_payload: Dictionary = _dictionary_or_empty(payloads.get("limit_break", {}))
		var eligible_sources: Array = limit_break_payload.get("eligible_sources", []) as Array
		if clean_perk_id in eligible_sources:
			bonus += 1
	return bonus


func get_candidates(runtime_catalog: Object, runtime_levels: Dictionary) -> Array[String]:
	return _fusion_catalog.get_candidate_ids(runtime_levels, runtime_catalog, self)


func commit_fusion(
	source_ids: Array,
	outcome_data: Dictionary,
	runtime_catalog: Object,
	runtime_levels: Dictionary
) -> Dictionary:
	return create_record(source_ids, runtime_levels, runtime_catalog, outcome_data)


func create_record(
	source_ids: Array,
	runtime_levels: Dictionary,
	runtime_catalog: Object,
	record_data: Dictionary = {}
) -> Dictionary:
	var sources: Array[String] = _normalize_sources(source_ids)
	if sources.size() != RECORD_SOURCE_COUNT:
		return {}
	var fused_lookup: Dictionary = get_fused_source_lookup()
	for source_id: String in sources:
		var base_level: int = _get_base_level(runtime_levels, source_id)
		if not _fusion_catalog.is_candidate(source_id, base_level, runtime_catalog, fused_lookup):
			return {}
	var pair_key: String = _pair_key(sources)
	if _has_pair(pair_key):
		return {}

	var fusion_id: String = _allocate_fusion_id()
	var record: Dictionary = record_data.duplicate(true)
	record["fusion_id"] = fusion_id
	record["sources"] = sources.duplicate()
	record["outcome"] = str(record.get("outcome", "success"))
	record["option_penalties"] = _dictionary_or_empty(record.get("option_penalties", {}))
	record["deleted_options"] = _dictionary_or_empty(record.get("deleted_options", {}))
	record["commit_value_snapshots"] = _dictionary_or_empty(record.get("commit_value_snapshots", {}))
	record["byproducts"] = _array_or_empty(record.get("byproducts", []))
	record["byproduct_payloads"] = _dictionary_or_empty(record.get("byproduct_payloads", {}))
	_prune_retired_byproducts(record)
	record["slot_reduction"] = SLOT_REDUCTION_PER_RECORD
	record["created_revision"] = _revision + 1
	_apply_token_transaction(record)
	_records.append(record.duplicate(true))
	_revision += 1
	return record.duplicate(true)


func restore_snapshot(
	snapshot: Dictionary,
	runtime_catalog: Object,
	runtime_levels: Dictionary
) -> Dictionary:
	var restored_records: Array[Dictionary] = []
	var fused_lookup: Dictionary = {}
	var pair_lookup: Dictionary = {}
	var fusion_id_lookup: Dictionary = {}
	var dropped_by_reason: Dictionary = {}
	var raw_records: Array = snapshot.get("records", []) as Array
	var max_valid_index := -1

	for raw_record_value: Variant in raw_records:
		var validation: Dictionary = _validate_restored_record(
			raw_record_value,
			runtime_levels,
			runtime_catalog,
			fused_lookup,
			pair_lookup,
			fusion_id_lookup
		)
		var reason: String = str(validation.get("reason", ""))
		if not reason.is_empty():
			dropped_by_reason[reason] = int(dropped_by_reason.get(reason, 0)) + 1
			continue

		var record: Dictionary = validation.get("record", {}) as Dictionary
		var sources: Array = record.get("sources", []) as Array
		var fusion_id: String = str(record.get("fusion_id", ""))
		restored_records.append(record.duplicate(true))
		fusion_id_lookup[fusion_id] = true
		pair_lookup[_pair_key(_normalize_sources(sources))] = true
		for source_value: Variant in sources:
			fused_lookup[str(source_value)] = fusion_id
		max_valid_index = maxi(max_valid_index, _fusion_index_from_id(fusion_id))

	_records = restored_records
	var serialized_next: int = maxi(0, int(snapshot.get("next_fusion_index", 0)))
	_next_fusion_index = maxi(serialized_next, max_valid_index + 1)
	_next_fusion_core_stabilize = bool(snapshot.get("next_fusion_core_stabilize", false))
	_next_fusion_dual_catalyst = bool(snapshot.get("next_fusion_dual_catalyst", false))
	var serialized_revision: int = maxi(0, int(snapshot.get("fusion_revision", 0)))
	_revision = maxi(_revision, serialized_revision) + 1
	return {
		"kept": _records.size(),
		"dropped": raw_records.size() - _records.size(),
		"dropped_by_reason": dropped_by_reason.duplicate(true),
		"revision": _revision,
	}


func _validate_restored_record(
	raw_record_value: Variant,
	runtime_levels: Dictionary,
	runtime_catalog: Object,
	fused_lookup: Dictionary,
	pair_lookup: Dictionary,
	fusion_id_lookup: Dictionary
) -> Dictionary:
	if not raw_record_value is Dictionary:
		return {"reason": "missing_record_fields"}
	var raw_record: Dictionary = _migrate_restored_record(raw_record_value as Dictionary)
	var fusion_id: String = str(raw_record.get("fusion_id", "")).strip_edges()
	var raw_sources_value: Variant = raw_record.get("sources", null)
	if fusion_id.is_empty() or not raw_sources_value is Array:
		return {"reason": "missing_record_fields"}
	if fusion_id_lookup.has(fusion_id):
		return {"reason": "duplicate_fusion_id"}

	var sources: Array[String] = _normalize_sources(raw_sources_value as Array)
	if sources.size() != RECORD_SOURCE_COUNT:
		return {"reason": "invalid_source_pair"}
	var pair_key: String = _pair_key(sources)
	if pair_lookup.has(pair_key):
		return {"reason": "duplicate_pair"}

	for source_id: String in sources:
		var perk_data: Dictionary = _get_perk_data(runtime_catalog, source_id)
		if perk_data.is_empty():
			return {"reason": "missing_source"}
		var base_level: int = _get_base_level(runtime_levels, source_id)
		if base_level <= 0:
			return {"reason": "source_not_owned"}
		if base_level != int(perk_data.get("max_level", 0)):
			return {"reason": "source_not_maxed"}
		if not _fusion_catalog.is_candidate(source_id, base_level, runtime_catalog):
			return {"reason": "source_not_candidate"}
		if fused_lookup.has(source_id):
			return {"reason": "source_reused"}

	var record: Dictionary = raw_record.duplicate(true)
	record["fusion_id"] = fusion_id
	record["sources"] = sources.duplicate()
	record["outcome"] = str(record.get("outcome", "success"))
	record["option_penalties"] = _dictionary_or_empty(record.get("option_penalties", {}))
	record["deleted_options"] = _dictionary_or_empty(record.get("deleted_options", {}))
	record["commit_value_snapshots"] = _dictionary_or_empty(record.get("commit_value_snapshots", {}))
	record["byproducts"] = _array_or_empty(record.get("byproducts", []))
	record["byproduct_payloads"] = _dictionary_or_empty(record.get("byproduct_payloads", {}))
	_prune_retired_byproducts(record)
	record["slot_reduction"] = SLOT_REDUCTION_PER_RECORD
	return {"record": record}


func _migrate_restored_record(raw_record: Dictionary) -> Dictionary:
	var record: Dictionary = raw_record.duplicate(true)
	var raw_sources_value: Variant = record.get("sources", null)
	if raw_sources_value is Array:
		var migrated_sources: Array[String] = []
		for source_value: Variant in (raw_sources_value as Array):
			migrated_sources.append(_restored_source_id(str(source_value)))
		record["sources"] = migrated_sources
	for field_name: String in ["option_penalties", "commit_value_snapshots"]:
		record[field_name] = _migrate_restored_source_options(
			_dictionary_or_empty(record.get(field_name, {}))
		)
	record["deleted_options"] = _migrate_restored_deleted_options(
		_dictionary_or_empty(record.get("deleted_options", {}))
	)
	var payloads: Dictionary = _dictionary_or_empty(record.get("byproduct_payloads", {}))
	var limit_break: Dictionary = _dictionary_or_empty(payloads.get("limit_break", {}))
	if not limit_break.is_empty():
		var eligible_sources: Array = limit_break.get("eligible_sources", []) as Array
		var migrated_eligible: Array[String] = []
		for source_value: Variant in eligible_sources:
			var migrated_id := _restored_source_id(str(source_value))
			if migrated_id != "" and migrated_id not in migrated_eligible:
				migrated_eligible.append(migrated_id)
		limit_break["eligible_sources"] = migrated_eligible
		payloads["limit_break"] = limit_break
	record["byproduct_payloads"] = payloads
	return record


func _migrate_restored_source_options(source_options: Dictionary) -> Dictionary:
	var migrated: Dictionary = {}
	for source_value: Variant in source_options.keys():
		var raw_source_id := str(source_value)
		var source_id := _restored_source_id(raw_source_id)
		var raw_options: Dictionary = _dictionary_or_empty(source_options.get(source_value, {}))
		var options: Dictionary = _dictionary_or_empty(migrated.get(source_id, {}))
		for option_value: Variant in raw_options.keys():
			var raw_option_key := str(option_value)
			var option_key := _restored_option_key(raw_source_id, raw_option_key)
			options[option_key] = raw_options[option_value]
		migrated[source_id] = options
	return migrated


func _migrate_restored_deleted_options(deleted_options: Dictionary) -> Dictionary:
	var migrated: Dictionary = {}
	for source_value: Variant in deleted_options.keys():
		var raw_source_id := str(source_value)
		var source_id := _restored_source_id(raw_source_id)
		var raw_deleted: Variant = deleted_options[source_value]
		var option_keys: Array[String] = []
		if raw_deleted is Array:
			for option_value: Variant in raw_deleted:
				option_keys.append(_restored_option_key(raw_source_id, str(option_value)))
		elif raw_deleted is Dictionary:
			for option_value: Variant in (raw_deleted as Dictionary).keys():
				option_keys.append(_restored_option_key(raw_source_id, str(option_value)))
		elif str(raw_deleted) != "":
			option_keys.append(_restored_option_key(raw_source_id, str(raw_deleted)))
		var existing: Array = migrated.get(source_id, []) as Array
		for option_key: String in option_keys:
			if option_key != "" and option_key not in existing:
				existing.append(option_key)
		migrated[source_id] = existing
	return migrated


func _prune_retired_byproducts(record: Dictionary) -> void:
	var kept: Array = []
	for value: Variant in _array_or_empty(record.get("byproducts", [])):
		var byproduct_id := str((value as Dictionary).get("id", "")) if value is Dictionary else str(value)
		if byproduct_id.strip_edges() in RETIRED_BYPRODUCT_IDS:
			continue
		kept.append(value)
	record["byproducts"] = kept
	var payloads: Dictionary = _dictionary_or_empty(record.get("byproduct_payloads", {}))
	for retired_id: String in RETIRED_BYPRODUCT_IDS:
		payloads.erase(retired_id)
	record["byproduct_payloads"] = payloads


func _restored_source_id(source_id: String) -> String:
	var clean_id := source_id.strip_edges()
	return str(RESTORED_SOURCE_ALIASES.get(clean_id, clean_id))


func _restored_option_key(source_id: String, option_key: String) -> String:
	var aliases: Dictionary = RESTORED_OPTION_ALIASES.get(source_id.strip_edges(), {})
	var clean_key := option_key.strip_edges()
	return str(aliases.get(clean_key, clean_key))


func _normalize_sources(source_ids: Array) -> Array[String]:
	if source_ids.size() != RECORD_SOURCE_COUNT:
		return []
	var sources: Array[String] = []
	for source_value: Variant in source_ids:
		var source_id: String = str(source_value).strip_edges()
		if source_id.is_empty() or source_id in sources:
			return []
		sources.append(source_id)
	sources.sort()
	return sources


func _pair_key(sources: Array[String]) -> String:
	return "%s\u001f%s" % [sources[0], sources[1]]


func _has_pair(pair_key: String) -> bool:
	for record: Dictionary in _records:
		var sources: Array[String] = _normalize_sources(record.get("sources", []) as Array)
		if sources.size() == RECORD_SOURCE_COUNT and _pair_key(sources) == pair_key:
			return true
	return false


func _allocate_fusion_id() -> String:
	var fusion_id: String = "%s%d" % [FUSION_ID_PREFIX, _next_fusion_index]
	while _has_fusion_id(fusion_id):
		_next_fusion_index += 1
		fusion_id = "%s%d" % [FUSION_ID_PREFIX, _next_fusion_index]
	_next_fusion_index += 1
	return fusion_id


func _has_fusion_id(fusion_id: String) -> bool:
	for record: Dictionary in _records:
		if str(record.get("fusion_id", "")) == fusion_id:
			return true
	return false


func _fusion_index_from_id(fusion_id: String) -> int:
	if not fusion_id.begins_with(FUSION_ID_PREFIX):
		return -1
	var suffix: String = fusion_id.trim_prefix(FUSION_ID_PREFIX)
	if not suffix.is_valid_int():
		return -1
	return int(suffix)


func _get_base_level(runtime_levels: Dictionary, perk_id: String) -> int:
	if runtime_levels.has(perk_id):
		return int(runtime_levels.get(perk_id, 0))
	var perk_name: StringName = StringName(perk_id)
	return int(runtime_levels.get(perk_name, 0))


func _get_perk_data(runtime_catalog: Object, perk_id: String) -> Dictionary:
	if runtime_catalog == null or not runtime_catalog.has_method("get_perk_data"):
		return {}
	var value: Variant = runtime_catalog.call("get_perk_data", perk_id)
	if value is Dictionary:
		return value as Dictionary
	return {}


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _apply_token_transaction(record: Dictionary) -> void:
	var consumption: Dictionary = _dictionary_or_empty(record.get("token_consumption", {}))
	if bool(consumption.get("core_stabilize", false)):
		_next_fusion_core_stabilize = false
	if bool(consumption.get("dual_catalyst", false)):
		_next_fusion_dual_catalyst = false
	var byproducts: Array = _array_or_empty(record.get("byproducts", []))
	if "core_stabilize" in byproducts:
		_next_fusion_core_stabilize = true
	if "dual_catalyst" in byproducts:
		_next_fusion_dual_catalyst = true


func _is_option_deleted(record: Dictionary, perk_id: String, option_key: String) -> bool:
	var deleted_options: Dictionary = _dictionary_or_empty(record.get("deleted_options", {}))
	var source_deleted: Variant = _get_string_key_value(deleted_options, perk_id)
	if source_deleted is Array:
		return option_key in (source_deleted as Array)
	if source_deleted is Dictionary:
		var deleted_lookup: Dictionary = source_deleted as Dictionary
		return deleted_lookup.has(option_key) or deleted_lookup.has(StringName(option_key))
	if source_deleted is String or source_deleted is StringName:
		return str(source_deleted) == option_key
	return false


func _get_string_key_value(source: Dictionary, key: String) -> Variant:
	if source.has(key):
		return source.get(key)
	var named_key := StringName(key)
	if source.has(named_key):
		return source.get(named_key)
	return null
