extends RefCounted

const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")

const SKILL_NAME := "emergency_supply"
const GAUGE_COST := 150.0
const TAP_WINDOW_MSEC := 250
const SUPPRESS_MSEC := 300

var last_down_pressed := false
var tap_count := 0
var tap_deadline_msec := 0
var suppress_until_msec := 0
var last_result: Dictionary = {}
var _runtime_perk_modal_pause_started_msec := -1


func reset() -> void:
	last_down_pressed = false
	tap_count = 0
	tap_deadline_msec = 0
	suppress_until_msec = 0
	_runtime_perk_modal_pause_started_msec = -1
	last_result.clear()


# 퍽 모달 동안 벽시계 앵커 동결. 규칙은 runtime_perk_modal_time_shift.gd 참조.
func pause_runtime_perk_modal_time(current_msec: int) -> void:
	_runtime_perk_modal_pause_started_msec = RuntimePerkModalTimeShift.begin_pause(
		_runtime_perk_modal_pause_started_msec, current_msec
	)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec: int = _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	shift_runtime_perk_modal_time(pause_started_msec, current_msec)


func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	tap_deadline_msec = RuntimePerkModalTimeShift.shift_anchor(tap_deadline_msec, delta_msec)
	suppress_until_msec = RuntimePerkModalTimeShift.shift_anchor(suppress_until_msec, delta_msec)


func cancel_transient() -> void:
	tap_count = 0
	tap_deadline_msec = 0
	last_result.clear()


func is_supply_drop_hold_suppressed(current_msec: int) -> bool:
	return current_msec < suppress_until_msec


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	deps: Dictionary
) -> Dictionary:
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
		"attempted": false,
		"failure_reason": "",
	}
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var down_just_pressed: bool = down_pressed and not last_down_pressed
	last_down_pressed = down_pressed

	if tap_count > 0 and current_msec > tap_deadline_msec:
		tap_count = 0
		tap_deadline_msec = 0

	if current_msec < suppress_until_msec:
		last_result = result.duplicate(true)
		return result

	if not down_just_pressed:
		last_result = result.duplicate(true)
		return result

	if bool(input_snapshot.get("left_pressed", false)) or bool(input_snapshot.get("right_pressed", false)):
		cancel_transient()
		result["failure_reason"] = "moving"
		last_result = result.duplicate(true)
		return result

	if tap_count == 1 and current_msec <= tap_deadline_msec:
		tap_count = 0
		tap_deadline_msec = 0
		result["attempted"] = true
		var activation: Dictionary = _try_activate(current_msec, special_gauge, deps)
		result.merge(activation, true)
		if bool(result.get("activated", false)):
			suppress_until_msec = current_msec + SUPPRESS_MSEC
		last_result = result.duplicate(true)
		return result

	tap_count = 1
	tap_deadline_msec = current_msec + TAP_WINDOW_MSEC
	result["tap_armed"] = true
	last_result = result.duplicate(true)
	return result


func get_snapshot() -> Dictionary:
	return {
		"last_down_pressed": last_down_pressed,
		"tap_count": tap_count,
		"tap_deadline_msec": tap_deadline_msec,
		"suppress_until_msec": suppress_until_msec,
		"last_result": last_result.duplicate(true),
	}


func _try_activate(current_msec: int, special_gauge: float, deps: Dictionary) -> Dictionary:
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return _failed(special_gauge, "not_equipped")
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return _failed(special_gauge, "gauge")
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return _failed(special_gauge, "cooldown")
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller == null:
		return _failed(special_gauge, "missing_weapon_controller")
	var target: Dictionary = _get_current_weapon_data(weapon_controller)
	var weapon_id: String = str(target.get("weapon_id", ""))
	if weapon_id == "":
		return _failed(special_gauge, "missing_weapon")
	if weapon_id != "pistol" and (bool(target.get("rental", false)) or str(target.get("kind", "")) == "rental"):
		return _failed(special_gauge, "rental_weapon")
	if not _has_refill_room(target):
		return _failed(special_gauge, "full")
	var delivery_state: Object = deps.get("commando_reload_delivery_state", null)
	if delivery_state != null and bool(delivery_state.get("active")):
		return _failed(special_gauge, "delivery_in_progress")
	if not _start_delivery(weapon_id, deps):
		# Fallback: legacy immediate refill so the skill never silently no-ops if the
		# delivery state is unavailable.
		if not _refill_current_weapon(weapon_controller, weapon_id):
			return _failed(special_gauge, "refill_failed")
		_play_reload_audio(deps)

	var cost: float = _get_skill_cost(deps.get("skill_config", null))
	_trigger_cooldown(current_msec, deps)
	_trigger_feedback(deps)
	return {
		"special_gauge": max(0.0, special_gauge - cost),
		"special_gauge_delta": -cost,
		"activated": true,
		"skill_name": SKILL_NAME,
		"weapon_id": weapon_id,
	}


func _start_delivery(weapon_id: String, deps: Dictionary) -> bool:
	var delivery_state: Object = deps.get("commando_reload_delivery_state", null)
	if delivery_state == null or not delivery_state.has_method("start"):
		return false
	var owner: Object = _resolve_delivery_owner(deps)
	# Delivery state owns the activation-time radio cue (see commando_reload_delivery_state.start).
	return bool(delivery_state.start(owner, weapon_id, deps))


func _resolve_delivery_owner(deps: Dictionary) -> Object:
	var owner: Variant = deps.get("delivery_owner", null)
	if typeof(owner) == TYPE_OBJECT and owner != null:
		return owner
	owner = deps.get("owner", null)
	if typeof(owner) == TYPE_OBJECT and owner != null:
		return owner
	owner = deps.get("commando_weapon_controller", null)
	if typeof(owner) == TYPE_OBJECT and owner != null:
		return owner
	return null


func _failed(special_gauge: float, reason: String) -> Dictionary:
	return {
		"special_gauge": special_gauge,
		"special_gauge_delta": 0.0,
		"activated": false,
		"failure_reason": reason,
	}


func _get_current_weapon_data(weapon_controller: Object) -> Dictionary:
	if weapon_controller != null and weapon_controller.has_method("get_current_weapon_data"):
		var value: Variant = weapon_controller.get_current_weapon_data()
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _has_refill_room(weapon_data: Dictionary) -> bool:
	if str(weapon_data.get("weapon_id", "")) == "pistol":
		var base_ammo_current: int = int(weapon_data.get("ammo_current", -1))
		var base_ammo_max: int = int(weapon_data.get("ammo_max", -1))
		return base_ammo_max > 0 and base_ammo_current >= 0 and base_ammo_current < base_ammo_max
	if str(weapon_data.get("weapon_id", "")) == "commando_pistol":
		var commando_pistol_ammo_current: int = int(weapon_data.get("ammo_current", -1))
		var commando_pistol_ammo_max: int = int(weapon_data.get("ammo_max", -1))
		return commando_pistol_ammo_max > 0 and commando_pistol_ammo_current >= 0 and commando_pistol_ammo_current < commando_pistol_ammo_max
	var ammo_current: int = int(weapon_data.get("ammo_current", -1))
	var ammo_max: int = int(weapon_data.get("ammo_max", -1))
	return ammo_max > 0 and ammo_current >= 0 and ammo_current < ammo_max


func _refill_current_weapon(weapon_controller: Object, weapon_id: String) -> bool:
	if weapon_id == "pistol":
		if weapon_controller != null and weapon_controller.has_method("refill_weapon_to_max"):
			return bool(weapon_controller.refill_weapon_to_max("pistol"))
		if weapon_controller != null and weapon_controller.has_method("refill_weapon"):
			return bool(weapon_controller.refill_weapon("pistol", 999))
		return false
	if weapon_controller != null and weapon_controller.has_method("refill_current_permanent_to_max"):
		return bool(weapon_controller.refill_current_permanent_to_max())
	if weapon_controller != null and weapon_controller.has_method("refill_current_permanent"):
		return bool(weapon_controller.refill_current_permanent(1))
	return false


func _play_reload_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_commando_reload"):
		audio.play_commando_reload()
	elif audio.has_method("play_commando_pistol_reload_round"):
		audio.play_commando_pistol_reload_round()
	elif audio.has_method("play_commando_pistol_reload_start"):
		audio.play_commando_pistol_reload_start()


func _get_cooldown_remaining(current_msec: int, deps: Dictionary) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null:
		return 0.0
	if skill_state.has_method("get_configured_cooldown_remaining"):
		return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))
	if skill_state.has_method("get_cooldown_remaining"):
		return float(skill_state.get_cooldown_remaining(SKILL_NAME, current_msec, _get_cooldown_seconds(deps.get("skill_config", null))))
	return 0.0


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _get_cooldown_seconds(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		return float(skill_config.get_cooldown_seconds(SKILL_NAME))
	return 60.0


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
	return false


func _trigger_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.08, 2.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()
