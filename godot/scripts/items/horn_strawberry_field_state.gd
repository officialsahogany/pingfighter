extends RefCounted

const GAUGE_COST := 100.0
const COOLDOWN_SEC := 10.0
const HOLD_MIN_SEC := 1.0
# Python-original live runtime (_StrawberryFieldSkillCore -> BoneBarrier): 120x12,
# 3.0s build, snapped to the paddle BOTTOM line. The module-level 180x12 / instant
# constants in item_effects/horn_strawberry_mask.py were dead code — do not port them.
const FIELD_WIDTH := 120.0
const FIELD_HEIGHT := 12.0
const BUILD_TIME_SEC := 3.0
const DEATH_TIME_SEC := 0.6
const REFLECT_SPEED_MULT := 1.05
const REFLECT_HIT_OFFSET_VEL_SCALE := 0.03
const FIELD_SOURCE := "horn_strawberry_field"

var holding := false
var hold_timer_sec := 0.0
var cooldown_sec := 0.0
var gauge_consumed := 0.0
var barriers: Array[Dictionary] = []
var last_reflect_count := 0
var _next_barrier_id := 1


func reset() -> void:
	holding = false
	hold_timer_sec = 0.0
	cooldown_sec = 0.0
	gauge_consumed = 0.0
	barriers.clear()
	last_reflect_count = 0


func update_input(input_snapshot: Dictionary, delta: float, owner: Object, runtime: Object, registry: Object = null) -> bool:
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	if down_pressed:
		if not holding:
			_start_hold()
		if holding:
			return _update_hold(max(0.0, delta), owner, runtime, registry)
	else:
		_release_hold()
	return false


func update(delta: float, transformed: bool) -> void:
	var safe_delta: float = max(0.0, delta)
	if transformed and not holding and _active_barrier_count() <= 0:
		cooldown_sec = max(0.0, cooldown_sec - safe_delta)
	if barriers.is_empty():
		return
	var alive: Array[Dictionary] = []
	for barrier in barriers:
		var next_barrier: Dictionary = barrier.duplicate(true)
		if bool(next_barrier.get("dying", false)):
			next_barrier["death_timer_sec"] = max(0.0, float(next_barrier.get("death_timer_sec", 0.0)) + safe_delta)
			if float(next_barrier.get("death_timer_sec", 0.0)) <= DEATH_TIME_SEC:
				alive.append(next_barrier)
			continue
		if bool(next_barrier.get("alive", false)) and not bool(next_barrier.get("built", false)):
			next_barrier["build_timer_sec"] = max(0.0, float(next_barrier.get("build_timer_sec", 0.0)) + safe_delta)
			if float(next_barrier.get("build_timer_sec", 0.0)) >= BUILD_TIME_SEC:
				next_barrier["built"] = true
		alive.append(next_barrier)
	barriers = alive


func get_ball_collision_context() -> Dictionary:
	# Python parity: a BUILDING barrier is also hittable — the ball destroys it
	# without reflecting (shurikenhit). Only BUILT barriers reflect.
	var entries: Array[Dictionary] = []
	for barrier in barriers:
		if bool(barrier.get("alive", false)) and not bool(barrier.get("dying", false)):
			entries.append({
				"id": int(barrier.get("id", 0)),
				"rect": _get_barrier_rect(barrier),
				"built": bool(barrier.get("built", false)),
				"reflect_speed_mult": REFLECT_SPEED_MULT,
				"hit_offset_vel_scale": REFLECT_HIT_OFFSET_VEL_SCALE,
			})
	return {
		"horn_strawberry_field_active": not entries.is_empty(),
		"horn_strawberry_field_barriers": entries,
	}


func notify_barrier_hit(barrier_id: int, was_built: bool = true) -> bool:
	for i in range(barriers.size()):
		var barrier: Dictionary = barriers[i]
		if int(barrier.get("id", 0)) != barrier_id:
			continue
		if not bool(barrier.get("alive", false)):
			return false
		barrier["alive"] = false
		barrier["dying"] = true
		barrier["death_timer_sec"] = 0.0
		barriers[i] = barrier
		if was_built:
			last_reflect_count += 1
		return true
	return false


func has_runtime_update_work() -> bool:
	return holding or cooldown_sec > 0.0 or not barriers.is_empty()


func has_visible_effects() -> bool:
	return holding or not barriers.is_empty()


func get_context() -> Dictionary:
	return {
		"holding": holding,
		"hold_timer_sec": hold_timer_sec,
		"hold_min_sec": HOLD_MIN_SEC,
		"cooldown_sec": cooldown_sec,
		"cooldown_max_sec": COOLDOWN_SEC,
		"gauge_cost": GAUGE_COST,
		"gauge_consumed": gauge_consumed,
		"field_width": FIELD_WIDTH,
		"field_height": FIELD_HEIGHT,
		"barriers": barriers.duplicate(true),
		"barrier_count": _active_barrier_count(),
		"last_reflect_count": last_reflect_count,
	}


func _start_hold() -> bool:
	if holding or cooldown_sec > 0.0 or _active_barrier_count() > 0:
		return false
	holding = true
	hold_timer_sec = 0.0
	gauge_consumed = 0.0
	return true


func _update_hold(delta: float, owner: Object, runtime: Object, registry: Object) -> bool:
	hold_timer_sec += delta
	var remaining_cost: float = max(0.0, GAUGE_COST - gauge_consumed)
	var consume_amount: float = min(GAUGE_COST / HOLD_MIN_SEC * delta, remaining_cost)
	if consume_amount > 0.0:
		var current_gauge: float = _get_owner_gauge(runtime, owner)
		if current_gauge + 0.001 < consume_amount:
			_cancel_hold()
			return false
		if owner != null:
			owner.set("special_gauge", max(0.0, current_gauge - consume_amount))
		gauge_consumed += consume_amount
	if hold_timer_sec + 0.001 < HOLD_MIN_SEC:
		return false
	holding = false
	cooldown_sec = COOLDOWN_SEC
	gauge_consumed = min(gauge_consumed, GAUGE_COST)
	_spawn_barrier(owner)
	_play_audio(runtime, registry, "_play_horn_strawberry_field_audio")
	return true


func _release_hold() -> void:
	if holding and hold_timer_sec < HOLD_MIN_SEC:
		_cancel_hold()


func _cancel_hold() -> void:
	holding = false
	hold_timer_sec = 0.0
	gauge_consumed = 0.0


func _spawn_barrier(owner: Object) -> void:
	# Python parity (_snap_latest_barrier_to_paddle): barrier top = paddle BOTTOM —
	# it is a last-line floor guard behind the paddle, not a shield above it.
	var player_pos: Vector2 = _get_player_pos(owner)
	var paddle_width: float = max(1.0, _get_owner_float(owner, "player_paddle_width", 155.0))
	var paddle_height: float = max(1.0, _get_owner_float(owner, "player_paddle_height", 50.0))
	var x: float = clamp(player_pos.x + paddle_width * 0.5 - FIELD_WIDTH * 0.5, 0.0, 760.0 - FIELD_WIDTH)
	var y: float = clamp(player_pos.y + paddle_height, 0.0, 750.0 - FIELD_HEIGHT)
	barriers.append({
		"id": _next_barrier_id,
		"alive": true,
		"built": false,
		"dying": false,
		"build_timer_sec": 0.0,
		"death_timer_sec": 0.0,
		"rect_x": x,
		"rect_y": y,
		"width": FIELD_WIDTH,
		"height": FIELD_HEIGHT,
		"seeds": _generate_seed_points(int(FIELD_WIDTH), int(FIELD_HEIGHT)),
	})
	_next_barrier_id += 1


func _active_barrier_count() -> int:
	var count := 0
	for barrier in barriers:
		if bool(barrier.get("alive", false)) and not bool(barrier.get("dying", false)):
			count += 1
	return count


func _get_barrier_rect(barrier: Dictionary) -> Rect2:
	return Rect2(
		Vector2(float(barrier.get("rect_x", 0.0)), float(barrier.get("rect_y", 0.0))),
		Vector2(max(1.0, float(barrier.get("width", FIELD_WIDTH))), max(1.0, float(barrier.get("height", FIELD_HEIGHT))))
	)


func _get_owner_gauge(runtime: Object, owner: Object) -> float:
	if runtime == null:
		return 0.0
	return max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))


func _get_player_pos(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(300.0, 700.0)
	var value: Variant = owner.get("player_pos")
	if value is Vector2:
		return value
	return Vector2(300.0, 700.0)


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return float(value)


func _generate_seed_points(width: int, height: int) -> Array[Vector2]:
	var seeds: Array[Vector2] = []
	var count: int = max(8, int(float(width) / 8.0))
	for i in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var jitter_x: float = sin(float(i) * 2.17) * 4.0
		var jitter_y: float = cos(float(i) * 1.63) * 2.0
		seeds.append(Vector2(
			clamp(float(width) * t + jitter_x, 4.0, float(width) - 4.0),
			clamp(float(height) * 0.5 + jitter_y, 2.0, float(height) - 2.0)
		))
	return seeds


func _play_audio(runtime: Object, registry: Object, method_name: String) -> void:
	if runtime == null:
		return
	var audio_router: Object = runtime.get("audio_router")
	if audio_router != null and audio_router.has_method("play_named"):
		audio_router.play_named(runtime, registry, method_name)
