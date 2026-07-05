extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")

const LUCKY_COIN_ITEM_NAME := "lucky_coin"
const TREASURE_MAP_SKILL_ID := "downtown_treasure_map"
const TARGET_PASSIVE_DROP_SHARE := 0.20
const MYTHIC_BASE_SHARE := 0.01
const MYTHIC_MAX_SHARE := 0.50
const MIN_ACTIVE_SHARE := 0.20
const ONE_TIME_PASSIVE_SPAWN_NAMES := {
	"lucky_coin": true,
	"rainbow_fur_glove": true,
	"revival": true,
	"sacred_laurel": true,
	"star_detector": true,
}
const VIPER_ONLY_PASSIVE_SPAWN_NAMES := {
	"venom_mist_gauntlet": true,
}
const LINGPET_OWNED_GATED_ACTIVE_SPAWN_NAMES := {
	"lingpet_feed": true,
	"lingpet_apple_feed": true,
	"lingpet_melon_feed": true,
}

var item_catalog: Object = ActiveItemCatalog.new()
var passive_mythic_catalog: Object = MythicItemCatalog.new()
var _active_spawn_template_cache: Array[Dictionary] = []
var _passive_mythic_spawn_template_cache: Array[Dictionary] = []
var _active_spawn_template_source: Object = null
var _passive_mythic_spawn_template_source: Object = null
var _active_spawn_template_cache_ready := false
var _passive_mythic_spawn_template_cache_ready := false
var _spawn_template_prewarm_phase := 0
var _active_spawn_template_prewarm_index := 0
var _passive_mythic_spawn_template_prewarm_index := 0


func clear_spawn_candidate_cache() -> void:
	_active_spawn_template_cache.clear()
	_passive_mythic_spawn_template_cache.clear()
	_active_spawn_template_source = null
	_passive_mythic_spawn_template_source = null
	_active_spawn_template_cache_ready = false
	_passive_mythic_spawn_template_cache_ready = false
	_spawn_template_prewarm_phase = 0
	_active_spawn_template_prewarm_index = 0
	_passive_mythic_spawn_template_prewarm_index = 0


func prewarm_spawn_candidate_templates(perf_logger: Object = null) -> void:
	while not prewarm_spawn_candidate_templates_step(perf_logger):
		pass


func prewarm_spawn_candidate_templates_step(perf_logger: Object = null) -> bool:
	if (
		_active_spawn_template_cache_ready
		and _active_spawn_template_source == item_catalog
		and _passive_mythic_spawn_template_cache_ready
		and _passive_mythic_spawn_template_source == passive_mythic_catalog
	):
		_spawn_template_prewarm_phase = 0
		return true
	match _spawn_template_prewarm_phase:
		0:
			if not _prewarm_active_spawn_candidate_templates_step():
				return false
		1:
			if not _prewarm_passive_mythic_spawn_candidate_templates_step(perf_logger):
				return false
		_:
			_spawn_template_prewarm_phase = 0
			return true
	_spawn_template_prewarm_phase += 1
	return false


func get_spawn_candidate_cache_status() -> Dictionary:
	return {
		"active_ready": _active_spawn_template_cache_ready,
		"passive_mythic_ready": _passive_mythic_spawn_template_cache_ready,
		"active_count": _active_spawn_template_cache.size(),
		"passive_mythic_count": _passive_mythic_spawn_template_cache.size(),
	}


func build_catalog_item(item_name: String) -> Dictionary:
	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	if not item_data.is_empty():
		return item_data
	if passive_mythic_catalog == null or not passive_mythic_catalog.has_method("build_item_by_name"):
		return {}
	item_data = passive_mythic_catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return {}
	if passive_mythic_catalog.has_method("build_random_rolls"):
		var rolls: Dictionary = passive_mythic_catalog.build_random_rolls(item_name)
		if not rolls.is_empty():
			item_data["rolls"] = rolls
	if passive_mythic_catalog.has_method("sync_roll_fields"):
		item_data = passive_mythic_catalog.sync_roll_fields(item_data, false)
	return item_data


func get_field_spawn_candidate_names(registry: Object = null, owner: Object = null) -> Dictionary:
	var names: Dictionary = {}
	for item_data in build_spawn_candidates(registry, owner):
		var item_name: String = str(item_data.get("name", ""))
		if item_name != "":
			names[item_name] = true
	return names


func build_random_spawn_item(
	registry: Object = null,
	owner: Object = null,
	perf_logger: Object = null
) -> Dictionary:
	var sample_start: int = _perf_begin(perf_logger)
	var candidates: Array[Dictionary] = build_spawn_candidates(registry, owner, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.random.candidates", sample_start)
	sample_start = _perf_begin(perf_logger)
	var item_data: Dictionary = build_weighted_spawn_item(candidates, {}, registry, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.random.weighted", sample_start)
	return item_data


func build_lucky_coin_bonus_spawn_item(
	registry: Object = null,
	owner: Object = null,
	perf_logger: Object = null
) -> Dictionary:
	var sample_start: int = _perf_begin(perf_logger)
	var mythic_item_runtime := _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("should_lucky_coin_double_spawn"):
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.lucky.check", sample_start)
		return {}
	if not bool(mythic_item_runtime.should_lucky_coin_double_spawn()):
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.lucky.check", sample_start)
		return {}
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.lucky.check", sample_start)
	sample_start = _perf_begin(perf_logger)
	var candidates: Array[Dictionary] = build_spawn_candidates(registry, owner, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.lucky.candidates", sample_start)
	sample_start = _perf_begin(perf_logger)
	var item_data: Dictionary = build_weighted_spawn_item(candidates, {LUCKY_COIN_ITEM_NAME: true}, registry, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.lucky.weighted", sample_start)
	return item_data


func build_weighted_spawn_item(
	candidates: Array[Dictionary],
	excluded_names: Dictionary = {},
	registry: Object = null,
	perf_logger: Object = null
) -> Dictionary:
	var sample_start: int = _perf_begin(perf_logger)
	var weighted_candidates: Array[Dictionary] = build_group_scaled_spawn_weights(
		candidates,
		excluded_names,
		registry,
		perf_logger
	)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.scale", sample_start)
	if weighted_candidates.is_empty():
		return {}
	sample_start = _perf_begin(perf_logger)
	var total_weight: float = 0.0
	for entry in weighted_candidates:
		total_weight += max(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.roll", sample_start)
		return {}

	var roll: float = randf() * total_weight
	for entry in weighted_candidates:
		roll -= max(0.0, float(entry.get("weight", 0.0)))
		if roll <= 0.0:
			var selected_item: Variant = entry.get("item", {})
			if selected_item is Dictionary:
				var selected_item_data: Dictionary = selected_item
				_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.roll", sample_start)
				return _prepare_selected_spawn_item(selected_item_data, perf_logger)
	var fallback_item: Variant = weighted_candidates.back().get("item", {})
	if fallback_item is Dictionary:
		var fallback_item_data: Dictionary = fallback_item
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.roll", sample_start)
		return _prepare_selected_spawn_item(fallback_item_data, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.roll", sample_start)
	return {}


func build_group_scaled_spawn_weights(
	candidates: Array[Dictionary],
	excluded_names: Dictionary = {},
	registry: Object = null,
	perf_logger: Object = null
) -> Array[Dictionary]:
	var base_entries: Array[Dictionary] = []
	var group_sums := {
		"active": 0.0,
		"passive": 0.0,
		"mythic": 0.0,
	}
	for candidate in candidates:
		var item_name: String = str(candidate.get("name", ""))
		if item_name == "" or excluded_names.has(item_name):
			continue
		var weight: float = max(0.0, float(candidate.get("chance", 0.0)))
		if weight <= 0.0:
			continue
		var group: String = _get_spawn_group(candidate)
		group_sums[group] = float(group_sums.get(group, 0.0)) + weight
		base_entries.append({
			"item": candidate,
			"weight": weight,
			"group": group,
		})

	var sample_start: int = _perf_begin(perf_logger)
	var targets: Dictionary = get_spawn_group_target_shares(group_sums, registry)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.target_shares", sample_start)
	var scaled_entries: Array[Dictionary] = []
	for entry in base_entries:
		var group: String = str(entry.get("group", "active"))
		var group_sum: float = max(0.0, float(group_sums.get(group, 0.0)))
		if group_sum <= 0.0:
			continue
		var target_share: float = max(0.0, float(targets.get(group, 0.0)))
		var scaled_weight: float = float(entry.get("weight", 0.0)) * target_share / group_sum
		if scaled_weight <= 0.0:
			continue
		scaled_entries.append({
			"item": entry.get("item", {}),
			"weight": scaled_weight,
			"group": group,
		})
	return scaled_entries


func get_spawn_group_target_shares(group_sums: Dictionary, registry: Object = null) -> Dictionary:
	var active_sum: float = max(0.0, float(group_sums.get("active", 0.0)))
	var passive_sum: float = max(0.0, float(group_sums.get("passive", 0.0)))
	var mythic_sum: float = max(0.0, float(group_sums.get("mythic", 0.0)))
	if active_sum + passive_sum + mythic_sum <= 0.0:
		return {"active": 0.0, "passive": 0.0, "mythic": 0.0}

	var treasure_map_level: int = max(0, _get_treasure_map_level(registry))
	var mythic_multiplier: float = _get_treasure_map_field_mythic_multiplier(registry, treasure_map_level)
	var passive_share_bonus: float = _get_treasure_map_passive_drop_share_bonus(registry, treasure_map_level)
	var raw_mythic: float = (
		min(MYTHIC_MAX_SHARE, MYTHIC_BASE_SHARE * mythic_multiplier)
		if mythic_sum > 0.0
		else 0.0
	)
	var raw_passive: float = (
		TARGET_PASSIVE_DROP_SHARE + passive_share_bonus
		if passive_sum > 0.0
		else 0.0
	)

	var target_active := 0.0
	var target_passive := 0.0
	var target_mythic := 0.0
	if active_sum > 0.0:
		target_mythic = raw_mythic
		target_passive = min(max(0.0, 1.0 - MIN_ACTIVE_SHARE - target_mythic), raw_passive)
		target_active = max(0.0, 1.0 - target_mythic - target_passive)
	else:
		var requested_total: float = raw_mythic + raw_passive
		if requested_total > 0.0:
			target_mythic = raw_mythic / requested_total
			target_passive = raw_passive / requested_total

	return {
		"active": target_active,
		"passive": target_passive,
		"mythic": target_mythic,
	}


func build_spawn_candidates(
	registry: Object = null,
	owner: Object = null,
	perf_logger: Object = null
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var sample_start: int = _perf_begin(perf_logger)
	for active_template in _get_active_spawn_candidate_templates():
		if _should_skip_active_spawn_candidate(active_template, registry, owner):
			continue
		# _apply_passive_spawn_weight returns the original template unchanged for
		# every name except wall/boomerang/aipill; only those three allocate a
		# duplicate. The downstream weighted picker reads candidates without
		# mutating, and the eventual winner is deep-copied in
		# _prepare_selected_spawn_item, so propagating template references here
		# avoids 48+ unused duplicate(true) calls per field spawn.
		candidates.append(_apply_passive_spawn_weight(active_template, registry))
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.active", sample_start)
	sample_start = _perf_begin(perf_logger)
	for passive_template in _get_passive_mythic_spawn_candidate_templates(perf_logger):
		if passive_template.is_empty():
			continue
		if _should_skip_passive_spawn_candidate(passive_template, registry, owner):
			continue
		candidates.append(passive_template)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.passive_mythic", sample_start)
	return candidates


func _get_active_spawn_candidate_templates() -> Array[Dictionary]:
	if _active_spawn_template_cache_ready and _active_spawn_template_source == item_catalog:
		return _active_spawn_template_cache
	_active_spawn_template_cache.clear()
	_active_spawn_template_source = item_catalog
	_active_spawn_template_cache_ready = true
	if item_catalog == null or not item_catalog.has_method("build_item_by_name"):
		return _active_spawn_template_cache
	for item_name_value in ActiveItemCatalog.FIELD_SPAWN_ORDER:
		var item_data: Dictionary = item_catalog.build_item_by_name(str(item_name_value))
		if not item_data.is_empty():
			_active_spawn_template_cache.append(item_data.duplicate(true))
	return _active_spawn_template_cache


func _prewarm_active_spawn_candidate_templates_step() -> bool:
	if _active_spawn_template_cache_ready and _active_spawn_template_source == item_catalog:
		_active_spawn_template_prewarm_index = 0
		return true
	if _active_spawn_template_source != item_catalog:
		_active_spawn_template_cache.clear()
		_active_spawn_template_source = item_catalog
		_active_spawn_template_cache_ready = false
		_active_spawn_template_prewarm_index = 0
	if item_catalog == null or not item_catalog.has_method("build_item_by_name"):
		_active_spawn_template_cache_ready = true
		_active_spawn_template_prewarm_index = 0
		return true
	if _active_spawn_template_prewarm_index >= ActiveItemCatalog.FIELD_SPAWN_ORDER.size():
		_active_spawn_template_cache_ready = true
		_active_spawn_template_prewarm_index = 0
		return true
	var item_name := str(ActiveItemCatalog.FIELD_SPAWN_ORDER[_active_spawn_template_prewarm_index])
	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	if not item_data.is_empty():
		_active_spawn_template_cache.append(item_data.duplicate(true))
	_active_spawn_template_prewarm_index += 1
	if _active_spawn_template_prewarm_index >= ActiveItemCatalog.FIELD_SPAWN_ORDER.size():
		_active_spawn_template_cache_ready = true
		_active_spawn_template_prewarm_index = 0
		return true
	return false


func _get_passive_mythic_spawn_candidate_templates(perf_logger: Object = null) -> Array[Dictionary]:
	if (
		_passive_mythic_spawn_template_cache_ready
		and _passive_mythic_spawn_template_source == passive_mythic_catalog
	):
		return _passive_mythic_spawn_template_cache
	_passive_mythic_spawn_template_cache.clear()
	_passive_mythic_spawn_template_source = passive_mythic_catalog
	_passive_mythic_spawn_template_cache_ready = true
	if passive_mythic_catalog == null:
		return _passive_mythic_spawn_template_cache

	var sample_start: int = _perf_begin(perf_logger)
	if passive_mythic_catalog.has_method("build_item_by_name"):
		for item_name_value in MythicItemCatalog.FIELD_SPAWN_ORDER:
			var item_data: Dictionary = passive_mythic_catalog.build_item_by_name(str(item_name_value))
			if not item_data.is_empty():
				item_data = _prepare_passive_mythic_template(item_data)
				_passive_mythic_spawn_template_cache.append(item_data)
	elif passive_mythic_catalog.has_method("get_field_spawn_items"):
		for item_value in passive_mythic_catalog.get_field_spawn_items():
			var item_data: Dictionary = _get_dict(item_value)
			if not item_data.is_empty():
				_passive_mythic_spawn_template_cache.append(item_data.duplicate(true))
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.passive_mythic.source", sample_start)
	return _passive_mythic_spawn_template_cache


func _prewarm_passive_mythic_spawn_candidate_templates_step(perf_logger: Object = null) -> bool:
	if (
		_passive_mythic_spawn_template_cache_ready
		and _passive_mythic_spawn_template_source == passive_mythic_catalog
	):
		_passive_mythic_spawn_template_prewarm_index = 0
		return true
	if _passive_mythic_spawn_template_source != passive_mythic_catalog:
		_passive_mythic_spawn_template_cache.clear()
		_passive_mythic_spawn_template_source = passive_mythic_catalog
		_passive_mythic_spawn_template_cache_ready = false
		_passive_mythic_spawn_template_prewarm_index = 0
	if passive_mythic_catalog == null:
		_passive_mythic_spawn_template_cache_ready = true
		_passive_mythic_spawn_template_prewarm_index = 0
		return true
	var sample_start: int = _perf_begin(perf_logger)
	if passive_mythic_catalog.has_method("build_item_by_name"):
		if _passive_mythic_spawn_template_prewarm_index >= MythicItemCatalog.FIELD_SPAWN_ORDER.size():
			_passive_mythic_spawn_template_cache_ready = true
			_passive_mythic_spawn_template_prewarm_index = 0
			_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.passive_mythic.source", sample_start)
			return true
		var item_name := str(MythicItemCatalog.FIELD_SPAWN_ORDER[_passive_mythic_spawn_template_prewarm_index])
		var item_data: Dictionary = passive_mythic_catalog.build_item_by_name(item_name)
		if not item_data.is_empty():
			_passive_mythic_spawn_template_cache.append(_prepare_passive_mythic_template(item_data))
		_passive_mythic_spawn_template_prewarm_index += 1
		if _passive_mythic_spawn_template_prewarm_index >= MythicItemCatalog.FIELD_SPAWN_ORDER.size():
			_passive_mythic_spawn_template_cache_ready = true
			_passive_mythic_spawn_template_prewarm_index = 0
			_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.passive_mythic.source", sample_start)
			return true
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.passive_mythic.source", sample_start)
		return false
	if passive_mythic_catalog.has_method("get_field_spawn_items"):
		for item_value in passive_mythic_catalog.get_field_spawn_items():
			var item_data: Dictionary = _get_dict(item_value)
			if not item_data.is_empty():
				_passive_mythic_spawn_template_cache.append(item_data.duplicate(true))
	_passive_mythic_spawn_template_cache_ready = true
	_passive_mythic_spawn_template_prewarm_index = 0
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.candidates.passive_mythic.source", sample_start)
	return true


func _prepare_passive_mythic_template(item_data: Dictionary) -> Dictionary:
	var result: Dictionary = item_data.duplicate(true)
	result.erase("rolls")
	result.erase("roll_options")
	result.erase("rolled_options")
	result.erase("name_prefix")
	result.erase("quality_tier")
	result.erase("quality_color")
	result.erase("qualified_display_name")
	result["_field_spawn_randomize_rolls"] = true
	return result


func _prepare_selected_spawn_item(item_data: Dictionary, perf_logger: Object = null) -> Dictionary:
	var result: Dictionary = item_data.duplicate(true)
	var should_randomize_rolls := bool(result.get("_field_spawn_randomize_rolls", false))
	result.erase("_field_spawn_randomize_rolls")
	if not should_randomize_rolls and not _get_dict(result.get("rolls", {})).is_empty():
		return result
	if _get_spawn_group(result) == "active":
		return result
	if passive_mythic_catalog == null:
		return result
	var item_name: String = str(result.get("name", ""))
	if item_name == "":
		return result
	var sample_start: int = _perf_begin(perf_logger)
	if passive_mythic_catalog.has_method("build_random_rolls"):
		result["rolls"] = passive_mythic_catalog.build_random_rolls(item_name)
	if passive_mythic_catalog.has_method("sync_roll_fields"):
		result = passive_mythic_catalog.sync_roll_fields(result, false)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.pool.weighted.finalize_selected", sample_start)
	return result


func _apply_passive_spawn_weight(item_data: Dictionary, registry: Object) -> Dictionary:
	var item_name: String = str(item_data.get("name", ""))
	var mythic_item_runtime := _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return item_data
	var method_name := ""
	match item_name:
		"wall":
			method_name = "get_wall_item_spawn_chance"
		"boomerang":
			method_name = "get_boomerang_item_spawn_chance"
		"aipill":
			method_name = "get_aipill_item_spawn_chance"
		_:
			return item_data
	if not mythic_item_runtime.has_method(method_name):
		return item_data
	var adjusted := item_data.duplicate(true)
	adjusted["chance"] = float(mythic_item_runtime.call(method_name, float(item_data.get("chance", 0.0))))
	return adjusted


func _should_skip_active_spawn_candidate(item_data: Dictionary, registry: Object = null, owner: Object = null) -> bool:
	var item_name: String = str(item_data.get("name", ""))
	if item_name == "lingpet_egg":
		return _should_skip_lingpet_egg_spawn(registry, owner)
	if not LINGPET_OWNED_GATED_ACTIVE_SPAWN_NAMES.has(item_name):
		return false
	return LingpetCollectionState.new().get_owned_pet_ids_from_owner(owner).is_empty()


# The Pro/Mythic "lingpet_egg" active item drops in non-junior leagues whenever
# the lingpet runtime can accept a new egg acquisition.
# Junior never offers it — its lingpet is auto-present from battle start. Uses the
# already-created runtime (cached peek, never a lazy instantiation in this spawn
# path); when the runtime is not cached yet it falls back to a league-only gate.
func _should_skip_lingpet_egg_spawn(registry: Object, owner: Object) -> bool:
	# Don't spawn a second egg while the player already holds one — it could not be
	# picked up anyway (active_item_slot_controller rejects a redundant egg), so an
	# uncatchable egg on the field would just be clutter.
	if _owner_has_lingpet_egg_in_slots(owner):
		return true
	var lingpet_runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime != null and lingpet_runtime.has_method("can_offer_egg_item"):
		return not bool(lingpet_runtime.can_offer_egg_item(owner))
	return _is_junior_league(owner)


func _owner_has_lingpet_egg_in_slots(owner: Object) -> bool:
	if owner == null:
		return false
	for slot_value in BattleSceneOwnerReader.get_array(owner, "active_item_slots"):
		if slot_value is Dictionary and str((slot_value as Dictionary).get("name", "")) == "lingpet_egg":
			return true
	return false


func _is_junior_league(owner: Object) -> bool:
	return str(LingpetCollectionState.new().get_hatch_context(owner).get("league_mode", "")) == "junior"


# Cache-only peek: the spawn path must NEVER lazy-instantiate the lingpet runtime
# (per the hot-path lazy-init contract). When it is not cached yet, callers fall
# back to a league-only gate rather than creating the module here.
func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	return registry.get_cached_instance(key)


func _should_skip_passive_spawn_candidate(item_data: Dictionary, registry: Object, owner: Object = null) -> bool:
	var item_name: String = str(item_data.get("name", ""))
	if VIPER_ONLY_PASSIVE_SPAWN_NAMES.has(item_name) and owner != null and _get_selected_character_type(owner) != "viper":
		return true
	if not ONE_TIME_PASSIVE_SPAWN_NAMES.has(item_name):
		return false
	var mythic_item_runtime := _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("should_skip_one_time_passive_spawn"):
		return bool(mythic_item_runtime.should_skip_one_time_passive_spawn(item_name))
	if mythic_item_runtime != null and mythic_item_runtime.has_method("has_owned_item_name"):
		return bool(mythic_item_runtime.has_owned_item_name(item_name))
	if mythic_item_runtime != null and mythic_item_runtime.has_method("is_lucky_coin_equipped") and item_name == LUCKY_COIN_ITEM_NAME:
		return bool(mythic_item_runtime.is_lucky_coin_equipped())
	if mythic_item_runtime != null and mythic_item_runtime.has_method("is_star_detector_equipped") and item_name == "star_detector":
		return bool(mythic_item_runtime.is_star_detector_equipped())
	return false


func _get_spawn_group(item_data: Dictionary) -> String:
	var item_type: String = str(item_data.get("type", "active"))
	var rarity: String = str(item_data.get("rarity", ""))
	if item_type in ["mythic", "legendary"] or rarity in ["mythic", "legendary"]:
		return "mythic"
	if item_type == "passive":
		return "passive"
	return "active"


func _get_treasure_map_level(registry: Object) -> int:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return 0
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level(TREASURE_MAP_SKILL_ID)))
	var levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
	if levels_value is Dictionary:
		return max(0, int(levels_value.get(TREASURE_MAP_SKILL_ID, 0)))
	return 0


func _get_treasure_map_field_mythic_multiplier(registry: Object, fallback_level: int) -> float:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_downtown_treasure_map_field_mythic_multiplier"):
		return max(0.0, float(runtime_perk_state.get_downtown_treasure_map_field_mythic_multiplier()))
	return 1.0 + 1.5 * float(max(0, fallback_level))


func _get_treasure_map_passive_drop_share_bonus(registry: Object, fallback_level: int) -> float:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_downtown_treasure_map_passive_drop_share_bonus"):
		return max(0.0, float(runtime_perk_state.get_downtown_treasure_map_passive_drop_share_bonus()))
	return 0.03 * float(max(0, fallback_level))


func _get_selected_character_type(owner: Object) -> String:
	return str(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")).strip_edges().to_lower()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
