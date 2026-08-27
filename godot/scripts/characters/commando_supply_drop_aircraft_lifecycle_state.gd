extends RefCounted

const FRAME_SECONDS := 1.0 / 60.0
const PYTHON_AIRCRAFT_ARRIVAL_MIN_FRAMES := 90
const PYTHON_AIRCRAFT_ARRIVAL_MAX_FRAMES := 300
const PYTHON_AIRCRAFT_SPEED_PX_PER_FRAME := 2.0

# Match the fire-support stealth lane: the aircraft starts at the screen edge
# beyond the centered game canvas, while payloads remain clamped to the canvas.
const AIRCRAFT_START_X := -360.0
const AIRCRAFT_END_X := 1120.0
const AIRCRAFT_ALTITUDE_Y := 56.0
const AIRCRAFT_SPEED_PIXELS_PER_SECOND := PYTHON_AIRCRAFT_SPEED_PX_PER_FRAME / FRAME_SECONDS
const AIRCRAFT_COLLISION_SIZE := Vector2(96.0, 44.0)
const AIRCRAFT_INVULNERABLE_SECONDS := 0.25
const AIRCRAFT_CRASH_SECONDS := 1.5
const AIRCRAFT_CRASH_GROUND_Y := 660.0
const AIRCRAFT_CRASH_DRIFT_X := 96.0
const PAYLOAD_SPAWN_OFFSET := Vector2(0.0, 104.0)
const DEFAULT_PLAY_WIDTH := 760.0

var spawned := false
var arrival_delay := 0.0
var arrival_timer := 0.0
var direction := "left_to_right"
var pos := Vector2(AIRCRAFT_START_X, AIRCRAFT_ALTITUDE_Y)
var crashing := false
var crash_elapsed := 0.0
var crash_timer := 0.0
var crash_rotation := 0.0
var crash_start_pos := Vector2.ZERO
var crash_target_pos := Vector2.ZERO
var exploded := false
var crash_source := ""
var flight_elapsed := 0.0
var flight_duration := get_travel_duration()


func reset() -> void:
	spawned = false
	arrival_delay = 0.0
	arrival_timer = 0.0
	direction = "left_to_right"
	pos = Vector2(AIRCRAFT_START_X, AIRCRAFT_ALTITUDE_Y)
	crashing = false
	crash_elapsed = 0.0
	crash_timer = 0.0
	crash_rotation = 0.0
	crash_start_pos = Vector2.ZERO
	crash_target_pos = Vector2.ZERO
	exploded = false
	crash_source = ""
	flight_elapsed = 0.0
	flight_duration = get_travel_duration()


func begin(deps: Dictionary = {}) -> Dictionary:
	spawned = false
	arrival_delay = _get_arrival_delay(deps)
	arrival_timer = arrival_delay
	direction = _get_direction(deps)
	pos = get_start_pos()
	crashing = false
	crash_elapsed = 0.0
	crash_timer = 0.0
	crash_rotation = 0.0
	crash_start_pos = Vector2.ZERO
	crash_target_pos = Vector2.ZERO
	exploded = false
	crash_source = ""
	flight_elapsed = 0.0
	flight_duration = get_travel_duration()
	return {
		"aircraft_arrival_delay": arrival_delay,
		"aircraft_direction": direction,
		"aircraft_pos": pos,
		"flight_duration": flight_duration,
	}


func restore(snapshot: Dictionary, active: bool) -> void:
	direction = _normalize_direction(str(snapshot.get("aircraft_direction", "left_to_right")))
	var fallback_pos: Vector2 = get_start_pos()
	crashing = bool(snapshot.get("aircraft_crashing", false))
	spawned = bool(snapshot.get(
		"aircraft_spawned",
		active and (
			bool(snapshot.get("aircraft_audio_active", false))
			or crashing
			or float(snapshot.get("flight_elapsed", 0.0)) > 0.0
		)
	))
	arrival_delay = max(0.0, float(snapshot.get("aircraft_arrival_delay", 0.0)))
	arrival_timer = 0.0
	if active and not spawned and not crashing:
		arrival_timer = max(0.0, float(snapshot.get("timer", arrival_delay)))
	pos = _get_vector2(snapshot.get("aircraft_pos", fallback_pos), fallback_pos)
	crash_elapsed = max(0.0, float(snapshot.get("aircraft_crash_elapsed", 0.0)))
	crash_timer = max(0.0, float(snapshot.get("aircraft_crash_timer", 0.0)))
	crash_rotation = float(snapshot.get("aircraft_crash_rotation", 0.0))
	crash_start_pos = _get_vector2(snapshot.get("aircraft_crash_start_pos", pos), pos)
	crash_target_pos = _get_vector2(snapshot.get("aircraft_crash_target_pos", Vector2.ZERO), Vector2.ZERO)
	exploded = bool(snapshot.get("aircraft_exploded", false))
	crash_source = str(snapshot.get("aircraft_crash_source", ""))
	flight_elapsed = max(0.0, float(snapshot.get("flight_elapsed", 0.0)))
	flight_duration = max(get_travel_duration(), float(snapshot.get("flight_duration", get_travel_duration())))


func get_snapshot() -> Dictionary:
	return {
		"aircraft_spawned": spawned,
		"aircraft_arrival_delay": arrival_delay,
		"aircraft_direction": direction,
		"aircraft_pos": pos,
		"aircraft_rect": get_collision_rect(),
		"aircraft_crashing": crashing,
		"aircraft_crash_elapsed": crash_elapsed,
		"aircraft_crash_timer": crash_timer,
		"aircraft_crash_rotation": crash_rotation,
		"aircraft_crash_start_pos": crash_start_pos,
		"aircraft_crash_target_pos": crash_target_pos,
		"aircraft_exploded": exploded,
		"aircraft_crash_source": crash_source,
		"flight_elapsed": flight_elapsed,
		"flight_duration": flight_duration,
	}


func advance_active_flight(delta: float, active: bool, deps: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if not active:
		return result
	var flight_delta: float = max(0.0, delta)
	if not spawned:
		result = update_arrival(flight_delta, active)
		if not spawned:
			return result
		flight_delta = max(0.0, float(result.get(
			"remaining_delta_after_aircraft_spawn",
			0.0
		)))
	var flight_result: Dictionary = advance_flight(flight_delta, deps)
	for key in flight_result.keys():
		result[key] = flight_result[key]
	return result


func update_arrival(delta: float, active: bool) -> Dictionary:
	if spawned:
		return {"remaining_delta_after_aircraft_spawn": max(0.0, delta)}
	if not active:
		return {}
	var safe_delta: float = max(0.0, delta)
	var previous_timer: float = arrival_timer
	arrival_timer = max(0.0, arrival_timer - safe_delta)
	if previous_timer > safe_delta:
		return {
			"aircraft_pending": true,
			"aircraft_arrival_timer": arrival_timer,
		}
	var remaining_delta: float = max(0.0, safe_delta - previous_timer)
	if not spawn(active):
		return {}
	return {
		"aircraft_spawned": true,
		"remaining_delta_after_aircraft_spawn": remaining_delta,
	}


func spawn(active: bool) -> bool:
	if spawned or not active or crashing or exploded:
		return false
	spawned = true
	arrival_timer = 0.0
	flight_elapsed = 0.0
	flight_duration = get_travel_duration()
	_update_visual()
	return true


func advance_flight(delta: float, deps: Dictionary = {}) -> Dictionary:
	if not spawned:
		return {}
	var safe_delta: float = max(0.0, delta)
	var previous_elapsed: float = flight_elapsed
	flight_elapsed += safe_delta
	_update_visual()
	return {
		"previous_flight_elapsed": previous_elapsed,
		"flight_elapsed": flight_elapsed,
		"payload_timer_delta": get_payload_drop_timer_delta(previous_elapsed, flight_elapsed, deps),
		"aircraft_offscreen": is_offscreen(),
	}


func complete_flight() -> void:
	spawned = false


func begin_crash(active: bool, source: String = "unknown") -> bool:
	if not active or not spawned or crashing or exploded:
		return false
	spawned = false
	crashing = true
	exploded = false
	crash_source = source
	crash_elapsed = 0.0
	crash_timer = AIRCRAFT_CRASH_SECONDS
	crash_rotation = 0.0
	crash_start_pos = pos
	var drift_sign: float = 1.0 if direction != "right_to_left" else -1.0
	crash_target_pos = Vector2(
		clamp(pos.x + AIRCRAFT_CRASH_DRIFT_X * drift_sign, 42.0, 718.0),
		AIRCRAFT_CRASH_GROUND_Y
	)
	return true


func advance_crash(delta: float) -> Dictionary:
	if not crashing:
		return {}
	var safe_delta: float = max(0.0, delta)
	crash_elapsed += safe_delta
	crash_timer = max(0.0, AIRCRAFT_CRASH_SECONDS - crash_elapsed)
	var progress: float = clamp(crash_elapsed / max(0.001, AIRCRAFT_CRASH_SECONDS), 0.0, 1.0)
	var eased: float = progress * progress
	pos = crash_start_pos.lerp(crash_target_pos, eased)
	var rotation_sign: float = 1.0 if direction != "right_to_left" else -1.0
	crash_rotation = rotation_sign * lerpf(0.0, PI * 1.15, progress)
	var result: Dictionary = {}
	if safe_delta > 0.0:
		result["smoke_position"] = pos
	if progress >= 1.0:
		crashing = false
		exploded = true
		crash_timer = 0.0
		crash_elapsed = AIRCRAFT_CRASH_SECONDS
		pos = crash_target_pos
		result["aircraft_exploded"] = true
		result["crash_finished"] = true
		result["impact_pos"] = pos
		return result
	result["aircraft_crashing"] = true
	return result


func get_collision_rect() -> Rect2:
	return Rect2(pos - AIRCRAFT_COLLISION_SIZE * 0.5, AIRCRAFT_COLLISION_SIZE)


func is_hittable(active: bool) -> bool:
	return active and spawned and not crashing and not exploded and flight_elapsed >= AIRCRAFT_INVULNERABLE_SECONDS


func is_offscreen() -> bool:
	return flight_elapsed >= get_travel_duration()


func is_over_payload_drop_zone(deps: Dictionary = {}) -> bool:
	var bounds: Vector2 = get_payload_drop_gate_bounds(deps)
	var payload_x: float = pos.x + PAYLOAD_SPAWN_OFFSET.x
	return payload_x >= bounds.x and payload_x <= bounds.y


func get_payload_drop_timer_delta(previous_elapsed: float, current_elapsed: float, deps: Dictionary = {}) -> float:
	var window: Vector2 = get_payload_drop_zone_elapsed_window(deps)
	var start_elapsed: float = max(previous_elapsed, window.x)
	var end_elapsed: float = min(current_elapsed, window.y)
	return max(0.0, end_elapsed - start_elapsed)


func get_payload_drop_zone_elapsed_window(deps: Dictionary = {}) -> Vector2:
	var bounds: Vector2 = get_payload_drop_gate_bounds(deps)
	var enter_elapsed := 0.0
	var exit_elapsed := 0.0
	var speed: float = max(1.0, AIRCRAFT_SPEED_PIXELS_PER_SECOND)
	if direction == "right_to_left":
		enter_elapsed = (AIRCRAFT_END_X - (bounds.y - PAYLOAD_SPAWN_OFFSET.x)) / speed
		exit_elapsed = (AIRCRAFT_END_X - (bounds.x - PAYLOAD_SPAWN_OFFSET.x)) / speed
	else:
		enter_elapsed = ((bounds.x - PAYLOAD_SPAWN_OFFSET.x) - AIRCRAFT_START_X) / speed
		exit_elapsed = ((bounds.y - PAYLOAD_SPAWN_OFFSET.x) - AIRCRAFT_START_X) / speed
	var travel_duration: float = get_travel_duration()
	enter_elapsed = clamp(enter_elapsed, 0.0, travel_duration)
	exit_elapsed = clamp(exit_elapsed, 0.0, travel_duration)
	if exit_elapsed < enter_elapsed:
		return Vector2(enter_elapsed, enter_elapsed)
	return Vector2(enter_elapsed, exit_elapsed)


func get_payload_drop_gate_bounds(deps: Dictionary = {}) -> Vector2:
	var play_width: float = max(1.0, float(deps.get("play_width", deps.get("width", DEFAULT_PLAY_WIDTH))))
	var min_x: float = clamp(float(deps.get("commando_supply_drop_aircraft_center_min_x", 0.0)), 0.0, play_width)
	var max_x: float = clamp(float(deps.get("commando_supply_drop_aircraft_center_max_x", play_width)), 0.0, play_width)
	if max_x < min_x:
		var center_x: float = play_width * 0.5
		return Vector2(center_x, center_x)
	return Vector2(min_x, max_x)


func get_start_pos() -> Vector2:
	var start_x := AIRCRAFT_START_X
	if direction == "right_to_left":
		start_x = AIRCRAFT_END_X
	return Vector2(start_x, AIRCRAFT_ALTITUDE_Y)


func get_travel_duration() -> float:
	return absf(AIRCRAFT_END_X - AIRCRAFT_START_X) / max(1.0, AIRCRAFT_SPEED_PIXELS_PER_SECOND)


func _update_visual() -> void:
	var progress: float = clamp(flight_elapsed / max(0.001, get_travel_duration()), 0.0, 1.0)
	var start_x := AIRCRAFT_START_X
	var end_x := AIRCRAFT_END_X
	if direction == "right_to_left":
		start_x = AIRCRAFT_END_X
		end_x = AIRCRAFT_START_X
	pos = Vector2(lerpf(start_x, end_x, progress), AIRCRAFT_ALTITUDE_Y)


func _get_arrival_delay(deps: Dictionary) -> float:
	if deps.has("commando_supply_drop_aircraft_arrival_delay"):
		return max(0.0, float(deps.get("commando_supply_drop_aircraft_arrival_delay", 0.0)))
	if deps.has("commando_supply_drop_aircraft_arrival_delay_frames"):
		return max(0.0, float(deps.get("commando_supply_drop_aircraft_arrival_delay_frames", 0.0))) * FRAME_SECONDS
	return float(randi_range(PYTHON_AIRCRAFT_ARRIVAL_MIN_FRAMES, PYTHON_AIRCRAFT_ARRIVAL_MAX_FRAMES)) * FRAME_SECONDS


func _get_direction(deps: Dictionary) -> String:
	var configured_direction := str(deps.get("commando_supply_drop_direction", ""))
	if configured_direction == "left_to_right" or configured_direction == "right_to_left":
		return configured_direction
	return "left_to_right" if randi_range(0, 1) == 0 else "right_to_left"


func _normalize_direction(value: String) -> String:
	return "right_to_left" if value == "right_to_left" else "left_to_right"


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
