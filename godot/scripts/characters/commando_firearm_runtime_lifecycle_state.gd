extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")


static func reset_runtime(target: Object, defaults: Dictionary) -> void:
	if target == null:
		return
	target.set("last_fire_msec", -100000)
	for property_name in [
		"projectiles",
		"muzzle_flashes",
		"impact_flashes",
		"lingering_effects",
		"shell_casings",
		"pistol_feedbacks",
		"support_calls",
		"bowling_traps",
		"hit_events",
		"pending_boss_damage_sources",
		"pending_special_gauge_sources",
	]:
		_clear_array(target, property_name)
	target.set("pistol_pending_weapon_id", "")
	target.set("serve_wait_fire_suppressed_until_release", false)
	target.set("pending_boss_damage_units", 0)
	target.set("pending_special_gauge_gain", 0.0)
	target.set("pending_special_gauge_hit_kind", "")
	target.set("pending_pistol_feedback_timer_frames", 0.0)
	target.set("pistol_boss_hit_count", 0)
	target.set("ak47_boss_hit_count", 0)
	target.set("slingshot_charging", false)
	target.set("slingshot_charge_timer_frames", 0.0)
	target.set("slingshot_charge_level", 0)
	target.set("slingshot_cooldown_frames", 0.0)
	target.set("slingshot_gauge_spent", 0.0)
	target.set("slingshot_last_action_pressed", false)
	target.set("slingshot_control_lock_frames", 0.0)
	target.set("pistol_cooldown_frames", 0.0)
	target.set("pistol_cooldown_max_frames", float(defaults.get("pistol_cooldown_frames", 0.0)))
	target.set("pistol_control_lock_frames", 0.0)
	target.set("pistol_control_lock_max_frames", float(defaults.get("pistol_control_lock_frames", 0.0)))
	target.set("pistol_fire_delay_frames", 0.0)
	target.set("pistol_post_fire_animation_frames", 0.0)
	_clear_dictionary(target, "pistol_pending_config")
	target.set("ak47_fire_interval_frames", 0.0)
	target.set("ak47_fire_interval_max_frames", float(defaults.get("ak47_fire_interval_frames", 0.0)))
	target.set("ak47_burst_shots_remaining", 0)
	target.set("ak47_trigger_held", false)
	target.set("ak47_last_action_pressed", false)
	target.set("ak47_recoil_accumulation", 0.0)
	target.set("bazooka_cooldown_frames", 0.0)
	target.set("bazooka_cooldown_max_frames", float(defaults.get("bazooka_cooldown_frames", 0.0)))
	target.set("bazooka_control_lock_frames", 0.0)
	target.set("bazooka_control_lock_max_frames", float(defaults.get("bazooka_control_lock_frames", 0.0)))
	target.set("bazooka_fire_animation_frames", 0.0)
	target.set("bazooka_firing_pose_frames", 0.0)
	target.set("bazooka_muzzle_flash_frames", 0.0)
	target.set("net_gun_cooldown_frames", 0.0)
	target.set("net_gun_control_lock_frames", 0.0)
	target.set("net_gun_throw_pose_frames", 0.0)
	target.set("net_gun_harpoon_flash_frames", 0.0)
	target.set("net_gun_last_dash_active", false)
	target.set("bowling_trap_cooldown_frames", 0.0)
	target.set("bowling_trap_control_lock_frames", 0.0)
	target.set("bowling_trap_install_pose_frames", 0.0)
	target.set("bowling_trap_last_action_pressed", false)
	target.set("suicide_drone_cooldown_frames", 0.0)
	target.set("suicide_drone_last_action_pressed", false)
	target.set("weapon_fire_sheet_id", "")
	target.set("weapon_fire_sheet_timer_frames", 0.0)
	target.set("weapon_fire_sheet_max_frames", 0.0)
	CommandoFirearmBowlingTrapGeometry.apply_guard_state(
		target,
		CommandoFirearmBowlingTrapGeometry.build_cleared_guard_state()
	)


static func reset_round(
	target: Object,
	deps: Dictionary,
	defaults: Dictionary,
	capture_ball_offset: Vector2
) -> void:
	if target == null:
		return
	CommandoFirearmAudioDispatcher.stop_all_support_aircraft_audio(
		_get_array(target.get("support_calls")),
		deps
	)
	CommandoFirearmAudioDispatcher.stop_suicide_drone_audio(deps)
	var carried_bowling_traps: Array = []
	if bool(deps.get("preserve_bowling_traps", true)):
		carried_bowling_traps = CommandoFirearmBowlingTrapGeometry.build_round_carryover(
			_get_array(target.get("bowling_traps")),
			capture_ball_offset
		)
	reset_runtime(target, defaults)
	target.set("bowling_traps", carried_bowling_traps)


static func _clear_array(target: Object, property_name: StringName) -> void:
	var value: Variant = target.get(property_name)
	if value is Array:
		(value as Array).clear()
	else:
		target.set(property_name, [])


static func _clear_dictionary(target: Object, property_name: StringName) -> void:
	var value: Variant = target.get(property_name)
	if value is Dictionary:
		(value as Dictionary).clear()
	else:
		target.set(property_name, {})


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
