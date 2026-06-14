extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const FIELD_HALF_Y := FIELD_HEIGHT * 0.5
const DEFAULT_BALL_SIZE := 28.6
const DEFAULT_PLAYER_PADDLE_WIDTH := 155.0
const DEFAULT_PLAYER_PADDLE_HEIGHT := 50.0
const PLAYER_COLLISION_COOLDOWN_FRAMES := 6.0
const MIN_REFLECT_SPEED := 1.0
const FIRST_STRIKE_BASE_ANGLE := -PI * 0.5
const FIRST_STRIKE_JITTER_RADIANS := PI * 0.25
const MIN_UPWARD_VY := -1.0
const DEFAULT_REFIRE_CHANCE_PCT := 50.0
const REFIRE_DELAY_MIN := 0.5
const REFIRE_DELAY_MAX := 1.0
const LIGHTNING_SECONDS := 0.20
const EXPLOSION_SECONDS := 0.38
const SPARK_SECONDS := 0.55
const SPARK_COUNT := 22
const PARTICLE_MAX := 72
const SCREEN_FLASH_ALPHA := 0.16

# Original PingFighter SolarBolt palette ported faithfully (gold main bolt =
# 태양신; lavender branch cores + blue-white explosion arcs are the original's
# accents). Glow alpha is bumped vs the original's BLEND_ADD surface because
# Godot immediate draw_polyline has no per-call additive blend.
const BOLT_GLOW_COLOR := Color(1.0, 0.706, 0.118, 0.34)   # GLOW_WIDE (255,180,30)
const BOLT_CORE_COLOR := Color(1.0, 0.941, 0.549, 1.0)    # CORE_OUTER (255,240,140)
const BOLT_WHITE_COLOR := Color(1.0, 1.0, 0.941, 1.0)     # CORE_INNER (255,255,240)
const BRANCH_CORE_COLOR := Color(0.863, 0.863, 1.0, 1.0)  # BRANCH_CORE (220,220,255)
const BRANCH_GLOW_COLOR := Color(0.784, 0.706, 1.0, 0.28) # BRANCH_GLOW (200,180,255)
const FORK_GLOW_COLOR := Color(1.0, 1.0, 0.902, 0.63)     # fork point (255,255,230)
const FLASH_COLOR := Color(1.0, 0.90, 0.39, 1.0)          # ScreenEffect flash (255,230,100)
const EXPL_FLASH_COLOR := Color(1.0, 1.0, 0.941, 1.0)     # EXPLOSION_FLASH (255,255,240)
const EXPL_CORE_COLOR := Color(1.0, 0.941, 0.588, 1.0)    # EXPLOSION_CORE (255,240,150)
const EXPL_INNER_COLOR := Color(1.0, 1.0, 0.863, 1.0)     # EXPLOSION_INNER (255,255,220)
const EXPL_RING_COLOR := Color(1.0, 0.784, 0.314, 1.0)    # EXPLOSION_RING (255,200,80)
const EXPL_ARC_COLORS: Array[Color] = [                   # EXPLOSION_ARC + accents
	Color(0.706, 0.824, 1.0), Color(1.0, 0.941, 0.706), Color(0.863, 0.902, 1.0),
]
const SPARK_GRAVITY := 288.0  # original vy += 0.08 px/frame^2 -> 0.08*60*60 px/sec^2
const SPARK_TYPES: Array[String] = ["streak", "dot", "flash"]
const SPARK_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 0.784), Color(1.0, 0.902, 0.392),
	Color(0.784, 0.863, 1.0), Color(1.0, 0.941, 0.627),
]

var _scheduled_refires := 0
var _refire_timer := 0.0
var _speed_locked := 0.0
var _active_skill_level := 1
var _refire_chance_pct := DEFAULT_REFIRE_CHANCE_PCT
var _stored_origin := Vector2.ZERO
var _registry: Object = null
var _effects: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _elapsed := 0.0
var _strike_count := 0
var _first_strike_count := 0
var _refire_strike_count := 0
var _last_result := "idle"
var _last_ball_speed_pre := 0.0
var _last_ball_speed_after := 0.0
var _last_reflect_dir := Vector2(0.0, -1.0)
var _last_ball_pos := Vector2.ZERO
var _last_target_center := Vector2.ZERO
var _last_player_blockable := false
var _last_can_arm_reason := "idle"
var _force_roll := -1.0
var _force_rolls: Array[float] = []
var _jitter_radians_for_tests: Array[float] = []
var _force_refire_delays: Array[float] = []


func reset() -> void:
	_scheduled_refires = 0
	_refire_timer = 0.0
	_speed_locked = 0.0
	_active_skill_level = 1
	_refire_chance_pct = DEFAULT_REFIRE_CHANCE_PCT
	_stored_origin = Vector2.ZERO
	_effects.clear()
	_particles.clear()
	_elapsed = 0.0
	_last_result = "idle"
	_last_ball_speed_pre = 0.0
	_last_ball_speed_after = 0.0
	_last_reflect_dir = Vector2(0.0, -1.0)
	_last_ball_pos = Vector2.ZERO
	_last_target_center = Vector2.ZERO
	_last_player_blockable = false
	_last_can_arm_reason = "idle"


func prewarm() -> void:
	pass


func can_arm(params: Dictionary) -> bool:
	if not bool(params.get("ball_active", false)):
		_last_can_arm_reason = "ball_inactive"
		return false
	if not bool(params.get("companion_visible", false)):
		_last_can_arm_reason = "companion_hidden"
		return false
	var owner: Object = params.get("owner", null) as Object
	if owner == null:
		_last_can_arm_reason = "missing_owner"
		return false
	if bool(BattleSceneOwnerReader.get_value(owner, "skip_ball_motion_step", false)):
		_last_can_arm_reason = "motion_skip"
		return false
	var companion_pos: Vector2 = _as_vector2(params.get("companion_pos", Vector2.ZERO), Vector2.ZERO)
	if companion_pos == Vector2.ZERO:
		_last_can_arm_reason = "missing_companion_pos"
		return false
	var ball_pos: Vector2 = _get_context_or_owner_vector2(params, owner, "ball_pos", Vector2.ZERO)
	var ball_vel: Vector2 = _get_context_or_owner_vector2(params, owner, "ball_vel", Vector2.ZERO)
	var ball_size := maxf(1.0, float(_get_context_or_owner_value(params, owner, "ball_size", DEFAULT_BALL_SIZE)))
	var ball_radius := ball_size * 0.5
	var ball_center := ball_pos + Vector2(ball_radius, ball_radius)
	if ball_vel.y <= 0.0:
		_last_can_arm_reason = "not_descending"
		return false
	if ball_center.y < FIELD_HALF_Y:
		_last_can_arm_reason = "upper_half"
		return false
	if not _ball_is_above_player(owner, ball_center, ball_radius):
		_last_can_arm_reason = "past_player"
		return false
	var future_x := _predict_player_lane_x(owner, ball_center, ball_vel, ball_radius)
	_last_player_blockable = _player_can_block(owner, future_x, ball_radius)
	if _last_player_blockable:
		_last_can_arm_reason = "player_can_block"
		return false
	_last_can_arm_reason = "ready"
	return true


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	var preserved_force_roll := _force_roll
	var preserved_force_rolls := _force_rolls.duplicate()
	var preserved_jitter := _jitter_radians_for_tests.duplicate()
	reset()
	_force_roll = preserved_force_roll
	_force_rolls = preserved_force_rolls
	_jitter_radians_for_tests = preserved_jitter
	_stored_origin = _get_origin_from_context(launch_context, origin)
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_registry = ctx_registry as Object
	_active_skill_level = clampi(int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))), 1, 5)
	_refire_chance_pct = clampf(float(launch_context.get("refire_chance_pct", DEFAULT_REFIRE_CHANCE_PCT)), 0.0, 100.0)
	if not _strike_ball(owner, launch_context, false):
		reset()
		_force_roll = preserved_force_roll
		_force_rolls = preserved_force_rolls
		_jitter_radians_for_tests = preserved_jitter
		return false
	_schedule_refires()
	return true


func update(delta: float, owner: Object, registry: Object = null, launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	_stored_origin = _get_origin_from_context(launch_context, _stored_origin)
	var safe_delta := maxf(0.0, delta)
	_elapsed += safe_delta
	_update_refires(safe_delta, owner, launch_context)
	_update_effects(safe_delta)
	_update_particles(safe_delta)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_draw_screen_flash(canvas)
	for effect in _effects:
		_draw_effect(canvas, effect, shake_offset)
	_draw_particles(canvas, shake_offset)


func has_visible_effects() -> bool:
	return not _effects.is_empty() or not _particles.is_empty()


func is_active() -> bool:
	return _scheduled_refires > 0 or has_visible_effects()


func is_projectile_active() -> bool:
	return is_active()


func get_snapshot() -> Dictionary:
	return {
		"solar_bolt_active": is_active(),
		"solar_bolt_vfx_active": has_visible_effects(),
		"solar_bolt_refire_pending": _scheduled_refires > 0,
		"solar_bolt_refire_timer": _refire_timer,
		"solar_bolt_scheduled_refires": _scheduled_refires,
		"solar_bolt_strike_count": _strike_count,
		"solar_bolt_first_strike_count": _first_strike_count,
		"solar_bolt_refire_strike_count": _refire_strike_count,
		"solar_bolt_speed_locked": _speed_locked,
		"solar_bolt_last_result": _last_result,
		"solar_bolt_last_ball_speed_pre": _last_ball_speed_pre,
		"solar_bolt_last_ball_speed_after": _last_ball_speed_after,
		"solar_bolt_last_reflect_dir": _last_reflect_dir,
		"solar_bolt_last_ball_pos": _last_ball_pos,
		"solar_bolt_last_target_center": _last_target_center,
		"solar_bolt_last_player_blockable": _last_player_blockable,
		"solar_bolt_last_can_arm_reason": _last_can_arm_reason,
		"solar_bolt_particle_count": _particles.size(),
		"solar_bolt_effect_count": _effects.size(),
	}


func get_strike_count_for_tests() -> int:
	return _strike_count


func get_scheduled_refires_for_tests() -> int:
	return _scheduled_refires


func set_force_roll_for_tests(value: float) -> void:
	_force_roll = clampf(value, 0.0, 1.0)
	_force_rolls.clear()


func set_force_rolls_for_tests(values: Array) -> void:
	_force_roll = -1.0
	_force_rolls.clear()
	for value in values:
		if value is int or value is float:
			_force_rolls.append(clampf(float(value), 0.0, 1.0))


func set_jitter_degrees_for_tests(values: Array) -> void:
	_jitter_radians_for_tests.clear()
	for value in values:
		if value is int or value is float:
			_jitter_radians_for_tests.append(deg_to_rad(clampf(float(value), -45.0, 45.0)))


func set_force_refire_delays_for_tests(values: Array) -> void:
	_force_refire_delays.clear()
	for value in values:
		if value is int or value is float:
			_force_refire_delays.append(maxf(0.0, float(value)))


# Re-fire spacing is rolled ONCE per scheduled follow-up (at schedule / after a
# fire) — NOT per frame — so it cannot compound. Each gap is a fresh 0.5..1.0s.
func _roll_refire_delay() -> float:
	if not _force_refire_delays.is_empty():
		return maxf(0.0, _force_refire_delays.pop_front())
	return randf_range(REFIRE_DELAY_MIN, REFIRE_DELAY_MAX)


func _strike_ball(owner: Object, context: Dictionary, retarget_boss: bool) -> bool:
	if owner == null:
		_last_result = "missing_owner"
		return false
	if not bool(_get_context_or_owner_value(context, owner, "ball_active", BattleSceneOwnerReader.get_value(owner, "ball_active", false))):
		_last_result = "ball_inactive"
		return false
	var ball_pos: Vector2 = _get_context_or_owner_vector2(context, owner, "ball_pos", BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = _get_context_or_owner_vector2(context, owner, "ball_vel", BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO))
	var ball_size := maxf(1.0, float(_get_context_or_owner_value(context, owner, "ball_size", DEFAULT_BALL_SIZE)))
	var ball_center := ball_pos + Vector2(ball_size * 0.5, ball_size * 0.5)
	if not retarget_boss:
		_speed_locked = maxf(MIN_REFLECT_SPEED, ball_vel.length())
		_last_ball_speed_pre = ball_vel.length()
	elif _speed_locked <= 0.0:
		_speed_locked = maxf(MIN_REFLECT_SPEED, ball_vel.length())
	var dir := Vector2(0.0, -1.0)
	var target_center := Vector2(ball_center.x, 0.0)
	if retarget_boss:
		target_center = _get_boss_rect(owner).get_center()
		var to_boss := target_center - ball_center
		dir = to_boss.normalized() if to_boss.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	else:
		var angle := FIRST_STRIKE_BASE_ANGLE + _consume_jitter_radians()
		dir = Vector2(cos(angle), sin(angle))
		if dir.y * _speed_locked >= MIN_UPWARD_VY:
			var adjusted_y := MIN_UPWARD_VY / maxf(MIN_REFLECT_SPEED, _speed_locked)
			var x_sign := signf(dir.x)
			if is_zero_approx(x_sign):
				dir = Vector2(0.0, -1.0)
			else:
				dir = Vector2(x_sign * sqrt(maxf(0.0, 1.0 - adjusted_y * adjusted_y)), adjusted_y).normalized()
	var next_vel := dir * _speed_locked
	owner.set("ball_vel", next_vel)
	owner.set("player_collision_cooldown", maxf(float(BattleSceneOwnerReader.get_value(owner, "player_collision_cooldown", 0.0)), PLAYER_COLLISION_COOLDOWN_FRAMES))
	_register_ball_intensity_contact(_registry)
	_spawn_strike_vfx(_stored_origin, ball_center, target_center)
	_apply_feedback_shake(_registry)
	_strike_count += 1
	if retarget_boss:
		_refire_strike_count += 1
		_play_solar_bolt_feedback(_registry)
	else:
		_first_strike_count += 1
	_last_result = "retarget" if retarget_boss else "reflected"
	_last_ball_speed_after = next_vel.length()
	_last_reflect_dir = dir
	_last_ball_pos = ball_center
	_last_target_center = target_center
	return true


func _schedule_refires() -> void:
	var max_extra := 0
	if _active_skill_level >= 5:
		max_extra = 2
	elif _active_skill_level >= 3:
		max_extra = 1
	_scheduled_refires = 0
	var chance := _refire_chance_pct / 100.0
	for _index in range(max_extra):
		if _roll_unit() < chance:
			_scheduled_refires += 1
		else:
			break
	_refire_timer = _roll_refire_delay() if _scheduled_refires > 0 else 0.0


func _update_refires(delta: float, owner: Object, launch_context: Dictionary) -> void:
	if _scheduled_refires <= 0:
		return
	_refire_timer -= delta
	if _refire_timer > 0.0:
		return
	var timer_carry := _refire_timer
	if not _strike_ball(owner, launch_context, true):
		_scheduled_refires = 0
		_refire_timer = 0.0
		return
	_scheduled_refires -= 1
	if _scheduled_refires > 0:
		_refire_timer = _roll_refire_delay() + timer_carry
	else:
		_refire_timer = 0.0


func _spawn_strike_vfx(start: Vector2, end: Vector2, target: Vector2) -> void:
	var safe_start := start if start != Vector2.ZERO else end + Vector2(0.0, 80.0)
	var seed_value := safe_start.x * 0.37 + safe_start.y * 0.73 + end.x * 0.19 + end.y * 0.41 + float(_strike_count) * 11.0
	var bolt := _gen_lightning(safe_start, end)
	_effects.append({
		"start": safe_start,
		"end": end,
		"target": target,
		"lightning": LIGHTNING_SECONDS,
		"explosion": EXPLOSION_SECONDS,
		"seed": seed_value,
		"main": bolt["main"],
		"branches": bolt["branches"],
	})
	_spawn_sparks(end, seed_value)


func _update_effects(delta: float) -> void:
	if _effects.is_empty():
		return
	var write_index := 0
	for effect in _effects:
		var lightning := maxf(0.0, float(effect.get("lightning", 0.0)) - delta)
		var explosion := maxf(0.0, float(effect.get("explosion", 0.0)) - delta)
		effect["lightning"] = lightning
		effect["explosion"] = explosion
		if lightning <= 0.0 and explosion <= 0.0:
			continue
		_effects[write_index] = effect
		write_index += 1
	if write_index < _effects.size():
		_effects.resize(write_index)


func _spawn_sparks(center: Vector2, seed_value: float) -> void:
	for index in range(SPARK_COUNT):
		if _particles.size() >= PARTICLE_MAX:
			_particles.pop_front()
		var angle := TAU * _seeded_unit(seed_value, float(index))
		var spark_type: String = SPARK_TYPES[index % SPARK_TYPES.size()]
		var is_flash := spark_type == "flash"
		# Original speeds are 2.5..9 px/frame; *60 -> px/sec for delta motion.
		var speed := lerpf(2.5, 9.0, _seeded_unit(seed_value, float(index) + 13.0)) * 60.0
		var size_unit := _seeded_unit(seed_value, float(index) + 7.0)
		var size := lerpf(4.0, 7.0, size_unit) if is_flash else lerpf(1.5, 4.0, size_unit)
		_particles.append({
			"pos": center + Vector2(cos(angle), sin(angle)) * lerpf(2.0, 10.0, _seeded_unit(seed_value, float(index) + 3.0)),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": lerpf(0.25, 0.55, _seeded_unit(seed_value, float(index) + 9.0)),
			"max_life": SPARK_SECONDS,
			"size": size,
			"type": spark_type,
			"color": SPARK_COLORS[index % SPARK_COLORS.size()],
		})


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var write_index := 0
	for particle in _particles:
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = particle.get("pos", Vector2.ZERO)
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		pos += vel * delta
		vel.y += SPARK_GRAVITY * delta  # original gravity vy += 0.08 px/frame^2
		particle["life"] = life
		particle["pos"] = pos
		particle["vel"] = vel
		_particles[write_index] = particle
		write_index += 1
	if write_index < _particles.size():
		_particles.resize(write_index)


func _draw_screen_flash(canvas: CanvasItem) -> void:
	var alpha := 0.0
	for effect in _effects:
		alpha = maxf(alpha, clampf(float(effect.get("lightning", 0.0)) / LIGHTNING_SECONDS, 0.0, 1.0) * SCREEN_FLASH_ALPHA)
	if alpha > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, alpha), true)


func _draw_effect(canvas: CanvasItem, effect: Dictionary, shake_offset: Vector2) -> void:
	var end: Vector2 = effect.get("end", Vector2.ZERO)
	var lightning_left := float(effect.get("lightning", 0.0))
	var explosion_left := float(effect.get("explosion", 0.0))
	# Original SolarBolt: a fixed procedural path generated once at strike time,
	# rendered as a 4-layer bolt + branches, flickering on/off (85%) over its life.
	if lightning_left > 0.0 and randf() < 0.85:
		var fade := minf(1.0, lightning_left / 0.06)
		var main: PackedVector2Array = effect.get("main", PackedVector2Array())
		var branches: Array = effect.get("branches", [])
		if main.size() >= 2:
			var main_pts := _shift_points(main, shake_offset)
			# Layer 1 — wide soft glow (alpha-emulated additive).
			canvas.draw_polyline(main_pts, Color(BOLT_GLOW_COLOR.r, BOLT_GLOW_COLOR.g, BOLT_GLOW_COLOR.b, BOLT_GLOW_COLOR.a * fade), 6.0, true)
			for branch in branches:
				var bg: PackedVector2Array = branch
				if bg.size() >= 2:
					canvas.draw_polyline(_shift_points(bg, shake_offset), Color(BRANCH_GLOW_COLOR.r, BRANCH_GLOW_COLOR.g, BRANCH_GLOW_COLOR.b, BRANCH_GLOW_COLOR.a * fade), 4.0, true)
			# Layer 2 — cores: main gold, branches lavender.
			canvas.draw_polyline(main_pts, Color(BOLT_CORE_COLOR.r, BOLT_CORE_COLOR.g, BOLT_CORE_COLOR.b, fade), 2.0, true)
			for branch in branches:
				var bc: PackedVector2Array = branch
				if bc.size() >= 2:
					canvas.draw_polyline(_shift_points(bc, shake_offset), Color(BRANCH_CORE_COLOR.r, BRANCH_CORE_COLOR.g, BRANCH_CORE_COLOR.b, fade), 1.0, true)
			# Layer 3 — inner white core (main only).
			canvas.draw_polyline(main_pts, Color(BOLT_WHITE_COLOR.r, BOLT_WHITE_COLOR.g, BOLT_WHITE_COLOR.b, fade), 1.0, true)
			# Branch fork glow points.
			for branch in branches:
				var bf: PackedVector2Array = branch
				if bf.size() >= 1:
					canvas.draw_circle(bf[0] + shake_offset, 2.5, Color(FORK_GLOW_COLOR.r, FORK_GLOW_COLOR.g, FORK_GLOW_COLOR.b, FORK_GLOW_COLOR.a * fade))
	if explosion_left > 0.0:
		_draw_explosion(canvas, end + shake_offset, explosion_left, float(effect.get("seed", 0.0)))


func _draw_explosion(canvas: CanvasItem, center: Vector2, explosion_left: float, seed_value: float) -> void:
	var progress := clampf(1.0 - explosion_left / EXPLOSION_SECONDS, 0.0, 1.0)  # 0 -> 1
	var life_ratio := 1.0 - progress
	# Central flash (first 30%).
	if progress < 0.3:
		var flash_a := 1.0 - progress / 0.3
		canvas.draw_circle(center, 12.0 + progress * 30.0, Color(EXPL_FLASH_COLOR.r, EXPL_FLASH_COLOR.g, EXPL_FLASH_COLOR.b, 0.85 * flash_a))
	# Core glow.
	var core_r := 6.0 + progress * 40.0
	canvas.draw_circle(center, core_r * 0.6, Color(EXPL_CORE_COLOR.r, EXPL_CORE_COLOR.g, EXPL_CORE_COLOR.b, 0.78 * life_ratio))
	canvas.draw_circle(center, core_r * 0.3, Color(EXPL_INNER_COLOR.r, EXPL_INNER_COLOR.g, EXPL_INNER_COLOR.b, 0.5 * life_ratio))
	# 3 staggered shockwave rings (gold).
	for ri in range(3):
		var rd := float(ri) * 0.1
		var rp := (progress - rd) / maxf(0.01, 1.0 - rd)
		if rp <= 0.0 or rp > 1.0:
			continue
		var rr := EXPLOSION_SECONDS * 60.0 * rp * float(ri + 1) * 0.25
		var ra := (0.63 - float(ri) * 0.16) * (1.0 - rp)
		if ra <= 0.0 or rr <= 4.0:
			continue
		canvas.draw_arc(center, rr, 0.0, TAU, 48, Color(EXPL_RING_COLOR.r, EXPL_RING_COLOR.g, EXPL_RING_COLOR.b, ra), maxf(1.0, 3.0 - float(ri)), true)
	# Radial lightning arcs (blue-white) — first 70%.
	if progress < 0.7:
		var arc_count := 5 + int(progress * 8.0)
		var flick := floorf(_elapsed * 30.0)
		for i in range(arc_count):
			var a := (float(i) / float(arc_count)) * TAU + (_seeded_unit(seed_value + float(i), flick) - 0.5) * 0.4
			var inner_r := 4.0 + progress * 15.0
			var outer_r := inner_r + lerpf(15.0, 35.0, _seeded_unit(seed_value + float(i) + 5.0, flick)) * (1.0 + progress)
			var dir := Vector2(cos(a), sin(a))
			var arc_s := center + dir * inner_r
			var arc_e := center + dir * outer_r
			var arc_mid := (arc_s + arc_e) * 0.5 + Vector2((_seeded_unit(seed_value + float(i), flick + 3.0) - 0.5) * 12.0, (_seeded_unit(seed_value + float(i), flick + 7.0) - 0.5) * 12.0)
			var col: Color = EXPL_ARC_COLORS[i % EXPL_ARC_COLORS.size()]
			canvas.draw_polyline(PackedVector2Array([arc_s, arc_mid, arc_e]), Color(col.r, col.g, col.b, 0.9 * life_ratio), 1.0, true)


func _shift_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	if offset == Vector2.ZERO:
		return points
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in range(points.size()):
		out[i] = points[i] + offset
	return out


func _draw_particles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for particle in _particles:
		var max_life := maxf(0.01, float(particle.get("max_life", SPARK_SECONDS)))
		var life_t := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var am := minf(1.0, life_t * 2.0)
		var color: Color = particle.get("color", SPARK_COLORS[0])
		var pos: Vector2 = (particle.get("pos", Vector2.ZERO) as Vector2) + shake_offset
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		var size := maxf(1.0, float(particle.get("size", 2.0)) * am)
		var ptype: String = particle.get("type", "dot")
		if ptype == "streak":
			var tail := pos - vel * (0.8 / 60.0)  # original tail = velocity * 0.8 px/frame
			canvas.draw_line(tail, pos, Color(color.r, color.g, color.b, am), maxf(1.0, size * 0.5), true)
			canvas.draw_circle(pos, maxf(1.0, size * 0.34), Color(1.0, 1.0, 1.0, am))
		elif ptype == "flash":
			canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.7 * am))
			canvas.draw_circle(pos, maxf(1.0, size * 0.5), Color(1.0, 1.0, 1.0, 0.6 * am))
		else:
			canvas.draw_circle(pos, maxf(1.0, size * 0.5), Color(color.r, color.g, color.b, am))
			if size > 2.0:
				canvas.draw_circle(pos, maxf(1.0, size * 0.25), Color(1.0, 1.0, 1.0, am))


# Recursive midpoint-displacement bolt, ported from the original SolarBolt
# `_gen_lightning` / `subdivide`: each pass inserts a perpendicular-offset
# midpoint, then recurses with the displacement scaled by 0.52 until it falls
# below min_disp. Produces the fractal jaggedness of the original.
func _subdivide(points: PackedVector2Array, disp: float, min_disp: float) -> PackedVector2Array:
	if disp < min_disp:
		return points
	var out := PackedVector2Array()
	out.append(points[0])
	for i in range(points.size() - 1):
		var p1 := points[i]
		var p2 := points[i + 1]
		var mid := (p1 + p2) * 0.5
		var seg := p2 - p1
		var seg_len := seg.length()
		if seg_len > 0.001:
			var normal := Vector2(-seg.y, seg.x) / seg_len
			mid += normal * randf_range(-disp, disp)
		out.append(mid)
		out.append(p2)
	return _subdivide(out, disp * 0.52, min_disp)


# Main fractal bolt + 3..5 branches (each 15..35% length, ±0.9 rad off the
# bolt->ball direction) + 40%-chance sub-branches. Mirrors original lines
# 16325-16358. Generated once per strike; the path is fixed for its lifetime.
func _gen_lightning(start: Vector2, end: Vector2) -> Dictionary:
	var total := start.distance_to(end)
	var main := _subdivide(PackedVector2Array([start, end]), maxf(16.0, total * 0.12), 3.0)
	var branches: Array[PackedVector2Array] = []
	if main.size() > 4:
		var branch_count := 3 + (randi() % 3)  # 3..5
		var used_indices := {}
		for _b in range(branch_count):
			var idx := randi_range(maxi(1, int(float(main.size()) / 4.0)), main.size() - 2)
			if used_indices.has(idx):
				continue  # original used_indices guard: no duplicate branch root
			used_indices[idx] = true
			var bp := main[idx]
			var blen := maxf(20.0, total * randf_range(0.15, 0.35))
			var ang := (end - bp).angle() + randf_range(-0.9, 0.9)
			var bend := bp + Vector2(cos(ang), sin(ang)) * blen
			var branch := _subdivide(PackedVector2Array([bp, bend]), maxf(10.0, blen * 0.15), 4.0)
			branches.append(branch)
			if randf() < 0.4 and branch.size() > 3:
				var sidx := randi_range(int(float(branch.size()) / 2.0), branch.size() - 2)
				var sp := branch[sidx]
				var slen := maxf(10.0, blen * 0.4)
				var sang := ang + randf_range(-1.2, 1.2)
				var send := sp + Vector2(cos(sang), sin(sang)) * slen
				branches.append(_subdivide(PackedVector2Array([sp, send]), maxf(6.0, slen * 0.12), 5.0))
	return {"main": main, "branches": branches}


func _register_ball_intensity_contact(registry: Object) -> void:
	var ball_intensity: Object = _get_registry_instance(registry, "ball_intensity")
	if ball_intensity != null and ball_intensity.has_method("register_contact"):
		ball_intensity.register_contact("lingpet", "player", {"source": "solar_bolt"})


func _play_solar_bolt_feedback(registry: Object) -> void:
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_solar_bolt_strike"):
		audio.play_solar_bolt_strike()
	elif audio.has_method("play_ragnarok_shot"):
		audio.play_ragnarok_shot()
	elif audio.has_method("play_thunder_orb_boom"):
		audio.play_thunder_orb_boom()


func _apply_feedback_shake(registry: Object) -> void:
	var feedback: Object = _get_registry_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.055, 2.0)


func _ball_is_above_player(owner: Object, ball_center: Vector2, ball_radius: float) -> bool:
	var player_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", DEFAULT_PLAYER_PADDLE_HEIGHT)))
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - player_height))
	return ball_center.y < player_pos.y - ball_radius


func _predict_player_lane_x(owner: Object, ball_center: Vector2, ball_vel: Vector2, ball_radius: float) -> float:
	var player_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", DEFAULT_PLAYER_PADDLE_HEIGHT)))
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - player_height))
	var target_y := player_pos.y - ball_radius
	var vertical_gap := maxf(0.0, target_y - ball_center.y)
	var impact_boost := maxf(0.01, float(BattleSceneOwnerReader.get_value(owner, "ball_impact_boost", 1.0)))
	var frames_to_player := vertical_gap / maxf(0.01, ball_vel.y * impact_boost)
	return ball_center.x + ball_vel.x * impact_boost * frames_to_player


func _player_can_block(owner: Object, future_ball_x: float, ball_radius: float) -> bool:
	var player_width := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", DEFAULT_PLAYER_PADDLE_WIDTH)))
	var player_height := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", DEFAULT_PLAYER_PADDLE_HEIGHT)))
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5 - player_width * 0.5, FIELD_HEIGHT - player_height))
	return future_ball_x >= player_pos.x - ball_radius and future_ball_x <= player_pos.x + player_width + ball_radius


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_paddle_width", 100.0)))
	var boss_h := maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_origin_from_context(context: Dictionary, fallback: Vector2) -> Vector2:
	var value: Variant = context.get("companion_pos", fallback)
	return value if value is Vector2 and value != Vector2.ZERO else fallback


func _get_context_or_owner_value(context: Dictionary, owner: Object, key: String, fallback: Variant) -> Variant:
	if context.has(key):
		return context.get(key, fallback)
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_context_or_owner_vector2(context: Dictionary, owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_context_or_owner_value(context, owner, key, fallback)
	return value if value is Vector2 else fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


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


func _consume_jitter_radians() -> float:
	if not _jitter_radians_for_tests.is_empty():
		return clampf(_jitter_radians_for_tests.pop_front(), -FIRST_STRIKE_JITTER_RADIANS, FIRST_STRIKE_JITTER_RADIANS)
	return randf_range(-FIRST_STRIKE_JITTER_RADIANS, FIRST_STRIKE_JITTER_RADIANS)


func _roll_unit() -> float:
	if not _force_rolls.is_empty():
		return clampf(_force_rolls.pop_front(), 0.0, 1.0)
	if _force_roll >= 0.0:
		return clampf(_force_roll, 0.0, 1.0)
	return randf()


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed := sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
