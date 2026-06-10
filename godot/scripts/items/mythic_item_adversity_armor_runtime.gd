extends RefCounted

const ITEM_ADVERSITY_ARMOR := "adversity_armor"
const MAX_TRIGGER_CHANCE_PCT := 100.0
const DEFAULT_SERVE_SPEED_BONUS_PCT := 20.0
const FLASH_FRAMES := 30.0
const AURA_PARTICLE_MAX := 48
const BARRIER_PARTICLE_MAX := 72
const BARRIER_Y_OFFSET := 18.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_ADVERSITY_ARMOR)


func is_active(runtime: Object) -> bool:
	return is_equipped(runtime)


func is_invincible(runtime: Object) -> bool:
	return is_equipped(runtime) and runtime.adversity_armor_invincible_timer_frames > 0.0


func get_trigger_chance_pct(runtime: Object) -> float:
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_ADVERSITY_ARMOR, "trigger_chance_pct"),
		0.0,
		MAX_TRIGGER_CHANCE_PCT
	)


func get_invincible_duration_sec(runtime: Object) -> float:
	if not is_equipped(runtime):
		return 0.0
	return max(0.0, runtime.roll_query.get_equipped_roll_value(runtime, ITEM_ADVERSITY_ARMOR, "invincible_duration_sec"))


func get_serve_speed_bonus_pct(runtime: Object) -> float:
	return DEFAULT_SERVE_SPEED_BONUS_PCT if is_equipped(runtime) else 0.0


func get_ball_collision_context(runtime: Object) -> Dictionary:
	if not is_invincible(runtime):
		return {"adversity_armor_invincible": false}
	return {
		"adversity_armor_invincible": true,
		"adversity_armor_barrier_y": get_barrier_y(),
	}


func try_queue_after_loss(runtime: Object, deps: Dictionary) -> bool:
	if not is_equipped(runtime):
		clear_runtime(runtime)
		return false
	var chance_pct: float = get_trigger_chance_pct(runtime)
	if chance_pct <= 0.0:
		runtime.adversity_armor_last_trigger_roll_pct = -1.0
		runtime.adversity_armor_last_triggered = false
		return false
	if runtime.adversity_armor_pending_invincible:
		return true
	var roll_pct: float = randf() * 100.0
	runtime.adversity_armor_last_trigger_roll_pct = roll_pct
	runtime.adversity_armor_last_triggered = roll_pct <= chance_pct
	var deps_dict: Dictionary = runtime._get_dict(deps)
	if not runtime.adversity_armor_last_triggered:
		runtime._sync_owner(deps_dict.get("owner", null), deps_dict.get("registry", null))
		return false
	runtime.adversity_armor_pending_invincible = true
	runtime.adversity_armor_serve_speed_boost_pending = true
	runtime._sync_owner(deps_dict.get("owner", null), deps_dict.get("registry", null))
	return true


func on_round_start(runtime: Object, owner: Object, registry: Object) -> void:
	if not is_equipped(runtime):
		# This runs on every round restart. The full owner sync costs ~1.5ms,
		# so only push the cleared state when something owner-visible was
		# actually cleared; clearing an already-clean runtime needs no sync.
		var had_visible_state: bool = (
			is_effect_active(runtime)
			or runtime.adversity_armor_pending_invincible
			or runtime.adversity_armor_serve_speed_boost_pending
		)
		clear_runtime(runtime)
		if had_visible_state:
			runtime._sync_owner(owner, registry)
		return
	if not runtime.adversity_armor_pending_invincible:
		return
	runtime.adversity_armor_pending_invincible = false
	var duration_frames: float = get_invincible_duration_sec(runtime) * 60.0
	runtime.adversity_armor_invincible_timer_frames = max(0.0, duration_frames)
	runtime.adversity_armor_invincible_total_frames = runtime.adversity_armor_invincible_timer_frames
	runtime.adversity_armor_flash_timer_frames = FLASH_FRAMES
	runtime.adversity_armor_last_reflect_center = Vector2(
		FIELD_WIDTH * 0.5,
		get_barrier_y()
	)
	spawn_barrier_particles(runtime, runtime.adversity_armor_last_reflect_center, 22, false)
	runtime.audio_router.play_adversity_armor_activate_audio(runtime, registry)
	runtime.audio_router.apply_ragnarok_feedback(runtime, {"registry": registry}, 0.05, 1.7)
	runtime._sync_owner(owner, registry)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func consume_serve_speed_bonus(runtime: Object) -> float:
	if not is_equipped(runtime):
		runtime.adversity_armor_serve_speed_boost_pending = false
		return 0.0
	if not runtime.adversity_armor_serve_speed_boost_pending:
		return 0.0
	runtime.adversity_armor_serve_speed_boost_pending = false
	return get_serve_speed_bonus_pct(runtime) / 100.0


func notify_barrier_hit(
	runtime: Object,
	impact_pos: Vector2,
	ball_vel: Vector2,
	deps: Dictionary
) -> void:
	if not is_invincible(runtime):
		return
	runtime.adversity_armor_last_reflect_center = impact_pos
	runtime.adversity_armor_flash_timer_frames = max(
		runtime.adversity_armor_flash_timer_frames,
		FLASH_FRAMES * 0.55
	)
	spawn_barrier_particles(runtime, impact_pos, 18, true)
	var deps_dict: Dictionary = runtime._get_dict(deps)
	runtime.audio_router.play_adversity_armor_reflect_audio(runtime, deps_dict.get("registry", null), abs(ball_vel.y))
	runtime.audio_router.apply_ragnarok_feedback(runtime, deps, 0.06, 2.4)
	runtime._sync_owner(deps_dict.get("owner", null), deps_dict.get("registry", null))


func clear_runtime(runtime: Object) -> void:
	runtime.adversity_armor_pending_invincible = false
	runtime.adversity_armor_serve_speed_boost_pending = false
	runtime.adversity_armor_last_trigger_roll_pct = -1.0
	runtime.adversity_armor_last_triggered = false
	clear_active_state(runtime)


func clear_round_state(runtime: Object) -> void:
	clear_active_state(runtime)


func clear_active_state(runtime: Object) -> void:
	runtime.adversity_armor_invincible_timer_frames = 0.0
	runtime.adversity_armor_invincible_total_frames = 0.0
	runtime.adversity_armor_flash_timer_frames = 0.0
	runtime.adversity_armor_phase = 0.0
	runtime.adversity_armor_last_reflect_center = Vector2.ZERO
	runtime.adversity_armor_aura_particles.clear()
	runtime.adversity_armor_barrier_particles.clear()


func get_barrier_y() -> float:
	return FIELD_HEIGHT - BARRIER_Y_OFFSET


func get_timer_ratio(runtime: Object) -> float:
	if runtime.adversity_armor_invincible_total_frames <= 0.0:
		return 0.0
	return clamp(
		runtime.adversity_armor_invincible_timer_frames / runtime.adversity_armor_invincible_total_frames,
		0.0,
		1.0
	)


func update_runtime(runtime: Object, owner: Object, fps_scale: float) -> void:
	if not is_equipped(runtime):
		if (
			is_effect_active(runtime)
			or runtime.adversity_armor_pending_invincible
			or runtime.adversity_armor_serve_speed_boost_pending
		):
			clear_runtime(runtime)
		return
	var step: float = max(0.0, fps_scale)
	var was_invincible: bool = runtime.adversity_armor_invincible_timer_frames > 0.0
	if runtime.adversity_armor_invincible_timer_frames > 0.0:
		runtime.adversity_armor_invincible_timer_frames = max(
			0.0,
			runtime.adversity_armor_invincible_timer_frames - step
		)
		runtime.adversity_armor_phase += 0.09 * step
		spawn_idle_particles(runtime, owner)
	if was_invincible and runtime.adversity_armor_invincible_timer_frames <= 0.0:
		runtime.adversity_armor_invincible_total_frames = 0.0
	if runtime.adversity_armor_flash_timer_frames > 0.0:
		runtime.adversity_armor_flash_timer_frames = max(0.0, runtime.adversity_armor_flash_timer_frames - step)
	update_particles(runtime, step)


func spawn_idle_particles(runtime: Object, owner: Object) -> void:
	var player_center: Vector2 = resolve_player_center(runtime, owner)
	while runtime.adversity_armor_aura_particles.size() < min(12, AURA_PARTICLE_MAX):
		runtime.adversity_armor_aura_particles.append({
			"position": player_center + Vector2(randf_range(-48.0, 48.0), randf_range(-30.0, 22.0)),
			"velocity": Vector2(randf_range(-0.24, 0.24), randf_range(-0.62, -0.18)),
			"life": randf_range(18.0, 38.0),
			"max_life": 38.0,
			"size": randf_range(1.4, 3.4),
		})
	while runtime.adversity_armor_barrier_particles.size() < min(18, BARRIER_PARTICLE_MAX):
		runtime.adversity_armor_barrier_particles.append({
			"position": Vector2(
				randf_range(26.0, FIELD_WIDTH - 26.0),
				get_barrier_y() + randf_range(-4.0, 4.0)
			),
			"velocity": Vector2(randf_range(-0.65, 0.65), randf_range(-0.26, 0.26)),
			"life": randf_range(20.0, 44.0),
			"max_life": 44.0,
			"size": randf_range(1.3, 3.2),
		})


func spawn_barrier_particles(
	runtime: Object,
	center: Vector2,
	count: int,
	impact: bool
) -> void:
	for _i in range(max(0, count)):
		var angle: float = randf_range(PI, TAU) if impact else randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 6.2) if impact else randf_range(0.7, 2.4)
		runtime.adversity_armor_barrier_particles.append({
			"position": center + Vector2(randf_range(-18.0, 18.0), randf_range(-5.0, 5.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(16.0, 34.0) if impact else randf_range(20.0, 42.0),
			"max_life": 34.0 if impact else 42.0,
			"size": randf_range(1.8, 4.8) if impact else randf_range(1.2, 3.0),
			"impact": impact,
		})
	while runtime.adversity_armor_barrier_particles.size() > BARRIER_PARTICLE_MAX:
		runtime.adversity_armor_barrier_particles.pop_front()


func update_particles(runtime: Object, step: float) -> void:
	var aura_write_index := 0
	for read_index in range(runtime.adversity_armor_aura_particles.size()):
		var particle: Dictionary = runtime._get_dict(runtime.adversity_armor_aura_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		var position: Vector2 = runtime._get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity.x *= pow(0.985, step)
		particle["position"] = position
		particle["velocity"] = velocity
		particle["life"] = life
		runtime.adversity_armor_aura_particles[aura_write_index] = particle
		aura_write_index += 1
	if aura_write_index < runtime.adversity_armor_aura_particles.size():
		runtime.adversity_armor_aura_particles.resize(aura_write_index)

	var barrier_write_index := 0
	for read_index in range(runtime.adversity_armor_barrier_particles.size()):
		var particle: Dictionary = runtime._get_dict(runtime.adversity_armor_barrier_particles[read_index])
		var life: float = float(particle.get("life", 0.0)) - step
		if life <= 0.0:
			continue
		var position: Vector2 = runtime._get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = runtime._get_vector2(particle.get("velocity", Vector2.ZERO))
		position += velocity * step
		velocity *= pow(0.965, step)
		particle["position"] = position
		particle["velocity"] = velocity
		particle["life"] = life
		barrier_write_index += 1
		runtime.adversity_armor_barrier_particles[barrier_write_index - 1] = particle
	if barrier_write_index < runtime.adversity_armor_barrier_particles.size():
		runtime.adversity_armor_barrier_particles.resize(barrier_write_index)


func resolve_player_center(runtime: Object, owner: Object) -> Vector2:
	if owner == null:
		return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5)
	var player_pos: Vector2 = runtime._get_vector2(
		runtime._safe_owner_get(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT))
	)
	var player_width: float = max(1.0, float(runtime._safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var player_height: float = max(1.0, float(runtime._safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	return player_pos + Vector2(player_width * 0.5, player_height * 0.5)


func is_effect_active(runtime: Object) -> bool:
	return (
		runtime.adversity_armor_invincible_timer_frames > 0.0
		or runtime.adversity_armor_flash_timer_frames > 0.0
		or not runtime.adversity_armor_aura_particles.is_empty()
		or not runtime.adversity_armor_barrier_particles.is_empty()
	)
