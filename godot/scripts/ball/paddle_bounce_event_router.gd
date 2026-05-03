extends RefCounted

const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")

const POWER_COUNTER_BASE_KNOCKBACK: float = 2.4 * 2.0
const POWER_COUNTER_KNOCKBACK_FRAMES: float = 18.0

# Smasher contact-animation intensity, ported from Python
# `trigger_smasher_contact_animation(offset_x, intensity)` callers in
# `pingfighter.py` (~183390 normal, 183659 drive, 202524-area power-smash).
const PLAYER_HIT_INTENSITY_NORMAL: float = 1.0
const PLAYER_HIT_INTENSITY_DRIVE: float = 1.5
const PLAYER_HIT_INTENSITY_POWER_SMASH: float = 2.0

var rally_feedback_router: Object = PaddleBounceRallyFeedbackRouter.new()


func register_player_hit(
	ball_pos: Vector2,
	hit_pos: float,
	drive_activated: bool,
	power_activated: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> float:
	var power_state = deps.get("power_state", null)
	var combo_state = deps.get("combo_state", null)
	if combo_state != null and (power_state == null or not power_state.is_freeze_active()):
		combo_state.register_hit(ball_pos)

	var updated_gauge: float = special_gauge
	if not drive_activated and not power_activated and not _is_dash_gauge_gain_blocked(deps):
		var gauge_gain: float = float(context.get("gauge_charge_per_hit", 0.0))
		if combo_state != null:
			gauge_gain = combo_state.get_gauge_gain(gauge_gain)
		updated_gauge = min(updated_gauge + gauge_gain, float(context.get("gauge_max", updated_gauge)))
		var feedback = deps.get("feedback", null)
		if feedback != null:
			feedback.trigger_gauge_flash()
	if power_activated:
		_set_pending_power_hit_anim(hit_pos, context, deps)
	else:
		_trigger_player_hit_anim(hit_pos, context, deps, _resolve_hit_intensity(drive_activated, false))
	return updated_gauge


func _resolve_hit_intensity(drive_activated: bool, power_activated: bool) -> float:
	if power_activated:
		return PLAYER_HIT_INTENSITY_POWER_SMASH
	if drive_activated:
		return PLAYER_HIT_INTENSITY_DRIVE
	return PLAYER_HIT_INTENSITY_NORMAL


func _is_dash_gauge_gain_blocked(deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return false
	if dash_state.has_method("is_active") and bool(dash_state.is_active()):
		return true
	if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
		return true
	return false


func register_rally_feedback(
	ball_pos: Vector2,
	ball_vel: Vector2,
	is_player: bool,
	power_activated: bool,
	deps: Dictionary
) -> void:
	rally_feedback_router.register(ball_pos, ball_vel, is_player, power_activated, deps)


func apply_drive_boss_counter(
	ball_vel: Vector2,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	deps: Dictionary
) -> Dictionary:
	var counter_state = deps.get("drive_counter_state", null)
	if counter_state == null:
		return {}
	var result: Dictionary = counter_state.apply_counter(
		ball_vel,
		ball_spin_strength,
		drive_speed_increase,
		drive_ball_active,
		drive_hit_boss
	)
	if bool(result.get("applied", false)):
		return result
	return {}


func end_power_smashing_on_boss_counter(ball_vel: Vector2, power_state: Object, deps: Dictionary = {}) -> Vector2:
	if power_state == null or (not power_state.is_parabola_active() and not power_state.is_freeze_active()):
		return ball_vel
	var combo_consumed: int = int(power_state.get_combo_consumed())
	if power_state.get_original_speed() > 0.0:
		var current_speed: float = ball_vel.length()
		if current_speed > 0.0:
			ball_vel *= power_state.get_original_speed() / current_speed
	if combo_consumed >= 2:
		_trigger_power_smash_counter_knockback(ball_vel, combo_consumed, deps)
	power_state.reset(false)
	return ball_vel


func trigger_boss_hit_anim(boss_vel: float, context: Dictionary, deps: Dictionary) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	animation_state.trigger_boss_hit(boss_vel, bool(context.get("boss_has_hit_sprite", false)))


func _trigger_player_hit_anim(hit_pos: float, context: Dictionary, deps: Dictionary, intensity: float = PLAYER_HIT_INTENSITY_NORMAL) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null:
		return
	# Pass the resolved intensity through the facade so player_actor_animation_state
	# can scale `hit_timer`, `shield_raise_timer`, and `left_raise_timer` together
	# (Python parity: drive holds the swing 1.5x longer, power-smash 2.0x).
	var hit_duration: float = float(context.get("player_hit_anim_duration", 0.36))
	animation_state.trigger_player_hit(hit_pos, bool(context.get("player_has_hit_sprite", false)), hit_duration, intensity)


func _set_pending_power_hit_anim(hit_pos: float, context: Dictionary, deps: Dictionary) -> void:
	var animation_state = deps.get("animation_state", null)
	if animation_state == null or not animation_state.has_method("set_player_pending_contact_offset"):
		return
	var paddle_width: float = max(1.0, float(context.get("paddle_width", 155.0)))
	var contact_offset: float = hit_pos * paddle_width * 0.5
	animation_state.set_player_pending_contact_offset(contact_offset)


func _trigger_power_smash_counter_knockback(ball_vel: Vector2, combo_consumed: int, deps: Dictionary) -> void:
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return
	var knockback_dir: float = 0.0
	if ball_vel.x > 0.0:
		knockback_dir = -1.0
	elif ball_vel.x < 0.0:
		knockback_dir = 1.0
	else:
		knockback_dir = -1.0 if randf() < 0.5 else 1.0
	var combo_mult: float = 1.0 + min(float(combo_consumed) * 0.30, 1.50)
	movement_state.start_knockback(
		knockback_dir * POWER_COUNTER_BASE_KNOCKBACK * combo_mult,
		POWER_COUNTER_KNOCKBACK_FRAMES
	)
