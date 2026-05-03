extends RefCounted

# Smasher contact animation state ported from Python's
# `trigger_smasher_contact_animation(offset_x, intensity)`.

const IDLE_FRAME_COUNT := 8
const SPRITE_FRAME_COUNT := 6
const IDLE_ANIMATION_SPEED := 0.15
const SPRITE_ANIMATION_SPEED := 0.10
const HIT_ANIM_DURATION := 0.36
const HIT_FRAME_COUNT := 4

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
var hit_active := false
var hit_timer := 0.0
var hit_base_duration := HIT_ANIM_DURATION
var hit_frame := 0
var hit_side := -1
var anim_clock := 0.0

# Smasher attack runtime state (Python `smasher_*` globals).
var swing_intensity := 1.0
var hit_pose_timer := 0.0
var shield_raise_timer := 0.0  # right-side hit (offset_x >= 0)
var left_raise_timer := 0.0    # left-side hit (offset_x < 0)

# Pending contact offset for power-smash freeze-then-release anticipation.
var pending_contact_offset := 0.0
var pending_contact_offset_active := false


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


func update(delta: float, context: Dictionary) -> void:
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
			var frame_progress: float = _ease_out_cubic(hit_progress)
			hit_frame = min(
				int(floor(frame_progress * float(context.get("player_hit_frame_count", HIT_FRAME_COUNT)))),
				max(0, int(context.get("player_hit_frame_count", HIT_FRAME_COUNT)) - 1)
			)
		return

	var player_is_moving: bool = abs(float(context.get("player_speed", 0.0))) > 0.2 or bool(context.get("dash_active", false))
	if player_is_moving and bool(context.get("player_has_sprite", false)):
		sprite_timer += delta
		var walk_speed: float = float(context.get("player_sprite_animation_speed", SPRITE_ANIMATION_SPEED))
		if sprite_timer >= walk_speed:
			sprite_timer -= walk_speed
			sprite_frame = (sprite_frame + 1) % max(1, int(context.get("player_sprite_frame_count", SPRITE_FRAME_COUNT)))
		idle_timer = 0.0
		idle_frame = 0
	else:
		sprite_timer = 0.0
		sprite_frame = 0
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
	intensity: float = INTENSITY_NORMAL
) -> void:
	if not has_hit_texture:
		return
	swing_intensity = max(INTENSITY_NORMAL, intensity)
	hit_base_duration = max(0.001, hit_duration)
	hit_active = true
	hit_timer = hit_base_duration * swing_intensity
	hit_pose_timer = SMASHER_HIT_POSE_DURATION_SEC * swing_intensity
	hit_frame = 0
	hit_side = 1 if hit_pos >= 0.0 else -1
	# Python: right-side hit raises the shield, left-side hit raises the left
	# arm (mutually exclusive). The unselected side is force-cleared.
	if hit_side >= 0:
		shield_raise_timer = SMASHER_SHIELD_RAISE_DURATION_SEC * swing_intensity
		left_raise_timer = 0.0
	else:
		left_raise_timer = SMASHER_LEFT_RAISE_DURATION_SEC * swing_intensity
		shield_raise_timer = 0.0
	# Pending offset is one-shot: clear it on every successful trigger.
	pending_contact_offset_active = false
	pending_contact_offset = 0.0


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


func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0) - 1.0
	return t * t * t + 1.0
