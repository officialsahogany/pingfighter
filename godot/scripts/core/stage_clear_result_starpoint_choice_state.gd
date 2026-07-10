extends RefCounted

const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultStarpointChoiceOpenData := preload("res://scripts/core/stage_clear_result_starpoint_choice_open_data.gd")
const StageClearResultStarpointPerkRewardData := preload("res://scripts/core/stage_clear_result_starpoint_perk_reward_data.gd")

var _pending_starpoint_choice_delay: float = 0.0
var _pending_starpoint_choice_box_index: int = -1
var _active_starpoint_choice_box_index: int = -1
var _last_recorded_perk_choice_sequence: int = 0


func reset(scene: Control = null) -> void:
	clear_pending_choice(scene)
	clear_active_choice_tracking()


func get_status() -> Dictionary:
	return {
		"pending_starpoint_choice_delay": _pending_starpoint_choice_delay,
		"pending_starpoint_choice_box_index": _pending_starpoint_choice_box_index,
	}


func schedule_deferred_choice(scene: Control, box_index: int, delay: float) -> void:
	_pending_starpoint_choice_delay = maxf(0.0, delay)
	_pending_starpoint_choice_box_index = box_index
	if scene != null and is_instance_valid(scene):
		StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active(scene, true, box_index)


func consume_pending_choice_if_ready(delta: float, scene: Control, runtime_perk_state: Object) -> Dictionary:
	if _pending_starpoint_choice_delay <= 0.0:
		return {"ready": false, "box_index": -1}
	if StageClearResultStarpointChoiceOpenData.is_runtime_perk_choice_active(runtime_perk_state):
		return {"ready": false, "box_index": -1}
	_pending_starpoint_choice_delay = maxf(0.0, _pending_starpoint_choice_delay - maxf(0.0, delta))
	if _pending_starpoint_choice_delay > 0.0:
		return {"ready": false, "box_index": -1}
	var box_index: int = _pending_starpoint_choice_box_index
	clear_pending_choice(scene)
	return {"ready": true, "box_index": box_index}


func record_open_result(scene: Control, box_index: int, result: Dictionary) -> void:
	if not bool(result.get("opened", false)):
		return
	_active_starpoint_choice_box_index = box_index
	_last_recorded_perk_choice_sequence = int(result.get("last_recorded_perk_choice_sequence", 0))
	if not bool(result.get("choice_active", false)):
		clear_active_choice_tracking()
	if scene != null and is_instance_valid(scene):
		scene.queue_redraw()


func record_active_choice(scene: Control, box_index: int, runtime_perk_state: Object) -> void:
	record_open_result(scene, box_index, {
		"opened": runtime_perk_state != null,
		"choice_active": StageClearResultStarpointChoiceOpenData.is_runtime_perk_choice_active(runtime_perk_state),
		"last_recorded_perk_choice_sequence": StageClearResultStarpointPerkRewardData.get_runtime_perk_choice_sequence(runtime_perk_state),
	})


func sync_box_perk_choice_rewards(scene: Control, runtime_perk_state: Object, perk_catalog: Object) -> void:
	if _active_starpoint_choice_box_index < 0:
		return
	if runtime_perk_state == null:
		clear_active_choice_tracking()
		return
	var snapshot: Dictionary = StageClearResultStarpointPerkRewardData.get_runtime_perk_snapshot(runtime_perk_state)
	var sequence: int = int(snapshot.get(
		"selected_choice_sequence",
		StageClearResultStarpointPerkRewardData.get_runtime_perk_choice_sequence(runtime_perk_state)
	))
	if sequence > _last_recorded_perk_choice_sequence:
		var reward: Dictionary = StageClearResultStarpointPerkRewardData.build_box_perk_choice_reward(
			snapshot,
			perk_catalog
		)
		if not reward.is_empty() and scene != null and is_instance_valid(scene):
			StageClearResultBoxSceneHandler.append_box_resolved_perk_reward(
				scene,
				_active_starpoint_choice_box_index,
				reward
			)
		_last_recorded_perk_choice_sequence = sequence
	if (
		not StageClearResultStarpointChoiceOpenData.is_runtime_perk_choice_active(runtime_perk_state)
		and int(snapshot.get("pending_skill_choices", 0)) <= 0
	):
		clear_active_choice_tracking()


func clear_pending_choice(scene: Control = null) -> void:
	_pending_starpoint_choice_delay = 0.0
	_pending_starpoint_choice_box_index = -1
	if scene != null and is_instance_valid(scene):
		StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active(scene, false, -1)


func clear_active_choice_tracking() -> void:
	_active_starpoint_choice_box_index = -1
	_last_recorded_perk_choice_sequence = 0
