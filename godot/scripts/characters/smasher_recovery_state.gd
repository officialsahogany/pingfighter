extends RefCounted

const SmasherRecoveryRenderer := preload("res://scripts/characters/smasher_recovery_renderer.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const SKILL_NAME := "recovery"
const GAUGE_COST := 120.0
const EFFECT_DURATION_FRAMES := 18.0
const BOOST_DURATION_FRAMES := 300.0
const EXTENSION_GEAR_DURATION_BONUS := 0.25
const SPEED_BOOST_PERCENT := 0.50
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const MAX_BURST_PARTICLES := 36
const MAX_LIGHT_PARTICLES := 40
const MAX_DUST_PUFFS := 12
const LIGHT_PARTICLE_SPAWN_CHANCE := 0.72
const DUST_PUFF_SPAWN_CHANCE := 0.22

var up_key_released := true
var effect_timer_frames := 0.0
var effect_center := Vector2.ZERO
var flash_alpha := 0.0
var wave_rings: Array[Dictionary] = []
var burst_particles: Array[Dictionary] = []
var speed_boost_timer_frames := 0.0
var speed_boost_total_frames := BOOST_DURATION_FRAMES
var light_particles: Array[Dictionary] = []
# 흙먼지 = 이 이펙트의 질량 담당. 빛 레이어만으로는 선만 남고 무게가 사라진다.
var dust_puffs: Array[Dictionary] = []
var _last_player_pos := Vector2(760.0 * 0.5, 700.0)
var _last_player_size := DEFAULT_PLAYER_SIZE
var _last_move_direction := 1.0
var _renderer: Object = SmasherRecoveryRenderer.new()


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	return bool(_renderer.prewarm_step())


func reset() -> void:
	up_key_released = true
	effect_timer_frames = 0.0
	effect_center = Vector2.ZERO
	flash_alpha = 0.0
	wave_rings.clear()
	burst_particles.clear()
	speed_boost_timer_frames = 0.0
	speed_boost_total_frames = BOOST_DURATION_FRAMES
	light_particles.clear()
	dust_puffs.clear()
	_last_move_direction = 1.0


func reset_round() -> void:
	reset()


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
	}

	var up_pressed: bool = bool(input_snapshot.get("up_pressed", false))
	if not up_pressed:
		up_key_released = true
		return result
	if not up_key_released:
		return result
	up_key_released = false

	if not _can_activate(current_msec, special_gauge, config, deps):
		return result

	var next_gauge: float = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null)))
	_clear_dash_recovery(deps)
	_trigger_recovery_effect(player_pos, config, deps)
	_trigger_cooldown(current_msec, deps)

	result["special_gauge"] = next_gauge
	result["activated"] = true
	return result


func update_effects(fps_scale: float, context: Dictionary, _deps: Dictionary) -> void:
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	_update_recovery_burst(fps_scale)
	_update_speed_boost(fps_scale, context)
	_update_dust_puffs(fps_scale)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, timer_stack: Object = null) -> void:
	if canvas == null:
		return
	var visual_time_msec: float = float(Time.get_ticks_msec())
	_renderer.draw(
		canvas,
		shake_offset,
		timer_stack,
		visual_time_msec,
		effect_center,
		effect_timer_frames,
		EFFECT_DURATION_FRAMES,
		flash_alpha,
		speed_boost_timer_frames,
		speed_boost_total_frames,
		_last_player_pos,
		_last_player_size,
		_last_move_direction,
		wave_rings,
		burst_particles,
		light_particles,
		dust_puffs
	)


func is_boost_active() -> bool:
	return speed_boost_timer_frames > 0.0


func get_player_speed_multiplier() -> float:
	if speed_boost_timer_frames <= 0.0:
		return 1.0
	return 1.0 + SPEED_BOOST_PERCENT


func get_boost_remaining_seconds() -> float:
	return max(0.0, speed_boost_timer_frames) / 60.0


func get_boost_ratio() -> float:
	if speed_boost_total_frames <= 0.0:
		return 0.0
	return clamp(speed_boost_timer_frames / speed_boost_total_frames, 0.0, 1.0)


func has_visible_effects() -> bool:
	return (
		speed_boost_timer_frames > 0.0
		or flash_alpha > 0.01
		or not wave_rings.is_empty()
		or not burst_particles.is_empty()
		or not light_particles.is_empty()
		or not dust_puffs.is_empty()
	)


func needs_effect_update() -> bool:
	return has_visible_effects()


func _can_activate(current_msec: int, special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if _is_power_motion_locked(deps):
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	if not _is_dash_recovering(config, deps):
		return false
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return false
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return false
	return true


func _is_dash_recovering(config: Dictionary, deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("is_recovering"):
		return bool(dash_state.is_recovering())
	var dash_snapshot: Variant = config.get("dash_snapshot", {})
	if dash_snapshot is Dictionary:
		return bool(dash_snapshot.get("recovering", false)) or float(dash_snapshot.get("stun_timer", 0.0)) > 0.0
	return false


func _clear_dash_recovery(deps: Dictionary) -> void:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("clear_recovery"):
		dash_state.clear_recovery()
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_dash_delay"):
		audio.stop_dash_delay()


func _trigger_recovery_effect(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	effect_center = player_pos + Vector2(_last_player_size.x * 0.5, _last_player_size.y * 0.38)
	effect_timer_frames = EFFECT_DURATION_FRAMES
	flash_alpha = 0.96
	wave_rings.clear()
	burst_particles.clear()
	for i in range(3):
		wave_rings.append({
			"radius": 14.0 + float(i) * 10.0,
			"speed": 6.8 + float(i) * 1.6,
			"alpha": 0.90 - float(i) * 0.13,
			"width": 4.0 - float(i) * 0.6,
		})
	for _i in range(24):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(3.6, 9.8)
		burst_particles.append({
			"pos": effect_center + Vector2(cos(angle), sin(angle)) * randf_range(3.0, 18.0),
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, randf_range(-1.8, 0.5)),
			"life": 0.0,
			"max_life": randf_range(18.0, 32.0),
			"size": randf_range(2.4, 6.6),
			"hue": randf_range(0.0, 1.0),
		})
	if burst_particles.size() > MAX_BURST_PARTICLES:
		while burst_particles.size() > MAX_BURST_PARTICLES:
			burst_particles.pop_front()

	dust_puffs.clear()
	for puff_index in range(4):
		var spread: float = (float(puff_index) - 1.5) / 1.5
		dust_puffs.append({
			"pos": effect_center + Vector2(spread * _last_player_size.x * 0.46, randf_range(-2.0, 8.0)),
			"vel": Vector2(spread * randf_range(1.5, 2.9), randf_range(-1.15, -0.35)),
			"life": 0.0,
			"max_life": randf_range(26.0, 40.0),
			"size": randf_range(108.0, 152.0),
			"alpha": randf_range(0.68, 0.88),
			"spin": randf_range(-0.24, 0.24),
			"spin_rate": randf_range(-0.36, 0.36),
			"mirrored": spread < 0.0,
		})

	speed_boost_total_frames = _get_boost_duration_frames(deps)
	speed_boost_timer_frames = speed_boost_total_frames
	light_particles.clear()
	_play_recovery_audio(deps)
	_trigger_feedback(deps)


func _update_recovery_burst(fps_scale: float) -> void:
	if effect_timer_frames > 0.0:
		effect_timer_frames = max(0.0, effect_timer_frames - fps_scale)
	flash_alpha = max(0.0, flash_alpha - 0.075 * fps_scale)

	var ring_write_index := 0
	for ring_read_index in range(wave_rings.size()):
		var ring: Dictionary = wave_rings[ring_read_index]
		var alpha: float = float(ring.get("alpha", 0.0)) - 0.045 * fps_scale
		if alpha <= 0.01:
			continue
		ring["alpha"] = alpha
		ring["radius"] = float(ring.get("radius", 0.0)) + float(ring.get("speed", 0.0)) * fps_scale
		ring["width"] = max(1.0, float(ring.get("width", 1.0)) - 0.025 * fps_scale)
		wave_rings[ring_write_index] = ring
		ring_write_index += 1
	if ring_write_index < wave_rings.size():
		wave_rings.resize(ring_write_index)

	var burst_write_index := 0
	for burst_read_index in range(burst_particles.size()):
		var particle: Dictionary = burst_particles[burst_read_index]
		var life: float = float(particle.get("life", 0.0)) + fps_scale
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		if life >= max_life:
			continue
		var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		vel = vel * pow(0.955, fps_scale) + Vector2(0.0, -0.035 * fps_scale)
		particle["vel"] = vel
		particle["pos"] = _as_vector2(particle.get("pos", effect_center), effect_center) + vel * fps_scale
		particle["life"] = life
		burst_particles[burst_write_index] = particle
		burst_write_index += 1
	if burst_write_index < burst_particles.size():
		burst_particles.resize(burst_write_index)


func _update_speed_boost(fps_scale: float, context: Dictionary) -> void:
	if speed_boost_timer_frames > 0.0:
		speed_boost_timer_frames = max(0.0, speed_boost_timer_frames - fps_scale)
		var player_speed: float = float(context.get("player_speed", 0.0))
		if abs(player_speed) > 0.25:
			_last_move_direction = sign(player_speed)
		if _is_player_moving(context):
			_spawn_light_particles(fps_scale)
			_spawn_dust_puff(fps_scale)

	var light_write_index := 0
	for light_read_index in range(light_particles.size()):
		var particle: Dictionary = light_particles[light_read_index]
		var life: float = float(particle.get("life", 0.0)) + fps_scale
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		if life >= max_life:
			continue
		var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		vel = vel * pow(0.97, fps_scale) + Vector2(0.0, -0.025 * fps_scale)
		particle["vel"] = vel
		particle["pos"] = _as_vector2(particle.get("pos", _last_player_pos), _last_player_pos) + vel * fps_scale
		particle["life"] = life
		light_particles[light_write_index] = particle
		light_write_index += 1
	if light_write_index < light_particles.size():
		light_particles.resize(light_write_index)


func _spawn_light_particles(fps_scale: float) -> void:
	if randf() > LIGHT_PARTICLE_SPAWN_CHANCE * clamp(fps_scale, 0.35, 1.35):
		return
	var spawn_count: int = 1
	if randf() < 0.18 * clamp(fps_scale, 0.35, 1.35):
		spawn_count += 1
	var center: Vector2 = _last_player_pos + _last_player_size * 0.5
	for _i in range(spawn_count):
		var side: float = -1.0 if randf() < 0.5 else 1.0
		var spawn_pos: Vector2 = center + Vector2(
			side * randf_range(_last_player_size.x * 0.20, _last_player_size.x * 0.55),
			randf_range(-_last_player_size.y * 0.25, _last_player_size.y * 0.35)
		)
		light_particles.append({
			"pos": spawn_pos,
			"vel": Vector2(randf_range(-0.55, 0.55), randf_range(-1.85, -0.35)),
			"life": 0.0,
			"max_life": randf_range(22.0, 42.0),
			"size": randf_range(1.8, 4.4),
			"hue": randf_range(0.0, 1.0),
		})
	if light_particles.size() > MAX_LIGHT_PARTICLES:
		while light_particles.size() > MAX_LIGHT_PARTICLES:
			light_particles.pop_front()


func _spawn_dust_puff(fps_scale: float) -> void:
	if randf() > DUST_PUFF_SPAWN_CHANCE * clamp(fps_scale, 0.35, 1.35):
		return
	# 밟고 지나간 자리에서 피어오르므로 진행 반대쪽 발치에 놓는다.
	var heel_x: float = _last_player_pos.x + _last_player_size.x * (0.5 - _last_move_direction * 0.33)
	dust_puffs.append({
		"pos": Vector2(heel_x + randf_range(-7.0, 7.0), _last_player_pos.y + _last_player_size.y * 0.72),
		"vel": Vector2(-_last_move_direction * randf_range(0.55, 1.45), randf_range(-0.85, -0.25)),
		"life": 0.0,
		"max_life": randf_range(20.0, 32.0),
		"size": randf_range(62.0, 94.0),
		"alpha": randf_range(0.44, 0.62),
		"spin": randf_range(-0.3, 0.3),
		"spin_rate": randf_range(-0.28, 0.28),
		"mirrored": _last_move_direction > 0.0,
	})
	if dust_puffs.size() > MAX_DUST_PUFFS:
		while dust_puffs.size() > MAX_DUST_PUFFS:
			dust_puffs.pop_front()


func _update_dust_puffs(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(dust_puffs.size()):
		var puff: Dictionary = dust_puffs[read_index]
		var life: float = float(puff.get("life", 0.0)) + fps_scale
		var max_life: float = max(1.0, float(puff.get("max_life", 1.0)))
		if life >= max_life:
			continue
		var vel: Vector2 = _as_vector2(puff.get("vel", Vector2.ZERO), Vector2.ZERO)
		vel = vel * pow(0.935, fps_scale)
		puff["vel"] = vel
		puff["pos"] = _as_vector2(puff.get("pos", _last_player_pos), _last_player_pos) + vel * fps_scale
		puff["life"] = life
		dust_puffs[write_index] = puff
		write_index += 1
	if write_index < dust_puffs.size():
		dust_puffs.resize(write_index)


func _is_player_moving(context: Dictionary) -> bool:
	if abs(float(context.get("player_speed", 0.0))) > 0.25:
		return true
	var dash_snapshot: Variant = context.get("dash_snapshot", {})
	return dash_snapshot is Dictionary and bool(dash_snapshot.get("active", false))


func _get_boost_duration_frames(deps: Dictionary) -> float:
	var extension_level: int = _get_runtime_skill_level(deps, "extension_gear")
	return BOOST_DURATION_FRAMES * (1.0 + RuntimePerkProgression.get_value("extension_gear", "duration_bonus", extension_level))


func _get_runtime_skill_level(deps: Dictionary, skill_id: String) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return int(runtime_perk_state.get_runtime_skill_level(skill_id))
	return 0


func _get_cooldown_remaining(current_msec: int, deps: Dictionary) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_configured_cooldown_remaining"):
		return 0.0
	return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
	return false


func _is_power_motion_locked(deps: Dictionary) -> bool:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null:
		return false
	if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
		return true
	if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
		return true
	return false


func _play_recovery_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_recovery"):
		audio.play_recovery()


func _trigger_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.13, 4.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _get_player_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", DEFAULT_PLAYER_SIZE.x))),
		max(1.0, float(config.get("paddle_height", DEFAULT_PLAYER_SIZE.y)))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
