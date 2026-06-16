extends RefCounted

const FRAME_SECONDS := 1.0 / 60.0
const PAYLOAD_INTERVAL_SECONDS := 0.28
const MIN_PAYLOAD_COUNT := 1
const MAX_PAYLOAD_COUNT := 3
const PYTHON_INITIAL_DROP_MIN_FRAMES := 12
const PYTHON_INITIAL_DROP_MAX_FRAMES := 150
const PYTHON_BURST_DROP_FRAMES := 10
const PYTHON_BURST_COOLDOWN_MIN_FRAMES := 90
const PYTHON_BURST_COOLDOWN_MAX_FRAMES := 180
const PYTHON_DELAYED_DROP_MIN_FRAMES := 120
const PYTHON_DELAYED_DROP_MAX_FRAMES := 210
const PYTHON_NORMAL_FAST_MIN_FRAMES := 10
const PYTHON_NORMAL_FAST_MAX_FRAMES := 30
const PYTHON_NORMAL_MID_MIN_FRAMES := 40
const PYTHON_NORMAL_MID_MAX_FRAMES := 80
const PYTHON_NORMAL_SLOW_MIN_FRAMES := 100
const PYTHON_NORMAL_SLOW_MAX_FRAMES := 180
const DROP_TIMING_PATTERNS := ["normal", "burst", "delayed"]
const DEFAULT_FIELD_ITEM_DROP_CANDIDATES := [
	{"item_id": "grenade", "weight": 1.0},
	{"item_id": "molotov", "weight": 1.0},
	{"item_id": "flare", "weight": 1.0},
	{"item_id": "spider_mine", "weight": 0.9},
	{"item_id": "dynamite", "weight": 0.8},
	{"item_id": "ammo_box", "weight": 1.0},
	{"item_id": "doping_potion", "weight": 1.0},
]
const DEFAULT_RENTAL_CANDIDATES := [
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
	"bazooka",
	"ak47",
]
const DEFAULT_RENTAL_WEAPON_DROP_WEIGHTS := {
	"net_gun": 0.45,
	"fire_support": 0.35,
	"bowling_trap": 0.4,
	"suicide_drone": 0.4,
	"bazooka": 0.45,
	"ak47": 0.55,
}
const DEFAULT_FIELD_ITEM_ID := "grenade"


static func build_pending_drops(deps: Dictionary) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var reserved_weapons := {}
	var payload_count: int = get_payload_count(deps)
	for payload_index in range(payload_count):
		var drop: Dictionary = build_pending_drop(deps, reserved_weapons, payload_index)
		drop["payload_index"] = payload_index
		drops.append(drop)
	return drops


static func get_payload_count(deps: Dictionary) -> int:
	if deps.has("commando_supply_drop_payload_count"):
		return clamp(int(deps.get("commando_supply_drop_payload_count", MIN_PAYLOAD_COUNT)), MIN_PAYLOAD_COUNT, MAX_PAYLOAD_COUNT)
	return randi_range(MIN_PAYLOAD_COUNT, MAX_PAYLOAD_COUNT)


static func build_pending_drop_delays(deps: Dictionary, payload_count: int, timing_pattern: String) -> Array[float]:
	if payload_count <= 0:
		return []
	var configured_value: Variant = deps.get("commando_supply_drop_payload_delays", [])
	if configured_value is Array and not (configured_value as Array).is_empty():
		return normalize_configured_drop_delays(configured_value as Array, payload_count)
	return build_python_drop_delay_schedule(timing_pattern, payload_count)


static func normalize_configured_drop_delays(configured_delays: Array, payload_count: int) -> Array[float]:
	var result: Array[float] = []
	for index in range(payload_count):
		var delay := PAYLOAD_INTERVAL_SECONDS
		if index < configured_delays.size():
			delay = max(0.0, float(configured_delays[index]))
		result.append(delay)
	return result


static func build_python_drop_delay_schedule(timing_pattern: String, payload_count: int) -> Array[float]:
	var result: Array[float] = []
	var current_pattern: String = normalize_drop_timing_pattern(timing_pattern)
	var next_drop_frames: int = randi_range(PYTHON_INITIAL_DROP_MIN_FRAMES, PYTHON_INITIAL_DROP_MAX_FRAMES)
	var burst_count := 0
	for payload_index in range(payload_count):
		var delay_frames: int
		if current_pattern == "burst" and burst_count < 2:
			delay_frames = PYTHON_BURST_DROP_FRAMES
			burst_count += 1
			if burst_count >= 2:
				next_drop_frames = randi_range(PYTHON_BURST_COOLDOWN_MIN_FRAMES, PYTHON_BURST_COOLDOWN_MAX_FRAMES)
				current_pattern = "normal"
		else:
			delay_frames = next_drop_frames
			if current_pattern == "delayed":
				next_drop_frames = randi_range(PYTHON_DELAYED_DROP_MIN_FRAMES, PYTHON_DELAYED_DROP_MAX_FRAMES)
			else:
				next_drop_frames = get_python_normal_next_drop_frames()
		result.append(float(delay_frames) * FRAME_SECONDS)
	return result


static func get_python_normal_next_drop_frames() -> int:
	var choices := [
		randi_range(PYTHON_NORMAL_FAST_MIN_FRAMES, PYTHON_NORMAL_FAST_MAX_FRAMES),
		randi_range(PYTHON_NORMAL_MID_MIN_FRAMES, PYTHON_NORMAL_MID_MAX_FRAMES),
		randi_range(PYTHON_NORMAL_SLOW_MIN_FRAMES, PYTHON_NORMAL_SLOW_MAX_FRAMES),
	]
	return int(choices[randi_range(0, choices.size() - 1)])


static func get_drop_timing_pattern(deps: Dictionary) -> String:
	var configured_pattern := str(deps.get("commando_supply_drop_timing_pattern", ""))
	if configured_pattern != "":
		return normalize_drop_timing_pattern(configured_pattern)
	return str(DROP_TIMING_PATTERNS[randi_range(0, DROP_TIMING_PATTERNS.size() - 1)])


static func normalize_drop_timing_pattern(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if DROP_TIMING_PATTERNS.has(normalized):
		return normalized
	return "normal"


static func build_pending_drop(deps: Dictionary, reserved_weapons: Dictionary = {}, payload_index: int = 0) -> Dictionary:
	var forced_drop: Dictionary = get_forced_pending_drop(deps, payload_index)
	if not forced_drop.is_empty():
		reserve_drop_weapon(forced_drop, reserved_weapons)
		return forced_drop

	var candidates: Array[Dictionary] = build_weighted_drop_candidates(deps, reserved_weapons)
	if candidates.is_empty():
		return {
			"type": "field_item",
			"item_id": str(deps.get("commando_supply_drop_field_item_id", DEFAULT_FIELD_ITEM_ID)),
		}

	var total_weight := 0.0
	for candidate in candidates:
		total_weight += max(0.0, float(candidate.get("weight", 0.0)))
	if total_weight <= 0.0:
		return candidates[0].duplicate(true)

	var roll: float = get_payload_roll(deps, payload_index) * total_weight
	for candidate in candidates:
		roll -= max(0.0, float(candidate.get("weight", 0.0)))
		if roll <= 0.0:
			var selected: Dictionary = candidate.duplicate(true)
			selected.erase("weight")
			reserve_drop_weapon(selected, reserved_weapons)
			return selected
	var fallback: Dictionary = candidates.back().duplicate(true)
	fallback.erase("weight")
	reserve_drop_weapon(fallback, reserved_weapons)
	return fallback


static func build_weighted_drop_candidates(deps: Dictionary, reserved_weapons: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for field_candidate in get_field_item_drop_candidates(deps):
		var item_id: String = str(field_candidate.get("item_id", ""))
		if item_id == "":
			continue
		candidates.append({
			"type": "field_item",
			"item_id": item_id,
			"weight": max(0.0, float(field_candidate.get("weight", 1.0))),
		})

	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	for weapon_id in DEFAULT_RENTAL_CANDIDATES:
		if reserved_weapons.has(weapon_id):
			continue
		if weapon_controller != null and weapon_controller.has_method("get_snapshot"):
			var snapshot: Dictionary = weapon_controller.get_snapshot()
			if _dict_has_key(snapshot.get("permanent_owned", {}), weapon_id):
				continue
			if _dict_has_key(snapshot.get("rental_weapons", {}), weapon_id):
				continue
		candidates.append({
			"type": "rental_weapon",
			"weapon_id": weapon_id,
			"weight": max(0.0, float(DEFAULT_RENTAL_WEAPON_DROP_WEIGHTS.get(weapon_id, 1.0))),
		})
	return candidates


static func get_field_item_drop_candidates(deps: Dictionary) -> Array[Dictionary]:
	var configured: Variant = deps.get("commando_supply_drop_field_item_candidates", [])
	var raw_candidates: Array = configured if configured is Array and not configured.is_empty() else DEFAULT_FIELD_ITEM_DROP_CANDIDATES
	var result: Array[Dictionary] = []
	for candidate_value in raw_candidates:
		if candidate_value is Dictionary:
			var candidate: Dictionary = candidate_value
			var item_id: String = str(candidate.get("item_id", candidate.get("name", "")))
			if item_id == "":
				continue
			if not is_field_item_candidate_available(item_id, deps):
				continue
			result.append({
				"item_id": item_id,
				"weight": max(0.0, float(candidate.get("weight", 1.0))),
			})
		else:
			var item_name := str(candidate_value)
			if item_name != "":
				if not is_field_item_candidate_available(item_name, deps):
					continue
				result.append({
					"item_id": item_name,
					"weight": 1.0,
				})
	return result


static func is_field_item_candidate_available(item_id: String, _deps: Dictionary) -> bool:
	if item_id == "doping_potion":
		return true
	if item_id == "ammo_box":
		return true
	return true


static func has_any_permanent_weapon(deps: Dictionary) -> bool:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller != null and weapon_controller.has_method("has_any_permanent_weapon"):
		return bool(weapon_controller.has_any_permanent_weapon())
	return not get_permanent_owned_from_deps(deps).is_empty()


static func get_permanent_owned_from_deps(deps: Dictionary) -> Dictionary:
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	if weapon_controller != null and weapon_controller.has_method("get_snapshot"):
		var snapshot: Dictionary = weapon_controller.get_snapshot()
		var permanent_value: Variant = snapshot.get("permanent_owned", {})
		if permanent_value is Dictionary:
			return permanent_value
	var direct_value: Variant = deps.get("commando_permanent_owned", {})
	if direct_value is Dictionary:
		return direct_value
	if direct_value is Array:
		var result := {}
		for weapon_id_value in direct_value:
			var weapon_id := str(weapon_id_value)
			if weapon_id != "":
				result[weapon_id] = true
		return result
	return {}


static func get_forced_pending_drop(deps: Dictionary, payload_index: int) -> Dictionary:
	var forced_value: Variant = deps.get("commando_supply_drop_forced_payloads", [])
	if not (forced_value is Array):
		return {}
	var forced_payloads: Array = forced_value
	if payload_index < 0 or payload_index >= forced_payloads.size():
		return {}
	var payload_value: Variant = forced_payloads[payload_index]
	if not (payload_value is Dictionary):
		return {}
	var payload: Dictionary = payload_value
	var payload_type: String = str(payload.get("type", ""))
	if payload_type == "rental_weapon":
		var weapon_id: String = str(payload.get("weapon_id", ""))
		return {"type": "rental_weapon", "weapon_id": weapon_id} if weapon_id != "" else {}
	if payload_type == "field_item":
		var item_id: String = str(payload.get("item_id", payload.get("name", "")))
		return {"type": "field_item", "item_id": item_id} if item_id != "" else {}
	return {}


static func get_payload_roll(deps: Dictionary, payload_index: int) -> float:
	var rolls_value: Variant = deps.get("commando_supply_drop_payload_rolls", [])
	if rolls_value is Array:
		var rolls: Array = rolls_value
		if payload_index >= 0 and payload_index < rolls.size():
			return clamp(float(rolls[payload_index]), 0.0, 0.999999)
	return randf()


static func reserve_drop_weapon(drop: Dictionary, reserved_weapons: Dictionary) -> void:
	if str(drop.get("type", "")) != "rental_weapon":
		return
	var weapon_id: String = str(drop.get("weapon_id", ""))
	if weapon_id != "":
		reserved_weapons[weapon_id] = true


static func _dict_has_key(value: Variant, key: String) -> bool:
	return value is Dictionary and (value as Dictionary).has(key)
