extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetSkeletonArcherPayloadFactory := preload("res://scripts/lingpet/lingpet_skeleton_archer_payload_factory.gd")
const LingpetSkeletonArcherRenderer := preload("res://scripts/lingpet/lingpet_skeleton_archer_renderer.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const GAME_LEFT := 0.0
const GAME_RIGHT := FIELD_WIDTH
const PLAYER_PATROL_Y_MIN := 570.0
const PLAYER_PATROL_Y_MAX := 690.0
const TOP_PATROL_Y_MIN := 100.0
const TOP_PATROL_Y_MAX := 220.0
const ARCHER_WIDTH := 30.0
const ARCHER_HEIGHT := 50.0
# Ball-vs-archer break geometry. The archer is drawn as a ~30x50 hovering figure, so modeling the
# break hit as a circle of only its half-WIDTH (15px) under-covered the much taller body and made a
# boss-returned ball feel like it "passed through" the archer without shattering it. This padding
# widens the break circle beyond the body half-width so a returned ball that passes near ANY part of
# the archer body reliably breaks it. Single lever -- raise to make the archer easier to break.
const ARCHER_HIT_RADIUS_PADDING := 12.0
const ARCHER_SPEED_PER_FRAME := 3.0
const ARCHER_SPEED := ARCHER_SPEED_PER_FRAME * 60.0
const ARROW_SPEED_PER_FRAME := 12.0
const ARROW_SPEED := ARROW_SPEED_PER_FRAME * 60.0
const ARROW_DRAW_TIME_BY_LEVEL := [1.00, 0.92, 0.84, 0.76, 0.68]
# Arrow fire cooldowns. Two cumulative nerfs vs the original tuning: +30% (read too strong), then a
# further +20% overall cooldown pass. Kept in sync with the lingpet_catalog nekuring_skeleton_archer
# arrays; these are the runtime fallbacks. (pre-20%: min [1.30,1.17,0.98,0.81,0.65] / max [3.90,3.38,2.86,2.34,1.95])
const ARROW_COOLDOWN_MIN_BY_LEVEL := [1.56, 1.40, 1.18, 0.97, 0.78]
const ARROW_COOLDOWN_MAX_BY_LEVEL := [4.68, 4.06, 3.43, 2.81, 2.34]
const EMERGE_DURATION := 1.2
const DEATH_DURATION := 0.7
const ARROW_MAX_AGE := 5.0
const PARTICLE_MAX := 96
const BALL_RADIUS_FALLBACK := 14.3
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const GOLDEN_CHANCE_BY_LEVEL := [0.0, 0.0, 0.20, 0.30, 0.30]
const BONUS_SUMMON_CHANCE_BY_LEVEL := [0.0, 0.0, 0.0, 0.0, 0.30]
const GOLDEN_SPREAD_DEGREES := 20.0
const NORMAL_SPREAD_DEGREES := 15.0
const ORIGINAL_KNOCKBACK_VEL := 150.0
const GODOT_KNOCKBACK_VELOCITY := 14.0
const GODOT_KNOCKBACK_FRAMES := 36.0
const GODOT_KNOCKBACK_DECAY := 0.85
const STATUS_SOURCE := "nekuring_skeleton_archer"
# Archers never expire on their own (original duration is effectively infinite -- they
# only die when a boss-returned ball hits them), and launch() is re-cast every cooldown
# with no occupancy check, so a long rally with no archer deaths lets them accumulate.
# Each full-detail archer now costs ~150-250 antialiased draw primitives (vs ~12 in the
# pre-upgrade abstraction), so the draw cost is per_archer x count -- count is the only
# unbounded scale axis. This generous soft cap bounds worst-case accumulation (typical
# play sits at 1-3 archers and never reaches it); over-cap archers gracefully dissolve.
const MAX_CONCURRENT_ARCHERS := 6

# Presentation-only geometry and composition live in LingpetSkeletonArcherRenderer.
var _renderer: Object = LingpetSkeletonArcherRenderer.new()

var _archers: Array[Dictionary] = []
var _dying_archers: Array[Dictionary] = []
var _arrows: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _active := false
var _active_skill_level := 1
var _next_archer_id := 1
var _summon_count := 0
var _arrow_fire_count := 0
var _arrow_hit_count := 0
var _archer_death_count := 0
var _last_hit_pos := Vector2.ZERO
var _last_knockback_velocity := 0.0
var _last_registry: Object = null
var _arrow_draw_time := 1.0
var _arrow_cooldown_min := 1.0
var _arrow_cooldown_max := 3.0
var _golden_chance := 0.0
var _bonus_summon_chance := 0.0
var _golden_rolls_for_tests: Array[float] = []
var _bonus_summon_rolls_for_tests: Array[float] = []
var _normal_spread_degrees_for_tests: Array[float] = []


func reset() -> void:
	_archers.clear()
	_dying_archers.clear()
	_arrows.clear()
	_particles.clear()
	_active = false
	_active_skill_level = 1
	_next_archer_id = 1
	_summon_count = 0
	_arrow_fire_count = 0
	_arrow_hit_count = 0
	_archer_death_count = 0
	_last_hit_pos = Vector2.ZERO
	_last_knockback_velocity = 0.0
	_sync_level_values({})


func cancel(_owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_last_registry = registry
	reset()


# Round-boundary reset: summoned archers persist into the next round (mirrors
# Bone Barrier's reset_round so the Nekuring archers stay deployed across rounds),
# so only the transient in-flight arrows, bone-fragment dissolves, and particles
# are cleared. A full reset() / cancel() (companion change / hatch / new battle /
# unequip) still wipes the archers too, so nothing leaks across sessions.
func reset_round() -> void:
	_arrows.clear()
	_dying_archers.clear()
	_particles.clear()
	_active = not _archers.is_empty()


func prewarm() -> void:
	pass


func launch(origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_last_registry = ctx_registry as Object
	_active = true
	_sync_level_values(launch_context)
	var caster_is_top := bool(launch_context.get("caster_is_top", false))
	var patrol_min := TOP_PATROL_Y_MIN if caster_is_top else PLAYER_PATROL_Y_MIN
	var patrol_max := TOP_PATROL_Y_MAX if caster_is_top else PLAYER_PATROL_Y_MAX
	var spawn_x := _get_context_float(launch_context, "spawn_x", randf_range(GAME_LEFT + 40.0, GAME_RIGHT - 40.0))
	var spawn_y_fallback := origin.y + 70.0 if caster_is_top else origin.y - 30.0
	var spawn_y := _get_context_float(launch_context, "spawn_y", spawn_y_fallback)
	var summon_count := _get_summon_count_for_launch(launch_context)
	for index in range(summon_count):
		var center_offset := (float(index) - (float(summon_count) - 1.0) * 0.5) * 52.0
		var spawn_pos := Vector2(clampf(spawn_x + center_offset, GAME_LEFT + 20.0, GAME_RIGHT - 20.0), clampf(spawn_y, patrol_min, patrol_max))
		var direction_x := -1.0 if randf() < 0.5 else 1.0
		var cooldown := _get_context_float(launch_context, "arrow_cooldown", _get_random_arrow_cooldown())
		var archer := LingpetSkeletonArcherPayloadFactory.build_archer(
			_next_archer_id,
			spawn_pos,
			direction_x * ARCHER_SPEED,
			patrol_min,
			patrol_max,
			cooldown,
			_consume_golden_roll() < _get_golden_chance(),
			caster_is_top
		)
		_next_archer_id += 1
		_summon_count += 1
		_archers.append(archer)
		_spawn_summon_particles(spawn_pos)
	_enforce_archer_cap()
	return true


# Bound the live archer count after a fresh summon. The newest archers are kept (the
# player just cast them and deserves the feedback); the OLDEST over-cap archers retire
# via the same bone-fragment dissolve as a real death, but WITHOUT the kill SFX or the
# `_archer_death_count` increment -- a cap retire is a graceful fade-out, not a kill, so
# it must not pollute the death-count that the boss-returned-ball smoke asserts on.
func _enforce_archer_cap() -> void:
	while _archers.size() > MAX_CONCURRENT_ARCHERS:
		var retired: Dictionary = _archers.pop_front()
		_retire_archer_to_dust(retired)


func _retire_archer_to_dust(archer: Dictionary) -> void:
	var pos := _get_dict_vector2(archer, "pos", Vector2.ZERO)
	var fragments: Array[Dictionary] = []
	for i in range(12):
		fragments.append(LingpetSkeletonArcherPayloadFactory.build_bone_fragment(pos, i))
	_dying_archers.append({
		"pos": pos,
		"timer": 0.0,
		"fragments": fragments,
	})


func update(delta: float, owner: Object = null, registry: Object = null, launch_context: Dictionary = {}) -> void:
	if registry != null:
		_last_registry = registry
	if not launch_context.is_empty():
		_sync_level_values(launch_context)
	var safe_delta := maxf(0.0, delta)
	_update_particles(safe_delta)
	_update_dying_archers(safe_delta)
	_update_arrows(safe_delta, owner, registry)
	_update_archers(safe_delta, owner, registry)
	_active = not _archers.is_empty()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_renderer.draw(
		canvas,
		shake_offset,
		_particles,
		_dying_archers,
		_archers,
		_arrows,
		EMERGE_DURATION,
		DEATH_DURATION,
		_arrow_draw_time
	)


func has_visible_effects() -> bool:
	return _active or not _archers.is_empty() or not _dying_archers.is_empty() or not _arrows.is_empty() or not _particles.is_empty()


func is_active() -> bool:
	return has_visible_effects()


func get_archer_count_for_tests() -> int:
	return _archers.size()


func get_arrow_count_for_tests() -> int:
	return _arrows.size()


func get_arrow_hit_count_for_tests() -> int:
	return _arrow_hit_count


func get_archer_death_count_for_tests() -> int:
	return _archer_death_count


func set_golden_rolls_for_tests(values: Array) -> void:
	_golden_rolls_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_golden_rolls_for_tests.append(float(value))


func set_bonus_summon_rolls_for_tests(values: Array) -> void:
	_bonus_summon_rolls_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_bonus_summon_rolls_for_tests.append(float(value))


func set_normal_spread_degrees_for_tests(values: Array) -> void:
	_normal_spread_degrees_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_normal_spread_degrees_for_tests.append(float(value))


func get_snapshot() -> Dictionary:
	return {
		"skeleton_archer_active": _active,
		"skeleton_archer_active_skill_level": _active_skill_level,
		"skeleton_archer_archer_count": _archers.size(),
		"skeleton_archer_archer_positions": _get_archer_positions(),
		"skeleton_archer_has_golden": _has_golden_archer(),
		"skeleton_archer_arrow_count": _arrows.size(),
		"skeleton_archer_arrow_positions": _get_arrow_positions(),
		"skeleton_archer_dying_count": _dying_archers.size(),
		"skeleton_archer_particle_count": _particles.size(),
		"skeleton_archer_summon_count": _summon_count,
		"skeleton_archer_arrow_fire_count": _arrow_fire_count,
		"skeleton_archer_arrow_hit_count": _arrow_hit_count,
		"skeleton_archer_archer_death_count": _archer_death_count,
		"skeleton_archer_last_hit_pos": _last_hit_pos,
		"skeleton_archer_last_knockback_velocity": _last_knockback_velocity,
		"skeleton_archer_original_knockback_vel": ORIGINAL_KNOCKBACK_VEL,
		"skeleton_archer_godot_knockback_velocity": GODOT_KNOCKBACK_VELOCITY,
		"skeleton_archer_godot_knockback_frames": GODOT_KNOCKBACK_FRAMES,
		"skeleton_archer_golden_chance": _get_golden_chance(),
		"skeleton_archer_golden_chance_pct": _get_golden_chance() * 100.0,
		"skeleton_archer_bonus_summon_chance": _get_bonus_summon_chance(),
		"skeleton_archer_bonus_summon_chance_pct": _get_bonus_summon_chance() * 100.0,
		"skeleton_archer_arrow_cooldown_min": _arrow_cooldown_min,
		"skeleton_archer_arrow_cooldown_max": _arrow_cooldown_max,
		"skeleton_archer_arrow_draw_time": _arrow_draw_time,
		"skeleton_archer_emerge_duration": EMERGE_DURATION,
	}


func _update_archers(delta: float, owner: Object, registry: Object) -> void:
	if _archers.is_empty():
		return
	var boss_rect := _get_boss_rect(owner)
	var kept: Array[Dictionary] = []
	for archer in _archers:
		archer["spawn_time"] = float(archer.get("spawn_time", 0.0)) + delta
		archer["step_phase"] = float(archer.get("step_phase", 0.0)) + delta * 7.0
		archer["body_bob"] = sin(float(archer.get("step_phase", 0.0))) * 2.0
		var pos := _get_dict_vector2(archer, "pos", Vector2.ZERO)
		if float(archer.get("spawn_time", 0.0)) < EMERGE_DURATION:
			if randf() < minf(1.0, 0.45 * delta * 60.0):
				_particles.append(LingpetSkeletonArcherPayloadFactory.build_summon_particle(pos))
			kept.append(archer)
			continue
		if _ball_destroys_archer(archer, owner):
			_destroy_archer(archer, registry)
			continue
		if bool(archer.get("is_drawing", false)):
			archer["draw_timer"] = float(archer.get("draw_timer", 0.0)) + delta
			if float(archer.get("draw_timer", 0.0)) >= _arrow_draw_time:
				_fire_arrows(archer, boss_rect, registry)
				archer["is_drawing"] = false
				archer["draw_timer"] = 0.0
				archer["arrow_cooldown"] = _get_random_arrow_cooldown()
		else:
			archer["arrow_cooldown"] = float(archer.get("arrow_cooldown", 0.0)) - delta
			if float(archer.get("arrow_cooldown", 0.0)) <= 0.0:
				archer["is_drawing"] = true
				archer["draw_timer"] = 0.0
				archer["draw_target"] = boss_rect.get_center()
		_patrol_archer(archer, delta)
		kept.append(archer)
	_archers = kept
	while _particles.size() > PARTICLE_MAX:
		_particles.remove_at(0)


func _patrol_archer(archer: Dictionary, delta: float) -> void:
	var pos := _get_dict_vector2(archer, "pos", Vector2.ZERO)
	var velocity_x := float(archer.get("velocity_x", 0.0))
	pos.x += velocity_x * delta
	if pos.x <= GAME_LEFT + 20.0:
		pos.x = GAME_LEFT + 20.0
		velocity_x = absf(velocity_x)
	elif pos.x >= GAME_RIGHT - 20.0:
		pos.x = GAME_RIGHT - 20.0
		velocity_x = -absf(velocity_x)
	if randf() < 0.005 * delta * 60.0:
		velocity_x *= -1.0
	pos.y = clampf(pos.y, float(archer.get("patrol_y_min", PLAYER_PATROL_Y_MIN)), float(archer.get("patrol_y_max", PLAYER_PATROL_Y_MAX)))
	archer["pos"] = pos
	archer["velocity_x"] = velocity_x


func _update_arrows(delta: float, owner: Object, registry: Object) -> void:
	if _arrows.is_empty():
		return
	var boss_rect := _get_boss_rect(owner)
	var kept: Array[Dictionary] = []
	for arrow in _arrows:
		var age := float(arrow.get("age", 0.0)) + delta
		var pos := _get_dict_vector2(arrow, "pos", Vector2.ZERO)
		var vel := _get_dict_vector2(arrow, "vel", Vector2.ZERO)
		pos += vel * delta
		var trail: Array = arrow.get("trail", []) as Array
		trail.append(pos)
		while trail.size() > 5:
			trail.pop_front()
		arrow["age"] = age
		arrow["pos"] = pos
		arrow["trail"] = trail
		if _arrow_hits_boss(pos, boss_rect):
			_apply_arrow_hit(arrow, owner, registry, boss_rect)
			continue
		if age > ARROW_MAX_AGE or pos.x < -32.0 or pos.x > FIELD_WIDTH + 32.0 or pos.y < -32.0 or pos.y > FIELD_HEIGHT + 32.0:
			continue
		kept.append(arrow)
	_arrows = kept


func _update_dying_archers(delta: float) -> void:
	if _dying_archers.is_empty():
		return
	var kept: Array[Dictionary] = []
	for dying in _dying_archers:
		var timer := float(dying.get("timer", 0.0)) + delta
		var fragments: Array = dying.get("fragments", []) as Array
		for fragment in fragments:
			var pos := _get_dict_vector2(fragment, "pos", Vector2.ZERO)
			var vel := _get_dict_vector2(fragment, "vel", Vector2.ZERO)
			pos += vel * delta
			vel.y += 360.0 * delta
			fragment["pos"] = pos
			fragment["vel"] = vel
			fragment["rotation"] = float(fragment.get("rotation", 0.0)) + float(fragment.get("rotation_speed", 0.0)) * delta
		dying["timer"] = timer
		if timer <= DEATH_DURATION:
			kept.append(dying)
	_dying_archers = kept


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var kept: Array[Dictionary] = []
	for particle in _particles:
		var age := float(particle.get("age", 0.0)) + delta
		var life := float(particle.get("life", 0.0))
		if age >= life:
			continue
		var pos := _get_dict_vector2(particle, "pos", Vector2.ZERO)
		var vel := _get_dict_vector2(particle, "vel", Vector2.ZERO)
		pos += vel * delta
		vel.y += 120.0 * delta
		particle["age"] = age
		particle["pos"] = pos
		particle["vel"] = vel
		kept.append(particle)
	_particles = kept


func _fire_arrows(archer: Dictionary, boss_rect: Rect2, registry: Object) -> void:
	var archer_pos := _get_dict_vector2(archer, "pos", Vector2.ZERO)
	var start_pos := archer_pos + Vector2(0.0, -ARCHER_HEIGHT * 0.46)
	var target_pos := boss_rect.get_center()
	var base_direction := (target_pos - start_pos).normalized()
	if base_direction.length_squared() <= 0.0001:
		base_direction = Vector2.UP
	var spreads: Array[float] = []
	if bool(archer.get("is_golden", false)):
		spreads = [0.0, GOLDEN_SPREAD_DEGREES, -GOLDEN_SPREAD_DEGREES]
	else:
		spreads = [_consume_normal_spread_degrees()]
	for spread in spreads:
		var direction := base_direction.rotated(deg_to_rad(float(spread)))
		_arrows.append(LingpetSkeletonArcherPayloadFactory.build_arrow(
			start_pos,
			direction,
			ARROW_SPEED,
			int(archer.get("id", 0)),
			bool(archer.get("is_golden", false))
		))
	_arrow_fire_count += spreads.size()
	# Original arrow-fire cue is arrow.wav (vol 0.7); the dedicated method is preferred,
	# with the legacy borrowed cues kept as fallbacks for older audio registries.
	_play_audio(registry, ["play_lingpet_skeleton_archer_arrow_fire", "play_shrapnel_armor_fire", "play_ragnarok_shot", "play_active_item"])


func _apply_arrow_hit(arrow: Dictionary, owner: Object, registry: Object, boss_rect: Rect2) -> void:
	var pos := _get_dict_vector2(arrow, "pos", Vector2.ZERO)
	var vel := _get_dict_vector2(arrow, "vel", Vector2.UP)
	var direction_x := signf(vel.x)
	if absf(direction_x) <= 0.001:
		direction_x = -1.0 if pos.x < boss_rect.get_center().x else 1.0
	var knockback_velocity := direction_x * GODOT_KNOCKBACK_VELOCITY
	_last_knockback_velocity = knockback_velocity
	_last_hit_pos = pos
	_arrow_hit_count += 1
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"boss",
			"stun",
			GODOT_KNOCKBACK_FRAMES,
			{
				"knockback_vel": knockback_velocity,
				"knockback_frames": GODOT_KNOCKBACK_FRAMES,
				"knockback_decay_per_frame": GODOT_KNOCKBACK_DECAY,
				"source": STATUS_SOURCE,
			},
			STATUS_SOURCE
		)
	else:
		var ai_state := _get_registry_instance(registry, "boss_ai_state")
		if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
			ai_state.start_paddle_hit_knockback(knockback_velocity, GODOT_KNOCKBACK_FRAMES, GODOT_KNOCKBACK_DECAY, true)
		elif owner != null:
			owner.set("boss_vel", knockback_velocity)
	_spawn_hit_particles(pos, vel)
	# Original arrow-hit cue is bullethit.wav (Commando pistol hit, vol 0.7).
	_play_audio(registry, ["play_lingpet_skeleton_archer_arrow_hit", "play_shrapnel_armor_hit", "play_boomerang_hit", "play_active_item"])


func _ball_destroys_archer(archer: Dictionary, owner: Object) -> bool:
	if owner == null or not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return false
	var ball_vel := BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if bool(archer.get("caster_is_top", false)):
		if ball_vel.y >= 0.0:
			return false
	else:
		if ball_vel.y <= 0.0:
			return false
	var archer_pos := _get_dict_vector2(archer, "pos", Vector2.ZERO)
	var ball_pos := BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius := _get_ball_radius(owner)
	var radius := ARCHER_WIDTH * 0.5 + ARCHER_HIT_RADIUS_PADDING + ball_radius
	return archer_pos.distance_squared_to(ball_pos) <= radius * radius


func _destroy_archer(archer: Dictionary, registry: Object) -> void:
	var pos := _get_dict_vector2(archer, "pos", Vector2.ZERO)
	var fragments: Array[Dictionary] = []
	for i in range(12):
		fragments.append(LingpetSkeletonArcherPayloadFactory.build_bone_fragment(pos, i))
	_dying_archers.append({
		"pos": pos,
		"timer": 0.0,
		"fragments": fragments,
	})
	_archer_death_count += 1
	# Original archer-death cue is skulldead.wav (vol 0.3).
	_play_audio(registry, ["play_lingpet_skeleton_archer_death", "play_boomerang_break", "play_lingpet_ghost_summon_out", "play_active_item"])


func _spawn_summon_particles(pos: Vector2) -> void:
	for _i in range(22):
		_particles.append(LingpetSkeletonArcherPayloadFactory.build_summon_particle(pos))
	while _particles.size() > PARTICLE_MAX:
		_particles.remove_at(0)


func _spawn_hit_particles(pos: Vector2, velocity: Vector2) -> void:
	for i in range(12):
		_particles.append(LingpetSkeletonArcherPayloadFactory.build_hit_particle(pos, velocity, i))
	while _particles.size() > PARTICLE_MAX:
		_particles.remove_at(0)


func _arrow_hits_boss(pos: Vector2, boss_rect: Rect2) -> bool:
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return false
	var boss_center := boss_rect.get_center()
	var hit_radius := boss_rect.size.x * 0.5 + 8.0
	return pos.distance_squared_to(boss_center) <= hit_radius * hit_radius


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos := BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - BOSS_PADDLE_WIDTH * 0.5, 25.0))
	var boss_width := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", BOSS_PADDLE_WIDTH)))
	var boss_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", BOSS_HITBOX_HEIGHT)))
	return Rect2(boss_pos, Vector2(boss_width, boss_height))


func _get_ball_radius(owner: Object) -> float:
	var ball_size: Variant = BattleSceneOwnerReader.get_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)
	if ball_size is int or ball_size is float:
		return maxf(1.0, float(ball_size) * 0.5)
	return BALL_RADIUS_FALLBACK


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", _active_skill_level))), 1, 5)


func _sync_level_values(launch_context: Dictionary) -> void:
	_active_skill_level = _get_active_skill_level(launch_context)
	_arrow_draw_time = _get_positive_context_float(launch_context, "arrow_draw_time", _get_level_array_value(ARROW_DRAW_TIME_BY_LEVEL, 1.0))
	_arrow_cooldown_min = _get_positive_context_float(launch_context, "arrow_cooldown_min", _get_level_array_value(ARROW_COOLDOWN_MIN_BY_LEVEL, 1.0))
	_arrow_cooldown_max = _get_positive_context_float(launch_context, "arrow_cooldown_max", _get_level_array_value(ARROW_COOLDOWN_MAX_BY_LEVEL, 3.0))
	if _arrow_cooldown_max < _arrow_cooldown_min:
		_arrow_cooldown_max = _arrow_cooldown_min
	_golden_chance = _get_context_chance(launch_context, "golden_chance_pct", _get_level_array_value(GOLDEN_CHANCE_BY_LEVEL, 0.0))
	_bonus_summon_chance = _get_context_chance(launch_context, "bonus_summon_chance_pct", _get_level_array_value(BONUS_SUMMON_CHANCE_BY_LEVEL, 0.0))


func _get_level_array_value(values: Array, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(_active_skill_level - 1, 0, values.size() - 1)
	return float(values[index])


func _get_context_chance(context: Dictionary, pct_key: String, fallback: float) -> float:
	if not context.has(pct_key):
		return clampf(fallback, 0.0, 1.0)
	var value: Variant = context.get(pct_key, 0.0)
	if value is int or value is float:
		var pct := float(value)
		if pct < 0.0:
			return clampf(fallback, 0.0, 1.0)
		return clampf(pct / 100.0, 0.0, 1.0)
	return clampf(fallback, 0.0, 1.0)


func _get_golden_chance() -> float:
	return clampf(_golden_chance, 0.0, 1.0)


func _get_bonus_summon_chance() -> float:
	return clampf(_bonus_summon_chance, 0.0, 1.0)


func _get_random_arrow_cooldown() -> float:
	return randf_range(_arrow_cooldown_min, _arrow_cooldown_max)


func _get_summon_count_for_launch(launch_context: Dictionary) -> int:
	var forced_count := _get_context_float(launch_context, "summon_count", -1.0)
	if forced_count > 0.0:
		return clampi(int(round(forced_count)), 1, 3)
	var chance := _get_bonus_summon_chance()
	if chance <= 0.0:
		return 1
	return 2 if _consume_bonus_summon_roll() < chance else 1


func _consume_golden_roll() -> float:
	if not _golden_rolls_for_tests.is_empty():
		return clampf(float(_golden_rolls_for_tests.pop_front()), 0.0, 1.0)
	return randf()


func _consume_bonus_summon_roll() -> float:
	if not _bonus_summon_rolls_for_tests.is_empty():
		return clampf(float(_bonus_summon_rolls_for_tests.pop_front()), 0.0, 1.0)
	return randf()


func _consume_normal_spread_degrees() -> float:
	if not _normal_spread_degrees_for_tests.is_empty():
		return float(_normal_spread_degrees_for_tests.pop_front())
	return randf_range(-NORMAL_SPREAD_DEGREES, NORMAL_SPREAD_DEGREES)


func _get_context_float(context: Dictionary, key: String, fallback: float) -> float:
	if not context.has(key):
		return fallback
	var value: Variant = context.get(key)
	if value is int or value is float:
		return float(value)
	return fallback


func _get_positive_context_float(context: Dictionary, key: String, fallback: float) -> float:
	var value := _get_context_float(context, key, fallback)
	return value if value > 0.0 else fallback


func _get_archer_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for archer in _archers:
		result.append(_get_dict_vector2(archer, "pos", Vector2.ZERO))
	return result


func _get_arrow_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for arrow in _arrows:
		result.append(_get_dict_vector2(arrow, "pos", Vector2.ZERO))
	return result


func _has_golden_archer() -> bool:
	for archer in _archers:
		if bool(archer.get("is_golden", false)):
			return true
	return false


func _play_audio(registry: Object, methods: Array[String]) -> void:
	var resolved_registry := registry if registry != null else _last_registry
	var audio := _get_registry_instance(resolved_registry, "game_audio")
	if audio == null:
		return
	for method_name in methods:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null


func _get_dict_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
