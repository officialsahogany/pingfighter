extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SHRAPNEL_ARMOR := "shrapnel_armor"
const MAX_TRIGGER_CHANCE_PCT := 100.0
const MAX_SHARD_COUNT := 24
const MAX_GAUGE_COST := 200.0
const SHARD_LIFE_FRAMES := 120.0
const SHARD_TRAIL_POINTS := 5
const DUST_MAX := 96
const FLASH_FRAMES := 8.0
const BOSS_STUN_FRAMES := 15.0
const BOSS_KNOCKBACK_FRAMES := 36.0
const BOSS_KNOCKBACK_DECAY := 0.85
const BOSS_IMPACT_FRAMES := 15.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_SHRAPNEL_ARMOR)


func is_active(runtime: Object) -> bool:
	return is_equipped(runtime)


func is_shrapnel_armor_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_SHRAPNEL_ARMOR) > 0
	return is_equipped(runtime)


func get_trigger_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_SHRAPNEL_ARMOR, "trigger_chance_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SHRAPNEL_ARMOR, "trigger_chance_pct"),
		0.0,
		MAX_TRIGGER_CHANCE_PCT
	)


func get_shard_count(runtime: Object) -> int:
	if PerkConversionFlags.is_enabled():
		return clampi(
			int(round(_get_converted_perk_value(runtime, ITEM_SHRAPNEL_ARMOR, "shard_count"))),
			0,
			MAX_SHARD_COUNT
		)
	if not is_equipped(runtime):
		return 0
	return clampi(
		int(round(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SHRAPNEL_ARMOR, "shard_count"))),
		0,
		MAX_SHARD_COUNT
	)


func get_knockback_level(runtime: Object) -> int:
	if PerkConversionFlags.is_enabled():
		return max(0, int(round(_get_converted_perk_value(runtime, ITEM_SHRAPNEL_ARMOR, "knockback_level"))))
	if not is_equipped(runtime):
		return 0
	return max(
		1,
		int(round(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SHRAPNEL_ARMOR, "knockback_level")))
	)


func get_gauge_cost(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return clamp(
			_get_converted_perk_value(runtime, ITEM_SHRAPNEL_ARMOR, "gauge_cost"),
			0.0,
			MAX_GAUGE_COST
		)
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SHRAPNEL_ARMOR, "gauge_cost"),
		0.0,
		MAX_GAUGE_COST
	)


func try_proc_player_hit(
	runtime: Object,
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not is_shrapnel_armor_effect_active(runtime):
		clear_runtime(runtime)
		return {"activated": false}
	var chance_pct: float = get_trigger_chance_pct(runtime)
	if chance_pct <= 0.0:
		return {"activated": false}
	var gauge_cost: float = get_gauge_cost(runtime)
	var current_special_gauge: float = current_gauge(runtime, context, deps)
	if current_special_gauge + 0.001 < gauge_cost:
		return {
			"activated": false,
			"special_gauge": current_special_gauge,
			"insufficient_gauge": true,
			"gauge_cost": gauge_cost,
		}
	if randf() * 100.0 >= chance_pct:
		return {"activated": false, "special_gauge": current_special_gauge}
	var spend_result: Dictionary = consume_gauge(runtime, gauge_cost, context, deps)
	if not bool(spend_result.get("ok", false)):
		return {
			"activated": false,
			"special_gauge": float(spend_result.get("special_gauge", current_special_gauge)),
			"insufficient_gauge": true,
			"gauge_cost": gauge_cost,
		}
	var shard_count: int = get_shard_count(runtime)
	var knockback_level: int = get_knockback_level(runtime)
	start_burst(runtime, resolve_spawn_center(runtime, ball_pos, context, deps), shard_count)
	runtime.shrapnel_armor_last_proc_shard_count = shard_count
	runtime.shrapnel_armor_last_gauge_cost = gauge_cost
	var deps_dict: Dictionary = runtime._get_dict(deps)
	runtime.audio_router.play_shrapnel_armor_fire_audio(runtime, deps_dict.get("registry", null))
	runtime.audio_router.apply_ragnarok_feedback(runtime, deps, 0.045, 1.8)
	runtime.gauge_feedback.trigger_gauge_flash(runtime, deps)
	runtime._sync_owner(deps_dict.get("owner", null), deps_dict.get("registry", null))
	return {
		"activated": true,
		"special_gauge": float(spend_result.get("special_gauge", current_special_gauge)),
		"gauge_cost": gauge_cost,
		"trigger_chance_pct": chance_pct,
		"shard_count": shard_count,
		"knockback_level": knockback_level,
	}


func clear_runtime(runtime: Object) -> void:
	clear_active_state(runtime)
	runtime.shrapnel_armor_last_proc_shard_count = 0
	runtime.shrapnel_armor_last_gauge_cost = 0.0


func clear_round_state(runtime: Object) -> void:
	clear_active_state(runtime)


func clear_active_state(runtime: Object) -> void:
	runtime.shrapnel_armor_shards.clear()
	runtime.shrapnel_armor_dust_particles.clear()
	runtime.shrapnel_armor_flash_timer_frames = 0.0
	runtime.shrapnel_armor_flash_center = Vector2.ZERO
	runtime.shrapnel_armor_boss_impact_timer_frames = 0.0
	runtime.shrapnel_armor_boss_impact_center = Vector2.ZERO
	runtime.shrapnel_armor_boss_knockback_timer_frames = 0.0
	runtime.shrapnel_armor_boss_knockback_vel = 0.0
	runtime.shrapnel_armor_boss_stun_timer_frames = 0.0


func current_gauge(runtime: Object, context: Dictionary, deps: Dictionary) -> float:
	var owner: Object = runtime._get_dict(deps).get("owner", context.get("owner", null))
	var fallback: float = float(context.get("special_gauge", 0.0))
	if owner != null:
		return max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", fallback)))
	return max(0.0, fallback)


func consume_gauge(runtime: Object, gauge_cost: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var current_special_gauge: float = current_gauge(runtime, context, deps)
	if gauge_cost <= 0.0:
		context["special_gauge"] = current_special_gauge
		return {"ok": true, "special_gauge": current_special_gauge}
	if current_special_gauge + 0.001 < gauge_cost:
		return {"ok": false, "special_gauge": current_special_gauge}
	var next_gauge: float = max(0.0, current_special_gauge - gauge_cost)
	var owner: Object = runtime._get_dict(deps).get("owner", context.get("owner", null))
	if owner != null:
		owner.set("special_gauge", next_gauge)
	context["special_gauge"] = next_gauge
	return {"ok": true, "special_gauge": next_gauge}


func resolve_spawn_center(
	runtime: Object,
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Vector2:
	var owner: Object = runtime._get_dict(deps).get("owner", context.get("owner", null))
	var fallback_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_pos: Vector2 = runtime._get_vector2(context.get("player_pos", fallback_pos))
	var paddle_width: float = max(1.0, float(context.get(
		"player_paddle_width",
		context.get("paddle_width", runtime._safe_owner_get(
			owner,
			"player_paddle_width",
			PLAYER_BASE_PADDLE_WIDTH
		))
	)))
	if player_pos != Vector2.ZERO or context.has("player_pos"):
		return player_pos + Vector2(paddle_width * 0.5, 0.0)
	return ball_pos


func start_burst(runtime: Object, center: Vector2, shard_count: int) -> void:
	var count: int = clampi(shard_count, 0, MAX_SHARD_COUNT)
	if count <= 0:
		return
	var spread_deg: float = 60.0
	for i in range(count):
		var ratio: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var angle: float = deg_to_rad(-90.0 + spread_deg * (ratio - 0.5))
		var speed: float = randf_range(9.4, 14.0)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
		var shard_life_frames: float = SHARD_LIFE_FRAMES
		runtime.shrapnel_armor_shards.append({
			"position": center + Vector2(randf_range(-10.0, 10.0), 0.0),
			"velocity": velocity,
			"life": shard_life_frames,
			"max_life": shard_life_frames,
			"size": randf_range(3.0, 6.0),
			"rotation": randf_range(0.0, TAU),
			"rot_speed": deg_to_rad(randf_range(-15.0, 15.0)),
			"color_shift": randf_range(-20.0, 20.0),
			"trail": [],
		})
	runtime.shrapnel_armor_flash_timer_frames = FLASH_FRAMES
	runtime.shrapnel_armor_flash_center = center


func update_runtime(runtime: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_shrapnel_armor_effect_active(runtime):
		if is_effect_active(runtime):
			clear_runtime(runtime)
		return
	var step: float = max(0.0, fps_scale)
	if runtime.shrapnel_armor_flash_timer_frames > 0.0:
		runtime.shrapnel_armor_flash_timer_frames = max(0.0, runtime.shrapnel_armor_flash_timer_frames - step)
	if runtime.shrapnel_armor_boss_impact_timer_frames > 0.0:
		runtime.shrapnel_armor_boss_impact_timer_frames = max(
			0.0,
			runtime.shrapnel_armor_boss_impact_timer_frames - step
		)
	if runtime.shrapnel_armor_boss_stun_timer_frames > 0.0:
		runtime.shrapnel_armor_boss_stun_timer_frames = max(
			0.0,
			runtime.shrapnel_armor_boss_stun_timer_frames - step
		)
	if runtime.shrapnel_armor_boss_knockback_timer_frames > 0.0:
		runtime.shrapnel_armor_boss_knockback_timer_frames = max(
			0.0,
			runtime.shrapnel_armor_boss_knockback_timer_frames - step
		)
		runtime.shrapnel_armor_boss_knockback_vel *= pow(
			BOSS_KNOCKBACK_DECAY,
			step
		)
		if (
			runtime.shrapnel_armor_boss_knockback_timer_frames <= 0.0
			or abs(runtime.shrapnel_armor_boss_knockback_vel) <= 0.3
		):
			runtime.shrapnel_armor_boss_knockback_timer_frames = 0.0
			runtime.shrapnel_armor_boss_knockback_vel = 0.0
	elif abs(runtime.shrapnel_armor_boss_knockback_vel) > 0.0:
		runtime.shrapnel_armor_boss_knockback_vel = 0.0

	var boss_rect: Rect2 = get_boss_rect(runtime, owner)
	var can_hit_boss: bool = (
		boss_rect.size != Vector2.ZERO
		and not runtime.stage_immunity.is_stage2_speed_defense_boss_immune(runtime, registry)
	)
	var write_index := 0
	for read_index in range(runtime.shrapnel_armor_shards.size()):
		var shard: Dictionary = runtime._get_dict(runtime.shrapnel_armor_shards[read_index])
		var position: Vector2 = runtime._get_vector2(shard.get("position", Vector2.ZERO))
		var velocity: Vector2 = runtime._get_vector2(shard.get("velocity", Vector2.ZERO))
		var trail: Array = runtime._get_array(shard.get("trail", [])).duplicate()
		trail.append(position)
		while trail.size() > SHARD_TRAIL_POINTS:
			trail.pop_front()
		position += velocity * step
		velocity.y += 0.08 * step
		var life: float = float(shard.get("life", 0.0)) - step
		var rotation: float = float(shard.get("rotation", 0.0)) + float(shard.get("rot_speed", 0.0)) * step
		if can_hit_boss and boss_rect.has_point(position):
			spawn_dust(runtime, position, 9, true)
			apply_boss_hit(runtime, position, velocity, boss_rect, registry)
			continue
		var expired: bool = (
			life <= 0.0
			or position.x <= 0.0
			or position.x >= FIELD_WIDTH
			or position.y <= 0.0
			or position.y >= FIELD_HEIGHT
		)
		if expired:
			spawn_dust(runtime, position, 4, false)
			continue
		shard["position"] = position
		shard["velocity"] = velocity
		shard["life"] = life
		shard["rotation"] = rotation
		shard["trail"] = trail
		runtime.shrapnel_armor_shards[write_index] = shard
		write_index += 1
	if write_index < runtime.shrapnel_armor_shards.size():
		runtime.shrapnel_armor_shards.resize(write_index)
	update_dust(runtime, step)


func update_dust(runtime: Object, step: float) -> void:
	var write_index := 0
	for read_index in range(runtime.shrapnel_armor_dust_particles.size()):
		var particle: Dictionary = runtime._get_dict(runtime.shrapnel_armor_dust_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		var position: Vector2 = runtime._get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity.x *= pow(0.96, step)
		velocity.y -= 0.03 * step
		particle["position"] = position
		particle["velocity"] = velocity
		particle["life"] = life
		particle["size"] = max(0.4, float(particle.get("size", 2.0)) - 0.06 * step)
		runtime.shrapnel_armor_dust_particles[write_index] = particle
		write_index += 1
	if write_index < runtime.shrapnel_armor_dust_particles.size():
		runtime.shrapnel_armor_dust_particles.resize(write_index)
	while runtime.shrapnel_armor_dust_particles.size() > DUST_MAX:
		runtime.shrapnel_armor_dust_particles.pop_front()


func spawn_dust(runtime: Object, center: Vector2, count: int, impact: bool) -> void:
	for _i in range(max(0, count)):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(1.1, 4.2) if impact else randf_range(0.6, 2.4)
		runtime.shrapnel_armor_dust_particles.append({
			"position": center + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(12.0, 26.0) if impact else randf_range(8.0, 18.0),
			"max_life": 26.0 if impact else 18.0,
			"size": randf_range(1.4, 3.8) if impact else randf_range(0.8, 2.4),
			"color": Color(1.0, randf_range(0.55, 0.78), randf_range(0.18, 0.32), 1.0),
		})
	while runtime.shrapnel_armor_dust_particles.size() > DUST_MAX:
		runtime.shrapnel_armor_dust_particles.pop_front()


func get_boss_rect(runtime: Object, owner: Object) -> Rect2:
	if owner == null:
		return Rect2()
	var boss_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "boss_pos", Vector2.ZERO))
	var boss_size: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "boss_paddle_size", Vector2.ZERO))
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			max(1.0, float(runtime._safe_owner_get(owner, "boss_paddle_width", 100.0))),
			max(1.0, float(runtime._safe_owner_get(owner, "boss_hitbox_height", 40.0)))
		)
	if boss_pos == Vector2.ZERO and runtime._safe_owner_get(owner, "boss_pos", null) == null:
		return Rect2()
	return Rect2(boss_pos, boss_size).grow(3.0)


func apply_boss_hit(
	runtime: Object,
	hit_pos: Vector2,
	velocity: Vector2,
	boss_rect: Rect2,
	registry: Object
) -> void:
	var direction: float = sign(velocity.x)
	if abs(direction) <= 0.01:
		direction = -1.0 if hit_pos.x >= boss_rect.get_center().x else 1.0
	runtime.shrapnel_armor_boss_knockback_vel = (
		direction * get_knockback_velocity(get_knockback_level(runtime))
	)
	runtime.shrapnel_armor_boss_knockback_timer_frames = BOSS_KNOCKBACK_FRAMES
	runtime.shrapnel_armor_boss_stun_timer_frames = max(
		runtime.shrapnel_armor_boss_stun_timer_frames,
		BOSS_STUN_FRAMES
	)
	runtime.shrapnel_armor_boss_impact_timer_frames = BOSS_IMPACT_FRAMES
	runtime.shrapnel_armor_boss_impact_center = boss_rect.get_center()
	runtime.audio_router.play_shrapnel_armor_hit_audio(runtime, registry)


func get_knockback_velocity(level: int) -> float:
	match max(1, level):
		1:
			return 6.0
		2:
			return 9.6
		3:
			return 14.4
		4:
			return 19.2
		_:
			return 19.2 + float(max(0, level - 4)) * 4.8


func is_effect_active(runtime: Object) -> bool:
	return (
		runtime.shrapnel_armor_flash_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_impact_timer_frames > 0.0
		or runtime.shrapnel_armor_boss_stun_timer_frames > 0.0
		or not runtime.shrapnel_armor_shards.is_empty()
		or not runtime.shrapnel_armor_dust_particles.is_empty()
	)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level, runtime.runtime_perk_state_ref if runtime != null else null)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
