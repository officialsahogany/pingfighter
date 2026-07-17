extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_VENOM_MIST_GAUNTLET := "venom_mist_gauntlet"
const RADIUS := 120.0
const DEFAULT_DURATION_SEC := 3.0
const MAX_TRIGGER_CHANCE_PCT := 100.0
const BOSS_SLOW_AMOUNT := 0.70
const GAUGE_DRAIN_PER_FRAME := 0.5
const HONGRYUN_DRAIN_THRESHOLD := 60.0
const FADE_IN_FRAMES := 18.0
const FADE_OUT_FRAMES := 30.0
const PARTICLE_COUNT := 46
const PARTICLE_MAX := 76


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_VENOM_MIST_GAUNTLET)


func is_active(runtime: Object) -> bool:
	return is_equipped(runtime)


func is_venom_mist_gauntlet_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_VENOM_MIST_GAUNTLET) > 0
	return is_equipped(runtime)


func get_count(runtime: Object) -> int:
	return runtime.roll_query.count_equipped_item_name(runtime, ITEM_VENOM_MIST_GAUNTLET)


func get_trigger_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_VENOM_MIST_GAUNTLET, "mist_trigger_chance_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_VENOM_MIST_GAUNTLET, "mist_trigger_chance_pct"),
		0.0,
		MAX_TRIGGER_CHANCE_PCT
	)


func get_trigger_chance(runtime: Object) -> float:
	return get_trigger_chance_pct(runtime) / 100.0


func get_duration_sec(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_VENOM_MIST_GAUNTLET, "mist_duration_sec")
	if not is_equipped(runtime):
		return 0.0
	var duration_sec: float = runtime.roll_query.get_equipped_roll_max(runtime, ITEM_VENOM_MIST_GAUNTLET, "mist_duration_sec")
	if duration_sec <= 0.0:
		duration_sec = DEFAULT_DURATION_SEC
	return clamp(duration_sec, 2.0, 5.0)


func get_boss_slow_multiplier(_runtime: Object) -> float:
	return max(0.05, 1.0 - BOSS_SLOW_AMOUNT)


func is_ball_poisoned(runtime: Object) -> bool:
	return runtime.venom_mist_ball_poisoned


func is_field_active(runtime: Object) -> bool:
	return runtime.venom_mist_field_active


func is_boss_in_field(runtime: Object) -> bool:
	return runtime.venom_mist_field_active and runtime.venom_mist_boss_in_field


func try_poison_ball(runtime: Object, deps: Dictionary) -> bool:
	if not is_venom_mist_gauntlet_effect_active(runtime):
		runtime.venom_mist_ball_poisoned = false
		return false
	if runtime.venom_mist_ball_poisoned:
		return true
	var chance: float = get_trigger_chance(runtime)
	if chance <= 0.0 or randf() >= chance:
		return false
	runtime.venom_mist_ball_poisoned = true
	runtime.audio_router.play_venom_mist_poison_audio(runtime, runtime._get_dict(deps).get("registry", null))
	return true


func consume_ball_poison(runtime: Object, boss_center: Vector2, deps: Dictionary) -> bool:
	if not runtime.venom_mist_ball_poisoned:
		return false
	runtime.venom_mist_ball_poisoned = false
	return try_spawn_at_boss(runtime, boss_center, deps, true)


func try_spawn_at_boss(
	runtime: Object,
	boss_center: Vector2,
	deps: Dictionary,
	force: bool
) -> bool:
	if not is_venom_mist_gauntlet_effect_active(runtime):
		return false
	if not force:
		var chance: float = get_trigger_chance(runtime)
		if chance <= 0.0 or randf() >= chance:
			return false
	start_field(runtime, boss_center, runtime._get_dict(deps).get("registry", null))
	return true


func clear_runtime(runtime: Object) -> void:
	runtime.venom_mist_ball_poisoned = false
	runtime.venom_mist_field_active = false
	runtime.venom_mist_timer_frames = 0.0
	runtime.venom_mist_duration_frames = 0.0
	runtime.venom_mist_center = Vector2.ZERO
	runtime.venom_mist_particles.clear()
	runtime.venom_mist_gauge_drain_accumulator = 0.0
	runtime.venom_mist_boss_in_field = false


func update_runtime(runtime: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_venom_mist_gauntlet_effect_active(runtime):
		clear_runtime(runtime)
		return
	if runtime.venom_mist_field_active:
		runtime.venom_mist_timer_frames = max(0.0, runtime.venom_mist_timer_frames - fps_scale)
		if runtime.venom_mist_timer_frames <= 0.0:
			runtime.venom_mist_field_active = false
			runtime.venom_mist_boss_in_field = false
			runtime.venom_mist_gauge_drain_accumulator = 0.0
	else:
		runtime.venom_mist_boss_in_field = false
	update_particles(runtime, fps_scale)
	if not runtime.venom_mist_field_active:
		return
	var boss_center: Vector2 = read_owner_boss_center(runtime, owner)
	runtime.venom_mist_boss_in_field = boss_center.distance_to(runtime.venom_mist_center) <= RADIUS
	if runtime.venom_mist_boss_in_field:
		update_boss_gauge_drain(runtime, owner, registry, fps_scale)


func start_field(runtime: Object, center: Vector2, registry: Object) -> void:
	runtime.venom_mist_field_active = true
	runtime.venom_mist_center = center
	runtime.venom_mist_duration_frames = max(1.0, get_duration_sec(runtime) * 60.0)
	runtime.venom_mist_timer_frames = runtime.venom_mist_duration_frames
	runtime.venom_mist_gauge_drain_accumulator = 0.0
	runtime.venom_mist_boss_in_field = false
	build_particles(runtime)
	runtime.audio_router.play_venom_mist_spawn_audio(runtime, registry)


func update_boss_gauge_drain(
	runtime: Object,
	owner: Object,
	registry: Object,
	fps_scale: float
) -> void:
	var current_stage: int = int(runtime._safe_owner_get(owner, "current_stage", 1))
	runtime.venom_mist_gauge_drain_accumulator += GAUGE_DRAIN_PER_FRAME * max(0.0, fps_scale)
	if current_stage == 5:
		if runtime.venom_mist_gauge_drain_accumulator < HONGRYUN_DRAIN_THRESHOLD:
			return
		runtime.venom_mist_gauge_drain_accumulator -= HONGRYUN_DRAIN_THRESHOLD
		drain_boss_special_gauge(runtime, registry, 1.0, current_stage)
		return
	var drain_amount: int = int(floor(runtime.venom_mist_gauge_drain_accumulator))
	if drain_amount <= 0:
		return
	runtime.venom_mist_gauge_drain_accumulator -= float(drain_amount)
	drain_boss_special_gauge(runtime, registry, float(drain_amount), current_stage)


func drain_boss_special_gauge(runtime: Object, registry: Object, amount: float, current_stage: int) -> bool:
	if amount <= 0.0:
		return false
	var state_keys: Array = []
	match current_stage:
		1:
			state_keys = ["stage1_dalji_whip_skill_state"]
		2:
			state_keys = ["stage2_boss_skill_state"]
		_:
			state_keys = ["stage1_dalji_whip_skill_state", "stage2_boss_skill_state"]
	for key in state_keys:
		var state: Object = runtime._get_instance(registry, str(key))
		if state == null:
			continue
		if state.has_method("drain_boss_special_gauge"):
			state.drain_boss_special_gauge(amount)
			return true
		var current_value: Variant = state.get("boss_special_gauge")
		if current_value != null:
			state.set("boss_special_gauge", max(0.0, float(current_value) - amount))
			return true
	return false


func read_owner_boss_center(runtime: Object, owner: Object) -> Vector2:
	var boss_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "boss_pos", Vector2(330.0, 25.0)))
	var boss_width: float = max(1.0, float(runtime._safe_owner_get(owner, "boss_paddle_width", 100.0)))
	var boss_height: float = max(1.0, float(runtime._safe_owner_get(owner, "boss_hitbox_height", 40.0)))
	var boss_size_value: Variant = runtime._safe_owner_get(owner, "boss_paddle_size", Vector2.ZERO)
	if boss_size_value is Vector2 and boss_size_value != Vector2.ZERO:
		var boss_size: Vector2 = boss_size_value
		boss_width = max(1.0, boss_size.x)
		boss_height = max(1.0, boss_size.y)
	return boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)


func build_particles(runtime: Object) -> void:
	runtime.venom_mist_particles.clear()
	for _i in range(PARTICLE_COUNT):
		runtime.venom_mist_particles.append(create_particle(true))


func create_particle(random_life: bool = false) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var dist: float = RADIUS * sqrt(randf())
	var offset := Vector2(cos(angle), sin(angle)) * dist
	var drift_angle: float = angle + randf_range(-PI * 0.65, PI * 0.65)
	var velocity := Vector2(cos(drift_angle), sin(drift_angle)) * randf_range(0.12, 0.42)
	var life: float = randf_range(45.0, 95.0) if random_life else 95.0
	return {
		"offset": offset,
		"velocity": velocity,
		"size": randf_range(9.0, 24.0),
		"life": life,
		"max_life": life,
		"alpha": randf_range(0.12, 0.36),
		"layer": randi() % 3,
	}


func update_particles(runtime: Object, fps_scale: float) -> void:
	for i in range(runtime.venom_mist_particles.size() - 1, -1, -1):
		var particle: Dictionary = runtime._get_dict(runtime.venom_mist_particles[i])
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			if runtime.venom_mist_field_active:
				runtime.venom_mist_particles[i] = create_particle()
			else:
				runtime.venom_mist_particles.remove_at(i)
			continue
		var offset: Vector2 = runtime._get_vector2(particle.get("offset", Vector2.ZERO))
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		offset += velocity * fps_scale
		if offset.length() > RADIUS * 1.08:
			offset = offset.normalized() * RADIUS * randf_range(0.45, 0.92)
		particle["offset"] = offset
		particle["life"] = life
		particle["size"] = max(2.0, float(particle.get("size", 8.0)) + sin((life + float(i)) * 0.08) * 0.04 * fps_scale)
		runtime.venom_mist_particles[i] = particle
	while runtime.venom_mist_field_active and runtime.venom_mist_particles.size() < PARTICLE_COUNT:
		runtime.venom_mist_particles.append(create_particle())
	while runtime.venom_mist_particles.size() > PARTICLE_MAX:
		runtime.venom_mist_particles.pop_front()


func get_alpha(runtime: Object) -> float:
	if runtime.venom_mist_duration_frames <= 0.0:
		return 0.0
	var elapsed: float = max(0.0, runtime.venom_mist_duration_frames - runtime.venom_mist_timer_frames)
	var fade_in: float = clamp(elapsed / FADE_IN_FRAMES, 0.0, 1.0)
	var fade_out: float = clamp(runtime.venom_mist_timer_frames / FADE_OUT_FRAMES, 0.0, 1.0)
	return min(fade_in, fade_out)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime.runtime_perk_state_ref if runtime != null else null)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
