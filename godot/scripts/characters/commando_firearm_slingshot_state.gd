extends RefCounted


static func build_charging_result(base_weapon_id: String, charge_timer_frames: float, charge_level: int, special_gauge: float) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": base_weapon_id,
		"charging": true,
		"charge_timer_frames": charge_timer_frames,
		"charge_level": charge_level,
		"special_gauge": special_gauge,
	}


static func build_not_ready_result(base_weapon_id: String, special_gauge: float) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": base_weapon_id,
		"fire_failed": true,
		"special_gauge": special_gauge,
		"failure_reason": "slingshot_not_ready",
	}


static func build_charge_canceled_result(base_weapon_id: String, special_gauge: float) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": base_weapon_id,
		"charge_canceled": true,
		"failure_reason": "slingshot_charge_short",
		"special_gauge": special_gauge,
	}


static func build_release_result(
	base_weapon_id: String,
	charge_level: int,
	charge_time: float,
	control_lock_frames: float,
	reason: String,
	special_gauge: float
) -> Dictionary:
	return {
		"handled": true,
		"weapon_id": base_weapon_id,
		"fired": true,
		"charge_level": charge_level,
		"charge_time_frames": charge_time,
		"control_lock_frames": control_lock_frames,
		"release_reason": reason,
		"special_gauge": special_gauge,
		"skill_gold_award": 0,
	}


static func advance_charge(
	charge_timer_frames: float,
	gauge_spent: float,
	special_gauge: float,
	gauge_cost: float,
	drain_interval_frames: float,
	threshold_1: float,
	threshold_2: float,
	threshold_3: float
) -> Dictionary:
	var next_timer: float = charge_timer_frames + 1.0
	var next_gauge: float = special_gauge
	var next_gauge_spent: float = gauge_spent
	var force_release := false
	var timer_int: int = int(round(next_timer))
	var interval_int: int = max(1, int(drain_interval_frames))
	if timer_int >= interval_int and timer_int % interval_int == 0:
		if next_gauge >= gauge_cost:
			next_gauge = max(0.0, next_gauge - gauge_cost)
			next_gauge_spent += gauge_cost
		else:
			force_release = true
	return {
		"charge_timer_frames": next_timer,
		"charge_level": get_charge_level(next_timer, threshold_1, threshold_2, threshold_3),
		"gauge_spent": next_gauge_spent,
		"special_gauge": next_gauge,
		"force_release": force_release,
	}


static func get_charge_level(timer_frames: float, threshold_1: float, threshold_2: float, threshold_3: float) -> int:
	if timer_frames >= threshold_3:
		return 3
	if timer_frames >= threshold_2:
		return 2
	if timer_frames >= threshold_1:
		return 1
	return 0


static func build_fire_profile(
	base_profile: Dictionary,
	charge_level: int,
	speed_by_level: Dictionary,
	base_bullet_speed: float,
	pellet_size: float
) -> Dictionary:
	var level: int = clampi(charge_level, 1, 3)
	var profile: Dictionary = base_profile.duplicate(true)
	profile["speed"] = float(speed_by_level.get(level, base_bullet_speed))
	profile["radius"] = pellet_size + float(level - 1)
	profile["charge_level"] = level
	profile["slingshot"] = true
	if level >= 3:
		profile["color"] = Color(1.0, 0.78, 0.36)
		profile["secondary"] = Color(1.0, 0.92, 0.42)
	elif level == 2:
		profile["color"] = Color(0.82, 0.82, 0.88)
		profile["secondary"] = Color(0.96, 0.96, 1.0)
	return profile


static func apply_hit_effects(
	weapon_id: String,
	projectile: Dictionary,
	result: Dictionary,
	base_weapon_id: String,
	stun_mult_by_level: Dictionary,
	knockback_mult_by_level: Dictionary
) -> void:
	if weapon_id != base_weapon_id or not bool(projectile.get("slingshot", false)):
		return
	var charge_level: int = clampi(int(projectile.get("charge_level", 1)), 1, 3)
	var stun_mult: float = float(stun_mult_by_level.get(charge_level, 1.0))
	var knockback_mult: float = float(knockback_mult_by_level.get(charge_level, 1.0))
	result["slingshot_charge_level"] = charge_level
	result["commando_firearm_slingshot_charge_level"] = charge_level
	result["stun_frames"] = round(18.0 * stun_mult)
	result["stun_source"] = "commando_firearm_slingshot_charge_%d" % charge_level
	result["knockback_power"] = 14.0 * knockback_mult
	result["commando_firearm_special_gauge_source"] = "commando_firearm_slingshot_charge_%d" % charge_level
