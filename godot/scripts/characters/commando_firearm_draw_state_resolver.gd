extends RefCounted


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
