extends RefCounted

const BallSpeedPolicy := preload("res://scripts/ball/ball_speed_policy.gd")

signal kinked(event: Dictionary)
signal active_changed(active: bool)

const SKILL_NAME := "smasher_overdrive"
const DURATION_FRAMES := 360 # project.godot physics tick 72 Hz * 5 seconds
const SPEED_MULTIPLIER := 1.30
const SPEED_CAP := 30.0
const KINK_INTERVAL_FRAMES := 12
const KINK_ANGLE_RAD := deg_to_rad(28.0)

var ball_speed_policy: Object = BallSpeedPolicy.new()

var active := false
var remaining_frames := 0
var base_heading := Vector2.ZERO
var zig_sign := -1
var pending_kink := false
var frames_since_kink := 0
var boost_pending := false
var boosted_effective_speed_floor := 0.0
var last_kink_event: Dictionary = {}
var kink_serial := 0


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	_configured_player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var result := {"special_gauge": special_gauge, "activated": false}
	var skill_config: Object = deps.get("skill_config", null)
	if active and not _is_skill_equipped(skill_config):
		reset()
		return result
	if active:
		# Temporary transform/control locks and shared stuns pause the frame-based
		# window. Round/character/equipment teardown remains explicit elsewhere.
		if bool(config.get("player_skill_input_locked", false)):
			return result
		if _has_conflicting_ball_control(deps):
			reset()
			return result
		_tick_active_frame()
		return result
	if not bool(input_snapshot.get("down_pressed", false)):
		return result
	if not bool(input_snapshot.get("secondary_action_just_pressed", false)):
		return result
	if not _can_activate(current_msec, special_gauge, config, deps):
		return result

	var cost := _get_skill_cost(skill_config)
	_activate(
		_get_vector2(config, "ball_vel", Vector2.ZERO),
		max(0.001, float(config.get("ball_impact_boost", 1.0)))
	)
	_trigger_cooldown(current_msec, deps)
	result["special_gauge"] = max(0.0, special_gauge - cost)
	result["activated"] = true
	return result


func apply_ball_motion(ball_pos: Vector2, ball_vel: Vector2, impact_boost: float = 1.0) -> Dictionary:
	if not active or ball_vel.length_squared() <= 0.0001:
		return {}
	var safe_boost: float = max(0.001, impact_boost)
	var effective_speed: float = ball_vel.length() * safe_boost
	var heading := ball_vel.normalized()
	if boost_pending:
		base_heading = heading
		boost_pending = false
	effective_speed = min(max(effective_speed, boosted_effective_speed_floor), SPEED_CAP)
	if pending_kink:
		zig_sign *= -1
		heading = base_heading.rotated(KINK_ANGLE_RAD * float(zig_sign))
		heading = ball_speed_policy.ensure_min_vertical_component(heading, _vertical_sign(heading, base_heading))
		pending_kink = false
		kink_serial += 1
		last_kink_event = {
			"pos": ball_pos,
			"heading": heading,
			"zig_sign": zig_sign,
			"serial": kink_serial,
		}
		kinked.emit(last_kink_event.duplicate(true))
	return {
		"ball_vel": heading * (effective_speed / safe_boost),
		"smasher_overdrive_active": true,
		"smasher_overdrive_remaining_frames": remaining_frames,
		"smasher_overdrive_ball_boost_active": true,
	}


func notify_ball_reflected(ball_vel: Vector2, _impact_pos: Vector2 = Vector2.ZERO) -> void:
	if not active or ball_vel.length_squared() <= 0.0001:
		return
	base_heading = ball_vel.normalized()
	frames_since_kink = 0
	pending_kink = false


func is_active() -> bool:
	return active


func get_speed_cap() -> float:
	return SPEED_CAP if active else 0.0


func get_timer_snapshot() -> Dictionary:
	return {
		"id": SKILL_NAME,
		"active": active,
		"remaining_frames": remaining_frames,
		"total_frames": DURATION_FRAMES,
		"remaining_ratio": float(remaining_frames) / float(DURATION_FRAMES) if active else 0.0,
	}


func get_snapshot() -> Dictionary:
	return {
		"smasher_overdrive_active": active,
		"smasher_overdrive_remaining_frames": remaining_frames,
		"smasher_overdrive_ball_boost_active": active,
		"base_heading": base_heading,
		"zig_sign": zig_sign,
		"last_kink_event": last_kink_event.duplicate(true),
		"kink_serial": kink_serial,
		"boosted_effective_speed_floor": boosted_effective_speed_floor,
	}


func reset_round() -> void:
	reset()


func reset() -> void:
	var was_active := active
	active = false
	remaining_frames = 0
	base_heading = Vector2.ZERO
	zig_sign = -1
	pending_kink = false
	frames_since_kink = 0
	boost_pending = false
	boosted_effective_speed_floor = 0.0
	last_kink_event.clear()
	if was_active:
		active_changed.emit(false)


func _activate(ball_vel: Vector2, impact_boost: float) -> void:
	active = true
	remaining_frames = DURATION_FRAMES
	base_heading = ball_vel.normalized() if ball_vel.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	zig_sign = -1
	pending_kink = false
	frames_since_kink = 0
	boost_pending = true
	boosted_effective_speed_floor = min(ball_vel.length() * impact_boost * SPEED_MULTIPLIER, SPEED_CAP)
	last_kink_event.clear()
	active_changed.emit(true)


func _tick_active_frame() -> void:
	remaining_frames -= 1
	if remaining_frames <= 0:
		reset()
		return
	frames_since_kink += 1
	if frames_since_kink >= KINK_INTERVAL_FRAMES:
		frames_since_kink = 0
		pending_kink = true


func _can_activate(current_msec: int, special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if not bool(config.get("ball_active", false)) or bool(config.get("player_skill_input_locked", false)):
		return false
	if _has_conflicting_ball_control(deps):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if not _is_skill_equipped(skill_config):
		return false
	if special_gauge < _get_skill_cost(skill_config):
		return false
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, skill_config)) <= 0.0
	return true


func _is_skill_equipped(skill_config: Object) -> bool:
	return (
		skill_config != null
		and skill_config.has_method("is_skill_equipped")
		and bool(skill_config.is_skill_equipped(SKILL_NAME))
	)


func _has_conflicting_ball_control(deps: Dictionary) -> bool:
	for key in ["smasher_magnum_grip_state", "smasher_wheel_state"]:
		var state: Object = deps.get(key, null)
		if state != null and state.has_method("is_active") and bool(state.is_active()):
			return true
	return false


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	return 280.0


func _vertical_sign(heading: Vector2, fallback: Vector2) -> float:
	if absf(heading.y) > 0.001:
		return signf(heading.y)
	if absf(fallback.y) > 0.001:
		return signf(fallback.y)
	return -1.0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector2 else fallback
