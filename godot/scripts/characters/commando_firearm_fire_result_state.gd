extends RefCounted


static func build_fire_failed_result(
	weapon_id: String,
	special_gauge: float,
	reason: String,
	extra_fields: Dictionary = {}
) -> Dictionary:
	var result := {
		"handled": true,
		"weapon_id": weapon_id,
		"fire_failed": true,
		"failure_reason": reason,
		"special_gauge": special_gauge,
	}
	result.merge(extra_fields, true)
	return result


static func build_pistol_shot_pending_result(
	weapon_id: String,
	fire_delay_frames: float,
	control_lock_frames: float
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"shot_pending": true,
		"fire_delay_frames": fire_delay_frames,
		"control_lock_frames": control_lock_frames,
	}


static func build_pistol_delayed_fire_result(
	weapon_id: String,
	cooldown_frames: float,
	control_lock_frames: float
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"fired": true,
		"fire_delay_frames": 0.0,
		"cooldown_frames": cooldown_frames,
		"control_lock_frames": control_lock_frames,
		"skill_gold_award": 0,
	}


static func build_pistol_reload_started_result(
	weapon_id: String,
	special_gauge: float,
	reason: String
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"fire_failed": true,
		"reload_started": true,
		"failure_reason": reason,
		"special_gauge": special_gauge,
	}


static func build_base_pistol_reload_started_result(
	weapon_id: String,
	special_gauge: float,
	updated_weapon: Dictionary,
	ammo_max_default: int,
	reload_timer_default: float,
	reload_gauge_cost: float
) -> Dictionary:
	var result: Dictionary = build_pistol_reload_started_result(
		weapon_id,
		special_gauge,
		"base_pistol_empty_reload_started"
	)
	result.merge({
		"ammo_current": int(updated_weapon.get("ammo_current", 0)),
		"ammo_max": int(updated_weapon.get("ammo_max", ammo_max_default)),
		"reload_display_ammo": int(updated_weapon.get("reload_display_ammo", updated_weapon.get("ammo_current", 0))),
		"reload_timer_frames": float(updated_weapon.get("reload_timer_frames", reload_timer_default)),
		"commando_pistol_reload_gauge_cost": reload_gauge_cost,
		"skill_gold_award": 0,
	}, true)
	return result


static func build_pistol_shot_queued_result(
	weapon_id: String,
	updated_weapon: Dictionary,
	fallback_ammo_current: int,
	ammo_max_default: int,
	fallback_magazines_current: int,
	cooldown_frames: float,
	control_lock_frames: float,
	fire_delay_frames: float,
	doping_context: Dictionary,
	doping_active: bool,
	special_gauge: float
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": weapon_id,
		"shot_queued": true,
		"ammo_current": int(updated_weapon.get("ammo_current", fallback_ammo_current)),
		"ammo_max": int(updated_weapon.get("ammo_max", ammo_max_default)),
		"magazines_current": int(updated_weapon.get("magazines_current", fallback_magazines_current)),
		"magazines_max": int(updated_weapon.get("magazines_max", 0)),
		"cooldown_frames": cooldown_frames,
		"control_lock_frames": control_lock_frames,
		"fire_delay_frames": fire_delay_frames,
		"doping_potion_active": doping_active,
		"doping_potion_head_leg_multiplier": float(doping_context.get("head_leg_multiplier", 1.0)),
		"doping_potion_pistol_speed_multiplier": float(doping_context.get("pistol_speed_multiplier", 1.0)),
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}
