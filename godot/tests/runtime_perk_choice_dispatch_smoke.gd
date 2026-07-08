extends SceneTree

const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_dispatch_actions()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_dispatch_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatch_actions() -> void:
	var helper := RuntimePerkChoiceDispatch.new()
	_expect_action(helper.build_dispatch({}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_INVALID, false, "empty id should be invalid")
	_expect_action(helper.build_dispatch({"id": "convert_to_gold"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_CONVERT_TO_GOLD, true, "gold conversion should route to gold action")
	_expect_action(helper.build_dispatch({"id": "instant_gauge_full"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_FULL_GAUGE, true, "full gauge should route to immediate action")
	_expect_action(helper.build_dispatch({"id": "instant_gauge_full"}, true, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_FULL_GAUGE_DEFERRED, true, "full gauge should route to deferred action when requested")
	_expect_action(helper.build_dispatch({"id": "instant_dimension_gate"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_DIMENSION_GATE, true, "Dimension Gate should route to immediate action")
	_expect_action(helper.build_dispatch({"id": "instant_dimension_gate"}, false, true, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_DIMENSION_GATE_DEFERRED, true, "Dimension Gate should route to deferred action when requested")
	_expect_action(helper.build_dispatch({"id": "instant_monkey_blessing"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_MONKEY_BLESSING, true, "Monkey Blessing should route to its action")
	_expect_action(helper.build_dispatch({"id": "instant_treasure_hunt"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_TREASURE_HUNT, true, "Treasure Hunt should route to its action")
	_expect_action(helper.build_dispatch({"id": "chip"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_LINGPET_AFFINITY_CHIP, true, "Lingpet affinity chip should route to its action")
	_expect_action(helper.build_dispatch({"id": "ring"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_LINGPET_RING_CORE_UPGRADE, true, "Lingpet ring-core upgrade should route to its action")
	_expect_action(helper.build_dispatch({"id": "common_refresh", "is_instant": true}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_STANDARD, true, "generic instant bookkeeping should stay on the standard path")
	_expect_action(helper.build_dispatch({"id": "unlock_plasma", "unlocks_skill": "plasma"}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_STANDARD, true, "unlock choices should stay on the standard path after explicit dispatch")
	_expect_action(helper.build_dispatch({"id": " common_swiftness "}, false, false, "chip", "ring"), RuntimePerkChoiceDispatch.ACTION_STANDARD, true, "ordinary level choices should stay on the standard path")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var apply_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var dispatch_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_dispatch.gd")
	_expect(state_source.find("RuntimePerkChoiceDispatch") >= 0, "state should preload choice dispatch helper")
	_expect(state_source.find("RuntimePerkChoiceApplyFlow") >= 0, "state should preload choice apply-flow helper")
	_expect(state_source.find("_choice_apply_flow.apply_choice") >= 0, "state should route choice application through apply-flow helper")
	_expect(apply_flow_source.find("build_dispatch(") >= 0, "apply-flow helper should consume helper-owned dispatch payloads")
	_expect(dispatch_source.find("instant_gauge_full") >= 0, "dispatch helper should own full-gauge action id matching")
	_expect(dispatch_source.find("instant_dimension_gate") >= 0, "dispatch helper should own Dimension Gate action id matching")
	_expect(dispatch_source.find("instant_monkey_blessing") >= 0, "dispatch helper should own Monkey Blessing action id matching")
	_expect(dispatch_source.find("instant_treasure_hunt") >= 0, "dispatch helper should own Treasure Hunt action id matching")
	var apply_body: String = _function_body(apply_flow_source, "func apply_choice(")
	_expect(apply_body.find("if choice_id == \"instant_gauge_full\"") < 0, "state should not own full-gauge id branch inline")
	_expect(apply_body.find("if choice_id == \"instant_dimension_gate\"") < 0, "state should not own Dimension Gate id branch inline")
	_expect(apply_body.find("if choice_id == LINGPET_AFFINITY_CHIP_CHOICE_ID") < 0, "state should not own affinity-chip id branch inline")
	_expect(apply_body.find("if choice_id == LINGPET_RING_CORE_UPGRADE_CHOICE_ID") < 0, "state should not own ring-core id branch inline")


func _expect_action(result: Dictionary, expected_action: String, expected_accepted: bool, message: String) -> void:
	_expect(bool(result.get("accepted", false)) == expected_accepted, "%s accepted flag" % message)
	_expect(str(result.get("action", "")) == expected_action, "%s (expected action %s, got %s)" % [message, expected_action, str(result.get("action", ""))])


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
