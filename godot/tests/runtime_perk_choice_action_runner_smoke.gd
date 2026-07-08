extends SceneTree

const RuntimePerkChoiceActionRunner := preload("res://scripts/characters/runtime_perk_choice_action_runner.gd")
const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")

var _failures: Array[String] = []
var _calls: Array[Dictionary] = []
var _feedback_apply_calls := 0
var _feedback_choice_id := ""
var _feedback_text := ""
var _feedback_timer := 0.0


func _init() -> void:
	_verify_bool_callback_action()
	_verify_dispatch_runner()
	_verify_feedback_callback_actions()
	_verify_handled_result_application()
	_verify_missing_callback_and_standard_action()
	_verify_callback_builder()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_action_runner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bool_callback_action() -> void:
	_calls.clear()
	var result: Dictionary = RuntimePerkChoiceActionRunner.new().run(
		RuntimePerkChoiceDispatch.ACTION_CONVERT_TO_GOLD,
		{"id": "convert_to_gold"},
		FakeOwner.new(),
		FakeRegistry.new(),
		_callbacks()
	)
	_expect(bool(result.get("handled", false)), "gold conversion action should be handled")
	_expect(bool(result.get("accepted", false)), "gold conversion callback result should be accepted")
	_expect(not bool(result.get("uses_feedback", true)), "gold conversion action should not request feedback application")
	_expect(_calls.size() == 1 and str(_calls[0].get("key", "")) == "gold", "gold conversion should call the gold callback once")


func _verify_dispatch_runner() -> void:
	_calls.clear()
	var runner := RuntimePerkChoiceActionRunner.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var gold: Dictionary = runner.run_dispatch(
		{
			"accepted": true,
			"action": RuntimePerkChoiceDispatch.ACTION_CONVERT_TO_GOLD,
		},
		{"id": "convert_to_gold"},
		owner,
		registry,
		_callbacks()
	)
	_expect(bool(gold.get("handled", false)), "dispatch runner should handle explicit actions")
	_expect(bool(gold.get("accepted", false)), "dispatch runner should preserve explicit action acceptance")
	_expect(_calls.size() == 1 and str(_calls[0].get("key", "")) == "gold", "dispatch runner should route action callbacks")

	var standard: Dictionary = runner.run_dispatch(
		{"accepted": true},
		{"id": "common_swiftness"},
		owner,
		registry,
		_callbacks()
	)
	_expect(not bool(standard.get("handled", true)), "dispatch runner should let missing action fall through as standard")

	_calls.clear()
	var rejected: Dictionary = runner.run_dispatch(
		{
			"accepted": false,
			"action": RuntimePerkChoiceDispatch.ACTION_CONVERT_TO_GOLD,
		},
		{"id": "convert_to_gold"},
		owner,
		registry,
		_callbacks()
	)
	_expect(bool(rejected.get("handled", false)), "rejected dispatch should be handled closed")
	_expect(not bool(rejected.get("accepted", true)), "rejected dispatch should not be accepted")
	_expect(str(rejected.get("blocked_reason", "")) == "dispatch_rejected", "rejected dispatch should expose the blocked reason")
	_expect(_calls.is_empty(), "rejected dispatch should not call action callbacks")


func _verify_feedback_callback_actions() -> void:
	_calls.clear()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runner := RuntimePerkChoiceActionRunner.new()
	var gauge_deferred: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_FULL_GAUGE_DEFERRED,
		{"id": "instant_gauge_full", "name": "Gauge"},
		owner,
		registry,
		_callbacks()
	)
	_expect_feedback(gauge_deferred, RuntimePerkChoiceActionRunner.TIMER_IMMEDIATE, "Gauge", "deferred full gauge")
	_expect(str(_calls.back().get("key", "")) == "queue_full_gauge", "deferred full gauge should call the queue callback")

	var gate: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_DIMENSION_GATE,
		{"id": "instant_dimension_gate", "name": "Gate"},
		owner,
		registry,
		_callbacks()
	)
	_expect_feedback(gate, RuntimePerkChoiceActionRunner.TIMER_IMMEDIATE, "dimension", "Dimension Gate")
	_expect(str(_calls.back().get("key", "")) == "dimension", "Dimension Gate should call the immediate gate callback")

	var monkey: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_MONKEY_BLESSING,
		{"id": "instant_monkey_blessing", "name": "Monkey"},
		owner,
		registry,
		_callbacks()
	)
	_expect_feedback(monkey, RuntimePerkChoiceActionRunner.TIMER_MONKEY_BLESSING, "Monkey", "Monkey Blessing")
	_expect(str(_calls.back().get("key", "")) == "monkey", "Monkey Blessing should call the monkey callback")

	var treasure: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_TREASURE_HUNT,
		{"id": "instant_treasure_hunt", "name": "Treasure"},
		owner,
		registry,
		_callbacks()
	)
	_expect_feedback(treasure, RuntimePerkChoiceActionRunner.TIMER_TREASURE_HUNT, "treasure", "Treasure Hunt")
	_expect(str(_calls.back().get("key", "")) == "treasure", "Treasure Hunt should call the treasure callback")

	var chip: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_LINGPET_AFFINITY_CHIP,
		{"id": "lingpet_affinity_chip", "name": "Chip"},
		owner,
		registry,
		_callbacks()
	)
	_expect_feedback(chip, RuntimePerkChoiceActionRunner.TIMER_LINGPET, "Chip", "Lingpet affinity chip")
	_expect(str(_calls.back().get("key", "")) == "chip", "Lingpet affinity chip should call the chip callback")

	var ring: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_LINGPET_RING_CORE_UPGRADE,
		{"id": "lingpet_ring_core_upgrade", "name": "Ring", "next_tier": 3},
		owner,
		registry,
		_callbacks()
	)
	_expect_feedback(ring, RuntimePerkChoiceActionRunner.TIMER_LINGPET, "Ring 3", "Lingpet ring-core upgrade")
	_expect(str(_calls.back().get("key", "")) == "ring" and int(_calls.back().get("tier", 0)) == 3, "ring-core callback should receive the target tier")


func _verify_missing_callback_and_standard_action() -> void:
	var runner := RuntimePerkChoiceActionRunner.new()
	var missing: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_FULL_GAUGE,
		{"id": "instant_gauge_full"},
		FakeOwner.new(),
		FakeRegistry.new(),
		{}
	)
	_expect(bool(missing.get("handled", false)), "missing callback action should still be handled")
	_expect(not bool(missing.get("accepted", true)), "missing callback action should fail closed")
	_expect(bool(missing.get("uses_feedback", false)), "missing feedback callback should keep feedback shape")

	var standard: Dictionary = runner.run(
		RuntimePerkChoiceDispatch.ACTION_STANDARD,
		{"id": "common_swiftness"},
		FakeOwner.new(),
		FakeRegistry.new(),
		_callbacks()
	)
	_expect(not bool(standard.get("handled", true)), "standard action should fall through to state bookkeeping/unlock/level paths")


func _verify_handled_result_application() -> void:
	var runner := RuntimePerkChoiceActionRunner.new()
	_feedback_apply_calls = 0
	_feedback_choice_id = ""
	_feedback_text = ""
	_feedback_timer = 0.0
	var feedback_result: Dictionary = runner.apply_handled_result(
		{
			"handled": true,
			"accepted": true,
			"uses_feedback": true,
			"feedback_result": {"accepted": true, "feedback_text": "full"},
			"fallback_timer": 1.25,
		},
		{"id": "instant_gauge_full"},
		Callable(self, "_apply_feedback")
	)
	_expect(bool(feedback_result.get("handled", false)), "handled feedback result should stay handled")
	_expect(bool(feedback_result.get("accepted", false)), "handled feedback result should accept callback success")
	_expect(_feedback_apply_calls == 1, "handled feedback result should call feedback callback once")
	_expect(_feedback_choice_id == "instant_gauge_full", "handled feedback result should pass choice payload")
	_expect(_feedback_text == "full", "handled feedback result should pass feedback payload")
	_expect(is_equal_approx(_feedback_timer, 1.25), "handled feedback result should pass fallback timer")

	var bool_result: Dictionary = runner.apply_handled_result(
		{
			"handled": true,
			"accepted": true,
			"uses_feedback": false,
		},
		{"id": "convert_to_gold"},
		Callable(self, "_apply_feedback")
	)
	_expect(bool(bool_result.get("handled", false)), "handled bool result should stay handled")
	_expect(bool(bool_result.get("accepted", false)), "handled bool result should preserve accepted flag")
	_expect(_feedback_apply_calls == 1, "handled bool result should not call feedback callback")

	var standard_result: Dictionary = runner.apply_handled_result(
		{"handled": false},
		{"id": "common_swiftness"},
		Callable(self, "_apply_feedback")
	)
	_expect(not bool(standard_result.get("handled", true)), "unhandled action result should keep standard path open")
	_expect(not bool(runner.apply_handled_result({"handled": true, "uses_feedback": true}, {"id": "bad"}, Callable()).get("accepted", true)), "feedback action result should reject missing feedback callback")


func _verify_callback_builder() -> void:
	var runner := RuntimePerkChoiceActionRunner.new()
	_expect(runner.build_state_action_callbacks(null).is_empty(), "callback builder should tolerate a null state")
	var provider := CallbackProvider.new()
	var callbacks: Dictionary = runner.build_state_action_callbacks(provider)
	_expect(callbacks.size() == 9, "callback builder should expose every explicit action callback")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_CONVERT_TO_GOLD), "callback builder should wire gold conversion")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_FULL_GAUGE_DEFERRED), "callback builder should wire deferred full gauge")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_FULL_GAUGE), "callback builder should wire immediate full gauge")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_DIMENSION_GATE_DEFERRED), "callback builder should wire deferred Dimension Gate")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_DIMENSION_GATE), "callback builder should wire immediate Dimension Gate")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_MONKEY_BLESSING), "callback builder should wire Monkey Blessing")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_TREASURE_HUNT), "callback builder should wire Treasure Hunt")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_LINGPET_AFFINITY_CHIP), "callback builder should wire Lingpet affinity chip")
	_expect(_callback_is_valid(callbacks, RuntimePerkChoiceActionRunner.CALLBACK_LINGPET_RING_CORE_UPGRADE), "callback builder should wire Lingpet ring-core upgrade")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var apply_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var runner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_action_runner.gd")
	_expect(state_source.find("RuntimePerkChoiceActionRunner") >= 0, "state should preload the action runner")
	_expect(state_source.find("RuntimePerkChoiceApplyFlow") >= 0, "state should preload the choice apply-flow helper")
	_expect(state_source.find("_choice_apply_flow.apply_choice") >= 0, "state should route dispatch payloads through apply-flow helper")
	_expect(apply_flow_source.find("run_dispatch") >= 0, "apply-flow helper should route dispatch payloads through the action runner")
	_expect(apply_flow_source.find("apply_handled_result") >= 0, "apply-flow helper should delegate handled action result application to the runner")
	_expect(apply_flow_source.find("build_state_action_callbacks(runtime_state)") >= 0, "apply-flow helper should delegate action callback map assembly to the runner")
	_expect(state_source.find("CALLBACK_CONVERT_TO_GOLD: Callable(self") < 0, "state should not assemble explicit action callback maps inline")
	var apply_body: String = _function_body(apply_flow_source, "func apply_choice(")
	_expect(apply_body.find("dispatch.get(\"action\"") < 0, "apply_choice should not inspect dispatch action inline")
	_expect(apply_body.find("action_result.get(\"uses_feedback\"") < 0, "apply_choice should not inspect action feedback routing inline")
	_expect(apply_body.find("action_result.get(\"feedback_result\"") < 0, "apply_choice should not read action feedback payload inline")
	_expect(apply_body.find("action_result.get(\"fallback_timer\"") < 0, "apply_choice should not read action fallback timer inline")
	_expect(apply_body.find("_apply_full_gauge_choice(owner, registry)") < 0, "apply_choice should not call full-gauge action inline")
	_expect(apply_body.find("_apply_dimension_gate_choice(registry)") < 0, "apply_choice should not call Dimension Gate action inline")
	_expect(apply_body.find("_apply_lingpet_affinity_chip(owner") < 0, "apply_choice should not call Lingpet affinity action inline")
	_expect(runner_source.find("func run_dispatch(dispatch: Dictionary") >= 0, "runner should own dispatch action extraction")
	_expect(runner_source.find("func build_state_action_callbacks(state: Object)") >= 0, "runner should own state action callback map assembly")
	_expect(runner_source.find("CALLBACK_LINGPET_RING_CORE_UPGRADE") >= 0, "runner should own ring-core callback routing")
	_expect(runner_source.find("TIMER_TREASURE_HUNT := 1.6") >= 0, "runner should own Treasure Hunt fallback timer")


func _callbacks() -> Dictionary:
	return {
		RuntimePerkChoiceActionRunner.CALLBACK_CONVERT_TO_GOLD: Callable(self, "_gold"),
		RuntimePerkChoiceActionRunner.CALLBACK_FULL_GAUGE_DEFERRED: Callable(self, "_queue_full_gauge"),
		RuntimePerkChoiceActionRunner.CALLBACK_FULL_GAUGE: Callable(self, "_full_gauge"),
		RuntimePerkChoiceActionRunner.CALLBACK_DIMENSION_GATE_DEFERRED: Callable(self, "_queue_dimension_gate"),
		RuntimePerkChoiceActionRunner.CALLBACK_DIMENSION_GATE: Callable(self, "_dimension_gate"),
		RuntimePerkChoiceActionRunner.CALLBACK_MONKEY_BLESSING: Callable(self, "_monkey"),
		RuntimePerkChoiceActionRunner.CALLBACK_TREASURE_HUNT: Callable(self, "_treasure"),
		RuntimePerkChoiceActionRunner.CALLBACK_LINGPET_AFFINITY_CHIP: Callable(self, "_chip"),
		RuntimePerkChoiceActionRunner.CALLBACK_LINGPET_RING_CORE_UPGRADE: Callable(self, "_ring"),
	}


func _gold(_choice: Dictionary, _owner: Object, _registry: Object) -> bool:
	_calls.append({"key": "gold"})
	return true


func _queue_full_gauge(_owner: Object, choice_name: String) -> Dictionary:
	_calls.append({"key": "queue_full_gauge", "name": choice_name})
	return {"accepted": true, "feedback_text": choice_name}


func _full_gauge(_owner: Object, _registry: Object) -> Dictionary:
	_calls.append({"key": "full_gauge"})
	return {"accepted": true, "feedback_text": "full"}


func _queue_dimension_gate(_owner: Object, choice_name: String) -> Dictionary:
	_calls.append({"key": "queue_dimension", "name": choice_name})
	return {"accepted": true, "feedback_text": choice_name}


func _dimension_gate(_registry: Object) -> Dictionary:
	_calls.append({"key": "dimension"})
	return {"accepted": true, "feedback_text": "dimension"}


func _monkey(_owner: Object, _registry: Object, choice_name: String) -> Dictionary:
	_calls.append({"key": "monkey", "name": choice_name})
	return {"accepted": true, "feedback_text": choice_name}


func _treasure(_owner: Object, _registry: Object) -> Dictionary:
	_calls.append({"key": "treasure"})
	return {"accepted": true, "feedback_text": "treasure"}


func _chip(_owner: Object, _registry: Object, choice_name: String) -> Dictionary:
	_calls.append({"key": "chip", "name": choice_name})
	return {"accepted": true, "feedback_text": choice_name}


func _ring(_owner: Object, _registry: Object, tier: int, choice_name: String) -> Dictionary:
	_calls.append({"key": "ring", "tier": tier, "name": choice_name})
	return {"accepted": true, "feedback_text": "%s %d" % [choice_name, tier]}


func _apply_feedback(result: Dictionary, choice: Dictionary, fallback_timer: float) -> bool:
	_feedback_apply_calls += 1
	_feedback_choice_id = str(choice.get("id", ""))
	_feedback_text = str(_as_dict(result.get("feedback_result", result)).get("feedback_text", result.get("feedback_text", "")))
	if _feedback_text == "":
		_feedback_text = str(result.get("feedback_text", ""))
	_feedback_timer = fallback_timer
	return bool(result.get("accepted", false))


func _expect_feedback(result: Dictionary, fallback_timer: float, feedback_text: String, label: String) -> void:
	_expect(bool(result.get("handled", false)), "%s action should be handled" % label)
	_expect(bool(result.get("accepted", false)), "%s action should be accepted" % label)
	_expect(bool(result.get("uses_feedback", false)), "%s action should request feedback application" % label)
	_expect(is_equal_approx(float(result.get("fallback_timer", 0.0)), fallback_timer), "%s action should expose fallback timer" % label)
	_expect(str(_as_dict(result.get("feedback_result", {})).get("feedback_text", "")) == feedback_text, "%s action should preserve feedback result" % label)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _callback_is_valid(callbacks: Dictionary, key: String) -> bool:
	var value: Variant = callbacks.get(key, Callable())
	return value is Callable and value.is_valid()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted


class CallbackProvider:
	extends RefCounted

	func _apply_convert_to_gold_choice(_choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		return true

	func _queue_full_gauge_after_spawn_intro_choice(_owner: Object, _choice_name: String) -> Dictionary:
		return {"accepted": true}

	func _apply_full_gauge_choice(_owner: Object, _registry: Object) -> Dictionary:
		return {"accepted": true}

	func _queue_dimension_gate_after_spawn_intro_choice(_owner: Object, _choice_name: String) -> Dictionary:
		return {"accepted": true}

	func _apply_dimension_gate_choice(_registry: Object) -> Dictionary:
		return {"accepted": true}

	func _apply_monkey_blessing_choice(_owner: Object, _registry: Object, _choice_name: String) -> Dictionary:
		return {"accepted": true}

	func _apply_treasure_hunt_choice(_owner: Object, _registry: Object) -> Dictionary:
		return {"accepted": true}

	func _apply_lingpet_affinity_chip(_owner: Object, _registry: Object, _choice_name: String) -> Dictionary:
		return {"accepted": true}

	func _apply_lingpet_ring_core_upgrade(_owner: Object, _registry: Object, _tier: int, _choice_name: String) -> Dictionary:
		return {"accepted": true}
