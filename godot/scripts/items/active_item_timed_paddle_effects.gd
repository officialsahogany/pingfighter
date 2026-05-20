extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const LONG_BOOST_DURATION_FRAMES := 480.0
const LONG_BOOST_TRANSITION_FRAMES := 60.0
const LONG_BOOST_TARGET_SCALE := 1.5
const VITAMIN_PILL_DURATION_FRAMES := 600.0
const VITAMIN_PILL_FLASH_FRAMES := 10.0
const STRANGE_VIAL_DURATION_FRAMES := 600.0
const STRANGE_VIAL_TRANSITION_FRAMES := 45.0
const STRANGE_VIAL_ENLARGE_PADDLE_SCALE := 2.2
const STRANGE_VIAL_ENLARGE_SPEED_MULTIPLIER := 0.5
const STRANGE_VIAL_SHRINK_PADDLE_SCALE := 0.5
const STRANGE_VIAL_SHRINK_SPEED_MULTIPLIER := 2.3
const STRANGE_VIAL_FLASH_FRAMES := 12.0


func get_default_player_center() -> Vector2:
	return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)


func start_long_boost(duration_multiplier: float = 1.0) -> Dictionary:
	var duration_frames: float = _scale_duration_frames(LONG_BOOST_DURATION_FRAMES, duration_multiplier)
	return {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"scale": 1.0,
	}


func update_long_boost(active: bool, timer_frames: float, initial_timer_frames: float, delta: float) -> Dictionary:
	if not active:
		return clear_long_boost()

	var fps_scale: float = delta * 60.0
	var next_timer: float = max(0.0, timer_frames - fps_scale)
	var next_scale: float = _get_transition_scale(
		next_timer,
		initial_timer_frames,
		LONG_BOOST_TRANSITION_FRAMES,
		LONG_BOOST_TARGET_SCALE
	)
	if next_timer <= 0.0:
		return clear_long_boost()

	return {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": initial_timer_frames,
		"scale": next_scale,
	}


func apply_update_long_boost(
	target: Object,
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	delta: float,
	state_applier: Object
) -> void:
	state_applier.apply_long_boost_state(target, update_long_boost(
		active,
		timer_frames,
		initial_timer_frames,
		delta
	))


func start_vitamin_pill(player_center: Vector2, duration_multiplier: float = 1.0) -> Dictionary:
	var duration_frames: float = _scale_duration_frames(VITAMIN_PILL_DURATION_FRAMES, duration_multiplier)
	return {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"phase": 0.0,
		"flash_timer_frames": VITAMIN_PILL_FLASH_FRAMES,
		"player_center": player_center,
	}


func update_vitamin_pill(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	delta: float
) -> Dictionary:
	if not active:
		return clear_vitamin_pill(player_center)

	var fps_scale: float = delta * 60.0
	var next_timer: float = max(0.0, timer_frames - fps_scale)
	if next_timer <= 0.0:
		return clear_vitamin_pill(player_center)

	return {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": initial_timer_frames,
		"phase": fmod(phase + 0.18 * fps_scale, TAU),
		"flash_timer_frames": max(0.0, flash_timer_frames - fps_scale),
		"player_center": player_center,
	}


func apply_update_vitamin_pill(
	target: Object,
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	delta: float,
	state_applier: Object
) -> void:
	state_applier.apply_vitamin_pill_state(target, update_vitamin_pill(
		active,
		timer_frames,
		initial_timer_frames,
		phase,
		flash_timer_frames,
		player_center,
		delta
	))


func start_strange_vial(enlarge: bool, player_center: Vector2, duration_multiplier: float = 1.0) -> Dictionary:
	var target_scale := STRANGE_VIAL_ENLARGE_PADDLE_SCALE if enlarge else STRANGE_VIAL_SHRINK_PADDLE_SCALE
	var target_speed := STRANGE_VIAL_ENLARGE_SPEED_MULTIPLIER if enlarge else STRANGE_VIAL_SHRINK_SPEED_MULTIPLIER
	var duration_frames: float = _scale_duration_frames(STRANGE_VIAL_DURATION_FRAMES, duration_multiplier)
	return {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"effect_type": "enlarge" if enlarge else "shrink",
		"scale": 1.0,
		"target_scale": target_scale,
		"speed_multiplier": 1.0,
		"target_speed_multiplier": target_speed,
		"phase": 0.0,
		"flash_timer_frames": STRANGE_VIAL_FLASH_FRAMES,
		"player_center": player_center,
	}


func update_strange_vial(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	effect_type: String,
	target_scale: float,
	target_speed_multiplier: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	delta: float
) -> Dictionary:
	if not active:
		return {
			"active": false,
			"timer_frames": 0.0,
			"initial_timer_frames": 0.0,
			"effect_type": effect_type,
			"scale": 1.0,
			"target_scale": target_scale,
			"speed_multiplier": 1.0,
			"target_speed_multiplier": target_speed_multiplier,
			"phase": 0.0,
			"flash_timer_frames": 0.0,
			"player_center": player_center,
		}

	var fps_scale: float = delta * 60.0
	var next_timer: float = max(0.0, timer_frames - fps_scale)
	var elapsed_frames: float = max(0.0, initial_timer_frames - next_timer)
	var next_scale: float = _get_transition_scale(next_timer, initial_timer_frames, STRANGE_VIAL_TRANSITION_FRAMES, target_scale)
	var next_speed: float = _get_transition_scale(
		next_timer,
		initial_timer_frames,
		STRANGE_VIAL_TRANSITION_FRAMES,
		target_speed_multiplier
	)
	if next_timer <= 0.0:
		return clear_strange_vial()

	return {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": initial_timer_frames,
		"effect_type": effect_type,
		"scale": next_scale,
		"target_scale": target_scale,
		"speed_multiplier": next_speed,
		"target_speed_multiplier": target_speed_multiplier,
		"phase": fmod(phase + 0.12 * fps_scale, TAU),
		"flash_timer_frames": max(0.0, flash_timer_frames - fps_scale),
		"player_center": player_center,
		"elapsed_frames": elapsed_frames,
	}


func apply_update_strange_vial(
	target: Object,
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	effect_type: String,
	target_scale: float,
	target_speed_multiplier: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	delta: float,
	state_applier: Object
) -> void:
	state_applier.apply_strange_vial_state(target, update_strange_vial(
		active,
		timer_frames,
		initial_timer_frames,
		effect_type,
		target_scale,
		target_speed_multiplier,
		phase,
		flash_timer_frames,
		player_center,
		delta
	))


func clear_strange_vial() -> Dictionary:
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"effect_type": "",
		"scale": 1.0,
		"target_scale": 1.0,
		"speed_multiplier": 1.0,
		"target_speed_multiplier": 1.0,
		"phase": 0.0,
		"flash_timer_frames": 0.0,
		"player_center": get_default_player_center(),
	}


func clear_long_boost() -> Dictionary:
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"scale": 1.0,
	}


func clear_vitamin_pill(player_center: Variant = null) -> Dictionary:
	var next_center: Vector2 = get_default_player_center()
	if player_center is Vector2:
		next_center = player_center
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"phase": 0.0,
		"flash_timer_frames": 0.0,
		"player_center": next_center,
	}


func _scale_duration_frames(base_duration_frames: float, duration_multiplier: float) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return max(1.0, float(int(base_duration_frames * max(0.0, duration_multiplier))))


func _get_transition_scale(timer_frames: float, initial_timer_frames: float, transition_frames: float, target: float) -> float:
	var elapsed_frames: float = max(0.0, initial_timer_frames - timer_frames)
	if elapsed_frames < transition_frames:
		var grow_progress: float = elapsed_frames / transition_frames
		return lerp(1.0, target, grow_progress)
	if timer_frames <= transition_frames:
		var shrink_progress: float = timer_frames / transition_frames
		return lerp(1.0, target, shrink_progress)
	return target
