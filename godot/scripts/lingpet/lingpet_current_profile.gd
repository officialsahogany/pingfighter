extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetVisualTextureCache := preload("res://scripts/lingpet/lingpet_visual_texture_cache.gd")

const DEFAULT_PET_ID := LingpetCatalog.DEFAULT_PET_ID

var pet_id := DEFAULT_PET_ID
var active_skill_id := ""
var passive_skill_id := ""
var active_skill_level := LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL
var passive_skill_level := LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
var _visual_texture_cache: Object = LingpetVisualTextureCache.new()
var _active_skill_cache_key := ""
var _active_skill_cache: Dictionary = {}
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
			return base_value * (1.0 + _get_passive_effect_value("patrol_speed_bonus_pct") / 100.0)
		"catch_width":
			return base_value * (1.0 + (_get_passive_effect_value("catch_size_bonus_pct") + _get_passive_effect_value("catch_width_bonus_pct")) / 100.0)
		"catch_height":
			return base_value * (1.0 + (_get_passive_effect_value("catch_size_bonus_pct") + _get_passive_effect_value("catch_height_bonus_pct")) / 100.0)
		"defense_rate":
			return clampf(base_value + _get_passive_effect_value("defense_rate_bonus"), 0.0, 1.0)
		"hit_gauge_gain":
			return maxf(0.0, base_value + _get_passive_effect_value("hit_gauge_gain_bonus"))
		"gauge_gain_bonus_pct":
			if passive_skill_id.strip_edges() != "":
				return maxf(0.0, _get_passive_effect_value("gauge_gain_bonus_pct"))
			return maxf(0.0, base_value)
	return base_value


func get_visual_layout_value(layout_key: String, fallback: float) -> float:
	return LingpetCatalog.get_visual_layout_value(pet_id, layout_key, fallback)


func get_active_skill() -> Dictionary:
	var cache_key := _build_active_skill_cache_key()
	if cache_key == _active_skill_cache_key:
		return _active_skill_cache
	var skill := LingpetCatalog.get_active_skill(pet_id, active_skill_id, active_skill_level)
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
	_active_skill_cache_key = cache_key
	_active_skill_cache = skill
	return _active_skill_cache


func get_active_skill_pool() -> Array[Dictionary]:
	return LingpetCatalog.get_active_skill_pool(pet_id)


func set_loadout(
	active_id: String,
	passive_id: String,
	active_level: int = LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL,
	passive_level: int = LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL
) -> void:
	active_skill_id = LingpetCatalog.normalize_active_skill_id(pet_id, active_id)
	passive_skill_id = LingpetCatalog.normalize_passive_skill_id(pet_id, passive_id)
	active_skill_level = LingpetCatalog.clamp_skill_level(active_level)
	passive_skill_level = LingpetCatalog.clamp_skill_level(passive_level)
	_apply_default_loadout_if_needed()
	_invalidate_metadata_cache()


func get_passive_skill() -> Dictionary:
	var cache_key := _build_passive_skill_cache_key()
	if cache_key != _passive_skill_cache_key:
		_passive_skill_cache_key = cache_key
		_passive_skill_cache = LingpetCatalog.get_passive_skill(pet_id, passive_skill_id, passive_skill_level)
	return _passive_skill_cache


func get_passive_skill_pool() -> Array[Dictionary]:
	return LingpetCatalog.get_passive_skill_pool(pet_id)


func get_effect_text() -> String:
	return LingpetCatalog.get_effect_text(pet_id)


func get_motion_style() -> String:
	return LingpetCatalog.get_motion_style(pet_id)


func get_skill_id() -> String:
	return str(get_active_skill().get("id", ""))


func get_skill_windup_seconds(fallback: float) -> float:
	return maxf(0.0, float(get_active_skill().get("windup_seconds", fallback)))


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
	active_skill_id = LingpetCatalog.normalize_active_skill_id(pet_id, active_skill_id)
	if active_skill_id == "":
		active_skill_id = str(defaults.get("active_skill_id", ""))
	active_skill_level = LingpetCatalog.clamp_skill_level(active_skill_level)
	passive_skill_id = LingpetCatalog.normalize_passive_skill_id(pet_id, passive_skill_id)
	if passive_skill_id == "":
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
	var value := LingpetCatalog.get_skill_level_value(passive, effect_key, passive_skill_level, fallback)
	_passive_effect_cache[effect_key] = value
	return value


func _invalidate_metadata_cache() -> void:
	_active_skill_cache_key = ""
	_active_skill_cache.clear()
	_passive_skill_cache_key = ""
	_passive_skill_cache.clear()
	_passive_effect_cache_key = ""
	_passive_effect_cache.clear()


func _build_active_skill_cache_key() -> String:
	return "%s|%s|%d|%s|%d" % [
		pet_id,
		active_skill_id,
		active_skill_level,
		passive_skill_id,
		passive_skill_level,
	]


func _build_passive_skill_cache_key() -> String:
	return "%s|%s|%d" % [
		pet_id,
		passive_skill_id,
		passive_skill_level,
	]
