extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetVisualTextureCache := preload("res://scripts/lingpet/lingpet_visual_texture_cache.gd")

const DEFAULT_PET_ID := LingpetCatalog.DEFAULT_PET_ID
const AFFINITY_MOBILITY_SPEED_BONUS_PCT := 5.0
const AFFINITY_MOBILITY_SPEED_CAP_PCT := 30.0
const AFFINITY_FLIGHT_APPEARANCE_BONUS := 0.05
const AFFINITY_FLIGHT_APPEARANCE_CAP := 0.30
const AFFINITY_PATROL_DEFENSE_BONUS := 0.04
const AFFINITY_PATROL_DEFENSE_STACK_CAP := 0.08
const AFFINITY_PATROL_DEFENSE_CAP := 0.80
const AFFINITY_HIT_GAUGE_CARD_BONUS := 5.0

var pet_id := DEFAULT_PET_ID
var active_skill_id := ""
var active_skill_ids: Array[String] = []
var active_skill_levels: Dictionary = {}
var active_slot_count := LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT
var passive_skill_id := ""
var active_skill_level := LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL
var passive_skill_level := LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
var affinity_level := 0
var affinity_rewards: Dictionary = LingpetAffinityState.get_empty_reward_counts()
var affinity_reward_signature := "0|0|0|0|0|0"
var _hatch_mobility_headstart := 0.0
var _hatch_defense_headstart := 0.0
var _visual_texture_cache: Object = LingpetVisualTextureCache.new()
var _active_skill_cache_key := ""
var _active_skill_cache: Dictionary = {}
var _active_skill_cache_keys: Dictionary = {}
var _active_skill_caches: Dictionary = {}
var _passive_skill_cache_key := ""
var _passive_skill_cache: Dictionary = {}
var _passive_effect_cache_key := ""
var _passive_effect_cache: Dictionary = {}


func set_pet_id(value: String, fallback: String = DEFAULT_PET_ID) -> String:
	var normalized := normalize_pet_id(value)
	if normalized == "":
		normalized = normalize_pet_id(fallback)
	if normalized == "":
		normalized = DEFAULT_PET_ID
	pet_id = normalized
	_apply_default_loadout_if_needed()
	_invalidate_metadata_cache()
	return pet_id


func normalize_pet_id(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if LingpetCatalog.has_pet(normalized):
		return normalized
	return ""


func get_display_name() -> String:
	return LingpetCatalog.get_display_name(pet_id)


func get_required_hits(fallback: int) -> int:
	return LingpetCatalog.get_required_hits(pet_id, fallback)


func get_stat(stat_name: String, fallback: float) -> float:
	var base_value := LingpetCatalog.get_stat(pet_id, stat_name, fallback)
	match stat_name:
		"patrol_speed_default", "patrol_speed_min", "patrol_speed_max":
			var speed_bonus_pct := _get_passive_effect_value("patrol_speed_bonus_pct")
			if _is_patrol_motion_style():
				var mobility_stacks := mini(_get_affinity_reward_count("mobility_stacks"), LingpetAffinityState.MAX_MOBILITY_STACKS)
				var hatch_speed_bonus_pct := _hatch_mobility_headstart * AFFINITY_MOBILITY_SPEED_CAP_PCT
				speed_bonus_pct += minf(hatch_speed_bonus_pct + float(mobility_stacks) * AFFINITY_MOBILITY_SPEED_BONUS_PCT, AFFINITY_MOBILITY_SPEED_CAP_PCT)
			return base_value * (1.0 + speed_bonus_pct / 100.0)
		"catch_width":
			return base_value * (1.0 + (_get_passive_effect_value("catch_size_bonus_pct") + _get_passive_effect_value("catch_width_bonus_pct")) / 100.0)
		"catch_height":
			return base_value * (1.0 + (_get_passive_effect_value("catch_size_bonus_pct") + _get_passive_effect_value("catch_height_bonus_pct")) / 100.0)
		"defense_rate":
			var defense_bonus := _get_passive_effect_value("defense_rate_bonus")
			if _is_patrol_motion_style():
				var defense_stacks := mini(_get_affinity_reward_count("defense_stacks"), LingpetAffinityState.MAX_DEFENSE_STACKS)
				var hatch_defense_bonus := _hatch_defense_headstart * AFFINITY_PATROL_DEFENSE_STACK_CAP
				defense_bonus += minf(hatch_defense_bonus + float(defense_stacks) * AFFINITY_PATROL_DEFENSE_BONUS, AFFINITY_PATROL_DEFENSE_STACK_CAP)
			return clampf(base_value + defense_bonus, 0.0, AFFINITY_PATROL_DEFENSE_CAP)
		"hit_gauge_gain":
			var gauge_bonus := _get_passive_effect_value("hit_gauge_gain_bonus")
			var gauge_stacks := mini(_get_affinity_reward_count("gauge_stacks"), LingpetAffinityState.MAX_GAUGE_STACKS)
			gauge_bonus += float(gauge_stacks) * AFFINITY_HIT_GAUGE_CARD_BONUS
			return maxf(0.0, base_value + gauge_bonus)
		"appearance_rate":
			var appearance_bonus := 0.0
			if _is_flight_motion_style():
				var mobility_stacks := mini(_get_affinity_reward_count("mobility_stacks"), LingpetAffinityState.MAX_MOBILITY_STACKS)
				var hatch_appearance_bonus := _hatch_mobility_headstart * AFFINITY_FLIGHT_APPEARANCE_CAP
				appearance_bonus += minf(hatch_appearance_bonus + float(mobility_stacks) * AFFINITY_FLIGHT_APPEARANCE_BONUS, AFFINITY_FLIGHT_APPEARANCE_CAP)
			return clampf(base_value + appearance_bonus, 0.0, 1.0)
		"gauge_gain_bonus_pct":
			if passive_skill_id.strip_edges() != "":
				return maxf(0.0, _get_passive_effect_value("gauge_gain_bonus_pct"))
			return maxf(0.0, base_value)
	return base_value


func get_visual_layout_value(layout_key: String, fallback: float) -> float:
	return LingpetCatalog.get_visual_layout_value(pet_id, layout_key, fallback)


func get_active_skill(slot_index: int = 0) -> Dictionary:
	var slot := clampi(slot_index, 0, LingpetCatalog.MAX_ACTIVE_SLOT_COUNT - 1)
	var cache_key := _build_active_skill_cache_key(slot)
	if str(_active_skill_cache_keys.get(slot, "")) == cache_key:
		return (_active_skill_caches.get(slot, {}) as Dictionary)
	var skill_id := get_skill_id(slot)
	var skill := LingpetCatalog.get_active_skill(pet_id, skill_id, _get_effective_active_skill_level(slot))
	var passive_cooldown_reduction_pct := _get_passive_effect_value("active_cooldown_reduction_pct")
	if passive_cooldown_reduction_pct > 0.0 and float(skill.get("cooldown", 0.0)) > 0.0:
		var current_cooldown := float(skill.get("cooldown", 0.0))
		skill["pre_passive_cooldown"] = current_cooldown
		skill["passive_cooldown_reduction_pct"] = passive_cooldown_reduction_pct
		skill["cooldown"] = current_cooldown * maxf(0.10, 1.0 - passive_cooldown_reduction_pct / 100.0)
	var passive_windup_reduction_pct := _get_passive_effect_value("active_windup_reduction_pct")
	if passive_windup_reduction_pct > 0.0 and float(skill.get("windup_seconds", 0.0)) > 0.0:
		var current_windup := float(skill.get("windup_seconds", 0.0))
		skill["pre_passive_windup_seconds"] = current_windup
		skill["passive_windup_reduction_pct"] = passive_windup_reduction_pct
		skill["windup_seconds"] = current_windup * maxf(0.10, 1.0 - passive_windup_reduction_pct / 100.0)
	_active_skill_cache_keys[slot] = cache_key
	_active_skill_caches[slot] = skill
	if slot == 0:
		_active_skill_cache_key = cache_key
		_active_skill_cache = skill
	return skill


func get_active_skill_pool() -> Array[Dictionary]:
	return LingpetCatalog.get_active_skill_pool(pet_id)


func set_loadout(
	active_id: String,
	passive_id: String,
	active_level: int = LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL,
	passive_level: int = LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL,
	next_active_skill_ids: Array[String] = [],
	next_active_skill_levels: Dictionary = {},
	next_active_slot_count: int = LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT
) -> void:
	active_skill_ids = _normalize_active_skill_ids(active_id, next_active_skill_ids)
	active_slot_count = _normalize_active_slot_count(next_active_slot_count, active_skill_ids)
	active_skill_levels = _normalize_active_skill_levels(active_skill_ids, active_level, next_active_skill_levels)
	active_skill_id = active_skill_ids[0] if active_skill_ids.size() > 0 else ""
	passive_skill_id = LingpetCatalog.normalize_passive_skill_id(pet_id, passive_id)
	active_skill_level = get_active_skill_level_for_slot(0)
	passive_skill_level = LingpetCatalog.clamp_skill_level(passive_level) if passive_skill_id != "" else 0
	_invalidate_metadata_cache()


func set_loadout_from_data(loadout: Dictionary) -> void:
	var raw_active_ids: Array[String] = []
	var active_ids_value: Variant = loadout.get("active_skill_ids", [])
	if active_ids_value is Array:
		for raw_id in active_ids_value as Array:
			raw_active_ids.append(str(raw_id))
	var has_active_loadout := str(loadout.get("active_skill_id", "")).strip_edges() != "" or not raw_active_ids.is_empty()
	var has_passive_loadout := str(loadout.get("passive_skill_id", "")).strip_edges() != ""
	set_loadout(
		str(loadout.get("active_skill_id", "")),
		str(loadout.get("passive_skill_id", "")),
		int(loadout.get("active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL if has_active_loadout else 0)),
		int(loadout.get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL if has_passive_loadout else 0)),
		raw_active_ids,
		loadout.get("active_skill_levels", {}) as Dictionary,
		int(loadout.get("active_slot_count", LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT if has_active_loadout else 0))
	)


func set_affinity_level(level: int) -> void:
	var next_level := clampi(level, 0, LingpetAffinityState.MAX_LEVEL)
	if next_level == affinity_level:
		return
	affinity_level = next_level
	_invalidate_metadata_cache()


func set_affinity_rewards(rewards: Dictionary) -> void:
	var next_rewards := LingpetAffinityState.get_empty_reward_counts()
	for key in next_rewards.keys():
		if rewards.has(key):
			next_rewards[key] = rewards.get(key)
	next_rewards["signature"] = str(rewards.get("signature", next_rewards.get("signature", "")))
	var next_signature := str(next_rewards.get("signature", "0|0|0|0|0|0"))
	if next_signature == affinity_reward_signature:
		return
	affinity_reward_signature = next_signature
	affinity_rewards = next_rewards
	_invalidate_metadata_cache()


func set_affinity_state(level: int, rewards: Dictionary) -> void:
	set_affinity_level(level)
	set_affinity_rewards(rewards)


func set_hatch_stat_roll(mobility_headstart: float, defense_headstart: float) -> void:
	var next_mobility := clampf(mobility_headstart, 0.0, 1.0)
	var next_defense := clampf(defense_headstart, 0.0, 1.0)
	if is_equal_approx(_hatch_mobility_headstart, next_mobility) and is_equal_approx(_hatch_defense_headstart, next_defense):
		return
	_hatch_mobility_headstart = next_mobility
	_hatch_defense_headstart = next_defense
	_invalidate_metadata_cache()


func get_passive_skill() -> Dictionary:
	if passive_skill_id.strip_edges() == "":
		_passive_skill_cache_key = ""
		_passive_skill_cache = {}
		return {}
	var cache_key := _build_passive_skill_cache_key()
	if cache_key != _passive_skill_cache_key:
		_passive_skill_cache_key = cache_key
		_passive_skill_cache = LingpetCatalog.get_passive_skill(pet_id, passive_skill_id, _get_effective_passive_skill_level())
	return _passive_skill_cache


func get_passive_skill_pool() -> Array[Dictionary]:
	return LingpetCatalog.get_passive_skill_pool(pet_id)


func get_effect_text() -> String:
	return LingpetCatalog.get_effect_text(pet_id)


func get_motion_style() -> String:
	return LingpetCatalog.get_motion_style(pet_id)


func get_affinity_motion_style() -> String:
	if _is_patrol_motion_style():
		return LingpetAffinityState.MOTION_STYLE_PATROL
	return LingpetAffinityState.MOTION_STYLE_FLIGHT


func get_skill_id(slot_index: int = 0) -> String:
	var slot := clampi(slot_index, 0, LingpetCatalog.MAX_ACTIVE_SLOT_COUNT - 1)
	if slot < active_skill_ids.size():
		return str(active_skill_ids[slot])
	return ""


func get_active_skill_level_for_slot(slot_index: int = 0) -> int:
	var skill_id := get_skill_id(slot_index)
	if skill_id == "":
		return 0
	return LingpetCatalog.clamp_skill_level(int(active_skill_levels.get(skill_id, LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL)))


func get_active_slot_count() -> int:
	return clampi(active_slot_count, 0, LingpetCatalog.MAX_ACTIVE_SLOT_COUNT)


func is_second_active_unlocked() -> bool:
	return bool(_get_affinity_rewards().get("second_active_unlocked", false))


func get_skill_windup_seconds(fallback: float, slot_index: int = 0) -> float:
	return maxf(0.0, float(get_active_skill(slot_index).get("windup_seconds", fallback)))


func get_gauge_gain_bonus_pct(fallback: float) -> float:
	return get_stat("gauge_gain_bonus_pct", fallback)


func get_player_speed_bonus_pct(fallback: float = 0.0) -> float:
	return maxf(0.0, _get_passive_effect_value("player_speed_bonus_pct", fallback))


func get_hit_gauge_gain(fallback: float) -> float:
	return get_stat("hit_gauge_gain", fallback)


func get_defense_rate(fallback: float) -> float:
	return get_stat("defense_rate", fallback)


func get_appearance_rate(fallback: float) -> float:
	return clampf(get_stat("appearance_rate", fallback), 0.0, 1.0)


func get_hit_half_width(fallback_width: float) -> float:
	return maxf(1.0, get_stat("catch_width", fallback_width) * 0.5)


func get_hit_half_height(fallback_height: float) -> float:
	return maxf(1.0, get_stat("catch_height", fallback_height) * 0.5)


func prewarm_visuals() -> void:
	_visual_texture_cache.prewarm_pet(pet_id)


func prewarm_visual_keys(keys: Array) -> void:
	_visual_texture_cache.prewarm_pet(pet_id, keys)


func prewarm_visual_key_threaded_step(visual_key: String, max_msec: int, max_polls: int) -> bool:
	return bool(_visual_texture_cache.prewarm_pet_key_threaded_step(pet_id, visual_key, max_msec, max_polls))


func get_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _visual_texture_cache.get_texture(pet_id, visual_key, fallback)


func get_cached_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _visual_texture_cache.get_cached_texture(pet_id, visual_key, fallback)


func _apply_default_loadout_if_needed() -> void:
	var defaults := LingpetCatalog.build_default_loadout(pet_id)
	if active_skill_ids.is_empty() and active_slot_count > 0:
		var default_active_id := LingpetCatalog.normalize_active_skill_id(pet_id, str(defaults.get("active_skill_id", "")))
		if default_active_id != "":
			active_skill_ids.append(default_active_id)
	else:
		active_skill_ids = _normalize_active_skill_ids("", active_skill_ids)
	active_slot_count = _normalize_active_slot_count(active_slot_count, active_skill_ids)
	active_skill_levels = _normalize_active_skill_levels(active_skill_ids, active_skill_level, active_skill_levels)
	active_skill_id = active_skill_ids[0] if active_skill_ids.size() > 0 else ""
	active_skill_level = get_active_skill_level_for_slot(0)
	passive_skill_id = LingpetCatalog.normalize_passive_skill_id(pet_id, passive_skill_id)
	if passive_skill_id == "" and active_slot_count > 0:
		passive_skill_id = str(defaults.get("passive_skill_id", ""))
	passive_skill_level = LingpetCatalog.clamp_skill_level(passive_skill_level)


func _get_passive_effect_value(effect_key: String, fallback: float = 0.0) -> float:
	var cache_key := _build_passive_skill_cache_key()
	if cache_key != _passive_effect_cache_key:
		_passive_effect_cache_key = cache_key
		_passive_effect_cache.clear()
	if _passive_effect_cache.has(effect_key):
		return float(_passive_effect_cache.get(effect_key, fallback))
	var passive := get_passive_skill()
	if passive.is_empty():
		_passive_effect_cache[effect_key] = fallback
		return fallback
	var value := LingpetCatalog.get_skill_level_value(passive, effect_key, _get_effective_passive_skill_level(), fallback)
	_passive_effect_cache[effect_key] = value
	return value


func _get_effective_active_skill_level(slot_index: int = 0) -> int:
	var bonus_key := "second_active_skill_bonus" if slot_index == 1 else "active_skill_bonus"
	return LingpetCatalog.clamp_skill_level(get_active_skill_level_for_slot(slot_index) + _get_affinity_reward_count(bonus_key))


func _get_effective_passive_skill_level() -> int:
	return LingpetCatalog.clamp_skill_level(passive_skill_level + _get_affinity_reward_count("passive_skill_bonus"))


func _get_affinity_reward_count(key: String) -> int:
	return int(_get_affinity_rewards().get(key, 0))


func _get_affinity_rewards() -> Dictionary:
	return affinity_rewards


func _is_patrol_motion_style() -> bool:
	return get_motion_style() == "patrol"


func _is_flight_motion_style() -> bool:
	return not _is_patrol_motion_style()


func _invalidate_metadata_cache() -> void:
	_active_skill_cache_key = ""
	_active_skill_cache.clear()
	_active_skill_cache_keys.clear()
	_active_skill_caches.clear()
	_passive_skill_cache_key = ""
	_passive_skill_cache.clear()
	_passive_effect_cache_key = ""
	_passive_effect_cache.clear()


func _build_active_skill_cache_key(slot_index: int = 0) -> String:
	return "%s|%d|%s|%d|%s|%d|%s" % [
		pet_id,
		slot_index,
		get_skill_id(slot_index),
		get_active_skill_level_for_slot(slot_index),
		passive_skill_id,
		passive_skill_level,
		affinity_reward_signature,
	]


func _normalize_active_skill_ids(primary_active_id: String, raw_ids: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	_append_normalized_active_skill_id(ids, primary_active_id)
	for raw_id in raw_ids:
		_append_normalized_active_skill_id(ids, raw_id)
	if ids.size() > LingpetCatalog.MAX_ACTIVE_SLOT_COUNT:
		ids.resize(LingpetCatalog.MAX_ACTIVE_SLOT_COUNT)
	return ids


func _append_normalized_active_skill_id(ids: Array[String], skill_id: String) -> void:
	var normalized := LingpetCatalog.normalize_active_skill_id(pet_id, skill_id)
	if normalized == "" or ids.has(normalized):
		return
	ids.append(normalized)


func _normalize_active_skill_levels(ids: Array[String], primary_level: int, raw_levels: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	for index in range(ids.size()):
		var skill_id := str(ids[index])
		var fallback_level := primary_level if index == 0 else LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL
		levels[skill_id] = LingpetCatalog.clamp_skill_level(int(raw_levels.get(skill_id, fallback_level)))
	return levels


func _normalize_active_slot_count(raw_count: int, ids: Array[String]) -> int:
	if ids.is_empty() and raw_count <= 0:
		return 0
	var count := clampi(raw_count, LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT, LingpetCatalog.MAX_ACTIVE_SLOT_COUNT)
	if ids.size() > count:
		count = ids.size()
	return clampi(count, LingpetCatalog.DEFAULT_ACTIVE_SLOT_COUNT, LingpetCatalog.MAX_ACTIVE_SLOT_COUNT)


func _build_passive_skill_cache_key() -> String:
	return "%s|%s|%d|%s" % [
		pet_id,
		passive_skill_id,
		passive_skill_level,
		affinity_reward_signature,
	]
