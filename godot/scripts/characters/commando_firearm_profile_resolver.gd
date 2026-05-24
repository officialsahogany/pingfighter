extends RefCounted


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
