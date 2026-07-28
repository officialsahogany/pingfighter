extends RefCounted

# Run-shared guardian uptime pool. The public satiety-shaped facade methods are
# intentionally retained for the Slice 1 transition, but pet_id and bench-slot
# arguments no longer select separate batteries.
const SAVE_VALUE_KEY := "duration_pool"
const SAVE_MAX_KEY := "duration_pool_max"
const SAVE_RESUMMON_LOCK_KEY := "duration_resummon_lock_remaining"
const SAVE_INCREASE_COUNT_KEY := "duration_increase_count"
const LEGACY_SAVE_KEYS := ["satiety", "satiety_exhausted", "satiety_exhaustion_timer"]

const DURATION_MIN := 0.0
const DURATION_ROLL_MIN := 60
const DURATION_ROLL_MAX := 80
const DURATION_INCREASE_SECONDS := 5.0
const MAX_DURATION_INCREASES := 2
const DURATION_ENHANCED_MAX := float(DURATION_ROLL_MAX) + DURATION_INCREASE_SECONDS * MAX_DURATION_INCREASES
const REVALIDATION_FALLBACK_SECONDS := 15.0
const DRAIN_PER_SECOND := 1.0
const REST_RECOVERY_RATIO := 1.0 / 3.0
const RESUMMON_THRESHOLD := 10.0
const WARNING_START_SECONDS := 10.0
const VALUE_SNAP_EPSILON := 0.001

# Compatibility aliases used by callers that are removed in later §9-3 slices.
const DURATION_MAX := float(DURATION_ROLL_MAX)
const DRAIN_REDUCTION_PCT_BY_LEVEL := [10.0, 17.0, 24.0, 31.0, 38.0]
const SLOW_START := 50.0
const SLOW_FLOOR_START := 10.0
const SLOW_MIN_MULTIPLIER := 1.0
const EXHAUSTION_TELEGRAPH_SECONDS := 1.75
const WAKE_THRESHOLD := RESUMMON_THRESHOLD
const SAVE_EXHAUSTED_KEY := SAVE_RESUMMON_LOCK_KEY
const SAVE_EXHAUSTION_TIMER_KEY := SAVE_RESUMMON_LOCK_KEY

var _pool_current := 0.0
var _pool_max := 0.0
var _resummon_locked := false
var _drain_exempt_latched := false
var _duration_increase_count := 0


func bind_pet_store(_pet_store: Dictionary, _get_or_create_pet_data: Callable = Callable()) -> void:
	# §9-2 injected this owner into the per-pet affinity dictionary. The shared
	# pool deliberately owns no reference to that dictionary after the schema swap.
	pass


func reset_run() -> void:
	_pool_current = 0.0
	_pool_max = 0.0
	_resummon_locked = false
	_drain_exempt_latched = false
	_duration_increase_count = 0


func initialize_pet_state(pet_data: Dictionary) -> void:
	# Old per-pet rail fields must not survive the §9-3 run-state schema swap.
	for legacy_key in LEGACY_SAVE_KEYS:
		pet_data.erase(legacy_key)


func sanitize_pet_run_state(pet_data: Dictionary) -> Dictionary:
	var pet_copy := pet_data.duplicate(true)
	initialize_pet_state(pet_copy)
	return pet_copy


func ensure_initial_roll(
	rng: RandomNumberGenerator = null,
	forced_roll: int = 0
) -> Dictionary:
	if is_initialized():
		return {
			"accepted": false,
			"blocked_reason": "already_rolled",
			"pool_current": _pool_current,
			"pool_max": _pool_max,
		}
	var rolled_seconds := forced_roll
	if rolled_seconds <= 0:
		rolled_seconds = (
			rng.randi_range(DURATION_ROLL_MIN, DURATION_ROLL_MAX)
			if rng != null
			else randi_range(DURATION_ROLL_MIN, DURATION_ROLL_MAX)
		)
	rolled_seconds = clampi(rolled_seconds, DURATION_ROLL_MIN, DURATION_ROLL_MAX)
	_pool_max = float(rolled_seconds)
	_pool_current = _pool_max
	_resummon_locked = false
	return {
		"accepted": true,
		"blocked_reason": "",
		"pool_current": _pool_current,
		"pool_max": _pool_max,
	}


func is_initialized() -> bool:
	return _pool_max >= float(DURATION_ROLL_MIN)


func export_run_state() -> Dictionary:
	if not is_initialized():
		return {
			SAVE_VALUE_KEY: 0.0,
			SAVE_MAX_KEY: 0.0,
			SAVE_RESUMMON_LOCK_KEY: 0.0,
			SAVE_INCREASE_COUNT_KEY: 0,
		}
	return {
		SAVE_VALUE_KEY: _sanitize_uncapped_current(_pool_current),
		SAVE_MAX_KEY: _sanitize_max_value(_pool_max),
		SAVE_RESUMMON_LOCK_KEY: get_resummon_lock_remaining(),
		SAVE_INCREASE_COUNT_KEY: get_duration_increase_count(),
	}


func import_run_state(data: Dictionary) -> void:
	# Legacy per-pet satiety fields are intentionally ignored. Only the new
	# run-global keys can initialize the shared pool.
	var imported_max := _sanitize_max_value(data.get(SAVE_MAX_KEY, 0.0))
	if imported_max <= 0.0:
		reset_run()
		return
	_pool_max = imported_max
	_pool_current = _sanitize_uncapped_current(data.get(SAVE_VALUE_KEY, imported_max))
	_duration_increase_count = clampi(
		int(data.get(SAVE_INCREASE_COUNT_KEY, 0)),
		0,
		MAX_DURATION_INCREASES
	)
	var imported_lock_remaining := maxf(
		0.0,
		float(data.get(SAVE_RESUMMON_LOCK_KEY, 0.0))
	)
	_resummon_locked = imported_lock_remaining > 0.0 or _pool_current <= DURATION_MIN
	if _pool_current > RESUMMON_THRESHOLD:
		_resummon_locked = false


func latch_drain_exempt(owner: Object, collection_state: Object) -> bool:
	_drain_exempt_latched = (
		owner != null
		and collection_state != null
		and collection_state.has_method("is_auto_present_league")
		and bool(collection_state.is_auto_present_league(owner))
	)
	return _drain_exempt_latched


func clear_drain_exempt_latch() -> void:
	_drain_exempt_latched = false


func is_drain_exempt_latched() -> bool:
	return _drain_exempt_latched


func advance_pool(
	delta_seconds: float,
	summoned: bool,
	drain_exempt: bool = false,
	active_drain_multiplier: float = 1.0,
	rest_recovery_multiplier: float = 1.0
) -> Dictionary:
	if delta_seconds <= 0.0 or not is_initialized():
		return _build_advance_result(false, false)
	var before := _pool_current
	var expired_now := false
	if summoned:
		if not drain_exempt:
			_pool_current = _sanitize_uncapped_current(
				_pool_current
				- DRAIN_PER_SECOND * maxf(0.0, active_drain_multiplier) * delta_seconds
			)
			expired_now = before > DURATION_MIN and _pool_current <= DURATION_MIN
			if expired_now:
				_resummon_locked = true
	else:
		if _pool_current < _pool_max:
			_pool_current = _sanitize_duration_value_for_max(
				_pool_current
				+ DRAIN_PER_SECOND * REST_RECOVERY_RATIO
					* maxf(0.0, rest_recovery_multiplier) * delta_seconds,
				_pool_max
			)
		if _pool_current > RESUMMON_THRESHOLD:
			_resummon_locked = false
	return _build_advance_result(not is_equal_approx(before, _pool_current), expired_now)


func refill_to_max() -> bool:
	if not is_initialized():
		return false
	var changed := not is_equal_approx(_pool_current, _pool_max) or _resummon_locked
	_pool_current = _pool_max
	_resummon_locked = false
	return changed


func restore_to_full_preserving_overfill() -> Dictionary:
	if not is_initialized():
		return {"accepted": false, "blocked_reason": "duration_pool_uninitialized"}
	var before_current := _pool_current
	_pool_current = _sanitize_uncapped_current(maxf(_pool_current, _pool_max))
	if _pool_current > RESUMMON_THRESHOLD:
		_resummon_locked = false
	return {
		"accepted": true,
		"changed": not is_equal_approx(before_current, _pool_current),
		"pool_current_before": before_current,
		"pool_current": _pool_current,
		"pool_max": _pool_max,
		"overfill_preserved": before_current > _pool_max and is_equal_approx(before_current, _pool_current),
	}


func get_pool_current() -> float:
	return _sanitize_uncapped_current(_pool_current)


func get_pool_max() -> float:
	return _sanitize_max_value(_pool_max)


func get_pool_pct() -> int:
	if not is_initialized():
		return 0
	return clampi(roundi(get_pool_current() / get_pool_max() * 100.0), 0, 100)


func can_resummon() -> bool:
	return is_initialized() and not _resummon_locked and _pool_current > RESUMMON_THRESHOLD


func is_resummon_locked() -> bool:
	return _resummon_locked or (is_initialized() and _pool_current <= DURATION_MIN)


func get_resummon_lock_remaining() -> float:
	if not is_resummon_locked():
		return 0.0
	return maxf(0.0, RESUMMON_THRESHOLD - _pool_current + VALUE_SNAP_EPSILON)


func get_warning_ratio() -> float:
	if not is_initialized() or _pool_current > WARNING_START_SECONDS:
		return 0.0
	return clampf(1.0 - _pool_current / WARNING_START_SECONDS, 0.0, 1.0)


func get_duration_increase_count() -> int:
	return clampi(_duration_increase_count, 0, MAX_DURATION_INCREASES)


func can_apply_duration_increase() -> bool:
	return is_initialized() and get_duration_increase_count() < MAX_DURATION_INCREASES


func apply_duration_increase() -> Dictionary:
	if not can_apply_duration_increase():
		return {"accepted": false, "blocked_reason": "duration_increase_cap"}
	var before_current := _pool_current
	var before_max := _pool_max
	_pool_max = _sanitize_max_value(_pool_max + DURATION_INCREASE_SECONDS)
	_pool_current = _sanitize_uncapped_current(_pool_current + DURATION_INCREASE_SECONDS)
	_duration_increase_count += 1
	return {
		"accepted": true,
		"storage_owner": "lingpet_duration_state",
		"duration_increase_count": get_duration_increase_count(),
		"pool_current_before": before_current,
		"pool_current": _pool_current,
		"pool_max_before": before_max,
		"pool_max": _pool_max,
	}


func apply_revalidation_fallback() -> Dictionary:
	if not is_initialized():
		return {"accepted": false, "blocked_reason": "duration_pool_uninitialized"}
	var before_current := _pool_current
	var before_max := _pool_max
	_pool_current = _sanitize_uncapped_current(
		_pool_current + REVALIDATION_FALLBACK_SECONDS
	)
	return {
		"accepted": true,
		"storage_owner": "lingpet_duration_state",
		"type": "duration_current_restore",
		"amount": REVALIDATION_FALLBACK_SECONDS,
		"pool_current_before": before_current,
		"pool_current": _pool_current,
		"pool_max_before": before_max,
		"pool_max": _pool_max,
		"pool_max_changed": not is_equal_approx(before_max, _pool_max),
	}


func set_pool_for_tests(current: float, maximum: float = 0.0) -> void:
	var target_max := maximum
	if target_max <= 0.0:
		target_max = _pool_max if is_initialized() else float(DURATION_ROLL_MAX)
	_pool_max = _sanitize_max_value(target_max)
	_pool_current = _sanitize_duration_value_for_max(current, _pool_max)
	_resummon_locked = _pool_current <= DURATION_MIN


# Transitional satiety-shaped facade -------------------------------------------------

func get_duration(_pet_id: String = "") -> float:
	return get_pool_current()


func get_duration_pct(_pet_id: String = "") -> int:
	return get_pool_pct()


func set_duration(_pet_id: String, value: float) -> Dictionary:
	if not is_initialized():
		_pool_max = float(DURATION_ROLL_MAX)
	var before := _pool_current
	_pool_current = _sanitize_duration_value_for_max(value, _pool_max)
	_resummon_locked = _pool_current <= DURATION_MIN
	return {
		"changed": not is_equal_approx(before, _pool_current),
		"value": _pool_current,
	}


func add_duration(pet_id: String, amount: float) -> Dictionary:
	if is_initialized() and _pool_current >= _pool_max and amount >= 0.0:
		return {"changed": false, "value": _pool_current}
	return set_duration(pet_id, get_duration(pet_id) + amount)


func advance_duration(
	_active_pet_id: String,
	_battle_slot_pet_ids: Array,
	delta_seconds: float,
	active_drain_multiplier: float = 1.0,
	rest_recovery_multiplier: float = 1.0,
	active_resting: bool = false
) -> Dictionary:
	var result := advance_pool(
		delta_seconds,
		not active_resting,
		_drain_exempt_latched,
		active_drain_multiplier,
		rest_recovery_multiplier
	)
	result["active_duration"] = _pool_current
	return result


func advance_exhaustion(
	_pet_id: String,
	_delta_seconds: float,
	_telegraph_seconds: float = EXHAUSTION_TELEGRAPH_SECONDS,
	_enabled: bool = true
) -> Dictionary:
	return {
		"changed": false,
		"exhausted": is_resummon_locked(),
		"timer": get_resummon_lock_remaining(),
		"ratio": get_warning_ratio(),
	}


func is_exhausted(_pet_id: String = "") -> bool:
	return is_resummon_locked()


func get_exhaustion_timer(_pet_id: String = "") -> float:
	return get_resummon_lock_remaining()


func get_exhaustion_ratio(
	_pet_id: String = "",
	_telegraph_seconds: float = EXHAUSTION_TELEGRAPH_SECONDS
) -> float:
	return get_warning_ratio()


func get_speed_multiplier(_pet_id: String = "") -> float:
	return 1.0


static func get_duration_speed_multiplier_for_value(_value: float) -> float:
	return 1.0


static func get_drain_reduction_pct_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var index := clampi(level, 1, DRAIN_REDUCTION_PCT_BY_LEVEL.size()) - 1
	return float(DRAIN_REDUCTION_PCT_BY_LEVEL[index])


func _build_advance_result(changed: bool, expired_now: bool) -> Dictionary:
	return {
		"changed": changed,
		"expired": expired_now,
		"pool_current": _pool_current,
		"pool_max": _pool_max,
		"pool_pct": get_pool_pct(),
		"warning_ratio": get_warning_ratio(),
		"resummon_locked": is_resummon_locked(),
		"resummon_lock_remaining": get_resummon_lock_remaining(),
		"can_resummon": can_resummon(),
	}


func _sanitize_max_value(value: Variant) -> float:
	var numeric := float(value)
	if numeric <= 0.0:
		return 0.0
	return clampf(numeric, float(DURATION_ROLL_MIN), DURATION_ENHANCED_MAX)


func _sanitize_duration_value(value: Variant) -> float:
	return _sanitize_duration_value_for_max(value, _pool_max)


func _sanitize_duration_value_for_max(value: Variant, maximum: float) -> float:
	var safe_max := maxf(DURATION_MIN, maximum)
	var clamped := clampf(float(value), DURATION_MIN, safe_max)
	if clamped < VALUE_SNAP_EPSILON:
		return DURATION_MIN
	if safe_max > DURATION_MIN and clamped > safe_max - VALUE_SNAP_EPSILON:
		return safe_max
	return clamped


func _sanitize_uncapped_current(value: Variant) -> float:
	var safe := maxf(DURATION_MIN, float(value))
	if safe < VALUE_SNAP_EPSILON:
		return DURATION_MIN
	return safe
