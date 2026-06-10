extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const TRAMPOLINE_WIDTH := 110.0
const TRAMPOLINE_HEIGHT := 18.0
const TRAMPOLINE_BOTTOM_Y := FIELD_HEIGHT - 7.0
# Mat top must stay ABOVE the player paddle hitbox top
# (player_pos.y 700 - hitbox_padding 5 = 695), or a descending ball meets a
# paddle-only sub-step first and check_paddles eats the bounce whenever the
# player x-overlaps the mat. The trampoline smoke locks this contract through
# the full BallMotionStepper path.
const TRAMPOLINE_MAT_TOP_Y := 686.0
const TRAMPOLINE_MAX_BOUNCES := 3
const TRAMPOLINE_SPAWN_FRAMES := 14.0
const TRAMPOLINE_BOUNCE_ANIM_FRAMES := 22.0
const TRAMPOLINE_BOUNCE_SPEED_MULTIPLIER := 1.25
const TRAMPOLINE_MIN_UPWARD_SPEED := 9.0
# A full draw adds up to 30% of the global ball speed cap on top of the
# entry-based launch, and the launch itself may exceed that cap by up to 30%.
# The overspeed only survives the per-frame clamp because the launch also
# raises the transient "trampoline_launch_speed_cap" scene key consumed by
# ball_frame_motion_controller (meditation-release cap precedent).
const LAUNCH_DRAW_BONUS_CAP_RATIO := 0.30
const LAUNCH_OVERSPEED_CAP_RATIO := 1.30

# Slingshot capture: the ball is not reflected instantly. Each frame the
# descending ball overlaps the mat it keeps its motion but loses speed to a
# depth-scaled spring (the mat stretches with the ball), grips it for a few
# hold frames at full draw, then releases the stored entry speed upward.
# Velocity is shaped only through the normal per-frame collision event, so
# there is no skip_ball_motion_step ownership; if events stop arriving
# (stopwatch freeze, round reset, lateral exit) the per-frame watchdog in
# update_animations relaxes the capture instead of leaving a stuck state.
const BALL_HALF_SIZE := 14.3
const CAPTURE_MAX_SINK_DEPTH := 40.0
const CAPTURE_SPRING_BASE_DECEL := 0.30
const CAPTURE_SPRING_DEPTH_DECEL := 0.045
const CAPTURE_MIN_SINK_SPEED := 0.6
const CAPTURE_HOLD_FRAMES := 6.0
const CAPTURE_HOLD_CREEP_SPEED := 0.5
const CAPTURE_HOLD_GRIP_X_DAMP := 0.55
const CAPTURE_RELAX_PER_FRAME := 2.4
const SPAWN_PARTICLE_COUNT := 10
const BOUNCE_PARTICLE_COUNT := 8
const DESTROY_PARTICLE_COUNT := 16
const PARTICLE_LIFE_FRAMES := 26.0
const PARTICLE_GRAVITY_PER_FRAME := 0.22

const RIM_COLOR := Color(0.42, 0.86, 1.0)


func build_spawn_trampoline(owner: Object) -> Dictionary:
	var fallback_pos := Vector2(FIELD_WIDTH * 0.5 - PLAYER_BASE_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", fallback_pos)
	var paddle_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var center_x: float = player_pos.x + paddle_width * 0.5
	var x: float = clamp(center_x - TRAMPOLINE_WIDTH * 0.5, 0.0, max(0.0, FIELD_WIDTH - TRAMPOLINE_WIDTH))
	var y: float = clamp(TRAMPOLINE_MAT_TOP_Y, 0.0, max(0.0, FIELD_HEIGHT - TRAMPOLINE_HEIGHT))
	return {
		"rect": Rect2(Vector2(x, y), Vector2(TRAMPOLINE_WIDTH, TRAMPOLINE_HEIGHT)),
		"bounce_count": 0,
		"spawn_timer_frames": TRAMPOLINE_SPAWN_FRAMES,
		"bounce_timer_frames": 0.0,
	}


func get_bounce_velocity(ball_vel: Vector2, draw_ratio: float = 0.0) -> Vector2:
	var max_ball_speed: float = BallUpdateStaticConfig.MAX_BALL_SPEED
	var draw_bonus: float = clamp(draw_ratio, 0.0, 1.0) * LAUNCH_DRAW_BONUS_CAP_RATIO * max_ball_speed
	var upward: float = clamp(
		abs(ball_vel.y) * TRAMPOLINE_BOUNCE_SPEED_MULTIPLIER + draw_bonus,
		TRAMPOLINE_MIN_UPWARD_SPEED,
		max_ball_speed * LAUNCH_OVERSPEED_CAP_RATIO
	)
	return Vector2(ball_vel.x, -upward)


func apply_contact(
	trampolines: Array[Dictionary],
	particles: Array[Dictionary],
	trampoline_index: int,
	ball_pos: Vector2,
	ball_vel: Vector2
) -> Dictionary:
	if trampoline_index < 0 or trampoline_index >= trampolines.size():
		return {"phase": "none", "destroyed": false}

	var trampoline: Dictionary = trampolines[trampoline_index]
	var trampoline_rect: Rect2 = _get_rect2(trampoline, "rect")
	var depth: float = max(0.0, (ball_pos.y + BALL_HALF_SIZE) - trampoline_rect.position.y)
	var first_contact: bool = not bool(trampoline.get("capture_active", false))
	if first_contact:
		trampoline["capture_active"] = true
		trampoline["capture_entry_speed"] = abs(ball_vel.y)
		trampoline["capture_entry_vx"] = ball_vel.x
		trampoline["capture_hold_started"] = false
		trampoline["capture_hold_frames"] = CAPTURE_HOLD_FRAMES
		trampoline["capture_peak_depth"] = depth
		_spawn_particles(particles, trampoline_rect, ball_pos, 4, false)
	trampoline["capture_seen"] = true
	trampoline["capture_depth"] = depth
	trampoline["capture_peak_depth"] = max(float(trampoline.get("capture_peak_depth", 0.0)), depth)
	if trampoline_rect.size.x > 0.0:
		trampoline["capture_x_ratio"] = clamp(
			(ball_pos.x - trampoline_rect.position.x) / trampoline_rect.size.x, 0.1, 0.9
		)

	if not bool(trampoline.get("capture_hold_started", false)):
		var decel: float = CAPTURE_SPRING_BASE_DECEL + CAPTURE_SPRING_DEPTH_DECEL * depth
		var next_vy: float = ball_vel.y - decel
		# Predictive depth gate: enter the hold BEFORE the next frame's motion
		# would overshoot the cap, so the peak depth stays bounded and the ball
		# never sinks out of the capture band toward the floor.
		if next_vy > CAPTURE_MIN_SINK_SPEED and depth + next_vy < CAPTURE_MAX_SINK_DEPTH:
			return {
				"phase": "catch" if first_contact else "sinking",
				"ball_vel": Vector2(ball_vel.x, next_vy),
				"destroyed": false,
			}
		trampoline["capture_hold_started"] = true

	var hold_frames: float = float(trampoline.get("capture_hold_frames", 0.0)) - 1.0
	trampoline["capture_hold_frames"] = hold_frames
	if hold_frames > 0.0:
		return {
			"phase": "catch" if first_contact else "hold",
			"ball_vel": Vector2(ball_vel.x * CAPTURE_HOLD_GRIP_X_DAMP, CAPTURE_HOLD_CREEP_SPEED),
			"destroyed": false,
		}

	var entry_vector := Vector2(
		float(trampoline.get("capture_entry_vx", ball_vel.x)),
		float(trampoline.get("capture_entry_speed", abs(ball_vel.y)))
	)
	var draw_ratio: float = clamp(
		float(trampoline.get("capture_peak_depth", 0.0)) / CAPTURE_MAX_SINK_DEPTH, 0.0, 1.0
	)
	var launch_velocity: Vector2 = get_bounce_velocity(entry_vector, draw_ratio)
	_clear_capture_state(trampoline)

	var bounce_count: int = int(trampoline.get("bounce_count", 0)) + 1
	var destroyed: bool = bounce_count >= TRAMPOLINE_MAX_BOUNCES
	if destroyed:
		trampolines.remove_at(trampoline_index)
		_spawn_particles(particles, trampoline_rect, ball_pos, DESTROY_PARTICLE_COUNT, true)
	else:
		trampoline["bounce_count"] = bounce_count
		trampoline["bounce_timer_frames"] = TRAMPOLINE_BOUNCE_ANIM_FRAMES
		_spawn_particles(particles, trampoline_rect, ball_pos, BOUNCE_PARTICLE_COUNT, false)

	return {
		"phase": "launch",
		"destroyed": destroyed,
		"bounce_count": bounce_count,
		"bounce_velocity": launch_velocity,
	}


# capture_depth is intentionally NOT zeroed here: after a launch the renderer
# switches to the bounce_timer rebound, and after a watchdog abort the
# update-loop decay relaxes the mat smoothly instead of snapping it flat.
func _clear_capture_state(trampoline: Dictionary) -> void:
	trampoline["capture_active"] = false
	trampoline["capture_hold_started"] = false
	trampoline["capture_hold_frames"] = 0.0
	trampoline["capture_seen"] = false


func spawn_install_particles(particles: Array[Dictionary], trampoline_rect: Rect2) -> void:
	_spawn_particles(particles, trampoline_rect, trampoline_rect.get_center(), SPAWN_PARTICLE_COUNT, false)


func update_animations(
	trampolines: Array[Dictionary],
	particles: Array[Dictionary],
	delta: float
) -> void:
	var fps_scale: float = delta * 60.0
	for trampoline in trampolines:
		var spawn_timer: float = float(trampoline.get("spawn_timer_frames", 0.0))
		if spawn_timer > 0.0:
			trampoline["spawn_timer_frames"] = max(0.0, spawn_timer - fps_scale)
		var bounce_timer: float = float(trampoline.get("bounce_timer_frames", 0.0))
		if bounce_timer > 0.0:
			trampoline["bounce_timer_frames"] = max(0.0, bounce_timer - fps_scale)
		if bool(trampoline.get("capture_active", false)):
			# Watchdog: contact events feed capture_seen every frame. If the
			# ball stopped reaching the mat (freeze, reset, lateral exit),
			# relax the capture instead of holding a stretched mat forever.
			if bool(trampoline.get("capture_seen", false)):
				trampoline["capture_seen"] = false
			else:
				_clear_capture_state(trampoline)
		elif float(trampoline.get("capture_depth", 0.0)) > 0.0:
			trampoline["capture_depth"] = max(
				0.0,
				float(trampoline.get("capture_depth", 0.0)) - CAPTURE_RELAX_PER_FRAME * fps_scale
			)

	for particle_index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[particle_index]
		var timer: float = float(particle.get("timer_frames", 0.0)) - fps_scale
		if timer <= 0.0:
			particles.remove_at(particle_index)
			continue
		particle["timer_frames"] = timer
		var velocity: Vector2 = _get_vector2(particle, "velocity")
		velocity.y += PARTICLE_GRAVITY_PER_FRAME * fps_scale
		particle["velocity"] = velocity
		particle["position"] = _get_vector2(particle, "position") + velocity * fps_scale


func _spawn_particles(
	particles: Array[Dictionary],
	trampoline_rect: Rect2,
	origin: Vector2,
	count: int,
	burst: bool
) -> void:
	var base_pos := Vector2(
		clamp(origin.x, trampoline_rect.position.x, trampoline_rect.end.x),
		trampoline_rect.position.y
	)
	for i in range(count):
		var spread: float = randf_range(-1.0, 1.0)
		var speed: float = randf_range(1.4, 3.4) if burst else randf_range(0.8, 2.0)
		particles.append({
			"position": base_pos + Vector2(spread * trampoline_rect.size.x * 0.42, randf_range(-3.0, 2.0)),
			"velocity": Vector2(spread * speed, -randf_range(1.6, 3.2) * (1.6 if burst else 1.0)),
			"timer_frames": randf_range(PARTICLE_LIFE_FRAMES * 0.6, PARTICLE_LIFE_FRAMES),
			"initial_frames": PARTICLE_LIFE_FRAMES,
			"radius": randf_range(1.4, 2.8),
			"color": RIM_COLOR if randf() < 0.7 else Color(1.0, 0.96, 0.74),
		})


func _get_rect2(source: Dictionary, key: String) -> Rect2:
	var value: Variant = source.get(key, Rect2())
	if value is Rect2:
		return value
	return Rect2()


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO
