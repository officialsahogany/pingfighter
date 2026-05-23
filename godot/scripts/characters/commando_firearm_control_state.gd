extends RefCounted


static func needs_effect_update(
	visible_effects: bool,
	pending_boss_damage_units: int,
	pending_special_gauge_gain: float
) -> bool:
	return visible_effects or pending_boss_damage_units > 0 or pending_special_gauge_gain > 0.0


static func is_player_control_locked(
	lock_timers: Array,
	active_support_call_lock: bool,
	active_suicide_drone: bool
) -> bool:
	for value in lock_timers:
		if float(value) > 0.0:
			return true
	return active_support_call_lock or active_suicide_drone


static func get_movement_speed_multiplier(
	active_suicide_drone: bool,
	ak47_trigger_held: bool,
	_hooked_net_field: bool,
	ak47_multiplier: float,
	_net_gun_multiplier: float
) -> float:
	if active_suicide_drone:
		return 0.0
	return ak47_multiplier if ak47_trigger_held else 1.0
