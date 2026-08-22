extends RefCounted

const LEGACY_FPS := 60.0
const FIELD_WIDTH := 760.0
const GAUGE_COST := 100.0
const TRIGGER_CHANCE := 0.25
const CAST_SEC := 0.50
const EMERGE_SEC := 0.60
const DURATION_SEC := 10.0
const COOLDOWN_SEC := 8.0
const INITIAL_COOLDOWN_SEC := COOLDOWN_SEC
const INVULN_BUFFER_SEC := 0.60
const DEATH_SEC := 0.70
const FADE_SEC := 1.50
const SIZE := Vector2(110.0, 96.0)
const WALL_MARGIN := 10.0
const INITIAL_SPEED_MIN_PER_FRAME := 7.5
const INITIAL_SPEED_MAX_PER_FRAME := 12.0
const SPEED_MAX_PER_FRAME := 15.0
const ACCEL_JITTER_PER_FRAME := 0.6
const MAX_ENTITIES := 8
const TEMP_GOLDEN_CHANCE := 0.50
const TEMP_GOLDEN_MUHON_DROPS := 1

var casting := false
var cast_elapsed_sec := 0.0
var cooldown_remaining_sec := INITIAL_COOLDOWN_SEC
var invuln_buffer_remaining_sec := 0.0
var cast_boss_pos := Vector2.ZERO
var cast_boss_center := Vector2.ZERO
var cast_free := false
var cast_source := ""
var next_id := 1
var entities: Array = []


func reset_full() -> void:
	clear_round_transients()
	cooldown_remaining_sec = INITIAL_COOLDOWN_SEC


func clear_round_transients() -> void:
	entities.clear()
	cancel_cast()
	next_id = 1


func cancel_cast() -> void:
	casting = false
	cast_elapsed_sec = 0.0
	cast_boss_pos = Vector2.ZERO
	cast_boss_center = Vector2.ZERO
	cast_free = false
	cast_source = ""
	invuln_buffer_remaining_sec = 0.0


func has_runtime_state() -> bool:
	return (
		casting
		or cooldown_remaining_sec > 0.0
		or invuln_buffer_remaining_sec > 0.0
		or not entities.is_empty()
	)


func set_cooldown_remaining(value: float) -> void:
	cooldown_remaining_sec = maxf(0.0, value)


func tick_cooldown(delta: float) -> void:
	cooldown_remaining_sec = maxf(0.0, cooldown_remaining_sec - delta)


func update_invulnerability(delta: float) -> void:
	if casting:
		return
	invuln_buffer_remaining_sec = maxf(0.0, invuln_buffer_remaining_sec - delta)
	if invuln_buffer_remaining_sec <= 0.000001:
		invuln_buffer_remaining_sec = 0.0


func is_boss_intangible() -> bool:
	return casting or invuln_buffer_remaining_sec > 0.0


func get_snapshot() -> Dictionary:
	var golden_vector: Array[bool] = []
	for clone_value in entities:
		var clone: Dictionary = clone_value if clone_value is Dictionary else {}
		golden_vector.append(bool(clone.get("golden", false)))
	return {
		"trigger_chance": TRIGGER_CHANCE,
		"golden_chance": TEMP_GOLDEN_CHANCE,
		"golden_muhon_drops": TEMP_GOLDEN_MUHON_DROPS,
		"max_entities": MAX_ENTITIES,
		"casting": casting,
		"cast_elapsed_sec": cast_elapsed_sec,
		"cast_free": cast_free,
		"cast_source": cast_source,
		"cooldown_remaining_sec": cooldown_remaining_sec,
		"invuln_buffer_remaining_sec": invuln_buffer_remaining_sec,
		"live_count": get_live_count(),
		"dying_count": get_dying_count(),
		"entity_count": entities.size(),
		"golden_vector": golden_vector,
	}


func build_hud_skill(boss_gauge: float, skill_paused: bool, blocked_by_other_skill: bool) -> Dictionary:
	var live_count: int = get_live_count()
	var ready: bool = (
		not skill_paused
		and cooldown_remaining_sec <= 0.0
		and boss_gauge >= GAUGE_COST
		and not casting
		and live_count == 0
		and not blocked_by_other_skill
	)
	var next_activation_remaining: float = maxf(
		cooldown_remaining_sec,
		maxf(get_max_live_remaining_sec(), maxf(0.0, GAUGE_COST - boss_gauge))
	)
	var clone_status := "charging"
	if live_count > 0:
		clone_status = "active"
	elif skill_paused:
		clone_status = "paused"
	elif casting:
		clone_status = "casting"
	elif ready:
		clone_status = "ready"
	return {
		"id": "stage7_clone",
		"name": "그림자분신",
		"color": Color(0.56, 0.48, 0.86),
		"cost": GAUGE_COST,
		"progress": clampf(1.0 - cooldown_remaining_sec / COOLDOWN_SEC, 0.0, 1.0),
		"cooldown_remaining": cooldown_remaining_sec,
		"cooldown_total": COOLDOWN_SEC,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"next_activation_remaining": next_activation_remaining,
		"ready": ready,
		"active": live_count > 0 or (casting and not skill_paused),
		"active_count": live_count,
		"implemented": true,
		"status": clone_status,
	}


func try_start_cast(
	context: Dictionary,
	boss_gauge: float,
	force_roll: bool,
	free_cast: bool,
	source: String,
	bypass_cooldown: bool,
	blocked_by_other_skill: bool,
	rng: RandomNumberGenerator
) -> bool:
	if (
		casting
		or get_live_count() > 0
		or blocked_by_other_skill
		or (not bypass_cooldown and cooldown_remaining_sec > 0.0)
		or (not free_cast and boss_gauge < GAUGE_COST)
	):
		return false
	if not force_roll and rng.randf() > TRIGGER_CHANCE:
		return false
	var boss_pos: Vector2 = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	var boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)),
		Vector2(100.0, 40.0)
	)
	casting = true
	cast_elapsed_sec = 0.0
	cast_boss_pos = boss_pos
	cast_boss_center = boss_pos + boss_size * 0.5
	cast_free = free_cast
	cast_source = source
	invuln_buffer_remaining_sec = 0.0
	return true


func advance_cast(
	delta: float,
	boss_gauge: float,
	spawn_awakened: bool,
	rng: RandomNumberGenerator,
	deps: Dictionary
) -> Dictionary:
	cast_elapsed_sec += delta
	if cast_elapsed_sec + 0.000001 < CAST_SEC:
		return {}
	if not cast_free and boss_gauge < GAUGE_COST:
		cancel_cast()
		return {"completed": true, "committed": false, "boss_gauge": boss_gauge}
	var next_gauge: float = boss_gauge
	if not cast_free:
		next_gauge = maxf(0.0, next_gauge - GAUGE_COST)
	var spawn_center: Vector2 = cast_boss_center
	casting = false
	cast_elapsed_sec = 0.0
	cast_boss_pos = Vector2.ZERO
	cast_boss_center = Vector2.ZERO
	cast_free = false
	cast_source = ""
	spawn_entities(spawn_center, spawn_awakened, rng)
	_play_audio(deps, &"play_stage7_akamu_clone_spawn")
	cooldown_remaining_sec = COOLDOWN_SEC
	invuln_buffer_remaining_sec = INVULN_BUFFER_SEC
	return {"completed": true, "committed": true, "boss_gauge": next_gauge}


func spawn_entities(center: Vector2, spawn_awakened: bool, rng: RandomNumberGenerator) -> void:
	var offsets: Array = (
		[-120.0, -60.0, 60.0, 120.0]
		if spawn_awakened
		else [-90.0, 90.0]
	)
	while entities.size() + offsets.size() > MAX_ENTITIES:
		var removable_index := -1
		for index in range(entities.size()):
			if str((entities[index] as Dictionary).get("phase", "")) == "dying":
				removable_index = index
				break
		if removable_index < 0:
			break
		entities.remove_at(removable_index)
	for offset in offsets:
		if entities.size() >= MAX_ENTITIES:
			break
		var direction: float = -1.0 if offset < 0.0 else 1.0
		var entity_id: int = next_id
		next_id += 1
		var velocity_x: float = rng.randf_range(
			INITIAL_SPEED_MIN_PER_FRAME,
			INITIAL_SPEED_MAX_PER_FRAME
		) * direction
		var motion_noise_state: int = rng.randi_range(1, 2147483646)
		# Reward-bearing randomness belongs to the authoritative stream and is
		# consumed exactly once, last in this entity block. Existing movement
		# parameters therefore retain their pre-golden first-entity baseline.
		var golden: bool = rng.randf() < TEMP_GOLDEN_CHANCE
		entities.append({
			"id": entity_id,
			"center": center,
			"spawn_center": center,
			"size": SIZE,
			"offset_x": offset,
			"direction": direction,
			"velocity_x": velocity_x,
			"motion_noise_state": motion_noise_state,
			"golden": golden,
			"motion_frame_accumulator": 0.0,
			"age_sec": 0.0,
			"death_elapsed_sec": 0.0,
			"phase": "emerging",
			"emerge_progress": 0.0,
			"death_progress": 0.0,
			"alpha": 0.0,
			"hop_offset": 0.0,
		})


func update_entities(frame_scale: float, delta: float, deps: Dictionary) -> void:
	if entities.is_empty():
		return
	var write_index := 0
	for read_index in range(entities.size()):
		var clone: Dictionary = entities[read_index]
		if str(clone.get("phase", "")) == "dying":
			var death_elapsed: float = float(clone.get("death_elapsed_sec", 0.0)) + delta
			if death_elapsed >= DEATH_SEC:
				continue
			var death_progress: float = clampf(death_elapsed / DEATH_SEC, 0.0, 1.0)
			clone["death_elapsed_sec"] = death_elapsed
			clone["death_progress"] = death_progress
			clone["alpha"] = 0.78 * (1.0 - death_progress)
			entities[write_index] = clone
			write_index += 1
			continue

		var previous_age: float = float(clone.get("age_sec", 0.0))
		var age: float = previous_age + delta
		if age >= DURATION_SEC:
			_play_audio(deps, &"play_stage7_akamu_clone_out")
			continue
		clone["age_sec"] = age
		var emerge_progress: float = clampf(age / EMERGE_SEC, 0.0, 1.0)
		clone["emerge_progress"] = emerge_progress
		var spawn_center: Vector2 = _as_vector2(clone.get("spawn_center", Vector2.ZERO), Vector2.ZERO)
		var offset_x: float = float(clone.get("offset_x", 0.0))
		if age < EMERGE_SEC:
			clone["phase"] = "emerging"
			clone["center"] = spawn_center + Vector2(offset_x * emerge_progress, 0.0)
		else:
			clone["phase"] = "active"
			if previous_age < EMERGE_SEC:
				clone["center"] = spawn_center + Vector2(offset_x, 0.0)
			var active_frames: float = (
				frame_scale
				if previous_age >= EMERGE_SEC
				else maxf(0.0, age - EMERGE_SEC) * LEGACY_FPS
			)
			var accumulator: float = float(clone.get("motion_frame_accumulator", 0.0)) + active_frames
			while accumulator + 0.000001 >= 1.0:
				_advance_motion_tick(clone)
				accumulator -= 1.0
			clone["motion_frame_accumulator"] = maxf(0.0, accumulator)
		var remaining: float = DURATION_SEC - age
		var fade: float = clampf(remaining / FADE_SEC, 0.0, 1.0)
		clone["alpha"] = 0.78 * emerge_progress * fade
		clone["hop_offset"] = sin(age * 12.0 + float(int(clone.get("id", 0))) * 0.37) * 6.0
		entities[write_index] = clone
		write_index += 1
	if write_index < entities.size():
		entities.resize(write_index)


func get_live_count() -> int:
	var count := 0
	for clone_value in entities:
		if clone_value is Dictionary and str((clone_value as Dictionary).get("phase", "")) != "dying":
			count += 1
	return count


func get_dying_count() -> int:
	var count := 0
	for clone_value in entities:
		if clone_value is Dictionary and str((clone_value as Dictionary).get("phase", "")) == "dying":
			count += 1
	return count


func get_max_live_remaining_sec() -> float:
	var remaining := 0.0
	for clone_value in entities:
		if not (clone_value is Dictionary):
			continue
		var clone: Dictionary = clone_value
		if str(clone.get("phase", "")) == "dying":
			continue
		remaining = maxf(remaining, DURATION_SEC - float(clone.get("age_sec", 0.0)))
	return remaining


func query_ball_collision(from_pos: Vector2, to_pos: Vector2, ball_radius: float) -> Dictionary:
	var nearest_index := -1
	var nearest_point := Vector2.ZERO
	var nearest_distance_squared := INF
	for index in range(entities.size()):
		var clone: Dictionary = entities[index]
		if str(clone.get("phase", "")) == "dying":
			continue
		var expanded_rect: Rect2 = rect_for_entity(clone).grow(ball_radius)
		var hit_point: Variant = _get_segment_rect_hit_point(from_pos, to_pos, expanded_rect)
		if hit_point == null:
			continue
		var point: Vector2 = hit_point as Vector2
		var distance_squared: float = from_pos.distance_squared_to(point)
		if nearest_index < 0 or distance_squared < nearest_distance_squared:
			nearest_index = index
			nearest_point = point
			nearest_distance_squared = distance_squared
	if nearest_index < 0:
		return {}
	var nearest_clone: Dictionary = entities[nearest_index]
	var clone_rect: Rect2 = rect_for_entity(nearest_clone)
	return {
		"index": nearest_index,
		"point": nearest_point,
		"golden": bool(nearest_clone.get("golden", false)),
		"clone_rect": clone_rect,
		"clone_center": clone_rect.get_center(),
	}


func rect_for_index(index: int) -> Rect2:
	if index < 0 or index >= entities.size():
		return Rect2()
	return rect_for_entity(entities[index] as Dictionary)


func rect_for_entity(clone: Dictionary) -> Rect2:
	var center: Vector2 = _as_vector2(clone.get("center", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = _as_vector2(clone.get("size", SIZE), SIZE)
	return Rect2(center - size * 0.5, size)


func begin_dying(index: int, deps: Dictionary) -> void:
	if index < 0 or index >= entities.size():
		return
	var clone: Dictionary = entities[index]
	clone["phase"] = "dying"
	clone["death_elapsed_sec"] = 0.0
	clone["death_progress"] = 0.0
	clone["motion_frame_accumulator"] = 0.0
	clone["velocity_x"] = 0.0
	entities[index] = clone
	_play_audio(deps, &"play_stage7_akamu_clone_out")


func debug_set_golden(index: int, value: bool) -> bool:
	if index < 0 or index >= entities.size():
		return false
	var clone: Dictionary = entities[index]
	clone["golden"] = value
	entities[index] = clone
	return true


func _advance_motion_tick(clone: Dictionary) -> void:
	var center: Vector2 = _as_vector2(clone.get("center", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = _as_vector2(clone.get("size", SIZE), SIZE)
	var velocity_x: float = float(clone.get("velocity_x", 0.0))
	center.x += velocity_x
	var min_center_x: float = WALL_MARGIN + size.x * 0.5
	var max_center_x: float = FIELD_WIDTH - WALL_MARGIN - size.x * 0.5
	if center.x < min_center_x:
		center.x = min_center_x
		velocity_x = absf(velocity_x)
	elif center.x > max_center_x:
		center.x = max_center_x
		velocity_x = -absf(velocity_x)
	var noise_state: int = int(clone.get("motion_noise_state", 1))
	noise_state = int((1103515245 * noise_state + 12345) % 2147483647)
	var noise_unit: float = float(noise_state) / 2147483647.0
	velocity_x += lerpf(-ACCEL_JITTER_PER_FRAME, ACCEL_JITTER_PER_FRAME, noise_unit)
	velocity_x = clampf(velocity_x, -SPEED_MAX_PER_FRAME, SPEED_MAX_PER_FRAME)
	clone["center"] = center
	clone["velocity_x"] = velocity_x
	clone["motion_noise_state"] = noise_state


func _get_segment_rect_hit_point(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> Variant:
	if rect.has_point(from_pos):
		return from_pos
	var endpoint_inside: bool = rect.has_point(to_pos)
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var closest_point := Vector2.ZERO
	var closest_distance_squared := INF
	var found := false
	for index in range(corners.size()):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			from_pos,
			to_pos,
			corners[index],
			corners[(index + 1) % corners.size()]
		)
		if intersection == null:
			continue
		var point: Vector2 = intersection as Vector2
		var distance_squared: float = from_pos.distance_squared_to(point)
		if not found or distance_squared < closest_distance_squared:
			closest_point = point
			closest_distance_squared = distance_squared
			found = true
	if found:
		return closest_point
	return to_pos if endpoint_inside else null


func _play_audio(deps: Dictionary, method_name: StringName) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
