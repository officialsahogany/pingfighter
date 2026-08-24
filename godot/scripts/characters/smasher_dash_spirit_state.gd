extends RefCounted

const SmasherDashSpiritRenderer := preload("res://scripts/characters/smasher_dash_spirit_renderer.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const PERK_ID := "dash_spirit"
const LASER_DURATION_BASE_FRAMES := 360.0
const LASER_DURATION_BONUS_PER_STAR := 0.20
const LASER_WIDTH := 8.0
const INVINCIBLE_FRAMES := 10.0
const FULL_DASH_FRAMES := 15.0
const DASH_FRAME_SPEED := 40.0
const DASH_DISTANCE_SCALE := 0.7
const LASER_DISTANCE_RATIO := 0.5
# 원본 수량 공식은 `min(60, max(30, laser_length // 5))`이라 한 번의 차단이
# 30~60개를 한꺼번에 띄운다. 원본 리스트에는 총량 상한이 아예 없다 —
# 상한을 1회 최대 버스트 근처로 잡으면 레이저 2개를 연달아 막았을 때
# `pop_front`가 앞 버스트를 산 채로 지운다(80이면 60+60 중 40개 소실).
# 파티클 수명이 60~120프레임이라 실제 동시 생존은 소수 버스트로 자연히 묶이고
# 드로우도 파티클당 1콜이라, 도달 불가능한 위치(최대 버스트 5회분)에 안전
# 가드만 둔다. 원본과의 유일한 차이이며 실플레이에서는 걸리지 않는다.
const EVAPORATION_PARTICLES_PER_PIXEL := 5.0
const EVAPORATION_PARTICLES_MIN := 30
const EVAPORATION_PARTICLES_MAX := 60
const MAX_EVAPORATION_PARTICLES := 300
const BALL_DEFAULT_SIZE := 28.6
const PLAYER_DEFAULT_SIZE := Vector2(155.0, 50.0)
# 레이저 Y는 패들 "중심"이 아니라 패들 "하단" 기준이다.
# 원본은 `PLAYER.centery + 30`인데, 원본 바닥선
# `_compute_player_floor_bottom()`이 확대 시 `PLAYER_VISUAL_OVERHANG(25) *
# (scale-1)`만큼 같이 내려간다. 오버행 25 == 기본 패들 반높이라 centery가
# 스케일과 무관하게 701로 고정되고, 결과적으로 원본 레이저는 챔피언 기준
# 화면 절대 y=731 = 바닥(750) - 19 에 항상 놓인다.
# Godot 패들은 크기가 바뀔 때마다 `player_pos.y = 750 - height`로 하단을
# 750에 재앵커하므로(오버행 개념 미포팅), 중심 기준 오프셋을 쓰면 확대 패들에서
# 레이저가 위로 뜬다(주니어 1.5배 -14px / 벌크업 1.2배 -5px). 하단에서
# 19px 위로 앵커해 모든 스케일에서 원본 절대 위치를 재현한다.
const PLAYER_BACK_LASER_FLOOR_INSET := 19.0
const REFLECT_X_MULT := 0.8
const UPWARD_ALREADY_MOVING_MULT := 1.2
const REFLECT_SPEED_BOOST := 1.3

var lasers: Array[Dictionary] = []
var evaporation_particles: Array[Dictionary] = []
var renderer: Object = SmasherDashSpiritRenderer.new()


func reset() -> void:
	lasers.clear()
	evaporation_particles.clear()


func reset_round() -> void:
	reset()


func try_spawn_from_dash(
	direction: float,
	is_half: bool,
	player_pos: Vector2,
	player_size: Vector2,
	deps: Dictionary,
	dash_frames: float = 0.0,
	dash_distance_multiplier: float = 1.0
) -> bool:
	# 원본은 하프대쉬 경로에 잔영호법 생성 호출 자체가 없다 — 굴림도 돌지 않는다.
	# (풀대쉬 5개 사이트에만 `create_dash_spirit_laser`가 있고, 하프대쉬 발동
	# 블록은 `rolling_timer`만 세팅한다.) 굴림 앞에서 끊어야 확률 소비까지 동일.
	if is_half:
		return false

	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	var chance: float = _get_dash_spirit_chance(runtime_perk_state)
	if chance <= 0.0 or randf() >= chance:
		return false

	var normalized_direction: float = -1.0 if direction < 0.0 else 1.0
	var safe_player_size: Vector2 = Vector2(
		max(1.0, player_size.x),
		max(1.0, player_size.y)
	)
	# 원본은 `set_roll("rolling_timer", int(skill_distance_boost))`으로 지속
	# 프레임을 먼저 정수화한 뒤 거리 공식에 넣는다. Godot 지속프레임은 실수라
	# (비천보 Lv.5 = 20.25) 그대로 곱하면 원본보다 1~3px 길어진다.
	var frames: float = floor(maxf(0.0, dash_frames))
	if frames <= 0.0:
		frames = FULL_DASH_FRAMES
	# 충돌 레이저 길이는 실 대쉬 거리와 함께 스케일해야 한다 — 신비의 주사위
	# dash_distance 배율이 실 이동만 늘리고 레이저가 base에 남으면 판정이
	# 시각 이동보다 짧아진다.
	var dash_distance: float = floor(frames * DASH_FRAME_SPEED * DASH_DISTANCE_SCALE * LASER_DISTANCE_RATIO * maxf(0.0, dash_distance_multiplier))
	var player_center: Vector2 = player_pos + safe_player_size * 0.5
	var star_level := _get_dash_spirit_star(runtime_perk_state)
	create_laser(
		player_center,
		normalized_direction,
		dash_distance,
		safe_player_size.x,
		safe_player_size.y,
		get_laser_duration_frames(star_level)
	)
	return true


func create_laser(
	player_center: Vector2,
	direction: float,
	dash_distance: float,
	paddle_width: float = PLAYER_DEFAULT_SIZE.x,
	paddle_height: float = PLAYER_DEFAULT_SIZE.y,
	duration_frames: float = LASER_DURATION_BASE_FRAMES
) -> Dictionary:
	var normalized_direction: float = -1.0 if direction < 0.0 else 1.0
	var half_width: float = floor(max(1.0, paddle_width) * 0.5)
	var start_x: float = player_center.x + half_width if normalized_direction < 0.0 else player_center.x - half_width
	var end_x: float = start_x + normalized_direction * max(0.0, dash_distance)
	# 확대 패들에서도 원본 절대 위치를 유지하려면 중심이 아니라 하단 기준이어야 한다.
	var paddle_bottom: float = player_center.y + max(1.0, paddle_height) * 0.5
	var y: float = paddle_bottom - PLAYER_BACK_LASER_FLOOR_INSET
	var safe_duration_frames := maxf(1.0, duration_frames)
	var laser: Dictionary = {
		"start": Vector2(start_x, y),
		"end": Vector2(end_x, y),
		"remaining_time": safe_duration_frames,
		"duration": safe_duration_frames,
		"direction": normalized_direction,
		"alpha": 255.0,
		"invincible_time": INVINCIBLE_FRAMES,
	}
	lasers.append(laser)
	return laser


func update_effects(fps_scale: float) -> void:
	_update_lasers(fps_scale)
	_update_evaporation_particles(fps_scale)


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if lasers.is_empty():
		return {}

	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_size: float = max(1.0, float(context.get("ball_size", BALL_DEFAULT_SIZE)))
	var ball_radius: float = ball_size * 0.5
	var threshold: float = ball_radius + floor(LASER_WIDTH * 0.5)
	for index in range(lasers.size()):
		var laser: Dictionary = lasers[index]
		if float(laser.get("invincible_time", 0.0)) > 0.0:
			continue
		if _distance_to_laser(ball_pos, laser) > threshold:
			continue

		var next_vel: Vector2 = _build_reflected_velocity(
			_get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO)),
			ball_pos,
			_get_player_center(context)
		)
		_create_laser_evaporation_effect(laser)
		lasers.remove_at(index)
		_play_delete_sound(deps)
		_trigger_feedback(deps)
		return {
			"ball_vel": next_vel,
			"dash_spirit_blocked": true,
		}
	return {}


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if renderer != null and renderer.has_method("draw"):
		renderer.draw(canvas, lasers, evaporation_particles, shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"lasers": lasers,
		"evaporation_particles": evaporation_particles,
	}


func has_visible_effects() -> bool:
	return not lasers.is_empty() or not evaporation_particles.is_empty()


func needs_effect_update() -> bool:
	return has_visible_effects()


func _get_dash_spirit_chance(runtime_perk_state: Object) -> float:
	if runtime_perk_state == null:
		return 0.0
	if runtime_perk_state.has_method("get_runtime_skill_bonus"):
		return max(0.0, float(runtime_perk_state.get_runtime_skill_bonus(PERK_ID)))
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0.0, RuntimePerkProgression.get_value(
			PERK_ID, "laser_chance", int(runtime_perk_state.get_runtime_skill_level(PERK_ID))
		))
	return 0.0


func _get_dash_spirit_star(runtime_perk_state: Object) -> int:
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return maxi(1, int(runtime_perk_state.get_runtime_skill_level(PERK_ID)))
	return 1


static func get_laser_duration_frames(star_level: int) -> float:
	var normalized_star := maxi(1, star_level)
	return LASER_DURATION_BASE_FRAMES * (
		1.0 + LASER_DURATION_BONUS_PER_STAR * float(normalized_star - 1)
	)


func _update_lasers(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(lasers.size()):
		var laser: Dictionary = lasers[read_index]
		var remaining: float = float(laser.get("remaining_time", 0.0)) - fps_scale
		laser["remaining_time"] = remaining
		laser["invincible_time"] = max(0.0, float(laser.get("invincible_time", 0.0)) - fps_scale)
		var duration: float = maxf(1.0, float(laser.get("duration", LASER_DURATION_BASE_FRAMES)))
		laser["alpha"] = 255.0 * clamp(remaining / duration, 0.0, 1.0)
		if remaining > 0.0:
			lasers[write_index] = laser
			write_index += 1
	if write_index < lasers.size():
		lasers.resize(write_index)


func _update_evaporation_particles(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(evaporation_particles.size()):
		var particle: Dictionary = evaporation_particles[read_index]
		var lifetime: float = float(particle.get("lifetime", 0.0)) - fps_scale
		var max_lifetime: float = max(1.0, float(particle.get("max_lifetime", 1.0)))
		if lifetime <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var velocity: Vector2 = _as_vector2(particle.get("velocity", Vector2.ZERO), Vector2.ZERO)
		pos += velocity * fps_scale
		# 원본 `particle['vx'] += random.uniform(-0.1, 0.1)` — 결정론적 사인파는
		# 진폭이 절반 이하라 수증기 특유의 흐트러짐이 죽는다.
		velocity.x = velocity.x * pow(0.98, fps_scale) + randf_range(-0.1, 0.1) * fps_scale
		velocity.y *= pow(0.99, fps_scale)
		var life_ratio: float = clamp(lifetime / max_lifetime, 0.0, 1.0)
		if life_ratio > 0.7:
			particle["size"] = float(particle.get("max_size", 1.0)) * (1.0 - (life_ratio - 0.7) / 0.3) * 0.8
		else:
			particle["size"] = float(particle.get("max_size", 1.0)) * life_ratio
		particle["alpha"] = int(180.0 * life_ratio)
		if int(particle.get("alpha", 0)) <= 0 or float(particle.get("size", 0.0)) <= 0.0:
			continue
		particle["pos"] = pos
		particle["velocity"] = velocity
		particle["lifetime"] = lifetime
		evaporation_particles[write_index] = particle
		write_index += 1
	if write_index < evaporation_particles.size():
		evaporation_particles.resize(write_index)


func _distance_to_laser(point: Vector2, laser: Dictionary) -> float:
	var start: Vector2 = _as_vector2(laser.get("start", Vector2.ZERO), Vector2.ZERO)
	var end: Vector2 = _as_vector2(laser.get("end", Vector2.ZERO), Vector2.ZERO)
	var segment: Vector2 = end - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(start)
	var t: float = clamp((point - start).dot(segment) / length_sq, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _build_reflected_velocity(ball_vel: Vector2, ball_pos: Vector2, player_center: Vector2) -> Vector2:
	var reflected: Vector2 = ball_vel
	if reflected.y > 0.0:
		reflected.y = -abs(reflected.y)
	else:
		reflected.y *= UPWARD_ALREADY_MOVING_MULT
	if ball_pos.x < player_center.x:
		reflected.x = abs(reflected.x) * REFLECT_X_MULT
	else:
		reflected.x = -abs(reflected.x) * REFLECT_X_MULT
	return reflected * REFLECT_SPEED_BOOST


func _create_laser_evaporation_effect(laser: Dictionary) -> void:
	var start: Vector2 = _as_vector2(laser.get("start", Vector2.ZERO), Vector2.ZERO)
	var end: Vector2 = _as_vector2(laser.get("end", Vector2.ZERO), Vector2.ZERO)
	var laser_length: float = abs(end.x - start.x)
	# 원본 `min(60, max(30, laser_length // 5))` — 210px면 42개, 154px면 30개다.
	var particle_count: int = mini(
		EVAPORATION_PARTICLES_MAX,
		maxi(EVAPORATION_PARTICLES_MIN, int(floor(laser_length / EVAPORATION_PARTICLES_PER_PIXEL)))
	)
	for _i in range(particle_count):
		var t: float = randf()
		var spawn_pos := Vector2(
			lerp(start.x, end.x, t),
			start.y + randf_range(-5.0, 5.0)
		)
		var size: float = randf_range(2.0, 5.0)
		var lifetime: float = float(randi_range(60, 120))
		evaporation_particles.append({
			"pos": spawn_pos,
			"velocity": Vector2(randf_range(-0.5, 0.5), randf_range(-2.5, -1.0)),
			"size": size,
			"max_size": size * 2.0,
			"lifetime": lifetime,
			"max_lifetime": lifetime,
			"color": Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
			"alpha": 180,
		})
	while evaporation_particles.size() > MAX_EVAPORATION_PARTICLES:
		evaporation_particles.pop_front()


func _play_delete_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_dash_spirit_delete"):
		audio.play_dash_spirit_delete()


func _trigger_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.10, 3.2)


func _get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", PLAYER_DEFAULT_SIZE)
	return player_pos + player_size * 0.5


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
