extends SceneTree

const RuntimePerkUnlockShowcaseFlow := preload("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_open_showcase_applies_and_syncs_owner()
	_verify_runtime_state_facade_open_showcase_applies_and_syncs_owner()
	_verify_non_showcase_path_finishes_immediately()
	_verify_update_auto_dismisses_and_finishes_choice()
	_verify_runtime_state_facade_update_auto_dismisses_and_finishes_choice()
	_verify_input_dismisses_and_finishes_choice()
	_verify_runtime_state_facade_input_dismisses_and_finishes_choice()
	_verify_missing_choice_id_syncs_owner_without_finishing()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_unlock_showcase_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_open_showcase_applies_and_syncs_owner() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.should_open_result = true
	var choice := {"id": "unlock_plasma", "unlocks_skill": "plasma"}
	var result: Dictionary = helper.finish_or_open_unlock_showcase(
		"unlock_plasma",
		FakeOwner.new(),
		FakeRegistry.new(),
		null,
		choice,
		state,
		controller,
		helper.build_state_callbacks(state)
	)
	_expect(bool(result.get("accepted", false)), "showcase flow should accept an opened showcase")
	_expect(bool(result.get("opened_showcase", false)), "showcase flow should report opened showcases")
	_expect(bool(state.unlock_showcase.get("active", false)), "showcase flow should apply showcase state")
	_expect(str(state.unlock_showcase.get("choice_id", "")) == "unlock_plasma", "showcase flow should keep choice id")
	_expect(state.sync_owner_calls == 1, "showcase flow should sync owner after applying showcase")
	_expect(state.finish_calls == 0, "showcase flow should delay finish while showcase is open")
	_expect(controller.build_calls == 1, "showcase flow should build one showcase payload")
	_expect(controller.apply_calls == 1, "showcase flow should apply one showcase payload")


func _verify_runtime_state_facade_open_showcase_applies_and_syncs_owner() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.should_open_result = true
	state._unlock_showcase_controller = controller
	var choice := {"id": "unlock_plasma", "unlocks_skill": "plasma"}
	var result: Dictionary = helper.finish_or_open_unlock_showcase_from_runtime_state(
		state,
		"unlock_plasma",
		FakeOwner.new(),
		FakeRegistry.new(),
		null,
		choice
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept an opened showcase")
	_expect(bool(result.get("opened_showcase", false)), "runtime-state facade should report opened showcases")
	_expect(bool(state.unlock_showcase.get("active", false)), "runtime-state facade should apply showcase state")
	_expect(str(state.unlock_showcase.get("choice_id", "")) == "unlock_plasma", "runtime-state facade should keep choice id")
	_expect(state.sync_owner_calls == 1, "runtime-state facade should sync owner after applying showcase")
	_expect(state.finish_calls == 0, "runtime-state facade should delay finish while showcase is open")


func _verify_non_showcase_path_finishes_immediately() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.should_open_result = false
	var result: Dictionary = helper.finish_or_open_unlock_showcase(
		"bulk_up",
		FakeOwner.new(),
		FakeRegistry.new(),
		null,
		{"id": "bulk_up"},
		state,
		controller,
		helper.build_state_callbacks(state)
	)
	_expect(bool(result.get("accepted", false)), "non-showcase path should accept successful finish")
	_expect(bool(result.get("finished", false)), "non-showcase path should report finished")
	_expect(state.finish_calls == 1, "non-showcase path should finish immediately")
	_expect(str(state.finished_choice_id) == "bulk_up", "non-showcase path should pass the choice id")
	_expect(state.sync_owner_calls == 0, "non-showcase path should not sync showcase owner state")
	_expect(controller.apply_calls == 0, "non-showcase path should not apply showcase state")


func _verify_update_auto_dismisses_and_finishes_choice() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.advance_result = true
	state.unlock_showcase = {
		"active": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	var result: Dictionary = helper.update_unlock_showcase(
		state.unlock_showcase,
		6.0,
		FakeOwner.new(),
		FakeRegistry.new(),
		controller,
		helper.build_state_callbacks(state)
	)
	_expect(bool(result.get("dismissed", false)), "auto-dismiss update should report dismissed")
	_expect(state.finish_calls == 1, "auto-dismiss update should finish the delayed choice")
	_expect(str(state.finished_choice_id) == "unlock_plasma", "auto-dismiss should pass consumed choice id")
	_expect(state.unlock_showcase.is_empty(), "auto-dismiss should consume and clear showcase state")
	_expect(controller.advance_calls == 1, "auto-dismiss path should advance showcase age")
	_expect(controller.consume_calls == 1, "auto-dismiss path should consume showcase state")


func _verify_runtime_state_facade_update_auto_dismisses_and_finishes_choice() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.advance_result = true
	state._unlock_showcase_controller = controller
	state.unlock_showcase = {
		"active": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	var result: Dictionary = helper.update_unlock_showcase_from_runtime_state(
		state,
		6.0,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(bool(result.get("dismissed", false)), "runtime-state facade auto-dismiss update should report dismissed")
	_expect(state.finish_calls == 1, "runtime-state facade auto-dismiss should finish the delayed choice")
	_expect(str(state.finished_choice_id) == "unlock_plasma", "runtime-state facade auto-dismiss should pass consumed choice id")
	_expect(state.unlock_showcase.is_empty(), "runtime-state facade auto-dismiss should consume and clear showcase state")


func _verify_input_dismisses_and_finishes_choice() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.should_dismiss_result = true
	state.unlock_showcase = {
		"active": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	var event := InputEventKey.new()
	event.pressed = true
	var result: Dictionary = helper.handle_unlock_showcase_input(
		state.unlock_showcase,
		event,
		FakeOwner.new(),
		FakeRegistry.new(),
		controller,
		helper.build_state_callbacks(state)
	)
	_expect(bool(result.get("handled", false)), "input path should report handled events")
	_expect(bool(result.get("dismissed", false)), "input path should dismiss when controller accepts input")
	_expect(state.finish_calls == 1, "input dismiss should finish the delayed choice")
	_expect(controller.should_dismiss_calls == 1, "input path should ask the showcase controller")
	_expect(state.unlock_showcase.is_empty(), "input dismiss should consume and clear showcase state")


func _verify_runtime_state_facade_input_dismisses_and_finishes_choice() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	controller.should_dismiss_result = true
	state._unlock_showcase_controller = controller
	state.unlock_showcase = {
		"active": true,
		"choice_id": "unlock_plasma",
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
	}
	var event := InputEventKey.new()
	event.pressed = true
	var result: Dictionary = helper.handle_unlock_showcase_input_from_runtime_state(
		state,
		event,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(bool(result.get("handled", false)), "runtime-state facade input path should report handled events")
	_expect(bool(result.get("dismissed", false)), "runtime-state facade input path should dismiss when controller accepts input")
	_expect(state.finish_calls == 1, "runtime-state facade input dismiss should finish the delayed choice")
	_expect(state.unlock_showcase.is_empty(), "runtime-state facade input dismiss should consume and clear showcase state")


func _verify_missing_choice_id_syncs_owner_without_finishing() -> void:
	var helper := RuntimePerkUnlockShowcaseFlow.new()
	var state := FakeRuntimeState.new()
	var controller := FakeShowcaseController.new()
	state.unlock_showcase = {"active": true}
	var result: Dictionary = helper.dismiss_unlock_showcase(
		state.unlock_showcase,
		FakeOwner.new(),
		FakeRegistry.new(),
		controller,
		helper.build_state_callbacks(state)
	)
	_expect(bool(result.get("dismissed", false)), "missing-choice dismiss should still clear the showcase")
	_expect(not bool(result.get("accepted", true)), "missing-choice dismiss should reject finishing")
	_expect(str(result.get("blocked_reason", "")) == "missing_choice_id", "missing-choice dismiss should explain why it did not finish")
	_expect(state.finish_calls == 0, "missing-choice dismiss should not finish a choice")
	_expect(state.sync_owner_calls == 1, "missing-choice dismiss should sync owner after clearing showcase")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")
	var finish_body: String = _function_body(state_source, "func _finish_or_open_unlock_showcase(")
	var update_body: String = _function_body(state_source, "func _update_unlock_showcase(")
	var dismiss_body: String = _function_body(state_source, "func _dismiss_unlock_showcase(")
	var input_body: String = _function_body(state_source, "func _handle_unlock_showcase_input(")
	var finish_facade_body: String = _function_body(helper_source, "func finish_or_open_unlock_showcase_from_runtime_state(")
	var update_facade_body: String = _function_body(helper_source, "func update_unlock_showcase_from_runtime_state(")
	var dismiss_facade_body: String = _function_body(helper_source, "func dismiss_unlock_showcase_from_runtime_state(")
	var input_facade_body: String = _function_body(helper_source, "func handle_unlock_showcase_input_from_runtime_state(")
	_expect(state_source.find("RuntimePerkUnlockShowcaseFlow") >= 0, "state should preload unlock-showcase flow helper")
	_expect(finish_body.find("_unlock_showcase_flow.finish_or_open_unlock_showcase_from_runtime_state") >= 0, "finish/showcase wrapper should delegate runtime-state assembly to flow helper")
	_expect(update_body.find("_unlock_showcase_flow.update_unlock_showcase_from_runtime_state") >= 0, "update wrapper should delegate runtime-state assembly to flow helper")
	_expect(dismiss_body.find("_unlock_showcase_flow.dismiss_unlock_showcase_from_runtime_state") >= 0, "dismiss wrapper should delegate runtime-state assembly to flow helper")
	_expect(input_body.find("_unlock_showcase_flow.handle_unlock_showcase_input_from_runtime_state") >= 0, "input wrapper should delegate runtime-state assembly to flow helper")
	_expect(finish_body.find("_unlock_showcase_controller") < 0, "finish/showcase wrapper should not pass controller inline")
	_expect(finish_body.find("build_state_callbacks(self)") < 0, "finish/showcase wrapper should not build callback map inline")
	_expect(update_body.find("\n\t\tunlock_showcase") < 0, "update wrapper should not pass showcase state inline")
	_expect(update_body.find("_unlock_showcase_controller") < 0, "update wrapper should not pass controller inline")
	_expect(update_body.find("build_state_callbacks(self)") < 0, "update wrapper should not build callback map inline")
	_expect(dismiss_body.find("\n\t\tunlock_showcase") < 0, "dismiss wrapper should not pass showcase state inline")
	_expect(dismiss_body.find("_unlock_showcase_controller") < 0, "dismiss wrapper should not pass controller inline")
	_expect(dismiss_body.find("build_state_callbacks(self)") < 0, "dismiss wrapper should not build callback map inline")
	_expect(input_body.find("\n\t\tunlock_showcase") < 0, "input wrapper should not pass showcase state inline")
	_expect(input_body.find("_unlock_showcase_controller") < 0, "input wrapper should not pass controller inline")
	_expect(input_body.find("build_state_callbacks(self)") < 0, "input wrapper should not build callback map inline")
	_expect(helper_source.find("func finish_or_open_unlock_showcase_from_runtime_state(") >= 0, "showcase flow helper should expose finish/open runtime-state facade")
	_expect(helper_source.find("func update_unlock_showcase_from_runtime_state(") >= 0, "showcase flow helper should expose update runtime-state facade")
	_expect(helper_source.find("func dismiss_unlock_showcase_from_runtime_state(") >= 0, "showcase flow helper should expose dismiss runtime-state facade")
	_expect(helper_source.find("func handle_unlock_showcase_input_from_runtime_state(") >= 0, "showcase flow helper should expose input runtime-state facade")
	_expect(finish_facade_body.find("_unlock_showcase_controller") >= 0, "finish/open facade should own controller lookup")
	_expect(finish_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "finish/open facade should own callback-map assembly")
	_expect(update_facade_body.find("unlock_showcase") >= 0, "update facade should own showcase state lookup")
	_expect(update_facade_body.find("_unlock_showcase_controller") >= 0, "update facade should own controller lookup")
	_expect(update_facade_body.find("build_state_callbacks(runtime_state)") >= 0, "update facade should own callback-map assembly")
	_expect(dismiss_facade_body.find("unlock_showcase") >= 0, "dismiss facade should own showcase state lookup")
	_expect(input_facade_body.find("unlock_showcase") >= 0, "input facade should own showcase state lookup")
	_expect(state_source.find("_unlock_showcase_controller.apply_showcase_state_update") < 0, "state should not apply showcase state directly")
	_expect(state_source.find("_unlock_showcase_controller.consume(unlock_showcase") < 0, "state should not consume showcase payloads directly")
	_expect(state_source.find("_unlock_showcase_controller.should_dismiss_from_input(unlock_showcase") < 0, "state should not own showcase input-dismiss checks")
	_expect(state_source.find("func _open_unlock_showcase(") < 0, "state should not keep a separate open-showcase orchestration function")
	_expect(helper_source.find("apply_showcase_state_update") >= 0, "showcase flow helper should apply showcase state")
	_expect(helper_source.find("consume(unlock_showcase") >= 0, "showcase flow helper should consume showcase state")
	_expect(helper_source.find("should_dismiss_from_input(unlock_showcase") >= 0, "showcase flow helper should own input-dismiss checks")
	_expect(helper_source.find("advance(unlock_showcase") >= 0, "showcase flow helper should advance showcase age")
	_expect(helper_source.find("CALLBACK_FINISH_SUCCESSFUL_CHOICE") >= 0, "showcase flow helper should finish through callback handoff")


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

	var unlock_showcase: Dictionary = {}
	var finish_calls := 0
	var sync_owner_calls := 0
	var finished_choice_id := ""
	var finished_choice: Dictionary = {}
	var _unlock_showcase_controller: Object = null

	func _finish_successful_choice(
		choice_id: String,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object = null,
		choice: Dictionary = {}
	) -> void:
		finish_calls += 1
		finished_choice_id = choice_id
		finished_choice = choice.duplicate(true)

	func _sync_owner(_owner: Object) -> void:
		sync_owner_calls += 1

	func is_unlock_showcase_active() -> bool:
		return bool(unlock_showcase.get("active", false))


class FakeShowcaseController:
	extends RefCounted

	var should_open_result := false
	var should_dismiss_result := false
	var advance_result := false
	var build_calls := 0
	var apply_calls := 0
	var advance_calls := 0
	var should_dismiss_calls := 0
	var consume_calls := 0

	func should_open(_choice: Dictionary, _owner: Object) -> bool:
		return should_open_result

	func build(choice_id: String, _owner: Object, _registry: Object, choice: Dictionary) -> Dictionary:
		build_calls += 1
		return {
			"active": true,
			"choice_id": choice_id,
			"choice": choice.duplicate(true),
			"skill_id": str(choice.get("unlocks_skill", "")),
		}

	func apply_showcase_state_update(runtime_state: Object, showcase: Dictionary) -> Dictionary:
		apply_calls += 1
		runtime_state.set("unlock_showcase", showcase.duplicate(true))
		return {
			"accepted": true,
			"active": bool(showcase.get("active", false)),
			"choice_id": str(showcase.get("choice_id", "")),
		}

	func advance(_showcase: Dictionary, _delta: float) -> bool:
		advance_calls += 1
		return advance_result

	func should_dismiss_from_input(_showcase: Dictionary, _event: InputEvent) -> bool:
		should_dismiss_calls += 1
		return should_dismiss_result

	func consume(showcase: Dictionary) -> Dictionary:
		consume_calls += 1
		var payload: Dictionary = showcase.duplicate(true)
		showcase.clear()
		return payload

	func is_active(showcase: Dictionary) -> bool:
		return bool(showcase.get("active", false))


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted
