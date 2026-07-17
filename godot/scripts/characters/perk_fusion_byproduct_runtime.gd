extends RefCounted

const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")

const OVERLOAD_CIRCUIT_ID := "overload_circuit"
const REVERB_ID := "reverb"
const GOLDEN_TRAJECTORY_ID := "golden_trajectory"
const STATIC_FIELD_ID := "static_field"
const RECYCLE_PROTOCOL_ID := "recycle_protocol"

const OVERLOAD_BOUNCE_SPEED_MULTIPLIER := 1.15
const REVERB_DURATION_SEC := 3.0
const REVERB_MOVE_SPEED_MULTIPLIER := 1.25
const GOLD_PER_WALL_BOUNCE := 2
const GOLDEN_TRAJECTORY_ROUND_CAP := 40
const STATIC_FIELD_DURATION_SEC := 4.0
const RECYCLE_PROTOCOL_CHANCE := 0.25

var _overload_armed := false
var _reverb_remaining_sec := 0.0
var _golden_trajectory_round_gold := 0
var _pending_point_loss_effects: Dictionary = {}


func reset() -> void:
	reset_round()
	_pending_point_loss_effects.clear()


func reset_round() -> void:
	_overload_armed = false
	_reverb_remaining_sec = 0.0
	_golden_trajectory_round_gold = 0


func update(delta: float) -> void:
	if delta <= 0.0 or _reverb_remaining_sec <= 0.0:
		return
	_reverb_remaining_sec = maxf(0.0, _reverb_remaining_sec - delta)


func on_player_dash(owned_ids: Variant) -> void:
	if _owns_byproduct(owned_ids, OVERLOAD_CIRCUIT_ID):
		_overload_armed = true


func consume_player_paddle_bounce_speed_multiplier() -> float:
	if not _overload_armed:
		return 1.0
	_overload_armed = false
	return OVERLOAD_BOUNCE_SPEED_MULTIPLIER


func on_skill_used(owned_ids: Variant) -> void:
	if _owns_byproduct(owned_ids, REVERB_ID):
		_reverb_remaining_sec = REVERB_DURATION_SEC


func get_player_move_speed_multiplier() -> float:
	return REVERB_MOVE_SPEED_MULTIPLIER if _reverb_remaining_sec > 0.0 else 1.0


func on_wall_bounce(owned_ids: Variant) -> int:
	var award := get_wall_bounce_gold_offer(owned_ids)
	record_wall_bounce_gold(award)
	return award


func get_wall_bounce_gold_offer(owned_ids: Variant) -> int:
	if not _owns_byproduct(owned_ids, GOLDEN_TRAJECTORY_ID):
		return 0
	var remaining_gold: int = GOLDEN_TRAJECTORY_ROUND_CAP - _golden_trajectory_round_gold
	if remaining_gold <= 0:
		return 0
	return mini(GOLD_PER_WALL_BOUNCE, remaining_gold)


func record_wall_bounce_gold(actual_award: int) -> void:
	var remaining_gold := maxi(0, GOLDEN_TRAJECTORY_ROUND_CAP - _golden_trajectory_round_gold)
	_golden_trajectory_round_gold += mini(maxi(0, actual_award), remaining_gold)


func get_remaining_wall_bounce_gold() -> int:
	return maxi(0, GOLDEN_TRAJECTORY_ROUND_CAP - _golden_trajectory_round_gold)


func get_round_golden_trajectory_gold() -> int:
	return _golden_trajectory_round_gold


func on_player_point_lost(owned_ids: Variant, recycle_roll_unit: float) -> Dictionary:
	var result := {
		"restore_dash_tokens": false,
	}
	if _owns_byproduct(owned_ids, STATIC_FIELD_ID):
		result["static_field"] = {
			"boss_slow_multiplier": BossSlowTiers.WEAK,
			"duration_sec": STATIC_FIELD_DURATION_SEC,
		}
	if _owns_byproduct(owned_ids, RECYCLE_PROTOCOL_ID):
		# The caller supplies exactly one roll for this point-loss event. Keeping
		# randomness outside this state object prevents per-frame rerolls.
		result["restore_dash_tokens"] = recycle_roll_unit < RECYCLE_PROTOCOL_CHANCE
	return result


func queue_player_point_lost(owned_ids: Variant, recycle_roll_unit: float) -> Dictionary:
	_pending_point_loss_effects = on_player_point_lost(owned_ids, recycle_roll_unit).duplicate(true)
	return _pending_point_loss_effects.duplicate(true)


func consume_pending_point_loss_effects() -> Dictionary:
	var result: Dictionary = _pending_point_loss_effects.duplicate(true)
	_pending_point_loss_effects.clear()
	return result


func get_snapshot() -> Dictionary:
	return {
		"overload_armed": _overload_armed,
		"reverb_remaining_sec": _reverb_remaining_sec,
		"golden_trajectory_round_gold": _golden_trajectory_round_gold,
		"pending_point_loss_effects": _pending_point_loss_effects.duplicate(true),
	}.duplicate(true)


func _owns_byproduct(owned_ids: Variant, byproduct_id: String) -> bool:
	match typeof(owned_ids):
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return byproduct_id in owned_ids
		TYPE_DICTIONARY:
			var owned_lookup: Dictionary = owned_ids as Dictionary
			return owned_lookup.has(byproduct_id) and bool(owned_lookup.get(byproduct_id, false))
	return false
