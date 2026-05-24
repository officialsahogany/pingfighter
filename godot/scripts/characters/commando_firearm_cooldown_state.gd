extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func trigger_skill_cooldown(
	weapon_id: String,
	now_msec: int,
	deps: Dictionary,
	doping_context: Dictionary,
	doping_active: bool,
	default_fire_rate_multiplier: float
) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null:
		return
	var skill_config: Object = deps.get("skill_config", null)
	var cooldown_seconds: float = get_skill_cooldown_seconds(
		weapon_id,
		skill_config,
		doping_context,
		doping_active,
		default_fire_rate_multiplier
	)
	if skill_state.has_method("trigger_cooldown"):
		skill_state.trigger_cooldown(weapon_id, now_msec, cooldown_seconds)
		return
	if skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(weapon_id, now_msec, skill_config)


static func trigger_configured_cooldown(weapon_id: String, now_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("trigger_configured_cooldown"):
		return
	var skill_config: Object = deps.get("skill_config", null)
	skill_state.trigger_configured_cooldown(weapon_id, now_msec, skill_config)


static func is_ready(weapon_id: String, now_msec: int, deps: Dictionary) -> bool:
	if weapon_id == "pistol" or weapon_id == "":
		return true
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_cooldown_remaining"):
		return true
	var skill_config: Object = deps.get("skill_config", null)
	var cooldown_seconds: float = get_skill_cooldown_seconds(
		weapon_id,
		skill_config,
		{},
		false,
		1.0
	)
	return float(skill_state.get_cooldown_remaining(weapon_id, now_msec, cooldown_seconds)) <= 0.0


static func get_skill_cooldown_seconds(
	weapon_id: String,
	skill_config: Object,
	doping_context: Dictionary,
	doping_active: bool,
	default_fire_rate_multiplier: float
) -> float:
	var cooldown_seconds := 0.0
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		cooldown_seconds = float(skill_config.get_cooldown_seconds(weapon_id))
	if not doping_active:
		return cooldown_seconds
	return cooldown_seconds * CommandoFirearmValueUtils.get_doping_fire_rate_multiplier(
		doping_context,
		default_fire_rate_multiplier
	)
