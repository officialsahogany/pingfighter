extends RefCounted

const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")
const PerkFusionReverbVfxState := preload("res://scripts/characters/perk_fusion_reverb_vfx_state.gd")
const PerkFusionReturningLightStepState := preload("res://scripts/characters/perk_fusion_returning_light_step_state.gd")
const PerkFusionSpellbreakerGuardState := preload("res://scripts/characters/perk_fusion_spellbreaker_guard_state.gd")

const OVERLOAD_CIRCUIT_ID := "overload_circuit"
const REVERB_ID := "reverb"
const GOLDEN_TRAJECTORY_ID := "golden_trajectory"
const STATIC_FIELD_ID := "static_field"
const RECYCLE_PROTOCOL_ID := "recycle_protocol"
const LINKED_ARSENAL_ID := "linked_arsenal"

const THUNDER_DRIVE_TRIGGER_CHANCE := 0.15
const THUNDER_DRIVE_SPEED_MULTIPLIER := 1.80
const REVERB_DURATION_SEC := 3.0
const REVERB_MOVE_SPEED_MULTIPLIER := 1.70
const GOLD_PER_WALL_BOUNCE := 2
const GOLDEN_TRAJECTORY_ROUND_CAP := 40
const STATIC_FIELD_DURATION_SEC := 4.0
const RECYCLE_PROTOCOL_CHANCE := 0.25

var _thunder_drive_active := false
var _thunder_drive_restore_effective_speed := 0.0
var _reverb_remaining_sec := 0.0
var _golden_trajectory_round_gold := 0
var _pending_point_loss_effects: Dictionary = {}
var _reverb_vfx_state: Object = PerkFusionReverbVfxState.new()
var _returning_light_step_state: Object = PerkFusionReturningLightStepState.new()
var _spellbreaker_guard_state: Object = PerkFusionSpellbreakerGuardState.new()


func reset() -> void:
	reset_round()
	_pending_point_loss_effects.clear()
	_reverb_vfx_state.reset_all()
	_returning_light_step_state.reset_all()
	_spellbreaker_guard_state.reset_all()


func reset_round() -> void:
	_thunder_drive_active = false
	_thunder_drive_restore_effective_speed = 0.0
	_reverb_remaining_sec = 0.0
	_golden_trajectory_round_gold = 0
	_reverb_vfx_state.reset_round()
	_returning_light_step_state.reset_round()
	_spellbreaker_guard_state.reset_round()


func update(
	delta: float,
	owned_ids: Variant = [],
	owner: Object = null,
	dash_state: Object = null,
	player_guard_available: bool = true
) -> Dictionary:
	if delta > 0.0 and _reverb_remaining_sec > 0.0:
		_reverb_remaining_sec = maxf(0.0, _reverb_remaining_sec - delta)
	_reverb_vfx_state.advance(delta, owner, _reverb_remaining_sec > 0.0)
	var result: Dictionary = _returning_light_step_state.advance(
		delta,
		owned_ids,
		owner,
		dash_state,
		player_guard_available
	)
	_spellbreaker_guard_state.advance(delta, owner)
	result["request_redraw"] = has_visible_effects()
	return result


func has_visible_effects() -> bool:
	return (
		bool(_reverb_vfx_state.has_visible_effects())
		or bool(_returning_light_step_state.has_visible_effects())
		or bool(_spellbreaker_guard_state.has_visible_effects())
	)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	_reverb_vfx_state.draw(canvas, shake_offset)
	_returning_light_step_state.draw(canvas, shake_offset)
	_spellbreaker_guard_state.draw(canvas, shake_offset)


func can_activate_spellbreaker_guard(owned_ids: Variant) -> bool:
	return _owns_byproduct(owned_ids, "spellbreaker_guard") and not _spellbreaker_guard_state.is_active()


func try_activate_spellbreaker_guard(
	owned_ids: Variant,
	roll_unit: float,
	player_center: Vector2
) -> Dictionary:
	return _spellbreaker_guard_state.try_activate(owned_ids, roll_unit, player_center).duplicate(true)


func is_spellbreaker_guard_active() -> bool:
	return bool(_spellbreaker_guard_state.is_active())


func try_parry_boss_skill(skill_id: String, skill_label: String, impact_pos: Vector2) -> Dictionary:
	return _spellbreaker_guard_state.try_parry(skill_id, skill_label, impact_pos).duplicate(true)


func on_player_dash(_owned_ids: Variant) -> void:
	# Compatibility hook: dash start used to arm this byproduct. The redesigned
	# effect rolls only when a live dash actually connects with the ball.
	pass


func can_trigger_dash_paddle_speed_boost(owned_ids: Variant) -> bool:
	return (
		_owns_byproduct(owned_ids, OVERLOAD_CIRCUIT_ID)
		and not _thunder_drive_active
	)


func try_trigger_dash_paddle_speed_boost(
	owned_ids: Variant,
	roll_unit: float,
	restore_effective_speed: float
) -> Dictionary:
	var result := {
		"triggered": false,
		"speed_multiplier": 1.0,
		"restore_effective_speed": 0.0,
	}
	if not can_trigger_dash_paddle_speed_boost(owned_ids):
		return result
	if clampf(roll_unit, 0.0, 1.0) >= THUNDER_DRIVE_TRIGGER_CHANCE:
		return result
	var normalized_restore_speed := maxf(0.0, restore_effective_speed)
	if normalized_restore_speed <= 0.001:
		return result
	_thunder_drive_active = true
	_thunder_drive_restore_effective_speed = normalized_restore_speed
	result["triggered"] = true
	result["speed_multiplier"] = THUNDER_DRIVE_SPEED_MULTIPLIER
	result["restore_effective_speed"] = normalized_restore_speed
	return result


func consume_boss_guard_restore_effective_speed() -> float:
	if not _thunder_drive_active:
		return 0.0
	var restore_speed := _thunder_drive_restore_effective_speed
	_thunder_drive_active = false
	_thunder_drive_restore_effective_speed = 0.0
	return restore_speed


func on_skill_used(owned_ids: Variant) -> void:
	if _owns_byproduct(owned_ids, REVERB_ID):
		_reverb_remaining_sec = REVERB_DURATION_SEC
		_reverb_vfx_state.trigger()


func get_player_move_speed_multiplier() -> float:
	return REVERB_MOVE_SPEED_MULTIPLIER if _reverb_remaining_sec > 0.0 else 1.0


func get_active_item_slot_bonus(owned_ids: Variant, dash_amplification_count: int) -> int:
	var breakdown: Dictionary = get_active_item_slot_bonus_breakdown(
		owned_ids,
		dash_amplification_count
	)
	var total := 0
	for value: Variant in breakdown.values():
		total += int(value)
	return total


func get_active_item_slot_bonus_breakdown(
	owned_ids: Variant,
	dash_amplification_count: int
) -> Dictionary:
	var result: Dictionary = {}
	if _owns_byproduct(owned_ids, LINKED_ARSENAL_ID):
		var linked_bonus := maxi(0, dash_amplification_count)
		if linked_bonus > 0:
			result[LINKED_ARSENAL_ID] = linked_bonus
	return result


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
	var result := {
		"thunder_drive_active": _thunder_drive_active,
		"thunder_drive_restore_effective_speed": _thunder_drive_restore_effective_speed,
		"reverb_remaining_sec": _reverb_remaining_sec,
		"golden_trajectory_round_gold": _golden_trajectory_round_gold,
		"pending_point_loss_effects": _pending_point_loss_effects.duplicate(true),
	}
	result.merge(_reverb_vfx_state.get_snapshot(), true)
	result.merge(_returning_light_step_state.get_snapshot(), true)
	result.merge(_spellbreaker_guard_state.get_snapshot(), true)
	return result.duplicate(true)


func _owns_byproduct(owned_ids: Variant, byproduct_id: String) -> bool:
	match typeof(owned_ids):
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return byproduct_id in owned_ids
		TYPE_DICTIONARY:
			var owned_lookup: Dictionary = owned_ids as Dictionary
			return owned_lookup.has(byproduct_id) and bool(owned_lookup.get(byproduct_id, false))
	return false
