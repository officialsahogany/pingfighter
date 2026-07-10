extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const RuntimePerkAngelBlessingModalFlow := preload("res://scripts/characters/runtime_perk_angel_blessing_modal_flow.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

const BUFF_IDS := ["paddle_size", "gauge_max", "move_speed"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_inactive_work_query_stays_allocation_free()
	var flow: Object = RuntimePerkAngelBlessingModalFlow.new()
	_start_face_three_reveal(flow, 3)
	var dismiss_result: Dictionary = _confirm_ready_modal(flow)
	_verify_face_three_absorption_contract(flow, dismiss_result)
	_verify_absorption_does_not_block_physics(flow)
	_verify_arrival_cues_and_visual_clock(flow)
	_verify_boundary_cleanup()
	_verify_ball_actor_cleanup_clears_logical_absorption()
	_finish()


func _verify_inactive_work_query_stays_allocation_free() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var body: String = SourceContractFunctionBody.extract(source, "func has_angel_blessing_modal_work")
	_expect(body.find("get_snapshot") < 0, "inactive Angel work query must not deep-copy the full presentation snapshot every frame")
	_expect(body.find("has_ready_current_stage_roll") >= 0, "Angel work query should use the flow's allocation-free ready-roll predicate")


func _start_face_three_reveal(flow: Object, stage: int) -> void:
	var queue_result: Dictionary = flow.queue_pending_reveal(stage, {
		"rolled": true,
		"reason": "rolled",
		"active_stage": stage,
		"roll_face": 3,
		"active_buff_ids": BUFF_IDS.duplicate(),
	}, "presentation_smoke")
	_expect(bool(queue_result.get("accepted", false)), "face-three Angel result should queue for presentation")
	var begin_result: Dictionary = flow.begin_next_pending_reveal(stage)
	_expect(bool(begin_result.get("started", false)), "queued Angel result should begin its modal presentation")


func _confirm_ready_modal(flow: Object) -> Dictionary:
	flow.update(0.0)
	flow.update(3.0)
	_expect(bool(flow.is_modal_active()), "Angel modal should remain active until fresh confirmation")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	var result: Dictionary = flow.handle_input(event)
	_expect(bool(result.get("confirmed", false)), "ready Angel modal should accept Enter confirmation")
	_expect(not bool(flow.is_modal_active()), "confirmation should close only the blocking Angel modal")
	return result


func _verify_face_three_absorption_contract(flow: Object, dismiss_result: Dictionary) -> void:
	var absorption: Dictionary = _as_dictionary(dismiss_result.get("absorption", {}))
	var trajectories: Array = _as_array(absorption.get("trajectories", []))
	_expect(bool(absorption.get("active", false)), "confirmed face-three Angel roll should begin absorption")
	_expect(trajectories.size() == 3, "face-three Angel roll should create exactly three absorption trajectories")
	var expected_arrivals := [1.8, 2.05, 2.30]
	for index: int in range(mini(trajectories.size(), expected_arrivals.size())):
		var trajectory: Dictionary = _as_dictionary(trajectories[index])
		_expect(int(trajectory.get("index", -1)) == index, "Angel absorption trajectories should retain stable indices")
		_expect(str(trajectory.get("buff_id", "")) == BUFF_IDS[index], "each Angel trajectory should retain its selected blessing id")
		_expect(
			is_equal_approx(float(trajectory.get("arrival_time", -1.0)), float(expected_arrivals[index])),
			"Angel trajectory %d should arrive at %.2fs" % [index, float(expected_arrivals[index])]
		)
	_expect(bool(flow.has_visual_work()), "absorption should remain visual work after the modal closes")
	_expect(bool(flow.is_absorption_active()), "flow should expose active absorption independently of modal state")


func _verify_absorption_does_not_block_physics(flow: Object) -> void:
	var runtime := FakeRuntime.new(flow)
	var getter := FakeModuleGetter.new(runtime)
	var gate := BattleSceneModalGateController.new()
	var module_getter := Callable(getter, "get_module")
	_expect(not bool(runtime.is_angel_blessing_modal_active()), "absorption-only state must report modal=false")
	_expect(bool(runtime.has_angel_blessing_visual_work()), "absorption-only state should still report visual work")
	_expect(not bool(gate.should_block_battle_physics(module_getter)), "non-modal Angel absorption must not block battle physics")
	_expect(not bool(gate.should_block_mobile_controls(module_getter)), "non-modal Angel absorption must not block mobile controls")
	_expect(getter.lazy_keys.is_empty(), "Angel modal gate should read the cached runtime state without lazy module creation")


func _verify_arrival_cues_and_visual_clock(flow: Object) -> void:
	var update_result: Dictionary = flow.update(1.79)
	_expect(bool(_as_dictionary(update_result.get("absorption", {})).get("active", false)), "absorption visual clock should advance while no modal is active")
	_expect(_arrival_cues(update_result).is_empty(), "no Angel absorb cue should fire before 1.80s")

	update_result = flow.update(0.02)
	_expect(_cue_indices(update_result) == [0], "first Angel blessing should arrive at 1.80s")
	_expect(is_equal_approx(_absorb_elapsed(update_result), 1.81), "absorption elapsed time should keep advancing outside modal physics gating")

	update_result = flow.update(0.24)
	_expect(_cue_indices(update_result) == [1], "second Angel blessing should arrive at 2.05s")
	update_result = flow.update(0.25)
	_expect(_cue_indices(update_result) == [2], "third Angel blessing should arrive at 2.30s")
	_expect(bool(flow.is_absorption_active()), "player glow tail should keep absorption active after the last arrival")

	update_result = flow.update(0.34)
	_expect(not bool(_as_dictionary(update_result.get("absorption", {})).get("completed", false)), "Angel absorption should preserve its 0.35s post-arrival glow tail")
	update_result = flow.update(0.02)
	_expect(bool(_as_dictionary(update_result.get("absorption", {})).get("completed", false)), "Angel absorption should complete after the last arrival plus glow tail")
	_expect(not bool(flow.is_absorption_active()), "completed Angel absorption should clear its logical visual state")
	_expect(not bool(flow.has_visual_work()), "completed Angel absorption should leave no stale visual work")


func _verify_boundary_cleanup() -> void:
	var flow: Object = RuntimePerkAngelBlessingModalFlow.new()
	_start_face_three_reveal(flow, 4)
	_confirm_ready_modal(flow)
	flow.update(0.4)
	_expect(bool(flow.is_absorption_active()), "cleanup fixture should begin with live absorption")
	flow.reset_for_round_boundary()
	_expect(not bool(flow.is_absorption_active()), "round-boundary cleanup should clear Angel absorption immediately")
	_expect(not bool(flow.has_visual_work()), "round-boundary cleanup should leave no detached visual work")

	_start_face_three_reveal(flow, 5)
	_confirm_ready_modal(flow)
	flow.reset()
	_expect(not bool(flow.has_visual_work()), "full reset should clear Angel modal and absorption presentation state")


func _verify_ball_actor_cleanup_clears_logical_absorption() -> void:
	var flow: Object = RuntimePerkAngelBlessingModalFlow.new()
	_start_face_three_reveal(flow, 6)
	_confirm_ready_modal(flow)
	flow.update(0.4)
	_expect(bool(flow.is_absorption_active()), "ball-reset fixture should begin with logical Angel absorption")
	BallRoundActorCleanup.new().reset_actor_round_state({
		"runtime_perk_state": FakeRoundCleanupRuntime.new(flow),
	})
	_expect(not bool(flow.is_absorption_active()), "ball actor reset should clear the logical Angel absorption, not only hide its host")
	_expect(not bool(flow.has_visual_work()), "ball actor reset should prevent the Angel host from reactivating on the next idle sync")


func _arrival_cues(update_result: Dictionary) -> Array:
	return _as_array(_as_dictionary(update_result.get("absorption", {})).get("arrival_cues", []))


func _cue_indices(update_result: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	for cue_value: Variant in _arrival_cues(update_result):
		indices.append(int(_as_dictionary(cue_value).get("index", -1)))
	return indices


func _absorb_elapsed(update_result: Dictionary) -> float:
	return float(_as_dictionary(update_result.get("absorption", {})).get("elapsed", -1.0))


func _as_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _as_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_presentation_lifecycle_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


class FakeRuntime:
	extends RefCounted

	var flow: Object

	func _init(source_flow: Object) -> void:
		flow = source_flow

	func is_angel_blessing_modal_active() -> bool:
		return flow != null and bool(flow.is_modal_active())

	func has_angel_blessing_visual_work() -> bool:
		return flow != null and bool(flow.has_visual_work())


class FakeModuleGetter:
	extends RefCounted

	var runtime: Object
	var lazy_keys: Array[String] = []

	func _init(source_runtime: Object) -> void:
		runtime = source_runtime

	func _get_cached_module(key: String) -> Object:
		return runtime if key == "runtime_perk_state" else null

	func get_module(key: String) -> Object:
		lazy_keys.append(key)
		return _get_cached_module(key)


class FakeRoundCleanupRuntime:
	extends RefCounted

	var flow: Object

	func _init(source_flow: Object) -> void:
		flow = source_flow

	func on_angel_blessing_round_boundary() -> void:
		if flow != null:
			flow.reset_for_round_boundary()
