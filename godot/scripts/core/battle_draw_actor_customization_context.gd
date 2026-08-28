extends RefCounted

## Owns player customization overlay texture and slot projection. It returns
## the same two deep-copied dictionaries the actor context already consumed,
## without adding a wrapper payload on the draw path.

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkVisualPartCatalog := preload("res://scripts/characters/runtime_perk_visual_part_catalog.gd")


func get_overlay_textures(context: Dictionary, textures: Dictionary) -> Dictionary:
	var overlay_textures: Dictionary = _get_dict(context.get("player_customization_overlay_textures", {})).duplicate(true)
	var debug_paddle_sheet: Variant = textures.get("smasher_debug_paddle_overlay_sheet", null)
	if debug_paddle_sheet is Texture2D and not overlay_textures.has("smasher_debug_paddle_overlay_sheet"):
		overlay_textures["smasher_debug_paddle_overlay_sheet"] = debug_paddle_sheet
	for part_texture_key in RuntimePerkVisualPartCatalog.texture_keys():
		var part_sheet: Variant = textures.get(part_texture_key, null)
		if part_sheet is Texture2D and not overlay_textures.has(part_texture_key):
			overlay_textures[part_texture_key] = part_sheet
	for optimus_key in [
		"optimus_overlay_paddle",
		"optimus_overlay_core_glow",
		"optimus_overlay_back",
		"optimus_overlay_accessory",
		"optimus_overlay_outfit_accent",
	]:
		var sheet: Variant = textures.get(optimus_key, null)
		if sheet is Texture2D and not overlay_textures.has(optimus_key):
			overlay_textures[optimus_key] = sheet
	return overlay_textures


func get_overlay_slots(
	context: Dictionary,
	overlay_textures: Dictionary,
	character_type: String
) -> Dictionary:
	var overlay_slots: Dictionary = _get_dict(context.get("player_customization_overlay_slots", {})).duplicate(true)
	if character_type == PlayerCharacterRuntime.OPTIMUS:
		_inject_optimus_default_overlay_slots(overlay_slots, overlay_textures)
	RuntimePerkVisualPartCatalog.inject_overlay_slots(
		overlay_slots,
		overlay_textures,
		_get_dict(context.get("player_perk_visual_part_levels", {}))
	)
	if not bool(context.get("player_customization_debug_overlay_enabled", false)):
		return overlay_slots
	if character_type != PlayerCharacterRuntime.SMASHER:
		return overlay_slots
	if overlay_slots.has("paddle"):
		return overlay_slots
	if not (overlay_textures.get("smasher_debug_paddle_overlay_sheet", null) is Texture2D):
		return overlay_slots
	overlay_slots["paddle"] = _build_smasher_debug_paddle_overlay_slot()
	return overlay_slots


func _inject_optimus_default_overlay_slots(overlay_slots: Dictionary, overlay_textures: Dictionary) -> void:
	if overlay_textures.get("optimus_overlay_paddle", null) is Texture2D and not overlay_slots.has("paddle"):
		overlay_slots["paddle"] = _optimus_overlay_slot_spec("optimus_overlay_paddle", {"scale_from_player_paddle": true})
	if overlay_textures.get("optimus_overlay_core_glow", null) is Texture2D and not overlay_slots.has("core_glow"):
		overlay_slots["core_glow"] = _optimus_overlay_slot_spec("optimus_overlay_core_glow", {"alpha_from_energy_ratio": true})
	if overlay_textures.get("optimus_overlay_back", null) is Texture2D and not overlay_slots.has("back"):
		overlay_slots["back"] = _optimus_overlay_slot_spec("optimus_overlay_back", {})
	if overlay_textures.get("optimus_overlay_accessory", null) is Texture2D and not overlay_slots.has("accessory"):
		overlay_slots["accessory"] = _optimus_overlay_slot_spec("optimus_overlay_accessory", {})
	if overlay_textures.get("optimus_overlay_outfit_accent", null) is Texture2D and not overlay_slots.has("outfit_accent"):
		overlay_slots["outfit_accent"] = _optimus_overlay_slot_spec("optimus_overlay_outfit_accent", {})


func _optimus_overlay_slot_spec(texture_key: String, extras: Dictionary) -> Dictionary:
	var spec: Dictionary = {
		"texture_key": texture_key,
		"mirror_policy": "mirror_ok",
		"grid_cols": 4,
		"grid_rows": 2,
		"frame_count": 8,
		"cell_width": 160.0,
		"cell_height": 160.0,
		"motions": _optimus_overlay_motion_specs(),
	}
	for key in extras.keys():
		spec[key] = extras[key]
	return spec


func _optimus_overlay_motion_specs() -> Dictionary:
	return {
		"idle": {
			"directions": {
				"back": {},
			},
		},
		"walk": {
			"directions": {
				"right": {},
			},
		},
		"dash": {
			"directions": {
				"right": {},
			},
		},
		"attack": {
			"directions": {
				"right": {},
			},
		},
	}


func _build_smasher_debug_paddle_overlay_slot() -> Dictionary:
	var right_spec: Dictionary = _smasher_debug_paddle_overlay_direction_spec()
	return {
		"mirror_policy": "mirror_ok",
		"motions": {
			"idle": {
				"directions": {
					"back": right_spec,
				},
			},
			"walk": {
				"directions": {
					"right": right_spec,
				},
			},
			"dash": {
				"directions": {
					"right": right_spec,
				},
			},
			"attack": {
				"directions": {
					"right": right_spec,
				},
			},
		},
	}


func _smasher_debug_paddle_overlay_direction_spec() -> Dictionary:
	return {
		"texture_key": "smasher_debug_paddle_overlay_sheet",
		"grid_cols": 4,
		"grid_rows": 2,
		"frame_count": 8,
		"cell_width": 160.0,
		"cell_height": 160.0,
	}


func _get_dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
