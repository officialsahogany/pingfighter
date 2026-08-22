extends RefCounted

const ViperAirStrikeFlashOverride := preload("res://scripts/core/viper_air_strike_flash_override.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const BASE_MAX_HOLD_FRAMES := 180.0
const MAX_HEIGHT := 200.0
const RISE_SPEED := 4.0
const FALL_SPEED := 3.0
const HOLD_RECHARGE_SPEED := 0.5
const HIT_SPEED_MULTIPLIER := 1.15
const AIR_STRIKE_GAUGE_BONUS_MAX_PCT := 20.0
const AIRBORNE_MOVE_BONUS_MAX := 2.15
const AIRBORNE_THRESHOLD := 10.0
const JETPACK_ENHANCE_HOLD_PER_LEVEL := 0.20
const JETPACK_ENHANCE_GAUGE_START_LEVEL := 3
const JETPACK_ENHANCE_GAUGE_PCT_PER_LEVEL := 10
const AIR_STRIKE_GOLD := 3
const AIR_STRIKE_FLASH_DURATION := 18.0
const AIR_STRIKE_TEXT_DURATION := 60.0
const AIR_STRIKE_SHAKE_AMOUNT := 0.055
const AIR_STRIKE_SHAKE_INTENSITY := 2.2
const AIR_STRIKE_HIT_PARTICLE_INTENSITY := 0.82
const AIR_STRIKE_ENERGY_SCALE := 0.58
const AIR_STRIKE_ENERGY_INTENSITY := 0.72
const AIR_STRIKE_HIT_PULSE_KIND := "viper_air_strike"
const AIR_STRIKE_HIT_PULSE_INTENSITY := 0.82
const PARTICLE_LIMIT := 90

var active := false
var offset_y := 0.0
var hold_timer := 0.0
var overheat := false
var particles: Array = []
var air_strike_flash_timer := 0.0
var air_strike_flash_pos := Vector2.ZERO
var air_strike_flash_height_ratio := 0.0
var air_strike_text_timer := 0.0
var air_strike_text_pos := Vector2.ZERO
var air_strike_text_pct := 0
var _last_audio_active := false
var _last_player_pos := Vector2(302.5, 700.0)
var _last_player_size := Vector2(155.0, 50.0)
var _last_floor_y := 700.0
var _last_max_hold_frames := BASE_MAX_HOLD_FRAMES


func reset() -> void:
	reset_round()


func reset_round(deps: Dictionary = {}) -> void:
	active = false
	offset_y = 0.0
	hold_timer = 0.0
	overheat = false
	particles.clear()
	air_strike_flash_timer = 0.0
	air_strike_flash_pos = Vector2.ZERO
	air_strike_flash_height_ratio = 0.0
	air_strike_text_timer = 0.0
	air_strike_text_pos = Vector2.ZERO
	air_strike_text_pct = 0
	_sync_audio(deps.get("audio", null), false)


func force_land(deps: Dictionary = {}) -> void:
	active = false
	offset_y = 0.0
	overheat = false
	_sync_audio(deps.get("audio", null), false)


func interrupt_thrust(deps: Dictionary = {}) -> void:
	active = false
	_sync_audio(deps.get("audio", null), false)


func update(delta: float, player_pos: Vector2, config: Dictionary, deps: Dictionary) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	var paddle_size := Vector2(
		max(1.0, float(config.get("paddle_width", 155.0))),
		max(1.0, float(config.get("paddle_height", 50.0)))
	)
	_last_player_size = paddle_size
	_last_floor_y = float(config.get("player_floor_y", HEIGHT - paddle_size.y))
	_last_max_hold_frames = get_max_hold_frames(deps)

	var next_pos: Vector2 = player_pos
	var input_snapshot: Dictionary = _get_input_snapshot(deps)
	var wants_jetpack: bool = bool(input_snapshot.get("jetpack_pressed", false))
	var can_fly: bool = wants_jetpack and not overheat and not _is_jetpack_blocked(config, deps)

	if can_fly:
		active = true
		hold_timer += fps_scale
		if hold_timer >= _last_max_hold_frames:
			hold_timer = _last_max_hold_frames
			active = false
			overheat = true
		else:
			offset_y = max(-MAX_HEIGHT, offset_y - RISE_SPEED * fps_scale)
	else:
		active = false

	if not active and offset_y < 0.0:
		var fall_speed: float = FALL_SPEED * _get_emp_hold_fall_multiplier(deps)
		offset_y = min(0.0, offset_y + fall_speed * fps_scale)

	if offset_y >= 0.0:
		offset_y = 0.0
		if overheat:
			overheat = false
		if hold_timer > 0.0 and not active:
			var recharge_multiplier: float = 1.0 + RuntimePerkProgression.get_value("jetpack_enhance", "max_gauge_bonus", _get_jetpack_enhance_level(deps))
			hold_timer = max(0.0, hold_timer - HOLD_RECHARGE_SPEED * recharge_multiplier * fps_scale)

	_sync_audio(deps.get("audio", null), active)
	if bool(config.get("viper_jetpack_hover_sheet_fx", false)):
		particles.clear()
	else:
		_update_particles(fps_scale)
		if active:
			_spawn_jetpack_particles(next_pos, paddle_size, fps_scale)
	if air_strike_flash_timer > 0.0:
		air_strike_flash_timer = max(0.0, air_strike_flash_timer - fps_scale)
	if air_strike_text_timer > 0.0:
		air_strike_text_timer = max(0.0, air_strike_text_timer - fps_scale)
		air_strike_text_pos.y -= 1.2 * fps_scale

	next_pos.y = _last_floor_y + offset_y
	_last_player_pos = next_pos
	return {
		"player_pos": next_pos,
		"viper_jetpack_active": active,
		"viper_jetpack_airborne": is_airborne(0.1),
		"viper_jetpack_offset_y": offset_y,
		"viper_jetpack_hold_timer": hold_timer,
		"viper_jetpack_overheat": overheat,
	}


func is_airborne(threshold: float = AIRBORNE_THRESHOLD) -> bool:
	return active or offset_y < -abs(threshold)


func get_max_hold_frames(deps: Dictionary = {}) -> float:
	return BASE_MAX_HOLD_FRAMES * (1.0 + RuntimePerkProgression.get_value("jetpack_enhance", "max_gauge_bonus", _get_jetpack_enhance_level(deps)))


func get_height_ratio() -> float:
	return clamp(abs(offset_y) / MAX_HEIGHT, 0.0, 1.0)


func get_air_strike_height_ratio() -> float:
	if offset_y >= -AIRBORNE_THRESHOLD:
		return 0.0
	return get_height_ratio()


func get_offset_y() -> float:
	return offset_y


func set_offset_y(value: float, deps: Dictionary = {}) -> void:
	offset_y = min(0.0, float(value))
	if offset_y >= 0.0:
		offset_y = 0.0
		active = false
		overheat = false
	_sync_audio(deps.get("audio", null), active)


func get_movement_bonus_multiplier() -> float:
	if offset_y >= 0.0:
		return 1.0
	return 1.0 + get_height_ratio() * AIRBORNE_MOVE_BONUS_MAX


func get_jetpack_enhance_gauge_bonus_pct(deps: Dictionary = {}) -> int:
	return int(round(RuntimePerkProgression.get_value(
		"jetpack_enhance", "airborne_gauge_gain_bonus", _get_jetpack_enhance_level(deps)
	) * 100.0))


func apply_air_strike_post_hit(
	ball_vel: Vector2,
	previous_special_gauge: float,
	updated_special_gauge: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var result := {
		"ball_vel": ball_vel,
		"special_gauge": updated_special_gauge,
	}
	if offset_y >= -AIRBORNE_THRESHOLD:
		return result

	var next_vel: Vector2 = ball_vel * HIT_SPEED_MULTIPLIER
	result["ball_vel"] = next_vel

	var gained_gauge: float = max(0.0, updated_special_gauge - previous_special_gauge)
	if gained_gauge > 0.0:
		var air_bonus: int = int(gained_gauge * (AIR_STRIKE_GAUGE_BONUS_MAX_PCT / 100.0) * get_air_strike_height_ratio())
		var gain_after_air_bonus: float = gained_gauge + float(air_bonus)
		var enhance_bonus: int = int(gain_after_air_bonus * float(get_jetpack_enhance_gauge_bonus_pct(deps)) / 100.0)
		var final_gain: float = gain_after_air_bonus + float(enhance_bonus)
		var gauge_max: float = float(context.get("gauge_max", context.get("special_gauge_max", 500.0)))
		result["special_gauge"] = min(gauge_max, previous_special_gauge + final_gain)

	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", _last_player_pos), _last_player_pos)
	_trigger_air_strike_feedback(ball_pos, next_vel, deps)
	result["paddle_hit_pulse_kind"] = AIR_STRIKE_HIT_PULSE_KIND
	result["paddle_hit_pulse_intensity"] = AIR_STRIKE_HIT_PULSE_INTENSITY
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
		result["runtime_perk_gold"] = int(_call_award_gold(runtime_perk_state, AIR_STRIKE_GOLD, context, deps))
	return result


func get_ball_collision_context(player_pos: Vector2 = Vector2.ZERO, _paddle_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var collision_pos: Vector2 = _last_player_pos
	if player_pos != Vector2.ZERO:
		collision_pos = Vector2(player_pos.x, _last_floor_y + offset_y)
	return {
		"player_pos": collision_pos,
		"player_y": collision_pos.y,
		"viper_jetpack_active": active,
		"viper_jetpack_airborne": is_airborne(0.1),
		"viper_jetpack_offset_y": offset_y,
		"viper_jetpack_floor_y": _last_floor_y,
	}


func get_actor_draw_context() -> Dictionary:
	var hold_ratio: float = 0.0
	if _last_max_hold_frames > 0.0:
		hold_ratio = clamp(hold_timer / _last_max_hold_frames, 0.0, 1.0)
	return {
		"viper_jetpack_active": active,
		"viper_jetpack_airborne": is_airborne(0.1),
		"viper_jetpack_offset_y": offset_y,
		"viper_jetpack_altitude_ratio": get_air_strike_height_ratio(),
		"viper_jetpack_hold_ratio": hold_ratio,
		"viper_jetpack_overheat": overheat,
		"viper_jetpack_floor_y": _last_floor_y,
		"viper_jetpack_particles": particles,
		"viper_air_strike_flash_timer": air_strike_flash_timer,
		"viper_air_strike_flash_duration": AIR_STRIKE_FLASH_DURATION,
		"viper_air_strike_flash_pos": air_strike_flash_pos,
		"viper_air_strike_flash_height_ratio": air_strike_flash_height_ratio,
		"viper_air_strike_text_timer": air_strike_text_timer,
		"viper_air_strike_text_duration": AIR_STRIKE_TEXT_DURATION,
		"viper_air_strike_text_pos": air_strike_text_pos,
		"viper_air_strike_text_pct": air_strike_text_pct,
	}


func _is_jetpack_blocked(config: Dictionary, deps: Dictionary) -> bool:
	if bool(config.get("player_skill_input_locked", false)):
		return true
	if not bool(config.get("ball_active", true)):
		return true
	var round_state: Object = deps.get("round_state", null)
	if round_state != null:
		if round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
			return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime != null and viper_skill_runtime.has_method("get_snapshot"):
		var snapshot: Variant = viper_skill_runtime.get_snapshot()
		if snapshot is Dictionary:
			if bool(snapshot.get("dive_active", false)):
				return true
			if bool(snapshot.get("marshal_active", false)):
				return true
			if bool(snapshot.get("core_flip_attack_active", false)):
				return true
			if bool(snapshot.get("blade_motion_active", false)):
				return true
	return false


func _get_emp_hold_fall_multiplier(deps: Dictionary) -> float:
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if viper_skill_runtime != null and viper_skill_runtime.has_method("get_snapshot"):
		var snapshot: Variant = viper_skill_runtime.get_snapshot()
		if snapshot is Dictionary and bool(snapshot.get("dive_hold_active", false)):
			var hold_ratio: float = clamp(float(snapshot.get("dive_hold_ratio", 0.0)), 0.0, 1.0)
			return max(0.1, 1.0 - hold_ratio * 0.9)
	return 1.0


func _get_input_snapshot(deps: Dictionary) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	if input_reader != null and input_reader.has_method("get_snapshot"):
		var snapshot: Variant = input_reader.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _get_jetpack_enhance_level(deps: Dictionary) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level("jetpack_enhance")))
	return 0


func _spawn_jetpack_particles(player_pos: Vector2, paddle_size: Vector2, fps_scale: float) -> void:
	var center_x: float = player_pos.x + paddle_size.x * 0.5
	var base_y: float = player_pos.y + paddle_size.y + 3.0
	var spawn_count: int = max(1, int(round(fps_scale * 2.0)))
	for _i in range(spawn_count):
		var nozzle_x: float = center_x + (-20.0 if randf() < 0.5 else 20.0) + randf_range(-4.0, 4.0)
		var is_smoke: bool = randf() < 0.28
		particles.append({
			"pos": Vector2(nozzle_x, base_y + randf_range(-2.0, 5.0)),
			"vel": Vector2(randf_range(-0.7, 0.7), randf_range(1.5, 4.2) if not is_smoke else randf_range(0.6, 2.0)),
			"life": randf_range(18.0, 30.0) if not is_smoke else randf_range(24.0, 42.0),
			"max_life": 30.0 if not is_smoke else 42.0,
			"size": randf_range(3.0, 6.0) if not is_smoke else randf_range(5.0, 10.0),
			"color": Color(0.35, 1.0, 1.0, 1.0) if not is_smoke else Color(0.48, 0.54, 0.62, 0.70),
			"smoke": is_smoke,
		})
	while particles.size() > PARTICLE_LIMIT:
		particles.pop_front()


func _update_particles(fps_scale: float) -> void:
	if particles.is_empty():
		return
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		particle["pos"] = pos + vel * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["vel"] = vel + Vector2(0.0, 0.045 * fps_scale)
		particles[i] = particle
		if float(particle.get("life", 0.0)) <= 0.0:
			particles.remove_at(i)


func _trigger_air_strike_feedback(ball_pos: Vector2, ball_vel: Vector2, deps: Dictionary) -> void:
	air_strike_flash_timer = 0.0 if ViperAirStrikeFlashOverride.is_disabled() else AIR_STRIKE_FLASH_DURATION
	air_strike_flash_pos = ball_pos
	air_strike_flash_height_ratio = get_air_strike_height_ratio()
	air_strike_text_timer = 0.0
	air_strike_text_pos = Vector2.ZERO
	air_strike_text_pct = 0
	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(AIR_STRIKE_SHAKE_AMOUNT, AIR_STRIKE_SHAKE_INTENSITY)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(AIR_STRIKE_SHAKE_AMOUNT, AIR_STRIKE_SHAKE_INTENSITY)
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		return
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null:
		return
	var direction: Vector2 = ball_vel.normalized() if ball_vel.length() > 0.0 else Vector2(0.0, -1.0)
	if impact_effects.has_method("spawn_hit_particles"):
		impact_effects.spawn_hit_particles(
			ball_pos,
			Color(0.0, 1.0, 0.78, 1.0),
			direction,
			AIR_STRIKE_HIT_PARTICLE_INTENSITY,
			ball_vel.length()
		)
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(ball_pos, AIR_STRIKE_ENERGY_SCALE, AIR_STRIKE_ENERGY_INTENSITY)


func _sync_audio(audio: Object, should_play: bool) -> void:
	if _last_audio_active == should_play:
		return
	_last_audio_active = should_play
	if audio == null:
		return
	if audio.has_method("sync_viper_jetpack_loop"):
		audio.sync_viper_jetpack_loop(should_play)
	elif should_play and audio.has_method("play_viper_jetpack_loop"):
		audio.play_viper_jetpack_loop()
	elif not should_play and audio.has_method("stop_viper_jetpack_loop"):
		audio.stop_viper_jetpack_loop()


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _call_award_gold(runtime_perk_state: Object, amount: int, context: Dictionary, deps: Dictionary) -> int:
	if _method_accepts_arg_count(runtime_perk_state, "award_gold", 3):
		return int(runtime_perk_state.award_gold(amount, context, deps))
	return int(runtime_perk_state.award_gold(amount))


func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method in target.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size() >= arg_count
	return false
