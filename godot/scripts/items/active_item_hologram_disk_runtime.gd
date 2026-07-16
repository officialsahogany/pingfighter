extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BALL_SIZE := 28.6
const BOSS_Y := 25.0
const LOWER_HALF_Y := FIELD_HEIGHT * 0.5
const DURATION_FRAMES := 300.0
const DECEPTION_CHANCE := 0.65
const DECOY_ANGLE_MIN := 0.1745329252
const DECOY_ANGLE_MAX := 0.3839724354
const DECOY_KILL_Y := BOSS_Y + 40.0
# 벽 반사 여백은 충돌 반지름(BALL_SIZE/2)이 아니라 '시각 최대 반경' 기준 —
# 분신은 순수 시각/기만 엔티티라, 에너지볼 미러의 외곽 글로우(렌더 반지름
# ×0.88×pulse≤1.08 ≈ 25.3px)가 필드 밖 필러 배경으로 새지 않는 것이
# 우선한다(item_runtime_checklist의 draw-geometry bounds 규칙).
const EnergyBallRendererScript := preload("res://scripts/ball/energy_ball_renderer.gd")
const DECOY_WALL_MARGIN := EnergyBallRendererScript.BALL_RENDER_RADIUS
const PHASE_ADVANCE_PER_FRAME := 0.11
const POP_LIFETIME_FRAMES := 12.0


func start_state(duration_multiplier: float = 1.0) -> Dictionary:
	var duration_frames: float = max(1.0, DURATION_FRAMES * max(0.0, duration_multiplier))
	return {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"phase": 0.0,
	}


func clear_state() -> Dictionary:
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"phase": 0.0,
		"locked_decoy_index": -1,
		"flight_active": false,
		"roll_locked": false,
		"last_ball_ascending": false,
		"clear_decoys": true,
		"clear_pop_particles": true,
	}


func apply_effects_update(target: Object, delta: float, state_applier: Object) -> void:
	if target == null or state_applier == null:
		return
	var fps_scale: float = max(0.0, delta * 60.0)
	_update_pop_particles(_get_array_property(target, "hologram_decoy_pop_particles"), fps_scale)
	var active: bool = bool(target.get("hologram_disk_active"))
	if not active and float(target.get("hologram_disk_timer_frames")) <= 0.0:
		return
	var next_timer: float = max(0.0, float(target.get("hologram_disk_timer_frames")) - fps_scale)
	if not active or next_timer <= 0.0:
		state_applier.apply_hologram_disk_state(target, clear_state())
		return
	state_applier.apply_hologram_disk_state(target, {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": float(target.get("hologram_disk_initial_timer_frames")),
		"phase": float(target.get("hologram_disk_phase")) + fps_scale * PHASE_ADVANCE_PER_FRAME,
	})


func apply_ball_path_tick(
	target: Object,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	if target == null or not bool(target.get("hologram_disk_active")):
		return {}
	if bool(context.get("waiting_for_serve", false)):
		_clear_decoys_and_lock(target)
		return {}
	if bool(context.get("skip_ball_motion_step", false)):
		return {}
	var real_ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var real_ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if real_ball_vel.length() < 0.01:
		return {}

	_advance_decoys(target, max(0.0, fps_scale), deps)

	var ascending: bool = real_ball_vel.y < 0.0
	if not ascending:
		_clear_deception_lock(target)
		target.set("hologram_last_ball_ascending", false)
		return {}

	var was_ascending: bool = bool(target.get("hologram_last_ball_ascending"))
	if not was_ascending and real_ball_pos.y >= LOWER_HALF_Y:
		_spawn_decoys(target, real_ball_pos, real_ball_vel, deps)
		_roll_deception_once(target)
	target.set("hologram_deception_flight_active", true)
	target.set("hologram_last_ball_ascending", true)
	return {}


func peek_deception_ball_context(target: Object) -> Dictionary:
	if target == null or not bool(target.get("hologram_disk_active")):
		return {"active": false}
	if not bool(target.get("hologram_deception_flight_active")):
		return {"active": false}
	var locked_index: int = int(target.get("hologram_locked_decoy_index"))
	var decoys: Array = _get_array_property(target, "hologram_decoys")
	if locked_index < 0 or locked_index >= decoys.size():
		return {"active": false}
	var decoy_value: Variant = decoys[locked_index]
	if not (decoy_value is Dictionary):
		return {"active": false}
	var decoy: Dictionary = decoy_value
	if not bool(decoy.get("alive", false)):
		return {"active": false}
	return {
		"active": true,
		"ball_pos": _get_vector2(decoy, "pos", Vector2.ZERO),
		"ball_vel": _get_vector2(decoy, "vel", Vector2.ZERO),
		"decoy_index": locked_index,
	}


func build_draw_context(target: Object) -> Dictionary:
	if target == null:
		return {}
	var decoys: Array[Dictionary] = []
	for decoy_value in _get_array_property(target, "hologram_decoys"):
		if decoy_value is Dictionary and bool(decoy_value.get("alive", false)):
			decoys.append((decoy_value as Dictionary).duplicate(true))
	var pop_particles: Array[Dictionary] = []
	for particle_value in _get_array_property(target, "hologram_decoy_pop_particles"):
		if particle_value is Dictionary:
			pop_particles.append((particle_value as Dictionary).duplicate(true))
	if not bool(target.get("hologram_disk_active")) and decoys.is_empty() and pop_particles.is_empty():
		return {}
	var initial_frames: float = max(1.0, float(target.get("hologram_disk_initial_timer_frames")))
	var timer_frames: float = float(target.get("hologram_disk_timer_frames"))
	return {
		"active": bool(target.get("hologram_disk_active")),
		"timer_frames": timer_frames,
		"initial_timer_frames": initial_frames,
		"remaining_ratio": clamp(timer_frames / initial_frames, 0.0, 1.0),
		"phase": float(target.get("hologram_disk_phase")),
		"decoys": decoys,
		"pop_particles": pop_particles,
		"locked_decoy_index": int(target.get("hologram_locked_decoy_index")),
	}


func has_visible_effects(target: Object) -> bool:
	if target == null:
		return false
	if bool(target.get("hologram_disk_active")):
		return true
	for decoy_value in _get_array_property(target, "hologram_decoys"):
		if decoy_value is Dictionary and bool(decoy_value.get("alive", false)):
			return true
	return not _get_array_property(target, "hologram_decoy_pop_particles").is_empty()


func _spawn_decoys(target: Object, real_ball_pos: Vector2, real_ball_vel: Vector2, deps: Dictionary = {}) -> void:
	var decoys: Array = _get_array_property(target, "hologram_decoys")
	# 설계 계약: 새 상승이 기존 분신을 대체할 때 살아있는 분신은 제자리에서
	# 글리치 팝(VFX+SFX)으로 소멸해야 한다 — 무음·무VFX 삭제 금지. 진행 중인
	# 팝 파티클도 지우지 않고 남은 수명대로 재생한다.
	for decoy_value in decoys:
		if decoy_value is Dictionary and bool(decoy_value.get("alive", false)):
			var pop_pos: Variant = decoy_value.get("pos", Vector2.ZERO)
			_spawn_pop_particle(target, pop_pos if pop_pos is Vector2 else Vector2.ZERO, float(decoy_value.get("flicker_seed", 0.0)))
			_play_pop_audio(deps)
	decoys.clear()
	target.set("hologram_locked_decoy_index", -1)
	target.set("hologram_deception_roll_locked", false)
	var speed: float = real_ball_vel.length()
	if speed < 0.01:
		return
	# 벽 근처 패들 히트의 최초 스폰 프레임도 시각 여백을 지켜야 한다 —
	# 클램프를 다음 advance 틱에만 맡기면 첫 렌더 프레임이 경계를 벗어난다.
	var spawn_pos := Vector2(
		clampf(real_ball_pos.x, DECOY_WALL_MARGIN, FIELD_WIDTH - DECOY_WALL_MARGIN),
		real_ball_pos.y
	)
	for side in [-1.0, 1.0]:
		var angle: float = randf_range(DECOY_ANGLE_MIN, DECOY_ANGLE_MAX) * float(side)
		var decoy_vel: Vector2 = real_ball_vel.rotated(angle)
		if decoy_vel.y >= -0.01:
			decoy_vel = Vector2(decoy_vel.x, -max(1.0, abs(decoy_vel.y))).normalized() * speed
		decoys.append({
			"pos": spawn_pos,
			"vel": decoy_vel,
			"alive": true,
			"flicker_seed": randf() * TAU,
			"age_frames": 0.0,
		})


func _roll_deception_once(target: Object) -> void:
	if bool(target.get("hologram_deception_roll_locked")):
		return
	target.set("hologram_deception_roll_locked", true)
	target.set("hologram_deception_roll_count", int(target.get("hologram_deception_roll_count")) + 1)
	var alive_indices: Array[int] = []
	var decoys: Array = _get_array_property(target, "hologram_decoys")
	for index in range(decoys.size()):
		var decoy_value: Variant = decoys[index]
		if decoy_value is Dictionary and bool(decoy_value.get("alive", false)):
			alive_indices.append(index)
	if alive_indices.is_empty():
		target.set("hologram_locked_decoy_index", -1)
		return
	var chance: float = _get_deception_chance(target)
	if randf() <= chance:
		target.set("hologram_locked_decoy_index", int(alive_indices[randi() % alive_indices.size()]))
	else:
		target.set("hologram_locked_decoy_index", -1)


func _advance_decoys(target: Object, fps_scale: float, deps: Dictionary) -> void:
	var decoys: Array = _get_array_property(target, "hologram_decoys")
	if decoys.is_empty():
		return
	var locked_index: int = int(target.get("hologram_locked_decoy_index"))
	for index in range(decoys.size()):
		var decoy_value: Variant = decoys[index]
		if not (decoy_value is Dictionary):
			continue
		var decoy: Dictionary = decoy_value
		if not bool(decoy.get("alive", false)):
			continue
		var pos: Vector2 = _get_vector2(decoy, "pos", Vector2.ZERO) + _get_vector2(decoy, "vel", Vector2.ZERO) * fps_scale
		var vel: Vector2 = _get_vector2(decoy, "vel", Vector2.ZERO)
		# 실 공 ball_pos는 '중심' 좌표 규약(충돌 rect가 -half 확장) — 분신도
		# 스폰 시 실 공 중심을 그대로 받으므로 벽 반사도 중심 기준. 여백은
		# 시각 최대 반경(DECOY_WALL_MARGIN — 충돌 반지름이면 글로우가 필드
		# 밖으로 ~11px 샌다). 반사는 경계 '스냅'이 아니라 초과분을 되접는
		# '미러' — 보스 AI 예측(_advance_x_with_walls)과 같은 반사 기하를
		# 써야 벽 반사 후 예측 도착 x가 분신 실궤적과 일치한다.
		if pos.x < DECOY_WALL_MARGIN:
			pos.x = clampf(DECOY_WALL_MARGIN * 2.0 - pos.x, DECOY_WALL_MARGIN, FIELD_WIDTH - DECOY_WALL_MARGIN)
			vel.x = abs(vel.x)
		elif pos.x > FIELD_WIDTH - DECOY_WALL_MARGIN:
			pos.x = clampf((FIELD_WIDTH - DECOY_WALL_MARGIN) * 2.0 - pos.x, DECOY_WALL_MARGIN, FIELD_WIDTH - DECOY_WALL_MARGIN)
			vel.x = -abs(vel.x)
		decoy["pos"] = pos
		decoy["vel"] = vel
		decoy["age_frames"] = float(decoy.get("age_frames", 0.0)) + fps_scale
		if pos.y <= DECOY_KILL_Y:
			decoy["alive"] = false
			_spawn_pop_particle(target, pos, float(decoy.get("flicker_seed", 0.0)))
			_play_pop_audio(deps)
			if index == locked_index:
				target.set("hologram_locked_decoy_index", -1)
		decoys[index] = decoy


func _spawn_pop_particle(target: Object, pos: Vector2, flicker_seed: float) -> void:
	_get_array_property(target, "hologram_decoy_pop_particles").append({
		"pos": pos,
		"age_frames": 0.0,
		"lifetime_frames": POP_LIFETIME_FRAMES,
		"flicker_seed": flicker_seed,
	})


func _update_pop_particles(pop_particles: Array, fps_scale: float) -> void:
	for index in range(pop_particles.size() - 1, -1, -1):
		var particle_value: Variant = pop_particles[index]
		if not (particle_value is Dictionary):
			pop_particles.remove_at(index)
			continue
		var particle: Dictionary = particle_value
		particle["age_frames"] = float(particle.get("age_frames", 0.0)) + fps_scale
		if float(particle.get("age_frames", 0.0)) >= float(particle.get("lifetime_frames", POP_LIFETIME_FRAMES)):
			pop_particles.remove_at(index)
		else:
			pop_particles[index] = particle


# 라운드 리셋 없이 공만 재실체화하는 경로(바이퍼 연습모드 재시도)용 공개
# 정리: 분신·팝·락·비행 상태를 지우되 효과 타이머는 유지한다.
func clear_decoys_and_lock_state(target: Object) -> void:
	_clear_decoys_and_lock(target)
	target.set("hologram_last_ball_ascending", false)


func _clear_decoys_and_lock(target: Object) -> void:
	_get_array_property(target, "hologram_decoys").clear()
	_get_array_property(target, "hologram_decoy_pop_particles").clear()
	_clear_deception_lock(target)


func _clear_deception_lock(target: Object) -> void:
	target.set("hologram_locked_decoy_index", -1)
	target.set("hologram_deception_flight_active", false)
	target.set("hologram_deception_roll_locked", false)


func _get_deception_chance(target: Object) -> float:
	var override: float = float(target.get("hologram_disk_deception_chance_override"))
	if override >= 0.0:
		return clamp(override, 0.0, 1.0)
	return DECEPTION_CHANCE


func _play_pop_audio(deps: Dictionary) -> void:
	# 볼 경로 frame_deps는 오디오를 "audio" 키로 싣는다 (ball_dependency_context).
	var audio: Object = deps.get("audio", null)
	if audio == null:
		audio = deps.get("game_audio", null)
	if audio == null:
		return
	if audio.has_method("play_hologram_decoy_pop"):
		audio.play_hologram_decoy_pop()
	elif audio.has_method("play_stage1_balloon_pop"):
		audio.play_stage1_balloon_pop()


func _get_array_property(target: Object, key: String) -> Array:
	var value: Variant = target.get(key)
	if value is Array:
		return value
	return []


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
