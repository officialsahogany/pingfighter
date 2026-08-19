extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const SEGMENT_BATTLE_FADE_OUT := "battle_fade_out"
const SEGMENT_MAP_FADE_IN := "map_fade_in"
const SEGMENT_TRAVEL := "travel"
const SEGMENT_ARRIVE_VANISH := "arrive_vanish"
const SEGMENT_MAP_FADE_OUT := "map_fade_out"

var _transition_elapsed_sec := 0.0
var _transition_active := false
var _node_modal_fade_progress := 1.0
var _map_overlay_fade_progress := 0.0
var _map_overlay_fade_direction := 0


func reset() -> void:
	_transition_elapsed_sec = 0.0
	_transition_active = false
	_node_modal_fade_progress = 1.0
	_map_overlay_fade_progress = 0.0
	_map_overlay_fade_direction = 0


func begin_map_transition() -> void:
	_transition_elapsed_sec = 0.0
	_transition_active = true
	_node_modal_fade_progress = 1.0


func update_map_transition(delta: float) -> bool:
	if not _transition_active:
		return false
	# A one-second-or-larger gap means the app was suspended or the window was
	# dragged. Do not strand a physics-blocking presentation after resume. Normal
	# 72 Hz ticks still advance the exact five-beat duration deterministically.
	var elapsed_step := (
		get_map_transition_duration_sec()
		if delta >= 1.0
		else maxf(0.0, delta)
	)
	_transition_elapsed_sec = minf(
		get_map_transition_duration_sec(),
		_transition_elapsed_sec + elapsed_step
	)
	if _transition_elapsed_sec >= get_map_transition_duration_sec():
		_transition_active = false
		return true
	return false


func get_map_transition_progress() -> float:
	return clampf(
		_transition_elapsed_sec / maxf(0.001, get_map_transition_duration_sec()),
		0.0,
		1.0
	)


func set_map_transition_progress_for_qa(progress: float) -> void:
	_transition_elapsed_sec = clampf(progress, 0.0, 1.0) * get_map_transition_duration_sec()
	_transition_active = _transition_elapsed_sec < get_map_transition_duration_sec()


func get_map_transition_duration_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func get_map_transition_visual_model() -> Dictionary:
	var elapsed := clampf(
		_transition_elapsed_sec,
		0.0,
		get_map_transition_duration_sec()
	)
	var battle_fade_end := TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
	var map_fade_end := battle_fade_end + TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	var travel_end := map_fade_end + TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
	var vanish_end := travel_end + TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
	var segment := SEGMENT_MAP_FADE_OUT
	var local_progress := _ratio(
		elapsed - vanish_end,
		TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)
	var blackout_alpha := local_progress
	var map_visible := true
	var travel_progress := 1.0
	var marker_scale := 0.0
	var marker_alpha := 0.0
	if elapsed < battle_fade_end:
		segment = SEGMENT_BATTLE_FADE_OUT
		local_progress = _ratio(elapsed, TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC)
		blackout_alpha = local_progress
		map_visible = false
		travel_progress = 0.0
		marker_scale = 1.0
		marker_alpha = 1.0
	elif elapsed < map_fade_end:
		segment = SEGMENT_MAP_FADE_IN
		local_progress = _ratio(
			elapsed - battle_fade_end,
			TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		)
		blackout_alpha = 1.0 - local_progress
		travel_progress = 0.0
		marker_scale = 1.0
		marker_alpha = 1.0
	elif elapsed < travel_end:
		segment = SEGMENT_TRAVEL
		local_progress = _ratio(
			elapsed - map_fade_end,
			TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		)
		blackout_alpha = 0.0
		travel_progress = smoothstep(0.0, 1.0, local_progress)
		marker_scale = 1.0
		marker_alpha = 1.0
	elif elapsed < vanish_end:
		segment = SEGMENT_ARRIVE_VANISH
		local_progress = _ratio(
			elapsed - travel_end,
			TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		)
		blackout_alpha = 0.0
		travel_progress = 1.0
		marker_scale = 1.0 - smoothstep(0.0, 1.0, local_progress)
		marker_alpha = 1.0 - local_progress
	return {
		"segment": segment,
		"segment_progress": local_progress,
		"progress": get_map_transition_progress(),
		"blackout_alpha": clampf(blackout_alpha, 0.0, 1.0),
		"map_visible": map_visible,
		"travel_progress": clampf(travel_progress, 0.0, 1.0),
		"marker_scale": clampf(marker_scale, 0.0, 1.0),
		"marker_alpha": clampf(marker_alpha, 0.0, 1.0),
	}


func begin_node_modal_fade() -> void:
	_node_modal_fade_progress = 0.0


func update_node_modal_fade(delta: float) -> void:
	if _node_modal_fade_progress >= 1.0:
		return
	_node_modal_fade_progress = minf(
		1.0,
		_node_modal_fade_progress
			+ maxf(0.0, delta) / maxf(0.001, TowerAscentTuning.TEMP_NODE_MODAL_FADE_IN_SEC)
	)


func get_node_modal_fade_progress() -> float:
	return _node_modal_fade_progress


func set_node_modal_fade_progress_for_qa(progress: float) -> void:
	_node_modal_fade_progress = clampf(progress, 0.0, 1.0)


func begin_map_overlay_open() -> void:
	_map_overlay_fade_progress = 0.0
	_map_overlay_fade_direction = 1


func begin_map_overlay_close() -> void:
	_map_overlay_fade_progress = 1.0
	_map_overlay_fade_direction = -1


func update_map_overlay(delta: float) -> bool:
	if _map_overlay_fade_direction == 0:
		return false
	_map_overlay_fade_progress = clampf(
		_map_overlay_fade_progress
			+ float(_map_overlay_fade_direction)
				* maxf(0.0, delta)
				/ maxf(0.001, TowerAscentTuning.TEMP_MAP_OVERLAY_FADE_SEC),
		0.0,
		1.0
	)
	var finished := (
		(_map_overlay_fade_direction > 0 and _map_overlay_fade_progress >= 1.0)
		or (_map_overlay_fade_direction < 0 and _map_overlay_fade_progress <= 0.0)
	)
	if finished:
		_map_overlay_fade_direction = 0
	return finished


func get_map_overlay_fade_progress() -> float:
	return _map_overlay_fade_progress


func set_map_overlay_fade_progress_for_qa(progress: float) -> void:
	_map_overlay_fade_progress = clampf(progress, 0.0, 1.0)
	_map_overlay_fade_direction = 0


func is_map_overlay_fading_closed() -> bool:
	return _map_overlay_fade_direction < 0


func _ratio(value: float, duration: float) -> float:
	return clampf(value / maxf(0.001, duration), 0.0, 1.0)
