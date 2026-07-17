extends RefCounted

const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const POLARITY_FORWARD := "forward"
const POLARITY_REVERSE := "reverse"
const VALUE_KIND_FLOAT := "float"
const VALUE_KIND_INT := "int"
const CENTRAL_VALUE_KEY := "runtime_skill_bonus"
const CENTRAL_INTEGER_PERK_IDS := {
	"item_bag_expansion": true,
	"perk_laurel_shield": true,
}

# Quantized gameplay lanes must not be reduced through float multiplication.
# This list is intentionally semantic rather than inferred from current values:
# several integer lanes happen to contain .0 floats in their authored tables.
const INTEGER_VALUE_KEYS := {
	"auto_dash_token_count": true,
	"shard_count": true,
	"knockback_level": true,
	"leaf_count": true,
	"skill_slot_bonus": true,
	"perk_level_bonus": true,
	"skill_bonus": true,
}

var _fusion_catalog := PerkFusionCatalog.new()
static var _forward_value_key_registry: Dictionary = {}


func build(source_ids: Array, runtime_state: Object, catalog: Object) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	if runtime_state == null or catalog == null:
		return lanes

	var forward_value_keys: Dictionary = _get_forward_value_key_registry()
	for perk_id: String in _normalize_source_ids(source_ids):
		var classification: Dictionary = _fusion_catalog.classify_perk(perk_id, catalog)
		if not bool(classification.get("penalty_hookable", false)):
			continue

		var source_lanes: Array[Dictionary] = _build_converted_lanes(
			perk_id,
			runtime_state,
			forward_value_keys
		)
		if source_lanes.is_empty():
			source_lanes = _build_central_bonus_lane(perk_id, runtime_state)
		var remaining_option_count: int = source_lanes.size()
		for lane: Dictionary in source_lanes:
			lane["remaining_option_count"] = remaining_option_count
			lanes.append(lane)

	return lanes


func _build_converted_lanes(
	perk_id: String,
	runtime_state: Object,
	forward_value_keys: Dictionary
) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	var value_keys: Array = PerkConversionValues.get_value_keys(perk_id)
	if value_keys.is_empty() or not runtime_state.has_method("get_converted_perk_effect_level"):
		return lanes

	var effect_level: int = int(runtime_state.call("get_converted_perk_effect_level", perk_id))
	if effect_level <= 0:
		return lanes
	for key_value: Variant in value_keys:
		var key: String = str(key_value).strip_edges()
		if key.is_empty():
			continue
		var is_boolean: bool = _is_single_entry_boolean_table(perk_id, key)
		if is_boolean:
			continue
		var polarity: String = _resolve_polarity(perk_id, key, forward_value_keys)
		if polarity.is_empty():
			continue
		var value_kind: String = _resolve_value_kind(key)
		if value_kind.is_empty():
			continue
		# Deliberately use the raw three-argument helper. The source is not fused
		# yet, so a resolver-aware read here would feed an overlay back into its
		# own commit snapshot.
		var raw_value: float = PerkConversionValues.get_value(perk_id, key, effect_level)
		if not is_finite(raw_value) or raw_value <= 0.0:
			continue
		var lane_value: Variant = raw_value
		if value_kind == VALUE_KIND_INT:
			lane_value = int(round(raw_value))
			if int(lane_value) <= 0:
				continue
		lanes.append(_make_lane(perk_id, key, lane_value, polarity, value_kind, false))
	return lanes


func _build_central_bonus_lane(perk_id: String, runtime_state: Object) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	if not runtime_state.has_method("get_runtime_skill_bonus"):
		return lanes
	var value: float
	if runtime_state.has_method("get_runtime_skill_bonus_before_fusion"):
		value = float(runtime_state.call("get_runtime_skill_bonus_before_fusion", perk_id))
	else:
		value = float(runtime_state.call("get_runtime_skill_bonus", perk_id))
	if not is_finite(value) or value <= 0.0:
		return lanes
	var value_kind := VALUE_KIND_INT if bool(CENTRAL_INTEGER_PERK_IDS.get(perk_id, false)) else VALUE_KIND_FLOAT
	var lane_value: Variant = int(round(value)) if value_kind == VALUE_KIND_INT else value
	lanes.append(_make_lane(
		perk_id,
		CENTRAL_VALUE_KEY,
		lane_value,
		POLARITY_FORWARD,
		value_kind,
		false
	))
	return lanes


func _make_lane(
	perk_id: String,
	key: String,
	value: Variant,
	polarity: String,
	value_kind: String,
	is_boolean: bool
) -> Dictionary:
	return {
		"perk_id": perk_id,
		"key": key,
		"value": value,
		"polarity": polarity,
		"value_kind": value_kind,
		"is_boolean": is_boolean,
		"remaining_option_count": 0,
	}


func _resolve_polarity(
	perk_id: String,
	key: String,
	forward_value_keys: Dictionary
) -> String:
	if PerkConversionValues.is_lower_value_better(perk_id, key):
		return POLARITY_REVERSE
	if bool(forward_value_keys.get(key, false)):
		return POLARITY_FORWARD
	return ""


func _resolve_value_kind(key: String) -> String:
	if bool(INTEGER_VALUE_KEYS.get(key, false)):
		return VALUE_KIND_INT
	return VALUE_KIND_FLOAT


static func _get_forward_value_key_registry() -> Dictionary:
	if _forward_value_key_registry.is_empty():
		_forward_value_key_registry = _build_static_forward_value_key_registry()
	return _forward_value_key_registry


static func _build_static_forward_value_key_registry() -> Dictionary:
	var registry: Dictionary = {CENTRAL_VALUE_KEY: true}
	for perk_id_value: Variant in PerkConversionValues.CONVERTED_PERK_VALUES.keys():
		var perk_id: String = str(perk_id_value).strip_edges()
		var table_value: Variant = PerkConversionValues.CONVERTED_PERK_VALUES.get(perk_id, {})
		if not table_value is Dictionary:
			continue
		for key_value: Variant in (table_value as Dictionary).keys():
			var key: String = str(key_value).strip_edges()
			if key.is_empty() or PerkConversionValues.is_lower_value_better(perk_id, key):
				continue
			registry[key] = true
	return registry


func _is_single_entry_boolean_table(perk_id: String, key: String) -> bool:
	var perk_table_value: Variant = PerkConversionValues.CONVERTED_PERK_VALUES.get(perk_id, {})
	if not perk_table_value is Dictionary:
		return false
	var values_value: Variant = (perk_table_value as Dictionary).get(key, [])
	return values_value is Array and (values_value as Array).size() <= 1


func _normalize_source_ids(source_ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	for source_value: Variant in source_ids:
		var perk_id: String = str(source_value).strip_edges()
		if perk_id.is_empty() or normalized.has(perk_id):
			continue
		normalized.append(perk_id)
	normalized.sort()
	return normalized
