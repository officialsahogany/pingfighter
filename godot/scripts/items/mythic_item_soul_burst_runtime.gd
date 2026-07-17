extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SOUL_BURST := "soul_burst"
const DEFAULT_GAUGE_COST := 160.0
const MIN_GAUGE_COST := 110.0
const MAX_GAUGE_COST := 160.0
const EFFECT_FRAMES := 30.0
const SHOCKWAVE_FRAMES := 18.0
const PARTICLE_COUNT := 30
const WIND_TRAIL_COUNT := 10
const PARTICLE_ALPHA_CUTOFF := 0.02


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_SOUL_BURST)


func is_active(runtime: Object) -> bool:
	return is_equipped(runtime)


func is_soul_burst_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_SOUL_BURST) > 0
	return is_equipped(runtime)


func get_gauge_cost(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		var converted_cost: float = _get_converted_perk_value(runtime, ITEM_SOUL_BURST, "soul_burst_gauge_cost")
		return converted_cost if converted_cost > 0.0 else DEFAULT_GAUGE_COST
	if not is_equipped(runtime):
		return DEFAULT_GAUGE_COST
	var cost: float = runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SOUL_BURST, "soul_burst_gauge_cost")
	if cost <= 0.0:
		cost = DEFAULT_GAUGE_COST
	return clamp(cost, MIN_GAUGE_COST, MAX_GAUGE_COST)


func can_dash(runtime: Object, special_gauge: float) -> bool:
	return is_soul_burst_effect_active(runtime) and float(special_gauge) + 0.001 >= get_gauge_cost(runtime)


# The consumed gauge is returned in "special_gauge" and is the single source of
# truth: the caller threads it back through the player-controller result and the
# result applier writes it to the owner. Do NOT also write the owner directly
# here — a same-frame direct write is silently overwritten by the applier's
# end-of-frame result write, so it gives false confidence (it was the failed
# patch for the Commando wrapper bug; the real fix is the wrapper propagating
# this return value). See docs/character_skill_perk_checklist.md §3.5.
func try_consume_dash(
	runtime: Object,
	special_gauge: float,
	player_center: Vector2,
	direction: float,
	registry: Object
) -> Dictionary:
	var current_gauge: float = max(0.0, float(special_gauge))
	if not can_dash(runtime, current_gauge):
		return {
			"activated": false,
			"special_gauge": current_gauge,
		}
	var gauge_cost: float = get_gauge_cost(runtime)
	trigger_effect(runtime, player_center, direction, registry)
	return {
		"activated": true,
		"soul_burst_dash": true,
		"gauge_cost": gauge_cost,
		"special_gauge": max(0.0, current_gauge - gauge_cost),
	}


func trigger_effect(
	runtime: Object,
	player_center: Vector2,
	direction: float,
	registry: Object
) -> void:
	runtime.soul_burst_center = player_center
	runtime.soul_burst_direction = sign(direction)
	if abs(runtime.soul_burst_direction) <= 0.01:
		runtime.soul_burst_direction = 1.0
	runtime.soul_burst_effect_timer_frames = EFFECT_FRAMES
	runtime.soul_burst_dash_active = true
	build_effects(runtime)
	runtime.audio_router.play_soul_burst_audio(runtime, registry)
	runtime.audio_router.apply_ragnarok_feedback(runtime, {"registry": registry}, 0.11, 4.2)


func clear_runtime(runtime: Object) -> void:
	runtime.soul_burst_effect_timer_frames = 0.0
	runtime.soul_burst_dash_active = false
	runtime.soul_burst_center = Vector2.ZERO
	runtime.soul_burst_direction = 0.0
	runtime.soul_burst_particles.clear()
	runtime.soul_burst_shockwaves.clear()
	runtime.soul_burst_wind_trails.clear()


func update_runtime(runtime: Object, fps_scale: float) -> void:
	if not is_soul_burst_effect_active(runtime) and (
		runtime.soul_burst_dash_active
		or not runtime.soul_burst_particles.is_empty()
	):
		clear_runtime(runtime)
		return
	var step: float = max(0.0, fps_scale)
	if runtime.soul_burst_effect_timer_frames > 0.0:
		runtime.soul_burst_effect_timer_frames = max(0.0, runtime.soul_burst_effect_timer_frames - step)
	if runtime.soul_burst_effect_timer_frames <= 0.0:
		runtime.soul_burst_dash_active = false

	for i in range(runtime.soul_burst_shockwaves.size() - 1, -1, -1):
		var wave: Dictionary = runtime._get_dict(runtime.soul_burst_shockwaves[i])
		var wave_life: float = float(wave.get("life", 0.0)) - step
		if wave_life <= 0.0:
			runtime.soul_burst_shockwaves.remove_at(i)
			continue
		wave["life"] = wave_life
		runtime.soul_burst_shockwaves[i] = wave

	for i in range(runtime.soul_burst_particles.size() - 1, -1, -1):
		var particle: Dictionary = runtime._get_dict(runtime.soul_burst_particles[i])
		var particle_life: float = float(particle.get("life", 0.0)) - step
		if particle_life <= 0.0:
			runtime.soul_burst_particles.remove_at(i)
			continue
		var position: Vector2 = runtime._get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity *= pow(0.95, step)
		particle["life"] = particle_life
		particle["position"] = position
		particle["velocity"] = velocity
		particle["size"] = max(1.0, float(particle.get("size", 2.0)) * pow(0.985, step))
		runtime.soul_burst_particles[i] = particle

	for i in range(runtime.soul_burst_wind_trails.size() - 1, -1, -1):
		var trail: Dictionary = runtime._get_dict(runtime.soul_burst_wind_trails[i])
		var trail_life: float = float(trail.get("life", 0.0)) - step
		if trail_life <= 0.0:
			runtime.soul_burst_wind_trails.remove_at(i)
			continue
		trail["life"] = trail_life
		trail["offset"] = (
			runtime._get_vector2(trail.get("offset", Vector2.ZERO))
			- Vector2(runtime.soul_burst_direction * 1.2 * step, 0.0)
		)
		runtime.soul_burst_wind_trails[i] = trail


func build_effects(runtime: Object) -> void:
	runtime.soul_burst_particles.clear()
	runtime.soul_burst_shockwaves.clear()
	runtime.soul_burst_wind_trails.clear()
	for wave_index in range(3):
		var max_life: float = max(8.0, SHOCKWAVE_FRAMES - float(wave_index) * 2.0)
		runtime.soul_burst_shockwaves.append({
			"start_radius": 18.0 + float(wave_index) * 8.0,
			"max_radius": 78.0 + float(wave_index) * 18.0,
			"squeeze": 0.62 + float(wave_index) * 0.08,
			"life": max_life,
			"max_life": max_life,
		})
	for _i in range(PARTICLE_COUNT):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 7.2)
		var forward_boost: Vector2 = Vector2(
			runtime.soul_burst_direction * randf_range(1.0, 5.0),
			randf_range(-1.0, 1.0)
		)
		var color: Color = [
			Color(92.0 / 255.0, 22.0 / 255.0, 170.0 / 255.0, 1.0),
			Color(170.0 / 255.0, 72.0 / 255.0, 1.0, 1.0),
			Color(235.0 / 255.0, 205.0 / 255.0, 1.0, 1.0),
		][randi() % 3]
		var life: float = randf_range(16.0, 30.0)
		runtime.soul_burst_particles.append({
			"position": runtime.soul_burst_center + Vector2(randf_range(-18.0, 18.0), randf_range(-16.0, 16.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed + forward_boost,
			"life": life,
			"max_life": life,
			"color": color,
			"size": randf_range(2.0, 4.8),
		})
	for _i in range(WIND_TRAIL_COUNT):
		var life: float = randf_range(10.0, 24.0)
		runtime.soul_burst_wind_trails.append({
			"offset": Vector2(
				-runtime.soul_burst_direction * randf_range(8.0, 58.0),
				randf_range(-28.0, 28.0)
			),
			"length": randf_range(34.0, 92.0),
			"width": randf_range(1.5, 4.0),
			"life": life,
			"max_life": life,
		})


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime.runtime_perk_state_ref if runtime != null else null)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
