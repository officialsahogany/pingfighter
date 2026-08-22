extends RefCounted

const SmasherCleanseRenderer := preload("res://scripts/characters/smasher_cleanse_renderer.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

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
var _renderer: Object = SmasherCleanseRenderer.new()


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	return bool(_renderer.prewarm_step())


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
	var visual_time_msec: float = float(Time.get_ticks_msec())
	_renderer.draw(
		canvas,
		shake_offset,
		timer_stack,
		visual_time_msec,
		active,
		cast_timer_frames,
		immunity_timer_frames,
		immunity_total_frames,
		shield_transition_timer_frames,
		SHIELD_TRANSITION_FRAMES,
		_last_player_pos,
		_last_player_size,
		center,
		flash_alpha,
		wave_rings,
		particles
	)


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


func _get_immunity_duration_frames(deps: Dictionary) -> float:
	var extension_level: int = _get_runtime_skill_level(deps, "extension_gear")
	return IMMUNITY_DURATION_FRAMES * (1.0 + RuntimePerkProgression.get_value("extension_gear", "duration_bonus", extension_level))


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
