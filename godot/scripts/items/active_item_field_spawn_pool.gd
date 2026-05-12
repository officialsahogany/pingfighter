extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

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

var item_catalog: Object = ActiveItemCatalog.new()
var passive_mythic_catalog: Object = MythicItemCatalog.new()


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


func build_random_spawn_item(registry: Object = null, owner: Object = null) -> Dictionary:
	return build_weighted_spawn_item(build_spawn_candidates(registry, owner), {}, registry)


func build_lucky_coin_bonus_spawn_item(registry: Object = null, owner: Object = null) -> Dictionary:
	var mythic_item_runtime := _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("should_lucky_coin_double_spawn"):
		return {}
	if not bool(mythic_item_runtime.should_lucky_coin_double_spawn()):
		return {}
	return build_weighted_spawn_item(build_spawn_candidates(registry, owner), {LUCKY_COIN_ITEM_NAME: true}, registry)


func build_weighted_spawn_item(
	candidates: Array[Dictionary],
	excluded_names: Dictionary = {},
	registry: Object = null
) -> Dictionary:
	var weighted_candidates: Array[Dictionary] = build_group_scaled_spawn_weights(
		candidates,
		excluded_names,
		registry
	)
	if weighted_candidates.is_empty():
		return {}
	var total_weight: float = 0.0
	for entry in weighted_candidates:
		total_weight += max(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		return {}

	var roll: float = randf() * total_weight
	for entry in weighted_candidates:
		roll -= max(0.0, float(entry.get("weight", 0.0)))
		if roll <= 0.0:
			var selected_item: Variant = entry.get("item", {})
			if selected_item is Dictionary:
				return selected_item.duplicate(true)
	var fallback_item: Variant = weighted_candidates.back().get("item", {})
	if fallback_item is Dictionary:
		return fallback_item.duplicate(true)
	return {}


func build_group_scaled_spawn_weights(
	candidates: Array[Dictionary],
	excluded_names: Dictionary = {},
	registry: Object = null
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

	var targets: Dictionary = get_spawn_group_target_shares(group_sums, registry)
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


func build_spawn_candidates(registry: Object = null, owner: Object = null) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for item_name_value in ActiveItemCatalog.FIELD_SPAWN_ORDER:
		var item_data: Dictionary = item_catalog.build_item_by_name(str(item_name_value))
		if not item_data.is_empty():
			item_data = _apply_passive_spawn_weight(item_data, registry)
			candidates.append(item_data)
	if passive_mythic_catalog != null and passive_mythic_catalog.has_method("get_field_spawn_items"):
		for item_value in passive_mythic_catalog.get_field_spawn_items():
			var item_data: Dictionary = _get_dict(item_value)
			if not item_data.is_empty():
				if _should_skip_passive_spawn_candidate(item_data, registry, owner):
					continue
				candidates.append(item_data)
	return candidates


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
