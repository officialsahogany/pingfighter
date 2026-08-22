extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _target_floor := 0
var _elapsed_sec := 0.0
var _pending := false
var _visible_animation_started := false


func begin_if_needed(target_floor: int, revealed_floor: int) -> bool:
	cancel()
	if target_floor <= revealed_floor:
		return false
	_target_floor = target_floor
	_pending = true
	return true


func begin_visible_animation() -> bool:
	if not _pending or _visible_animation_started:
		return false
	_visible_animation_started = true
	return true


func update(delta: float) -> bool:
	if not _pending or not _visible_animation_started:
		return false
	_elapsed_sec = minf(
		TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC,
		_elapsed_sec + maxf(0.0, delta)
	)
	return is_complete()


func skip() -> bool:
	if not _pending or not _visible_animation_started:
		return false
	_elapsed_sec = TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC
	return true


func is_pending() -> bool:
	return _pending


func has_visible_animation_started() -> bool:
	return _visible_animation_started


func is_complete() -> bool:
	return (
		_pending
		and _elapsed_sec >= TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC
	)


func get_target_floor() -> int:
	return _target_floor


func get_visual_model(revealed_floor: int) -> Dictionary:
	var progress := clampf(
		_elapsed_sec / maxf(0.001, TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC),
		0.0,
		1.0
	)
	return {
		"revealed_floor": revealed_floor,
		"target_floor": _target_floor,
		"pending": _pending,
		"active": _pending and _visible_animation_started,
		"progress": progress,
		"drift_time_sec": _elapsed_sec if _visible_animation_started else 0.0,
		"duration_sec": TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC,
	}


func finish() -> int:
	if not is_complete():
		return 0
	var completed_floor := _target_floor
	cancel()
	return completed_floor


func cancel() -> void:
	_target_floor = 0
	_elapsed_sec = 0.0
	_pending = false
	_visible_animation_started = false
