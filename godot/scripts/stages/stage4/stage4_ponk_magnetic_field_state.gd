extends RefCounted

const COOLDOWN_SEC := 25.0
const DURATION_FRAMES := 200.0
const ENRAGED_DURATION_FRAMES := 300.0
const RADIUS := 160.0
const ENRAGED_RADIUS := 200.0
const CURVE_ANGLE_PER_FRAME := 4.1
const CURVE_ACCEL_PER_FRAME := 1.8
const SPEED_GROWTH_PER_FRAME := 1.04
const SPEED_CAP_MULTIPLIER := 2.2
const DEFAULT_CENTER := Vector2(380.0, 78.0)
const DEFAULT_RELEASE_MIN_SPEED := 7.65

# Mutable owner for Ponk's refraction magnetic field, ball-curvature math,
# cooldown, and one-shot release-speed restoration. It owns no RNG, audio,
# projectile state, scene annotations, or node-backed FX lifecycle.

var magnetic_cooldown_seconds := COOLDOWN_SEC
var magnetic_active := false
var magnetic_timer_frames := 0.0
var magnetic_radius := RADIUS
var magnetic_enraged := false
var magnetic_center := DEFAULT_CENTER
var magnet_curve_angle_degrees := 0.0
var magnetic_release_pending := false
var magnetic_release_min_speed := DEFAULT_RELEASE_MIN_SPEED


func reset() -> void:
	magnetic_cooldown_seconds = COOLDOWN_SEC
	magnetic_active = false
	magnetic_timer_frames = 0.0
	magnetic_radius = RADIUS
	magnetic_enraged = false
	magnetic_center = DEFAULT_CENTER
	magnet_curve_angle_degrees = 0.0
	magnetic_release_pending = false
	magnetic_release_min_speed = DEFAULT_RELEASE_MIN_SPEED


func reset_round() -> void:
	magnetic_active = false
	magnetic_timer_frames = 0.0
	magnet_curve_angle_degrees = 0.0
	magnetic_release_pending = false


func clear_stage_transients() -> void:
	magnetic_active = false


func sync_center(center: Vector2) -> void:
	magnetic_center = center


func update_cooldown(delta: float) -> void:
	magnetic_cooldown_seconds = maxf(
		0.0,
		magnetic_cooldown_seconds - maxf(0.0, delta)
	)


func can_auto_activate(meditation_active: bool, serve_waiting: bool) -> bool:
	return (
		magnetic_cooldown_seconds <= 0.0
		and not magnetic_active
		and not meditation_active
		and not serve_waiting
	)


func activate(enraged: bool, boss_center: Vector2, release_min_speed: float) -> bool:
	magnetic_enraged = enraged
	magnetic_radius = ENRAGED_RADIUS if magnetic_enraged else RADIUS
	magnetic_timer_frames = ENRAGED_DURATION_FRAMES if magnetic_enraged else DURATION_FRAMES
	magnetic_center = boss_center
	magnet_curve_angle_degrees = 0.0
	magnetic_active = true
	magnetic_release_pending = false
	magnetic_release_min_speed = release_min_speed
	magnetic_cooldown_seconds = COOLDOWN_SEC
	return true


func consume_parried() -> void:
	magnetic_active = false
	magnetic_timer_frames = 0.0
	magnetic_release_pending = false
	magnet_curve_angle_degrees = 0.0
	magnetic_cooldown_seconds = COOLDOWN_SEC


func update(fps_scale: float) -> bool:
	if not magnetic_active:
		return false
	magnetic_timer_frames = maxf(
		0.0,
		magnetic_timer_frames - maxf(0.0, fps_scale)
	)
	if magnetic_timer_frames > 0.0:
		return false
	magnetic_active = false
	magnetic_release_pending = true
	magnet_curve_angle_degrees = 0.0
	return true


func consume_release(ball_velocity: Vector2, base_ball_speed: float) -> Dictionary:
	if not magnetic_release_pending:
		return {}
	magnetic_release_pending = false
	var release_velocity := ball_velocity
	var velocity_changed := false
	if release_velocity.length() > 0.001:
		var min_speed: float = maxf(magnetic_release_min_speed, base_ball_speed)
		if release_velocity.length() < min_speed:
			release_velocity = release_velocity.normalized() * min_speed
			velocity_changed = true
	return {
		"velocity": release_velocity,
		"velocity_changed": velocity_changed,
	}


func curve_ball(
	ball_pos: Vector2,
	ball_velocity: Vector2,
	boss_center: Vector2,
	player_center: Vector2,
	fps_scale: float,
	timing_frozen: bool
) -> Dictionary:
	if not magnetic_active or timing_frozen:
		return {}
	magnetic_center = boss_center
	if ball_pos.distance_to(boss_center) > magnetic_radius:
		return {}
	var to_player: Vector2 = player_center - ball_pos
	if to_player.length() <= 0.001:
		to_player = Vector2(0.0, 1.0)
	var step: float = maxf(0.0, fps_scale)
	magnet_curve_angle_degrees += CURVE_ANGLE_PER_FRAME * step
	var curve_vector: Vector2 = (
		to_player.normalized().rotated(deg_to_rad(magnet_curve_angle_degrees))
		* (CURVE_ACCEL_PER_FRAME * step)
	)
	return {
		"velocity": (ball_velocity + curve_vector) * pow(SPEED_GROWTH_PER_FRAME, step),
		"angle": magnet_curve_angle_degrees,
	}


func apply_speed_cap(velocity: Vector2, base_ball_speed: float) -> Vector2:
	var speed_cap: float = base_ball_speed * SPEED_CAP_MULTIPLIER
	if velocity.length() > speed_cap:
		return velocity.normalized() * speed_cap
	return velocity


func get_actor_draw_context() -> Dictionary:
	return {
		"stage4_magnetic_active": magnetic_active,
		"stage4_magnetic_timer": magnetic_timer_frames,
		"stage4_magnetic_radius": magnetic_radius,
		"stage4_magnetic_center": magnetic_center,
		"stage4_magnetic_enraged": magnetic_enraged,
		"stage4_magnetic_curve_angle": magnet_curve_angle_degrees,
		"stage4_magnetic_cooldown_remaining": magnetic_cooldown_seconds,
		"stage4_magnetic_cooldown_total": COOLDOWN_SEC,
	}


func get_snapshot() -> Dictionary:
	return {
		"magnetic_active": magnetic_active,
		"magnetic_timer_frames": magnetic_timer_frames,
		"magnetic_radius": magnetic_radius,
		"magnetic_enraged": magnetic_enraged,
		"magnetic_center": magnetic_center,
		"magnet_curve_angle_degrees": magnet_curve_angle_degrees,
		"magnetic_release_pending": magnetic_release_pending,
		"magnetic_release_min_speed": magnetic_release_min_speed,
		"magnetic_cooldown_seconds": magnetic_cooldown_seconds,
	}
