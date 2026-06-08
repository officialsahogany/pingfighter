extends RefCounted

# Koyora 꼭두각시 조종 (Puppet Control) — ported from the original PingFighter
# arena hero 연화 (maria) skill `puppet_control` in downtown/hero_skills.py.
#
# Faithful 4-phase paddle-displacement crowd-control gag: Koyora flings cyan
# puppet strings up to the boss, drags it down to her cast spot, "kisses" it,
# then slides it back to its exact original position. It does NOT touch the
# ball, score, or apply damage — the payoff is emergent: while the boss is
# dragged out of its goal (and held there) it cannot defend, so rising balls
# score on it. While the grab owns the boss, `lingpet_puppet_grab_active` is
# written onto the owner so (a) boss_ai_state freezes the boss at the scripted
# position instead of chasing the ball, and (b) the ball collision detector
# skips the boss paddle (its hitbox is now sitting near midfield).

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

# Phase ids (mirror the original PuppetControl PHASE_* constants).
const PHASE_EXTENDING := 0   # 실이 뻗어나가는 중
const PHASE_PULLING := 1     # 상대를 끌어당기는 중
const PHASE_KISSING := 2     # 뽀뽀 중
const PHASE_RETURNING := 3   # 원래 위치로 복귀 중

# Phase durations (seconds) — the original's "20% faster" tuned values.
const EXTEND_SECONDS := 0.7
const PULL_SECONDS := 1.083
const KISS_SECONDS := 1.0
const RETURN_SECONDS := 0.833
const TOTAL_SECONDS := EXTEND_SECONDS + PULL_SECONDS + KISS_SECONDS + RETURN_SECONDS

# Boss center is pulled to KISS_FRONT_OFFSET px in front of (above) Koyora,
# toward midfield — mirrors the original kiss_y = caster_y - 60 for a bottom
# caster.
const KISS_FRONT_OFFSET := 60.0
const KISS_CENTER_Y_MIN := 120.0
const KISS_CENTER_Y_MAX := FIELD_HEIGHT - 90.0

const STRING_COUNT := 5
const STRING_SEGMENTS := 18
const STRING_WAVE_SPEED := 6.2
const HAND_OFFSET_Y := -6.0

const HEART_MAX := 14
const HEART_SPAWN_INTERVAL := 0.085
const HEART_RISE_SPEED := 46.0
const HEART_LIFE_SECONDS := 0.9

var _active := false
var _phase := PHASE_EXTENDING
var _phase_timer := 0.0
var _anim_time := 0.0
var _cast_pos := Vector2.ZERO
var _boss_size := Vector2(100.0, 40.0)
var _boss_original_center := Vector2.ZERO
var _kiss_center := Vector2.ZERO
var _boss_draw_center := Vector2.ZERO
var _heart_spawn_accum := 0.0
var _hearts: Array[Dictionary] = []
var _grab_count := 0
var _kiss_count := 0
var _last_phase_for_test := PHASE_EXTENDING
# True from launch until the boss is released back to its origin. This survives
# an owner-less cancel() (round-end cleanup runs without the owner in its deps)
# so the next update() that does have the owner can finish the release. Without
# it, the grab flag + dragged boss_pos leak into the next round and the boss AI
# re-freezes the boss at the dragged position.
var _owns_boss := false


func reset() -> void:
	_active = false
	_owns_boss = false
	_phase = PHASE_EXTENDING
	_phase_timer = 0.0
	_anim_time = 0.0
	_cast_pos = Vector2.ZERO
	_boss_size = Vector2(100.0, 40.0)
	_boss_original_center = Vector2.ZERO
	_kiss_center = Vector2.ZERO
	_boss_draw_center = Vector2.ZERO
	_heart_spawn_accum = 0.0
	_hearts.clear()
	_last_phase_for_test = PHASE_EXTENDING


func prewarm() -> void:
	pass


func cancel(owner: Object = null, _registry: Object = null) -> void:
	# Round-end / teardown: release the boss cleanly so the freeze + collision
	# skip never leak across rounds.
	_active = false
	_clear_visuals()
	if owner != null:
		_release(owner)
	# owner == null (round-end cleanup deps carry no owner): keep _owns_boss and
	# the captured origin so the next update() with the owner finishes the
	# release. Do NOT full-reset here or the restore data is lost.


func launch(origin: Vector2, owner: Object = null, _launch_context: Dictionary = {}) -> bool:
	if owner == null:
		return false
	_boss_size = Vector2(
		maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0))),
		maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	)
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	_boss_original_center = boss_pos + _boss_size * 0.5
	_cast_pos = origin
	_kiss_center = Vector2(
		clampf(origin.x, _boss_size.x * 0.5, FIELD_WIDTH - _boss_size.x * 0.5),
		clampf(origin.y - KISS_FRONT_OFFSET, KISS_CENTER_Y_MIN, KISS_CENTER_Y_MAX)
	)
	_active = true
	_phase = PHASE_EXTENDING
	_phase_timer = 0.0
	_anim_time = 0.0
	_heart_spawn_accum = 0.0
	_hearts.clear()
	_boss_draw_center = _boss_original_center
	_grab_count += 1
	_last_phase_for_test = PHASE_EXTENDING
	# Take ownership of the boss on the launch frame so there is no one-frame gap
	# before the boss AI sees the freeze flag.
	_owns_boss = true
	_write_owner_grab(owner, _boss_original_center)
	return true


func update(delta: float, owner: Object = null, _registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if not _active:
		# Deferred release: a round-end cancel() without the owner left the grab
		# flag + dragged boss_pos on the owner. Now that we have the owner, restore
		# the boss to its origin and clear the flag so the next round is clean.
		if _owns_boss and owner != null:
			_release(owner)
		return
	var safe_delta: float = maxf(0.0, delta)
	_anim_time += safe_delta
	_phase_timer += safe_delta
	_advance_phase()
	if not _active:
		# Natural finish (return phase complete): restore + clear with this frame's owner.
		if owner != null:
			_release(owner)
		return
	_boss_draw_center = _compute_boss_center()
	_update_hearts(safe_delta)
	_write_owner_grab(owner, _boss_draw_center)


func _advance_phase() -> void:
	# Roll any number of completed phases over in a single frame so a large delta
	# cannot strand the skill in a finished phase.
	while _active:
		match _phase:
			PHASE_EXTENDING:
				if _phase_timer < EXTEND_SECONDS:
					return
				_phase_timer -= EXTEND_SECONDS
				_phase = PHASE_PULLING
			PHASE_PULLING:
				if _phase_timer < PULL_SECONDS:
					return
				_phase_timer -= PULL_SECONDS
				_phase = PHASE_KISSING
				_kiss_count += 1
			PHASE_KISSING:
				if _phase_timer < KISS_SECONDS:
					return
				_phase_timer -= KISS_SECONDS
				_phase = PHASE_RETURNING
			PHASE_RETURNING:
				if _phase_timer < RETURN_SECONDS:
					return
				_active = false
				return
			_:
				_active = false
				return
		_last_phase_for_test = _phase


func _compute_boss_center() -> Vector2:
	match _phase:
		PHASE_EXTENDING:
			return _boss_original_center
		PHASE_PULLING:
			var p: float = clampf(_phase_timer / PULL_SECONDS, 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - p, 2.0)
			return _boss_original_center.lerp(_kiss_center, eased)
		PHASE_KISSING:
			return _kiss_center
		PHASE_RETURNING:
			var rp: float = clampf(_phase_timer / RETURN_SECONDS, 0.0, 1.0)
			var reased: float = rp * rp
			return _kiss_center.lerp(_boss_original_center, reased)
		_:
			return _boss_original_center


func _write_owner_grab(owner: Object, boss_center: Vector2) -> void:
	if owner == null:
		return
	_owns_boss = true
	owner.set("lingpet_puppet_grab_active", true)
	owner.set("boss_pos", boss_center - _boss_size * 0.5)


func _release(owner: Object) -> void:
	# Restore the boss to its exact captured origin and drop the freeze /
	# collision-skip flag, then fully reset. Requires the owner; the deferred
	# path in update() guarantees this only runs with a non-null owner.
	if owner != null and _owns_boss:
		owner.set("boss_pos", _boss_original_center - _boss_size * 0.5)
		owner.set("lingpet_puppet_grab_active", false)
	_owns_boss = false
	reset()


func _clear_visuals() -> void:
	_hearts.clear()
	_heart_spawn_accum = 0.0


func _update_hearts(delta: float) -> void:
	for heart in _hearts:
		heart["life"] = float(heart.get("life", 0.0)) - delta
		var pos: Vector2 = heart.get("pos", Vector2.ZERO)
		pos.y -= HEART_RISE_SPEED * delta
		pos.x += float(heart.get("drift", 0.0)) * delta
		heart["pos"] = pos
	var i := _hearts.size() - 1
	while i >= 0:
		if float(_hearts[i].get("life", 0.0)) <= 0.0:
			_hearts.remove_at(i)
		i -= 1
	if _phase != PHASE_KISSING:
		return
	_heart_spawn_accum += delta
	while _heart_spawn_accum >= HEART_SPAWN_INTERVAL and _hearts.size() < HEART_MAX:
		_heart_spawn_accum -= HEART_SPAWN_INTERVAL
		_hearts.append({
			"pos": _kiss_center + Vector2(randf_range(-22.0, 22.0), randf_range(-6.0, 14.0)),
			"drift": randf_range(-18.0, 18.0),
			"life": HEART_LIFE_SECONDS,
			"size": randf_range(5.0, 9.0),
		})


func is_active() -> bool:
	return _active


func has_visible_effects() -> bool:
	return _active or not _hearts.is_empty()


func has_companion_position_override() -> bool:
	return _active


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _cast_pos if _active else fallback


func get_grab_count_for_tests() -> int:
	return _grab_count


func get_kiss_count_for_tests() -> int:
	return _kiss_count


func get_snapshot() -> Dictionary:
	return {
		"puppet_grab_active": _active,
		"puppet_grab_phase": _phase,
		"puppet_grab_phase_timer": _phase_timer,
		"puppet_grab_boss_center": _boss_draw_center,
		"puppet_grab_kiss_center": _kiss_center,
		"puppet_grab_original_center": _boss_original_center,
		"puppet_grab_cast_pos": _cast_pos,
		"puppet_grab_companion_override_active": has_companion_position_override(),
		"puppet_grab_owns_boss": _owns_boss,
		"puppet_grab_grab_count": _grab_count,
		"puppet_grab_kiss_count": _kiss_count,
		"puppet_grab_heart_count": _hearts.size(),
		"puppet_grab_extend_seconds": EXTEND_SECONDS,
		"puppet_grab_pull_seconds": PULL_SECONDS,
		"puppet_grab_kiss_seconds": KISS_SECONDS,
		"puppet_grab_return_seconds": RETURN_SECONDS,
		"puppet_grab_total_seconds": TOTAL_SECONDS,
		"puppet_grab_kiss_front_offset": KISS_FRONT_OFFSET,
	}


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _active:
		_draw_strings(canvas, shake_offset)
		_draw_hand(canvas, shake_offset)
	if not _hearts.is_empty():
		_draw_hearts(canvas, shake_offset)


func _draw_strings(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var hand: Vector2 = _cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	var tip: Vector2 = _boss_draw_center + shake_offset
	var kissing := _phase == PHASE_KISSING or _phase == PHASE_RETURNING
	var base_color := Color(1.0, 0.62, 0.78, 0.9) if kissing else Color(0.38, 0.92, 0.86, 0.85)
	var axis: Vector2 = tip - hand
	var length: float = axis.length()
	if length < 1.0:
		return
	var perp: Vector2 = Vector2(-axis.y, axis.x).normalized()
	# Strings reach their full wave only once they've extended; during EXTENDING
	# the wave is suppressed near the tip so the strings read as "shooting out".
	var extend_ratio: float = clampf(_phase_timer / EXTEND_SECONDS, 0.0, 1.0) if _phase == PHASE_EXTENDING else 1.0
	for s in range(STRING_COUNT):
		var offset: float = -20.0 + float(s) * 10.0
		var phase_seed: float = float(s) * 1.31 + _anim_time * STRING_WAVE_SPEED
		var points := PackedVector2Array()
		for seg in range(STRING_SEGMENTS + 1):
			var t: float = float(seg) / float(STRING_SEGMENTS)
			var along: Vector2 = hand.lerp(tip, t)
			var taper: float = sin(t * PI)
			var wave: float = sin(phase_seed + t * 7.0) * 5.0 * taper * extend_ratio
			along += perp * (offset * (1.0 - t * 0.6) + wave)
			points.append(along)
		canvas.draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.85), 2.0, true)


func _draw_hand(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var hand: Vector2 = _cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	canvas.draw_circle(hand, 7.0, Color(0.20, 0.55, 0.52, 0.65))
	canvas.draw_circle(hand, 4.0, Color(0.60, 0.96, 0.90, 0.85))


func _draw_hearts(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for heart in _hearts:
		var life_ratio: float = clampf(float(heart.get("life", 0.0)) / HEART_LIFE_SECONDS, 0.0, 1.0)
		var pos: Vector2 = heart.get("pos", Vector2.ZERO) + shake_offset
		var size: float = float(heart.get("size", 6.0))
		var alpha: float = 0.85 * life_ratio
		_draw_heart(canvas, pos, size, Color(1.0, 0.42, 0.62, alpha))


func _draw_heart(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var lobe: float = size * 0.5
	canvas.draw_circle(center + Vector2(-lobe * 0.55, -lobe * 0.25), lobe, color)
	canvas.draw_circle(center + Vector2(lobe * 0.55, -lobe * 0.25), lobe, color)
	var tri := PackedVector2Array([
		center + Vector2(-size * 0.6, 0.0),
		center + Vector2(size * 0.6, 0.0),
		center + Vector2(0.0, size * 0.9),
	])
	canvas.draw_colored_polygon(tri, color)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback
