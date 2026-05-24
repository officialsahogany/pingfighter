extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const VISIBLE_EFFECT_ARRAY_FIELDS := [
	"projectiles",
	"muzzle_flashes",
	"impact_flashes",
	"lingering_effects",
	"shell_casings",
	"pistol_feedbacks",
	"support_calls",
	"bowling_traps",
]

const VISIBLE_TIMER_FIELDS := [
	"slingshot_control_lock_frames",
	"pistol_fire_delay_frames",
	"pistol_post_fire_animation_frames",
	"weapon_fire_sheet_timer_frames",
	"pistol_control_lock_frames",
	"bazooka_control_lock_frames",
	"bazooka_fire_animation_frames",
	"bazooka_firing_pose_frames",
	"bazooka_muzzle_flash_frames",
	"net_gun_control_lock_frames",
	"net_gun_throw_pose_frames",
	"net_gun_harpoon_flash_frames",
	"bowling_trap_control_lock_frames",
	"bowling_trap_install_pose_frames",
	"suicide_drone_cooldown_frames",
]


static func build_slingshot_state(
	charging: bool,
	charge_timer_frames: float,
	charge_level: int,
	charge_threshold_frames: float,
	charge_tick_interval_frames: float,
	cooldown_frames: float,
	cooldown_max_frames: float,
	gauge_spent: float,
	control_lock_frames: float,
	control_lock_max_frames: float
) -> Dictionary:
	return {
		"charging": charging,
		"charge_timer_frames": charge_timer_frames,
		"charge_level": charge_level,
		"charge_ratio": clamp(charge_timer_frames / charge_threshold_frames, 0.0, 1.0),
		"charge_tick_ratio": fmod(max(0.0, charge_timer_frames), charge_tick_interval_frames) / charge_tick_interval_frames,
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"gauge_spent": gauge_spent,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
	}


static func build_pistol_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	fire_delay_frames: float,
	fire_delay_max_frames: float,
	post_fire_animation_frames: float,
	post_fire_animation_max_frames: float
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"fire_delay_frames": fire_delay_frames,
		"fire_delay_max_frames": fire_delay_max_frames,
		"shot_pending": fire_delay_frames > 0.0,
		"post_fire_animation_frames": post_fire_animation_frames,
		"post_fire_animation_max_frames": post_fire_animation_max_frames,
		"animation_active": fire_delay_frames > 0.0 or post_fire_animation_frames > 0.0,
	}


static func build_weapon_fire_sheet_state(
	weapon_id: String,
	timer_frames: float,
	timer_max_frames: float,
	frame_count: int
) -> Dictionary:
	return {
		"active": timer_frames > 0.0 and weapon_id != "",
		"weapon_id": weapon_id,
		"timer_frames": timer_frames,
		"timer_max_frames": timer_max_frames,
		"frame_count": frame_count,
	}


static func build_ak47_state(
	trigger_held: bool,
	fire_interval_frames: float,
	fire_interval_max_frames: float,
	burst_shots_remaining: int,
	recoil_accumulation: float,
	movement_speed_multiplier: float
) -> Dictionary:
	return {
		"trigger_held": trigger_held,
		"fire_interval_frames": fire_interval_frames,
		"fire_interval_max_frames": fire_interval_max_frames,
		"burst_shots_remaining": burst_shots_remaining,
		"recoil_accumulation": recoil_accumulation,
		"movement_speed_multiplier": movement_speed_multiplier,
	}


static func build_bazooka_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	fire_animation_frames: float,
	fire_animation_max_frames: float,
	firing_pose_frames: float,
	firing_pose_max_frames: float,
	muzzle_flash_frames: float,
	muzzle_flash_max_frames: float
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"fire_animation_frames": fire_animation_frames,
		"fire_animation_max_frames": fire_animation_max_frames,
		"firing_pose_frames": firing_pose_frames,
		"firing_pose_max_frames": firing_pose_max_frames,
		"muzzle_flash_frames": muzzle_flash_frames,
		"muzzle_flash_max_frames": muzzle_flash_max_frames,
		"firing_pose": firing_pose_frames > 0.0,
	}


static func build_net_gun_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	throw_pose_frames: float,
	throw_pose_max_frames: float,
	harpoon_flash_frames: float,
	harpoon_flash_max_frames: float,
	player_slow_multiplier: float,
	hooked_net_active: bool
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"throw_pose_frames": throw_pose_frames,
		"throw_pose_max_frames": throw_pose_max_frames,
		"harpoon_flash_frames": harpoon_flash_frames,
		"harpoon_flash_max_frames": harpoon_flash_max_frames,
		"throw_pose": throw_pose_frames > 0.0,
		"player_slow_multiplier": player_slow_multiplier,
		"hooked_net_active": hooked_net_active,
	}


static func build_bowling_trap_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	install_pose_frames: float,
	install_pose_max_frames: float,
	installing: bool,
	install_progress: float
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"install_pose_frames": install_pose_frames,
		"install_pose_max_frames": install_pose_max_frames,
		"installing": installing,
		"install_progress": install_progress,
	}


static func build_suicide_drone_state(
	active: bool,
	cooldown_frames: float,
	cooldown_max_frames: float,
	grace_frames: float,
	pos: Vector2,
	velocity: Vector2
) -> Dictionary:
	return {
		"active": active,
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"grace_frames": grace_frames,
		"pos": pos,
		"velocity": velocity,
	}


static func build_actor_context(
	effects_visible: bool,
	projectiles: Array,
	muzzle_flashes: Array,
	impact_flashes: Array,
	lingering_effects: Array,
	shell_casings: Array,
	pistol_feedbacks: Array,
	pistol_state: Dictionary,
	slingshot_state: Dictionary,
	ak47_state: Dictionary,
	bazooka_state: Dictionary,
	net_gun_state: Dictionary,
	bowling_trap_state: Dictionary,
	suicide_drone_state: Dictionary,
	weapon_fire_sheet_state: Dictionary,
	support_calls: Array,
	bowling_traps: Array
) -> Dictionary:
	return {
		"commando_firearm_projectiles": projectiles.duplicate(true) if effects_visible else [],
		"commando_firearm_muzzle_flashes": muzzle_flashes.duplicate(true) if effects_visible else [],
		"commando_firearm_impact_flashes": impact_flashes.duplicate(true) if effects_visible else [],
		"commando_firearm_lingering_effects": lingering_effects.duplicate(true) if effects_visible else [],
		"commando_firearm_shell_casings": shell_casings.duplicate(true) if effects_visible else [],
		"commando_firearm_pistol_feedbacks": pistol_feedbacks.duplicate(true) if effects_visible else [],
		"commando_firearm_pistol_state": pistol_state,
		"commando_firearm_slingshot_state": slingshot_state,
		"commando_firearm_ak47_state": ak47_state,
		"commando_firearm_bazooka_state": bazooka_state,
		"commando_firearm_net_gun_state": net_gun_state,
		"commando_firearm_bowling_trap_state": bowling_trap_state,
		"commando_firearm_suicide_drone_state": suicide_drone_state,
		"commando_firearm_weapon_fire_sheet_state": weapon_fire_sheet_state,
		"commando_firearm_support_calls": support_calls.duplicate(true) if effects_visible else [],
		"commando_firearm_bowling_traps": bowling_traps.duplicate(true) if effects_visible else [],
	}


static func has_visible_effects(effect_arrays: Array, timer_values: Array) -> bool:
	for value in effect_arrays:
		if value is Array and not (value as Array).is_empty():
			return true
	for value in timer_values:
		if float(value) > 0.0:
			return true
	return false


static func has_runtime_visible_effects(target: Object) -> bool:
	if target == null:
		return false
	var effect_arrays: Array = []
	for field_value in VISIBLE_EFFECT_ARRAY_FIELDS:
		effect_arrays.append(CommandoFirearmValueUtils.get_array(target.get(str(field_value))))
	var timer_values: Array = []
	for field_value in VISIBLE_TIMER_FIELDS:
		timer_values.append(float(target.get(str(field_value))))
	return has_visible_effects(effect_arrays, timer_values)
