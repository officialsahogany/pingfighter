extends RefCounted

const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)

const STATE_VERSION := "tower_taiji_elder_state_v1"
const OFFER_VERSION := "tower_taiji_elder_offer_v1"
const OFFER_GENERATION := 0
const ACTION_ACCEPT := "taiji_elder:accept"
const ACTION_DECLINE := "taiji_elder:decline"
const SOURCE_RNG_DOMAIN := "taiji_elder_source_designation_v1"
const TARGET_RNG_DOMAIN := "taiji_elder_mythic_target_v1"

const KEY_DIALOGUE_AGE := "tower_ascent.node_modal.taiji_elder.dialogue.age"
const KEY_DIALOGUE_HEIR := "tower_ascent.node_modal.taiji_elder.dialogue.heir"
const KEY_DIALOGUE_EYES := "tower_ascent.node_modal.taiji_elder.dialogue.eyes"
const KEY_DIALOGUE_TRUST := "tower_ascent.node_modal.taiji_elder.dialogue.trust"
const KEY_DIALOGUE_COST := "tower_ascent.node_modal.taiji_elder.dialogue.cost"
const KEY_DIALOGUE_REQUEST := "tower_ascent.node_modal.taiji_elder.dialogue.request"
const KEY_QUESTION := "tower_ascent.node_modal.taiji_elder.question"
const KEY_ACCEPT := "tower_ascent.node_modal.taiji_elder.accept"
const KEY_DECLINE := "tower_ascent.node_modal.taiji_elder.decline"
const KEY_RESULT_ACCEPT := "tower_ascent.node_modal.taiji_elder.result.accept"
const KEY_RESULT_DECLINE := "tower_ascent.node_modal.taiji_elder.result.decline"
const KEY_UNAVAILABLE_SOURCE := "tower_ascent.node_modal.taiji_elder.unavailable.source"
const KEY_UNAVAILABLE_TARGET := "tower_ascent.node_modal.taiji_elder.unavailable.target"

const EXCLUDED_SOURCE_FLAGS: Array[String] = [
	"is_instant",
	"is_gold_conversion",
	"is_physique_training",
	"is_mystic_dice",
	"is_perk_fusion",
	"is_lingpet_guardian_enhance",
]

var _generated_pairs: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _resolutions: Dictionary = {}
var _active_node_id := ""


func reset() -> void:
	_generated_pairs.clear()
	_history.clear()
	_resolutions.clear()
	_active_node_id = ""


func build_save_snapshot() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"active_node_id": _active_node_id,
		"generated_pairs": _dictionary_array(_generated_pairs),
		"history": _dictionary_array(_history),
		"resolutions": _resolutions.duplicate(true),
	}


func export_state() -> Dictionary:
	return build_save_snapshot()


func restore_save_snapshot(value: Variant) -> Dictionary:
	reset()
	if not (value is Dictionary):
		return _rejected("invalid_taiji_elder_snapshot")
	var snapshot := value as Dictionary
	# Legacy Tower snapshots predate the Taiji field and restore it as an empty
	# dictionary. Treat that as a valid no-state snapshot; malformed non-empty
	# payloads still fail closed on the version check below.
	if snapshot.is_empty():
		return {
			"accepted": true,
			"restored": true,
			"empty": true,
			"generated_pair_count": 0,
			"history_count": 0,
			"resolution_count": 0,
		}
	if str(snapshot.get("state_version", "")) != STATE_VERSION:
		return _rejected("unsupported_taiji_elder_snapshot")
	_active_node_id = str(snapshot.get("active_node_id", "")).strip_edges()
	for pair in _dictionary_array(snapshot.get("generated_pairs", [])):
		if _is_restorable_pair(pair):
			_generated_pairs.append(pair.duplicate(true))
	_history = _dictionary_array(snapshot.get("history", []))
	var resolutions_value: Variant = snapshot.get("resolutions", {})
	if resolutions_value is Dictionary:
		_resolutions = (resolutions_value as Dictionary).duplicate(true)
	return {
		"accepted": true,
		"restored": true,
		"generated_pair_count": _generated_pairs.size(),
		"history_count": _history.size(),
		"resolution_count": _resolutions.size(),
	}


func restore_state(value: Variant) -> void:
	restore_save_snapshot(value)


func get_generated_pairs() -> Array[Dictionary]:
	return _dictionary_array(_generated_pairs)


func get_history() -> Array[Dictionary]:
	return _dictionary_array(_history)


func get_resolutions() -> Dictionary:
	return _resolutions.duplicate(true)


func begin_visit(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		return _rejected("invalid_taiji_elder_node_id")
	_active_node_id = normalized_node_id
	var existing := _find_pair(normalized_node_id)
	if existing.is_empty():
		var generated := _generate_pair(
			normalized_node_id,
			map_seed,
			owner,
			registry,
			catalog
		)
		_generated_pairs.append(generated)
	var modal := get_modal_snapshot(normalized_node_id)
	modal["accepted"] = true
	modal["applied"] = existing.is_empty()
	modal["reason"] = (
		"taiji_elder_offer_generated"
		if existing.is_empty()
		else "taiji_elder_offer_restored"
	)
	return modal


func get_modal_snapshot(node_id: String = "") -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		normalized_node_id = _active_node_id
	var pair := _find_pair(normalized_node_id)
	if pair.is_empty():
		return {}
	var result := pair.duplicate(true)
	var record := _find_history_record(normalized_node_id)
	result["choice_committed"] = not record.is_empty()
	result["accepted_exchange"] = bool(record.get("accepted_exchange", false))
	result["node_resolution_id"] = str(record.get("node_resolution_id", ""))
	result["record"] = record.duplicate(true)
	result["result_reason"] = str(record.get("result_reason", ""))
	result["actions"] = build_actions(normalized_node_id)
	return result


func build_actions(node_id: String = "") -> Array[Dictionary]:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		normalized_node_id = _active_node_id
	var pair := _find_pair(normalized_node_id)
	if (
		pair.is_empty()
		or not bool(pair.get("available", false))
		or not _find_history_record(normalized_node_id).is_empty()
	):
		return []
	var ready := bool(pair.get("confirmation_ready", false))
	return [
		_build_action(ACTION_ACCEPT, KEY_ACCEPT, ready, pair),
		_build_action(ACTION_DECLINE, KEY_DECLINE, ready, pair),
	]


func mark_confirmation_ready(node_id: String) -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	var pair_index := _find_pair_index(normalized_node_id)
	if pair_index < 0:
		return _rejected("taiji_elder_offer_missing")
	if not _find_history_record(normalized_node_id).is_empty():
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"choice_committed": true,
		}
	var pair := _generated_pairs[pair_index].duplicate(true)
	if not bool(pair.get("available", false)):
		return _rejected(str(pair.get("unavailable_reason", "taiji_elder_offer_unavailable")))
	if bool(pair.get("confirmation_ready", false)):
		return {
			"accepted": true,
			"applied": false,
			"reason": "taiji_confirmation_already_ready",
		}
	pair["confirmation_ready"] = true
	_generated_pairs[pair_index] = pair
	return {
		"accepted": true,
		"applied": true,
		"reason": "taiji_confirmation_ready",
	}


func resolve_exchange(
	accept: bool,
	resolution_id: String,
	node_id: String,
	resolution_ids: Dictionary,
	owner: Object,
	registry: Object,
	catalog: Object = null,
	transaction_hooks: Dictionary = {}
) -> Dictionary:
	var normalized_resolution_id := resolution_id.strip_edges()
	var normalized_node_id := node_id.strip_edges()
	if normalized_resolution_id.is_empty():
		return _rejected("invalid_resolution_id")
	if normalized_node_id.is_empty():
		return _rejected("invalid_taiji_elder_node_id")
	var committed := _find_history_record(normalized_node_id)
	if _resolutions.has(normalized_resolution_id) or resolution_ids.has(
		normalized_resolution_id
	) or not committed.is_empty():
		var duplicate_record: Dictionary = (
			committed
			if not committed.is_empty()
			else _dictionary(_resolutions.get(normalized_resolution_id, {}))
		)
		return _duplicate_result(normalized_resolution_id, duplicate_record)
	var pair := _find_pair(normalized_node_id)
	if pair.is_empty():
		return _rejected("taiji_elder_offer_missing")
	var available := bool(pair.get("available", false))
	if not available:
		if accept:
			return _rejected(str(pair.get("unavailable_reason", "taiji_elder_offer_unavailable")))
		return _commit_resolution(
			false,
			normalized_resolution_id,
			normalized_node_id,
			resolution_ids,
			pair,
			"taiji_exchange_unavailable_resolved",
			true,
			{}
		)
	if not bool(pair.get("confirmation_ready", false)):
		return _rejected("taiji_confirmation_not_ready")
	if not accept:
		return _commit_resolution(
			false,
			normalized_resolution_id,
			normalized_node_id,
			resolution_ids,
			pair,
			"taiji_exchange_declined",
			false,
			{}
		)

	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var resolved_catalog := _resolve_catalog(catalog, registry)
	if runtime_state == null or not runtime_state.has_method("apply_taiji_elder_exchange"):
		return _rejected("taiji_exchange_runtime_unavailable")
	var source_id := str(pair.get("source_id", ""))
	var target_id := str(pair.get("target_id", ""))
	var live_sources := build_visible_source_candidate_ids(
		owner,
		registry,
		resolved_catalog
	)
	if source_id not in live_sources:
		return _rejected("taiji_exchange_source_stale")
	var live_targets := _build_target_candidate_ids(
		runtime_state,
		owner,
		registry,
		resolved_catalog
	)
	if target_id not in live_targets:
		return _rejected("taiji_exchange_target_stale")
	var exchange_value: Variant = runtime_state.call(
		"apply_taiji_elder_exchange",
		source_id,
		target_id,
		owner,
		registry,
		resolved_catalog,
		transaction_hooks
	)
	if not (exchange_value is Dictionary):
		return _rejected("taiji_exchange_transaction_invalid")
	var exchange := (exchange_value as Dictionary).duplicate(true)
	if not bool(exchange.get("accepted", false)) or not bool(
		exchange.get("applied", false)
	):
		var reason := str(exchange.get(
			"blocked_reason",
			exchange.get("reason", "taiji_exchange_transaction_rejected")
		))
		var rejected := exchange.duplicate(true)
		rejected["accepted"] = false
		rejected["applied"] = false
		rejected["reason"] = reason
		rejected["choice_committed"] = false
		rejected["accepted_exchange"] = false
		return rejected
	return _commit_resolution(
		true,
		normalized_resolution_id,
		normalized_node_id,
		resolution_ids,
		pair,
		"taiji_exchange_committed",
		false,
		exchange
	)


func build_visible_source_candidate_ids(
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Array[String]:
	var result: Array[String] = []
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var resolved_catalog := _resolve_catalog(catalog, registry)
	if (
		runtime_state == null
		or resolved_catalog == null
		or not runtime_state.has_method("get_perk_fusion_display_projection")
	):
		return result
	var levels := _runtime_levels(runtime_state)
	var projection_value: Variant = runtime_state.call(
		"get_perk_fusion_display_projection",
		resolved_catalog
	)
	if not (projection_value is Dictionary):
		return result
	var projection := projection_value as Dictionary
	var entries_value: Variant = projection.get("entries", [])
	if not (entries_value is Array):
		return result
	var character_type := _selected_character_type(owner)
	for entry_value: Variant in entries_value as Array:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		if str(entry.get("type", "")) != "perk":
			continue
		var source_id := str(
			entry.get("perk_id", entry.get("id", ""))
		).strip_edges()
		var source_level := _raw_level(levels, source_id)
		if source_id.is_empty() or source_level <= 0:
			continue
		var source_data := _catalog_perk_data(resolved_catalog, source_id)
		if source_data.is_empty():
			continue
		source_data["id"] = source_id
		if not _is_visible_ordinary_source(
			source_id,
			source_level,
			source_data,
			character_type
		):
			continue
		result.append(source_id)
	result.sort()
	return result


func _generate_pair(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object,
	catalog: Object
) -> Dictionary:
	var resolved_catalog := _resolve_catalog(catalog, registry)
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var source_ids := build_visible_source_candidate_ids(
		owner,
		registry,
		resolved_catalog
	)
	var target_ids := _build_target_candidate_ids(
		runtime_state,
		owner,
		registry,
		resolved_catalog
	)
	var base := {
		"offer_version": OFFER_VERSION,
		"offer_generation": OFFER_GENERATION,
		"generation": OFFER_GENERATION,
		"node_id": node_id,
		"map_seed": map_seed,
		"source_rng_domain": SOURCE_RNG_DOMAIN,
		"target_rng_domain": TARGET_RNG_DOMAIN,
		"eligible_source_ids": source_ids.duplicate(),
		"eligible_target_ids": target_ids.duplicate(),
		"source_id": "",
		"target_id": "",
		"source_card": {},
		"target_card": {},
		"dialogue_lines": [],
		"question": TowerAscentNodeModalLocalization.text(KEY_QUESTION),
		"confirmation_ready": false,
		"available": false,
		"auto_resolve": true,
		"unavailable_reason": "",
		"unavailable_message": "",
	}
	if source_ids.is_empty():
		base["unavailable_reason"] = "taiji_exchange_source_pool_empty"
		base["unavailable_message"] = TowerAscentNodeModalLocalization.text(
			KEY_UNAVAILABLE_SOURCE
		)
		return base
	if target_ids.is_empty():
		base["unavailable_reason"] = "taiji_exchange_target_pool_empty"
		base["unavailable_message"] = TowerAscentNodeModalLocalization.text(
			KEY_UNAVAILABLE_TARGET
		)
		return base
	var source_id := _pick_candidate(
		source_ids,
		_seed_for_domain(map_seed, node_id, SOURCE_RNG_DOMAIN)
	)
	var target_id := _pick_candidate(
		target_ids,
		_seed_for_domain(map_seed, node_id, TARGET_RNG_DOMAIN)
	)
	var levels := _runtime_levels(runtime_state)
	var source_card := _catalog_perk_data(resolved_catalog, source_id)
	source_card["id"] = source_id
	source_card["current_level"] = _raw_level(levels, source_id)
	source_card["next_level"] = _raw_level(levels, source_id)
	var target_card := _catalog_perk_data(resolved_catalog, target_id)
	target_card["id"] = target_id
	target_card["current_level"] = 0
	target_card["next_level"] = 1
	base["source_id"] = source_id
	base["target_id"] = target_id
	base["source_card"] = source_card
	base["target_card"] = target_card
	base["dialogue_lines"] = _build_dialogue_lines(
		str(source_card.get("name", source_id))
	)
	base["available"] = true
	base["auto_resolve"] = false
	base["offer_signature"] = hash([
		OFFER_VERSION,
		OFFER_GENERATION,
		map_seed,
		node_id,
		source_id,
		target_id,
	])
	return base


func _build_target_candidate_ids(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	catalog: Object
) -> Array[String]:
	if (
		runtime_state == null
		or not runtime_state.has_method("build_taiji_elder_mythic_target_ids")
	):
		return []
	var value: Variant = runtime_state.call(
		"build_taiji_elder_mythic_target_ids",
		owner,
		registry,
		catalog
	)
	var result: Array[String] = []
	if value is Array:
		for target_value: Variant in value as Array:
			var target_id := str(target_value).strip_edges()
			if not target_id.is_empty() and target_id not in result:
				result.append(target_id)
	result.sort()
	return result


func _is_visible_ordinary_source(
	source_id: String,
	source_level: int,
	source_data: Dictionary,
	character_type: String
) -> bool:
	if source_data.is_empty() or source_level <= 0:
		return false
	if (
		RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(source_id)
		or RuntimePerkCatalog.ACQUISITION_ONLY_PERKS.has(source_id)
		or str(source_data.get("rarity", "")).strip_edges().to_lower() == "mythic"
		or str(source_data.get("tree", "")).strip_edges().to_lower() == "mythic"
	):
		return false
	if (
		RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(source_id)
		or source_id == RuntimePerkCatalog.SLOT_EXPANSION_PERK_ID
		or source_id.begins_with("physique_")
		or source_id in ["convert_to_gold", "mystic_dice"]
		or bool(RuntimePerkCatalog.LINGPET_GATED_CHOICE_IDS.get(source_id, false))
	):
		return false
	if not str(source_data.get("unlocks_skill", "")).strip_edges().is_empty():
		return false
	for excluded_flag: String in EXCLUDED_SOURCE_FLAGS:
		if bool(source_data.get(excluded_flag, false)):
			return false
	var restriction := str(
		source_data.get("character_restriction", "")
	).strip_edges().to_lower()
	if not restriction.is_empty() and restriction != character_type:
		return false
	if not RuntimePerkCatalog.is_slot_consuming_perk(source_data):
		return false
	return RuntimePerkCatalog.get_slot_cost_for_level(
		source_data,
		source_level
	) > 0


func _commit_resolution(
	accepted_exchange: bool,
	resolution_id: String,
	node_id: String,
	resolution_ids: Dictionary,
	pair: Dictionary,
	result_reason: String,
	auto_resolved: bool,
	exchange_receipt: Dictionary
) -> Dictionary:
	var action_id := ACTION_ACCEPT if accepted_exchange else ACTION_DECLINE
	var record := {
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"action_id": action_id,
		"accepted_exchange": accepted_exchange,
		"choice_committed": true,
		"source_id": str(pair.get("source_id", "")),
		"target_id": str(pair.get("target_id", "")),
		"source_card": _dictionary(pair.get("source_card", {})),
		"target_card": _dictionary(pair.get("target_card", {})),
		"offer_version": str(pair.get("offer_version", OFFER_VERSION)),
		"offer_generation": int(pair.get("offer_generation", OFFER_GENERATION)),
		"result_reason": result_reason,
		"auto_resolved": auto_resolved,
		"exchange_receipt": exchange_receipt.duplicate(true),
	}
	resolution_ids[resolution_id] = true
	_resolutions[resolution_id] = record.duplicate(true)
	_history.append(record.duplicate(true))
	var pair_index := _find_pair_index(node_id)
	if pair_index >= 0:
		var committed_pair := _generated_pairs[pair_index].duplicate(true)
		committed_pair["confirmation_ready"] = false
		committed_pair["resolved"] = true
		_generated_pairs[pair_index] = committed_pair
	var message := TowerAscentNodeModalLocalization.text(
		KEY_RESULT_ACCEPT if accepted_exchange else KEY_RESULT_DECLINE
	)
	return {
		"accepted": true,
		"applied": true,
		"reason": result_reason,
		"choice_committed": true,
		"accepted_exchange": accepted_exchange,
		"node_resolution_id": resolution_id,
		"source_card": _dictionary(pair.get("source_card", {})),
		"target_card": _dictionary(pair.get("target_card", {})),
		"record": record.duplicate(true),
		"message": message,
		"presentation_lines": [message],
	}


func _duplicate_result(resolution_id: String, record: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"applied": false,
		"reason": "already_committed",
		"choice_committed": not record.is_empty(),
		"accepted_exchange": bool(record.get("accepted_exchange", false)),
		"node_resolution_id": str(record.get("node_resolution_id", resolution_id)),
		"source_card": _dictionary(record.get("source_card", {})),
		"target_card": _dictionary(record.get("target_card", {})),
		"record": record.duplicate(true),
	}


func _build_action(
	action_id: String,
	label_key: String,
	enabled: bool,
	pair: Dictionary
) -> Dictionary:
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(label_key),
		"label_key": label_key,
		"enabled": enabled,
		"disabled_reason": "" if enabled else "taiji_confirmation_not_ready",
		"payload": {
			"operation": action_id.trim_prefix("taiji_elder:"),
			"presentation_mode": "taiji_elder_exchange",
			"force_choice": true,
			"source_card": _dictionary(pair.get("source_card", {})),
			"target_card": _dictionary(pair.get("target_card", {})),
		},
	}


func _build_dialogue_lines(source_name: String) -> Array[String]:
	var request := TowerAscentNodeModalLocalization.text(KEY_DIALOGUE_REQUEST)
	request = request.replace("~", source_name)
	return [
		TowerAscentNodeModalLocalization.text(KEY_DIALOGUE_AGE),
		TowerAscentNodeModalLocalization.text(KEY_DIALOGUE_HEIR),
		TowerAscentNodeModalLocalization.text(KEY_DIALOGUE_EYES),
		TowerAscentNodeModalLocalization.text(KEY_DIALOGUE_TRUST),
		TowerAscentNodeModalLocalization.text(KEY_DIALOGUE_COST),
		request,
	]


func _pick_candidate(candidates: Array[String], seed_value: int) -> String:
	if candidates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _seed_for_domain(map_seed: int, node_id: String, domain: String) -> int:
	return absi(hash("%d:%s:%s:%d:%s" % [
		map_seed,
		node_id,
		OFFER_VERSION,
		OFFER_GENERATION,
		domain,
	]))


func _find_pair(node_id: String) -> Dictionary:
	var index := _find_pair_index(node_id)
	return _generated_pairs[index].duplicate(true) if index >= 0 else {}


func _find_pair_index(node_id: String) -> int:
	for index in range(_generated_pairs.size()):
		if str(_generated_pairs[index].get("node_id", "")) == node_id:
			return index
	return -1


func _find_history_record(node_id: String) -> Dictionary:
	for record in _history:
		if str(record.get("node_id", "")) == node_id:
			return record.duplicate(true)
	return {}


func _is_restorable_pair(pair: Dictionary) -> bool:
	return (
		not str(pair.get("node_id", "")).strip_edges().is_empty()
		and str(pair.get("offer_version", "")) == OFFER_VERSION
		and int(pair.get("offer_generation", -1)) == OFFER_GENERATION
	)


func _resolve_catalog(catalog: Object, registry: Object) -> Object:
	if catalog != null and catalog.has_method("get_perk_data"):
		return catalog
	var registered := _get_registry_instance(registry, "runtime_perk_catalog")
	return registered if registered != null else RuntimePerkCatalog.new()


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name: String in ["get_cached_instance", "get_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null


func _catalog_perk_data(catalog: Object, perk_id: String) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_data"):
		return {}
	var value: Variant = catalog.call("get_perk_data", perk_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _runtime_levels(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get("runtime_skill_levels")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _raw_level(levels: Dictionary, perk_id: String) -> int:
	return maxi(
		maxi(0, int(levels.get(perk_id, 0))),
		maxi(0, int(levels.get(StringName(perk_id), 0)))
	)


func _selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	var result := str(value).strip_edges().to_lower() if value != null else ""
	return result if not result.is_empty() else "smasher"


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for child: Variant in value as Array:
			if child is Dictionary:
				result.append((child as Dictionary).duplicate(true))
	return result


func _rejected(reason: String) -> Dictionary:
	return {
		"accepted": false,
		"applied": false,
		"restored": false,
		"reason": reason,
		"blocked_reason": reason,
		"choice_committed": false,
		"accepted_exchange": false,
	}
