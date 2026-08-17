extends RefCounted

const RuntimePerkModalTimeShift := preload("res://scripts/core/runtime_perk_modal_time_shift.gd")

# ⚠️`duration_msec` 는 길이라 제외. 시각 앵커만 민다.
const PENDING_SPAWN_MODAL_TIME_KEYS: Array[String] = ["release_msec"]
const PORTAL_MODAL_TIME_KEYS: Array[String] = [
	"start_msec",
	"phase_start_msec",
	"end_msec",
	"effect_end_msec",
]

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const ITEM_SPAWN_PORTAL_DURATION_MSEC := 1000
const ITEM_SPAWN_PORTAL_RELEASE_DELAY_MSEC := 438
const DIMENSION_GATE_DURATION_MSEC := 3000
const DIMENSION_GATE_SPAWN_DELAY_MIN_MSEC := 500
const DIMENSION_GATE_SPAWN_DELAY_MAX_MSEC := 1000
const DIMENSION_GATE_PORTAL_DRAW_SIZE := 104.0
const DIMENSION_GATE_PORTAL_OPENING_DURATION_MSEC := 438
const DIMENSION_GATE_PORTAL_CLOSING_DURATION_MSEC := 500

var pending_spawn_items: Array[Dictionary] = []
var item_spawn_portals: Array[Dictionary] = []
var dimension_gate_active := false
var dimension_gate_start_msec: int = 0
var dimension_gate_end_msec: int = 0
var dimension_gate_next_spawn_msec: int = 0


func reset() -> void:
	pending_spawn_items.clear()
	item_spawn_portals.clear()
	dimension_gate_active = false
	dimension_gate_start_msec = 0
	dimension_gate_end_msec = 0
	dimension_gate_next_spawn_msec = 0


# 퍽 모달 동안 벽시계 앵커 동결. 정지 마커는 소유자(active_item_runtime)가 들고
# 여기로 구간을 흘려준다. 규칙은 runtime_perk_modal_time_shift.gd 참조.
func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
	var delta_msec: int = RuntimePerkModalTimeShift.resolve_paused_duration(pause_started_msec, resumed_msec)
	if delta_msec <= 0:
		return
	dimension_gate_start_msec = RuntimePerkModalTimeShift.shift_anchor(dimension_gate_start_msec, delta_msec)
	dimension_gate_end_msec = RuntimePerkModalTimeShift.shift_anchor(dimension_gate_end_msec, delta_msec)
	dimension_gate_next_spawn_msec = RuntimePerkModalTimeShift.shift_anchor(
		dimension_gate_next_spawn_msec, delta_msec
	)
	RuntimePerkModalTimeShift.shift_dict_array_anchors(
		pending_spawn_items, PENDING_SPAWN_MODAL_TIME_KEYS, delta_msec
	)
	RuntimePerkModalTimeShift.shift_dict_array_anchors(
		item_spawn_portals, PORTAL_MODAL_TIME_KEYS, delta_msec
	)


func activate_dimension_gate() -> bool:
	if dimension_gate_active:
		return true
	var now_msec: int = Time.get_ticks_msec()
	dimension_gate_active = true
	dimension_gate_start_msec = now_msec
	dimension_gate_end_msec = now_msec + DIMENSION_GATE_DURATION_MSEC
	dimension_gate_next_spawn_msec = now_msec + _roll_dimension_gate_spawn_delay_msec()
	_ensure_dimension_gate_portal(now_msec)
	return true


func is_dimension_gate_active() -> bool:
	return dimension_gate_active


func get_dimension_gate_center() -> Vector2:
	return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)


func get_item_spawn_portals() -> Array[Dictionary]:
	return item_spawn_portals


func get_pending_spawn_items() -> Array[Dictionary]:
	return pending_spawn_items


func has_pending_spawn_or_portals() -> bool:
	return not pending_spawn_items.is_empty() or not item_spawn_portals.is_empty()


func has_visible_portals() -> bool:
	return not item_spawn_portals.is_empty()


func update_dimension_gate(is_item_spawn_blocked: bool) -> bool:
	if not dimension_gate_active:
		return false
	var now_msec: int = Time.get_ticks_msec()
	if is_item_spawn_blocked:
		_clear_dimension_gate()
		return false
	if now_msec >= dimension_gate_end_msec:
		_start_dimension_gate_closing(now_msec)
		return false
	_ensure_dimension_gate_portal(now_msec)
	if now_msec < dimension_gate_next_spawn_msec:
		return false
	dimension_gate_next_spawn_msec = now_msec + _roll_dimension_gate_spawn_delay_msec()
	return true


func queue_item_after_portal(field_item: Dictionary, position: Vector2) -> int:
	var now_msec: int = Time.get_ticks_msec()
	var release_msec: int = now_msec + ITEM_SPAWN_PORTAL_RELEASE_DELAY_MSEC
	pending_spawn_items.append({
		"item": field_item,
		"release_msec": release_msec,
	})
	item_spawn_portals.append({
		"position": position,
		"start_msec": now_msec,
		"duration_msec": ITEM_SPAWN_PORTAL_DURATION_MSEC,
	})
	return release_msec


func queue_dimension_gate_item(field_item: Dictionary) -> int:
	var now_msec: int = Time.get_ticks_msec()
	pending_spawn_items.append({
		"item": field_item,
		"release_msec": now_msec,
	})
	return now_msec


func queue_lucky_coin_bonus_after_portal(field_item: Dictionary, position: Vector2, release_msec: int) -> void:
	var now_msec: int = Time.get_ticks_msec()
	pending_spawn_items.append({
		"item": field_item,
		"release_msec": release_msec,
	})
	item_spawn_portals.append({
		"position": position,
		"start_msec": now_msec,
		"duration_msec": ITEM_SPAWN_PORTAL_DURATION_MSEC,
		"lucky_bonus": true,
	})


func release_pending_spawn_items() -> Array[Dictionary]:
	if pending_spawn_items.is_empty():
		return []
	var now_msec: int = Time.get_ticks_msec()
	var released_items: Array[Dictionary] = []
	var survivors: Array[Dictionary] = []
	for pending in pending_spawn_items:
		if now_msec < int(pending.get("release_msec", now_msec)):
			survivors.append(pending)
			continue
		var item_value: Variant = pending.get("item", {})
		if item_value is Dictionary:
			released_items.append(item_value)
	pending_spawn_items = survivors
	return released_items


func update_item_spawn_portals() -> void:
	if item_spawn_portals.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for portal in item_spawn_portals:
		if bool(portal.get("sustained", false)):
			var phase: String = str(portal.get("phase", "holding"))
			var phase_start_msec: int = int(portal.get("phase_start_msec", portal.get("start_msec", now_msec)))
			if phase == "opening":
				if now_msec - phase_start_msec >= DIMENSION_GATE_PORTAL_OPENING_DURATION_MSEC:
					portal["phase"] = "holding"
					portal["phase_start_msec"] = now_msec
				survivors.append(portal)
			elif phase == "holding":
				survivors.append(portal)
			elif phase == "closing":
				if now_msec - phase_start_msec < DIMENSION_GATE_PORTAL_CLOSING_DURATION_MSEC:
					survivors.append(portal)
			continue
		var start_msec: int = int(portal.get("start_msec", now_msec))
		var duration_msec: int = max(1, int(portal.get("duration_msec", ITEM_SPAWN_PORTAL_DURATION_MSEC)))
		if now_msec - start_msec < duration_msec:
			survivors.append(portal)
	item_spawn_portals = survivors


func _ensure_dimension_gate_portal(now_msec: int) -> void:
	var center := get_dimension_gate_center()
	for portal in item_spawn_portals:
		if bool(portal.get("dimension_gate", false)):
			portal["position"] = center
			portal["start_msec"] = dimension_gate_start_msec
			portal["end_msec"] = dimension_gate_end_msec
			portal["effect_end_msec"] = dimension_gate_end_msec
			if str(portal.get("phase", "")) == "closing":
				portal["phase"] = "opening"
				portal["phase_start_msec"] = now_msec
			return
	item_spawn_portals.append({
		"position": center,
		"start_msec": now_msec,
		"duration_msec": ITEM_SPAWN_PORTAL_DURATION_MSEC,
		"end_msec": dimension_gate_end_msec,
		"effect_end_msec": dimension_gate_end_msec,
		"sustained": true,
		"dimension_gate": true,
		"draw_size": DIMENSION_GATE_PORTAL_DRAW_SIZE,
		"phase": "opening",
		"phase_start_msec": now_msec,
	})


func _start_dimension_gate_closing(now_msec: int) -> void:
	dimension_gate_active = false
	dimension_gate_start_msec = 0
	dimension_gate_end_msec = 0
	dimension_gate_next_spawn_msec = 0
	for portal in item_spawn_portals:
		if bool(portal.get("dimension_gate", false)):
			portal["phase"] = "closing"
			portal["phase_start_msec"] = now_msec
			return


func _clear_dimension_gate() -> void:
	dimension_gate_active = false
	dimension_gate_start_msec = 0
	dimension_gate_end_msec = 0
	dimension_gate_next_spawn_msec = 0
	var survivors: Array[Dictionary] = []
	for portal in item_spawn_portals:
		if not bool(portal.get("dimension_gate", false)):
			survivors.append(portal)
	item_spawn_portals = survivors


func _roll_dimension_gate_spawn_delay_msec() -> int:
	return randi_range(DIMENSION_GATE_SPAWN_DELAY_MIN_MSEC, DIMENSION_GATE_SPAWN_DELAY_MAX_MSEC)
