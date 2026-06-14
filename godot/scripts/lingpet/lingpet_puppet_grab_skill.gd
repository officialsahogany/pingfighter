extends RefCounted

# Koyora 꼭두각시 조종 (Puppet Control) — ported from the original PingFighter
# arena hero 연화 (maria) skill `puppet_control` in downtown/hero_skills.py.
#
# Faithful 4-phase paddle-displacement crowd-control gag: Koyora flings rose
# puppet strings up to the boss, drags it down to her cast spot, "kisses" it,
# then slides it back to its exact original position. The live ball can now cut
# the strings during the held control window; the skill still never moves the
# ball, score, or applies damage. While the grab owns the boss,
# `lingpet_puppet_grab_active` is written onto the owner so boss_ai_state
# freezes the boss at the scripted position instead of chasing the ball. Boss
# paddle collision remains normal while displaced, matching the Python original.

const CHU_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const LingpetPuppetGrabPayloadFactory := preload("res://scripts/lingpet/lingpet_puppet_grab_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

# Phase ids (mirror the original PuppetControl PHASE_* constants, plus a
# Godot-only miss / retry phases for the Venom-Edge-style snapshot-lock-on miss).
const PHASE_EXTENDING := 0   # 실이 뻗어나가는 중
const PHASE_PULLING := 1     # 상대를 끌어당기는 중
const PHASE_KISSING := 2     # 뽀뽀 중
const PHASE_RETURNING := 3   # 원래 위치로 복귀 중
const PHASE_MISSING := 4     # 잡기 실패: 줄이 빈자리에 도착, MISS 텍스트 + 줄 회수
const PHASE_RETRY_WAIT := 5  # 잡기 실패 후 재시도 대기: MISS 피드백 뒤 줄 재발사

# Phase durations (seconds).
# EXTEND is 30% faster than the original Yeonhwa 0.7s (0.7 / 1.3 ≈ 0.538) so
# the strings whip out fast enough to make a real lock-on / dodge race.
# PULL / KISS / RETURN remain the original's "20% faster" tuned values.
const EXTEND_SECONDS := 0.538
const PULL_SECONDS := 1.083
const KISS_SECONDS := 1.0
const RETURN_SECONDS := 0.833
const MISS_SECONDS := 0.45   # 줄이 회수되며 MISS 텍스트가 페이드아웃하는 시간
const TOTAL_SECONDS := EXTEND_SECONDS + PULL_SECONDS + KISS_SECONDS + RETURN_SECONDS

const RETRY_DELAY_SECONDS := 0.5
const RETRY_CHANCE_PCT := 50.0

const COMPANION_CAST_EXTEND_PROGRESS_MAX := 0.56
const COMPANION_CAST_PULL_PROGRESS_START := 0.62
const COMPANION_CAST_PULL_PROGRESS_END := 0.96

# Snapshot lock-on hit window: at launch we capture the boss center as the
# string tip target. At end of EXTENDING we check the current boss center
# against that lock-on point — within `_boss_size.x * 0.5 + HIT_TOLERANCE_PAD`
# is a HIT, otherwise it's a MISS (boss dodged in time → strings hit air).
const HIT_TOLERANCE_PAD := 8.0

# Boss center is pulled to KISS_FRONT_OFFSET px in front of (above) Koyora,
# toward midfield — mirrors the original kiss_y = caster_y - 60 for a bottom
# caster.
const KISS_FRONT_OFFSET := 60.0
const KISS_CENTER_Y_MIN := 120.0
const KISS_CENTER_Y_MAX := FIELD_HEIGHT - 90.0

const STRING_COUNT := 5
const STRING_SEGMENTS := 20
const STRING_WAVE_SPEED := 4.0
const STRING_WAVE_AMPLITUDE := 12.0
const STRING_TIP_FOCUS_START := 0.55
const STRING_TIP_FOCUS_POWER := 1.35
const HAND_OFFSET_Y := -6.0

const HEART_MAX := 14
const HEART_SPAWN_INTERVAL := 0.085
const HEART_RISE_SPEED := 46.0
const HEART_LIFE_SECONDS := 0.9

const SPARKLE_MAX := 16
const SPARKLE_SPAWN_INTERVAL := 0.045
const SPARKLE_LIFE_SECONDS := 0.5

const PULL_TENSION_LINE_COUNT := 3
const PULL_TENSION_LINE_MIN := 20.0
const PULL_TENSION_LINE_MAX := 40.0

const CHU_TEXT := "CHU~"
const CHU_FONT_SIZE := 22
const CHU_OFFSET := Vector2(48.0, -28.0)

const MISS_TEXT := "MISS"
const MISS_FONT_SIZE := 32
const MISS_FLOAT_UP_SPEED := 28.0
const MISS_OFFSET := Vector2(-32.0, -6.0)
const ROPE_CUT_BALL_RADIUS_PAD := 18.0
const ROPE_CUT_ARMING_SECONDS := 0.14
const ROPE_CUT_GAP := 18.0
const CUT_TEXT := "끊김!"
const CUT_FONT_SIZE := 25
const CUT_OFFSET := Vector2(-36.0, -18.0)

var _active := false
var _phase := PHASE_EXTENDING
var _phase_timer := 0.0
var _anim_time := 0.0
var _cast_pos := Vector2.ZERO
var _boss_size := Vector2(100.0, 40.0)
var _boss_original_center := Vector2.ZERO
var _return_start_center := Vector2.ZERO
var _kiss_center := Vector2.ZERO
var _boss_draw_center := Vector2.ZERO
var _cut_by_ball := false
var _cut_point := Vector2.ZERO
var _cut_count := 0
var _heart_spawn_accum := 0.0
var _hearts: Array[Dictionary] = []
var _sparkle_spawn_accum := 0.0
var _sparkles: Array[Dictionary] = []
var _grab_count := 0
var _kiss_count := 0
var _miss_count := 0
var _shot_count := 0
var _retry_count := 0
var _active_skill_level := 1
var _retries_remaining := 0
var _retry_roll_queue_for_tests: Array[bool] = []
var _missed := false
# Captured at launch: where the boss center WAS the moment strings fired. The
# strings travel toward this fixed point; if the boss moves out of HIT range
# by the time they arrive, the grab MISSes (snapshot lock-on, Venom-Edge style).
var _predicted_target_center := Vector2.ZERO
var _last_phase_for_test := PHASE_EXTENDING
# True from launch until the boss is released back to its origin. This survives
# an owner-less cancel() (round-end cleanup runs without the owner in its deps)
# so the next update() that does have the owner can finish the release. Without
# it, the grab flag + dragged boss_pos leak into the next round and the boss AI
# re-freezes the boss at the dragged position.
var _owns_boss := false
var _pending_owner_grab := false


func reset() -> void:
	_active = false
	_owns_boss = false
	_pending_owner_grab = false
	_missed = false
	_phase = PHASE_EXTENDING
	_phase_timer = 0.0
	_anim_time = 0.0
	_cast_pos = Vector2.ZERO
	_boss_size = Vector2(100.0, 40.0)
	_boss_original_center = Vector2.ZERO
	_return_start_center = Vector2.ZERO
	_predicted_target_center = Vector2.ZERO
	_kiss_center = Vector2.ZERO
	_boss_draw_center = Vector2.ZERO
	_cut_by_ball = false
	_cut_point = Vector2.ZERO
	_heart_spawn_accum = 0.0
	_hearts.clear()
	_sparkle_spawn_accum = 0.0
	_sparkles.clear()
	_last_phase_for_test = PHASE_EXTENDING
	_active_skill_level = 1
	_retries_remaining = 0
	_retry_roll_queue_for_tests.clear()


func prewarm() -> void:
	pass


func cancel(owner: Object = null, _registry: Object = null) -> void:
	# Round-end / teardown: release the boss cleanly so the freeze + collision
	# skip never leak across rounds.
	_active = false
	_clear_visuals()
	if owner != null:
		_release(owner)
	elif not _owns_boss:
		reset()
	# owner == null (round-end cleanup deps carry no owner): keep _owns_boss and
	# the captured origin so the next update() with the owner finishes the
	# release. Do NOT full-reset here or the restore data is lost.


func launch(origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	if owner == null:
		return false
	_active_skill_level = _get_active_skill_level(launch_context)
	_retries_remaining = _get_max_retries_for_level(_active_skill_level)
	_retry_count = 0
	_shot_count = 0
	_grab_count += 1
	return _begin_shot(origin, owner)


func _begin_shot(origin: Vector2, owner: Object = null) -> bool:
	_boss_size = Vector2(
		maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0))),
		maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	)
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	# Snapshot lock-on: the strings target the boss center AT LAUNCH. The boss is
	# free to keep tracking the ball during EXTENDING; if it has moved out of
	# range by the time the strings arrive, the grab MISSes.
	_predicted_target_center = boss_pos + _boss_size * 0.5
	_boss_original_center = _predicted_target_center
	_cast_pos = origin
	_kiss_center = Vector2(
		clampf(origin.x, _boss_size.x * 0.5, FIELD_WIDTH - _boss_size.x * 0.5),
		clampf(origin.y - KISS_FRONT_OFFSET, KISS_CENTER_Y_MIN, KISS_CENTER_Y_MAX)
	)
	_return_start_center = _kiss_center
	_active = true
	_missed = false
	_cut_by_ball = false
	_cut_point = Vector2.ZERO
	_phase = PHASE_EXTENDING
	_phase_timer = 0.0
	_anim_time = 0.0
	_heart_spawn_accum = 0.0
	_hearts.clear()
	_sparkle_spawn_accum = 0.0
	_sparkles.clear()
	_boss_draw_center = _predicted_target_center
	_shot_count += 1
	_last_phase_for_test = PHASE_EXTENDING
	# IMPORTANT: do NOT take ownership of the boss yet. EXTENDING is the dodge
	# window; we only flip `lingpet_puppet_grab_active` (and start writing
	# `boss_pos`) on a confirmed HIT at end of EXTENDING. Otherwise the boss
	# would be pinned during the window and could never dodge — there would be
	# no real MISS case.
	_owns_boss = false
	_pending_owner_grab = false
	return true


func update(delta: float, owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
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
	_advance_phase(owner, registry)
	if not _active:
		# Natural finish: only release the owner state if we actually owned it
		# (HIT path → freeze flag was set). A MISS finish never owned the boss,
		# so there is nothing to restore — just reset locally.
		if _owns_boss and owner != null:
			_release(owner)
		else:
			_missed = false
			_cut_by_ball = false
			_owns_boss = false
			_pending_owner_grab = false
			reset()
		return
	_boss_draw_center = _compute_boss_center(owner)
	if _maybe_cut_rope_by_ball(owner, registry):
		_boss_draw_center = _compute_boss_center(owner)
	_update_hearts(safe_delta)
	_update_sparkles(safe_delta)
	# Only pin / sync the owner once we have committed to a HIT. During EXTENDING
	# and miss / retry feedback the boss must be free.
	if _owns_boss or _pending_owner_grab:
		_write_owner_grab(owner, _boss_draw_center)


func _advance_phase(owner: Object = null, registry: Object = null) -> void:
	# Roll any number of completed phases over in a single frame so a large delta
	# cannot strand the skill in a finished phase.
	while _active:
		match _phase:
			PHASE_EXTENDING:
				if _phase_timer < EXTEND_SECONDS:
					return
				_phase_timer -= EXTEND_SECONDS
				# Snapshot lock-on hit check: did the boss stay within reach of
				# the point we aimed for at launch?
				var arrival_center: Vector2 = _get_current_boss_center(owner)
				if arrival_center.distance_to(_predicted_target_center) <= hit_tolerance():
					# HIT — commit the grab. Re-capture origin to the actual
					# arrival position so the post-kiss RETURN puts the boss back
					# exactly where it was on grab, not where it was at launch.
					_boss_original_center = arrival_center
					_phase = PHASE_PULLING
					_pending_owner_grab = true
					_write_owner_grab(owner, arrival_center)
					_play_audio(registry, "play_lingpet_puppet_grab_pull")
				else:
					# MISS — strings hit air. Skill ends without ever freezing the
					# boss; no PULL / KISS / RETURN.
					_enter_miss_or_retry(registry)
			PHASE_PULLING:
				if _phase_timer < PULL_SECONDS:
					return
				_phase_timer -= PULL_SECONDS
				_phase = PHASE_KISSING
				_kiss_count += 1
				_play_audio(registry, "play_lingpet_puppet_grab_kiss")
			PHASE_KISSING:
				if _phase_timer < KISS_SECONDS:
					return
				_phase_timer -= KISS_SECONDS
				_return_start_center = _kiss_center
				_phase = PHASE_RETURNING
			PHASE_RETURNING:
				if _phase_timer < RETURN_SECONDS:
					return
				_active = false
				return
			PHASE_MISSING:
				if _phase_timer < MISS_SECONDS:
					return
				_active = false
				return
			PHASE_RETRY_WAIT:
				if _phase_timer < RETRY_DELAY_SECONDS:
					return
				_phase_timer -= RETRY_DELAY_SECONDS
				var retry_carry := _phase_timer
				_retry_count += 1
				_begin_shot(_cast_pos, owner)
				_phase_timer = retry_carry
				_play_audio(registry, "play_lingpet_puppet_grab_cast")
			_:
				_active = false
				return
		_last_phase_for_test = _phase


func _enter_miss_or_retry(registry: Object = null) -> void:
	_missed = true
	_miss_count += 1
	_play_audio(registry, "play_lingpet_puppet_grab_miss")
	if _retries_remaining <= 0:
		_phase = PHASE_MISSING
		return
	if _roll_retry():
		_retries_remaining -= 1
		_phase = PHASE_RETRY_WAIT
	else:
		_retries_remaining = 0
		_phase = PHASE_MISSING


func _get_active_skill_level(launch_context: Dictionary) -> int:
	return clampi(
		int(launch_context.get("active_skill_level", launch_context.get("skill_level", 1))),
		1,
		5
	)


func _get_max_retries_for_level(level: int) -> int:
	if level >= 5:
		return 2
	if level >= 3:
		return 1
	return 0


func _roll_retry() -> bool:
	if not _retry_roll_queue_for_tests.is_empty():
		return bool(_retry_roll_queue_for_tests.pop_front())
	return randf() < RETRY_CHANCE_PCT / 100.0


func hit_tolerance() -> float:
	return _boss_size.x * 0.5 + HIT_TOLERANCE_PAD


func _maybe_cut_rope_by_ball(owner: Object, registry: Object = null) -> bool:
	if not _is_rope_cuttable_phase():
		return false
	if owner == null or not bool(_get_owner_value(owner, "ball_active", false)):
		return false
	if _phase == PHASE_PULLING and _phase_timer < ROPE_CUT_ARMING_SECONDS:
		return false
	var hand := _get_rope_hand()
	var tip := _boss_draw_center
	if hand.distance_to(tip) < 1.0:
		return false
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var prev_value: Variant = _get_owner_value(owner, "ball_pos_prev", null)
	var ball_prev: Vector2 = prev_value if prev_value is Vector2 else ball_pos
	if ball_prev == Vector2.ZERO and ball_pos.distance_to(Vector2.ZERO) > 90.0:
		ball_prev = ball_pos
	var ball_radius: float = maxf(1.0, float(_get_owner_value(owner, "ball_size", 28.6)) * 0.5)
	var cut_radius: float = ball_radius + ROPE_CUT_BALL_RADIUS_PAD
	if _segment_distance(ball_prev, ball_pos, hand, tip) > cut_radius:
		return false
	_enter_rope_cut(registry, _closest_point_on_segment(ball_pos, hand, tip))
	return true


func _is_rope_cuttable_phase() -> bool:
	return _phase == PHASE_PULLING or _phase == PHASE_KISSING


func _enter_rope_cut(registry: Object, cut_point: Vector2) -> void:
	if _cut_by_ball:
		return
	_cut_by_ball = true
	_cut_count += 1
	_cut_point = cut_point
	_return_start_center = _boss_draw_center
	_phase = PHASE_RETURNING
	_phase_timer = 0.0
	_heart_spawn_accum = 0.0
	_sparkle_spawn_accum = 0.0
	_hearts.clear()
	_sparkles.clear()
	_play_audio(registry, "play_lingpet_puppet_grab_miss")


func _get_current_boss_center(owner: Object) -> Vector2:
	if owner == null:
		return _predicted_target_center
	var pos: Vector2 = _get_owner_vector2(owner, "boss_pos", _predicted_target_center - _boss_size * 0.5)
	return pos + _boss_size * 0.5


func _compute_boss_center(owner: Object = null) -> Vector2:
	match _phase:
		PHASE_EXTENDING:
			# Boss is free during the dodge window — report its CURRENT center so
			# snapshots / debug reads stay honest.
			return _get_current_boss_center(owner)
		PHASE_PULLING:
			var p: float = clampf(_phase_timer / PULL_SECONDS, 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - p, 2.0)
			return _boss_original_center.lerp(_kiss_center, eased)
		PHASE_KISSING:
			return _kiss_center
		PHASE_RETURNING:
			var rp: float = clampf(_phase_timer / RETURN_SECONDS, 0.0, 1.0)
			var reased: float = rp * rp
			return _return_start_center.lerp(_boss_original_center, reased)
		PHASE_MISSING, PHASE_RETRY_WAIT:
			return _get_current_boss_center(owner)
		_:
			return _boss_original_center


func _write_owner_grab(owner: Object, boss_center: Vector2) -> bool:
	if owner == null:
		return false
	_owns_boss = true
	_pending_owner_grab = false
	owner.set("lingpet_puppet_grab_active", true)
	owner.set("boss_pos", boss_center - _boss_size * 0.5)
	return true


func _get_rope_hand() -> Vector2:
	return _cast_pos + Vector2(0.0, HAND_OFFSET_Y)


func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(_closest_point_on_segment(point, a, b))


func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return a
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if _segments_intersect(a, b, c, d):
		return 0.0
	return minf(
		minf(_point_segment_distance(a, c, d), _point_segment_distance(b, c, d)),
		minf(_point_segment_distance(c, a, b), _point_segment_distance(d, a, b))
	)


func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denom := _cross(ab, cd)
	var ac := c - a
	if absf(denom) <= 0.0001:
		return _point_segment_distance(a, c, d) <= 0.01 \
			or _point_segment_distance(b, c, d) <= 0.01 \
			or _point_segment_distance(c, a, b) <= 0.01 \
			or _point_segment_distance(d, a, b) <= 0.01
	var t := _cross(ac, cd) / denom
	var u := _cross(ac, ab) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


func _release(owner: Object) -> void:
	# Restore the boss to its exact captured origin and drop the freeze /
	# ownership flag, then fully reset. Requires the owner; the deferred
	# path in update() guarantees this only runs with a non-null owner.
	if owner != null and _owns_boss:
		owner.set("boss_pos", _boss_original_center - _boss_size * 0.5)
		owner.set("lingpet_puppet_grab_active", false)
	_owns_boss = false
	_pending_owner_grab = false
	reset()


func _clear_visuals() -> void:
	_hearts.clear()
	_heart_spawn_accum = 0.0
	_sparkles.clear()
	_sparkle_spawn_accum = 0.0


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
		_hearts.append(LingpetPuppetGrabPayloadFactory.build_heart(_kiss_center, HEART_LIFE_SECONDS))


func _update_sparkles(delta: float) -> void:
	for sp in _sparkles:
		sp["life"] = float(sp.get("life", 0.0)) - delta
	var i := _sparkles.size() - 1
	while i >= 0:
		if float(_sparkles[i].get("life", 0.0)) <= 0.0:
			_sparkles.remove_at(i)
		i -= 1
	if _phase != PHASE_KISSING:
		return
	_sparkle_spawn_accum += delta
	while _sparkle_spawn_accum >= SPARKLE_SPAWN_INTERVAL and _sparkles.size() < SPARKLE_MAX:
		_sparkle_spawn_accum -= SPARKLE_SPAWN_INTERVAL
		_sparkles.append(LingpetPuppetGrabPayloadFactory.build_sparkle(_kiss_center, SPARKLE_LIFE_SECONDS))


func is_active() -> bool:
	return _active


func has_visible_effects() -> bool:
	return _active or not _hearts.is_empty() or not _sparkles.is_empty()


func has_companion_position_override() -> bool:
	return _active


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _cast_pos if _active else fallback


func get_companion_cast_pose_progress() -> float:
	if not _active:
		return -1.0
	match _phase:
		PHASE_EXTENDING:
			var extend_ratio := clampf(_phase_timer / EXTEND_SECONDS, 0.0, 1.0)
			return lerpf(0.0, COMPANION_CAST_EXTEND_PROGRESS_MAX, extend_ratio)
		PHASE_MISSING, PHASE_RETRY_WAIT:
			return COMPANION_CAST_EXTEND_PROGRESS_MAX
		PHASE_PULLING:
			var pull_ratio := clampf(_phase_timer / PULL_SECONDS, 0.0, 1.0)
			return lerpf(COMPANION_CAST_PULL_PROGRESS_START, COMPANION_CAST_PULL_PROGRESS_END, pull_ratio)
	return -1.0


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
		"puppet_grab_return_start_center": _return_start_center,
		"puppet_grab_cast_pos": _cast_pos,
		"puppet_grab_cut_by_ball": _cut_by_ball,
		"puppet_grab_cut_count": _cut_count,
		"puppet_grab_cut_point": _cut_point,
		"puppet_grab_companion_override_active": has_companion_position_override(),
		"puppet_grab_owns_boss": _owns_boss,
		"puppet_grab_pending_owner": _pending_owner_grab,
		"puppet_grab_grab_count": _grab_count,
		"puppet_grab_kiss_count": _kiss_count,
		"puppet_grab_heart_count": _hearts.size(),
		"puppet_grab_sparkle_count": _sparkles.size(),
		"puppet_grab_missed": _missed,
		"puppet_grab_miss_count": _miss_count,
		"puppet_grab_shot_count": _shot_count,
		"puppet_grab_retry_count": _retry_count,
		"puppet_grab_retries_remaining": _retries_remaining,
		"puppet_grab_active_skill_level": _active_skill_level,
		"puppet_grab_retry_rolls_queued": _retry_roll_queue_for_tests.size(),
		"puppet_grab_predicted_target": _predicted_target_center,
		"puppet_grab_hit_tolerance": hit_tolerance(),
		"puppet_grab_phase_missing": PHASE_MISSING,
		"puppet_grab_phase_retry_wait": PHASE_RETRY_WAIT,
		"puppet_grab_extend_seconds": EXTEND_SECONDS,
		"puppet_grab_pull_seconds": PULL_SECONDS,
		"puppet_grab_kiss_seconds": KISS_SECONDS,
		"puppet_grab_return_seconds": RETURN_SECONDS,
		"puppet_grab_miss_seconds": MISS_SECONDS,
		"puppet_grab_retry_delay_seconds": RETRY_DELAY_SECONDS,
		"puppet_grab_retry_chance_pct": RETRY_CHANCE_PCT,
		"puppet_grab_rope_cut_radius_pad": ROPE_CUT_BALL_RADIUS_PAD,
		"puppet_grab_rope_cut_arming_seconds": ROPE_CUT_ARMING_SECONDS,
		"puppet_grab_companion_cast_pose_progress": get_companion_cast_pose_progress(),
		"puppet_grab_total_seconds": TOTAL_SECONDS,
		"puppet_grab_kiss_front_offset": KISS_FRONT_OFFSET,
	}


func get_miss_count_for_tests() -> int:
	return _miss_count


func is_missed_for_tests() -> bool:
	return _missed


func get_string_visual_lateral_radius_for_tests(path_progress: float, extend_ratio: float = 1.0) -> float:
	var t := clampf(path_progress, 0.0, 1.0)
	var focus := _string_tip_focus(t)
	var max_offset := 20.0 * (1.0 - t * 0.6)
	var max_wave := STRING_WAVE_AMPLITUDE * (1.0 - t * 0.5) * clampf(extend_ratio, 0.0, 1.0)
	return (max_offset + max_wave) * focus


func set_retry_roll_queue_for_tests(values: Array) -> void:
	_retry_roll_queue_for_tests.clear()
	for value in values:
		_retry_roll_queue_for_tests.append(bool(value))


func _is_miss_feedback_phase() -> bool:
	return _phase == PHASE_MISSING or _phase == PHASE_RETRY_WAIT


func _miss_feedback_progress() -> float:
	return clampf(minf(_phase_timer, MISS_SECONDS) / MISS_SECONDS, 0.0, 1.0)


func _miss_feedback_fade() -> float:
	return 1.0 - _miss_feedback_progress()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _active:
		_draw_strings(canvas, shake_offset)
		if _phase == PHASE_PULLING:
			_draw_pull_tension(canvas, shake_offset)
		_draw_hand(canvas, shake_offset)
		if _phase == PHASE_KISSING:
			_draw_chu_text(canvas, shake_offset)
		if _cut_by_ball and _phase == PHASE_RETURNING:
			_draw_cut_text(canvas, shake_offset)
		if _is_miss_feedback_phase():
			_draw_miss_text(canvas, shake_offset)
	if not _sparkles.is_empty():
		_draw_sparkles(canvas, shake_offset)
	if not _hearts.is_empty():
		_draw_hearts(canvas, shake_offset)


func _compute_string_tip(hand: Vector2, shake_offset: Vector2) -> Vector2:
	# The visible string TIP is decoupled from `_boss_draw_center`. During
	# EXTENDING the strings race outward toward the snapshot lock-on point
	# (fast-out cubic easing) — this is what makes the strings actually look
	# like they're being thrown, instead of snapping to the boss instantly.
	# During MISSING the same tip retracts back to the hand.
	match _phase:
		PHASE_EXTENDING:
			var p: float = clampf(_phase_timer / EXTEND_SECONDS, 0.0, 1.0)
			var eased: float = 1.0 - pow(1.0 - p, 3.0)  # ease-out cubic: quick start, settled finish
			return hand.lerp(_predicted_target_center + shake_offset, eased)
		PHASE_MISSING, PHASE_RETRY_WAIT:
			var rp: float = _miss_feedback_fade()
			return hand.lerp(_predicted_target_center + shake_offset, rp)
		_:
			return _boss_draw_center + shake_offset


func _draw_strings(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var hand: Vector2 = _cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	var tip: Vector2 = _compute_string_tip(hand, shake_offset)
	var kissing := _phase == PHASE_KISSING or _phase == PHASE_RETURNING
	# Mirror the original PuppetControl 분홍-보라 그라데이션:
	#   pre-kiss  (180, 100, 150)  → kiss  (255, 150, 180)
	# MISS path overrides to a fading red so the failure reads instantly.
	var base_color: Color
	if _is_miss_feedback_phase():
		var miss_fade: float = _miss_feedback_fade()
		base_color = Color(0.85, 0.30, 0.40, 0.85 * miss_fade)
	elif kissing:
		base_color = Color(1.0, 0.588, 0.706, 0.9)
	else:
		base_color = Color(0.706, 0.392, 0.588, 0.85)
	var axis: Vector2 = tip - hand
	var length: float = axis.length()
	if length < 1.0:
		return
	if _cut_by_ball and _phase == PHASE_RETURNING:
		_draw_cut_strings(canvas, hand, tip, base_color)
		return
	var perp: Vector2 = Vector2(-axis.y, axis.x).normalized()
	# Strings reach their full wave only once they've extended; during EXTENDING
	# the wave is suppressed proportionally to extend progress so the strings
	# read as taut/quiet at launch and lazy/dangling by arrival.
	var extend_ratio: float = 1.0
	if _phase == PHASE_EXTENDING:
		extend_ratio = clampf(_phase_timer / EXTEND_SECONDS, 0.0, 1.0)
	for s in range(STRING_COUNT):
		var offset: float = -20.0 + float(s) * 10.0
		var phase_seed: float = float(s) * 1.31 + _anim_time * STRING_WAVE_SPEED
		var points := PackedVector2Array()
		for seg in range(STRING_SEGMENTS + 1):
			var t: float = float(seg) / float(STRING_SEGMENTS)
			var along: Vector2 = hand.lerp(tip, t)
			# Original taper: (1 - prog * 0.5) — full wave at the hand, half at the boss.
			# Lazy dangling string feel, NOT a vibrating midpoint.
			var taper: float = 1.0 - t * 0.5
			var wave: float = sin(phase_seed + t * PI * 3.0) * STRING_WAVE_AMPLITUDE * taper * extend_ratio
			var tip_focus := _string_tip_focus(t)
			along += perp * ((offset * (1.0 - t * 0.6) + wave) * tip_focus)
			points.append(along)
		canvas.draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.85), 2.0, true)


func _draw_cut_strings(canvas: CanvasItem, hand: Vector2, tip: Vector2, base_color: Color) -> void:
	var axis := tip - hand
	var length := axis.length()
	if length < 1.0:
		return
	var dir := axis / length
	var perp := Vector2(-dir.y, dir.x)
	var break_point := _cut_point
	if break_point == Vector2.ZERO:
		break_point = hand.lerp(tip, 0.5)
	else:
		break_point += hand - _get_rope_hand()
	var local_break := _closest_point_on_segment(break_point, hand, tip)
	var left_end := _closest_point_on_segment(local_break - dir * ROPE_CUT_GAP, hand, tip)
	var right_start := _closest_point_on_segment(local_break + dir * ROPE_CUT_GAP, hand, tip)
	var fade := 1.0 - clampf(_phase_timer / RETURN_SECONDS, 0.0, 1.0) * 0.55
	for s in range(STRING_COUNT):
		var offset: float = -20.0 + float(s) * 10.0
		var flutter: float = sin(_anim_time * 13.0 + float(s) * 1.9) * 5.0
		var string_offset := perp * (offset * 0.32)
		var tear_offset := perp * (flutter + offset * 0.08)
		canvas.draw_line(
			hand + string_offset,
			left_end + tear_offset,
			Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.75 * fade),
			2.0,
			true
		)
		canvas.draw_line(
			tip + string_offset,
			right_start - tear_offset,
			Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.75 * fade),
			2.0,
			true
		)
		canvas.draw_line(
			left_end + tear_offset,
			left_end + tear_offset + perp * randf_range(-4.0, 4.0) - dir * randf_range(3.0, 8.0),
			Color(1.0, 0.78, 0.88, 0.55 * fade),
			1.0,
			true
		)


func _string_tip_focus(t: float) -> float:
	var progress := clampf((t - STRING_TIP_FOCUS_START) / maxf(0.001, 1.0 - STRING_TIP_FOCUS_START), 0.0, 1.0)
	var eased := pow(progress, STRING_TIP_FOCUS_POWER)
	return clampf(1.0 - eased, 0.0, 1.0)


func _draw_miss_text(canvas: CanvasItem, shake_offset: Vector2) -> void:
	# "MISS" reads where the strings landed (the predicted lock-on point that
	# the boss successfully dodged), drifting upward and fading out.
	var anchor: Vector2 = _predicted_target_center + MISS_OFFSET + shake_offset
	anchor.y -= MISS_FLOAT_UP_SPEED * _phase_timer
	var fade: float = _miss_feedback_fade()
	var alpha: float = 0.95 * fade
	# Drop shadow for legibility against busy backgrounds.
	canvas.draw_string(
		CHU_FONT,
		anchor + Vector2(2.0, 2.0),
		MISS_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MISS_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.6 * fade),
	)
	canvas.draw_string(
		CHU_FONT,
		anchor,
		MISS_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MISS_FONT_SIZE,
		Color(1.0, 0.27, 0.32, alpha),
	)


func _draw_cut_text(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var anchor := (_cut_point if _cut_point != Vector2.ZERO else _boss_draw_center) + CUT_OFFSET + shake_offset
	var fade := 1.0 - clampf(_phase_timer / RETURN_SECONDS, 0.0, 1.0)
	var alpha := 0.95 * fade
	canvas.draw_string(
		CHU_FONT,
		anchor + Vector2(2.0, 2.0),
		CUT_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CUT_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.58 * fade),
	)
	canvas.draw_string(
		CHU_FONT,
		anchor,
		CUT_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CUT_FONT_SIZE,
		Color(1.0, 0.82, 0.92, alpha),
	)


func _draw_pull_tension(canvas: CanvasItem, shake_offset: Vector2) -> void:
	# Original: 3 random radial tension lines from the midpoint of hand→boss while
	# pulling, faint pink (255, 200, 220, ~100/255).
	var hand: Vector2 = _cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	var tip: Vector2 = _boss_draw_center + shake_offset
	var center: Vector2 = hand.lerp(tip, 0.5)
	var color := Color(1.0, 0.784, 0.863, 0.4)
	for _i in range(PULL_TENSION_LINE_COUNT):
		var angle: float = randf_range(0.0, TAU)
		var line_len: float = randf_range(PULL_TENSION_LINE_MIN, PULL_TENSION_LINE_MAX)
		var endp: Vector2 = center + Vector2(cos(angle), sin(angle)) * line_len
		canvas.draw_line(center, endp, color, 1.0, true)


func _draw_hand(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var hand: Vector2 = _cast_pos + Vector2(0.0, HAND_OFFSET_Y) + shake_offset
	# Original 손 잡는 곳: outer (150, 80, 120) r=8, inner (200, 120, 160) r=5.
	canvas.draw_circle(hand, 8.0, Color(0.588, 0.314, 0.471, 0.85))
	canvas.draw_circle(hand, 5.0, Color(0.784, 0.471, 0.627, 0.95))


func _draw_sparkles(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for sp in _sparkles:
		var life_ratio: float = clampf(float(sp.get("life", 0.0)) / SPARKLE_LIFE_SECONDS, 0.0, 1.0)
		var pos: Vector2 = sp.get("pos", Vector2.ZERO) + shake_offset
		var size: float = float(sp.get("size", 3.0))
		# Original 반짝이 색: 옅은 노란 (255, 255, 200), 알파는 life_ratio.
		canvas.draw_circle(pos, size, Color(1.0, 1.0, 0.784, life_ratio))


func _draw_chu_text(canvas: CanvasItem, shake_offset: Vector2) -> void:
	# Original "CHU~" 텍스트 효과: pink-yellow (255, 150, 200), 작은 폰트, 키스 중 표시.
	# Position: 키스 지점 옆 (offset right + up toward Koyora side).
	var anchor: Vector2 = _kiss_center + CHU_OFFSET + shake_offset
	# Soft fade-in for the first ~150ms of the kiss so it doesn't pop hard.
	var fade: float = clampf(_phase_timer / 0.18, 0.0, 1.0)
	var alpha: float = 0.95 * fade
	# Drop shadow for legibility against busy scene.
	canvas.draw_string(
		CHU_FONT,
		anchor + Vector2(2.0, 2.0),
		CHU_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CHU_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.5 * fade),
	)
	canvas.draw_string(
		CHU_FONT,
		anchor,
		CHU_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CHU_FONT_SIZE,
		Color(1.0, 0.588, 0.784, alpha),
	)


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


func _play_audio(registry: Object, method_name: String) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method(method_name):
		audio.call(method_name)
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


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


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback
