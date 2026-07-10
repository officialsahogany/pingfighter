extends RefCounted

const BASE_PADDLE_WIDTH := 296.0
const BASE_PADDLE_HEIGHT := 147.0
const DEFAULT_PADDLE_WIDTH := 155.0
const MAX_GAUGE := 500.0
const DRAIN_PER_SECOND := 7.0
const MANUAL_CHARGE_HOLD_SECONDS := 0.5
const MANUAL_CHARGE_RATE_PER_SECOND := 60.0
const MANUAL_CHARGE_RELEASE_LOCK_SECONDS := 0.5
const MIN_PADDLE_WIDTH := 240.0
const MIN_SPEED_MULTIPLIER := 0.25

var drain_buffer := 0.0
var initialized := false
var manual_charge_hold_seconds := 0.0
var manual_charge_active := false
var manual_charge_lock_seconds := 0.0


func reset() -> void:
	drain_buffer = 0.0
	initialized = false
	manual_charge_hold_seconds = 0.0
	manual_charge_active = false
	manual_charge_lock_seconds = 0.0


func prepare_owner_for_optimus(owner: Object, paddle_base_scale: float = 1.0) -> Dictionary:
	return _prepare_owner_for_optimus(owner, true, paddle_base_scale)


func prepare_owner_runtime_base_for_optimus(owner: Object, paddle_base_scale: float = 1.0) -> Dictionary:
	return _prepare_owner_for_optimus(owner, false, paddle_base_scale)


func _prepare_owner_for_optimus(
	owner: Object,
	include_final_size: bool,
	paddle_base_scale: float
) -> Dictionary:
	if owner == null:
		return {}
	var selected: String = str(_safe_get(owner, "selected_character_type", "smasher")).strip_edges().to_lower()
	if selected != "optimus":
		initialized = false
		return {}
	var gauge_max: float = maxf(1.0, float(_safe_get(owner, "special_gauge_max", MAX_GAUGE)))
	if not bool(_safe_get(owner, "optimus_energy_initialized", false)):
		initialized = true
		drain_buffer = 0.0
		owner.set("optimus_energy_initialized", true)
		owner.set("special_gauge_max", gauge_max)
		owner.set("special_gauge", gauge_max)
	else:
		initialized = true
	var special_gauge: float = float(_safe_get(owner, "special_gauge", gauge_max))
	if include_final_size:
		return build_scale_snapshot(special_gauge, gauge_max, paddle_base_scale)
	return build_runtime_base_snapshot(special_gauge, gauge_max, paddle_base_scale)


func update_energy(
	delta: float,
	special_gauge: float,
	paused: bool = false,
	special_gauge_max: float = MAX_GAUGE,
	paddle_base_scale: float = 1.0
) -> Dictionary:
	var gauge_max: float = maxf(1.0, special_gauge_max)
	var next_gauge: float = clampf(float(special_gauge), 0.0, gauge_max)
	if paused:
		drain_buffer = 0.0
	else:
		drain_buffer += max(0.0, delta) * DRAIN_PER_SECOND
		var drain_units: int = int(drain_buffer)
		if drain_units > 0:
			drain_buffer -= float(drain_units)
			next_gauge = max(0.0, next_gauge - float(drain_units))
	var snapshot: Dictionary = build_runtime_base_snapshot(next_gauge, gauge_max, paddle_base_scale)
	snapshot["special_gauge"] = next_gauge
	snapshot["special_gauge_max"] = gauge_max
	snapshot["optimus_energy_initialized"] = true
	_merge_manual_charge_snapshot(snapshot)
	return snapshot


func update_manual_charge(
	delta: float,
	down_held: bool,
	special_gauge: float,
	blocked: bool = false,
	special_gauge_max: float = MAX_GAUGE,
	paddle_base_scale: float = 1.0
) -> Dictionary:
	var step: float = max(0.0, delta)
	var gauge_max: float = maxf(1.0, special_gauge_max)
	var next_gauge: float = clampf(float(special_gauge), 0.0, gauge_max)
	var was_active: bool = manual_charge_active
	var started := false
	var released := false
	if manual_charge_lock_seconds > 0.0:
		manual_charge_lock_seconds = max(0.0, manual_charge_lock_seconds - step)

	if blocked:
		manual_charge_hold_seconds = 0.0
		manual_charge_active = false
		return _build_manual_charge_result(
			next_gauge,
			false,
			false,
			true,
			gauge_max,
			paddle_base_scale
		)

	if down_held and manual_charge_lock_seconds <= 0.0:
		manual_charge_hold_seconds += step
		if not manual_charge_active and manual_charge_hold_seconds >= MANUAL_CHARGE_HOLD_SECONDS:
			manual_charge_active = true
			started = not was_active
		if manual_charge_active:
			next_gauge = minf(gauge_max, next_gauge + MANUAL_CHARGE_RATE_PER_SECOND * step)
	else:
		if was_active:
			manual_charge_lock_seconds = MANUAL_CHARGE_RELEASE_LOCK_SECONDS
			released = true
		manual_charge_hold_seconds = 0.0
		manual_charge_active = false

	return _build_manual_charge_result(
		next_gauge,
		started,
		released,
		false,
		gauge_max,
		paddle_base_scale
	)


func build_scale_snapshot(
	special_gauge: float,
	special_gauge_max: float = MAX_GAUGE,
	paddle_base_scale: float = 1.0
) -> Dictionary:
	var snapshot: Dictionary = build_runtime_base_snapshot(
		special_gauge,
		special_gauge_max,
		paddle_base_scale
	)
	var paddle_width: float = float(snapshot.get("runtime_paddle_base_width", BASE_PADDLE_WIDTH))
	var paddle_height: float = float(snapshot.get("runtime_paddle_base_height", BASE_PADDLE_HEIGHT))
	snapshot["player_paddle_scale"] = paddle_width / DEFAULT_PADDLE_WIDTH
	snapshot["player_paddle_width"] = paddle_width
	snapshot["player_paddle_height"] = paddle_height
	return snapshot


func build_runtime_base_snapshot(
	special_gauge: float,
	special_gauge_max: float = MAX_GAUGE,
	paddle_base_scale: float = 1.0
) -> Dictionary:
	var ratio: float = get_gauge_ratio(special_gauge, special_gauge_max)
	var paddle_scale: float = get_paddle_scale_for_ratio(ratio)
	var base_scale: float = maxf(0.1, paddle_base_scale)
	var paddle_width: float = BASE_PADDLE_WIDTH * paddle_scale * base_scale
	var paddle_height: float = BASE_PADDLE_HEIGHT * paddle_scale * base_scale
	return {
		"optimus_energy_ratio": ratio,
		"optimus_paddle_scale": paddle_scale,
		"optimus_speed_multiplier": get_player_speed_multiplier_for_ratio(ratio),
		"runtime_paddle_base_width": paddle_width,
		"runtime_paddle_base_height": paddle_height,
	}


func apply_movement_config(
	config: Dictionary,
	special_gauge: float,
	special_gauge_max: float = MAX_GAUGE
) -> Dictionary:
	var next_config: Dictionary = config.duplicate(true)
	var speed_multiplier: float = get_player_speed_multiplier_for_ratio(
		get_gauge_ratio(special_gauge, special_gauge_max)
	)
	for key in ["paddle_speed", "paddle_max_speed", "paddle_accel", "paddle_decel", "paddle_turn_decel"]:
		if next_config.has(key):
			next_config[key] = float(next_config[key]) * speed_multiplier
	return next_config


func get_gauge_ratio(special_gauge: float, special_gauge_max: float = MAX_GAUGE) -> float:
	return clampf(float(special_gauge) / maxf(1.0, special_gauge_max), 0.0, 1.0)


func get_paddle_scale_for_ratio(ratio: float) -> float:
	var min_scale: float = min(1.0, MIN_PADDLE_WIDTH / BASE_PADDLE_WIDTH)
	return min_scale + (1.0 - min_scale) * clamp(ratio, 0.0, 1.0)


func get_player_speed_multiplier_for_ratio(ratio: float) -> float:
	return max(MIN_SPEED_MULTIPLIER, clamp(ratio, 0.0, 1.0))


func is_manual_charge_active() -> bool:
	return manual_charge_active


func is_manual_charge_movement_locked() -> bool:
	return manual_charge_active or manual_charge_lock_seconds > 0.0


func _build_manual_charge_result(
	special_gauge: float,
	started: bool,
	released: bool,
	blocked: bool,
	special_gauge_max: float,
	paddle_base_scale: float
) -> Dictionary:
	var gauge_max: float = maxf(1.0, special_gauge_max)
	var snapshot: Dictionary = build_runtime_base_snapshot(special_gauge, gauge_max, paddle_base_scale)
	snapshot["special_gauge"] = clampf(float(special_gauge), 0.0, gauge_max)
	snapshot["special_gauge_max"] = gauge_max
	snapshot["optimus_energy_initialized"] = true
	snapshot["optimus_charge_started"] = started
	snapshot["optimus_charge_released"] = released
	snapshot["optimus_charge_blocked"] = blocked
	_merge_manual_charge_snapshot(snapshot)
	return snapshot


func _merge_manual_charge_snapshot(snapshot: Dictionary) -> void:
	snapshot["optimus_charge_active"] = manual_charge_active
	snapshot["optimus_charge_hold_seconds"] = manual_charge_hold_seconds
	snapshot["optimus_charge_hold_ratio"] = clamp(manual_charge_hold_seconds / MANUAL_CHARGE_HOLD_SECONDS, 0.0, 1.0)
	snapshot["optimus_charge_lock_seconds"] = manual_charge_lock_seconds
	snapshot["optimus_charge_movement_locked"] = is_manual_charge_movement_locked()


func _safe_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value
