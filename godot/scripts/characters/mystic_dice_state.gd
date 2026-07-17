extends RefCounted

const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")

const PERK_ID := "mystic_dice"
const MAX_USES_PER_RUN := 3
const RAW_ABS_CAP := 9
const STAT_KEYS: Array[String] = MysticDiceRoller.STAT_KEYS

var permanent_raw: Dictionary = {}
var use_count := 0
var revision := 0


func _init() -> void:
	_clear_permanent_raw()


func reset() -> void:
	_clear_permanent_raw()
	use_count = 0
	revision += 1


func can_commit() -> bool:
	return use_count < MAX_USES_PER_RUN


func commit_roll(raw_roll: Dictionary) -> Dictionary:
	if not can_commit():
		return _build_commit_result(false, "use_cap_reached")

	var validated_raw: Dictionary = {}
	var roller := MysticDiceRoller.new()
	for stat_key: String in STAT_KEYS:
		if not raw_roll.has(stat_key) or typeof(raw_roll.get(stat_key)) != TYPE_INT:
			return _build_commit_result(false, "invalid_roll_shape")
		var raw_value := int(raw_roll.get(stat_key, 0))
		var allowed_range: Vector2i = roller.get_allowed_raw_range(stat_key)
		if raw_value < allowed_range.x or raw_value > allowed_range.y:
			return _build_commit_result(false, "roll_value_out_of_range")
		validated_raw[stat_key] = raw_value

	var next_permanent_raw := permanent_raw.duplicate(true)
	for stat_key: String in STAT_KEYS:
		next_permanent_raw[stat_key] = clampi(
			int(next_permanent_raw.get(stat_key, 0)) + int(validated_raw.get(stat_key, 0)),
			-RAW_ABS_CAP,
			RAW_ABS_CAP
		)
	permanent_raw = next_permanent_raw
	use_count += 1
	revision += 1
	return _build_commit_result(true, "committed", validated_raw)


func get_raw(stat_key: String) -> int:
	if stat_key.strip_edges() not in STAT_KEYS:
		return 0
	return clampi(int(permanent_raw.get(stat_key, 0)), -RAW_ABS_CAP, RAW_ABS_CAP)


func get_multiplier(stat_key: String) -> float:
	return 1.0 + float(get_raw(stat_key)) / 100.0


func get_use_count() -> int:
	return use_count


func get_remaining_uses() -> int:
	return maxi(0, MAX_USES_PER_RUN - use_count)


func get_revision() -> int:
	return revision


func get_snapshot() -> Dictionary:
	var multipliers: Dictionary = {}
	for stat_key: String in STAT_KEYS:
		multipliers[stat_key] = get_multiplier(stat_key)
	return {
		"perk_id": PERK_ID,
		"permanent_raw": permanent_raw.duplicate(true),
		"multipliers": multipliers,
		"use_count": use_count,
		"max_uses_per_run": MAX_USES_PER_RUN,
		"remaining_uses": get_remaining_uses(),
		"raw_abs_cap": RAW_ABS_CAP,
		"revision": revision,
	}


func _clear_permanent_raw() -> void:
	permanent_raw.clear()
	for stat_key: String in STAT_KEYS:
		permanent_raw[stat_key] = 0


func _build_commit_result(
	accepted: bool,
	reason: String,
	committed_raw: Dictionary = {}
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"committed_raw": committed_raw.duplicate(true),
		"use_count": use_count,
		"remaining_uses": get_remaining_uses(),
		"revision": revision,
	}
