extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func normalize_weapon_id(weapon_id: String) -> String:
	return weapon_id.strip_edges().to_lower()


static func get_weapon_profile(
	weapon_id: String,
	weapon_profiles: Dictionary,
	overrides_by_id: Dictionary = {}
) -> Dictionary:
	return get_profile(weapon_profiles, weapon_id, "pistol", overrides_by_id)


static func get_hit_feedback_profile(
	weapon_id: String,
	hit_feedback_profiles: Dictionary,
	overrides_by_id: Dictionary = {}
) -> Dictionary:
	return get_profile(hit_feedback_profiles, weapon_id, "pistol", overrides_by_id)


static func get_hit_result_profile(
	weapon_id: String,
	hit_result_profiles: Dictionary,
	overrides_by_id: Dictionary = {}
) -> Dictionary:
	return get_profile(hit_result_profiles, weapon_id, "pistol", overrides_by_id)


static func get_lingering_effect_profile(weapon_id: String, lingering_effect_profiles: Dictionary) -> Dictionary:
	var id: String = normalize_weapon_id(weapon_id)
	var value: Variant = lingering_effect_profiles.get(id, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func build_ak47_fire_profile(
	weapon_profiles: Dictionary,
	overrides_by_id: Dictionary,
	recoil_accumulation: float,
	base_spread_radians: float
) -> Dictionary:
	var profile: Dictionary = get_weapon_profile(
		"ak47",
		weapon_profiles,
		overrides_by_id
	)
	var spread: float = base_spread_radians + recoil_accumulation
	profile["angle_offset"] = randf_range(-spread, spread)
	profile["recoil_accumulation"] = recoil_accumulation
	return profile


static func build_spawn_profile_state(
	weapon_id: String,
	profile_override: Dictionary,
	weapon_profiles: Dictionary,
	overrides_by_id: Dictionary,
	config: Dictionary,
	doping_defaults: Dictionary,
	base_weapon_id: String,
	pistol_bullet_speed: float,
	doping_pistol_speed_multiplier: float,
	pistol_spread_radians: float,
	beretta_spread_radians: float,
	base_pistol_speed_mult: float = 1.0
) -> Dictionary:
	var profile: Dictionary = profile_override.duplicate(true)
	if profile.is_empty():
		profile = get_weapon_profile(
			weapon_id,
			weapon_profiles,
			overrides_by_id
		)
	var doping_context: Dictionary = CommandoFirearmValueUtils.normalize_doping_potion_context(
		config,
		doping_defaults
	)
	if weapon_id == "commando_pistol" and bool(doping_context.get("active", false)):
		profile["speed"] = float(profile.get("speed", pistol_bullet_speed)) * float(doping_context.get("pistol_speed_multiplier", doping_pistol_speed_multiplier))
		profile["color"] = Color(1.0, 0.47, 0.24)
		profile["secondary"] = Color(1.0, 0.78, 0.22)
	if (
		CommandoFirearmValueUtils.is_pistol_weapon(weapon_id, base_weapon_id)
		and weapon_id != "commando_pistol"
		and not bool(profile.get("slingshot", false))
	):
		profile["speed"] = float(profile.get("speed", pistol_bullet_speed)) * max(0.0, base_pistol_speed_mult)
	if (
		CommandoFirearmValueUtils.is_pistol_weapon(weapon_id, base_weapon_id)
		and not bool(profile.get("slingshot", false))
		and not profile.has("angle_offset")
	):
		var spread_radians: float = beretta_spread_radians if weapon_id == "commando_pistol" else pistol_spread_radians
		profile["angle_offset"] = randf_range(-spread_radians, spread_radians)
	return {
		"profile": profile,
		"doping_context": doping_context,
	}


static func get_profile(
	profiles: Dictionary,
	weapon_id: String,
	fallback_id: String = "pistol",
	overrides_by_id: Dictionary = {}
) -> Dictionary:
	var id: String = normalize_weapon_id(weapon_id)
	var fallback: Variant = profiles.get(fallback_id, {})
	var value: Variant = profiles.get(id, fallback)
	if value is Dictionary:
		var profile: Dictionary = (value as Dictionary).duplicate(true)
		var overrides: Variant = overrides_by_id.get(id, {})
		if overrides is Dictionary:
			var override_profile: Dictionary = overrides
			profile.merge(override_profile, true)
		return profile
	if fallback is Dictionary:
		return (fallback as Dictionary).duplicate(true)
	return {}
