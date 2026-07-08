extends SceneTree

const RuntimePerkDeferredInstants := preload("res://scripts/characters/runtime_perk_deferred_instants.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []
var _dimension_gate_calls := 0
var _full_gauge_calls := 0
var _dimension_gate_result := true
var _feedback_apply_calls := 0


func _init() -> void:
	_verify_helper_queues_choice_payloads()
	_verify_helper_waits_until_stage_advance()
	_verify_helper_resolves_ready_actions()
	_verify_helper_applies_spawn_intro_state_update()
	_verify_state_apply_choice_uses_deferred_choice_payloads()
	_verify_state_wrapper_preserves_public_result_shape()

	if _failures.is_empty():
		print("runtime_perk_deferred_instants_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_queues_choice_payloads() -> void:
	var helper := RuntimePerkDeferredInstants.new()
	var owner := FakeOwner.new(5)
	var gate_result: Dictionary = helper.queue_dimension_gate_choice(owner, "Gate")
	var gauge_result: Dictionary = helper.queue_full_gauge_choice(owner, "Gauge")
	_expect(bool(gate_result.get("accepted", false)), "deferred Dimension Gate queue choice should be accepted")
	_expect(str(gate_result.get("feedback_text", "")) == "Gate", "deferred Dimension Gate queue choice should return choice feedback")
	_expect(is_equal_approx(float(gate_result.get("feedback_timer", 0.0)), RuntimePerkDeferredInstants.DEFERRED_CHOICE_FEEDBACK_TIMER), "deferred Dimension Gate queue choice should return helper-owned timer")
	_expect(bool(gauge_result.get("accepted", false)), "deferred full gauge queue choice should be accepted")
	_expect(str(gauge_result.get("feedback_text", "")) == "Gauge", "deferred full gauge queue choice should return choice feedback")
	_expect(is_equal_approx(float(gauge_result.get("feedback_timer", 0.0)), RuntimePerkDeferredInstants.DEFERRED_CHOICE_FEEDBACK_TIMER), "deferred full gauge queue choice should return helper-owned timer")
	_expect(helper.has_pending_dimension_gate(), "deferred Dimension Gate queue choice should mark pending")
	_expect(helper.has_pending_full_gauge(), "deferred full gauge queue choice should mark pending")


func _verify_helper_waits_until_stage_advance() -> void:
	var helper := RuntimePerkDeferredInstants.new()
	var owner := FakeOwner.new(5)
	helper.queue_dimension_gate(owner, "Gate")
	helper.queue_full_gauge(owner, "Gauge")

	var actions: Dictionary = helper.collect_spawn_intro_actions(owner)
	_expect(bool(actions.get("wait_for_stage_advance", false)), "same-stage intro finish should wait for stage advance")
	_expect(not bool(actions.get("dimension_gate_ready", false)), "same-stage Dimension Gate should not be ready")
	_expect(not bool(actions.get("full_gauge_ready", false)), "same-stage full gauge should not be ready")
	_expect(helper.has_pending_dimension_gate(), "same-stage wait should keep Dimension Gate queued")
	_expect(helper.has_pending_full_gauge(), "same-stage wait should keep full gauge queued")


func _verify_helper_resolves_ready_actions() -> void:
	_dimension_gate_calls = 0
	_full_gauge_calls = 0
	_dimension_gate_result = true
	var helper := RuntimePerkDeferredInstants.new()
	helper.queue_dimension_gate(FakeOwner.new(5), "Gate")
	helper.queue_full_gauge(FakeOwner.new(5), "Gauge")
	var actions: Dictionary = helper.collect_spawn_intro_actions(FakeOwner.new(6))
	var result: Dictionary = helper.resolve_spawn_intro_actions(
		actions,
		FakeOwner.new(6),
		null,
		Callable(self, "_apply_dimension_gate"),
		Callable(self, "_apply_full_gauge")
	)
	_expect(bool(result.get("dimension_gate_activated", false)), "next-stage Dimension Gate should activate")
	_expect(bool(result.get("full_gauge_activated", false)), "next-stage full gauge should activate")
	_expect(_dimension_gate_calls == 1, "Dimension Gate callback should be called once")
	_expect(_full_gauge_calls == 1, "full gauge callback should be called once")
	_expect(str(result.get("_feedback_text", "")) == "Gauge", "later full-gauge feedback should win when both actions resolve")
	_expect(bool(result.get("_sync_owner", false)), "resolved actions should request owner sync")
	var state_update: Dictionary = helper.build_spawn_intro_state_update(result)
	var public_result: Dictionary = state_update.get("public_result", {})
	_expect(bool(state_update.get("has_feedback", false)), "state update should expose helper feedback state")
	_expect(str(state_update.get("feedback_text", "")) == "Gauge", "state update should expose helper feedback text")
	_expect(bool(state_update.get("sync_owner", false)), "state update should expose owner-sync request")
	_expect(not public_result.has("_feedback_text"), "state update public result should strip helper feedback text")
	_expect(not public_result.has("_sync_owner"), "state update public result should strip helper sync flag")
	_expect(not helper.has_pending_dimension_gate(), "resolved Dimension Gate should clear queue")
	_expect(not helper.has_pending_full_gauge(), "resolved full gauge should clear queue")

	_dimension_gate_calls = 0
	_full_gauge_calls = 0
	_dimension_gate_result = false
	helper.queue_dimension_gate(FakeOwner.new(5), "Gate")
	actions = helper.collect_spawn_intro_actions(FakeOwner.new(6))
	result = helper.resolve_spawn_intro_actions(
		actions,
		FakeOwner.new(6),
		null,
		Callable(self, "_apply_dimension_gate"),
		Callable(self, "_apply_full_gauge")
	)
	_expect(bool(result.get("dimension_gate_failed", false)), "failed Dimension Gate callback should report failure")
	_expect(not bool(result.get("dimension_gate_activated", false)), "failed Dimension Gate callback should not report activation")
	_expect(str(result.get("_feedback_text", "")) == "", "failed Dimension Gate should not set success feedback")


func _verify_helper_applies_spawn_intro_state_update() -> void:
	_feedback_apply_calls = 0
	var helper := RuntimePerkDeferredInstants.new()
	var state := FakeFeedbackState.new()
	var update: Dictionary = helper.apply_spawn_intro_state_update(
		state,
		{
			"dimension_gate_pending": true,
			"dimension_gate_activated": true,
			"_feedback_text": "Gate",
			"_feedback_timer": 1.2,
			"_sync_owner": true,
		},
		Callable(self, "_apply_feedback_state_update")
	)
	var public_result: Dictionary = update.get("public_result", {})
	_expect(_feedback_apply_calls == 1, "spawn-intro state update helper should apply feedback once")
	_expect(str(state.feedback_text) == "Gate", "spawn-intro state update helper should write feedback text")
	_expect(is_equal_approx(float(state.feedback_timer), 1.2), "spawn-intro state update helper should write feedback timer")
	_expect(bool(update.get("sync_owner", false)), "spawn-intro state update helper should preserve owner-sync request")
	_expect(not public_result.has("_feedback_text"), "spawn-intro state update helper should strip helper-only feedback text")
	_expect(not public_result.has("_sync_owner"), "spawn-intro state update helper should strip helper-only sync flag")

	helper.apply_spawn_intro_state_update(
		state,
		{"dimension_gate_pending": true, "_feedback_text": "", "_sync_owner": false},
		Callable(self, "_apply_feedback_state_update")
	)
	_expect(_feedback_apply_calls == 1, "spawn-intro state update helper should skip feedback callback without text")


func _verify_state_apply_choice_uses_deferred_choice_payloads() -> void:
	var registry := FakeRegistry.new({})

	var gauge_state := RuntimePerkState.new()
	gauge_state.current_choice_context = {
		RuntimePerkDeferredInstants.DEFER_FULL_GAUGE_CONTEXT_KEY: true,
	}
	_expect(gauge_state.apply_choice({"id": "instant_gauge_full", "name": "Gauge"}, FakeOwner.new(5), registry), "state apply_choice should accept deferred full gauge")
	_expect(gauge_state.has_pending_full_gauge_after_spawn_intro(), "state apply_choice should queue deferred full gauge")
	_expect(str(gauge_state.feedback_text) == "Gauge", "state apply_choice should use deferred full-gauge queue feedback text")
	_expect(is_equal_approx(float(gauge_state.feedback_timer), RuntimePerkDeferredInstants.DEFERRED_CHOICE_FEEDBACK_TIMER), "state apply_choice should use deferred full-gauge queue feedback timer")

	var gate_state := RuntimePerkState.new()
	gate_state.current_choice_context = {
		RuntimePerkDeferredInstants.DEFER_DIMENSION_GATE_CONTEXT_KEY: true,
	}
	_expect(gate_state.apply_choice({"id": "instant_dimension_gate", "name": "Gate"}, FakeOwner.new(5), registry), "state apply_choice should accept deferred Dimension Gate")
	_expect(gate_state.has_pending_dimension_gate_after_spawn_intro(), "state apply_choice should queue deferred Dimension Gate")
	_expect(str(gate_state.feedback_text) == "Gate", "state apply_choice should use deferred Dimension Gate queue feedback text")
	_expect(is_equal_approx(float(gate_state.feedback_timer), RuntimePerkDeferredInstants.DEFERRED_CHOICE_FEEDBACK_TIMER), "state apply_choice should use deferred Dimension Gate queue feedback timer")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(state_source.find("func _queue_dimension_gate_after_spawn_intro_choice") >= 0, "state should route deferred Dimension Gate queue choice through helper")
	_expect(state_source.find("func _queue_full_gauge_after_spawn_intro_choice") >= 0, "state should route deferred full-gauge queue choice through helper")


func _verify_state_wrapper_preserves_public_result_shape() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new(5)
	var registry := FakeRegistry.new({"active_item_runtime": FakeActiveItemRuntime.new()})
	state.current_choice_context = {
		RuntimePerkDeferredInstants.DEFER_DIMENSION_GATE_CONTEXT_KEY: true,
	}
	state._queue_dimension_gate_after_spawn_intro(owner, "Gate")
	owner.current_stage = 6
	var result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(result.get("dimension_gate_activated", false)), "state wrapper should activate ready Dimension Gate")
	_expect(str(state.feedback_text) == "Gate", "state wrapper should apply feedback text")
	_expect(not result.has("_feedback_text"), "state wrapper should not expose helper-only feedback text")
	_expect(not result.has("_sync_owner"), "state wrapper should not expose helper-only sync flag")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
	var intro_body: String = _function_body(state_source, "func on_ball_spawn_intro_finished(")
	_expect(intro_body.find("_instant_choice_flow.on_ball_spawn_intro_finished_from_runtime_state") >= 0, "state spawn-intro wrapper should delegate to instant choice flow runtime-state API")
	_expect(flow_source.find("func on_ball_spawn_intro_finished_from_runtime_state") >= 0, "instant choice flow should own runtime-state spawn-intro assembly")
	_expect(flow_source.find("apply_spawn_intro_state_update") >= 0, "instant choice flow should consume helper-owned update application")
	_expect(intro_body.find("build_spawn_intro_state_update") < 0, "state spawn-intro wrapper should not build state update inline")
	_expect(intro_body.find("apply_feedback_state_update(self, state_update") < 0, "state spawn-intro wrapper should not apply feedback inline")
	_expect(intro_body.find("collect_spawn_intro_actions") < 0, "state spawn-intro wrapper should not collect actions inline")
	_expect(intro_body.find("resolve_spawn_intro_actions") < 0, "state spawn-intro wrapper should not resolve actions inline")
	_expect(intro_body.find("_deferred_instants") < 0, "state spawn-intro wrapper should not pass deferred helper directly")
	_expect(intro_body.find("_choice_feedback") < 0, "state spawn-intro wrapper should not pass feedback helper directly")
	_expect(state_source.find("get(\"_feedback_text\"") < 0, "state wrapper should not read helper-only feedback text key")
	_expect(state_source.find("[\"_feedback_text\"]") < 0, "state wrapper should not index helper-only feedback text key")
	_expect(state_source.find("get(\"_sync_owner\"") < 0, "state wrapper should not read helper-only sync key")
	_expect(state_source.find("[\"_sync_owner\"]") < 0, "state wrapper should not index helper-only sync key")


func _apply_dimension_gate(_registry: Object) -> bool:
	_dimension_gate_calls += 1
	return _dimension_gate_result


func _apply_full_gauge(_owner: Object, _registry: Object) -> void:
	_full_gauge_calls += 1


func _apply_feedback_state_update(runtime_state: Object, update: Dictionary, fallback_timer: float = 0.0) -> Dictionary:
	_feedback_apply_calls += 1
	if runtime_state == null:
		return {"accepted": false}
	runtime_state.set("feedback_text", str(update.get("feedback_text", "")))
	runtime_state.set("feedback_timer", float(update.get("feedback_timer", fallback_timer)))
	return {"accepted": true}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


class FakeOwner:
	var current_stage := 0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false
	var runtime_perk_gold := 0
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0

	func _init(stage: int) -> void:
		current_stage = stage


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeActiveItemRuntime:
	var activate_calls := 0

	func activate_dimension_gate(_registry: Object) -> bool:
		activate_calls += 1
		return true


class FakeFeedbackState:
	var feedback_text := ""
	var feedback_timer := 0.0
