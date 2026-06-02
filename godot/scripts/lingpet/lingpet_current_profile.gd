extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetVisualTextureCache := preload("res://scripts/lingpet/lingpet_visual_texture_cache.gd")

const DEFAULT_PET_ID := LingpetCatalog.DEFAULT_PET_ID

var pet_id := DEFAULT_PET_ID
var active_skill_id := ""
var passive_skill_id := ""
var _visual_texture_cache: Object = LingpetVisualTextureCache.new()


func set_pet_id(value: String, fallback: String = DEFAULT_PET_ID) -> String:
	var normalized := normalize_pet_id(value)
	if normalized == "":
		normalized = normalize_pet_id(fallback)
	if normalized == "":
		normalized = DEFAULT_PET_ID
	pet_id = normalized
	_apply_default_loadout_if_needed()
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
	return LingpetCatalog.get_stat(pet_id, stat_name, fallback)


func get_visual_layout_value(layout_key: String, fallback: float) -> float:
	return LingpetCatalog.get_visual_layout_value(pet_id, layout_key, fallback)


func get_active_skill() -> Dictionary:
	return LingpetCatalog.get_active_skill(pet_id, active_skill_id)


func get_active_skill_pool() -> Array[Dictionary]:
	return LingpetCatalog.get_active_skill_pool(pet_id)


func set_loadout(active_id: String, passive_id: String) -> void:
	active_skill_id = LingpetCatalog.normalize_active_skill_id(pet_id, active_id)
	passive_skill_id = LingpetCatalog.normalize_passive_skill_id(pet_id, passive_id)
	_apply_default_loadout_if_needed()


func get_passive_skill() -> Dictionary:
	return LingpetCatalog.get_passive_skill(pet_id, passive_skill_id)


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
	var passive := get_passive_skill()
	if passive.has("gauge_gain_bonus_pct"):
		return float(passive.get("gauge_gain_bonus_pct", fallback))
	return get_stat("gauge_gain_bonus_pct", fallback)


func get_hit_gauge_gain(fallback: float) -> float:
	return get_stat("hit_gauge_gain", fallback)


func get_defense_rate(fallback: float) -> float:
	return get_stat("defense_rate", fallback)


func get_hit_half_width(fallback_width: float) -> float:
	return maxf(1.0, get_stat("catch_width", fallback_width) * 0.5)


func get_hit_half_height(fallback_height: float) -> float:
	return maxf(1.0, get_stat("catch_height", fallback_height) * 0.5)


func prewarm_visuals() -> void:
	_visual_texture_cache.prewarm_pet(pet_id)


func prewarm_visual_keys(keys: Array) -> void:
	_visual_texture_cache.prewarm_pet(pet_id, keys)


func get_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _visual_texture_cache.get_texture(pet_id, visual_key, fallback)


func _apply_default_loadout_if_needed() -> void:
	var defaults := LingpetCatalog.build_default_loadout(pet_id)
	active_skill_id = LingpetCatalog.normalize_active_skill_id(pet_id, active_skill_id)
	if active_skill_id == "":
		active_skill_id = str(defaults.get("active_skill_id", ""))
	passive_skill_id = LingpetCatalog.normalize_passive_skill_id(pet_id, passive_skill_id)
	if passive_skill_id == "":
		passive_skill_id = str(defaults.get("passive_skill_id", ""))
