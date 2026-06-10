extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BASE_WEAPON := "pistol"
const PISTOL_ORB_SKILL := "commando_pistol"
const PISTOL_AMMO_MAX := 5
const PISTOL_RELOAD_FRAMES := 120.0
const BERETTA_AMMO_MAX := 12
const AK47_AMMO_MAX := 90
const AK47_DURATION_FRAMES := 1800.0
const BAZOOKA_AMMO_MAX := 4
const NET_GUN_AMMO_MAX := 4
const FIRE_SUPPORT_AMMO_MAX := 2
const BOWLING_TRAP_AMMO_MAX := 3
const SUICIDE_DRONE_AMMO_MAX := 4
const PERMANENT_WEAPONS := [
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
	"bazooka",
	"ak47",
	PISTOL_ORB_SKILL,
]
const SAVE_SNAPSHOT_VERSION := 1
const HUD_HIGHLIGHT_DURATION_FRAMES := 180.0

const WEAPON_DATA := {
	"pistol": {
		"display_name_ko": "권총",
		"kind": "base",
		"ammo_current": PISTOL_AMMO_MAX,
		"ammo_max": PISTOL_AMMO_MAX,
		"reloading": false,
		"reload_timer_frames": 0.0,
		"reload_total_frames": PISTOL_RELOAD_FRAMES,
		"reload_display_ammo": PISTOL_AMMO_MAX,
		"status_label": "탄약",
	},
	"commando_pistol": {
		"display_name_ko": "베레타",
		"kind": "owned",
		"ammo_current": BERETTA_AMMO_MAX,
		"ammo_max": BERETTA_AMMO_MAX,
		"magazines_current": 0,
		"magazines_max": 0,
		"reloading": false,
		"reload_timer_frames": 0.0,
		"reload_total_frames": PISTOL_RELOAD_FRAMES,
		"status_label": "탄약",
	},
	"net_gun": {
		"display_name_ko": "그물덫총",
		"kind": "owned",
		"ammo_current": NET_GUN_AMMO_MAX,
		"ammo_max": NET_GUN_AMMO_MAX,
		"status_label": "탄환",
	},
	"fire_support": {
		"display_name_ko": "화력지원",
		"kind": "owned",
		"ammo_current": FIRE_SUPPORT_AMMO_MAX,
		"ammo_max": FIRE_SUPPORT_AMMO_MAX,
		"status_label": "호출권",
	},
	"bowling_trap": {
		"display_name_ko": "볼링트랩",
		"kind": "owned",
		"ammo_current": BOWLING_TRAP_AMMO_MAX,
		"ammo_max": BOWLING_TRAP_AMMO_MAX,
		"status_label": "탄환",
	},
	"suicide_drone": {
		"display_name_ko": "자폭드론",
		"kind": "owned",
		"ammo_current": SUICIDE_DRONE_AMMO_MAX,
		"ammo_max": SUICIDE_DRONE_AMMO_MAX,
		"status_label": "탄환",
	},
	"bazooka": {
		"display_name_ko": "바주카포",
		"kind": "owned",
		"ammo_current": BAZOOKA_AMMO_MAX,
		"ammo_max": BAZOOKA_AMMO_MAX,
		"status_label": "탄약",
	},
	"ak47": {
		"display_name_ko": "AK-47",
		"kind": "owned",
		"ammo_current": AK47_AMMO_MAX,
		"ammo_max": AK47_AMMO_MAX,
		"duration_frames": AK47_DURATION_FRAMES,
		"duration_max_frames": AK47_DURATION_FRAMES,
		"status_label": "탄약",
	},
}

var permanent_owned: Dictionary = {}
var equipped_permanent: Array = []
var rental_weapons: Dictionary = {}
var base_weapon_runtime: Dictionary = {}
var current_weapon_id := BASE_WEAPON
var prepared_stage_id := 0
var last_switch_msec := -100000
var switch_debounce_msec := 80
var hud_highlight_weapon_id := ""
var hud_highlight_timer_frames := 0.0
var hud_highlight_max_frames := HUD_HIGHLIGHT_DURATION_FRAMES


func _init() -> void:
	base_weapon_runtime = _get_base_weapon_data(BASE_WEAPON)


func reset() -> void:
	permanent_owned.clear()
	equipped_permanent.clear()
	rental_weapons.clear()
	base_weapon_runtime = _get_base_weapon_data(BASE_WEAPON)
	current_weapon_id = BASE_WEAPON
	prepared_stage_id = 0
	last_switch_msec = -100000
	_clear_hud_highlight()


func get_snapshot() -> Dictionary:
	return {
		"permanent_owned": permanent_owned.duplicate(true),
		"equipped_permanent": equipped_permanent.duplicate(),
		"rental_weapons": rental_weapons.duplicate(true),
		"base_weapon_runtime": _get_weapon_runtime_data(BASE_WEAPON),
		"weapons": get_weapons(),
		"current_weapon_id": current_weapon_id,
		"current_weapon": get_current_weapon_data(),
		"prepared_stage_id": prepared_stage_id,
		"last_switch_msec": last_switch_msec,
		"hud_highlight_state": get_hud_highlight_state(),
	}


func get_save_snapshot() -> Dictionary:
	return {
		"version": SAVE_SNAPSHOT_VERSION,
		"permanent_owned": permanent_owned.duplicate(true),
		"equipped_permanent": equipped_permanent.duplicate(),
		"rental_weapons": rental_weapons.duplicate(true),
		"current_weapon_id": current_weapon_id,
		"prepared_stage_id": prepared_stage_id,
		"last_switch_msec": last_switch_msec,
	}


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary) -> Dictionary:
	reset()
	if snapshot.is_empty():
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	var dropped_ids: Array = []
	_restore_permanent_owned(snapshot.get("permanent_owned", {}), dropped_ids)
	_restore_equipped_permanent(snapshot.get("equipped_permanent", []), dropped_ids)
	_restore_rental_weapons(snapshot.get("rental_weapons", {}), dropped_ids)
	prepared_stage_id = max(0, int(snapshot.get("prepared_stage_id", 0)))
	last_switch_msec = int(snapshot.get("last_switch_msec", -100000))

	var selected_id: String = _normalize_weapon_id(snapshot.get("current_weapon_id", BASE_WEAPON))
	current_weapon_id = selected_id if get_weapons().has(selected_id) else BASE_WEAPON
	_reconcile_current_weapon()
	return {
		"restored": true,
		"permanent_count": permanent_owned.size(),
		"rental_count": rental_weapons.size(),
		"dropped_ids": dropped_ids,
		"current_weapon_id": current_weapon_id,
	}


func restore_save_snapshot(snapshot: Dictionary) -> Dictionary:
	return apply_save_snapshot(snapshot)


func get_weapons() -> Array:
	var result: Array = [BASE_WEAPON]
	for weapon_id in equipped_permanent:
		if _is_valid_permanent_weapon(str(weapon_id)) and not result.has(str(weapon_id)):
			result.append(str(weapon_id))
	for weapon_id in rental_weapons.keys():
		var id := str(weapon_id)
		if not result.has(id):
			result.append(id)
	return result


func get_current_weapon_data() -> Dictionary:
	return get_weapon_data(current_weapon_id)


func get_weapon_data(weapon_id: String) -> Dictionary:
	var id: String = _normalize_weapon_id(weapon_id)
	var data: Dictionary = _get_base_weapon_data(id)
	if id == BASE_WEAPON:
		data.merge(_get_weapon_runtime_data(id), true)
	if rental_weapons.has(id):
		var rental: Dictionary = _get_dict(rental_weapons[id])
		data.merge(rental, true)
		data["kind"] = "rental"
		data["rental"] = true
		data["badge"] = "대여"
	elif permanent_owned.has(id):
		var owned: Dictionary = _get_dict(permanent_owned[id])
		data.merge(owned, true)
		data["kind"] = "owned"
		data["rental"] = false
		data["badge"] = "영구"
	else:
		data["rental"] = false
		data["badge"] = "기본" if id == BASE_WEAPON else ""
	data["weapon_id"] = id
	if id == PISTOL_ORB_SKILL:
		_apply_pistol_display_fields(data)
	elif id == "ak47":
		_apply_ak47_display_fields(data)
	data["can_fire"] = can_fire(id)
	data["ammo_text"] = get_weapon_ammo_text(id)
	return data


func unlock_permanent_weapon(weapon_id: String, equip: bool = true) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if not _is_valid_permanent_weapon(id):
		return false
	if not permanent_owned.has(id):
		permanent_owned[id] = _get_base_weapon_data(id)
	if equip and not equipped_permanent.has(id):
		equipped_permanent.append(id)
	if rental_weapons.has(id):
		rental_weapons.erase(id)
	_reconcile_current_weapon()
	return true


func sync_equipped_permanent(skill_config: Object) -> void:
	if skill_config == null or not skill_config.has_method("get_snapshot"):
		return
	var snapshot: Dictionary = skill_config.get_snapshot()
	var next_equipped: Array = []
	var equipped: Variant = snapshot.get("equipped_permanent", [])
	if equipped is Array:
		for value in equipped:
			var weapon_id := str(value)
			if _is_valid_permanent_weapon(weapon_id):
				unlock_permanent_weapon(weapon_id, false)
				next_equipped.append(weapon_id)
	equipped_permanent = next_equipped
	_reconcile_current_weapon()


func reset_round() -> Dictionary:
	_reconcile_current_weapon()
	return {
		"round_reset": true,
		"permanent_weapons_preserved": permanent_owned.keys().duplicate(),
		"rental_weapons_preserved": rental_weapons.keys().duplicate(),
	}


func update_timers(fps_scale: float = 1.0) -> Dictionary:
	var step: float = max(0.0, float(fps_scale))
	_update_hud_highlight_timer(step)
	var base_result: Dictionary = _update_base_pistol_reload(step)
	var pistol_result: Dictionary = _update_pistol_reload(step)
	return {
		"base_pistol": base_result,
		"commando_pistol": pistol_result,
		"hud_highlight": get_hud_highlight_state(),
	}


func prepare_stage_start(stage_id: int, force: bool = false) -> Dictionary:
	var normalized_stage: int = int(max(1, int(stage_id)))
	if prepared_stage_id == normalized_stage and not force:
		return {
			"stage_start": false,
			"stage": normalized_stage,
			"removed_rentals": [],
			"refilled_permanent": [],
			"refilled_base_weapon": false,
			"preserved_permanent": permanent_owned.keys().duplicate(),
		}

	var removed_rentals := remove_stage_rentals(normalized_stage)
	var refilled_base_weapon := refill_weapon_to_max(BASE_WEAPON)
	prepared_stage_id = normalized_stage
	_reconcile_current_weapon()
	return {
		"stage_start": true,
		"stage": normalized_stage,
		"removed_rentals": removed_rentals,
		"refilled_permanent": [],
		"refilled_base_weapon": refilled_base_weapon,
		"preserved_permanent": permanent_owned.keys().duplicate(),
	}


func add_rental_weapon(weapon_id: String, acquired_stage: int = 1, ammo: int = -1, set_active: bool = false, highlight_hud: bool = false) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if id == BASE_WEAPON or permanent_owned.has(id):
		return false
	var data: Dictionary = _get_base_weapon_data(id)
	if data.is_empty():
		return false
	if ammo >= 0:
		data["ammo_current"] = ammo
	data["kind"] = "rental"
	data["acquired_stage"] = max(1, acquired_stage)
	data["badge"] = "대여"
	rental_weapons[id] = data
	_reconcile_current_weapon()
	if set_active and get_weapons().has(id):
		current_weapon_id = id
		last_switch_msec = Time.get_ticks_msec()
	if highlight_hud:
		trigger_hud_highlight(id)
	return true


func remove_stage_rentals(next_stage: int) -> Array:
	var removed: Array = []
	for weapon_id in rental_weapons.keys():
		var data: Dictionary = _get_dict(rental_weapons[weapon_id])
		if int(data.get("acquired_stage", next_stage)) != int(next_stage):
			removed.append(str(weapon_id))
	for weapon_id in removed:
		rental_weapons.erase(str(weapon_id))
	_reconcile_current_weapon()
	return removed


func clear_rentals() -> void:
	rental_weapons.clear()
	_reconcile_current_weapon()


func trigger_hud_highlight(weapon_id: String = "", duration_frames: float = HUD_HIGHLIGHT_DURATION_FRAMES) -> bool:
	var id: String = current_weapon_id if weapon_id.is_empty() else _normalize_weapon_id(weapon_id)
	if not get_weapons().has(id):
		return false
	hud_highlight_weapon_id = id
	hud_highlight_max_frames = max(1.0, float(duration_frames))
	hud_highlight_timer_frames = hud_highlight_max_frames
	return true


func get_hud_highlight_state() -> Dictionary:
	var safe_max: float = max(1.0, hud_highlight_max_frames)
	var timer: float = clamp(hud_highlight_timer_frames, 0.0, safe_max)
	return {
		"active": timer > 0.0,
		"weapon_id": hud_highlight_weapon_id,
		"timer_frames": timer,
		"timer_max_frames": safe_max,
		"ratio": clamp(timer / safe_max, 0.0, 1.0),
	}


func cycle_weapon(direction: int, now_msec: int = -1) -> String:
	if _is_current_weapon_reloading():
		return current_weapon_id
	var time_now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	if time_now - last_switch_msec < switch_debounce_msec:
		return current_weapon_id
	var weapons: Array = get_weapons()
	if weapons.is_empty():
		current_weapon_id = BASE_WEAPON
		return current_weapon_id
	var current_index: int = weapons.find(current_weapon_id)
	if current_index < 0:
		current_index = 0
	var next_index: int = (current_index + int(sign(direction))) % weapons.size()
	if next_index < 0:
		next_index += weapons.size()
	current_weapon_id = str(weapons[next_index])
	last_switch_msec = time_now
	return current_weapon_id


func set_current_weapon(weapon_id: String) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if id != current_weapon_id and _is_current_weapon_reloading():
		return false
	if not get_weapons().has(id):
		return false
	current_weapon_id = id
	return true


func select_base_weapon(now_msec: int = -1) -> bool:
	if not set_current_weapon(BASE_WEAPON):
		return false
	last_switch_msec = Time.get_ticks_msec() if now_msec < 0 else now_msec
	return true


func get_last_switch_msec() -> int:
	return last_switch_msec


func can_fire(weapon_id: String = "") -> bool:
	var id: String = current_weapon_id if weapon_id == "" else _normalize_weapon_id(weapon_id)
	var data: Dictionary = _get_weapon_runtime_data(id)
	if id == BASE_WEAPON and bool(data.get("reloading", false)):
		return false
	var ammo_current: int = int(data.get("ammo_current", -1))
	return ammo_current != 0


func consume_current_weapon_ammo(amount: int = 1) -> bool:
	var id: String = current_weapon_id
	var target: Dictionary = _get_weapon_runtime_data(id)
	if target.is_empty():
		return false
	if id == BASE_WEAPON and bool(target.get("reloading", false)):
		return false
	var ammo_current: int = int(target.get("ammo_current", -1))
	if ammo_current == 0:
		return false
	if ammo_current > 0:
		target["ammo_current"] = max(0, ammo_current - max(1, amount))
		_set_weapon_runtime_data(id, target)
		if int(target["ammo_current"]) <= 0 and rental_weapons.has(id):
			rental_weapons.erase(id)
			_reconcile_current_weapon()
	return true


func consume_current_weapon_duration(frames: float = 1.0) -> bool:
	return consume_weapon_duration(current_weapon_id, frames)


func consume_weapon_duration(weapon_id: String, frames: float = 1.0) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if id != "ak47":
		return false
	var target: Dictionary = _get_weapon_runtime_data(id)
	if target.is_empty():
		return false
	var duration_max: float = max(0.0, float(target.get("duration_max_frames", AK47_DURATION_FRAMES)))
	var duration_frames: float = clamp(float(target.get("duration_frames", duration_max)), 0.0, duration_max)
	if duration_frames <= 0.0:
		target["duration_frames"] = 0.0
		_set_weapon_runtime_data(id, target)
		return false
	target["duration_frames"] = max(0.0, duration_frames - max(0.0, float(frames)))
	_set_weapon_runtime_data(id, target)
	return true


func refill_weapon(weapon_id: String, amount: int = 1) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if rental_weapons.has(id):
		return false
	var target: Dictionary = _get_weapon_runtime_data(id)
	if target.is_empty():
		return false
	if id == BASE_WEAPON:
		return _refill_basic_ammo(id, target, amount)
	if id == PISTOL_ORB_SKILL:
		return _refill_basic_ammo(id, target, amount)
	if id == "ak47":
		var changed_ak47 := _refill_ak47_ammo(target, amount)
		if changed_ak47:
			_set_weapon_runtime_data(id, target)
		return changed_ak47
	var ammo_max: int = int(target.get("ammo_max", -1))
	var ammo_current: int = int(target.get("ammo_current", -1))
	if ammo_max < 0 or ammo_current < 0 or ammo_current >= ammo_max:
		return false
	target["ammo_current"] = min(ammo_max, ammo_current + max(1, amount))
	_set_weapon_runtime_data(id, target)
	return true


func refill_weapon_to_max(weapon_id: String) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if rental_weapons.has(id):
		return false
	var target: Dictionary = _get_weapon_runtime_data(id)
	if target.is_empty():
		return false
	if id == BASE_WEAPON:
		return _refill_basic_ammo_to_max(id, target)
	if id == PISTOL_ORB_SKILL:
		var changed := _refill_pistol_to_max(target)
		if changed:
			_set_weapon_runtime_data(id, target)
		return changed
	if id == "ak47":
		var changed_ak47 := _refill_ak47_to_max(target)
		if changed_ak47:
			_set_weapon_runtime_data(id, target)
		return changed_ak47
	var ammo_max: int = int(target.get("ammo_max", -1))
	var ammo_current: int = int(target.get("ammo_current", -1))
	if ammo_max < 0 or ammo_current < 0 or ammo_current >= ammo_max:
		return false
	target["ammo_current"] = ammo_max
	_set_weapon_runtime_data(id, target)
	return true


func refill_current_permanent(amount: int = 1) -> bool:
	return refill_weapon(current_weapon_id, amount)


func refill_current_permanent_to_max() -> bool:
	return refill_weapon_to_max(current_weapon_id)


func refill_all_permanent_to_max() -> Array:
	var refilled: Array = _refill_all_permanent_to_max()
	_reconcile_current_weapon()
	return refilled


func has_permanent_weapon(weapon_id: String) -> bool:
	return permanent_owned.has(_normalize_weapon_id(weapon_id))


func has_any_permanent_weapon() -> bool:
	return not permanent_owned.is_empty()


func start_current_weapon_reload() -> bool:
	return start_weapon_reload(current_weapon_id)


func start_weapon_reload(weapon_id: String) -> bool:
	var id: String = _normalize_weapon_id(weapon_id)
	if id == BASE_WEAPON:
		return _start_base_pistol_reload()
	return false


func _refill_all_permanent_to_max() -> Array:
	var refilled: Array = []
	for raw_weapon_id in permanent_owned.keys():
		var weapon_id := str(raw_weapon_id)
		var data := _get_dict(permanent_owned.get(weapon_id, {})).duplicate(true)
		if weapon_id == PISTOL_ORB_SKILL:
			if _refill_pistol_to_max(data):
				permanent_owned[weapon_id] = data
				refilled.append(weapon_id)
			continue
		if weapon_id == "ak47":
			if _refill_ak47_to_max(data):
				permanent_owned[weapon_id] = data
				refilled.append(weapon_id)
			continue
		var ammo_max := int(data.get("ammo_max", -1))
		var ammo_current := int(data.get("ammo_current", -1))
		if ammo_max < 0 or ammo_current < 0:
			continue
		if ammo_current >= ammo_max:
			continue
		data["ammo_current"] = ammo_max
		permanent_owned[weapon_id] = data
		refilled.append(weapon_id)
	return refilled


func get_weapon_ammo_text(weapon_id: String = "") -> String:
	var id: String = current_weapon_id if weapon_id == "" else _normalize_weapon_id(weapon_id)
	var data: Dictionary = _get_weapon_runtime_data(id)
	if id == BASE_WEAPON:
		return _get_base_pistol_ammo_text(data)
	if id == PISTOL_ORB_SKILL:
		return _get_pistol_ammo_text(data)
	if id == "ak47":
		return _get_ak47_ammo_text(data)
	var ammo_current: int = int(data.get("ammo_current", -1))
	var ammo_max: int = int(data.get("ammo_max", -1))
	if ammo_current < 0 or ammo_max < 0:
		return LanguageSettings.translate_text("무제한")
	var label: String = LanguageSettings.translate_text(str(data.get("status_label", "탄약")))
	return "%s %d/%d" % [label, ammo_current, ammo_max]


func _update_pistol_reload(fps_scale: float) -> Dictionary:
	var result := {
		"reloading": false,
		"completed": false,
		"reload_rounds_added": 0,
	}
	if fps_scale <= 0.0 or not permanent_owned.has(PISTOL_ORB_SKILL):
		return result
	var data: Dictionary = _get_dict(permanent_owned.get(PISTOL_ORB_SKILL, {})).duplicate(true)
	if bool(data.get("reloading", false)) or float(data.get("reload_timer_frames", 0.0)) > 0.0:
		data["reloading"] = false
		data["reload_timer_frames"] = 0.0
		data["reload_display_ammo"] = int(data.get("ammo_current", BERETTA_AMMO_MAX))
		permanent_owned[PISTOL_ORB_SKILL] = data
	return result


func _start_base_pistol_reload() -> bool:
	var target: Dictionary = _get_weapon_runtime_data(BASE_WEAPON)
	if target.is_empty() or bool(target.get("reloading", false)):
		return false
	var ammo_current: int = int(target.get("ammo_current", 0))
	var ammo_max: int = int(target.get("ammo_max", PISTOL_AMMO_MAX))
	if ammo_current >= ammo_max:
		return false
	target["reloading"] = true
	target["reload_timer_frames"] = PISTOL_RELOAD_FRAMES
	target["reload_total_frames"] = PISTOL_RELOAD_FRAMES
	target["reload_display_ammo"] = clampi(ammo_current, 0, ammo_max)
	_set_weapon_runtime_data(BASE_WEAPON, target)
	return true


func _update_base_pistol_reload(fps_scale: float) -> Dictionary:
	var result := {
		"reloading": false,
		"completed": false,
		"reload_rounds_added": 0,
	}
	if fps_scale <= 0.0:
		return result
	var data: Dictionary = _get_weapon_runtime_data(BASE_WEAPON)
	if data.is_empty() or not bool(data.get("reloading", false)):
		return result
	var timer: float = max(0.0, float(data.get("reload_timer_frames", PISTOL_RELOAD_FRAMES)) - fps_scale)
	var total: float = max(1.0, float(data.get("reload_total_frames", PISTOL_RELOAD_FRAMES)))
	var ammo_max: int = int(data.get("ammo_max", PISTOL_AMMO_MAX))
	var start_ammo: int = int(data.get("ammo_current", 0))
	var previous_display: int = clampi(int(data.get("reload_display_ammo", start_ammo)), 0, ammo_max)
	var progress: float = clamp(1.0 - timer / total, 0.0, 1.0)
	var display_ammo: int = clampi(max(start_ammo, int(floor(progress * float(ammo_max)))), 0, ammo_max)
	data["reload_timer_frames"] = timer
	data["reload_display_ammo"] = display_ammo
	result["reloading"] = true
	result["reload_timer_frames"] = timer
	result["reload_rounds_added"] = max(0, display_ammo - previous_display)
	if timer <= 0.0:
		data["reloading"] = false
		data["reload_timer_frames"] = 0.0
		data["ammo_current"] = ammo_max
		data["reload_display_ammo"] = ammo_max
		result["completed"] = true
	_set_weapon_runtime_data(BASE_WEAPON, data)
	return result


func _refill_pistol_to_max(target: Dictionary) -> bool:
	var ammo_max: int = int(target.get("ammo_max", BERETTA_AMMO_MAX))
	var changed: bool = (
		int(target.get("ammo_current", 0)) < ammo_max
		or int(target.get("magazines_current", 0)) != 0
		or int(target.get("magazines_max", 0)) != 0
		or bool(target.get("reloading", false))
		or float(target.get("reload_timer_frames", 0.0)) > 0.0
	)
	if not changed:
		return false
	target["ammo_current"] = ammo_max
	target["magazines_current"] = 0
	target["magazines_max"] = 0
	target["reloading"] = false
	target["reload_timer_frames"] = 0.0
	target["reload_total_frames"] = PISTOL_RELOAD_FRAMES
	target["reload_display_ammo"] = ammo_max
	return true


func _refill_ak47_ammo(target: Dictionary, amount: int = 1) -> bool:
	var ammo_max: int = int(target.get("ammo_max", AK47_AMMO_MAX))
	var ammo_current: int = int(target.get("ammo_current", ammo_max))
	if ammo_current >= ammo_max:
		return false
	target["ammo_current"] = min(ammo_max, ammo_current + max(1, int(amount)))
	return true


func _refill_ak47_to_max(target: Dictionary) -> bool:
	var ammo_max: int = int(target.get("ammo_max", AK47_AMMO_MAX))
	var ammo_current: int = int(target.get("ammo_current", ammo_max))
	var duration_max: float = max(0.0, float(target.get("duration_max_frames", AK47_DURATION_FRAMES)))
	var duration_frames: float = clamp(float(target.get("duration_frames", duration_max)), 0.0, duration_max)
	var changed: bool = ammo_current < ammo_max or duration_frames < duration_max
	if not changed:
		return false
	target["ammo_current"] = ammo_max
	target["duration_frames"] = duration_max
	target["duration_max_frames"] = duration_max
	return true


func _apply_pistol_display_fields(data: Dictionary) -> void:
	var ammo_max: int = BERETTA_AMMO_MAX
	data["ammo_max"] = ammo_max
	data["magazines_max"] = 0
	data["ammo_current"] = clampi(int(data.get("ammo_current", ammo_max)), 0, ammo_max)
	data["magazines_current"] = 0
	data["reloading"] = false
	data["reload_timer_frames"] = 0.0
	data["reload_total_frames"] = PISTOL_RELOAD_FRAMES
	data["reload_display_ammo"] = int(data.get("ammo_current", ammo_max))


func _apply_ak47_display_fields(data: Dictionary) -> void:
	var ammo_max: int = int(data.get("ammo_max", AK47_AMMO_MAX))
	data["ammo_current"] = clampi(int(data.get("ammo_current", ammo_max)), 0, ammo_max)
	data["duration_max_frames"] = max(0.0, float(data.get("duration_max_frames", AK47_DURATION_FRAMES)))
	data["duration_frames"] = clamp(
		float(data.get("duration_frames", data.get("duration_max_frames", AK47_DURATION_FRAMES))),
		0.0,
		float(data.get("duration_max_frames", AK47_DURATION_FRAMES))
	)


func _get_pistol_ammo_text(data: Dictionary) -> String:
	var ammo_current: int = int(data.get("ammo_current", BERETTA_AMMO_MAX))
	var ammo_max: int = int(data.get("ammo_max", BERETTA_AMMO_MAX))
	return "%s %d/%d" % [LanguageSettings.translate_text("탄약"), ammo_current, ammo_max]


func _get_base_pistol_ammo_text(data: Dictionary) -> String:
	var ammo_current: int = int(data.get("ammo_current", PISTOL_AMMO_MAX))
	var ammo_max: int = int(data.get("ammo_max", PISTOL_AMMO_MAX))
	if bool(data.get("reloading", false)):
		var display_ammo: int = int(data.get("reload_display_ammo", ammo_current))
		return "%s %d/%d" % [LanguageSettings.translate_text("재장전"), display_ammo, ammo_max]
	return "%s %d/%d" % [LanguageSettings.translate_text("탄약"), ammo_current, ammo_max]


func _refill_basic_ammo(id: String, target: Dictionary, amount: int = 1) -> bool:
	var ammo_max: int = int(target.get("ammo_max", -1))
	var ammo_current: int = int(target.get("ammo_current", -1))
	if ammo_max <= 0 or ammo_current < 0 or ammo_current >= ammo_max:
		return false
	target["ammo_current"] = min(ammo_max, ammo_current + max(1, int(amount)))
	target["reloading"] = false
	target["reload_timer_frames"] = 0.0
	target["reload_display_ammo"] = int(target.get("ammo_current", ammo_max))
	if id == PISTOL_ORB_SKILL:
		target["magazines_current"] = 0
		target["magazines_max"] = 0
		target["reload_total_frames"] = PISTOL_RELOAD_FRAMES
	_set_weapon_runtime_data(id, target)
	return true


func _refill_basic_ammo_to_max(id: String, target: Dictionary) -> bool:
	var ammo_max: int = int(target.get("ammo_max", -1))
	var ammo_current: int = int(target.get("ammo_current", -1))
	if ammo_max <= 0 or ammo_current < 0 or ammo_current >= ammo_max:
		return false
	target["ammo_current"] = ammo_max
	target["reloading"] = false
	target["reload_timer_frames"] = 0.0
	target["reload_display_ammo"] = ammo_max
	if id == PISTOL_ORB_SKILL:
		target["magazines_current"] = 0
		target["magazines_max"] = 0
		target["reload_total_frames"] = PISTOL_RELOAD_FRAMES
	_set_weapon_runtime_data(id, target)
	return true


func _get_ak47_ammo_text(data: Dictionary) -> String:
	var ammo_current: int = int(data.get("ammo_current", AK47_AMMO_MAX))
	var ammo_max: int = int(data.get("ammo_max", AK47_AMMO_MAX))
	var duration_frames: float = max(0.0, float(data.get("duration_frames", AK47_DURATION_FRAMES)))
	var duration_seconds: float = duration_frames / 60.0
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		return "Ammo %d/%d - Durability %.1fs" % [ammo_current, ammo_max, duration_seconds]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "Munición %d/%d - Durabilidad %.1fs" % [ammo_current, ammo_max, duration_seconds]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Munição %d/%d - Durabilidade %.1fs" % [ammo_current, ammo_max, duration_seconds]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Патроны %d/%d - Прочность %.1fс" % [ammo_current, ammo_max, duration_seconds]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "弹药 %d/%d · 耐久 %.1f秒" % [ammo_current, ammo_max, duration_seconds]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "弾薬 %d/%d · 耐久 %.1f秒" % [ammo_current, ammo_max, duration_seconds]
	return "탄약 %d/%d · 내구 %.1f초" % [ammo_current, ammo_max, duration_seconds]


func _update_hud_highlight_timer(fps_scale: float) -> void:
	if hud_highlight_timer_frames <= 0.0:
		return
	hud_highlight_timer_frames = max(0.0, hud_highlight_timer_frames - max(0.0, fps_scale))
	if hud_highlight_timer_frames <= 0.0:
		hud_highlight_weapon_id = ""


func _clear_hud_highlight() -> void:
	hud_highlight_weapon_id = ""
	hud_highlight_timer_frames = 0.0
	hud_highlight_max_frames = HUD_HIGHLIGHT_DURATION_FRAMES


func _reconcile_current_weapon() -> void:
	var weapons: Array = get_weapons()
	if not weapons.has(current_weapon_id):
		current_weapon_id = BASE_WEAPON
	if not hud_highlight_weapon_id.is_empty() and not weapons.has(hud_highlight_weapon_id):
		_clear_hud_highlight()


func _is_current_weapon_reloading() -> bool:
	if current_weapon_id != BASE_WEAPON:
		return false
	var data: Dictionary = _get_weapon_runtime_data(current_weapon_id)
	return bool(data.get("reloading", false))


func _get_weapon_runtime_data(weapon_id: String) -> Dictionary:
	var id: String = _normalize_weapon_id(weapon_id)
	if id == BASE_WEAPON:
		if base_weapon_runtime.is_empty():
			base_weapon_runtime = _get_base_weapon_data(BASE_WEAPON)
		return base_weapon_runtime.duplicate(true)
	if rental_weapons.has(id):
		return _get_dict(rental_weapons[id]).duplicate(true)
	if permanent_owned.has(id):
		return _get_dict(permanent_owned[id]).duplicate(true)
	return _get_base_weapon_data(id)


func _set_weapon_runtime_data(weapon_id: String, data: Dictionary) -> void:
	var id: String = _normalize_weapon_id(weapon_id)
	if id == BASE_WEAPON:
		base_weapon_runtime = data
	elif rental_weapons.has(id):
		rental_weapons[id] = data
	elif permanent_owned.has(id):
		permanent_owned[id] = data


func _restore_permanent_owned(value: Variant, dropped_ids: Array) -> void:
	if not (value is Dictionary):
		return
	var source: Dictionary = value
	for raw_weapon_id in source.keys():
		var weapon_id: String = _normalize_weapon_id(raw_weapon_id)
		if not _is_valid_permanent_weapon(weapon_id):
			dropped_ids.append(weapon_id)
			continue
		var data: Dictionary = _sanitize_weapon_runtime_data(weapon_id, source[raw_weapon_id], false)
		if data.is_empty():
			dropped_ids.append(weapon_id)
			continue
		data["kind"] = "owned"
		data["rental"] = false
		permanent_owned[weapon_id] = data


func _restore_equipped_permanent(value: Variant, dropped_ids: Array) -> void:
	if not (value is Array):
		return
	for raw_weapon_id in value:
		var weapon_id: String = _normalize_weapon_id(raw_weapon_id)
		if not _is_valid_permanent_weapon(weapon_id) or not permanent_owned.has(weapon_id):
			dropped_ids.append(weapon_id)
			continue
		if not equipped_permanent.has(weapon_id):
			equipped_permanent.append(weapon_id)


func _restore_rental_weapons(value: Variant, dropped_ids: Array) -> void:
	if not (value is Dictionary):
		return
	var source: Dictionary = value
	for raw_weapon_id in source.keys():
		var weapon_id: String = _normalize_weapon_id(raw_weapon_id)
		if weapon_id == BASE_WEAPON or permanent_owned.has(weapon_id):
			dropped_ids.append(weapon_id)
			continue
		var data: Dictionary = _sanitize_weapon_runtime_data(weapon_id, source[raw_weapon_id], true)
		if data.is_empty():
			dropped_ids.append(weapon_id)
			continue
		data["kind"] = "rental"
		data["rental"] = true
		data["acquired_stage"] = max(1, int(data.get("acquired_stage", 1)))
		rental_weapons[weapon_id] = data


func _sanitize_weapon_runtime_data(weapon_id: String, value: Variant, rental: bool) -> Dictionary:
	var id: String = _normalize_weapon_id(weapon_id)
	var data: Dictionary = _get_base_weapon_data(id)
	if data.is_empty() or id == BASE_WEAPON:
		return {}
	if value is Dictionary:
		data.merge((value as Dictionary).duplicate(true), true)
	var ammo_max: int = int(data.get("ammo_max", -1))
	if ammo_max >= 0:
		if id == PISTOL_ORB_SKILL:
			ammo_max = BERETTA_AMMO_MAX
		data["ammo_max"] = ammo_max
		data["ammo_current"] = clampi(int(data.get("ammo_current", ammo_max)), 0, ammo_max)
	if id == PISTOL_ORB_SKILL:
		data["magazines_max"] = 0
		data["magazines_current"] = 0
		data["reload_total_frames"] = PISTOL_RELOAD_FRAMES
		data["reload_timer_frames"] = 0.0
		data["reload_display_ammo"] = int(data.get("ammo_current", BERETTA_AMMO_MAX))
		data["reloading"] = false
	if id == "ak47":
		var duration_max: float = max(0.0, float(data.get("duration_max_frames", AK47_DURATION_FRAMES)))
		data["duration_max_frames"] = duration_max
		data["duration_frames"] = clamp(float(data.get("duration_frames", duration_max)), 0.0, duration_max)
	if rental:
		data["acquired_stage"] = max(1, int(data.get("acquired_stage", 1)))
	return data


func _get_base_weapon_data(weapon_id: String) -> Dictionary:
	var id: String = _normalize_weapon_id(weapon_id)
	var value: Variant = WEAPON_DATA.get(id, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _is_valid_permanent_weapon(weapon_id: String) -> bool:
	return PERMANENT_WEAPONS.has(_normalize_weapon_id(weapon_id))


func _normalize_weapon_id(weapon_id: Variant) -> String:
	return str(weapon_id).strip_edges().to_lower()


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
