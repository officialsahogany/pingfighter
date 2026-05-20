extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const SKILL_NAME := "recovery"
const GAUGE_COST := 120.0
const EFFECT_DURATION_FRAMES := 18.0
const BOOST_DURATION_FRAMES := 300.0
const EXTENSION_GEAR_DURATION_BONUS := 0.25
const SPEED_BOOST_PERCENT := 0.50
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const MAX_BURST_PARTICLES := 36
const MAX_LIGHT_PARTICLES := 40
const MAX_RENDERED_BURST_PARTICLES := 24
const MAX_RENDERED_LIGHT_PARTICLES := 28
const LIGHT_PARTICLE_SPAWN_CHANCE := 0.72
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "recovery_boost"
const TIMER_STACK_INDEX := 0

var up_key_released := true
var effect_timer_frames := 0.0
var effect_center := Vector2.ZERO
var flash_alpha := 0.0
var wave_rings: Array[Dictionary] = []
var burst_particles: Array[Dictionary] = []
var speed_boost_timer_frames := 0.0
var speed_boost_total_frames := BOOST_DURATION_FRAMES
var light_particles: Array[Dictionary] = []
var _last_player_pos := Vector2(760.0 * 0.5, 700.0)
var _last_player_size := DEFAULT_PLAYER_SIZE


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


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


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, timer_stack: Object = null) -> void:
	if canvas == null:
		return
	_draw_speed_trail(canvas, shake_offset)
	_draw_recovery_burst(canvas, shake_offset)
	_draw_speed_boost_timer(canvas, timer_stack)


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
	effect_center = player_pos + _last_player_size * 0.5
	effect_timer_frames = EFFECT_DURATION_FRAMES
	flash_alpha = 0.82
	wave_rings.clear()
	burst_particles.clear()
	for i in range(3):
		wave_rings.append({
			"radius": 14.0 + float(i) * 10.0,
			"speed": 5.5 + float(i) * 1.4,
			"alpha": 0.82 - float(i) * 0.14,
			"width": 4.0 - float(i) * 0.6,
		})
	for _i in range(16):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(2.5, 7.6)
		burst_particles.append({
			"pos": effect_center + Vector2(cos(angle), sin(angle)) * randf_range(3.0, 18.0),
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, randf_range(-1.8, 0.5)),
			"life": 0.0,
			"max_life": randf_range(16.0, 30.0),
			"size": randf_range(2.0, 5.5),
			"hue": randf_range(0.0, 1.0),
		})
	if burst_particles.size() > MAX_BURST_PARTICLES:
		while burst_particles.size() > MAX_BURST_PARTICLES:
			burst_particles.pop_front()

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
		if _is_player_moving(context):
			_spawn_light_particles(fps_scale)

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


func _draw_recovery_burst(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var center := effect_center + shake_offset
	if flash_alpha > 0.01:
		ImpactFlareTextureCache.draw_glow(
			canvas,
			center,
			44.0 + (1.0 - flash_alpha) * 18.0,
			Color(0.58, 1.0, 0.75),
			flash_alpha * 0.18
		)
	for ring in wave_rings:
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center,
			float(ring.get("radius", 12.0)),
			Color(0.35, 1.0, 0.68),
			float(ring.get("alpha", 0.0)) * 0.58
		)
	var particle_start: int = max(0, burst_particles.size() - MAX_RENDERED_BURST_PARTICLES)
	for index in range(particle_start, burst_particles.size()):
		var particle: Dictionary = burst_particles[index]
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(1.0 - life / max_life, 0.0, 1.0)
		var size: float = max(0.8, float(particle.get("size", 2.0)) * (0.65 + alpha * 0.55))
		var color: Color = _get_recovery_particle_color(float(particle.get("hue", 0.0)), alpha)
		ImpactFlareTextureCache.draw_sparkle(canvas, _as_vector2(particle.get("pos", effect_center), effect_center) + shake_offset, size * 1.45, color, min(0.72, color.a))


func _draw_speed_trail(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var particle_start: int = max(0, light_particles.size() - MAX_RENDERED_LIGHT_PARTICLES)
	for index in range(particle_start, light_particles.size()):
		var particle: Dictionary = light_particles[index]
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(1.0 - life / max_life, 0.0, 1.0)
		var size: float = max(0.6, float(particle.get("size", 2.0)) * (0.55 + alpha * 0.55))
		var color: Color = _get_trail_particle_color(float(particle.get("hue", 0.0)), alpha)
		ImpactFlareTextureCache.draw_sparkle(canvas, _as_vector2(particle.get("pos", _last_player_pos), _last_player_pos) + shake_offset, size * 1.35, color, min(0.52, color.a))


func _draw_speed_boost_timer(canvas: CanvasItem, timer_stack: Object = null) -> void:
	if speed_boost_timer_frames <= 0.0:
		return
	var ratio: float = get_boost_ratio()
	var remaining_seconds: float = speed_boost_timer_frames / 60.0
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(18.0 / 255.0, 42.0 / 255.0, 34.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(42.0 / 255.0, 150.0 / 255.0, 105.0 / 255.0, 0.92))
	canvas.draw_rect(mid_rect, Color(145.0 / 255.0, 1.0, 190.0 / 255.0, 0.80), false, 2.0)
	canvas.draw_rect(border_rect, Color(12.0 / 255.0, 28.0 / 255.0, 24.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.03, 0.08, 0.06, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 3.0:
		base_color = Color(65.0 / 255.0, 1.0, 145.0 / 255.0, 0.98)
		highlight_color = Color(170.0 / 255.0, 1.0, 210.0 / 255.0, 0.98)
	elif remaining_seconds > 1.5:
		base_color = Color(70.0 / 255.0, 230.0 / 255.0, 120.0 / 255.0, 0.98)
		highlight_color = Color(1.0, 230.0 / 255.0, 110.0 / 255.0, 0.95)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
		base_color = Color((130.0 + 80.0 * pulse) / 255.0, (210.0 + 45.0 * pulse) / 255.0, (75.0 + 55.0 * pulse) / 255.0, 0.99)
		highlight_color = Color(1.0, (210.0 + 35.0 * pulse) / 255.0, (90.0 + 75.0 * pulse) / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(150.0 / 255.0, 230.0 / 255.0, 185.0 / 255.0, 0.84),
			1.0
		)

	var icon_size := Vector2(19.0, 19.0)
	var icon_center := frame_rect.position + Vector2(-19.0, frame_rect.size.y * 0.5)
	var icon_pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.012))
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, 16.0, Color(0.0, 0.0, 0.0), 0.26)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, icon_center, 13.0, Color(85.0 / 255.0, 1.0, 150.0 / 255.0), 0.34 + 0.22 * icon_pulse)
	canvas.draw_line(icon_center + Vector2(-icon_size.x * 0.35, icon_size.y * 0.12), icon_center + Vector2(icon_size.x * 0.15, -icon_size.y * 0.28), Color(0.72, 1.0, 0.82, 0.95), 3.0, true)
	canvas.draw_line(icon_center + Vector2(icon_size.x * 0.15, -icon_size.y * 0.28), icon_center + Vector2(icon_size.x * 0.35, icon_size.y * 0.10), Color(0.72, 1.0, 0.82, 0.95), 3.0, true)


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		760.0 - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		750.0 - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * TIMER_STACK_SPACING
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _get_recovery_particle_color(hue: float, alpha: float) -> Color:
	if hue < 0.34:
		return Color(0.28, 1.0, 0.62, 0.82 * alpha)
	if hue < 0.68:
		return Color(1.0, 0.86, 0.36, 0.74 * alpha)
	return Color(0.92, 1.0, 0.84, 0.82 * alpha)


func _get_trail_particle_color(hue: float, alpha: float) -> Color:
	if hue < 0.45:
		return Color(0.18, 1.0, 0.62, 0.54 * alpha)
	if hue < 0.78:
		return Color(1.0, 0.82, 0.34, 0.45 * alpha)
	return Color(0.70, 1.0, 0.90, 0.50 * alpha)


func _is_player_moving(context: Dictionary) -> bool:
	if abs(float(context.get("player_speed", 0.0))) > 0.25:
		return true
	var dash_snapshot: Variant = context.get("dash_snapshot", {})
	return dash_snapshot is Dictionary and bool(dash_snapshot.get("active", false))


func _get_boost_duration_frames(deps: Dictionary) -> float:
	var extension_level: int = _get_runtime_skill_level(deps, "extension_gear")
	return BOOST_DURATION_FRAMES * (1.0 + EXTENSION_GEAR_DURATION_BONUS * float(extension_level))


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
		feedback.set_screen_shake(0.10, 3.0)
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
