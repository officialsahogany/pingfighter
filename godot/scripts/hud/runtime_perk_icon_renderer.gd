extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

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
}

const DRAW_SCALE := {
	"dash_module_control": 1.08,
	"dash_lightweight": 1.07,
	"perk_boost_charge": 1.07,
	"dash_spirit": 1.06,
	"jetpack_enhance": 1.06,
	"kick_enhance": 1.06,
	"blade_amp": 1.06,
	"four_poisons": 1.06,
}

var _texture_cache: Dictionary = {}
var _sheet_cache: Dictionary = {}


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


func _get_icon_source(skill_id: String) -> Dictionary:
	var sheet_path: String = str(PERK_SHEET_PATHS.get(skill_id, ""))
	if sheet_path != "":
		var sheet_texture: Texture2D = _get_sheet_texture(sheet_path)
		if sheet_texture != null:
			return {
				"texture": sheet_texture,
				"region": _get_sheet_region(sheet_texture),
			}

	var path: String = _get_static_path(skill_id)
	if path == "":
		return {}
	var texture: Texture2D = _get_texture(path)
	if texture == null:
		return {}
	return {"texture": texture, "region": Rect2()}


func _get_static_path(skill_id: String) -> String:
	if PERK_ICON_PATHS.has(skill_id):
		return str(PERK_ICON_PATHS[skill_id])
	var resolved_id: String = str(UNLOCK_ALIASES.get(skill_id, skill_id))
	if SKILL_ICON_PATHS.has(resolved_id):
		return str(SKILL_ICON_PATHS[resolved_id])
	return ""


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
	var frame_size: int = max(1, texture.get_height())
	var frame_count: int = max(1, int(floor(float(texture.get_width()) / float(frame_size))))
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
	return skill_id.begins_with("unlock_")


func _draw_unlock_badge(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var radius: float = max(6.0, min(rect.size.x, rect.size.y) * 0.17)
	var center: Vector2 = rect.end - Vector2(radius * 0.9, radius * 0.9)
	canvas.draw_circle(center, radius + 1.5, Color(4.0 / 255.0, 12.0 / 255.0, 18.0 / 255.0, 0.92 * alpha))
	canvas.draw_circle(center, radius, Color(0.0, 215.0 / 255.0, 1.0, 0.95 * alpha))
	canvas.draw_line(center + Vector2(-radius * 0.45, 0.0), center + Vector2(radius * 0.45, 0.0), Color.WHITE, 2.0)
	canvas.draw_line(center + Vector2(0.0, -radius * 0.45), center + Vector2(0.0, radius * 0.45), Color.WHITE, 2.0)
