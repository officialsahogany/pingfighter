extends RefCounted

const ActiveItemDurationBonus := preload("res://scripts/items/active_item_duration_bonus.gd")

const DOPING_POTION_DURATION_FRAMES := 480.0
const DOPING_POTION_HEAD_LEG_MULTIPLIER := 2.0
const DOPING_POTION_FIRE_RATE_MULTIPLIER := 0.5
const DOPING_POTION_PISTOL_COOLDOWN_FRAMES := 30.0
const DOPING_POTION_PISTOL_CONTROL_LOCK_FRAMES := 9.0
const DOPING_POTION_PISTOL_SPEED_MULTIPLIER := 1.2
const DOPING_POTION_BERETTA_COOLDOWN_FRAMES := 15.0
const DOPING_POTION_AK47_FIRE_INTERVAL_FRAMES := 3.0
const DOPING_POTION_BAZOOKA_COOLDOWN_FRAMES := 60.0
const DOPING_POTION_BAZOOKA_CONTROL_LOCK_FRAMES := 15.0
const DOPING_POTION_FLASH_FRAMES := 12.0

var _duration_bonus: Object = ActiveItemDurationBonus.new()


func apply_ammo_box(
	_target: Object,
	_item_data: Dictionary,
	_owner: Object,
	registry: Object,
	effect_feedback: Object
) -> bool:
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return false

	var refilled: Array = []
	if weapon_controller.has_method("refill_all_permanent_to_max"):
		refilled = weapon_controller.refill_all_permanent_to_max()
	else:
		refilled = _fallback_refill_all_permanent_to_max(weapon_controller)
	if refilled.is_empty():
		return false

	effect_feedback.trigger_registry_feedback(registry, false, false, 0.018, 0.65)
	effect_feedback.play_first_audio(registry, ["play_reload", "play_active_item", "play_item_get"])
	return true


func activate_doping_potion(
	target: Object,
	item_data: Dictionary,
	owner: Object,
	registry: Object,
	state_applier: Object,
	player_center_reader: Object,
	effect_feedback: Object
) -> bool:
	if not _has_commando_pistol_access(registry):
		return false

	var base_duration: float = max(
		1.0,
		float(item_data.get("duration", DOPING_POTION_DURATION_FRAMES))
	)
	var duration_frames: float = max(
		1.0,
		float(int(base_duration * max(0.0, _duration_bonus.get_multiplier(registry))))
	)
	var player_center: Vector2 = _read_player_center(
		player_center_reader,
		owner,
		_get_vector2_property(target, "doping_potion_player_center")
	)
	var next_use_count: int = int(target.get("doping_potion_use_count")) + 1
	state_applier.apply_doping_potion_state(target, {
		"active": true,
		"timer_frames": duration_frames,
		"initial_timer_frames": duration_frames,
		"phase": 0.0,
		"flash_timer_frames": DOPING_POTION_FLASH_FRAMES,
		"player_center": player_center,
		"use_count": next_use_count,
	})
	effect_feedback.trigger_registry_feedback(registry, true, false, 0.025, 0.95)
	effect_feedback.play_first_audio(registry, ["play_drink", "play_active_item"])
	return true


func apply_update_doping_potion(
	target: Object,
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	delta: float,
	state_applier: Object
) -> void:
	state_applier.apply_doping_potion_state(target, update_doping_potion(
		active,
		timer_frames,
		initial_timer_frames,
		phase,
		flash_timer_frames,
		player_center,
		int(target.get("doping_potion_use_count")),
		delta
	))


func update_doping_potion(
	active: bool,
	timer_frames: float,
	initial_timer_frames: float,
	phase: float,
	flash_timer_frames: float,
	player_center: Vector2,
	use_count: int,
	delta: float
) -> Dictionary:
	if not active:
		return clear_doping_potion(player_center, use_count)

	var fps_scale: float = max(0.0, delta) * 60.0
	var next_timer: float = max(0.0, timer_frames - fps_scale)
	if next_timer <= 0.0:
		return clear_doping_potion(player_center, use_count)

	return {
		"active": true,
		"timer_frames": next_timer,
		"initial_timer_frames": max(1.0, initial_timer_frames),
		"phase": fmod(phase + 0.22 * fps_scale, TAU),
		"flash_timer_frames": max(0.0, flash_timer_frames - fps_scale),
		"player_center": player_center,
		"use_count": max(0, use_count),
	}


func clear_doping_potion(player_center: Variant = null, use_count: int = 0) -> Dictionary:
	var next_center := Vector2(380.0, 725.0)
	if player_center is Vector2:
		next_center = player_center
	return {
		"active": false,
		"timer_frames": 0.0,
		"initial_timer_frames": 0.0,
		"phase": 0.0,
		"flash_timer_frames": 0.0,
		"player_center": next_center,
		"use_count": max(0, use_count),
	}


func _fallback_refill_all_permanent_to_max(weapon_controller: Object) -> Array:
	var refilled: Array = []
	if weapon_controller == null or not weapon_controller.has_method("get_snapshot"):
		return refilled
	var snapshot: Dictionary = weapon_controller.get_snapshot()
	var permanent_owned: Dictionary = _get_dictionary(snapshot.get("permanent_owned", {}))
	for weapon_id_value in permanent_owned.keys():
		var weapon_id := str(weapon_id_value)
		if weapon_id == "" or weapon_id == "pistol":
			continue
		if (
			weapon_controller.has_method("refill_weapon_to_max")
			and bool(weapon_controller.refill_weapon_to_max(weapon_id))
		):
			refilled.append(weapon_id)
	return refilled


func _has_permanent_weapon(registry: Object, weapon_id: String) -> bool:
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return false
	if weapon_controller.has_method("has_permanent_weapon"):
		return bool(weapon_controller.has_permanent_weapon(weapon_id))
	if not weapon_controller.has_method("get_snapshot"):
		return false
	var snapshot: Dictionary = weapon_controller.get_snapshot()
	var permanent_owned: Dictionary = _get_dictionary(snapshot.get("permanent_owned", {}))
	return permanent_owned.has(weapon_id)


func _has_commando_pistol_access(registry: Object) -> bool:
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return false
	if weapon_controller.has_method("get_weapons"):
		var weapons: Array = weapon_controller.get_weapons()
		if weapons.has("pistol") or weapons.has("commando_pistol"):
			return true
	return _has_permanent_weapon(registry, "commando_pistol")


func _read_player_center(player_center_reader: Object, owner: Object, fallback: Vector2) -> Vector2:
	if owner == null or player_center_reader == null:
		return fallback
	return player_center_reader.get_player_center(owner)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2_property(target: Object, key: String) -> Vector2:
	var value: Variant = target.get(key)
	if value is Vector2:
		return value
	return Vector2(380.0, 725.0)
