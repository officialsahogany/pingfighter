extends RefCounted

# 건곤환문을 완전히 통과한 뒤 2초 동안 이동 경로에 남는 1회용 방어 잔상.
# 샘플은 짧게 유지하며 계속 뒤에 놓이므로 화면 전체를 영구 판정으로 덮지 않는다.

const ACTIVE_DURATION_MSEC := 2000
const SAMPLE_INTERVAL_MSEC := 150
const SAMPLE_LIFETIME_MSEC := ACTIVE_DURATION_MSEC
const WINDOW_FADE_OUT_MSEC := 260
const SMOKE_LIFETIME_MSEC := 460
const MAX_SAMPLES := 12
const MAX_SMOKE_PUFFS := 14
const MIN_SAMPLE_DISTANCE := 5.0
const COLLISION_WIDTH_SCALE := 0.92
const DASH_SAMPLE_SPACING := 28.0
const DASH_SAMPLE_AGE_STEP_MSEC := 24
const DASH_PORTAL_SAMPLE_AGE_MSEC := 40

var _active_until_msec := 0
var _last_update_msec := 0
var _last_sample_msec := -1
var _sample_anchor_pos := Vector2.ZERO
var _sample_anchor_size := Vector2(155.0, 50.0)
var _hit_available := false
var _next_sample_id := 1
var _samples: Array[Dictionary] = []
var _collision_entries: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []


func reset() -> void:
	_active_until_msec = 0
	_last_update_msec = 0
	_last_sample_msec = -1
	_sample_anchor_pos = Vector2.ZERO
	_sample_anchor_size = Vector2(155.0, 50.0)
	_hit_available = false
	_next_sample_id = 1
	_samples.clear()
	_collision_entries.clear()
	_smoke_puffs.clear()


func start(current_msec: int, player_pos: Vector2, paddle_size: Vector2) -> void:
	_begin_window(current_msec, player_pos, paddle_size)
	_append_sample(current_msec, player_pos, _sample_anchor_size)
	_rebuild_collision_entries()


func start_from_wrap(
	current_msec: int,
	player_pos: Vector2,
	paddle_size: Vector2,
	motion_start_pos: Vector2,
	field_width: float,
	deps: Dictionary
) -> void:
	if not _is_dash_motion_active(deps):
		start(current_msec, player_pos, paddle_size)
		return

	_begin_window(current_msec, player_pos, paddle_size)
	var max_player_x: float = maxf(0.0, field_width - _sample_anchor_size.x)
	var dash_start := Vector2(clampf(motion_start_pos.x, 0.0, max_player_x), player_pos.y)
	var entry_x: float = max_player_x if player_pos.x < field_width * 0.5 else 0.0
	var entry_pos := Vector2(entry_x, player_pos.y)
	_append_sample(current_msec - DASH_PORTAL_SAMPLE_AGE_MSEC * 2, dash_start, _sample_anchor_size)
	_append_sample(current_msec - DASH_PORTAL_SAMPLE_AGE_MSEC, entry_pos, _sample_anchor_size)
	_append_sample(current_msec, player_pos, _sample_anchor_size)
	_rebuild_collision_entries()


func _begin_window(current_msec: int, player_pos: Vector2, paddle_size: Vector2) -> void:
	_last_update_msec = current_msec
	_active_until_msec = current_msec + ACTIVE_DURATION_MSEC
	_last_sample_msec = current_msec
	_sample_anchor_pos = player_pos
	_sample_anchor_size = _sanitize_size(paddle_size)
	_hit_available = true
	# 재통과는 기존 궤적을 교체한다. 여러 줄의 방어 판정은 중첩하지 않는다.
	_samples.clear()
	_collision_entries.clear()


func update(current_msec: int, player_pos: Vector2, paddle_size: Vector2, dash_snapshot: Variant = {}) -> void:
	_last_update_msec = current_msec
	_update_smoke(current_msec)
	_update_samples(current_msec)

	if _hit_available and current_msec >= _active_until_msec:
		_hit_available = false

	if _hit_available and current_msec < _active_until_msec:
		var next_size: Vector2 = _sanitize_size(paddle_size)
		if _last_sample_msec < 0:
			_last_sample_msec = current_msec
			_sample_anchor_pos = player_pos
			_sample_anchor_size = next_size
		elif _is_dash_snapshot_active(dash_snapshot):
			_append_dash_motion_samples(current_msec, player_pos, next_size)
		elif current_msec - _last_sample_msec >= SAMPLE_INTERVAL_MSEC:
			if player_pos.distance_to(_sample_anchor_pos) >= MIN_SAMPLE_DISTANCE:
				_append_sample(current_msec, _sample_anchor_pos, _sample_anchor_size)
			_sample_anchor_pos = player_pos
			_sample_anchor_size = next_size
			_last_sample_msec = current_msec

	_rebuild_collision_entries()


func _append_dash_motion_samples(current_msec: int, player_pos: Vector2, paddle_size: Vector2) -> void:
	var displacement: Vector2 = player_pos - _sample_anchor_pos
	var distance: float = displacement.length()
	if distance < DASH_SAMPLE_SPACING:
		return
	var direction: Vector2 = displacement / distance
	var step_count: int = mini(MAX_SAMPLES, int(floor(distance / DASH_SAMPLE_SPACING)))
	var previous_sample_msec: int = _last_sample_msec
	for step_index in range(step_count):
		var sample_pos: Vector2 = _sample_anchor_pos + direction * DASH_SAMPLE_SPACING * float(step_index + 1)
		var sample_msec: int = maxi(
			previous_sample_msec,
			current_msec - (step_count - step_index - 1) * DASH_SAMPLE_AGE_STEP_MSEC
		)
		_append_sample(sample_msec, sample_pos, paddle_size)
		previous_sample_msec = sample_msec
	_sample_anchor_pos += direction * DASH_SAMPLE_SPACING * float(step_count)
	_sample_anchor_size = paddle_size
	_last_sample_msec = current_msec


func _is_dash_motion_active(deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return false
	if dash_state.has_method("is_active") and bool(dash_state.is_active()):
		return true
	if dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
		return true
	if dash_state.has_method("get_snapshot"):
		return _is_dash_snapshot_active(dash_state.get_snapshot())
	return false


func _is_dash_snapshot_active(value: Variant) -> bool:
	return value is Dictionary and bool((value as Dictionary).get("active", false))


func shift_time(delta_msec: int) -> void:
	if delta_msec <= 0:
		return
	if _active_until_msec > 0:
		_active_until_msec += delta_msec
	if _last_update_msec > 0:
		_last_update_msec += delta_msec
	if _last_sample_msec >= 0:
		_last_sample_msec += delta_msec
	_shift_entry_times(_samples, delta_msec)
	_shift_entry_times(_smoke_puffs, delta_msec)


func has_visible_effects() -> bool:
	return not _samples.is_empty() or not _smoke_puffs.is_empty()


func needs_update() -> bool:
	return _hit_available or has_visible_effects()


func get_actor_draw_context() -> Dictionary:
	return {
		"warp_gate_afterimage_samples": _samples,
		"warp_gate_afterimage_active": _hit_available,
	}


func get_ball_collision_context() -> Dictionary:
	return {
		"warp_gate_afterimage_rects": _collision_entries if _hit_available else [],
		"warp_gate_afterimage_time_msec": _last_update_msec,
	}


func get_smoke_puffs() -> Array[Dictionary]:
	return _smoke_puffs


func consume_hit(sample_id: int, impact_pos: Vector2, current_msec: int) -> bool:
	if not _hit_available:
		return false
	var matched := false
	for sample in _samples:
		if int(sample.get("id", -1)) == sample_id:
			matched = true
			break
	if not matched:
		return false

	if current_msec < 0:
		current_msec = _last_update_msec
	_last_update_msec = current_msec
	_hit_available = false
	_active_until_msec = current_msec
	_spawn_smoke_for_samples(current_msec, impact_pos)
	_samples.clear()
	_collision_entries.clear()
	return true


func is_hit_available() -> bool:
	return _hit_available


func get_sample_count() -> int:
	return _samples.size()


func get_collision_entries_for_tests() -> Array[Dictionary]:
	return _collision_entries


func get_active_until_msec() -> int:
	return _active_until_msec


func _append_sample(current_msec: int, player_pos: Vector2, paddle_size: Vector2) -> void:
	if not _samples.is_empty():
		var latest_pos: Vector2 = _as_vector2(_samples.back().get("player_pos", player_pos), player_pos)
		if latest_pos.distance_to(player_pos) < MIN_SAMPLE_DISTANCE:
			return
	_samples.append({
		"id": _next_sample_id,
		"player_pos": player_pos,
		"paddle_size": paddle_size,
		"spawn_msec": current_msec,
		"alpha": 0.56,
		"scale": 1.0,
	})
	_next_sample_id += 1
	while _samples.size() > MAX_SAMPLES:
		_samples.pop_front()


func _update_samples(current_msec: int) -> void:
	if _active_until_msec > 0 and current_msec >= _active_until_msec:
		_samples.clear()
		return
	var window_fade: float = clamp(
		float(_active_until_msec - current_msec) / float(WINDOW_FADE_OUT_MSEC),
		0.0,
		1.0
	)
	var write_index := 0
	for read_index in range(_samples.size()):
		var sample: Dictionary = _samples[read_index]
		var age_msec: int = max(0, current_msec - int(sample.get("spawn_msec", current_msec)))
		if age_msec >= SAMPLE_LIFETIME_MSEC:
			continue
		var life_ratio: float = clamp(float(age_msec) / float(SAMPLE_LIFETIME_MSEC), 0.0, 1.0)
		# 오래된 꼬리부터 투명해지고 조금씩 수축한다.
		sample["alpha"] = 0.56 * pow(1.0 - life_ratio, 1.35) * window_fade
		sample["scale"] = lerp(1.0, 0.88, life_ratio)
		_samples[write_index] = sample
		write_index += 1
	if write_index < _samples.size():
		_samples.resize(write_index)


func _rebuild_collision_entries() -> void:
	_collision_entries.clear()
	if not _hit_available:
		return
	for sample in _samples:
		var pos: Vector2 = _as_vector2(sample.get("player_pos", Vector2.ZERO), Vector2.ZERO)
		var size: Vector2 = _sanitize_size(_as_vector2(sample.get("paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0)))
		var collision_width: float = size.x * COLLISION_WIDTH_SCALE
		var collision_pos := Vector2(pos.x + (size.x - collision_width) * 0.5, pos.y)
		_collision_entries.append({
			"id": int(sample.get("id", -1)),
			"rect": Rect2(collision_pos, Vector2(collision_width, size.y)),
		})


func _spawn_smoke_for_samples(current_msec: int, impact_pos: Vector2) -> void:
	for sample in _samples:
		var pos: Vector2 = _as_vector2(sample.get("player_pos", impact_pos), impact_pos)
		var size: Vector2 = _sanitize_size(_as_vector2(sample.get("paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0)))
		_smoke_puffs.append({
			"center": pos + size * 0.5,
			"spawn_msec": current_msec,
			"life_msec": SMOKE_LIFETIME_MSEC,
			"seed": int(sample.get("id", 0)),
			"size": size,
		})
	_smoke_puffs.append({
		"center": impact_pos,
		"spawn_msec": current_msec,
		"life_msec": SMOKE_LIFETIME_MSEC,
		"seed": _next_sample_id + 97,
		"size": Vector2(72.0, 44.0),
	})
	while _smoke_puffs.size() > MAX_SMOKE_PUFFS:
		_smoke_puffs.pop_front()


func _update_smoke(current_msec: int) -> void:
	var write_index := 0
	for read_index in range(_smoke_puffs.size()):
		var puff: Dictionary = _smoke_puffs[read_index]
		var life_msec: int = max(1, int(puff.get("life_msec", SMOKE_LIFETIME_MSEC)))
		if current_msec - int(puff.get("spawn_msec", current_msec)) >= life_msec:
			continue
		_smoke_puffs[write_index] = puff
		write_index += 1
	if write_index < _smoke_puffs.size():
		_smoke_puffs.resize(write_index)


func _shift_entry_times(entries: Array[Dictionary], delta_msec: int) -> void:
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		entry["spawn_msec"] = int(entry.get("spawn_msec", 0)) + delta_msec
		entries[index] = entry


func _sanitize_size(value: Vector2) -> Vector2:
	return Vector2(max(1.0, value.x), max(1.0, value.y))


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
