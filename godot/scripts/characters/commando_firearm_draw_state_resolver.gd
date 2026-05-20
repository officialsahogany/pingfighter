extends RefCounted


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
