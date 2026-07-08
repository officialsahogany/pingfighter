extends SceneTree

const RuntimePerkUpdateFlow := preload("res://scripts/characters/runtime_perk_update_flow.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_update_runs_active_branches_and_perf_labels()
	_verify_runtime_state_facade_runs_active_branches_and_perf_labels()
	_verify_inactive_gate_skips_particle_tick()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_update_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_runs_active_branches_and_perf_labels() -> void:
	var helper := RuntimePerkUpdateFlow.new()
	var state := FakeRuntimeState.new()
	state.choice_flight_active = true
	state.unlock_showcase_active = true
	state.starpoint_absorption_active = true
	state.choice_active = true
	state.animation_time = 0.5
	state.particles = [{"age": 0.0}]
	var feedback := FakeChoiceFeedback.new()
	var opening := FakeChoiceOpening.new()
	var layout := FakeChoiceLayout.new()
	var perf := FakePerfLogger.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var result: Dictionary = helper.update_internal(
		0.25,
		Vector2(1280.0, 720.0),
		owner,
		registry,
		state,
		helper.build_update_context("선택 완료", 1.0, 1.45),
		feedback,
		opening,
		layout,
		helper.build_state_callbacks(state),
		perf
	)
	_expect(bool(result.get("accepted", false)), "update flow should accept an active update tick")
	_expect(bool(result.get("updated_particles", false)), "update flow should report particle updates")
	_expect(state.events == ["feedback", "flight", "showcase", "absorption", "active_gate"], "update flow should keep update branch order")
	_expect(feedback.calls == 1, "update flow should tick feedback once")
	_expect(state.choice_flight_calls == 1, "update flow should update active unlock flight once")
	_expect(state.unlock_showcase_calls == 1, "update flow should update unlock showcase once")
	_expect(state.starpoint_absorption_calls == 1, "update flow should update starpoint absorption once")
	_expect(opening.calls == 1, "update flow should build one active tick update")
	_expect(abs(opening.last_animation_time - 0.5) <= 0.001, "update flow should pass animation time")
	_expect(layout.calls == 1, "update flow should tick particles once")
	_expect(abs(layout.last_particle_life - 1.45) <= 0.001, "update flow should pass particle life")
	_expect(
		perf.labels == [
			"process.runtime_perk.feedback",
			"process.runtime_perk.flight",
			"process.runtime_perk.unlock_showcase",
			"process.runtime_perk.starpoint_absorption",
			"process.runtime_perk.active_gate",
			"process.runtime_perk.particles",
		],
		"update flow should emit expected perf labels"
	)


func _verify_runtime_state_facade_runs_active_branches_and_perf_labels() -> void:
	var helper := RuntimePerkUpdateFlow.new()
	var state := FakeRuntimeState.new()
	state.choice_flight_active = true
	state.unlock_showcase_active = true
	state.starpoint_absorption_active = true
	state.choice_active = true
	state.feedback_text = "ready"
	state.feedback_timer = 1.0
	state.animation_time = 0.5
	state.particles = [{"age": 0.0}]
	var feedback := FakeChoiceFeedback.new()
	var opening := FakeChoiceOpening.new()
	var layout := FakeChoiceLayout.new()
	state._choice_feedback = feedback
	state._choice_opening = opening
	state._choice_layout = layout
	var perf := FakePerfLogger.new()
	var result: Dictionary = helper.update_internal_from_runtime_state(
		0.25,
		Vector2(1280.0, 720.0),
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		perf
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept an active update tick")
	_expect(state.events == ["feedback", "flight", "showcase", "absorption", "active_gate"], "runtime-state facade should keep update branch order")
	_expect(feedback.calls == 1, "runtime-state facade should tick feedback once")
	_expect(opening.calls == 1, "runtime-state facade should build one active tick update")
	_expect(layout.calls == 1, "runtime-state facade should tick particles once")
	_expect(is_equal_approx(layout.last_particle_life, RuntimePerkState.PARTICLE_LIFE), "runtime-state facade particle-life default should match RuntimePerkState constant")
	_expect(
		perf.labels == [
			"process.runtime_perk.feedback",
			"process.runtime_perk.flight",
			"process.runtime_perk.unlock_showcase",
			"process.runtime_perk.starpoint_absorption",
			"process.runtime_perk.active_gate",
			"process.runtime_perk.particles",
		],
		"runtime-state facade should emit expected perf labels"
	)


func _verify_inactive_gate_skips_particle_tick() -> void:
	var helper := RuntimePerkUpdateFlow.new()
	var state := FakeRuntimeState.new()
	state.particles = [{"age": 0.0}]
	var feedback := FakeChoiceFeedback.new()
	var opening := FakeChoiceOpening.new()
	opening.active_tick_result = {"accepted": false, "blocked_reason": "inactive_choice"}
	var layout := FakeChoiceLayout.new()
	var perf := FakePerfLogger.new()
	var result: Dictionary = helper.update_internal(
		0.25,
		Vector2(1280.0, 720.0),
		FakeOwner.new(),
		FakeRegistry.new(),
		state,
		helper.build_update_context("", 0.0, 1.45),
		feedback,
		opening,
		layout,
		helper.build_state_callbacks(state),
		perf
	)
	_expect(not bool(result.get("accepted", true)), "inactive active-gate result should propagate rejection")
	_expect(str(result.get("blocked_reason", "")) == "inactive_choice", "inactive active-gate result should keep reason")
	_expect(layout.calls == 0, "inactive choice should skip particle update")
	_expect(perf.labels.find("process.runtime_perk.particles") < 0, "inactive choice should not emit particles perf label")
	_expect(perf.labels.has("process.runtime_perk.active_gate"), "inactive choice should still close active-gate perf sample")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_update_flow.gd")
	var update_body: String = _function_body(state_source, "func _update_internal(")
	var facade_body: String = _function_body(helper_source, "func update_internal_from_runtime_state(")
	_expect(state_source.find("RuntimePerkUpdateFlow") >= 0, "state should preload update-flow helper")
	_expect(update_body.find("_update_flow.update_internal_from_runtime_state") >= 0, "state update internals should delegate runtime-state assembly to update-flow helper")
	_expect(update_body.find("build_update_context") < 0, "state update internals should not build update context inline")
	_expect(update_body.find("_choice_feedback") < 0, "state update internals should not pass feedback helper inline")
	_expect(update_body.find("_choice_opening") < 0, "state update internals should not pass choice-opening helper inline")
	_expect(update_body.find("_choice_layout") < 0, "state update internals should not pass choice-layout helper inline")
	_expect(update_body.find("build_state_callbacks(self)") < 0, "state update internals should not build callback map inline")
	_expect(update_body.find("PARTICLE_LIFE") < 0, "state update internals should not pass particle-life constants inline")
	_expect(update_body.find("apply_tick_feedback_state_update") < 0, "state update internals should not tick feedback directly")
	_expect(update_body.find("_update_choice_flight_effect") < 0, "state update internals should not update active-unlock flight directly")
	_expect(update_body.find("_update_unlock_showcase") < 0, "state update internals should not update unlock showcase directly")
	_expect(update_body.find("_update_starpoint_absorption_effect") < 0, "state update internals should not update starpoint absorption directly")
	_expect(update_body.find("update_particles") < 0, "state update internals should not tick particles directly")
	_expect(helper_source.find("func update_internal_from_runtime_state(") >= 0, "update-flow helper should expose runtime-state facade")
	_expect(facade_body.find("_choice_feedback") >= 0, "update-flow facade should own feedback helper lookup")
	_expect(facade_body.find("_choice_opening") >= 0, "update-flow facade should own choice-opening helper lookup")
	_expect(facade_body.find("_choice_layout") >= 0, "update-flow facade should own choice-layout helper lookup")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "update-flow facade should own callback-map assembly")
	_expect(facade_body.find("DEFAULT_PARTICLE_LIFE") >= 0, "update-flow facade should own default particle life")
	_expect(helper_source.find("apply_tick_feedback_state_update") >= 0, "update-flow helper should tick feedback")
	_expect(helper_source.find("CALLBACK_UPDATE_CHOICE_FLIGHT_EFFECT") >= 0, "update-flow helper should own active-unlock flight callback")
	_expect(helper_source.find("CALLBACK_UPDATE_UNLOCK_SHOWCASE") >= 0, "update-flow helper should own unlock showcase callback")
	_expect(helper_source.find("CALLBACK_UPDATE_STARPOINT_ABSORPTION_EFFECT") >= 0, "update-flow helper should own starpoint absorption callback")
	_expect(helper_source.find("build_active_tick_state_update") >= 0, "update-flow helper should build active tick updates")
	_expect(helper_source.find("update_particles") >= 0, "update-flow helper should tick particles")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	extends RefCounted

	var events: Array = []
	var choice_flight_active := false
	var unlock_showcase_active := false
	var starpoint_absorption_active := false
	var choice_flight_calls := 0
	var unlock_showcase_calls := 0
	var starpoint_absorption_calls := 0
	var feedback_text := ""
	var feedback_timer := 0.0
	var animation_time := 0.0
	var choice_active := false
	var particles: Array = []
	var _choice_feedback: Object = null
	var _choice_opening: Object = null
	var _choice_layout: Object = null

	func is_choice_flight_active() -> bool:
		return choice_flight_active

	func _update_choice_flight_effect(_delta: float, _owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
		choice_flight_calls += 1
		events.append("flight")

	func is_unlock_showcase_active() -> bool:
		return unlock_showcase_active

	func _update_unlock_showcase(_delta: float, _owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
		unlock_showcase_calls += 1
		events.append("showcase")

	func is_starpoint_absorption_active() -> bool:
		return starpoint_absorption_active

	func _update_starpoint_absorption_effect(_delta: float, _view_size: Vector2, _owner: Object, _registry: Object) -> void:
		starpoint_absorption_calls += 1
		events.append("absorption")

	func _apply_choice_opening_update(update: Dictionary) -> Dictionary:
		events.append("active_gate")
		if bool(update.get("accepted", false)):
			animation_time = float(update.get("animation_time", animation_time))
		return update.duplicate(true)


class FakeChoiceFeedback:
	extends RefCounted

	var calls := 0

	func apply_tick_feedback_state_update(
		runtime_state: Object,
		current_text: String,
		current_timer: float,
		delta: float
	) -> Dictionary:
		calls += 1
		runtime_state.events.append("feedback")
		runtime_state.feedback_text = current_text
		runtime_state.feedback_timer = max(0.0, current_timer - delta)
		return {"accepted": true}


class FakeChoiceOpening:
	extends RefCounted

	var calls := 0
	var last_animation_time := 0.0
	var active_tick_result: Dictionary = {"accepted": true, "animation_time": 0.75, "update_particles": true}

	func build_active_tick_state_update(current_animation_time: float, _delta: float, _choice_active: bool) -> Dictionary:
		calls += 1
		last_animation_time = current_animation_time
		return active_tick_result.duplicate(true)


class FakeChoiceLayout:
	extends RefCounted

	var calls := 0
	var last_particle_life := 0.0

	func update_particles(_particles: Array, _delta: float, _view_size: Vector2, particle_life: float) -> void:
		calls += 1
		last_particle_life = particle_life
		if _particles.size() > 0 and _particles[0] is Dictionary:
			var first: Dictionary = _particles[0]
			first["ticked"] = true


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []
	var next_sample_id := 0

	func begin_sample() -> int:
		next_sample_id += 1
		return next_sample_id

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted
