extends RefCounted

const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")

# ⚠️`start_msec` 는 시간 앵커가 아니라 `_seeded_rng(start_msec + ...)` 의 **시드**다.
# 여기에 모달 시프트를 걸면 순간이동 패턴이 비행 도중에 바뀐다 — 시프트 대상은
# 실제 경과 비교에 쓰이는 앵커뿐이다.
const PENDING_TELEPORT_MODAL_TIME_KEYS: Array[String] = ["arrive_msec"]
const BLACKHOLE_MODAL_TIME_KEYS: Array[String] = ["start_msec"]

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BALL_RADIUS := 14.3
const PHASE1_END := 0.40
const CHAOS_START_Y := 500.0
const PHASE2_END := 2.60
const PHASE2_INTERVAL := 0.15
const TELEPORT_DELAY_MSEC := 180
const BLACKHOLE_IN_DURATION_MSEC := 400
const BLACKHOLE_OUT_DURATION_MSEC := 500
const FINAL_FIRE_SPEED := 18.0
const FINAL_FIRE_ANGLE_DEG := 40.0
const HIDDEN_BALL_POS := Vector2(-1000.0, -1000.0)
const GHOST_COUNT := 8
const TRAJECTORY_MAX_POINTS := 24
const TRAJECTORY_MIN_DISTANCE := 10.0
const TRAJECTORY_INITIAL_ALPHA := 0.76
const TRAJECTORY_FADE_SPEED := 0.030

var active := false
var start_msec := 0
var chaos_start_elapsed := -1.0
var motion_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pending_teleport: Dictionary = {}
var performance_teleport_times: Array[float] = []
var performance_teleports_initialized := false
var performance_teleports_done: Dictionary = {}
var blackhole_effects: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var trajectory_points: Array[Dictionary] = []
var scatter_active := false
var scatter_timer_frames := 0.0
var last_visible_ball_pos := Vector2.ZERO


func reset(clear_visuals: bool = true) -> void:
	active = false
	start_msec = 0
	chaos_start_elapsed = -1.0
	pending_teleport.clear()
	performance_teleport_times.clear()
	performance_teleports_initialized = false
	performance_teleports_done.clear()
	scatter_active = false
	scatter_timer_frames = 0.0
	last_visible_ball_pos = Vector2.ZERO
	if clear_visuals:
		blackhole_effects.clear()
		ghosts.clear()
		trajectory_points.clear()


func begin(current_msec: int) -> void:
	reset(false)
	active = true
	start_msec = current_msec
	chaos_start_elapsed = -1.0
	motion_rng.seed = int(abs(current_msec)) + 424242
	pending_teleport.clear()
	performance_teleport_times.clear()
	performance_teleports_initialized = false
	performance_teleports_done.clear()
	scatter_active = false
	scatter_timer_frames = 0.0
	ghosts.clear()
	trajectory_points.clear()


func is_active() -> bool:
	return active


# 퍽 모달 동안 벽시계 앵커 동결. 소유자(smasher_power_smash_state)가 정지 마커를
# 들고 여기로 흘려준다. 규칙은 runtime_perk_modal_time_shift.gd 참조.
func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	RuntimePerkModalTimeShift.shift_dict_anchors(pending_teleport, PENDING_TELEPORT_MODAL_TIME_KEYS, delta_msec)
	RuntimePerkModalTimeShift.shift_dict_array_anchors(blackhole_effects, BLACKHOLE_MODAL_TIME_KEYS, delta_msec)


func has_pending_teleport() -> bool:
	return not pending_teleport.is_empty()


func is_motion_active() -> bool:
	return active or has_pending_teleport()


func finish_motion(clear_visuals: bool = true) -> void:
	active = false
	pending_teleport.clear()
	performance_teleport_times.clear()
	performance_teleports_initialized = false
	performance_teleports_done.clear()
	if clear_visuals:
		ghosts.clear()
		trajectory_points.clear()


func apply_motion(scene: Dictionary, fps_scale: float, elapsed: float, arc_strength: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)

	if has_pending_teleport():
		return _apply_pending_teleport(current_msec)
	if not active:
		return {}

	last_visible_ball_pos = ball_pos
	if chaos_start_elapsed < 0.0:
		if ball_pos.y > CHAOS_START_Y and elapsed < PHASE2_END:
			return _apply_rise_phase(ball_pos, ball_vel, fps_scale, arc_strength)
		chaos_start_elapsed = elapsed
	if elapsed < PHASE2_END:
		return _apply_chaos_phase(ball_pos, ball_vel, fps_scale, elapsed, current_msec)
	return _schedule_final_teleport(ball_pos, arc_strength, current_msec, context, deps)


func update_effects(fps_scale: float, ball_pos: Vector2, ball_active: bool, ball_size: float) -> void:
	var current_msec: int = Time.get_ticks_msec()
	_update_blackholes(current_msec)
	_update_trajectory(fps_scale, ball_pos, ball_active, ball_size)
	_update_ghosts(fps_scale, ball_pos, ball_active, ball_size)


func scatter_from(origin: Vector2) -> void:
	# Boss counter dismisses the ghost shot. Stop emitting new trajectory points
	# and stop reporting the aura / motion-active flags before the dispersing
	# ghosts and any in-flight trajectory points are allowed to fade out.
	active = false
	pending_teleport.clear()
	performance_teleport_times.clear()
	performance_teleports_initialized = false
	performance_teleports_done.clear()
	last_visible_ball_pos = origin
	if ghosts.is_empty():
		_ensure_ghosts(origin, BALL_RADIUS * 2.0)
	for i in range(ghosts.size()):
		var ghost: Dictionary = ghosts[i]
		var angle: float = float(i) * TAU / max(1.0, float(ghosts.size()))
		ghost["pos"] = origin
		ghost["vel"] = Vector2(cos(angle), sin(angle)) * randf_range(5.0, 9.0)
		ghost["alpha"] = 0.75
		ghost["size"] = randf_range(10.0, 18.0)
		ghosts[i] = ghost
	scatter_active = true
	scatter_timer_frames = 42.0


func get_ghosts() -> Array[Dictionary]:
	return ghosts


func get_blackhole_effects() -> Array[Dictionary]:
	return blackhole_effects


func get_trajectory_points() -> Array[Dictionary]:
	return trajectory_points


func get_last_visible_ball_pos() -> Vector2:
	return last_visible_ball_pos


func has_visible_aura() -> bool:
	return active and not has_pending_teleport()


func has_visible_effects() -> bool:
	return (
		has_visible_aura()
		or not blackhole_effects.is_empty()
		or not ghosts.is_empty()
		or not trajectory_points.is_empty()
	)


func _apply_pending_teleport(current_msec: int) -> Dictionary:
	var arrive_msec: int = int(pending_teleport.get("arrive_msec", current_msec))
	if current_msec < arrive_msec:
		return {
			"ball_pos": HIDDEN_BALL_POS,
			"ball_vel": Vector2.ZERO,
			"skip_ball_motion_step": true,
		}

	var target: Vector2 = _get_vector2(pending_teleport.get("target", Vector2.ZERO), Vector2.ZERO)
	var fire_on_arrive: bool = bool(pending_teleport.get("fire_on_arrive", false))
	var fire_velocity: Vector2 = _get_vector2(pending_teleport.get("fire_velocity", Vector2.ZERO), Vector2.ZERO)
	pending_teleport.clear()
	last_visible_ball_pos = target
	if fire_on_arrive:
		active = false
		ghosts.clear()
		return {
			"ball_pos": target,
			"ball_vel": fire_velocity,
			"skip_ball_motion_step": false,
			"finish_power_motion": true,
		}
	return {
		"ball_pos": target,
		"ball_vel": Vector2.ZERO,
		"skip_ball_motion_step": true,
	}


func _apply_rise_phase(ball_pos: Vector2, ball_vel: Vector2, fps_scale: float, arc_strength: float) -> Dictionary:
	ball_vel.x = arc_strength * 8.0
	ball_vel.y = -14.0
	var next_x: float = ball_pos.x + ball_vel.x * fps_scale
	if next_x <= BALL_RADIUS or next_x >= FIELD_WIDTH - BALL_RADIUS:
		ball_vel.x = abs(ball_vel.x) + 2.0 if next_x <= BALL_RADIUS else -(abs(ball_vel.x) + 2.0)
	return {
		"ball_vel": ball_vel,
		"skip_ball_motion_step": false,
	}


func _get_chaos_start_elapsed() -> float:
	if chaos_start_elapsed >= 0.0:
		return chaos_start_elapsed
	return PHASE1_END


func _apply_chaos_phase(ball_pos: Vector2, ball_vel: Vector2, fps_scale: float, elapsed: float, current_msec: int) -> Dictionary:
	_initialize_performance_teleports()
	for i in range(performance_teleport_times.size()):
		if bool(performance_teleports_done.get(i, false)):
			continue
		if elapsed >= float(performance_teleport_times[i]):
			performance_teleports_done[i] = true
			var target: Vector2 = _get_performance_teleport_target(i)
			_spawn_blackhole(ball_pos, target, current_msec)
			pending_teleport = {
				"target": target,
				"arrive_msec": current_msec + TELEPORT_DELAY_MSEC,
				"fire_on_arrive": false,
			}
			return {
				"ball_pos": HIDDEN_BALL_POS,
				"ball_vel": Vector2.ZERO,
				"skip_ball_motion_step": true,
			}

	var phase2_time: float = max(0.0, elapsed - _get_chaos_start_elapsed())
	var interval_index: int = int(floor(phase2_time / PHASE2_INTERVAL))
	var interval_progress: float = clamp(fmod(phase2_time, PHASE2_INTERVAL) / PHASE2_INTERVAL, 0.0, 1.0)
	var phase_rng: RandomNumberGenerator = _seeded_rng(start_msec + interval_index * 7919)
	var current_target: Vector2 = Vector2(
		phase_rng.randf_range(BALL_RADIUS, FIELD_WIDTH - BALL_RADIUS),
		phase_rng.randf_range(180.0, FIELD_HEIGHT * 0.5 + 100.0)
	)
	var next_rng: RandomNumberGenerator = _seeded_rng(start_msec + (interval_index + 1) * 7919)
	var next_target: Vector2 = Vector2(
		next_rng.randf_range(BALL_RADIUS, FIELD_WIDTH - BALL_RADIUS),
		next_rng.randf_range(180.0, FIELD_HEIGHT * 0.5 + 100.0)
	)
	var interpolated_target: Vector2 = current_target.lerp(next_target, interval_progress)
	var desired: Vector2 = interpolated_target - ball_pos
	if desired.length() > 1.0:
		var chaos_speed: float = phase_rng.randf_range(24.0, 36.0)
		ball_vel = desired.normalized() * chaos_speed
		if motion_rng.randf() < 0.20:
			ball_vel = ball_vel.rotated(motion_rng.randf_range(-1.2, 1.2))

	var next_pos: Vector2 = ball_pos + ball_vel * fps_scale
	if next_pos.x <= BALL_RADIUS or next_pos.x >= FIELD_WIDTH - BALL_RADIUS:
		ball_vel.x = abs(ball_vel.x) if next_pos.x <= BALL_RADIUS else -abs(ball_vel.x)
	if next_pos.y <= 5.0 or next_pos.y >= FIELD_HEIGHT - 100.0:
		ball_vel.y = abs(ball_vel.y) if next_pos.y <= 5.0 else -abs(ball_vel.y)

	return {
		"ball_vel": ball_vel,
		"skip_ball_motion_step": false,
	}


func _schedule_final_teleport(ball_pos: Vector2, arc_strength: float, current_msec: int, context: Dictionary, deps: Dictionary) -> Dictionary:
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2(FIELD_WIDTH * 0.5, 60.0)), Vector2(FIELD_WIDTH * 0.5, 60.0))
	var final_rng: RandomNumberGenerator = _seeded_rng(start_msec + 99991)
	var side: float = -1.0 if final_rng.randf() < 0.5 else 1.0
	var target_x: float = clamp(boss_pos.x + side * final_rng.randf_range(250.0, 400.0), 35.0, FIELD_WIDTH - 35.0)
	var target_y: float = final_rng.randf_range(200.0, 260.0)
	var target := Vector2(target_x, target_y)
	var angle_spread: float = deg_to_rad(FINAL_FIRE_ANGLE_DEG)
	var amplifier: int = _get_combo_amplifier_level(deps)
	if amplifier > 0:
		angle_spread *= max(0.45, 1.0 - float(amplifier) * 0.08)
	var base_angle: float = -PI * 0.5
	var final_angle: float = base_angle + final_rng.randf_range(-angle_spread, angle_spread)
	var speed: float = FINAL_FIRE_SPEED * (1.0 + float(amplifier) * 0.10)
	var fire_velocity: Vector2 = Vector2(cos(final_angle), sin(final_angle)) * speed
	if abs(arc_strength) > 0.05:
		fire_velocity.x += arc_strength * 2.4

	_spawn_blackhole(ball_pos, target, current_msec)
	pending_teleport = {
		"target": target,
		"arrive_msec": current_msec + TELEPORT_DELAY_MSEC,
		"fire_on_arrive": true,
		"fire_velocity": fire_velocity,
	}
	active = false
	return {
		"ball_pos": HIDDEN_BALL_POS,
		"ball_vel": Vector2.ZERO,
		"skip_ball_motion_step": true,
	}


func _initialize_performance_teleports() -> void:
	if performance_teleports_initialized:
		return
	performance_teleports_initialized = true
	var rng: RandomNumberGenerator = _seeded_rng(start_msec + 12345)
	var count: int = rng.randi_range(1, 2)
	var first_teleport_time: float = min(_get_chaos_start_elapsed() + 0.28, PHASE2_END - 0.28)
	for _i in range(count):
		performance_teleport_times.append(rng.randf_range(first_teleport_time, PHASE2_END - 0.28))
	performance_teleport_times.sort()


func _get_performance_teleport_target(index: int) -> Vector2:
	var rng: RandomNumberGenerator = _seeded_rng(start_msec + 24680 + index * 313)
	return Vector2(
		rng.randf_range(30.0, FIELD_WIDTH - 30.0),
		rng.randf_range(180.0, FIELD_HEIGHT * 0.5 + 80.0)
	)


func _spawn_blackhole(from_pos: Vector2, to_pos: Vector2, current_msec: int) -> void:
	blackhole_effects.append({
		"pos": from_pos,
		"start_msec": current_msec,
		"duration_msec": BLACKHOLE_IN_DURATION_MSEC,
		"kind": "in",
	})
	blackhole_effects.append({
		"pos": to_pos,
		"start_msec": current_msec + 50,
		"duration_msec": BLACKHOLE_OUT_DURATION_MSEC,
		"kind": "out",
	})


func _update_blackholes(current_msec: int) -> void:
	if blackhole_effects.is_empty():
		return
	var write_idx: int = 0
	for i in range(blackhole_effects.size()):
		var effect: Dictionary = blackhole_effects[i]
		var start: int = int(effect.get("start_msec", current_msec))
		var duration: int = max(1, int(effect.get("duration_msec", 1)))
		if current_msec <= start + duration:
			blackhole_effects[write_idx] = effect
			write_idx += 1
	blackhole_effects.resize(write_idx)


func _update_trajectory(fps_scale: float, ball_pos: Vector2, ball_active: bool, ball_size: float) -> void:
	if not trajectory_points.is_empty():
		var write_idx: int = 0
		for i in range(trajectory_points.size()):
			var point: Dictionary = trajectory_points[i]
			point["alpha"] = max(0.0, float(point.get("alpha", 0.0)) - TRAJECTORY_FADE_SPEED * fps_scale)
			point["size"] = max(1.0, float(point.get("size", ball_size)) * pow(0.992, fps_scale))
			if float(point.get("alpha", 0.0)) > 0.025:
				trajectory_points[write_idx] = point
				write_idx += 1
		trajectory_points.resize(write_idx)

	if not active or not ball_active or has_pending_teleport():
		return
	if ball_pos.x < -100.0 or ball_pos.y < -100.0:
		return
	_append_trajectory_point(ball_pos, ball_size)


func _append_trajectory_point(ball_pos: Vector2, ball_size: float) -> void:
	var sample_size: float = max(12.0, ball_size * 0.72)
	var now: float = Time.get_ticks_msec() / 1000.0
	if not trajectory_points.is_empty():
		var last_index: int = trajectory_points.size() - 1
		var last_point: Dictionary = trajectory_points[last_index]
		var last_pos: Vector2 = _get_vector2(last_point.get("pos", Vector2.ZERO), Vector2.ZERO)
		if last_pos.distance_to(ball_pos) < TRAJECTORY_MIN_DISTANCE:
			last_point["pos"] = ball_pos
			last_point["alpha"] = TRAJECTORY_INITIAL_ALPHA
			last_point["size"] = sample_size
			last_point["phase"] = now
			trajectory_points[last_index] = last_point
			return
	trajectory_points.append({
		"pos": ball_pos,
		"alpha": TRAJECTORY_INITIAL_ALPHA,
		"size": sample_size,
		"phase": now,
	})
	while trajectory_points.size() > TRAJECTORY_MAX_POINTS:
		trajectory_points.remove_at(0)


func _update_ghosts(fps_scale: float, ball_pos: Vector2, ball_active: bool, ball_size: float) -> void:
	if scatter_active:
		scatter_timer_frames = max(0.0, scatter_timer_frames - fps_scale)
		for i in range(ghosts.size()):
			var ghost: Dictionary = ghosts[i]
			var vel: Vector2 = _get_vector2(ghost.get("vel", Vector2.ZERO), Vector2.ZERO)
			ghost["pos"] = _get_vector2(ghost.get("pos", Vector2.ZERO), Vector2.ZERO) + vel * fps_scale
			ghost["vel"] = vel * pow(0.92, fps_scale)
			ghost["alpha"] = max(0.0, float(ghost.get("alpha", 0.0)) - 0.025 * fps_scale)
			ghosts[i] = ghost
		var write_idx: int = 0
		for i in range(ghosts.size()):
			var ghost: Dictionary = ghosts[i]
			if float(ghost.get("alpha", 0.0)) > 0.02:
				ghosts[write_idx] = ghost
				write_idx += 1
		ghosts.resize(write_idx)
		if scatter_timer_frames <= 0.0 or ghosts.is_empty():
			scatter_active = false
			ghosts.clear()
		return

	if not active or not ball_active or has_pending_teleport():
		if not active:
			ghosts.clear()
		return

	_ensure_ghosts(ball_pos, ball_size)
	var now: float = Time.get_ticks_msec() / 1000.0
	var radius_base: float = max(12.0, ball_size * 0.52)
	for i in range(ghosts.size()):
		var ghost: Dictionary = ghosts[i]
		var angle: float = now * (5.6 + float(i % 3) * 0.55) + float(i) * TAU / max(1.0, float(ghosts.size()))
		var radius: float = radius_base + sin(now * 7.0 + float(i)) * 9.0
		ghost["pos"] = ball_pos + Vector2(cos(angle), sin(angle)) * radius
		ghost["alpha"] = 0.26 + 0.24 * sin(now * 8.2 + float(i) * 0.8)
		ghost["size"] = max(6.0, ball_size * (0.22 + 0.04 * sin(now * 2.1 + float(i))))
		ghosts[i] = ghost
	last_visible_ball_pos = ball_pos


func _ensure_ghosts(origin: Vector2, ball_size: float) -> void:
	if ghosts.size() >= GHOST_COUNT:
		return
	ghosts.clear()
	for i in range(GHOST_COUNT):
		ghosts.append({
			"pos": origin,
			"vel": Vector2.ZERO,
			"alpha": 0.18,
			"size": max(6.0, ball_size * 0.22),
			"phase": float(i),
		})


func _get_combo_amplifier_level(deps: Dictionary) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return int(runtime_perk_state.get_runtime_skill_level("combo_amplifier_chip"))
	return 0


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(seed_value)) + 1
	return rng


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
