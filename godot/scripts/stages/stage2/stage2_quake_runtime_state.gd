extends RefCounted

var timer := 0.0
var duration := 0.0
var cooldown := 0.0
var ball_velocity_backup := Vector2.ZERO
var ball_velocity_backup_valid := false
var boss_launch_guard_timer := 0.0
var affects_ball := false
var motion_rng := RandomNumberGenerator.new()
var ball_rng := RandomNumberGenerator.new()
var audio_active := false


func reset(default_duration: float, initial_cooldown: float) -> void:
	timer = 0.0
	duration = default_duration
	cooldown = initial_cooldown
	ball_velocity_backup = Vector2.ZERO
	ball_velocity_backup_valid = false
	boss_launch_guard_timer = 0.0
	affects_ball = false
	audio_active = false


func seed_random_sources(motion_seed: int, ball_seed: int) -> void:
	motion_rng.seed = motion_seed
	ball_rng.seed = ball_seed


func randomize_ball_motion() -> void:
	ball_rng.randomize()


func sample_ball_shake(max_x: float, max_y: float) -> Vector2:
	var bounded_x: float = abs(max_x)
	var bounded_y: float = abs(max_y)
	return Vector2(
		ball_rng.randf_range(-bounded_x, bounded_x),
		ball_rng.randf_range(-bounded_y, bounded_y)
	)


func activate(
	duration_sec: float,
	minimum_duration_sec: float,
	repeat_cooldown_sec: float,
	launch_guard_sec: float,
	should_affect_ball: bool
) -> void:
	duration = max(minimum_duration_sec, duration_sec)
	timer = duration
	cooldown = repeat_cooldown_sec
	ball_velocity_backup = Vector2.ZERO
	ball_velocity_backup_valid = false
	boss_launch_guard_timer = max(0.0, launch_guard_sec)
	affects_ball = should_affect_ball


func advance_timing(delta: float, allow_cooldown_advance: bool) -> bool:
	var clamped_delta: float = max(0.0, delta)
	var advanced_active := timer > 0.0
	if advanced_active:
		timer = max(0.0, timer - clamped_delta)
	elif allow_cooldown_advance:
		cooldown = max(0.0, cooldown - clamped_delta)
	return advanced_active


func capture_ball_velocity(ball_velocity: Vector2, reference_base_speed: float) -> void:
	if ball_velocity_backup_valid:
		return
	var current_speed: float = ball_velocity.length()
	if current_speed > reference_base_speed * 2.0 and current_speed > 0.001:
		ball_velocity_backup = ball_velocity.normalized() * reference_base_speed * 1.6
	else:
		ball_velocity_backup = ball_velocity
	ball_velocity_backup_valid = true


func ensure_boss_launch_guard(duration_sec: float) -> void:
	boss_launch_guard_timer = max(boss_launch_guard_timer, duration_sec)


func set_boss_launch_guard_timer(value: float) -> void:
	boss_launch_guard_timer = max(0.0, value)


func take_restored_ball_velocity(reference_base_speed: float) -> Dictionary:
	if not ball_velocity_backup_valid:
		affects_ball = false
		return {
			"restored": false,
			"velocity": Vector2.ZERO,
		}
	var restored := ball_velocity_backup
	if restored.length() < reference_base_speed * 0.85:
		var direction: Vector2 = restored.normalized() if restored.length_squared() > 0.001 else Vector2.DOWN
		restored = direction * reference_base_speed
	ball_velocity_backup = Vector2.ZERO
	ball_velocity_backup_valid = false
	boss_launch_guard_timer = 0.0
	affects_ball = false
	return {
		"restored": true,
		"velocity": restored,
	}


func clear_round_state() -> void:
	timer = 0.0
	ball_velocity_backup = Vector2.ZERO
	ball_velocity_backup_valid = false
	boss_launch_guard_timer = 0.0
	affects_ball = false
	audio_active = false
