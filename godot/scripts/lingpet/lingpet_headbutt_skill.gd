extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DASH_SPEED := 1080.0
const DASH_RADIUS := 25.0
const HOMING_TURN_RATE := 5.80
const HOMING_LEAD_SECONDS := 0.18
const IMPACT_SECONDS := 0.34
const MISS_FLASH_SECONDS := 0.24
const KNOCKBACK_DISTANCE := 150.0
const IMPACT_NUDGE_DISTANCE := 24.0
const KNOCKBACK_VELOCITY := 13.0
const KNOCKBACK_FRAMES := 30.0
const KNOCKBACK_DECAY := 0.91
const MOVING_MISS_SPEED_THRESHOLD := 0.75
const GUARANTEED_MISS_SPEED := 9.0
const MOVING_MISS_CHANCE := 0.42
const MISS_OFFSET_X := 130.0
const TRAIL_MAX_POINTS := 12
const COMBO_MIN_COUNT := 1
const COMBO_MAX_COUNT := 3
const COMBO_SINGLE_ROLL := 0.42
const COMBO_DOUBLE_ROLL := 0.78
const REPEAT_DELAY_MIN_SECONDS := 1.0
const REPEAT_DELAY_MAX_SECONDS := 2.0

var _active := false
var _planned_miss := false
var _pos := Vector2.ZERO
var _target := Vector2.ZERO
var _dash_dir := Vector2(0.0, -1.0)
var _trail: Array[Vector2] = []
var _impact_pos := Vector2.ZERO
var _impact_timer := 0.0
var _miss_timer := 0.0
var _repeat_wait_timer := 0.0
var _repeat_anchor_pos := Vector2.ZERO
var _combo_total := 0
var _combo_index := 0
var _strike_request_count := 0
var _last_result := ""
var _last_miss_reason := ""
var _last_knockback_velocity := 0.0
var _hit_count := 0
var _miss_count := 0
var _last_boss_pos := Vector2.ZERO
var _has_last_boss_pos := false


func reset() -> void:
	_active = false
	_planned_miss = false
	_pos = Vector2.ZERO
	_target = Vector2.ZERO
	_dash_dir = Vector2(0.0, -1.0)
	_trail.clear()
	_impact_pos = Vector2.ZERO
	_impact_timer = 0.0
	_miss_timer = 0.0
	_repeat_wait_timer = 0.0
	_repeat_anchor_pos = Vector2.ZERO
	_combo_total = 0
	_combo_index = 0
	_strike_request_count = 0
	_last_result = ""
	_last_miss_reason = ""
	_last_knockback_velocity = 0.0
	_last_boss_pos = Vector2.ZERO
	_has_last_boss_pos = false


func prewarm() -> void:
	pass


func can_arm(params: Dictionary) -> bool:
	if not bool(params.get("companion_visible", false)):
		return false
	var companion_pos: Vector2 = _as_vector2(params.get("companion_pos", Vector2.ZERO), Vector2.ZERO)
	return _is_companion_onscreen(companion_pos)


func launch(origin: Vector2, owner: Object) -> bool:
	if owner == null:
		return false
	var boss_rect: Rect2 = _get_boss_rect(owner)
	_combo_total = _pick_combo_total(origin, boss_rect.position)
	_combo_index = 1
	_repeat_wait_timer = 0.0
	_repeat_anchor_pos = origin
	_strike_request_count = 0
	return _begin_dash(origin, owner)


func _begin_dash(origin: Vector2, owner: Object) -> bool:
	if owner == null:
		return false
	var boss_rect: Rect2 = _get_boss_rect(owner)
	_pos = origin
	_target = _get_homing_target(owner, boss_rect)
	_trail.clear()
	_trail.append(_pos)
	var moving_speed: float = _get_boss_moving_speed(owner, boss_rect.position)
	_planned_miss = _should_miss_moving_target(origin, boss_rect.position, moving_speed)
	if _planned_miss:
		var boss_center: Vector2 = boss_rect.get_center()
		var boss_vel: float = float(_get_owner_value(owner, "boss_vel", 0.0))
		var miss_dir: float = float(sign(boss_vel))
		if absf(miss_dir) <= 0.01:
			miss_dir = float(sign(boss_center.x - origin.x))
		if absf(miss_dir) <= 0.01:
			miss_dir = 1.0
		_target.x = clampf(boss_center.x + miss_dir * (boss_rect.size.x * 0.55 + MISS_OFFSET_X), -80.0, FIELD_WIDTH + 80.0)
		_target.y = boss_center.y + 18.0
		_last_miss_reason = "moving_target"
	else:
		_last_miss_reason = ""
	var to_target: Vector2 = _target - _pos
	if to_target.length_squared() <= 1.0:
		_dash_dir = Vector2(0.0, -1.0)
	else:
		_dash_dir = to_target.normalized()
	_active = true
	_last_result = "charging"
	_strike_request_count += 1
	_remember_boss_pos(boss_rect.position)
	return true


func update(delta: float, owner: Object, registry: Object = null) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_impact_timer = maxf(0.0, _impact_timer - safe_delta)
	_miss_timer = maxf(0.0, _miss_timer - safe_delta)
	if _active:
		_step_dash(safe_delta, owner, registry)
	elif _repeat_wait_timer > 0.0:
		_repeat_wait_timer = maxf(0.0, _repeat_wait_timer - safe_delta)
		if _repeat_wait_timer <= 0.0 and _combo_index < _combo_total:
			_combo_index += 1
			if not _begin_dash(_repeat_anchor_pos, owner):
				_repeat_wait_timer = 0.0
		else:
			_remember_boss_pos(_get_boss_rect(owner).position)
	else:
		_remember_boss_pos(_get_boss_rect(owner).position)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _active:
		_draw_dash(canvas, shake_offset)
	if _impact_timer > 0.0:
		_draw_impact(canvas, _impact_pos + shake_offset, _impact_timer / IMPACT_SECONDS, true)
	if _miss_timer > 0.0:
		_draw_impact(canvas, _impact_pos + shake_offset, _miss_timer / MISS_FLASH_SECONDS, false)


func has_visible_effects() -> bool:
	return _active or _impact_timer > 0.0 or _miss_timer > 0.0 or _repeat_wait_timer > 0.0


func is_active() -> bool:
	return _active or _repeat_wait_timer > 0.0


func has_companion_position_override() -> bool:
	return _active or _impact_timer > 0.0 or _miss_timer > 0.0 or _repeat_wait_timer > 0.0


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if _active:
		return _pos
	if _impact_timer > 0.0 or _miss_timer > 0.0:
		return _impact_pos
	if _repeat_wait_timer > 0.0:
		return _repeat_anchor_pos
	return fallback


func consume_companion_strike_request() -> bool:
	if _strike_request_count <= 0:
		return false
	_strike_request_count -= 1
	return true


func get_hit_count_for_tests() -> int:
	return _hit_count


func get_miss_count_for_tests() -> int:
	return _miss_count


func get_snapshot() -> Dictionary:
	return {
		"headbutt_active": _active,
		"headbutt_pos": _pos,
		"headbutt_target": _target,
		"headbutt_companion_override_active": has_companion_position_override(),
		"headbutt_companion_pos": get_companion_position_override(Vector2.ZERO),
		"headbutt_impact_active": _impact_timer > 0.0,
		"headbutt_impact_timer": _impact_timer,
		"headbutt_miss_active": _miss_timer > 0.0,
		"headbutt_miss_timer": _miss_timer,
		"headbutt_repeat_wait_active": _repeat_wait_timer > 0.0,
		"headbutt_repeat_wait_timer": _repeat_wait_timer,
		"headbutt_repeat_delay_min": REPEAT_DELAY_MIN_SECONDS,
		"headbutt_repeat_delay_max": REPEAT_DELAY_MAX_SECONDS,
		"headbutt_combo_min": COMBO_MIN_COUNT,
		"headbutt_combo_max": COMBO_MAX_COUNT,
		"headbutt_combo_total": _combo_total,
		"headbutt_combo_index": _combo_index,
		"headbutt_combo_remaining": maxi(0, _combo_total - _combo_index),
		"headbutt_last_result": _last_result,
		"headbutt_last_miss_reason": _last_miss_reason,
		"headbutt_hit_count": _hit_count,
		"headbutt_miss_count": _miss_count,
		"headbutt_knockback_distance": KNOCKBACK_DISTANCE,
		"headbutt_impact_nudge_distance": IMPACT_NUDGE_DISTANCE,
		"headbutt_knockback_velocity": _last_knockback_velocity,
		"headbutt_knockback_frames": KNOCKBACK_FRAMES,
		"headbutt_knockback_decay": KNOCKBACK_DECAY,
		"headbutt_moving_miss_chance": MOVING_MISS_CHANCE,
	}


func _step_dash(delta: float, owner: Object, registry: Object) -> void:
	if delta <= 0.0:
		return
	_trail.append(_pos)
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.remove_at(0)
	var boss_rect: Rect2 = _get_boss_rect(owner)
	if not _planned_miss:
		_target = _get_homing_target(owner, boss_rect)
		_steer_toward_target(delta)
	var remaining: float = (_target - _pos).length()
	var step_distance: float = DASH_SPEED * delta
	if step_distance >= remaining:
		_pos = _target
	else:
		_pos += _dash_dir * step_distance
	if not _planned_miss and _circle_hits_rect(_pos, DASH_RADIUS, boss_rect):
		_resolve_hit(owner, registry, boss_rect)
		return
	if step_distance >= remaining:
		_resolve_miss()
		return
	_remember_boss_pos(boss_rect.position)


func _resolve_hit(owner: Object, registry: Object, boss_rect: Rect2) -> void:
	_active = false
	_planned_miss = false
	_impact_pos = _pos
	_impact_timer = IMPACT_SECONDS
	_miss_timer = 0.0
	_last_result = "hit"
	_last_miss_reason = ""
	_hit_count += 1
	var boss_pos: Vector2 = boss_rect.position
	var boss_w: float = boss_rect.size.x
	var direction: float = float(sign(_dash_dir.x))
	if absf(direction) <= 0.01:
		direction = 1.0 if boss_rect.get_center().x <= FIELD_WIDTH * 0.5 else -1.0
	var next_pos := boss_pos
	_last_knockback_velocity = direction * KNOCKBACK_VELOCITY
	var ai_knockback_applied := _apply_ai_knockback(registry, _last_knockback_velocity)
	var impact_nudge := direction * (IMPACT_NUDGE_DISTANCE if ai_knockback_applied else KNOCKBACK_DISTANCE)
	next_pos.x = clampf(boss_pos.x + impact_nudge, 0.0, maxf(0.0, FIELD_WIDTH - boss_w))
	if owner != null:
		owner.set("boss_pos", next_pos)
		if owner.get("boss_vel") != null:
			owner.set("boss_vel", _last_knockback_velocity)
	_play_paddle_hit(registry)
	_trail.clear()
	_remember_boss_pos(next_pos)
	_schedule_next_dash_or_finish()


func _resolve_miss() -> void:
	_active = false
	_planned_miss = false
	_impact_pos = _pos
	_miss_timer = MISS_FLASH_SECONDS
	_impact_timer = 0.0
	_last_result = "miss"
	_miss_count += 1
	_trail.clear()
	_schedule_next_dash_or_finish()


func _schedule_next_dash_or_finish() -> void:
	if _combo_index < _combo_total:
		_repeat_anchor_pos = _impact_pos
		_repeat_wait_timer = _pick_repeat_delay()
	else:
		_repeat_wait_timer = 0.0


func _steer_toward_target(delta: float) -> void:
	var offset := _target - _pos
	if offset.length_squared() <= 1.0:
		return
	var desired_dir := offset.normalized()
	var turn_angle := clampf(_dash_dir.angle_to(desired_dir), -HOMING_TURN_RATE * delta, HOMING_TURN_RATE * delta)
	_dash_dir = _dash_dir.rotated(turn_angle).normalized()


func _get_homing_target(owner: Object, boss_rect: Rect2) -> Vector2:
	var target := boss_rect.get_center()
	var boss_vel := float(_get_owner_value(owner, "boss_vel", 0.0))
	target.x += boss_vel * 60.0 * HOMING_LEAD_SECONDS
	target.x = clampf(target.x, boss_rect.size.x * 0.5, FIELD_WIDTH - boss_rect.size.x * 0.5)
	return target


func _should_miss_moving_target(origin: Vector2, boss_pos: Vector2, moving_speed: float) -> bool:
	if moving_speed < MOVING_MISS_SPEED_THRESHOLD:
		return false
	if moving_speed >= GUARANTEED_MISS_SPEED:
		return true
	var roll := _deterministic_unit(origin, boss_pos, moving_speed)
	return roll < MOVING_MISS_CHANCE


func _pick_combo_total(origin: Vector2, boss_pos: Vector2) -> int:
	var roll := _deterministic_unit(origin + Vector2(31.0, -17.0), boss_pos, 5.0)
	if roll < COMBO_SINGLE_ROLL:
		return 1
	if roll < COMBO_DOUBLE_ROLL:
		return 2
	return 3


func _pick_repeat_delay() -> float:
	var roll := _deterministic_unit(
		_repeat_anchor_pos + Vector2(float(_combo_index) * 19.0, 43.0),
		_target,
		3.0 + float(_combo_index)
	)
	return lerpf(REPEAT_DELAY_MIN_SECONDS, REPEAT_DELAY_MAX_SECONDS, roll)


func _get_boss_moving_speed(owner: Object, boss_pos: Vector2) -> float:
	var owner_speed := absf(float(_get_owner_value(owner, "boss_vel", 0.0)))
	var sampled_speed := 0.0
	if _has_last_boss_pos:
		sampled_speed = absf(boss_pos.x - _last_boss_pos.x)
	return maxf(owner_speed, sampled_speed)


func _circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w: float = maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h: float = maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _remember_boss_pos(boss_pos: Vector2) -> void:
	_last_boss_pos = boss_pos
	_has_last_boss_pos = true


func _is_companion_onscreen(companion_pos: Vector2) -> bool:
	return (
		companion_pos.x >= 0.0
		and companion_pos.x <= FIELD_WIDTH
		and companion_pos.y >= 0.0
		and companion_pos.y <= FIELD_HEIGHT
	)


func _apply_ai_knockback(registry: Object, knockback_velocity: float) -> bool:
	var ai_state := _get_registry_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_velocity, KNOCKBACK_FRAMES, KNOCKBACK_DECAY, true)
		return true
	return false


func _deterministic_unit(origin: Vector2, boss_pos: Vector2, moving_speed: float) -> float:
	var hash_seed := origin.x * 12.9898 + origin.y * 4.1414 + boss_pos.x * 78.233 + moving_speed * 37.719 + float(_hit_count + _miss_count) * 11.13
	var value := sin(hash_seed) * 43758.5453
	return value - floor(value)


func _draw_dash(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for i in range(_trail.size()):
		var ratio := float(i + 1) / float(maxi(1, _trail.size()))
		var trail_pos := _trail[i] + shake_offset
		var alpha := 0.08 + 0.30 * ratio
		canvas.draw_circle(trail_pos, lerpf(3.0, 10.0, ratio), Color(0.84, 0.34, 1.0, alpha))
		if i > 0:
			var prev_pos := _trail[i - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.55, 0.95, 1.0, 0.26 * ratio), maxf(1.0, 4.0 * ratio), true)
	var pos := _pos + shake_offset
	canvas.draw_circle(pos, DASH_RADIUS + 9.0, Color(0.72, 0.25, 1.0, 0.12))
	canvas.draw_arc(pos, DASH_RADIUS + 5.0, 0.0, TAU, 30, Color(0.92, 0.62, 1.0, 0.42), 1.8, true)


func _draw_impact(canvas: CanvasItem, pos: Vector2, ratio: float, hit: bool) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var expansion := 1.0 - clamped
	var color := Color(0.58, 0.95, 1.0, 1.0) if hit else Color(0.75, 0.68, 0.90, 1.0)
	var radius := lerpf(18.0, 58.0, expansion)
	canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.18 * clamped))
	canvas.draw_arc(pos, radius * 0.82, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.62 * clamped), 2.4)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + expansion * 0.55
		var start := pos + Vector2(cos(angle), sin(angle)) * radius * 0.26
		var end := pos + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(start, end, Color(1.0, 1.0, 1.0, 0.42 * clamped), 1.5, true)


func _play_paddle_hit(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_paddle_hit"):
		audio.play_paddle_hit()


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
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
