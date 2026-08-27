extends RefCounted

const CommandoSupplyDropPayloadResolver := preload("res://scripts/characters/commando_supply_drop_payload_resolver.gd")

var _timer := 0.0
var _timing_pattern := "normal"
var _pending_drop: Dictionary = {}
var _pending_drops: Array[Dictionary] = []
var _pending_drop_delays: Array[float] = []


func reset() -> void:
	_timer = 0.0
	_timing_pattern = "normal"
	_pending_drop.clear()
	_pending_drops.clear()
	_pending_drop_delays.clear()


func begin(deps: Dictionary) -> void:
	_timer = 0.0
	_pending_drops = CommandoSupplyDropPayloadResolver.build_pending_drops(deps)
	_timing_pattern = CommandoSupplyDropPayloadResolver.get_drop_timing_pattern(deps)
	_pending_drop_delays = CommandoSupplyDropPayloadResolver.build_pending_drop_delays(
		deps,
		_pending_drops.size(),
		_timing_pattern
	)
	_refresh_pending_drop()


func start_flight() -> void:
	_timer = _peek_next_drop_delay()


func advance_timer(delta: float) -> void:
	if delta <= 0.0:
		return
	_timer -= delta


func is_ready() -> bool:
	return _timer <= 0.0 and not _pending_drops.is_empty()


func resolve_ready_drops() -> Array[Dictionary]:
	var resolved_drops: Array[Dictionary] = []
	while is_ready():
		resolved_drops.append(_pop_next_drop())
		if _pending_drops.is_empty():
			break
		# Preserve overshoot and allow configured zero-delay payloads to chain in
		# this same frame, matching the legacy host loop exactly.
		_timer += _peek_next_drop_delay()
	_refresh_pending_drop()
	return resolved_drops


func clear_pending() -> void:
	_timer = 0.0
	_pending_drop.clear()
	_pending_drops.clear()
	_pending_drop_delays.clear()


func get_snapshot() -> Dictionary:
	return {
		"timer": _timer,
		"drop_timing_pattern": _timing_pattern,
		"pending_drop": _pending_drop.duplicate(true),
		"pending_drops": _pending_drops.duplicate(true),
		"pending_drop_delays": _pending_drop_delays.duplicate(),
	}


func restore(snapshot: Dictionary, aircraft_spawned: bool) -> void:
	_timer = max(0.0, float(snapshot.get("timer", 0.0))) if aircraft_spawned else 0.0
	_timing_pattern = CommandoSupplyDropPayloadResolver.normalize_drop_timing_pattern(
		str(snapshot.get("drop_timing_pattern", "normal"))
	)
	_pending_drop = _duplicate_dictionary(snapshot.get("pending_drop", {}))
	_pending_drops = _duplicate_dictionary_array(snapshot.get("pending_drops", []))
	_pending_drop_delays = _duplicate_float_array(snapshot.get("pending_drop_delays", []))
	if _pending_drop.is_empty() and not _pending_drops.is_empty():
		_refresh_pending_drop()


func get_pending_count() -> int:
	return _pending_drops.size()


func get_timer() -> float:
	return _timer


func _pop_next_drop() -> Dictionary:
	var drop_value: Variant = _pending_drops.pop_front()
	if not _pending_drop_delays.is_empty():
		_pending_drop_delays.pop_front()
	return drop_value.duplicate(true) if drop_value is Dictionary else {}


func _peek_next_drop_delay() -> float:
	if _pending_drop_delays.is_empty():
		return CommandoSupplyDropPayloadResolver.PAYLOAD_INTERVAL_SECONDS
	return max(0.0, float(_pending_drop_delays[0]))


func _refresh_pending_drop() -> void:
	_pending_drop = _pending_drops[0].duplicate(true) if not _pending_drops.is_empty() else {}


static func _duplicate_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


static func _duplicate_float_array(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if not (value is Array):
		return result
	for entry in value:
		result.append(max(0.0, float(entry)))
	return result
