extends RefCounted

const Stage2QuakeBallMotionState := preload("res://scripts/stages/stage2/stage2_quake_ball_motion_state.gd")
const Stage2QuakeScreenShakeState := preload("res://scripts/stages/stage2/stage2_quake_screen_shake_state.gd")
const Stage2RockLifecycleCoordinator := preload("res://scripts/stages/stage2/stage2_rock_lifecycle_coordinator.gd")

const DEFAULT_DURATION_SEC := 80.0 / 60.0
const INITIAL_COOLDOWN_SEC := 0.0
const REPEAT_COOLDOWN_SEC := 4.0
const MINIMUM_DURATION_SEC := 0.2
const WATER_CANNON_DELAY_SEC := 7.0
const WARNING_DURATION_SEC := 1.35
const BOSS_LAUNCH_GUARD_SEC := 22.0 / 60.0
const BOSS_BACKSTOP_SEC := 6.0 / 60.0
const BALL_SHAKE_SCALE := 0.95
const BALL_MAX_SPEED := 12.5
const BALL_EFFECTIVE_SPEED_CAP := 5.0
const BALL_REFERENCE_BASE_SPEED := 9.0
const WAVE_COUNT := 4
const WAVE_SEGMENTS := 8
const MAX_ROCKS := Stage2RockLifecycleCoordinator.MAX_ROCKS

var quake_state: Object = null
var rock_state: Object = null
var water_cannon_state: Object = null
var rock_lifecycle_coordinator: Object = null
var skill_warning_state: Object = null
var audio_coordinator: Object = null


func configure(
	quake_state_ref: Object,
	rock_state_ref: Object,
	water_cannon_state_ref: Object,
	rock_lifecycle_coordinator_ref: Object,
	skill_warning_state_ref: Object,
	audio_coordinator_ref: Object
) -> void:
	quake_state = quake_state_ref
	rock_state = rock_state_ref
	water_cannon_state = water_cannon_state_ref
	rock_lifecycle_coordinator = rock_lifecycle_coordinator_ref
	skill_warning_state = skill_warning_state_ref
	audio_coordinator = audio_coordinator_ref


func reset() -> void:
	if quake_state != null:
		quake_state.reset(DEFAULT_DURATION_SEC, INITIAL_COOLDOWN_SEC)


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if quake_state == null:
		return false
	var advanced_timing: bool = quake_state.advance_timing(
		max(0.0, delta),
		deps.get("stage2_boss_skill_state", null) == null
			and int(context.get("current_stage", 1)) == 2
			and bool(context.get("ball_active", false))
	)
	if advanced_timing:
		_publish_screen_shake(deps)
	if audio_coordinator != null and audio_coordinator.has_method("sync_quake_audio"):
		audio_coordinator.sync_quake_audio(deps)
	return advanced_timing


func activate(
	duration_sec: float = DEFAULT_DURATION_SEC,
	rock_count: int = MAX_ROCKS,
	schedule_water_cannon: bool = true,
	start_boss_launch_guard: bool = false,
	deps: Dictionary = {}
) -> bool:
	if quake_state == null:
		return false
	quake_state.activate(
		duration_sec,
		MINIMUM_DURATION_SEC,
		REPEAT_COOLDOWN_SEC,
		BOSS_LAUNCH_GUARD_SEC if start_boss_launch_guard else 0.0,
		true
	)
	quake_state.randomize_ball_motion()
	if audio_coordinator != null and audio_coordinator.has_method("remember_audio"):
		audio_coordinator.remember_audio(deps)

	var current_rocks: Array = rock_state.rocks as Array if rock_state != null else []
	var available_rock_slots: int = maxi(0, MAX_ROCKS - current_rocks.size())
	var spawn_count: int = mini(clampi(rock_count, 0, MAX_ROCKS), available_rock_slots)
	if spawn_count > 0 and rock_lifecycle_coordinator != null:
		rock_lifecycle_coordinator.spawn_quake_rocks(spawn_count, deps)
	current_rocks = rock_state.rocks as Array if rock_state != null else []
	if water_cannon_state != null:
		water_cannon_state.delay = WATER_CANNON_DELAY_SEC if schedule_water_cannon and not current_rocks.is_empty() else -1.0
	if skill_warning_state != null and skill_warning_state.has_method("trigger"):
		skill_warning_state.trigger("quake", "지맥진동!", WARNING_DURATION_SEC)
	if audio_coordinator != null and audio_coordinator.has_method("play_quake_audio"):
		audio_coordinator.play_quake_audio(deps)
	return true


func clear_round_state(deps: Dictionary = {}) -> void:
	if quake_state != null:
		quake_state.clear_round_state()
	if audio_coordinator != null and audio_coordinator.has_method("stop_quake_audio"):
		audio_coordinator.stop_quake_audio(deps)


func is_active() -> bool:
	return quake_state != null and float(quake_state.timer) > 0.0


func apply_ball_motion(scene: Dictionary, context: Dictionary, fps_scale: float = 1.0) -> bool:
	if quake_state == null or int(context.get("current_stage", 1)) != 2:
		return false
	return apply_active_ball_motion(scene, context, fps_scale)


# Shared presentation path for the boss quake and Cheongringwi's Vision Chosik.
# The public Stage 2 entry point above keeps its stage gate, while the learned
# Chosik can reuse the exact shake/cap/restore contract on later stages.
func apply_active_ball_motion(scene: Dictionary, context: Dictionary, fps_scale: float = 1.0) -> bool:
	if quake_state == null:
		return false
	if not bool(quake_state.affects_ball):
		return false
	if float(quake_state.timer) <= 0.0:
		return _restore_ball_velocity(scene)

	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	quake_state.capture_ball_velocity(ball_vel, BALL_REFERENCE_BASE_SPEED)

	var duration: float = float(quake_state.duration)
	var effective_timer: float = max(0.0, float(quake_state.timer) - max(1.0, fps_scale) / 60.0)
	var quake_progress: float = 1.0 - (effective_timer / max(0.001, duration))
	var impulse_scale: float = Stage2QuakeBallMotionState.get_impulse_scale(quake_progress)
	var elapsed_frames: float = max(0.0, duration - effective_timer) * 60.0
	var random_shake: Vector2 = quake_state.sample_ball_shake(7.6, 5.2)
	var shake_x: float = random_shake.x * BALL_SHAKE_SCALE * impulse_scale
	var shake_y: float = random_shake.y * BALL_SHAKE_SCALE * impulse_scale
	ball_vel.x += shake_x + sin(elapsed_frames * 0.95) * 0.95 * impulse_scale
	ball_vel.y += shake_y + cos(elapsed_frames * 1.2) * 0.72 * impulse_scale
	ball_vel = Stage2QuakeBallMotionState.apply_player_pull(ball_vel, ball_pos, context)
	ball_vel.x = clamp(ball_vel.x, -BALL_MAX_SPEED, BALL_MAX_SPEED)
	ball_vel.y = clamp(ball_vel.y, -BALL_MAX_SPEED, BALL_MAX_SPEED)
	ball_vel = _apply_boss_launch_guard(scene, context, ball_vel, fps_scale)
	ball_vel = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, ball_vel, BALL_EFFECTIVE_SPEED_CAP)
	scene["ball_vel"] = ball_vel
	return true


func resolve_boss_backstop(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	if quake_state == null or int(context.get("current_stage", 1)) != 2:
		return false
	if float(quake_state.timer) <= 0.0 or not bool(quake_state.affects_ball) or not _was_last_hit_by_boss(deps):
		return false
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	if ball_pos.y - ball_radius > 0.0:
		return false

	quake_state.ensure_boss_launch_guard(BOSS_BACKSTOP_SEC)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	ball_vel = _apply_boss_launch_guard(scene, context, ball_vel, 1.0)
	ball_vel = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, ball_vel, BALL_EFFECTIVE_SPEED_CAP)
	ball_pos = _get_vector2(scene.get("ball_pos", ball_pos), ball_pos)
	if ball_pos.y - ball_radius <= 0.0:
		var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
		# A boss-scripting skill may hold the paddle mid-field. Keep the escape
		# backstop anchored to its home top band instead of teleporting the ball.
		var boss_anchor_y: float = min(boss_pos.y, float(context.get("boss_y", boss_pos.y)))
		var boss_bottom: float = boss_anchor_y + float(context.get("boss_hitbox_height", 40.0))
		ball_pos.y = boss_bottom + max(6.0, ball_radius + 2.0) + ball_radius
		scene["ball_pos"] = ball_pos
	ball_vel.y = max(abs(ball_vel.y), BALL_REFERENCE_BASE_SPEED * 0.65)
	ball_vel = Stage2QuakeBallMotionState.apply_original_speed_cap(scene, ball_vel, BALL_EFFECTIVE_SPEED_CAP)
	scene["ball_vel"] = ball_vel
	return true


func _publish_screen_shake(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("push_fixed_shake_offset"):
		feedback.push_fixed_shake_offset(Stage2QuakeScreenShakeState.get_offset(
			float(quake_state.timer),
			float(quake_state.duration),
			quake_state.motion_rng as RandomNumberGenerator
		))
	elif feedback.has_method("max_screen_shake"):
		var ratio: float = float(quake_state.timer) / max(0.001, float(quake_state.duration))
		feedback.max_screen_shake(0.040 + ratio * 0.025, 1.6 + ratio * 1.2)


func _restore_ball_velocity(scene: Dictionary) -> bool:
	var restore: Dictionary = quake_state.take_restored_ball_velocity(BALL_REFERENCE_BASE_SPEED)
	if not bool(restore.get("restored", false)):
		return false
	scene["ball_vel"] = _get_vector2(restore.get("velocity", Vector2.ZERO), Vector2.ZERO)
	return true


func _apply_boss_launch_guard(
	scene: Dictionary,
	context: Dictionary,
	ball_vel: Vector2,
	fps_scale: float
) -> Vector2:
	var result: Dictionary = Stage2QuakeBallMotionState.apply_boss_launch_guard(
		scene,
		context,
		ball_vel,
		fps_scale,
		float(quake_state.boss_launch_guard_timer),
		float(quake_state.ball_velocity_backup.y),
		bool(quake_state.ball_velocity_backup_valid),
		BALL_REFERENCE_BASE_SPEED
	)
	quake_state.set_boss_launch_guard_timer(float(result.get("guard_timer", quake_state.boss_launch_guard_timer)))
	return _get_vector2(result.get("ball_vel", ball_vel), ball_vel)


func _was_last_hit_by_boss(deps: Dictionary) -> bool:
	var ball_intensity: Object = deps.get("ball_intensity", null)
	return ball_intensity != null \
		and ball_intensity.has_method("get_last_hit_by") \
		and str(ball_intensity.get_last_hit_by()) == "boss"


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
