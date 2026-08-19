extends RefCounted

# Smasher contact animation state ported from Python's
# `trigger_smasher_contact_animation(offset_x, intensity)`.

const IDLE_FRAME_COUNT := 8
const SPRITE_FRAME_COUNT := 6
const IDLE_ANIMATION_SPEED := 0.15
const SPRITE_ANIMATION_SPEED := 0.10
# Walk frames advance per pixel actually travelled, not per second, so the
# cadence tracks accel/decel/turn-inertia instead of running at a fixed rate.
# The live budget arrives as `player_walk_distance_per_frame` from the sprite
# context builder, which derives it per character. This fallback is the Smasher
# value: PADDLE_MAX_SPEED (6.0 px/physics-tick) * 60 fps *
# SMASHER_DIRECTIONAL_WALK_FRAME_SPEED (0.050 s) = 18.0, so at full speed the
# cadence matches the previous timer. Below full speed it slows down, and at a
# clamped wall it stops (GRT-012: drawn movement drives the walk gate).
const WALK_DISTANCE_PER_FRAME_PX := 18.0
const HIT_ANIM_DURATION := 0.36
const HIT_FRAME_COUNT := 4
const ATTACK_X_TOLERANCE_EXTRA := 18.0
const ATTACK_ANTICIPATION_MAX_VERTICAL_GAP := 220.0

# Smasher contact-animation durations (Python frame counts / 60 fps).
const SMASHER_HIT_POSE_DURATION_SEC := 8.0 / 60.0  # Python: SMASHER_HIT_POSE_DURATION = 8 frames
const SMASHER_SHIELD_RAISE_DURATION_SEC := 18.0 / 60.0  # Python: SMASHER_SHIELD_RAISE_DURATION = 18 frames
const SMASHER_LEFT_RAISE_DURATION_SEC := 18.0 / 60.0  # Python: SMASHER_LEFT_RAISE_DURATION = 18 frames

# Intensity multipliers from Python contact-animation callers.
const INTENSITY_NORMAL := 1.0
const INTENSITY_DRIVE := 1.5
const INTENSITY_POWER_SMASH := 2.0

var idle_frame := 0
var idle_timer := 0.0
var sprite_frame := 0
var sprite_timer := 0.0
# Walk odometer: distance actually drawn since the last frame advance, and the
# previous drawn x. `has_walk_anchor` keeps the first update from reading a
# bogus delta against an unseeded anchor.
var walk_distance := 0.0
var last_walk_x := 0.0
var has_walk_anchor := false
var hit_active := false
var hit_timer := 0.0
var hit_base_duration := HIT_ANIM_DURATION
var hit_frame := 0
var hit_side := -1
var hit_center := false
var anim_clock := 0.0

# Center-hit threshold: hit_pos is NORMALIZED [-1.0, 1.0] (offset / paddle_half_width).
# Within +/-0.5 = inner 50% of paddle width = "center hit" zone (used for viper up-kick).
const HIT_CENTER_THRESHOLD := 0.5

# Smasher attack runtime state (Python `smasher_*` globals).
var swing_intensity := 1.0
var hit_pose_timer := 0.0
var shield_raise_timer := 0.0  # right-side hit (offset_x >= 0)
var left_raise_timer := 0.0    # left-side hit (offset_x < 0)

# Pending contact offset for power-smash freeze-then-release anticipation.
var pending_contact_offset := 0.0
var pending_contact_offset_active := false
var attack_anticipation_latched := false


func reset() -> void:
	idle_frame = 0
	idle_timer = 0.0
	sprite_frame = 0
	sprite_timer = 0.0
	hit_active = false
	hit_timer = 0.0
	hit_base_duration = HIT_ANIM_DURATION
	hit_frame = 0
	hit_side = -1
	anim_clock = 0.0
	swing_intensity = 1.0
	hit_pose_timer = 0.0
	shield_raise_timer = 0.0
	left_raise_timer = 0.0
	pending_contact_offset = 0.0
	pending_contact_offset_active = false
	attack_anticipation_latched = false


func update(delta: float, context: Dictionary) -> void:
	_maybe_trigger_anticipated_hit(context)
	anim_clock += delta

	# Tick the auxiliary smasher contact timers every frame (Python lines
	# 148372-148380). `swing_intensity` resets to 1.0 only after every timer
	# (sprite hit, hit pose, shield raise, and left raise) has expired, so the
	# intensity stays elevated through the full follow-through window.
	if hit_pose_timer > 0.0:
		hit_pose_timer = max(0.0, hit_pose_timer - delta)
	if shield_raise_timer > 0.0:
		shield_raise_timer = max(0.0, shield_raise_timer - delta)
	if left_raise_timer > 0.0:
		left_raise_timer = max(0.0, left_raise_timer - delta)
	if not hit_active and hit_pose_timer <= 0.0 and shield_raise_timer <= 0.0 and left_raise_timer <= 0.0:
		swing_intensity = 1.0

	if hit_active:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_active = false
			if hit_pose_timer <= 0.0 and shield_raise_timer <= 0.0 and left_raise_timer <= 0.0:
				swing_intensity = 1.0
		else:
			var context_hit_duration: float = float(context.get("player_hit_anim_duration", HIT_ANIM_DURATION))
			if abs(context_hit_duration - hit_base_duration) > 0.001:
				hit_base_duration = context_hit_duration
			var hit_progress: float = get_hit_progress(get_effective_hit_duration())
			var frame_progress: float = hit_progress if bool(context.get("player_hit_linear_frames", false)) else _ease_out_cubic(hit_progress)
			hit_frame = min(
				int(floor(frame_progress * float(context.get("player_hit_frame_count", HIT_FRAME_COUNT)))),
				max(0, int(context.get("player_hit_frame_count", HIT_FRAME_COUNT)) - 1)
			)
		return

	# `player_speed` is intent, not travel: update_horizontal() clamps player_pos
	# at the wall but returns the un-zeroed speed (it still feeds ball physics),
	# so speed alone keeps the walk cycle running in place. Gate on the drawn x.
	var dash_active: bool = bool(context.get("dash_active", false))
	var player_x: float = _get_vector2(context, "player_pos", Vector2.ZERO).x
	var travelled: float = absf(player_x - last_walk_x) if has_walk_anchor else 0.0
	last_walk_x = player_x
	has_walk_anchor = true
	var player_is_moving: bool = dash_active or (
		absf(float(context.get("player_speed", 0.0))) > 0.2 and travelled > 0.0
	)
	if player_is_moving and bool(context.get("player_has_sprite", false)):
		# Dash rides its own sheet and can be positionally locked, so it keeps the
		# timer cadence; walking is driven by the odometer.
		if dash_active:
			sprite_timer += delta
			var walk_speed: float = float(context.get("player_sprite_animation_speed", SPRITE_ANIMATION_SPEED))
			if sprite_timer >= walk_speed:
				sprite_timer -= walk_speed
				sprite_frame = (sprite_frame + 1) % max(1, int(context.get("player_sprite_frame_count", SPRITE_FRAME_COUNT)))
		else:
			# A missing or non-positive budget must fall back to the authored
			# constant, never to a near-zero budget that would advance a frame
			# per pixel.
			var distance_budget: float = float(context.get("player_walk_distance_per_frame", 0.0))
			if distance_budget <= 0.0:
				distance_budget = WALK_DISTANCE_PER_FRAME_PX
			walk_distance += travelled
			if walk_distance >= distance_budget:
				# One frame per update, mirroring the previous timer: a knockback or
				# teleport must not spin the cycle through several frames at once.
				walk_distance -= distance_budget
				sprite_frame = (sprite_frame + 1) % max(1, int(context.get("player_sprite_frame_count", SPRITE_FRAME_COUNT)))
		idle_timer = 0.0
		idle_frame = 0
	else:
		sprite_timer = 0.0
		sprite_frame = 0
		walk_distance = 0.0
		if bool(context.get("player_has_idle_sprite", false)):
			idle_timer += delta
			var idle_speed: float = float(context.get("player_idle_animation_speed", IDLE_ANIMATION_SPEED))
			if idle_timer >= idle_speed:
				idle_timer -= idle_speed
				idle_frame = (idle_frame + 1) % max(1, int(context.get("player_idle_frame_count", IDLE_FRAME_COUNT)))


# `intensity` mirrors Python's `trigger_smasher_contact_animation`: 1.0 normal,
# 1.5 drive, 2.0 power-smash. It scales the hit anim duration and the auxiliary
# shield_raise / left_raise timers so high-intensity strikes hold longer.
func trigger_hit(
	hit_pos: float,
	has_hit_texture: bool,
	hit_duration: float = HIT_ANIM_DURATION,
	intensity: float = INTENSITY_NORMAL,
	start_frame: int = 0,
	frame_count: int = HIT_FRAME_COUNT
) -> void:
	if not has_hit_texture:
		return
	var next_hit_side: int = _resolve_hit_side(hit_pos)
	hit_center = abs(hit_pos) <= HIT_CENTER_THRESHOLD
	if hit_active:
		apply_hit_side(next_hit_side, intensity)
		if intensity > swing_intensity:
			swing_intensity = max(INTENSITY_NORMAL, intensity)
			hit_base_duration = max(0.001, hit_duration)
			hit_timer = max(hit_timer, hit_base_duration * swing_intensity * 0.35)
			hit_pose_timer = max(hit_pose_timer, SMASHER_HIT_POSE_DURATION_SEC * swing_intensity)
		pending_contact_offset_active = false
		pending_contact_offset = 0.0
		attack_anticipation_latched = hit_active
		return
	swing_intensity = max(INTENSITY_NORMAL, intensity)
	hit_base_duration = max(0.001, hit_duration)
	hit_active = true
	var effective_duration: float = hit_base_duration * swing_intensity
	var safe_frame_count: int = max(1, frame_count)
	var start_progress: float = clamp(float(start_frame) / float(safe_frame_count), 0.0, 0.999)
	hit_timer = max(0.001, effective_duration * (1.0 - start_progress))
	hit_pose_timer = SMASHER_HIT_POSE_DURATION_SEC * swing_intensity
	hit_frame = int(clamp(start_frame, 0, safe_frame_count - 1))
	apply_hit_side(next_hit_side, swing_intensity)
	# Pending offset is one-shot: clear it on every successful trigger.
	pending_contact_offset_active = false
	pending_contact_offset = 0.0
	attack_anticipation_latched = hit_active


func apply_hit_side(next_hit_side: int, intensity: float = INTENSITY_NORMAL) -> void:
	# Sheet side follows the ball contact offset from the paddle center:
	# negative = left attack sheet, zero / positive = right attack sheet.
	hit_side = next_hit_side
	var timer_scale: float = max(INTENSITY_NORMAL, intensity)
	if hit_side >= 0:
		shield_raise_timer = max(shield_raise_timer, SMASHER_SHIELD_RAISE_DURATION_SEC * timer_scale)
		left_raise_timer = 0.0
	else:
		left_raise_timer = max(left_raise_timer, SMASHER_LEFT_RAISE_DURATION_SEC * timer_scale)
		shield_raise_timer = 0.0


func _resolve_hit_side(hit_pos: float) -> int:
	return 1 if hit_pos >= 0.0 else -1


func _maybe_trigger_anticipated_hit(context: Dictionary) -> void:
	if not bool(context.get("ball_active", false)):
		attack_anticipation_latched = false
		return

	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		attack_anticipation_latched = false
		return
	if attack_anticipation_latched or hit_active:
		return
	if not bool(context.get("player_has_hit_sprite", false)):
		return
	if float(context.get("player_collision_cooldown", 0.0)) > 0.0:
		attack_anticipation_latched = false
		return

	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var paddle_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2.ZERO)
	if paddle_size.x <= 0.0 or paddle_size.y <= 0.0:
		return

	var ball_size: float = float(context.get("ball_size", 28.6))
	var vertical_gap: float = player_pos.y - (ball_pos.y + ball_size * 0.5)
	if vertical_gap < 0.0:
		return
	if vertical_gap > ATTACK_ANTICIPATION_MAX_VERTICAL_GAP:
		return

	var impact_boost: float = max(0.01, float(context.get("ball_impact_boost", 1.0)))
	var downward_speed: float = max(0.01, ball_vel.y * impact_boost)
	var frames_to_contact: float = vertical_gap / downward_speed
	var start_frame: int = _get_anticipatory_start_frame(frames_to_contact)
	if start_frame < 0:
		return

	var future_ball_center_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var player_center_x: float = player_pos.x + paddle_size.x * 0.5
	var x_tolerance: float = (paddle_size.x + ball_size) * 0.5 + ATTACK_X_TOLERANCE_EXTRA
	if abs(future_ball_center_x - player_center_x) > x_tolerance:
		return

	trigger_hit(
		future_ball_center_x - player_center_x,
		true,
		float(context.get("player_hit_anim_duration", HIT_ANIM_DURATION)),
		INTENSITY_NORMAL,
		start_frame,
		int(context.get("player_hit_frame_count", HIT_FRAME_COUNT))
	)


func _get_anticipatory_start_frame(frames_to_contact: float) -> int:
	if frames_to_contact >= 16.0 and frames_to_contact <= 18.0:
		return 0
	if frames_to_contact >= 12.0 and frames_to_contact < 16.0:
		return 2
	if frames_to_contact >= 8.0 and frames_to_contact < 12.0:
		return 4
	if frames_to_contact >= 4.0 and frames_to_contact < 8.0:
		return 6
	if frames_to_contact >= 0.0 and frames_to_contact < 4.0:
		return 8
	return -1


func set_pending_contact_offset(offset_x: float) -> void:
	pending_contact_offset = offset_x
	pending_contact_offset_active = true


func has_pending_contact_offset() -> bool:
	return pending_contact_offset_active


func consume_pending_contact_offset() -> float:
	if not pending_contact_offset_active:
		return 0.0
	var value: float = pending_contact_offset
	pending_contact_offset_active = false
	pending_contact_offset = 0.0
	return value


func get_hit_progress(hit_duration: float) -> float:
	if hit_duration <= 0.0:
		return 1.0
	return clamp(1.0 - (hit_timer / hit_duration), 0.0, 1.0)


func get_effective_hit_duration() -> float:
	return hit_base_duration * max(INTENSITY_NORMAL, swing_intensity)


func get_draw_context() -> Dictionary:
	return {
		"player_anim_clock": anim_clock,
		"player_hit_active": hit_active,
		"player_hit_timer": hit_timer,
		"player_hit_anim_duration": hit_base_duration,
		"player_hit_effective_anim_duration": get_effective_hit_duration(),
		"player_hit_side": hit_side,
		"player_hit_center": hit_center,
		"player_hit_frame": hit_frame,
		"player_idle_frame": idle_frame,
		"player_sprite_frame": sprite_frame,
		"player_swing_intensity": swing_intensity,
		"player_hit_pose_timer": hit_pose_timer,
		"player_shield_raise_timer": shield_raise_timer,
		"player_left_raise_timer": left_raise_timer,
		"player_shield_raise_strength": _bell_strength(shield_raise_timer, SMASHER_SHIELD_RAISE_DURATION_SEC, swing_intensity),
		"player_left_raise_strength": _bell_strength(left_raise_timer, SMASHER_LEFT_RAISE_DURATION_SEC, swing_intensity),
		"player_hit_pose_strength": _hit_pose_ratio(hit_pose_timer, SMASHER_HIT_POSE_DURATION_SEC, swing_intensity),
	}


# Mirror of Python `_smasher_bell_strength`: bell-curve ease-in / ease-out
# centered on the timer's midpoint, used by procedural arm / shield raise
# rendering. Returns 0.0 when timer is idle, peaks at 1.0 mid-anim.
func _bell_strength(timer: float, duration_sec: float, intensity: float) -> float:
	if timer <= 0.0 or duration_sec <= 0.0:
		return 0.0
	var total: float = duration_sec * max(INTENSITY_NORMAL, intensity)
	if total <= 0.0:
		return 0.0
	var progress: float = clamp(1.0 - (timer / total), 0.0, 1.0)
	# Symmetric bell: rises to 1.0 at progress=0.5, returns to 0.0 at edges.
	return sin(PI * progress)


# Mirror of Python `_smasher_hit_ratio`: linear ease-out from 1.0 (just hit)
# down to 0.0 (recovered). Used to drive the lunge/scale modulation in the
# Stage 1 player renderer.
func _hit_pose_ratio(timer: float, duration_sec: float, intensity: float) -> float:
	if timer <= 0.0 or duration_sec <= 0.0:
		return 0.0
	var total: float = duration_sec * max(INTENSITY_NORMAL, intensity)
	if total <= 0.0:
		return 0.0
	return clamp(timer / total, 0.0, 1.0)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0) - 1.0
	return t * t * t + 1.0
