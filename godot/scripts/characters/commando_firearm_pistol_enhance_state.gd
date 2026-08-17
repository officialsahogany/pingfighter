extends RefCounted


static func get_runtime_perk_level(deps: Dictionary, perk_id: String) -> int:
	var perk_state: Object = deps.get("runtime_perk_state", null)
	if perk_state == null or not perk_state.has_method("get_runtime_skill_level"):
		return 0
	return max(0, int(perk_state.call("get_runtime_skill_level", perk_id)))


static func get_ammo_bonus(level: int) -> int:
	if level <= 2:
		return 0
	if level <= 4:
		return 1
	return level - 3


static func get_spread_radians(level: int, tuning: Dictionary) -> float:
	var base_spread_radians := float(tuning.get("base_spread_radians", 0.0))
	if level <= 0:
		return base_spread_radians
	var spread_degrees_value: Variant = tuning.get("spread_degrees", [])
	if not spread_degrees_value is Array:
		return base_spread_radians
	var spread_degrees: Array = spread_degrees_value
	if spread_degrees.size() <= 1:
		return base_spread_radians
	var index: int = clampi(level, 1, spread_degrees.size() - 1)
	return deg_to_rad(float(spread_degrees[index]))


static func get_speed_multiplier(level: int, tuning: Dictionary) -> float:
	return 1.0 + float(clampi(level, 0, 5)) * float(tuning.get("speed_bonus_per_level", 0.0))


static func get_knockback_multiplier(level: int, tuning: Dictionary) -> float:
	return 1.0 + float(clampi(level, 0, 5)) * float(tuning.get("knockback_bonus_per_level", 0.0))


static func build_spawn_options(deps: Dictionary, tuning: Dictionary) -> Dictionary:
	var level := get_runtime_perk_level(deps, str(tuning.get("perk_id", "pistol_enhance")))
	return {
		"pistol_spread_radians": get_spread_radians(level, tuning),
		"base_pistol_speed_mult": get_speed_multiplier(level, tuning),
		"base_pistol_knockback_mult": get_knockback_multiplier(level, tuning),
		"beretta_spread_radians": float(tuning.get("beretta_spread_radians", 0.0)),
	}


static func sync_base_pistol_ammo(
	deps: Dictionary,
	weapon_controller: Object,
	tuning: Dictionary
) -> void:
	if weapon_controller == null or not weapon_controller.has_method("set_base_pistol_ammo_max"):
		return
	var level := get_runtime_perk_level(deps, str(tuning.get("perk_id", "pistol_enhance")))
	var ammo_max := int(tuning.get("base_ammo_max", 0)) + get_ammo_bonus(level)
	weapon_controller.call("set_base_pistol_ammo_max", ammo_max)
