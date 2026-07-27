extends RefCounted

# Rahoset active skill: 모래감옥 / Sand Prison.
#
# The original Python SandPrison is used only for mood / sound reference. This
# Godot runtime is new gameplay: Rahoset builds a sand cage around the boss. The
# boss may escape while the cage is forming; on capture, boss_ai_state clamps the
# boss's final x into the cage while preserving normal AI velocity/collision.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetSandPrisonRenderer := preload("res://scripts/lingpet/lingpet_sand_prison_renderer.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DEFAULT_BOSS_PADDLE_WIDTH := 100.0
const DEFAULT_BOSS_HITBOX_HEIGHT := 40.0

const CLAMP_ACTIVE_KEY := "lingpet_sand_prison_clamp_active"
const CAGE_LEFT_KEY := "lingpet_sand_prison_cage_left"
const CAGE_RIGHT_KEY := "lingpet_sand_prison_cage_right"

const PHASE_CREATING := 0
const PHASE_IMPRISON := 1
const PHASE_DISSOLVE := 2
const PHASE_MISSING := 3
const PHASE_RETRY_WAIT := 4

const CREATION_SECONDS_BY_LEVEL: Array[float] = [1.5, 1.3, 1.1, 0.9, 0.7]
const IMPRISON_SECONDS_BY_LEVEL: Array[float] = [2.3, 2.725, 3.15, 3.575, 4.0]
const RETRY_DELAY_SECONDS := 0.5
const MISS_SECONDS := 0.45
const DISSOLVE_SECONDS := 0.5
const RETRY_CHANCE_LV3_4_PCT := 30.0
const RETRY_CHANCE_LV5_PCT := 50.0
const CAGE_HALF_MIN := 100.0
const CAGE_HALF_MAX := 150.0

const COMPANION_CAST_CREATE_PROGRESS_MAX := 0.56
const COMPANION_CAST_HOLD_PROGRESS := 0.72
const COMPANION_CAST_DISSOLVE_PROGRESS := 0.44

const SAND_PARTICLE_MAX := 64
const SAND_SPAWN_INTERVAL := 0.045

# Body->cage sand stream (원본 SandPrison body_particles 포팅, hero_skills.py:15368-15496):
# 시전자(라호세트) 몸(_cast_pos)에서 형성 중인 감옥으로 흘러가는 모래 가루. 건설
# 초반에 많고 후반에 줄며, 각 알갱이는 등속 직선(중력 없음)으로 날아 life 끝에 감옥에 도달.
const BODY_STREAM_RATE_EARLY := 180.0   # grains/sec at build start (raw 원본 ≈240/frame@60fps; 체감 튜닝값)
const BODY_STREAM_RATE_LATE := 60.0     # grains/sec near build end
const BODY_PARTICLE_MAX := 200
const BODY_WALL_DEST_CHANCE := 0.6
const BODY_TRAVEL_MIN := 0.5
const BODY_TRAVEL_MAX := 0.9

var _active := false
var _phase := PHASE_CREATING
var _phase_timer := 0.0
var _anim_time := 0.0
var _cast_pos := Vector2.ZERO
var _boss_size := Vector2(DEFAULT_BOSS_PADDLE_WIDTH, DEFAULT_BOSS_HITBOX_HEIGHT)
var _boss_y := 25.0
var _cage_center := FIELD_WIDTH * 0.5
var _cage_half := 125.0
var _cage_left := FIELD_WIDTH * 0.5 - 125.0
var _cage_right := FIELD_WIDTH * 0.5 + 125.0
var _active_skill_level := 1
# MISS 세척 연출: 보스가 도망친 방향(+1=오른쪽/-1=왼쪽)으로 모래바람이 쓸어간다.
var _wash_dir := 1.0
var _retries_remaining := 0
var _retry_roll_queue_for_tests: Array[bool] = []
var _shot_count := 0
var _retry_count := 0
var _miss_count := 0
var _capture_count := 0
var _missed := false
var _owns_clamp := false
var _sand_spawn_accum := 0.0
var _sand_particles: Array[Dictionary] = []
var _body_spawn_accum := 0.0
var _body_particles: Array[Dictionary] = []
var _renderer: Object = LingpetSandPrisonRenderer.new()


func prewarm() -> void:
	_renderer.prewarm()


func reset() -> void:
	_active = false
	_phase = PHASE_CREATING
	_phase_timer = 0.0
	_anim_time = 0.0
	_cast_pos = Vector2.ZERO
	_boss_size = Vector2(DEFAULT_BOSS_PADDLE_WIDTH, DEFAULT_BOSS_HITBOX_HEIGHT)
	_boss_y = 25.0
	_cage_center = FIELD_WIDTH * 0.5
	_cage_half = 125.0
	_cage_left = FIELD_WIDTH * 0.5 - 125.0
	_cage_right = FIELD_WIDTH * 0.5 + 125.0
	_active_skill_level = 1
	_wash_dir = 1.0
	_retries_remaining = 0
	_retry_roll_queue_for_tests.clear()
	_missed = false
	_owns_clamp = false
	_sand_spawn_accum = 0.0
	_sand_particles.clear()
	_body_spawn_accum = 0.0
	_body_particles.clear()


func cancel(owner: Object = null, _registry: Object = null) -> void:
	_active = false
	_sand_spawn_accum = 0.0
	if owner != null:
		_release(owner)
	elif not _owns_clamp:
		reset()
	# If cancel() has no owner while the cage owns the boss clamp, keep
	# _owns_clamp and the cage bounds so the next update(owner) can clear the
	# owner flags. This mirrors the shipped ownerless round-cleanup self-heal.


func reset_round(owner: Object = null, registry: Object = null) -> void:
	cancel(owner, registry)


func can_arm(params: Dictionary) -> bool:
	if is_active():
		return false
	if not bool(params.get("companion_visible", false)):
		return false
	return _is_companion_onscreen(_as_vector2(params.get("companion_pos", Vector2.ZERO), Vector2.ZERO))


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	if owner == null:
		return false
	_active_skill_level = clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)
	_retries_remaining = _get_max_retries_for_level(_active_skill_level)
	_retry_count = 0
	_shot_count = 0
	_miss_count = 0
	_capture_count = 0
	return _begin_summon(origin, owner)


func update(delta: float, owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if not _active:
		if _owns_clamp and owner != null:
			_release(owner)
		return
	var safe_delta := maxf(0.0, delta)
	_anim_time += safe_delta
	_phase_timer += safe_delta
	_update_particles(safe_delta)
	_update_ambient_sand(safe_delta)
	_update_body_stream(safe_delta)
	_advance_phase(owner, registry)
	if not _active:
		if _owns_clamp and owner != null:
			_release(owner)
		else:
			reset()
		return
	if _owns_clamp:
		_write_owner_clamp(owner)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not has_visible_effects():
		return
	_renderer.draw_sand_prison(
		canvas,
		shake_offset,
		_active,
		_phase == PHASE_CREATING,
		_phase == PHASE_DISSOLVE,
		_phase == PHASE_MISSING,
		_phase == PHASE_RETRY_WAIT,
		_phase_timer,
		_anim_time,
		_get_creation_seconds(),
		DISSOLVE_SECONDS,
		MISS_SECONDS,
		_cage_left,
		_cage_right,
		_get_cage_top(),
		_get_cage_bottom(),
		_wash_dir,
		_sand_particles,
		_body_particles
	)


func has_visible_effects() -> bool:
	return _active or not _sand_particles.is_empty() or not _body_particles.is_empty() or _owns_clamp


func is_active() -> bool:
	return _active or _owns_clamp


func has_companion_position_override() -> bool:
	return _active


func get_companion_position_override(fallback: Vector2) -> Vector2:
	return _cast_pos if _active else fallback


func get_companion_cast_pose_progress() -> float:
	if not _active:
		return -1.0
	match _phase:
		PHASE_CREATING:
			var p := clampf(_phase_timer / _get_creation_seconds(), 0.0, 1.0)
			return lerpf(0.0, COMPANION_CAST_CREATE_PROGRESS_MAX, p)
		PHASE_IMPRISON, PHASE_RETRY_WAIT, PHASE_MISSING:
			return COMPANION_CAST_HOLD_PROGRESS
		PHASE_DISSOLVE:
			return COMPANION_CAST_DISSOLVE_PROGRESS
		_:
			return -1.0


func get_snapshot() -> Dictionary:
	return {
		"sand_prison_active": _active,
		"sand_prison_phase": _phase,
		"sand_prison_phase_timer": _phase_timer,
		"sand_prison_creating": _phase == PHASE_CREATING,
		"sand_prison_imprison": _phase == PHASE_IMPRISON,
		"sand_prison_dissolve": _phase == PHASE_DISSOLVE,
		"sand_prison_missing": _phase == PHASE_MISSING,
		"sand_prison_retry_wait": _phase == PHASE_RETRY_WAIT,
		"sand_prison_cage_left": _cage_left,
		"sand_prison_cage_right": _cage_right,
		"sand_prison_cage_half": _cage_half,
		"sand_prison_cage_center": _cage_center,
		"sand_prison_active_skill_level": _active_skill_level,
		"sand_prison_creation_seconds": _get_creation_seconds(),
		"sand_prison_imprison_seconds": _get_imprison_seconds(),
		"sand_prison_retries_remaining": _retries_remaining,
		"sand_prison_retry_count": _retry_count,
		"sand_prison_shot_count": _shot_count,
		"sand_prison_miss_count": _miss_count,
		"sand_prison_capture_count": _capture_count,
		"sand_prison_missed": _missed,
		"sand_prison_owns_clamp": _owns_clamp,
		"sand_prison_retry_delay_seconds": RETRY_DELAY_SECONDS,
		"sand_prison_retry_chance_pct": _get_retry_chance_pct(_active_skill_level),
		"sand_prison_retry_rolls_queued": _retry_roll_queue_for_tests.size(),
		"sand_prison_particle_count": _sand_particles.size(),
		"sand_prison_body_particle_count": _body_particles.size(),
		"sand_prison_body_particle_cap": BODY_PARTICLE_MAX,
		"sand_prison_phase_creating": PHASE_CREATING,
		"sand_prison_phase_imprison": PHASE_IMPRISON,
		"sand_prison_phase_dissolve": PHASE_DISSOLVE,
		"sand_prison_phase_missing": PHASE_MISSING,
		"sand_prison_phase_retry_wait": PHASE_RETRY_WAIT,
	}


func set_retry_roll_queue_for_tests(values: Array) -> void:
	_retry_roll_queue_for_tests.clear()
	for value in values:
		_retry_roll_queue_for_tests.append(bool(value))


func force_cage_half_for_tests(value: float) -> void:
	_cage_half = clampf(value, CAGE_HALF_MIN, CAGE_HALF_MAX)


func get_capture_count_for_tests() -> int:
	return _capture_count


func get_miss_count_for_tests() -> int:
	return _miss_count


func get_shot_count_for_tests() -> int:
	return _shot_count


func get_retry_count_for_tests() -> int:
	return _retry_count


func get_body_particles_for_tests() -> Array:
	return _body_particles.duplicate(true)


func get_sand_particles_for_tests() -> Array:
	return _sand_particles.duplicate(true)


func get_wash_dir_for_tests() -> float:
	return _wash_dir


func get_visual_tuning_for_tests() -> Dictionary:
	return _renderer.get_visual_tuning_for_tests()


func _begin_summon(origin: Vector2, owner: Object = null) -> bool:
	_boss_size = Vector2(
		maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", DEFAULT_BOSS_PADDLE_WIDTH))),
		maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", DEFAULT_BOSS_HITBOX_HEIGHT)))
	)
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - DEFAULT_BOSS_PADDLE_WIDTH * 0.5, 25.0))
	var boss_center_x := boss_pos.x + _boss_size.x * 0.5
	_boss_y = boss_pos.y
	_cage_half = randf_range(CAGE_HALF_MIN, CAGE_HALF_MAX)
	_cage_center = clampf(boss_center_x, _cage_half, FIELD_WIDTH - _cage_half)
	_cage_left = _cage_center - _cage_half
	_cage_right = _cage_center + _cage_half
	_cast_pos = origin if origin != Vector2.ZERO else Vector2(_cage_center, FIELD_HEIGHT - 120.0)
	_active = true
	_missed = false
	_phase = PHASE_CREATING
	_phase_timer = 0.0
	_anim_time = 0.0
	_sand_spawn_accum = 0.0
	_sand_particles.clear()
	_body_spawn_accum = 0.0
	_body_particles.clear()
	_spawn_sand_burst(Vector2(_cage_left, _get_cage_bottom()), 10, 1.2)
	_spawn_sand_burst(Vector2(_cage_right, _get_cage_bottom()), 10, 1.2)
	_shot_count += 1
	_owns_clamp = false
	return true


func _advance_phase(owner: Object = null, registry: Object = null) -> void:
	while _active:
		match _phase:
			PHASE_CREATING:
				var create_seconds := _get_creation_seconds()
				if _phase_timer < create_seconds:
					return
				_phase_timer -= create_seconds
				if _capture_succeeds(owner):
					_capture_count += 1
					_phase = PHASE_IMPRISON
					_owns_clamp = true
					_write_owner_clamp(owner)
					_spawn_sand_burst(Vector2(_cage_left, _get_cage_mid_y()), 16, 1.4)
					_spawn_sand_burst(Vector2(_cage_right, _get_cage_mid_y()), 16, 1.4)
				else:
					_enter_miss_or_retry(owner, registry)
			PHASE_IMPRISON:
				var imprison_seconds := _get_imprison_seconds()
				if _phase_timer < imprison_seconds:
					return
				_phase_timer -= imprison_seconds
				if owner != null:
					_clear_owner_clamp(owner)
				_owns_clamp = false
				_phase = PHASE_DISSOLVE
				_spawn_sand_burst(Vector2(_cage_left, _get_cage_top()), 16, 1.6)
				_spawn_sand_burst(Vector2(_cage_right, _get_cage_top()), 16, 1.6)
			PHASE_DISSOLVE:
				if _phase_timer < DISSOLVE_SECONDS:
					return
				_active = false
				return
			PHASE_MISSING:
				if _phase_timer < MISS_SECONDS:
					return
				_active = false
				return
			PHASE_RETRY_WAIT:
				if _phase_timer < RETRY_DELAY_SECONDS:
					return
				_phase_timer -= RETRY_DELAY_SECONDS
				var retry_carry := _phase_timer
				_retry_count += 1
				_begin_summon(_cast_pos, owner)
				_phase_timer = retry_carry
				_play_audio(registry, "play_lingpet_sand_prison_cast")
			_:
				_active = false
				return


func _enter_miss_or_retry(owner: Object = null, registry: Object = null) -> void:
	_missed = true
	_miss_count += 1
	# 도망친 쪽으로 감옥이 모래바람에 쓸려나간다: 보스 중심이 감옥 중심의 어느 쪽인지로 방향 결정.
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(_cage_center - _boss_size.x * 0.5, _boss_y))
	var boss_center_x := boss_pos.x + _boss_size.x * 0.5
	_wash_dir = 1.0 if boss_center_x >= _cage_center else -1.0
	_spawn_wind_sweep()
	if _retries_remaining <= 0:
		_phase = PHASE_MISSING
		_phase_timer = 0.0
		return
	if _roll_retry():
		_retries_remaining -= 1
		_phase = PHASE_RETRY_WAIT
		_phase_timer = 0.0
	else:
		_retries_remaining = 0
		_phase = PHASE_MISSING
		_phase_timer = 0.0


func _capture_succeeds(owner: Object = null) -> bool:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(_cage_center - _boss_size.x * 0.5, _boss_y))
	var boss_center_x := boss_pos.x + _boss_size.x * 0.5
	return boss_center_x >= _cage_left and boss_center_x <= _cage_right


func _write_owner_clamp(owner: Object) -> bool:
	if owner == null:
		return false
	_owns_clamp = true
	owner.set(CLAMP_ACTIVE_KEY, true)
	owner.set(CAGE_LEFT_KEY, _cage_left)
	owner.set(CAGE_RIGHT_KEY, _cage_right)
	return true


func _clear_owner_clamp(owner: Object) -> bool:
	if owner == null:
		return false
	owner.set(CLAMP_ACTIVE_KEY, false)
	owner.set(CAGE_LEFT_KEY, 0.0)
	owner.set(CAGE_RIGHT_KEY, FIELD_WIDTH)
	return true


func _release(owner: Object) -> void:
	if owner != null:
		_clear_owner_clamp(owner)
	_owns_clamp = false
	reset()


func _get_creation_seconds() -> float:
	return CREATION_SECONDS_BY_LEVEL[clampi(_active_skill_level, 1, 5) - 1]


func _get_imprison_seconds() -> float:
	return IMPRISON_SECONDS_BY_LEVEL[clampi(_active_skill_level, 1, 5) - 1]


func _get_max_retries_for_level(level: int) -> int:
	if level >= 5:
		return 2
	if level >= 3:
		return 1
	return 0


func _get_retry_chance_pct(level: int) -> float:
	if level >= 5:
		return RETRY_CHANCE_LV5_PCT
	if level >= 3:
		return RETRY_CHANCE_LV3_4_PCT
	return 0.0


func _roll_retry() -> bool:
	if not _retry_roll_queue_for_tests.is_empty():
		return bool(_retry_roll_queue_for_tests.pop_front())
	return randf() < _get_retry_chance_pct(_active_skill_level) / 100.0


func _update_ambient_sand(delta: float) -> void:
	if _phase != PHASE_CREATING and _phase != PHASE_IMPRISON and _phase != PHASE_DISSOLVE:
		return
	_sand_spawn_accum -= delta
	if _sand_spawn_accum > 0.0:
		return
	_sand_spawn_accum = SAND_SPAWN_INTERVAL
	var y0 := _get_cage_bottom()
	var y1 := _get_cage_top()
	var left_pos := Vector2(_cage_left + randf_range(-3.0, 3.0), randf_range(y1, y0))
	var right_pos := Vector2(_cage_right + randf_range(-3.0, 3.0), randf_range(y1, y0))
	_spawn_particle(left_pos, Vector2(randf_range(-10.0, 12.0), randf_range(-40.0, -10.0)), randf_range(0.32, 0.55), randf_range(1.4, 2.8))
	_spawn_particle(right_pos, Vector2(randf_range(-12.0, 10.0), randf_range(-40.0, -10.0)), randf_range(0.32, 0.55), randf_range(1.4, 2.8))


func _update_particles(delta: float) -> void:
	for i in range(_sand_particles.size() - 1, -1, -1):
		var particle: Dictionary = _sand_particles[i]
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			_sand_particles.remove_at(i)
			continue
		particle["life"] = life
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * delta
		particle["vel"] = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) + Vector2(0.0, 36.0) * delta
		_sand_particles[i] = particle


func _spawn_sand_burst(center: Vector2, count: int, speed_scale: float) -> void:
	for _i in range(maxi(0, count)):
		var angle := randf_range(-PI, 0.0)
		var speed := randf_range(35.0, 105.0) * maxf(0.1, speed_scale)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		vel.x += randf_range(-24.0, 24.0)
		_spawn_particle(center + Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0)), vel, randf_range(0.38, 0.72), randf_range(1.5, 3.4))


func _spawn_wind_sweep() -> void:
	# MISS 순간의 모래바람: 벽/바닥에서 그레인이 도망 방향으로 쓸리며 아래로 가라앉는다.
	# life는 MISS_SECONDS(0.45s) 안에 다 소멸하도록 짧게 — 최종 MISS의 reset()이 클리어해도
	# 잘리는 알갱이가 없어야 자연스럽다.
	var top := _get_cage_top()
	var bottom := _get_cage_bottom()
	for wall_index in range(2):
		var wall_x := _cage_left if wall_index == 0 else _cage_right
		for _i in range(9):
			var pos := Vector2(wall_x + randf_range(-4.0, 4.0), randf_range(top, bottom))
			var vel := Vector2(_wash_dir * randf_range(70.0, 150.0), randf_range(8.0, 42.0))
			_spawn_particle(pos, vel, randf_range(0.25, 0.42), randf_range(1.6, 3.2))
	for _i in range(10):
		var pos := Vector2(randf_range(_cage_left, _cage_right), bottom + randf_range(-6.0, 2.0))
		var vel := Vector2(_wash_dir * randf_range(70.0, 150.0), randf_range(4.0, 30.0))
		_spawn_particle(pos, vel, randf_range(0.25, 0.42), randf_range(1.6, 3.2))


func _spawn_particle(pos: Vector2, vel: Vector2, life: float, radius: float) -> void:
	if _sand_particles.size() >= SAND_PARTICLE_MAX:
		_sand_particles.pop_front()
	_sand_particles.append({
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": maxf(0.01, life),
		"radius": radius,
		"color": Color(0.87 + randf_range(-0.04, 0.03), 0.67 + randf_range(-0.04, 0.03), 0.35 + randf_range(-0.04, 0.05), 0.95),
	})


func _update_body_stream(delta: float) -> void:
	# Emit only while the cage is BUILDING (mirrors the original body_particles);
	# always advance existing grains so a grain emitted at build's end can finish
	# its flight into early IMPRISON. Phase-timer driven (no wall-clock).
	if _phase == PHASE_CREATING:
		var create_p := clampf(_phase_timer / _get_creation_seconds(), 0.0, 1.0)
		var rate := lerpf(BODY_STREAM_RATE_EARLY, BODY_STREAM_RATE_LATE, create_p)
		_body_spawn_accum += delta * rate
		while _body_spawn_accum >= 1.0 and _body_particles.size() < BODY_PARTICLE_MAX:
			_body_spawn_accum -= 1.0
			_spawn_body_particle()
		_body_spawn_accum = minf(_body_spawn_accum, 8.0)
	else:
		_body_spawn_accum = 0.0
	for i in range(_body_particles.size() - 1, -1, -1):
		var particle: Dictionary = _body_particles[i]
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			_body_particles.remove_at(i)
			continue
		particle["life"] = life
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * delta
		_body_particles[i] = particle


func _spawn_body_particle() -> void:
	var start := _cast_pos + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
	var dest_x: float
	if randf() < BODY_WALL_DEST_CHANCE:
		var wall := _cage_left if randf() < 0.5 else _cage_right
		dest_x = wall + randf_range(-6.0, 6.0)
	else:
		dest_x = randf_range(_cage_left, _cage_right)
	var dest_y := randf_range(_get_cage_top(), _get_cage_bottom())
	var travel := randf_range(BODY_TRAVEL_MIN, BODY_TRAVEL_MAX)
	var vel := (Vector2(dest_x, dest_y) - start) / travel
	_body_particles.append({
		"pos": start,
		"vel": vel,
		"life": travel,
		"max_life": travel,
		"size": randf_range(1.5, 4.0),
		"init_alpha": randf_range(0.63, 0.94),
	})


func _get_cage_top() -> float:
	return clampf(_boss_y - 50.0, 0.0, FIELD_HEIGHT - 1.0)


func _get_cage_bottom() -> float:
	return clampf(_boss_y + _boss_size.y + 88.0, 12.0, FIELD_HEIGHT)


func _get_cage_mid_y() -> float:
	return (_get_cage_top() + _get_cage_bottom()) * 0.5


func _play_audio(registry: Object, method_name: String) -> void:
	if registry == null:
		return
	var audio: Object = null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance("game_audio")
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			audio = cached as Object
	if audio == null and registry.has_method("get_instance"):
		var value: Variant = registry.get_instance("game_audio")
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			audio = value as Object
	if audio == null:
		return
	if audio.has_method(method_name):
		audio.call(method_name)
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _get_owner_value(owner: Object, key: String, default_value: Variant = null) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, default_value)


func _get_owner_vector2(owner: Object, key: String, default_value: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, default_value)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _is_companion_onscreen(companion_pos: Vector2) -> bool:
	return companion_pos.x >= 0.0 and companion_pos.x <= FIELD_WIDTH and companion_pos.y >= 0.0 and companion_pos.y <= FIELD_HEIGHT
