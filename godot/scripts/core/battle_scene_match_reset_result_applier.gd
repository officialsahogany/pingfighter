extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FLOAT_KEYS := {
	"special_gauge": 0.0,
	"special_gauge_max": 500.0,
	"drive_text_timer_frames": 0.0,
	"player_paddle_width": 155.0,
	"player_paddle_height": 50.0,
	"player_paddle_scale": 1.0,
	"player_paddle_visual_scale_override": -1.0,
	"runtime_paddle_base_width": 155.0,
	"runtime_paddle_base_height": 50.0,
	"runtime_paddle_scale": 1.0,
	"boss_paddle_width": 100.0,
	"boss_hitbox_height": 40.0,
	"optimus_energy_ratio": 1.0,
	"optimus_paddle_scale": 1.0,
	"optimus_speed_multiplier": 1.0,
	"optimus_charge_hold_seconds": 0.0,
	"optimus_charge_hold_ratio": 0.0,
	"optimus_charge_lock_seconds": 0.0,
	"sage_ring_speed_penalty_pct": 0.0,
	"sage_ring_body_penalty_pct": 0.0,
	"sage_ring_speed_multiplier": 1.0,
}

const INT_KEYS := {
	"runtime_perk_pending_choices": 0,
	"runtime_perk_starpoints": 0,
	"runtime_perk_gold": 0,
	"runtime_accessory_slot_bonus": 0,
	"runtime_laurel_leaf_count": 0,
	"item_perk_level_bonus": 0,
	"sage_ring_count": 0,
	"sage_ring_perk_level_bonus": 0,
}

const BOOL_KEYS := {
	"runtime_perk_choice_active": false,
	"optimus_energy_initialized": false,
	"optimus_charge_active": false,
	"optimus_charge_movement_locked": false,
	"megingjord_equipped": false,
	"sage_ring_equipped": false,
	"sage_ring_active": false,
}

const ARRAY_KEYS := {
	"active_item_slots": [],
	"passive_item_inventory": [],
}

const DICTIONARY_KEYS := {
	"runtime_perk_levels": {},
	"equipment_slots": {},
	"passive_item_slots": {},
	"equipped_passive_items": {},
	"mythic_item_state": {},
}


func apply_reset_result(owner: Object, result: Dictionary) -> void:
	if owner == null:
		return
	for key in FLOAT_KEYS.keys():
		_apply_float(owner, result, str(key), float(FLOAT_KEYS[key]))
	for key in INT_KEYS.keys():
		_apply_int(owner, result, str(key), int(INT_KEYS[key]))
	for key in BOOL_KEYS.keys():
		_apply_bool(owner, result, str(key), bool(BOOL_KEYS[key]))
	for key in ARRAY_KEYS.keys():
		_apply_array(owner, result, str(key), ARRAY_KEYS[key])
	for key in DICTIONARY_KEYS.keys():
		_apply_dictionary(owner, result, str(key), DICTIONARY_KEYS[key])


func _apply_float(owner: Object, result: Dictionary, key: String, fallback: float) -> void:
	owner.set(key, float(result.get(key, _get_owner_value(owner, key, fallback))))


func _apply_int(owner: Object, result: Dictionary, key: String, fallback: int) -> void:
	owner.set(key, int(result.get(key, _get_owner_value(owner, key, fallback))))


func _apply_bool(owner: Object, result: Dictionary, key: String, fallback: bool) -> void:
	owner.set(key, bool(result.get(key, _get_owner_value(owner, key, fallback))))


func _apply_array(owner: Object, result: Dictionary, key: String, fallback: Array) -> void:
	var value: Variant = result.get(key, _get_owner_value(owner, key, fallback))
	if value is Array:
		var array_value: Array = value
		owner.set(key, array_value.duplicate(true))


func _apply_dictionary(owner: Object, result: Dictionary, key: String, fallback: Dictionary) -> void:
	var value: Variant = result.get(key, _get_owner_value(owner, key, fallback))
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		owner.set(key, dictionary_value.duplicate(true))


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
