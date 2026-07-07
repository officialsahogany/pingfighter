extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_RAINBOW_FUR_GLOVE := "rainbow_fur_glove"
const MAX_TRIGGER_CHANCE_PCT := 100.0
const MAX_COOLDOWN_REDUCTION_PCT := 95.0
const AURA_FRAMES := 36.0
const PARTICLE_COUNT := 18
const PARTICLE_MAX := 42
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const COLORS := [
	Color(1.0, 80.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(1.0, 160.0 / 255.0, 60.0 / 255.0, 1.0),
	Color(1.0, 240.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(90.0 / 255.0, 220.0 / 255.0, 110.0 / 255.0, 1.0),
	Color(90.0 / 255.0, 170.0 / 255.0, 1.0, 1.0),
	Color(200.0 / 255.0, 110.0 / 255.0, 1.0, 1.0),
]


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_RAINBOW_FUR_GLOVE)


func is_active(runtime: Object) -> bool:
	return is_equipped(runtime)


func is_rainbow_fur_glove_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_RAINBOW_FUR_GLOVE) > 0
	return is_equipped(runtime)


func get_trigger_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_RAINBOW_FUR_GLOVE, "rainbow_glove_trigger_chance_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_RAINBOW_FUR_GLOVE, "rainbow_glove_trigger_chance_pct"),
		0.0,
		MAX_TRIGGER_CHANCE_PCT
	)


func get_cooldown_reduction_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_RAINBOW_FUR_GLOVE, "rainbow_glove_cooldown_reduction_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_RAINBOW_FUR_GLOVE, "rainbow_glove_cooldown_reduction_pct"),
		0.0,
		MAX_COOLDOWN_REDUCTION_PCT
	)


func try_proc_player_hit(
	runtime: Object,
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not is_rainbow_fur_glove_effect_active(runtime):
		clear_runtime(runtime)
		return {"activated": false}
	var chance_pct: float = get_trigger_chance_pct(runtime)
	if chance_pct <= 0.0 or randf() * 100.0 >= chance_pct:
		return {"activated": false}
	var reduction_pct: float = get_cooldown_reduction_pct(runtime)
	var reduction_fraction: float = clamp(reduction_pct / 100.0, 0.0, 0.95)
	if reduction_fraction <= 0.0:
		return {"activated": false}

	var deps_dict: Dictionary = runtime._get_dict(deps)
	var current_msec: int = resolve_context_msec(context)
	var changed_count: int = apply_skill_cooldown_reduction(runtime, reduction_fraction, current_msec, deps)
	runtime.rainbow_fur_glove_last_reduction_pct = reduction_pct
	start_aura(runtime, resolve_center(runtime, ball_pos, context, deps_dict))
	runtime.audio_router.play_rainbow_fur_glove_audio(runtime, deps_dict.get("registry", null))
	runtime.audio_router.apply_ragnarok_feedback(runtime, deps, 0.035, 1.6)
	runtime._sync_owner(deps_dict.get("owner", null), deps_dict.get("registry", null))
	return {
		"activated": true,
		"cooldown_reduction_pct": reduction_pct,
		"cooldown_reduction_fraction": reduction_fraction,
		"cooldown_states_changed": changed_count,
	}


func clear_runtime(runtime: Object) -> void:
	runtime.rainbow_fur_glove_aura_timer_frames = 0.0
	runtime.rainbow_fur_glove_aura_life_frames = AURA_FRAMES
	runtime.rainbow_fur_glove_aura_center = Vector2.ZERO
	runtime.rainbow_fur_glove_aura_phase = 0.0
	runtime.rainbow_fur_glove_particles.clear()
	runtime.rainbow_fur_glove_last_reduction_pct = 0.0


func clear_round_state(runtime: Object) -> void:
	runtime.rainbow_fur_glove_aura_timer_frames = 0.0
	runtime.rainbow_fur_glove_aura_life_frames = AURA_FRAMES
	runtime.rainbow_fur_glove_aura_center = Vector2.ZERO
	runtime.rainbow_fur_glove_particles.clear()


func apply_skill_cooldown_reduction(
	runtime: Object,
	reduction_fraction: float,
	current_msec: int,
	deps: Dictionary
) -> int:
	var total_changed := 0
	for skill_state in collect_player_skill_states(runtime, deps):
		if skill_state == null or not skill_state.has_method("reduce_all_cooldowns_by_fraction"):
			continue
		total_changed += int(skill_state.reduce_all_cooldowns_by_fraction(reduction_fraction, current_msec))
	return total_changed


func collect_player_skill_states(runtime: Object, deps: Dictionary) -> Array:
	var result: Array = []
	var deps_dict: Dictionary = runtime._get_dict(deps)
	_append_unique_object(result, deps_dict.get("skill_state", null))
	for state_value in runtime._get_array(deps_dict.get("skill_states", [])):
		_append_unique_object(result, state_value)
	var registry: Object = deps_dict.get("registry", null)
	for key in [
		"smasher_skill_state",
		"viper_skill_state",
		"soldier_skill_state",
		"commando_skill_state",
		"blacksmith_skill_state",
		"baltor_skill_state",
		"optimus_skill_state",
	]:
		_append_unique_object(result, runtime._get_instance(registry, str(key)))
	return result


func resolve_context_msec(context: Dictionary) -> int:
	for key in ["current_time_msec", "current_msec", "time_now_msec", "time_msec"]:
		if context.has(key):
			return max(0, int(context.get(key, 0)))
	return Time.get_ticks_msec()


func resolve_center(
	runtime: Object,
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Vector2:
	var owner: Object = deps.get("owner", context.get("owner", null))
	var fallback_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_pos: Vector2 = runtime._get_vector2(context.get("player_pos", fallback_pos))
	var paddle_width: float = max(1.0, float(context.get(
		"player_paddle_width",
		context.get(
			"paddle_width",
			runtime._safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)
		)
	)))
	var paddle_height: float = max(1.0, float(context.get(
		"player_paddle_height",
		runtime._safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)
	)))
	if player_pos != Vector2.ZERO:
		return player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)
	return ball_pos


func start_aura(runtime: Object, center: Vector2) -> void:
	runtime.rainbow_fur_glove_aura_center = center
	runtime.rainbow_fur_glove_aura_life_frames = AURA_FRAMES
	runtime.rainbow_fur_glove_aura_timer_frames = runtime.rainbow_fur_glove_aura_life_frames
	runtime.rainbow_fur_glove_aura_phase = randf_range(0.0, TAU)
	build_particles(runtime, center)


func build_particles(runtime: Object, center: Vector2) -> void:
	runtime.rainbow_fur_glove_particles.clear()
	for _i in range(PARTICLE_COUNT):
		runtime.rainbow_fur_glove_particles.append(create_particle(center, true))


func create_particle(center: Vector2, random_life: bool = false) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(12.0, 54.0)
	var life: float = randf_range(18.0, 36.0) if random_life else randf_range(24.0, 36.0)
	var color := Color.WHITE
	if not COLORS.is_empty():
		color = COLORS[randi() % COLORS.size()]
	return {
		"position": center + Vector2(cos(angle), sin(angle)) * dist,
		"velocity": Vector2(cos(angle), sin(angle)) * randf_range(1.2, 4.2),
		"life": life,
		"max_life": life,
		"size": randf_range(2.0, 4.8),
		"color": color,
		"phase": randf_range(0.0, TAU),
	}


func update_runtime(runtime: Object, fps_scale: float) -> void:
	if not is_rainbow_fur_glove_effect_active(runtime):
		if runtime.rainbow_fur_glove_aura_timer_frames > 0.0 or not runtime.rainbow_fur_glove_particles.is_empty():
			clear_runtime(runtime)
		return
	var step: float = max(0.0, fps_scale)
	if runtime.rainbow_fur_glove_aura_timer_frames > 0.0:
		runtime.rainbow_fur_glove_aura_timer_frames = max(0.0, runtime.rainbow_fur_glove_aura_timer_frames - step)
		runtime.rainbow_fur_glove_aura_phase = fmod(runtime.rainbow_fur_glove_aura_phase + 0.18 * step, TAU)
	update_particles(runtime, step)


func update_particles(runtime: Object, step: float) -> void:
	for i in range(runtime.rainbow_fur_glove_particles.size() - 1, -1, -1):
		var particle: Dictionary = runtime._get_dict(runtime.rainbow_fur_glove_particles[i])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			runtime.rainbow_fur_glove_particles.remove_at(i)
			continue
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		var position: Vector2 = runtime._get_vector2(particle.get("position", Vector2.ZERO))
		velocity *= pow(0.965, step)
		position += velocity * step
		particle["life"] = life
		particle["velocity"] = velocity
		particle["position"] = position
		particle["phase"] = float(particle.get("phase", 0.0)) + 0.11 * step
		runtime.rainbow_fur_glove_particles[i] = particle
	while (
		runtime.rainbow_fur_glove_aura_timer_frames > 0.0
		and runtime.rainbow_fur_glove_particles.size() < PARTICLE_COUNT
	):
		runtime.rainbow_fur_glove_particles.append(
			create_particle(runtime.rainbow_fur_glove_aura_center)
		)
	while runtime.rainbow_fur_glove_particles.size() > PARTICLE_MAX:
		runtime.rainbow_fur_glove_particles.pop_front()


func _append_unique_object(items: Array, value: Variant) -> void:
	if value == null or not (value is Object):
		return
	var object_value: Object = value
	for existing in items:
		if existing == object_value:
			return
	items.append(object_value)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
