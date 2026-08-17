extends RefCounted

const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const PERK_ID := "sage_ring"
const ROLL_OVERRIDE_KEY := "hyeonmun_charyeok_roll_unit"
const DEFAULT_TRIGGER_CHANCE_PCT := 5.0

var _active := false
var _level_bonus := 0
var _remaining_sec := 0.0
var _total_duration_sec := 0.0


func try_proc(
	invested_level: int,
	roll_unit: float = -1.0,
	runtime_state: Object = null
) -> Dictionary:
	var level := maxi(0, invested_level)
	if level <= 0:
		return _build_result(false, "not_invested")
	var chance_pct := resolve_trigger_chance_pct(level, runtime_state)
	var resolved_roll := roll_unit if roll_unit >= 0.0 else randf()
	if chance_pct <= 0.0 or resolved_roll >= chance_pct / 100.0:
		var miss := _build_result(false, "chance_failed")
		miss["roll_unit"] = resolved_roll
		miss["trigger_chance_pct"] = chance_pct
		return miss

	var previous_bonus := _level_bonus if _active else 0
	_level_bonus = resolve_level_bonus(level, runtime_state)
	_total_duration_sec = resolve_duration_sec(level, runtime_state)
	_remaining_sec = _total_duration_sec
	_active = _level_bonus > 0 and _total_duration_sec > 0.0
	var result := _build_result(_active, "activated" if _active else "invalid_spec")
	result["previous_level_bonus"] = previous_bonus
	result["roll_unit"] = resolved_roll
	result["trigger_chance_pct"] = chance_pct
	result["refreshed"] = previous_bonus > 0
	return result


func update(delta: float) -> Dictionary:
	if not _active:
		return _build_result(false, "inactive")
	var previous_bonus := _level_bonus
	_remaining_sec = maxf(0.0, _remaining_sec - maxf(0.0, delta))
	if _remaining_sec > 0.0:
		var ticking := _build_result(false, "ticking")
		ticking["was_active"] = true
		ticking["previous_level_bonus"] = previous_bonus
		return ticking
	var expired := reset()
	expired["expired"] = true
	expired["was_active"] = true
	return expired


func reset() -> Dictionary:
	var previous_bonus := _level_bonus if _active else 0
	var changed := _active or _level_bonus > 0 or _remaining_sec > 0.0 or _total_duration_sec > 0.0
	_active = false
	_level_bonus = 0
	_remaining_sec = 0.0
	_total_duration_sec = 0.0
	var result := _build_result(false, "reset")
	result["changed"] = changed
	result["previous_level_bonus"] = previous_bonus
	return result


func is_active() -> bool:
	return _active and _level_bonus > 0 and _remaining_sec > 0.0


func get_level_bonus() -> int:
	return _level_bonus if is_active() else 0


func get_snapshot() -> Dictionary:
	var safe_total := maxf(0.0, _total_duration_sec)
	var safe_remaining := maxf(0.0, _remaining_sec) if is_active() else 0.0
	return {
		"active": is_active(),
		"level_bonus": get_level_bonus(),
		"remaining_sec": safe_remaining,
		"total_duration_sec": safe_total,
		"duration_ratio": clampf(safe_remaining / safe_total, 0.0, 1.0) if safe_total > 0.0 else 0.0,
	}


static func resolve_trigger_chance_pct(invested_level: int, runtime_state: Object = null) -> float:
	var resolved := PerkConversionValues.get_value(
		PERK_ID,
		"trigger_chance_pct",
		maxi(1, invested_level),
		runtime_state
	)
	return resolved if resolved > 0.0 else DEFAULT_TRIGGER_CHANCE_PCT


static func resolve_level_bonus(invested_level: int, runtime_state: Object = null) -> int:
	return maxi(0, int(round(PerkConversionValues.get_value(
		PERK_ID,
		"perk_level_bonus",
		maxi(1, invested_level),
		runtime_state
	))))


static func resolve_duration_sec(invested_level: int, runtime_state: Object = null) -> float:
	return maxf(0.0, PerkConversionValues.get_value(
		PERK_ID,
		"duration_sec",
		maxi(1, invested_level),
		runtime_state
	))


func _build_result(activated: bool, reason: String) -> Dictionary:
	return {
		"activated": activated,
		"reason": reason,
		"active": is_active(),
		"level_bonus": get_level_bonus(),
		"remaining_sec": maxf(0.0, _remaining_sec) if is_active() else 0.0,
		"total_duration_sec": maxf(0.0, _total_duration_sec),
	}
