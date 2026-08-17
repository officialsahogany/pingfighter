extends RefCounted

const RuntimePerkEffectiveStatQuerySurface := preload("res://scripts/characters/runtime_perk_effective_stat_query_surface.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

var _perk_fusion_projector: Object = null
var _default_catalog: Object = null
var _mystic_dice_projector: Object = null
var _projection_cache: Dictionary = {}
var _projection_cache_ready := false
var _projection_builds := 0
var _effective_stat_queries: Object = RuntimePerkEffectiveStatQuerySurface.new()
var _cached_level_hash := 0
var _cached_fusion_revision := 0
var _cached_mystic_dice_revision := 0
var _cached_locale := ""
var _cached_item_perk_level_bonus := 0
var _cached_ignition_aura_active := false
var _cached_catalog_instance_id := 0
var _modal_preview_cache: Dictionary = {}
var _modal_preview_cache_key := 0
var _modal_preview_builds := 0


func get_composite_projection(runtime_state: Object, catalog: Object = null) -> Dictionary:
	if runtime_state == null:
		return {}
	if catalog == null:
		if _default_catalog == null:
			_default_catalog = load("res://scripts/characters/runtime_perk_catalog.gd").new()
		catalog = _default_catalog
	var runtime_skill_levels: Dictionary = _get_dictionary(runtime_state.get("runtime_skill_levels"))
	var fusion_revision := 0
	if runtime_state.has_method("get_perk_fusion_state"):
		var fusion_state: Object = runtime_state.call("get_perk_fusion_state")
		if fusion_state != null and fusion_state.has_method("get_revision"):
			fusion_revision = int(fusion_state.call("get_revision"))
	var mystic_dice_revision := 0
	if runtime_state.has_method("get_mystic_dice_revision"):
		mystic_dice_revision = int(runtime_state.call("get_mystic_dice_revision"))
	var level_hash := runtime_skill_levels.hash()
	var locale := _get_display_locale()
	var item_perk_level_bonus := int(runtime_state.get("item_perk_level_bonus"))
	var ignition_aura_active := bool(runtime_state.get("viper_ignition_aura_active"))
	var catalog_instance_id := catalog.get_instance_id() if catalog != null else 0
	if _matches_projection_signature(
		level_hash,
		fusion_revision,
		mystic_dice_revision,
		locale,
		item_perk_level_bonus,
		ignition_aura_active,
		catalog_instance_id
	):
		return _projection_cache
	var cache_key := hash([
		level_hash,
		fusion_revision,
		mystic_dice_revision,
		locale,
		item_perk_level_bonus,
		int(ignition_aura_active),
		catalog_instance_id,
	])
	if _perk_fusion_projector == null:
		_perk_fusion_projector = load("res://scripts/characters/perk_fusion_display_projection.gd").new()
	_projection_builds += 1
	var projection: Dictionary = _perk_fusion_projector.build(
		runtime_skill_levels,
		_call_dictionary(runtime_state, "get_perk_fusion_snapshot"),
		catalog,
		_call_dictionary(runtime_state, "get_effective_runtime_skill_levels"),
		_build_live_source_options(runtime_state)
	)
	# Mystic Dice bonuses remain in the stat breakdown, but the source is now a
	# consumed active item and must not occupy the acquired-Mugong/perk grid.
	projection["cache_signature"] = cache_key
	_projection_cache = projection
	_store_projection_signature(
		level_hash,
		fusion_revision,
		mystic_dice_revision,
		locale,
		item_perk_level_bonus,
		ignition_aura_active,
		catalog_instance_id
	)
	_projection_cache_ready = true
	return projection


func build_mystic_dice_projection(snapshot: Dictionary) -> Dictionary:
	return _get_mystic_dice_projector().build(snapshot)


func get_cache_stats() -> Dictionary:
	return {
		"projection_builds": _projection_builds,
		"modal_preview_builds": _modal_preview_builds,
	}


func invalidate() -> void:
	_projection_cache_ready = false


func reset_modal_preview_cache() -> void:
	_modal_preview_cache = {}
	_modal_preview_cache_key = 0


func merge_perk_fusion_modal_preview(
	runtime_state: Object,
	snapshot: Dictionary,
	catalog: Object
) -> Dictionary:
	if runtime_state == null:
		return snapshot
	var revision := 0
	if runtime_state.has_method("get_perk_fusion_revision"):
		revision = int(runtime_state.call("get_perk_fusion_revision"))
	var preview_key := hash([
		snapshot.get("selected_source_ids", []),
		str(snapshot.get("phase", "")),
		revision,
	])
	if preview_key != _modal_preview_cache_key or _modal_preview_cache.is_empty():
		_modal_preview_cache = _build_modal_preview(runtime_state, snapshot, catalog)
		_modal_preview_cache_key = preview_key
		_modal_preview_builds += 1
	snapshot.merge(_modal_preview_cache, true)
	return snapshot


func _matches_projection_signature(
	level_hash: int,
	fusion_revision: int,
	mystic_dice_revision: int,
	locale: String,
	item_perk_level_bonus: int,
	ignition_aura_active: bool,
	catalog_instance_id: int
) -> bool:
	return (
		_projection_cache_ready
		and _cached_level_hash == level_hash
		and _cached_fusion_revision == fusion_revision
		and _cached_mystic_dice_revision == mystic_dice_revision
		and _cached_locale == locale
		and _cached_item_perk_level_bonus == item_perk_level_bonus
		and _cached_ignition_aura_active == ignition_aura_active
		and _cached_catalog_instance_id == catalog_instance_id
	)


func _store_projection_signature(
	level_hash: int,
	fusion_revision: int,
	mystic_dice_revision: int,
	locale: String,
	item_perk_level_bonus: int,
	ignition_aura_active: bool,
	catalog_instance_id: int
) -> void:
	_cached_level_hash = level_hash
	_cached_fusion_revision = fusion_revision
	_cached_mystic_dice_revision = mystic_dice_revision
	_cached_locale = locale
	_cached_item_perk_level_bonus = item_perk_level_bonus
	_cached_ignition_aura_active = ignition_aura_active
	_cached_catalog_instance_id = catalog_instance_id


func _build_modal_preview(runtime_state: Object, snapshot: Dictionary, catalog: Object) -> Dictionary:
	var outcome_rules: Object = load("res://scripts/characters/perk_fusion_outcome_rules.gd")
	var conversion_values: Object = load("res://scripts/characters/perk_conversion_values.gd")
	var tokens: Dictionary = _call_dictionary(runtime_state, "get_perk_fusion_token_snapshot")
	var source_ids: Array = _get_array(snapshot.get("selected_source_ids", []))
	var owned: Array[String] = []
	if runtime_state.has_method("get_perk_fusion_owned_byproduct_ids"):
		owned.assign(_get_array(runtime_state.call("get_perk_fusion_owned_byproduct_ids")))
	var limit_context: Dictionary = {}
	if runtime_state.has_method("_build_perk_fusion_result_context"):
		limit_context = _get_dictionary(runtime_state.call("_build_perk_fusion_result_context", source_ids, catalog))
	var byproduct_catalog: Object = load("res://scripts/characters/perk_fusion_byproduct_catalog.gd").new()
	var available: Array[String] = []
	available.assign(byproduct_catalog.get_contextual_pool(
		owned,
		_get_array(limit_context.get("limit_break_eligible_sources", [])),
		PerkConversionFlags.is_enabled()
	))
	var dual_catalyst_armed := bool(tokens.get("dual_catalyst_armed", false))
	var byproduct_chance_bonus_percent := 0.0
	if runtime_state.has_method("get_perk_fusion_byproduct_chance_bonus_percent"):
		byproduct_chance_bonus_percent = maxf(
			0.0,
			float(runtime_state.call("get_perk_fusion_byproduct_chance_bonus_percent"))
		)
	var weights: Dictionary = outcome_rules.build_final_outcome_weights(
		available.is_empty(),
		dual_catalyst_armed,
		byproduct_chance_bonus_percent,
		available.size()
	)
	var runtime_skill_levels: Dictionary = _get_dictionary(runtime_state.get("runtime_skill_levels"))
	var source_previews: Array = []
	for source_value: Variant in source_ids:
		var perk_id := str(source_value)
		var options: Array = []
		var base_level := maxi(
			maxi(0, int(runtime_skill_levels.get(perk_id, 0))),
			maxi(0, int(runtime_skill_levels.get(StringName(perk_id), 0)))
		)
		var effective_level := 0
		if runtime_state.has_method("get_runtime_skill_level"):
			effective_level = int(runtime_state.call("get_runtime_skill_level", perk_id))
		for option_key_value: Variant in conversion_values.get_value_keys(perk_id):
			var option_key := str(option_key_value)
			options.append({
				"option_key": option_key,
				"value": float(conversion_values.get_value(perk_id, option_key, effective_level, runtime_state)),
				"polarity": "reverse" if conversion_values.is_lower_value_better(perk_id, option_key) else "forward",
			})
		source_previews.append({
			"perk_id": perk_id,
			"base_level": base_level,
			"effective_level": effective_level,
			"options": options,
		})
	return {
		"outcome_preview": {
			"core_stabilize_armed": bool(tokens.get("core_stabilize_armed", false)),
			"side_effect_effective_outcome": "stable" if bool(tokens.get("core_stabilize_armed", false)) else "side_effect",
			"byproduct_chance_bonus_percent": byproduct_chance_bonus_percent,
			"weights": weights.duplicate(true),
		},
		"source_previews": source_previews,
		"weights": weights.duplicate(true),
	}


func _get_mystic_dice_projector() -> Object:
	if _mystic_dice_projector == null:
		_mystic_dice_projector = load("res://scripts/characters/mystic_dice_display_projection.gd").new()
	return _mystic_dice_projector


func _get_display_locale() -> String:
	var language_settings: Object = load("res://scripts/core/language_settings.gd")
	if language_settings != null and language_settings.has_method("get_language"):
		return str(language_settings.call("get_language"))
	return ""


func _build_live_source_options(runtime_state: Object) -> Dictionary:
	var live: Dictionary = {}
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_state"):
		return live
	var fusion_state: Object = runtime_state.call("get_perk_fusion_state")
	if fusion_state == null or not fusion_state.has_method("get_all_records"):
		return live
	var conversion_values: Object = load("res://scripts/characters/perk_conversion_values.gd")
	for record_value: Variant in _get_array(fusion_state.call("get_all_records")):
		var record: Dictionary = _get_dictionary(record_value)
		var penalties: Dictionary = _get_dictionary(record.get("option_penalties", {}))
		var snapshots: Dictionary = _get_dictionary(record.get("commit_value_snapshots", {}))
		var deleted: Dictionary = _get_dictionary(record.get("deleted_options", {}))
		for source_value: Variant in _get_array(record.get("sources", [])):
			var perk_id := str(source_value)
			var option_keys: Array[String] = []
			for key_source: Dictionary in [
				_get_dictionary(penalties.get(perk_id, {})),
				_get_dictionary(snapshots.get(perk_id, {})),
			]:
				for option_value: Variant in key_source.keys():
					var option_key := str(option_value)
					if option_key not in option_keys:
						option_keys.append(option_key)
			for option_value: Variant in _get_array(deleted.get(perk_id, [])):
				var deleted_key := str(option_value)
				if deleted_key not in option_keys:
					option_keys.append(deleted_key)
			if option_keys.is_empty():
				continue
			var per_perk: Dictionary = {}
			var effective_level := 0
			if runtime_state.has_method("get_runtime_skill_level"):
				effective_level = int(runtime_state.call("get_runtime_skill_level", perk_id))
			for option_key: String in option_keys:
				var base_value: float
				var adjusted_value: float
				if option_key == "runtime_skill_bonus":
					base_value = _effective_stat_queries.get_runtime_skill_bonus_before_fusion_from_runtime_state(runtime_state, perk_id)
					adjusted_value = _effective_stat_queries.get_runtime_skill_bonus_from_runtime_state(runtime_state, perk_id)
				else:
					base_value = float(conversion_values.get_value_before_fusion(
						perk_id,
						option_key,
						effective_level,
						runtime_state
					))
					adjusted_value = float(conversion_values.get_value(
						perk_id,
						option_key,
						effective_level,
						runtime_state
					))
				per_perk[option_key] = {
					"value": base_value,
					"adjusted_value": adjusted_value,
				}
			live[perk_id] = per_perk
	return live


func _call_dictionary(target: Object, method_name: String) -> Dictionary:
	if target == null or not target.has_method(method_name):
		return {}
	return _get_dictionary(target.call(method_name))


func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _get_array(value: Variant) -> Array:
	return value if value is Array else []
