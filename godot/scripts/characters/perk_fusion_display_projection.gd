extends RefCounted

const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")

# Canonical, read-only display projection for runtime perk fusion.
#
# Consumers must render this projection instead of folding raw runtime levels
# independently. Invalid or conflicting records fail closed: their source
# perks remain ordinary visible entries.


func build(
	runtime_levels: Dictionary,
	fusion_snapshot: Dictionary,
	catalog: Object,
	effective_levels: Dictionary = {},
	live_source_options: Dictionary = {}
) -> Dictionary:
	var normalized_levels: Dictionary = _normalize_positive_levels(runtime_levels)
	var normalized_effective_levels: Dictionary = _normalize_effective_levels(
		effective_levels,
		normalized_levels
	)
	var fusion_revision: int = _snapshot_revision(fusion_snapshot)
	var candidates: Array[Dictionary] = []
	for raw_record: Variant in _snapshot_records(fusion_snapshot):
		var candidate: Dictionary = _build_record_candidate(
			raw_record,
			normalized_levels,
			normalized_effective_levels,
			catalog
		)
		if not candidate.is_empty():
			candidates.append(candidate)
	candidates.sort_custom(_candidate_less)

	# Reject every side of an ambiguous conflict. Picking whichever record was
	# encountered first would make record ordering affect which perks disappear.
	var fusion_id_counts: Dictionary = {}
	var source_counts: Dictionary = {}
	for candidate: Dictionary in candidates:
		var fusion_id: String = str(candidate.get("fusion_id", ""))
		fusion_id_counts[fusion_id] = int(fusion_id_counts.get(fusion_id, 0)) + 1
		for source_value: Variant in candidate.get("sources", []):
			var source_id: String = str(source_value)
			source_counts[source_id] = int(source_counts.get(source_id, 0)) + 1

	var consumed_sources: Dictionary = {}
	var fusion_entries: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var fusion_id: String = str(candidate.get("fusion_id", ""))
		if int(fusion_id_counts.get(fusion_id, 0)) != 1:
			continue
		var sources: Array = candidate.get("sources", []) as Array
		var has_source_conflict := false
		for source_value: Variant in sources:
			if int(source_counts.get(str(source_value), 0)) != 1:
				has_source_conflict = true
				break
		if has_source_conflict:
			continue
		for source_value: Variant in sources:
			consumed_sources[str(source_value)] = true
		var fusion_entry := _build_fusion_entry(candidate, live_source_options)
		fusion_entry["fusion_revision"] = fusion_revision
		fusion_entries.append(fusion_entry)

	var entries: Array[Dictionary] = []
	var owned_ids: Array[String] = []
	for perk_id_value: Variant in normalized_levels.keys():
		owned_ids.append(str(perk_id_value))
	owned_ids.sort()
	for perk_id: String in owned_ids:
		if consumed_sources.has(perk_id):
			continue
		entries.append(
			_build_ordinary_entry(
				perk_id,
				int(normalized_levels.get(perk_id, 0)),
				int(normalized_effective_levels.get(perk_id, normalized_levels.get(perk_id, 0))),
				catalog
			)
		)
	entries.append_array(fusion_entries)
	entries.sort_custom(_entry_less)

	var signature_payload := {
		"fusion_revision": fusion_revision,
		"entries": entries.duplicate(true),
	}
	return {
		"entries": entries.duplicate(true),
		"fusion_revision": fusion_revision,
		"cache_signature": hash(_stable_serialize(signature_payload)),
	}


func diff(before_projection: Dictionary, after_projection: Dictionary) -> Array:
	var before_by_id: Dictionary = {}
	for entry_value: Variant in _projection_entries(before_projection):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("type", "")) != "fusion":
			continue
		var fusion_id: String = str(entry.get("fusion_id", "")).strip_edges()
		if not fusion_id.is_empty():
			before_by_id[fusion_id] = entry.duplicate(true)

	var changed: Array[Dictionary] = []
	for entry_value: Variant in _projection_entries(after_projection):
		if not entry_value is Dictionary:
			continue
		var after_entry: Dictionary = entry_value as Dictionary
		if str(after_entry.get("type", "")) != "fusion":
			continue
		var fusion_id: String = str(after_entry.get("fusion_id", "")).strip_edges()
		if fusion_id.is_empty():
			continue
		var before_entry: Dictionary = before_by_id.get(fusion_id, {}) as Dictionary
		if not before_entry.is_empty() and _stable_serialize(
			_record_payload_for_diff(before_entry)
		) == _stable_serialize(_record_payload_for_diff(after_entry)):
			continue
		var change: Dictionary = after_entry.duplicate(true)
		change["type"] = "fusion"
		change["fusion_id"] = fusion_id
		change["change"] = "added" if before_entry.is_empty() else "changed"
		change["fusion_revision"] = int(after_projection.get("fusion_revision", 0))
		if not before_entry.is_empty():
			change["before"] = before_entry.duplicate(true)
		changed.append(change)
	changed.sort_custom(_fusion_diff_less)
	return changed.duplicate(true)


func _record_payload_for_diff(entry: Dictionary) -> Dictionary:
	var payload: Dictionary = _dictionary_or_empty(entry.get("record_payload", {}))
	if not payload.is_empty():
		return payload
	# Compatibility for projections produced before record_payload was added.
	return {
		"fusion_id": str(entry.get("fusion_id", entry.get("id", ""))),
		"sources": _array_or_empty(entry.get("sources", [])),
		"outcome": str(entry.get("outcome", "success")),
		"option_penalties": _dictionary_or_empty(entry.get("option_penalties", {})),
		"deleted_options": _dictionary_or_empty(entry.get("deleted_options", {})),
		"commit_value_snapshots": _dictionary_or_empty(entry.get("commit_value_snapshots", {})),
		"byproducts": _array_or_empty(entry.get("byproducts", [])),
		"byproduct_payloads": _dictionary_or_empty(entry.get("byproduct_payloads", {})),
	}


func _build_record_candidate(
	raw_record: Variant,
	normalized_levels: Dictionary,
	normalized_effective_levels: Dictionary,
	catalog: Object
) -> Dictionary:
	if not raw_record is Dictionary:
		return {}
	var record: Dictionary = (raw_record as Dictionary).duplicate(true)
	var fusion_id: String = str(record.get("fusion_id", "")).strip_edges()
	var raw_sources_value: Variant = record.get("sources", null)
	if fusion_id.is_empty() or not raw_sources_value is Array:
		return {}
	var raw_sources: Array = raw_sources_value as Array
	if raw_sources.size() != 2:
		return {}
	var sources: Array[String] = []
	for source_value: Variant in raw_sources:
		var source_id: String = str(source_value).strip_edges()
		if source_id.is_empty():
			return {}
		sources.append(source_id)
	sources.sort()
	if sources[0] == sources[1]:
		return {}

	var source_names: Array[String] = []
	var base_levels: Dictionary = {}
	var projected_effective_levels: Dictionary = {}
	for source_id: String in sources:
		var base_level: int = int(normalized_levels.get(source_id, 0))
		var perk_data: Dictionary = _get_perk_data(catalog, source_id)
		if base_level <= 0 or perk_data.is_empty():
			return {}
		var max_level: int = int(perk_data.get("max_level", 0))
		if max_level <= 0 or base_level != max_level:
			return {}
		if _get_slot_cost(catalog, perk_data, base_level) != 1:
			return {}
		source_names.append(str(perk_data.get("name", source_id)))
		base_levels[source_id] = base_level
		projected_effective_levels[source_id] = int(
			normalized_effective_levels.get(source_id, base_level)
		)

	record["fusion_id"] = fusion_id
	record["sources"] = sources.duplicate()
	return {
		"fusion_id": fusion_id,
		"sources": sources.duplicate(),
		"source_names": source_names.duplicate(),
		"base_levels": base_levels.duplicate(true),
		"effective_levels": projected_effective_levels.duplicate(true),
		"record": record.duplicate(true),
	}


func _build_fusion_entry(candidate: Dictionary, live_source_options: Dictionary = {}) -> Dictionary:
	var record: Dictionary = (candidate.get("record", {}) as Dictionary).duplicate(true)
	var source_names: Array = candidate.get("source_names", []) as Array
	var outcome: String = str(record.get("outcome", "success"))
	var byproducts: Array = _array_or_empty(record.get("byproducts", []))
	return {
		"type": "fusion",
		"id": str(candidate.get("fusion_id", "")),
		"fusion_id": str(candidate.get("fusion_id", "")),
		"sources": (candidate.get("sources", []) as Array).duplicate(true),
		"source_names": source_names.duplicate(true),
		"base_levels": (candidate.get("base_levels", {}) as Dictionary).duplicate(true),
		"effective_levels": (candidate.get("effective_levels", {}) as Dictionary).duplicate(true),
		"slot_cost": 1,
		"outcome": outcome,
		"option_penalties": _dictionary_or_empty(record.get("option_penalties", {})),
		"deleted_options": _dictionary_or_empty(record.get("deleted_options", {})),
		"commit_value_snapshots": _dictionary_or_empty(record.get("commit_value_snapshots", {})),
		"live_source_options": _source_option_subset(
			live_source_options,
			candidate.get("sources", []) as Array
		),
		"byproducts": byproducts.duplicate(true),
		"byproduct_payloads": _dictionary_or_empty(record.get("byproduct_payloads", {})),
		"summary": _build_summary(source_names, outcome, byproducts.size()),
		# Preserve the complete normalized record so future display-affecting
		# fields participate in cache invalidation and before/after diffing.
		"record_payload": record.duplicate(true),
	}


func _source_option_subset(live_source_options: Dictionary, sources: Array) -> Dictionary:
	var result: Dictionary = {}
	for source_value: Variant in sources:
		var source_id := str(source_value)
		var options := _dictionary_or_empty(live_source_options.get(source_id, {}))
		if not options.is_empty():
			result[source_id] = options.duplicate(true)
	return result


func _build_ordinary_entry(
	perk_id: String,
	base_level: int,
	effective_level: int,
	catalog: Object
) -> Dictionary:
	var perk_data: Dictionary = _get_perk_data(catalog, perk_id)
	return {
		"type": "perk",
		"id": perk_id,
		"perk_id": perk_id,
		"name": str(perk_data.get("name", perk_id)),
		"base_level": base_level,
		"effective_level": effective_level,
		"slot_cost": _get_slot_cost(catalog, perk_data, base_level) if not perk_data.is_empty() else 1,
	}


func _build_summary(source_names: Array, outcome: String, byproduct_count: int) -> String:
	var outcome_label: String
	match outcome:
		"stable":
			outcome_label = PerkFusionLocalization.text("label_stable")
		"side_effect":
			outcome_label = PerkFusionLocalization.text("label_side")
		"byproduct":
			outcome_label = PerkFusionLocalization.text("label_byproduct")
		_:
			outcome_label = PerkFusionLocalization.text("label_success")
	var summary := PerkFusionLocalization.format("summary", [str(source_names[0]), str(source_names[1]), outcome_label])
	if byproduct_count > 0:
		summary += PerkFusionLocalization.format("summary_byproducts", [byproduct_count])
	return summary


func _normalize_positive_levels(levels: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for perk_id_value: Variant in levels.keys():
		var perk_id: String = str(perk_id_value).strip_edges()
		var level: int = int(levels.get(perk_id_value, 0))
		if not perk_id.is_empty() and level > 0:
			normalized[perk_id] = level
	return normalized


func _normalize_effective_levels(effective_levels: Dictionary, base_levels: Dictionary) -> Dictionary:
	var normalized: Dictionary = base_levels.duplicate(true)
	for perk_id_value: Variant in effective_levels.keys():
		var perk_id: String = str(perk_id_value).strip_edges()
		if not perk_id.is_empty():
			normalized[perk_id] = int(effective_levels.get(perk_id_value, 0))
	return normalized


func _snapshot_records(snapshot: Dictionary) -> Array:
	var records_value: Variant = snapshot.get("records", [])
	return _array_or_empty(records_value)


func _snapshot_revision(snapshot: Dictionary) -> int:
	return int(snapshot.get("fusion_revision", 0))


func _projection_entries(projection: Dictionary) -> Array:
	return _array_or_empty(projection.get("entries", []))


func _get_perk_data(catalog: Object, perk_id: String) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_data"):
		return {}
	var value: Variant = catalog.call("get_perk_data", perk_id)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_slot_cost(catalog: Object, perk_data: Dictionary, level: int) -> int:
	if catalog != null and catalog.has_method("get_slot_cost_for_level"):
		return int(catalog.call("get_slot_cost_for_level", perk_data.duplicate(true), level))
	return 1 if level > 0 else 0


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_id: String = str(a.get("fusion_id", ""))
	var b_id: String = str(b.get("fusion_id", ""))
	if a_id != b_id:
		return a_id < b_id
	return _stable_serialize(a.get("record", {})) < _stable_serialize(b.get("record", {}))


func _entry_less(a: Dictionary, b: Dictionary) -> bool:
	var a_key: String = _entry_sort_key(a)
	var b_key: String = _entry_sort_key(b)
	if a_key != b_key:
		return a_key < b_key
	var a_type: String = str(a.get("type", ""))
	var b_type: String = str(b.get("type", ""))
	if a_type != b_type:
		return a_type < b_type
	return str(a.get("id", "")) < str(b.get("id", ""))


func _entry_sort_key(entry: Dictionary) -> String:
	if str(entry.get("type", "")) == "fusion":
		var sources: Array = entry.get("sources", []) as Array
		if not sources.is_empty():
			return str(sources[0])
	return str(entry.get("id", ""))


func _fusion_diff_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("fusion_id", "")) < str(b.get("fusion_id", ""))


func _stable_serialize(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "bool:%s" % ("1" if bool(value) else "0")
		TYPE_INT:
			return "int:%d" % int(value)
		TYPE_FLOAT:
			return "float:%s" % str(float(value))
		TYPE_STRING, TYPE_STRING_NAME:
			return "string:%s" % JSON.stringify(str(value))
		TYPE_ARRAY:
			var array_parts: Array[String] = []
			for item: Variant in value as Array:
				array_parts.append(_stable_serialize(item))
			return "array:[%s]" % ",".join(array_parts)
		TYPE_DICTIONARY:
			var dictionary_parts: Array[String] = []
			var dictionary: Dictionary = value as Dictionary
			for key: Variant in dictionary.keys():
				dictionary_parts.append(
					"%s=%s" % [_stable_serialize(key), _stable_serialize(dictionary.get(key))]
				)
			dictionary_parts.sort()
			return "dictionary:{%s}" % ",".join(dictionary_parts)
		_:
			return "variant:%s" % str(value)
