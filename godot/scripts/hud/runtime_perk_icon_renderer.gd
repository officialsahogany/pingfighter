extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")

const PERK_ICON_PATHS := {
	"dash_lightweight": "res://assets/sprites/perks/dash_lightweight_perk_icon.png",
	"dash_module_control": "res://assets/sprites/perks/dash_module_control_perk_icon.png",
	"dash_jump": "res://assets/sprites/perks/dash_jump_perk_icon.png",
	"dash_amplification": "res://assets/sprites/perks/dash_amplification_perk_icon.png",
	"dash_acceleration": "res://assets/sprites/perks/dash_acceleration_perk_icon.png",
	"item_luck": "res://assets/sprites/perks/item_luck_perk_icon.png",
	"item_cooldown_mastery": "res://assets/sprites/perks/item_cooldown_mastery_perk_icon.png",
	"item_gauge_mastery": "res://assets/sprites/perks/item_gauge_mastery_perk_icon.png",
	"item_bag_expansion": "res://assets/sprites/perks/item_bag_expansion_perk_icon.png",
	"item_caffeine": "res://assets/sprites/perks/item_caffeine_perk_icon.png",
	"item_polish": "res://assets/sprites/perks/item_polish_perk_icon.png",
	"item_recycle": "res://assets/sprites/perks/item_recycle_perk_icon.png",
	"common_swiftness": "res://assets/sprites/perks/common_swiftness_perk_icon.png",
	"common_expansion": "res://assets/sprites/perks/common_expansion_perk_icon.png",
	"common_bulk_up": "res://assets/sprites/perks/common_bulk_up_perk_icon.png",
	"common_training": "res://assets/sprites/perks/common_training_perk_icon.png",
	"common_refresh": "res://assets/sprites/perks/common_refresh_perk_icon.png",
	"perk_boost_charge": "res://assets/sprites/perks/perk_boost_charge_perk_icon_v2.png",
	"perk_laurel_shield": "res://assets/sprites/perks/perk_laurel_shield_perk_icon.png",
	"downtown_treasure_map": "res://assets/sprites/perks/downtown_treasure_map_perk_icon.png",
	"downtown_gamble": "res://assets/sprites/perks/downtown_gamble_perk_icon.png",
	"downtown_bargain": "res://assets/sprites/perks/downtown_bargain_perk_icon.png",
	"convert_to_gold": "res://assets/sprites/perks/convert_to_gold_perk_icon.png",
	"instant_gauge_full": "res://assets/sprites/perks/instant_gauge_full_perk_icon.png",
	"instant_dimension_gate": "res://assets/sprites/perks/instant_dimension_gate_perk_icon.png",
	"instant_treasure_hunt": "res://assets/sprites/perks/instant_treasure_hunt_perk_icon.png",
	"instant_monkey_blessing": "res://assets/sprites/perks/instant_monkey_blessing_perk_icon.png",
	"lingpet_affinity_chip": "res://assets/sprites/perks/lingpet_affinity_chip_perk_icon.png",
	"lingpet_ring_core_upgrade": "res://assets/sprites/perks/lingpet_ring_core_standard_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_1": "res://assets/sprites/perks/lingpet_ring_core_standard_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_2": "res://assets/sprites/perks/lingpet_ring_core_boost_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_3": "res://assets/sprites/perks/lingpet_ring_core_hyper_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_4": "res://assets/sprites/perks/lingpet_ring_core_overdrive_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_5": "res://assets/sprites/perks/lingpet_ring_core_ultimate_perk_icon.png",
	"lingpet_ring_core_upgrade_tier_6": "res://assets/sprites/perks/lingpet_ring_core_zenith_perk_icon.png",
	"dash_spirit": "res://assets/sprites/perks/smasher_dash_spirit_perk_icon.png",
	"extension_gear": "res://assets/sprites/perks/smasher_extension_gear_perk_icon.png",
	"combo_amplifier_chip": "res://assets/sprites/perks/smasher_combo_amplifier_chip_perk_icon.png",
	"jetpack_enhance": "res://assets/sprites/perks/viper_jetpack_enhance_perk_icon.png",
	"kick_enhance": "res://assets/sprites/perks/viper_kick_enhance_perk_icon.png",
	"blade_amp": "res://assets/sprites/perks/viper_blade_amp_perk_icon.png",
	"four_poisons": "res://assets/sprites/perks/viper_four_poisons_perk_icon.png",
}

const PERK_SHEET_PATHS := {
	"common_refresh": "res://assets/sprites/perks/common_refresh_perk_icon_sheet.png",
	"instant_gauge_full": "res://assets/sprites/perks/instant_gauge_full_perk_icon_sheet.png",
	"instant_dimension_gate": "res://assets/sprites/perks/instant_dimension_gate_perk_icon_sheet.png",
	"instant_treasure_hunt": "res://assets/sprites/perks/instant_treasure_hunt_perk_icon_sheet.png",
	"instant_monkey_blessing": "res://assets/sprites/perks/instant_monkey_blessing_perk_icon_sheet.png",
}

const SKILL_ICON_PATHS := {
	"drive": "res://assets/sprites/skills/smasher_drive_skill_orb.png",
	"power_smashing": "res://assets/sprites/skills/smasher_power_smashing_skill_orb.png",
	"plasma": "res://assets/sprites/skills/smasher_plasma_skill_orb.png",
	"recovery": "res://assets/sprites/skills/smasher_recovery_skill_orb.png",
	"cleanse": "res://assets/sprites/skills/smasher_cleanse_skill_orb.png",
	"shield_kiting": "res://assets/sprites/skills/smasher_shield_kiting_skill_orb.png",
	"magnum_grip": "res://assets/sprites/skills/smasher_magnum_grip_skill_orb.png",
	"ghost_shot": "res://assets/sprites/skills/smasher_ghost_shot_skill_orb.png",
	"warp_gate": "res://assets/sprites/skills/smasher_warp_gate_skill_orb.png",
	"smasher_wheel": "res://assets/sprites/skills/smasher_wheel_skill_orb.png",
	"shadow_step": "res://assets/sprites/skills/viper_shadow_step_skill_orb.png",
	"blade_rush": "res://assets/sprites/skills/viper_blade_rush_skill_orb.png",
	"nerve_strike": "res://assets/sprites/skills/viper_nerve_strike_skill_orb.png",
	"dive_strike": "res://assets/sprites/skills/viper_emp_strike_skill_orb.png",
	"marshal_kick": "res://assets/sprites/skills/viper_marshal_kick_skill_orb.png",
	"phantom_kick": "res://assets/sprites/skills/viper_phantom_kick_skill_orb.png",
	"dark_blade": "res://assets/sprites/skills/viper_dark_blade_skill_orb.png",
	"chaos_spear": "res://assets/sprites/skills/viper_chaos_spear_skill_orb.png",
	"core_flip": "res://assets/sprites/skills/viper_core_flip_skill_orb.png",
	"dual_glitch": "res://assets/sprites/skills/viper_dual_glitch_skill_orb.png",
	"ignition_aura": "res://assets/sprites/skills/viper_ignition_aura_skill_orb.png",
	"supply_drop": "res://assets/sprites/skills/commando_supply_drop_skill_orb.png",
	"emergency_supply": "res://assets/sprites/skills/commando_emergency_supply_skill_orb.png",
	"commando_pistol": "res://assets/sprites/skills/commando_pistol_skill_orb.png",
	"net_gun": "res://assets/sprites/skills/commando_net_gun_skill_orb.png",
	"fire_support": "res://assets/sprites/skills/commando_fire_support_skill_orb.png",
	"bowling_trap": "res://assets/sprites/skills/commando_bowling_trap_skill_orb.png",
	"suicide_drone": "res://assets/sprites/skills/commando_suicide_drone_skill_orb.png",
	"bazooka": "res://assets/sprites/skills/commando_bazooka_skill_orb.png",
	"ak47": "res://assets/sprites/skills/commando_ak47_skill_orb.png",
}

const UNLOCK_ALIASES := {
	"unlock_plasma": "plasma",
	"unlock_recovery_skill": "recovery",
	"unlock_cleanse": "cleanse",
	"unlock_shield_kiting": "shield_kiting",
	"unlock_magnum_grip": "magnum_grip",
	"unlock_ghost_shot": "ghost_shot",
	"unlock_warp_gate": "warp_gate",
	"unlock_smasher_wheel": "smasher_wheel",
	"unlock_nerve_strike": "nerve_strike",
	"unlock_dive_strike": "dive_strike",
	"unlock_chaos_spear": "chaos_spear",
	"unlock_dual_glitch": "dual_glitch",
	"unlock_ignition_aura": "ignition_aura",
	"double_marshal_kick": "phantom_kick",
	"soldier_unlock_net_gun": "net_gun",
	"soldier_unlock_fire_support": "fire_support",
	"soldier_unlock_bowling_trap": "bowling_trap",
	"soldier_unlock_suicide_drone": "suicide_drone",
	"soldier_unlock_bazooka": "bazooka",
	"soldier_unlock_ak47": "ak47",
	"soldier_pistol_perk": "commando_pistol",
}

const COMMANDO_UNLOCK_BADGE_IDS := {
	"soldier_unlock_net_gun": true,
	"soldier_unlock_fire_support": true,
	"soldier_unlock_bowling_trap": true,
	"soldier_unlock_suicide_drone": true,
	"soldier_unlock_bazooka": true,
	"soldier_unlock_ak47": true,
	"soldier_pistol_perk": true,
}

const DRAW_SCALE := {
	"dash_module_control": 1.08,
	"dash_lightweight": 1.07,
	"dash_acceleration": 1.08,
	"perk_boost_charge": 1.07,
	"perk_laurel_shield": 1.06,
	"dash_spirit": 1.06,
	"jetpack_enhance": 1.06,
	"kick_enhance": 1.06,
	"blade_amp": 1.06,
	"four_poisons": 1.06,
}

const PREWARM_ASSET_BATCH_SIZE := 1

var _texture_cache: Dictionary = {}
var _sheet_cache: Dictionary = {}
var _static_source_cache: Dictionary = {}
var _sheet_region_cache: Dictionary = {}
var _prewarm_asset_jobs: Array = []
var _prewarm_asset_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step(256):
		pass


func prewarm_assets_step(batch_size: int = PREWARM_ASSET_BATCH_SIZE) -> bool:
	if _prewarm_asset_jobs.is_empty():
		_prewarm_asset_jobs = _build_prewarm_asset_jobs()
		_prewarm_asset_index = 0
	var remaining: int = max(1, batch_size)
	while _prewarm_asset_index < _prewarm_asset_jobs.size() and remaining > 0:
		_run_prewarm_asset_job(_prewarm_asset_jobs[_prewarm_asset_index])
		_prewarm_asset_index += 1
		remaining -= 1
	if _prewarm_asset_index >= _prewarm_asset_jobs.size():
		_prewarm_asset_jobs.clear()
		_prewarm_asset_index = 0
		return true
	return false


func draw_icon(canvas: CanvasItem, skill_id: String, rect: Rect2, alpha: float = 1.0, active: bool = true) -> bool:
	if canvas == null or skill_id == "":
		return false
	var source: Dictionary = _get_icon_source(skill_id)
	var texture: Texture2D = source.get("texture", null)
	if texture == null:
		return false

	var draw_rect: Rect2 = _get_draw_rect(rect, skill_id, texture)
	var modulate := Color(1.0, 1.0, 1.0, alpha) if active else Color(0.48, 0.48, 0.48, 0.78 * alpha)
	var region: Rect2 = source.get("region", Rect2())
	if region.size.x > 0.0 and region.size.y > 0.0:
		canvas.draw_texture_rect_region(texture, draw_rect, region, modulate)
	else:
		canvas.draw_texture_rect(texture, draw_rect, false, modulate)

	if _needs_unlock_badge(skill_id):
		_draw_unlock_badge(canvas, rect, alpha)
	return true


func has_icon(skill_id: String) -> bool:
	return _get_icon_source(skill_id).get("texture", null) != null


func covered_ids() -> Array:
	var ids: Array = []
	for key in PERK_ICON_PATHS.keys():
		ids.append(str(key))
	for key in SKILL_ICON_PATHS.keys():
		ids.append(str(key))
	for key in UNLOCK_ALIASES.keys():
		ids.append(str(key))
	return ids


func _build_prewarm_asset_jobs() -> Array:
	var jobs: Array = []
	for key in PERK_ICON_PATHS.keys():
		jobs.append({"type": "texture", "path": str(PERK_ICON_PATHS[key])})
	for key in SKILL_ICON_PATHS.keys():
		jobs.append({"type": "texture", "path": str(SKILL_ICON_PATHS[key])})
	for key in PERK_SHEET_PATHS.keys():
		jobs.append({"type": "sheet", "path": str(PERK_SHEET_PATHS[key])})
	for skill_id in covered_ids():
		jobs.append({"type": "source", "id": str(skill_id)})
	return jobs


func _run_prewarm_asset_job(job_value: Variant) -> void:
	if not (job_value is Dictionary):
		return
	var job: Dictionary = job_value
	match str(job.get("type", "")):
		"texture":
			_touch_texture(_get_texture(str(job.get("path", ""))))
		"sheet":
			_touch_texture(_get_sheet_texture(str(job.get("path", ""))))
		"source":
			var source: Dictionary = _get_icon_source(str(job.get("id", "")))
			_touch_texture(source.get("texture", null))


func _get_icon_source(skill_id: String) -> Dictionary:
	var sheet_path: String = str(PERK_SHEET_PATHS.get(skill_id, ""))
	if sheet_path != "":
		var sheet_texture: Texture2D = _get_sheet_texture(sheet_path)
		if sheet_texture != null:
			return {
				"texture": sheet_texture,
				"region": _get_sheet_region(sheet_texture),
			}

	if _static_source_cache.has(skill_id):
		var cached_source: Variant = _static_source_cache[skill_id]
		if cached_source is Dictionary:
			return cached_source
		_static_source_cache.erase(skill_id)

	var path: String = _get_static_path(skill_id)
	if path == "":
		return {}
	var texture: Texture2D = _get_texture(path)
	if texture == null:
		return {}
	texture = SkillOrbTextureNormalizer.normalize(_resolve_skill_icon_id(skill_id), texture)
	var source := {"texture": texture, "region": Rect2()}
	_static_source_cache[skill_id] = source
	return source


func _get_static_path(skill_id: String) -> String:
	if PERK_ICON_PATHS.has(skill_id):
		return str(PERK_ICON_PATHS[skill_id])
	var resolved_id: String = _resolve_skill_icon_id(skill_id)
	if SKILL_ICON_PATHS.has(resolved_id):
		return str(SKILL_ICON_PATHS[resolved_id])
	return ""


func _resolve_skill_icon_id(skill_id: String) -> String:
	return str(UNLOCK_ALIASES.get(skill_id, skill_id))


func _get_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = ProjectResourceLoader.load_texture(
		path,
		"Missing runtime perk icon at %s",
		"Failed to load runtime perk icon at %s"
	)
	_texture_cache[path] = texture
	return texture


func _get_sheet_texture(path: String) -> Texture2D:
	if _sheet_cache.has(path):
		return _sheet_cache[path]
	var texture: Texture2D = ProjectResourceLoader.load_texture(
		path,
		"Missing runtime perk icon sheet at %s",
		"Failed to load runtime perk icon sheet at %s"
	)
	_sheet_cache[path] = texture
	return texture


func _get_sheet_region(texture: Texture2D) -> Rect2:
	var cache_key: String = str(texture.get_rid().get_id())
	var region_data: Dictionary = {}
	if _sheet_region_cache.has(cache_key):
		var cached_region_data: Variant = _sheet_region_cache[cache_key]
		if cached_region_data is Dictionary:
			region_data = cached_region_data
	if region_data.is_empty():
		var frame_size_new: int = max(1, texture.get_height())
		var frame_count_new: int = max(1, int(floor(float(texture.get_width()) / float(frame_size_new))))
		region_data = {
			"frame_size": frame_size_new,
			"frame_count": frame_count_new,
		}
		_sheet_region_cache[cache_key] = region_data
	var frame_size: int = int(region_data.get("frame_size", max(1, texture.get_height())))
	var frame_count: int = int(region_data.get("frame_count", 1))
	var frame_index: int = int(floor(float(Time.get_ticks_msec()) / 110.0)) % frame_count
	return Rect2(Vector2(float(frame_index * frame_size), 0.0), Vector2(float(frame_size), float(frame_size)))


func _get_draw_rect(rect: Rect2, skill_id: String, texture: Texture2D) -> Rect2:
	var scale: float = float(DRAW_SCALE.get(skill_id, 1.0))
	if UNLOCK_ALIASES.has(skill_id):
		scale = min(scale, 0.98)
	var size: Vector2 = rect.size * scale
	var source_w: float = max(1.0, float(texture.get_width()))
	var source_h: float = max(1.0, float(texture.get_height()))
	if source_w > source_h * 1.5:
		source_w = source_h
	var aspect: float = source_w / source_h
	if aspect > 1.0:
		size.y = size.x / aspect
	else:
		size.x = size.y * aspect
	return Rect2(rect.get_center() - size * 0.5, size)


func _needs_unlock_badge(skill_id: String) -> bool:
	return skill_id.begins_with("unlock_") or bool(COMMANDO_UNLOCK_BADGE_IDS.get(skill_id, false))


func _draw_unlock_badge(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var radius: float = max(6.0, min(rect.size.x, rect.size.y) * 0.17)
	var center: Vector2 = rect.end - Vector2(radius * 0.9, radius * 0.9)
	canvas.draw_circle(center, radius + 1.5, Color(4.0 / 255.0, 12.0 / 255.0, 18.0 / 255.0, 0.92 * alpha))
	canvas.draw_circle(center, radius, Color(0.0, 215.0 / 255.0, 1.0, 0.95 * alpha))
	canvas.draw_line(center + Vector2(-radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), Color.WHITE, 2.0)
	canvas.draw_line(center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), Color.WHITE, 2.0)


func _touch_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	texture.get_width()
	texture.get_height()
