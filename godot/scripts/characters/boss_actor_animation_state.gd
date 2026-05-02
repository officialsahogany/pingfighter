extends RefCounted

# Stage 1 Dalji sprite contract:
# - Walk: 8 frames per direction, separate left/right sheets, 4x2 grid, cell 344x384.
# - Idle: 8-frame breathing loop, 4x2 grid, cell 384x512, 250 ms / cell (~2.0 s loop).
# - Ball-contact hit: attack sheet, 8-frame 4x2 grid, cell 384x512.
#   F5 (index 4) is the contact apex, so approaching balls trigger a short
#   anticipation window before the actual paddle collision.
const SPRITE_FRAME_COUNT := 8
const SPRITE_ANIMATION_SPEED := 0.10
const HIT_ANIM_DURATION := 0.60
const HIT_FRAME_COUNT := 8
const HIT_FRAME_SPEED := 0.075
const IDLE_FRAME_COUNT := 8
const IDLE_FRAME_SPEED := 0.25
const STATIONARY_VELOCITY_THRESHOLD := 0.2
const ATTACK_X_TOLERANCE_EXTRA := 12.0

# facing: -1 = left, 1 = right (0 means "no facing yet" -> defaults to right).
var sprite_frame := 0
var sprite_timer := 0.0
var facing := 1
var is_walking := false
var idle_frame := 0
var idle_timer := 0.0
var hit_active := false
var hit_timer := 0.0
var hit_frame := 0
var hit_frame_timer := 0.0
var hit_facing := 1
var attack_anticipation_latched := false


func reset() -> void:
	sprite_frame = 0
	sprite_timer = 0.0
	facing = 1
	is_walking = false
	idle_frame = 0
	idle_timer = 0.0
	hit_active = false
	hit_timer = 0.0
	hit_frame = 0
	hit_frame_timer = 0.0
	hit_facing = 1
	attack_anticipation_latched = false


func update(delta: float, context: Dictionary) -> void:
	_maybe_trigger_anticipated_hit(context)
	_update_sprite_animation(delta, context)
	_update_hit_animation(delta, context)


func trigger_hit(
	boss_vel: float,
	has_hit_texture: bool,
	hit_duration: float = HIT_ANIM_DURATION,
	start_frame: int = 0
) -> void:
	if not has_hit_texture or hit_active:
		return
	hit_active = true
	hit_frame = int(clamp(start_frame, 0, HIT_FRAME_COUNT - 1))
	hit_timer = max(HIT_FRAME_SPEED, hit_duration - float(hit_frame) * HIT_FRAME_SPEED)
	hit_frame_timer = 0.0
	hit_facing = -1 if boss_vel < 0.0 else 1


func get_draw_context() -> Dictionary:
	return {
		"boss_sprite_frame": sprite_frame,
		"boss_facing": facing,
		"boss_is_walking": is_walking,
		"boss_idle_frame": idle_frame,
		"boss_hit_active": hit_active,
		"boss_hit_frame": hit_frame,
		"boss_hit_facing": hit_facing,
	}


func _update_sprite_animation(delta: float, context: Dictionary) -> void:
	if not bool(context.get("boss_has_sprite", false)):
		return

	var boss_vel: float = float(context.get("boss_vel", 0.0))
	var threshold: float = float(context.get("boss_stationary_velocity_threshold", STATIONARY_VELOCITY_THRESHOLD))
	if abs(boss_vel) > threshold:
		facing = -1 if boss_vel < 0.0 else 1
		is_walking = true
		sprite_timer += delta
		var animation_speed: float = float(context.get("boss_sprite_animation_speed", SPRITE_ANIMATION_SPEED))
		if sprite_timer >= animation_speed:
			sprite_timer -= animation_speed
			sprite_frame = (sprite_frame + 1) % max(1, int(context.get("boss_sprite_frame_count", SPRITE_FRAME_COUNT)))
		idle_timer = 0.0
		idle_frame = 0
	else:
		is_walking = false
		sprite_timer = 0.0
		sprite_frame = 0
		idle_timer += delta
		var idle_speed: float = float(context.get("boss_idle_frame_speed", IDLE_FRAME_SPEED))
		if idle_timer >= idle_speed:
			idle_timer -= idle_speed
		idle_frame = (idle_frame + 1) % max(1, int(context.get("boss_idle_frame_count", IDLE_FRAME_COUNT)))


func _maybe_trigger_anticipated_hit(context: Dictionary) -> void:
	if not bool(context.get("ball_active", false)):
		attack_anticipation_latched = false
		return

	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if ball_vel.y >= 0.0:
		attack_anticipation_latched = false
		return
	if attack_anticipation_latched or hit_active:
		return
	if not bool(context.get("boss_has_hit_sprite", false)):
		return
	if float(context.get("boss_collision_cooldown", 0.0)) > 0.0:
		return

	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var ball_size: float = float(context.get("ball_size", 22.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	var vertical_gap: float = (ball_pos.y - ball_size * 0.5) - (boss_pos.y + boss_hitbox_height)
	if vertical_gap < 0.0:
		return

	var impact_boost: float = max(0.01, float(context.get("ball_impact_boost", 1.0)))
	var upward_speed: float = max(0.01, -ball_vel.y * impact_boost)
	var frames_to_contact: float = vertical_gap / upward_speed
	var start_frame: int = _get_anticipatory_start_frame(frames_to_contact)
	if start_frame < 0:
		return

	var future_ball_center_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_center_x: float = boss_pos.x + boss_paddle_width * 0.5
	var x_tolerance: float = (boss_paddle_width + ball_size) * 0.5 + ATTACK_X_TOLERANCE_EXTRA
	if abs(future_ball_center_x - boss_center_x) > x_tolerance:
		return

	trigger_hit(float(context.get("boss_vel", 0.0)), true, HIT_ANIM_DURATION, start_frame)
	attack_anticipation_latched = hit_active


func _get_anticipatory_start_frame(frames_to_contact: float) -> int:
	if frames_to_contact >= 16.0 and frames_to_contact <= 20.0:
		return 0
	if frames_to_contact >= 12.0 and frames_to_contact < 16.0:
		return 1
	if frames_to_contact >= 8.0 and frames_to_contact < 12.0:
		return 2
	if frames_to_contact >= 4.0 and frames_to_contact < 8.0:
		return 3
	if frames_to_contact >= 0.0 and frames_to_contact < 4.0:
		return 4
	return -1


func _update_hit_animation(delta: float, context: Dictionary) -> void:
	if not hit_active:
		return
	hit_frame_timer += delta
	var hit_frame_speed: float = float(context.get("boss_hit_frame_speed", HIT_FRAME_SPEED))
	if hit_frame_timer >= hit_frame_speed:
		hit_frame_timer -= hit_frame_speed
		hit_frame += 1
		if hit_frame >= max(1, int(context.get("boss_hit_frame_count", HIT_FRAME_COUNT))):
			hit_active = false
			hit_timer = 0.0
			hit_frame = 0
			hit_frame_timer = 0.0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
