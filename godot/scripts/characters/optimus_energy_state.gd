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


func prepare_owner_for_optimus(owner: Object) -> Dictionary:
	if owner == null:
		return {}
	var selected: String = str(_safe_get(owner, "selected_character_type", "smasher")).strip_edges().to_lower()
	if selected != "optimus":
		initialized = false
		return {}
	if not bool(_safe_get(owner, "optimus_energy_initialized", false)):
		initialized = true
		drain_buffer = 0.0
		owner.set("optimus_energy_initialized", true)
		owner.set("special_gauge_max", MAX_GAUGE)
		owner.set("special_gauge", MAX_GAUGE)
	else:
		initialized = true
	return build_scale_snapshot(float(_safe_get(owner, "special_gauge", MAX_GAUGE)))


func update_energy(delta: float, special_gauge: float, paused: bool = false) -> Dictionary:
	var next_gauge: float = clamp(float(special_gauge), 0.0, MAX_GAUGE)
	if paused:
		drain_buffer = 0.0
	else:
		drain_buffer += max(0.0, delta) * DRAIN_PER_SECOND
		var drain_units: int = int(drain_buffer)
		if drain_units > 0:
			drain_buffer -= float(drain_units)
			next_gauge = max(0.0, next_gauge - float(drain_units))
	var snapshot: Dictionary = build_scale_snapshot(next_gauge)
	snapshot["special_gauge"] = next_gauge
	snapshot["special_gauge_max"] = MAX_GAUGE
	snapshot["optimus_energy_initialized"] = true
	_merge_manual_charge_snapshot(snapshot)
	return snapshot


func update_manual_charge(
	delta: float,
	down_held: bool,
	special_gauge: float,
	blocked: bool = false
) -> Dictionary:
	var step: float = max(0.0, delta)
	var next_gauge: float = clamp(float(special_gauge), 0.0, MAX_GAUGE)
	var was_active: bool = manual_charge_active
	var started := false
	var released := false
	if manual_charge_lock_seconds > 0.0:
		manual_charge_lock_seconds = max(0.0, manual_charge_lock_seconds - step)

	if blocked:
		manual_charge_hold_seconds = 0.0
		manual_charge_active = false
		return _build_manual_charge_result(next_gauge, false, false, true)

	if down_held and manual_charge_lock_seconds <= 0.0:
		manual_charge_hold_seconds += step
		if not manual_charge_active and manual_charge_hold_seconds >= MANUAL_CHARGE_HOLD_SECONDS:
			manual_charge_active = true
			started = not was_active
		if manual_charge_active:
			next_gauge = min(MAX_GAUGE, next_gauge + MANUAL_CHARGE_RATE_PER_SECOND * step)
	else:
		if was_active:
			manual_charge_lock_seconds = MANUAL_CHARGE_RELEASE_LOCK_SECONDS
			released = true
		manual_charge_hold_seconds = 0.0
		manual_charge_active = false

	return _build_manual_charge_result(next_gauge, started, released, false)


func build_scale_snapshot(special_gauge: float) -> Dictionary:
	var ratio: float = get_gauge_ratio(special_gauge)
	var paddle_scale: float = get_paddle_scale_for_ratio(ratio)
	var paddle_width: float = BASE_PADDLE_WIDTH * paddle_scale
	var paddle_height: float = BASE_PADDLE_HEIGHT * paddle_scale
	return {
		"optimus_energy_ratio": ratio,
		"optimus_paddle_scale": paddle_scale,
		"optimus_speed_multiplier": get_player_speed_multiplier_for_ratio(ratio),
		"runtime_paddle_base_width": paddle_width,
		"runtime_paddle_base_height": paddle_height,
		"player_paddle_scale": paddle_width / DEFAULT_PADDLE_WIDTH,
		"player_paddle_width": paddle_width,
		"player_paddle_height": paddle_height,
	}


func apply_movement_config(config: Dictionary, special_gauge: float) -> Dictionary:
	var next_config: Dictionary = config.duplicate(true)
	var speed_multiplier: float = get_player_speed_multiplier_for_ratio(get_gauge_ratio(special_gauge))
	for key in ["paddle_speed", "paddle_max_speed", "paddle_accel", "paddle_decel", "paddle_turn_decel"]:
		if next_config.has(key):
			next_config[key] = float(next_config[key]) * speed_multiplier
	return next_config


func get_gauge_ratio(special_gauge: float) -> float:
	return clamp(float(special_gauge) / MAX_GAUGE, 0.0, 1.0)


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
	blocked: bool
) -> Dictionary:
	var snapshot: Dictionary = build_scale_snapshot(special_gauge)
	snapshot["special_gauge"] = clamp(float(special_gauge), 0.0, MAX_GAUGE)
	snapshot["special_gauge_max"] = MAX_GAUGE
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
