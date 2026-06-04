extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const SKILL_NAME := "cleanse"
const GAUGE_COST := 100.0
const CAST_DURATION_FRAMES := 30.0
const IMMUNITY_DURATION_FRAMES := 300.0
const COUNTER_WINDOW_FRAMES := 120.0
const COUNTER_SPEED_BONUS := 1.015
const EXTENSION_GEAR_DURATION_BONUS := 0.25
const SHIELD_TRANSITION_FRAMES := 20.0
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const MAX_CAST_PARTICLES := 36
const MAX_RENDERED_CAST_PARTICLES := 24
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "cleanse_immunity"
const TIMER_STACK_INDEX := 0

var up_key_released := true
var active := false
var cast_timer_frames := 0.0
var immunity_timer_frames := 0.0
var immunity_total_frames := IMMUNITY_DURATION_FRAMES
var counter_window_frames := 0.0
var shield_transition_timer_frames := 0.0
var shield_fully_formed := false
var flash_alpha := 0.0
var center := Vector2.ZERO
var wave_rings: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var _last_player_pos := Vector2(760.0 * 0.5, 700.0)
var _last_player_size := DEFAULT_PLAYER_SIZE
var _prewarm_assets_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_step_index == 0:
		if not bool(ImpactFlareTextureCache.prewarm_step()):
			return false
		_prewarm_assets_step_index = 1
	if _prewarm_assets_step_index == 1:
		if not bool(ImpactShockwaveTextureCache.prewarm_step()):
			return false
		_prewarm_assets_step_index = 0
		return true
	_prewarm_assets_step_index = 0
	return true


func reset() -> void:
	up_key_released = true
	active = false
	cast_timer_frames = 0.0
	immunity_timer_frames = 0.0
	immunity_total_frames = IMMUNITY_DURATION_FRAMES
	counter_window_frames = 0.0
	shield_transition_timer_frames = 0.0
	shield_fully_formed = false
	flash_alpha = 0.0
	center = Vector2.ZERO
	wave_rings.clear()
	particles.clear()


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
	_clear_status_effects(deps)
	_trigger_cleanse(player_pos, config, deps)
	_trigger_cooldown(current_msec, deps)

	result["special_gauge"] = next_gauge
	result["activated"] = true
	return result


func update_effects(fps_scale: float, context: Dictionary, _deps: Dictionary) -> void:
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	if immunity_timer_frames > 0.0:
		immunity_timer_frames = max(0.0, immunity_timer_frames - fps_scale)
	if counter_window_frames > 0.0:
		counter_window_frames = max(0.0, counter_window_frames - fps_scale)
	if active:
		cast_timer_frames = max(0.0, cast_timer_frames - fps_scale)
	_update_cast_effect(fps_scale)
	if active and cast_timer_frames <= 0.0:
		active = false
		wave_rings.clear()
		particles.clear()
		if immunity_timer_frames > 0.0 and not shield_fully_formed:
			shield_transition_timer_frames = SHIELD_TRANSITION_FRAMES
	if shield_transition_timer_frames > 0.0:
		shield_transition_timer_frames = max(0.0, shield_transition_timer_frames - fps_scale)
		if shield_transition_timer_frames <= 0.0:
			shield_fully_formed = true
	if immunity_timer_frames <= 0.0:
		shield_transition_timer_frames = 0.0
		shield_fully_formed = false


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, timer_stack: Object = null) -> void:
	if canvas == null:
		return
	_draw_cast_effect(canvas, shake_offset)
	_draw_immunity_shield(canvas, shake_offset)
	_draw_immunity_timer(canvas, timer_stack)


func is_immune() -> bool:
	return immunity_timer_frames > 0.0


func has_status_effect(deps: Dictionary, config: Dictionary = {}) -> bool:
	return _has_status_effect(deps, config)


func get_immunity_remaining_seconds() -> float:
	return max(0.0, immunity_timer_frames) / 60.0


func get_immunity_ratio() -> float:
	return clamp(immunity_timer_frames / max(1.0, immunity_total_frames), 0.0, 1.0)


func get_status_context() -> Dictionary:
	return {
		"active": immunity_timer_frames > 0.0,
		"timer_frames": immunity_timer_frames,
		"initial_timer_frames": immunity_total_frames,
		"ratio": get_immunity_ratio(),
		"counter_window_frames": counter_window_frames,
	}


func has_visible_effects() -> bool:
	return (
		active
		or immunity_timer_frames > 0.0
		or flash_alpha > 0.01
		or not wave_rings.is_empty()
		or not particles.is_empty()
	)


func needs_effect_update() -> bool:
	return has_visible_effects()


func apply_counter_speed_bonus(ball_vel: Vector2) -> Vector2:
	if counter_window_frames <= 0.0 or ball_vel.length_squared() <= 0.001:
		return ball_vel
	counter_window_frames = 0.0
	return ball_vel * COUNTER_SPEED_BONUS


func _can_activate(current_msec: int, special_gauge: float, config: Dictionary, deps: Dictionary) -> bool:
	if active:
		return false
	if _is_input_blocked(config, deps):
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	if not _has_status_effect(deps, config):
		return false
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return false
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return false
	return true


func _is_input_blocked(config: Dictionary, deps: Dictionary) -> bool:
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return true
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		if dash_state.has_method("is_active") and bool(dash_state.is_active()):
			return true
		if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
			return true
		if dash_state.has_method("get_snapshot"):
			var dash_snapshot: Dictionary = dash_state.get_snapshot()
			if bool(dash_snapshot.get("active", false)) or bool(dash_snapshot.get("recovering", false)):
				return true
	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if plasma_state != null and plasma_state.has_method("is_charging") and bool(plasma_state.is_charging()):
		return true
	var power_state: Object = deps.get("power_state", null)
	if power_state != null:
		if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
			return true
		if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
			return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	return bool(config.get("player_skill_input_locked", false))


func _has_status_effect(deps: Dictionary, config: Dictionary = {}) -> bool:
	if bool(config.get("player_status_effect_active", false)):
		return true
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("has_status_effect"):
		return bool(movement_state.has_status_effect())
	if movement_state != null and movement_state.has_method("get_status_snapshot"):
		var snapshot: Dictionary = movement_state.get_status_snapshot()
		if bool(snapshot.get("knockback_active", false)) and bool(snapshot.get("knockback_cleansable", true)):
			return true
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("has_status_effect"):
		return bool(status_effect_state.has_status_effect("player", true))
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("has_player_status_effect"):
		return bool(active_item_runtime.has_player_status_effect())
	return false


func _clear_status_effects(deps: Dictionary) -> void:
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null:
		if movement_state.has_method("clear_status_effects"):
			movement_state.clear_status_effects()
		elif movement_state.has_method("clear_knockback"):
			movement_state.clear_knockback()
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("clear_player_status_effects"):
		active_item_runtime.clear_player_status_effects()
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("clear_player_status_effects"):
		status_effect_state.clear_player_status_effects()


func _trigger_cleanse(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	center = player_pos + _last_player_size * 0.5
	active = true
	cast_timer_frames = CAST_DURATION_FRAMES
	immunity_total_frames = _get_immunity_duration_frames(deps)
	immunity_timer_frames = immunity_total_frames
	counter_window_frames = COUNTER_WINDOW_FRAMES
	shield_transition_timer_frames = 0.0
	shield_fully_formed = false
	flash_alpha = 1.0
	_build_wave_rings()
	_spawn_cast_particles()
	_play_cleanse_audio(deps)
	_trigger_feedback(deps)


func _build_wave_rings() -> void:
	wave_rings.clear()
	for i in range(3):
		wave_rings.append({
			"radius": 10.0,
			"max_radius": 120.0 + float(i) * 40.0,
			"alpha": 1.0,
			"thickness": 4.0 - float(i),
			"delay": float(i) * 5.0,
			"started": false,
		})


func _spawn_cast_particles() -> void:
	particles.clear()
	for _i in range(18):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(3.0, 8.0)
		particles.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": randf_range(3.0, 8.0),
			"alpha": 1.0,
			"hue": randf_range(0.0, 1.0),
			"life": randf_range(20.0, 35.0),
			"max_life": 35.0,
		})
	if particles.size() > MAX_CAST_PARTICLES:
		while particles.size() > MAX_CAST_PARTICLES:
			particles.pop_front()


func _update_cast_effect(fps_scale: float) -> void:
	flash_alpha = max(0.0, flash_alpha - 0.118 * fps_scale)
	for ring in wave_rings:
		if not bool(ring.get("started", false)):
			var delay: float = float(ring.get("delay", 0.0)) - fps_scale
			ring["delay"] = delay
			if delay <= 0.0:
				ring["started"] = true
			continue
		var radius: float = float(ring.get("radius", 10.0))
		var max_radius: float = max(11.0, float(ring.get("max_radius", 120.0)))
		var expansion_speed: float = (max_radius - 10.0) / 20.0
		radius = min(radius + expansion_speed * fps_scale, max_radius)
		var progress: float = clamp((radius - 10.0) / (max_radius - 10.0), 0.0, 1.0)
		ring["radius"] = radius
		ring["alpha"] = 1.0 - progress * 0.8

	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			continue
		var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * pow(0.95, fps_scale)
		particle["vel"] = vel
		particle["pos"] = _as_vector2(particle.get("pos", center), center) + vel * fps_scale
		particle["life"] = life
		particle["alpha"] = clamp(life / max(1.0, float(particle.get("max_life", 35.0))), 0.0, 1.0)
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func _draw_cast_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if not active:
		return
	if flash_alpha > 0.01:
		canvas.draw_rect(
			Rect2(Vector2.ZERO, Vector2(760.0, 750.0)),
			Color(200.0 / 255.0, 220.0 / 255.0, 1.0, min(0.40, flash_alpha * 0.18))
		)
	for ring in wave_rings:
		if not bool(ring.get("started", false)) or float(ring.get("alpha", 0.0)) <= 0.0:
			continue
		var radius: float = float(ring.get("radius", 10.0))
		var alpha: float = float(ring.get("alpha", 0.0))
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center + shake_offset,
			radius + 5.0,
			Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
			alpha * 0.26
		)
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center + shake_offset,
			radius,
			Color(220.0 / 255.0, 240.0 / 255.0, 1.0),
			alpha * 0.56
		)
	var particle_start: int = max(0, particles.size() - MAX_RENDERED_CAST_PARTICLES)
	for index in range(particle_start, particles.size()):
		var particle: Dictionary = particles[index]
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var t: float = float(particle.get("hue", 0.0))
		var color := Color((100.0 + 155.0 * t) / 255.0, (200.0 - 100.0 * t) / 255.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("pos", center), center) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 3.0)))
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, size * 1.55, color, alpha * 0.62)
	if cast_timer_frames <= 10.0 and cast_timer_frames > 0.0:
		var shrink_progress: float = 1.0 - cast_timer_frames / 10.0
		var shrink_radius: float = 150.0 - 90.0 * shrink_progress
		var shrink_alpha: float = (100.0 + 155.0 * shrink_progress) / 255.0
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center + shake_offset, shrink_radius, Color(180.0 / 255.0, 230.0 / 255.0, 1.0), max(0.0, shrink_alpha * 0.50))


func _draw_immunity_shield(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if immunity_timer_frames <= 0.0 or active:
		return
	var shield_center: Vector2 = _last_player_pos + _last_player_size * 0.5 + shake_offset
	var alpha_multiplier: float
	var shield_radius: float
	if shield_transition_timer_frames > 0.0:
		var transition_progress: float = shield_transition_timer_frames / SHIELD_TRANSITION_FRAMES
		var eased: float = 1.0 - pow(1.0 - transition_progress, 2.0)
		shield_radius = lerp(100.0, 150.0, eased)
		alpha_multiplier = (1.0 - transition_progress) * 0.8 + 0.2
	else:
		shield_radius = 100.0
		alpha_multiplier = min(1.0, get_immunity_ratio())
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.85 + 0.15 * sin(now * 0.012)
	var base_alpha: float = clamp(0.86 * alpha_multiplier * pulse, 0.0, 0.86)
	var color_shift: float = sin(now * 0.003)
	ImpactFlareTextureCache.draw_glow(
		canvas,
		shield_center,
		shield_radius + 20.0,
		Color((80.0 + 60.0 * max(0.0, color_shift)) / 255.0, (180.0 - 40.0 * abs(color_shift)) / 255.0, 1.0),
		base_alpha * 0.22
	)
	for i in range(2):
		var ring_alpha: float = max(0.0, base_alpha * (0.90 - float(i) * 0.25))
		var phase: float = now * 0.008 + float(i) * 1.2
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			shield_center,
			shield_radius + float(i) * 4.0,
			Color((100.0 + 80.0 * sin(phase)) / 255.0, (200.0 + 40.0 * sin(phase + 1.5)) / 255.0, 1.0),
			ring_alpha * 0.54
		)
	ImpactFlareTextureCache.draw_glow(canvas, shield_center, shield_radius - 4.0, Color(130.0 / 255.0, 210.0 / 255.0, 1.0), base_alpha * 0.08)
	for arc_i in range(3):
		var angle: float = fmod(now * 0.006 + float(arc_i) * (TAU / 3.0), TAU)
		var p0: Vector2 = shield_center + Vector2(cos(angle), sin(angle)) * shield_radius * 0.80
		var p1: Vector2 = shield_center + Vector2(cos(angle + 0.4), sin(angle + 0.4)) * shield_radius * 0.85
		var arc_alpha: float = base_alpha * (0.5 + 0.3 * sin(now * 0.02 + float(arc_i)))
		canvas.draw_line(
			p0,
			p1,
			Color((150.0 + 105.0 * sin(now * 0.015 + float(arc_i))) / 255.0, (220.0 + 35.0 * sin(now * 0.02 + float(arc_i))) / 255.0, 1.0, arc_alpha),
			2.0,
			true
		)
	ImpactFlareTextureCache.draw_glow(canvas, shield_center + Vector2(0.0, -shield_radius * 0.40), shield_radius * 0.5, Color(220.0 / 255.0, 245.0 / 255.0, 1.0), base_alpha * 0.22)


func _draw_immunity_timer(canvas: CanvasItem, timer_stack: Object = null) -> void:
	if immunity_timer_frames <= 0.0:
		return
	var ratio: float = get_immunity_ratio()
	var remaining_seconds: float = immunity_timer_frames / 60.0
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(16.0 / 255.0, 18.0 / 255.0, 32.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(40.0 / 255.0, 80.0 / 255.0, 130.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(80.0 / 255.0, 140.0 / 255.0, 200.0 / 255.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(20.0 / 255.0, 24.0 / 255.0, 36.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.04, 0.06, 0.10, 0.94))
	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 3.0:
		base_color = Color(60.0 / 255.0, 180.0 / 255.0, 220.0 / 255.0, 0.98)
		highlight_color = Color(140.0 / 255.0, 220.0 / 255.0, 1.0, 0.98)
	elif remaining_seconds > 1.5:
		base_color = Color(120.0 / 255.0, 160.0 / 255.0, 220.0 / 255.0, 0.98)
		highlight_color = Color(180.0 / 255.0, 200.0 / 255.0, 1.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
		base_color = Color(220.0 / 255.0, (100.0 + 80.0 * pulse) / 255.0, 60.0 / 255.0, 0.99)
		highlight_color = Color(1.0, (150.0 + 60.0 * pulse) / 255.0, 100.0 / 255.0, 0.99)
	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(160.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 0.92),
			1.0
		)
	var icon_center := frame_rect.position + Vector2(-16.0, frame_rect.size.y * 0.5)
	var icon_pulse: float = 1.0 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.02)
	var icon_radius: float = max(7.0, 9.0 * icon_pulse)
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, icon_radius + 4.0, Color(0.0, 0.0, 0.0), 0.28)
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, icon_radius, Color(40.0 / 255.0, 160.0 / 255.0, 210.0 / 255.0), 0.46)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, icon_center, icon_radius, Color(100.0 / 255.0, 220.0 / 255.0, 1.0), 0.50)
	canvas.draw_line(icon_center + Vector2(0.0, -icon_radius * 0.55), icon_center + Vector2(0.0, icon_radius * 0.55), Color.WHITE, 2.0, true)
	canvas.draw_line(icon_center + Vector2(-icon_radius * 0.55, 0.0), icon_center + Vector2(icon_radius * 0.55, 0.0), Color.WHITE, 2.0, true)


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


func _get_immunity_duration_frames(deps: Dictionary) -> float:
	var extension_level: int = _get_runtime_skill_level(deps, "extension_gear")
	return IMMUNITY_DURATION_FRAMES * (1.0 + EXTENSION_GEAR_DURATION_BONUS * float(extension_level))


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


func _play_cleanse_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_cleanse"):
		audio.play_cleanse()


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
