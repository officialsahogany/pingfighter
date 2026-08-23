extends RefCounted

const TowerTrainingTimingJudgmentPolicy := preload(
	"res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd"
)

const FULL_CYCLE_MSEC := 1600
const PULSE_CYCLE_MSEC := 900

var _running := false
var _resolved := false
var _started_msec := 0
var _stopped_msec := 0
var _clock_override_msec := -1
var _target_position := 0.5
var _pendulum_position := 0.0
var _luck_percent := TowerTrainingTimingJudgmentPolicy.BASE_LUCK_PERCENT
var _target_roll: Dictionary = {}
var _judgment: Dictionary = {}
var _active_update_count := 0
var _model_build_count := 0
var _visual_model: Dictionary = {}


func start(target_roll: Dictionary) -> bool:
	if int(target_roll.get("roll_count", 0)) != 1:
		return false
	_target_roll = target_roll.duplicate(true)
	_target_position = clampf(float(target_roll.get("target_position", 0.5)), 0.0, 1.0)
	_luck_percent = float(target_roll.get(
		"luck_percent",
		TowerTrainingTimingJudgmentPolicy.BASE_LUCK_PERCENT
	))
	_started_msec = _now_msec()
	_stopped_msec = 0
	_pendulum_position = 0.0
	_judgment.clear()
	_running = true
	_resolved = false
	_rebuild_visual_model()
	return true


func update_wall_clock() -> bool:
	if not _running:
		return false
	_pendulum_position = pendulum_position_at_elapsed(
		maxi(0, _now_msec() - _started_msec)
	)
	_active_update_count += 1
	_rebuild_visual_model()
	return true


func stop() -> Dictionary:
	if not _running:
		return {"accepted": false, "reason": "training_timing_not_running"}
	update_wall_clock()
	_running = false
	_resolved = true
	_stopped_msec = _now_msec()
	_judgment = TowerTrainingTimingJudgmentPolicy.judge_position(
		_pendulum_position,
		_target_position,
		_luck_percent
	)
	_judgment["accepted"] = true
	_judgment["pendulum_position"] = _pendulum_position
	_judgment["target_position"] = _target_position
	_judgment["target_roll_count"] = int(_target_roll.get("roll_count", 0))
	_rebuild_visual_model()
	return _judgment.duplicate(true)


func cancel() -> void:
	_running = false
	_resolved = false
	_target_roll.clear()
	_judgment.clear()
	_visual_model.clear()


func is_running() -> bool:
	return _running


func is_resolved() -> bool:
	return _resolved


func get_visual_model() -> Dictionary:
	return _visual_model


func get_result() -> Dictionary:
	return _judgment.duplicate(true)


func set_clock_msec_for_tests(value: int) -> void:
	_clock_override_msec = value


func clear_clock_msec_for_tests() -> void:
	_clock_override_msec = -1


func get_debug_state() -> Dictionary:
	return {
		"running": _running,
		"resolved": _resolved,
		"started_msec": _started_msec,
		"stopped_msec": _stopped_msec,
		"target_position": _target_position,
		"pendulum_position": _pendulum_position,
		"luck_percent": _luck_percent,
		"target_roll_count": int(_target_roll.get("roll_count", 0)),
		"target_seed": int(_target_roll.get("seed", 0)),
		"active_update_count": _active_update_count,
		"model_build_count": _model_build_count,
		"judgment_kind": str(_judgment.get("judgment_kind", "")),
		"host_node_count": 0,
		"dynamic_layer_count": 0,
	}


static func pendulum_position_at_elapsed(elapsed_msec: int) -> float:
	var phase := fposmod(float(maxi(0, elapsed_msec)), float(FULL_CYCLE_MSEC))
	phase /= float(FULL_CYCLE_MSEC)
	return 1.0 - absf(phase * 2.0 - 1.0)


func _rebuild_visual_model() -> void:
	var elapsed := maxi(0, _now_msec() - _started_msec)
	var pulse_phase := fposmod(float(elapsed), float(PULSE_CYCLE_MSEC)) / float(PULSE_CYCLE_MSEC)
	var cell_width := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(_luck_percent)
	_visual_model = {
		"visible": _running or _resolved,
		"running": _running,
		"resolved": _resolved,
		"target_position": _target_position,
		"pendulum_position": _pendulum_position,
		"cell_width_ratio": cell_width,
		"critical_start": _target_position - cell_width * 0.5,
		"critical_end": _target_position + cell_width * 0.5,
		"great_left_start": _target_position - cell_width * (
			0.5 + TowerTrainingTimingJudgmentPolicy.GREAT_CELL_MULTIPLIER
		),
		"great_left_end": _target_position - cell_width * 0.5,
		"great_right_start": _target_position + cell_width * 0.5,
		"great_right_end": _target_position + cell_width * (
			0.5 + TowerTrainingTimingJudgmentPolicy.GREAT_CELL_MULTIPLIER
		),
		"pulse_strength": 0.5 - 0.5 * cos(pulse_phase * TAU),
		"judgment_kind": str(_judgment.get("judgment_kind", "")),
		"wall_elapsed_msec": elapsed,
	}
	_model_build_count += 1


func _now_msec() -> int:
	return _clock_override_msec if _clock_override_msec >= 0 else Time.get_ticks_msec()
