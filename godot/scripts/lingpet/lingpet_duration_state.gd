extends RefCounted

# §9-2 extraction owner for the legacy per-pet satiety rail. Internal APIs use
# duration terminology, while the serialized field names remain unchanged until
# the §9-3 schema/ownership swap.
const SAVE_VALUE_KEY := "satiety"
const SAVE_EXHAUSTED_KEY := "satiety_exhausted"
const SAVE_EXHAUSTION_TIMER_KEY := "satiety_exhaustion_timer"

const DURATION_MIN := 0.0
const DURATION_MAX := 100.0
const DRAIN_PER_SECOND := 0.52
const REST_RECOVERY_RATIO := 1.0 / 3.0
const DRAIN_REDUCTION_PCT_BY_LEVEL := [10.0, 17.0, 24.0, 31.0, 38.0]
const SLOW_START := 50.0
const SLOW_FLOOR_START := 10.0
const SLOW_MIN_MULTIPLIER := 0.60
const EXHAUSTION_TELEGRAPH_SECONDS := 1.75
const WAKE_THRESHOLD := 10.0
# Snap band for float residue at both duration rails (see
# _sanitize_duration_value): values inside (0, epsilon) collapse to 0 and
# (100-epsilon, 100) to 100 so write-gating / strict comparisons never pin the
# gauge just off a rail. Gameplay-invisible.
const VALUE_SNAP_EPSILON := 0.001

var _pet_store: Dictionary = {}
var _get_or_create_pet_data := Callable()


func bind_pet_store(pet_store: Dictionary, get_or_create_pet_data: Callable = Callable()) -> void:
	_pet_store = pet_store
	_get_or_create_pet_data = get_or_create_pet_data


func initialize_pet_state(pet_data: Dictionary) -> void:
	if not pet_data.has(SAVE_VALUE_KEY):
		pet_data[SAVE_VALUE_KEY] = DURATION_MAX
	if not pet_data.has(SAVE_EXHAUSTED_KEY):
		pet_data[SAVE_EXHAUSTED_KEY] = false
	if not pet_data.has(SAVE_EXHAUSTION_TIMER_KEY):
		pet_data[SAVE_EXHAUSTION_TIMER_KEY] = 0.0


func sanitize_pet_run_state(pet_data: Dictionary) -> Dictionary:
	var pet_copy := pet_data.duplicate(true)
	var sanitized_duration := _sanitize_duration_value(pet_copy.get(SAVE_VALUE_KEY, DURATION_MAX))
	pet_copy[SAVE_VALUE_KEY] = sanitized_duration
	pet_copy[SAVE_EXHAUSTION_TIMER_KEY] = _sanitize_exhaustion_timer(
		pet_copy.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0),
		sanitized_duration
	)
	pet_copy[SAVE_EXHAUSTED_KEY] = sanitized_duration < WAKE_THRESHOLD and (
		bool(pet_copy.get(SAVE_EXHAUSTED_KEY, false))
		or float(pet_copy.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0)) >= EXHAUSTION_TELEGRAPH_SECONDS
	)
	return pet_copy


func get_duration(pet_id: String) -> float:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return DURATION_MAX
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return DURATION_MAX
	return _sanitize_duration_value(pet_data.get(SAVE_VALUE_KEY, DURATION_MAX))


func get_duration_pct(pet_id: String) -> int:
	return clampi(roundi(get_duration(pet_id)), int(DURATION_MIN), int(DURATION_MAX))


func set_duration(pet_id: String, value: float) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"changed": false, "value": DURATION_MAX}
	var pet_data := _get_or_create_pet_state(normalized_pet_id)
	var next_duration := _sanitize_duration_value(value)
	var changed := false
	if not is_equal_approx(float(pet_data.get(SAVE_VALUE_KEY, DURATION_MAX)), next_duration):
		pet_data[SAVE_VALUE_KEY] = next_duration
		changed = true
	if next_duration >= WAKE_THRESHOLD:
		if bool(pet_data.get(SAVE_EXHAUSTED_KEY, false)) or float(pet_data.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0)) > 0.0:
			pet_data[SAVE_EXHAUSTED_KEY] = false
			pet_data[SAVE_EXHAUSTION_TIMER_KEY] = 0.0
			changed = true
	elif next_duration > DURATION_MIN:
		if bool(pet_data.get(SAVE_EXHAUSTED_KEY, false)):
			var rested_timer := maxf(float(pet_data.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0)), EXHAUSTION_TELEGRAPH_SECONDS)
			if not is_equal_approx(float(pet_data.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0)), rested_timer):
				pet_data[SAVE_EXHAUSTION_TIMER_KEY] = rested_timer
				changed = true
		elif float(pet_data.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0)) > 0.0:
			pet_data[SAVE_EXHAUSTION_TIMER_KEY] = 0.0
			changed = true
	if changed:
		_pet_store[normalized_pet_id] = pet_data
	return {"changed": changed, "value": next_duration}


func add_duration(pet_id: String, amount: float) -> Dictionary:
	return set_duration(pet_id, get_duration(pet_id) + amount)


func advance_duration(
	active_pet_id: String,
	battle_slot_pet_ids: Array,
	delta_seconds: float,
	active_drain_multiplier: float = 1.0,
	rest_recovery_multiplier: float = 1.0,
	active_resting: bool = false
) -> Dictionary:
	if delta_seconds <= 0.0:
		return {"changed": false, "active_duration": get_duration(active_pet_id)}
	var normalized_active_pet_id := _normalize_pet_id(active_pet_id)
	var changed := false
	var rest_amount := DRAIN_PER_SECOND * REST_RECOVERY_RATIO * delta_seconds * maxf(0.0, rest_recovery_multiplier)
	if normalized_active_pet_id != "":
		if active_resting:
			if rest_amount > 0.0:
				var before_active_rest := get_duration(normalized_active_pet_id)
				var active_rest_result := set_duration(normalized_active_pet_id, before_active_rest + rest_amount)
				changed = changed or bool(active_rest_result.get("changed", false))
		else:
			var drain_amount := DRAIN_PER_SECOND * delta_seconds * maxf(0.0, active_drain_multiplier)
			if drain_amount > 0.0:
				var before_active := get_duration(normalized_active_pet_id)
				var active_result := set_duration(normalized_active_pet_id, before_active - drain_amount)
				changed = changed or bool(active_result.get("changed", false))
	if rest_amount > 0.0:
		var seen := {}
		for raw_pet_id in battle_slot_pet_ids:
			var rest_pet_id := _normalize_pet_id(str(raw_pet_id))
			if rest_pet_id == "" or rest_pet_id == normalized_active_pet_id or seen.has(rest_pet_id):
				continue
			seen[rest_pet_id] = true
			var before_rest := get_duration(rest_pet_id)
			var rest_result := set_duration(rest_pet_id, before_rest + rest_amount)
			changed = changed or bool(rest_result.get("changed", false))
	return {
		"changed": changed,
		"active_duration": get_duration(normalized_active_pet_id),
	}


func advance_exhaustion(
	pet_id: String,
	delta_seconds: float,
	telegraph_seconds: float = EXHAUSTION_TELEGRAPH_SECONDS,
	enabled: bool = true
) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"changed": false, "exhausted": false, "timer": 0.0, "ratio": 0.0}
	var pet_data := _get_or_create_pet_state(normalized_pet_id)
	var current_duration := get_duration(normalized_pet_id)
	var before_timer := _sanitize_exhaustion_timer(
		pet_data.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0),
		current_duration
	)
	var before_exhausted := bool(pet_data.get(SAVE_EXHAUSTED_KEY, false))
	var next_timer := before_timer
	var next_exhausted := before_exhausted
	if not enabled or current_duration >= WAKE_THRESHOLD:
		next_timer = 0.0
		next_exhausted = false
	elif before_exhausted:
		next_timer = maxf(before_timer, maxf(0.0, telegraph_seconds))
		next_exhausted = true
	elif current_duration > DURATION_MIN:
		next_timer = 0.0
		next_exhausted = false
	else:
		next_timer = maxf(0.0, before_timer + maxf(0.0, delta_seconds))
		next_exhausted = next_timer >= maxf(0.0, telegraph_seconds)
	var changed := (
		not is_equal_approx(before_timer, next_timer)
		or before_exhausted != next_exhausted
	)
	if changed:
		pet_data[SAVE_EXHAUSTION_TIMER_KEY] = next_timer
		pet_data[SAVE_EXHAUSTED_KEY] = next_exhausted
		_pet_store[normalized_pet_id] = pet_data
	return {
		"changed": changed,
		"exhausted": next_exhausted,
		"timer": next_timer,
		"ratio": _get_exhaustion_ratio(next_timer, telegraph_seconds),
	}


func is_exhausted(pet_id: String) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "" or get_duration(normalized_pet_id) >= WAKE_THRESHOLD:
		return false
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	return bool(pet_data.get(SAVE_EXHAUSTED_KEY, false))


func get_exhaustion_timer(pet_id: String) -> float:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return 0.0
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	return _sanitize_exhaustion_timer(
		pet_data.get(SAVE_EXHAUSTION_TIMER_KEY, 0.0),
		get_duration(normalized_pet_id)
	)


func get_exhaustion_ratio(
	pet_id: String,
	telegraph_seconds: float = EXHAUSTION_TELEGRAPH_SECONDS
) -> float:
	return _get_exhaustion_ratio(get_exhaustion_timer(pet_id), telegraph_seconds)


func get_speed_multiplier(pet_id: String) -> float:
	return get_duration_speed_multiplier_for_value(get_duration(pet_id))


static func get_duration_speed_multiplier_for_value(value: float) -> float:
	var duration := clampf(value, DURATION_MIN, DURATION_MAX)
	if duration > SLOW_START:
		return 1.0
	if duration >= SLOW_FLOOR_START:
		var ratio := (duration - SLOW_FLOOR_START) / (SLOW_START - SLOW_FLOOR_START)
		return lerpf(SLOW_MIN_MULTIPLIER, 1.0, ratio)
	return SLOW_MIN_MULTIPLIER


static func get_drain_reduction_pct_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var index := clampi(level, 1, DRAIN_REDUCTION_PCT_BY_LEVEL.size()) - 1
	return float(DRAIN_REDUCTION_PCT_BY_LEVEL[index])


func _get_or_create_pet_state(pet_id: String) -> Dictionary:
	if _get_or_create_pet_data.is_valid():
		var resolved: Variant = _get_or_create_pet_data.call(pet_id)
		if resolved is Dictionary:
			var resolved_state := resolved as Dictionary
			initialize_pet_state(resolved_state)
			return resolved_state
	if _pet_store.has(pet_id):
		var existing: Variant = _pet_store.get(pet_id, {})
		if existing is Dictionary:
			var existing_state := existing as Dictionary
			initialize_pet_state(existing_state)
			return existing_state
	var pet_state := {"pet_id": pet_id}
	initialize_pet_state(pet_state)
	_pet_store[pet_id] = pet_state
	return pet_state


func _get_existing_pet_data(pet_id: String) -> Dictionary:
	if _pet_store.has(pet_id):
		var existing: Variant = _pet_store.get(pet_id, {})
		if existing is Dictionary:
			return existing as Dictionary
	return {}


func _sanitize_duration_value(value: Variant) -> float:
	var clamped := clampf(float(value), DURATION_MIN, DURATION_MAX)
	# Float-residue snap: a real-tick drain sequence can land on a sub-epsilon
	# positive remainder (e.g. 2e-10) that set_duration's is_equal_approx write
	# gate then freezes forever ("2e-10 -> 0" skips the 0.0 write). A strictly
	# positive residue keeps the exhaustion "duration > 0" branch resetting the
	# KO timer every tick, so the pet can never exhaust. Snap both rails.
	if clamped < VALUE_SNAP_EPSILON:
		return DURATION_MIN
	if clamped > DURATION_MAX - VALUE_SNAP_EPSILON:
		return DURATION_MAX
	return clamped


func _sanitize_exhaustion_timer(value: Variant, duration: float) -> float:
	if duration >= WAKE_THRESHOLD:
		return 0.0
	return maxf(0.0, float(value))


func _get_exhaustion_ratio(timer: float, telegraph_seconds: float) -> float:
	var duration := maxf(0.001, telegraph_seconds)
	return clampf(maxf(0.0, timer) / duration, 0.0, 1.0)


func _normalize_pet_id(pet_id: String) -> String:
	return pet_id.strip_edges()
