extends RefCounted

const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")


static func get_runtime_perk_level(deps: Dictionary, perk_id: String) -> int:
	var perk_state: Object = deps.get("runtime_perk_state", null)
	if perk_state == null or not perk_state.has_method("get_runtime_skill_level"):
		return 0
	return max(0, int(perk_state.call("get_runtime_skill_level", perk_id)))


static func get_ammo_bonus(level: int) -> int:
	if level <= 0:
		return 0
	return RuntimePerkProgression.get_int_value("pistol_enhance", "magazine_size", level) - RuntimePerkProgression.get_int_value("pistol_enhance", "magazine_size", 1)


static func get_spread_radians(level: int, tuning: Dictionary) -> float:
	var base_spread_radians := float(tuning.get("base_spread_radians", 0.0))
	if level <= 0:
		return base_spread_radians
	return deg_to_rad(RuntimePerkProgression.get_value("pistol_enhance", "spread_degrees", level))


static func get_speed_multiplier(level: int, _tuning: Dictionary) -> float:
	return 1.0 + RuntimePerkProgression.get_value("pistol_enhance", "speed_bonus_pct", level) / 100.0


static func get_knockback_multiplier(level: int, _tuning: Dictionary) -> float:
	return 1.0 + RuntimePerkProgression.get_value("pistol_enhance", "knockback_bonus_pct", level) / 100.0


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
