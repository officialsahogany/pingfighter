extends SceneTree

const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")

var _failures: Array[String] = []


func _init() -> void:
	var flow := MysticDiceModalFlow.new()
	var first_roll := _roll(0.0)
	_expect(flow.start(_card(), [_card(), {"id": "other"}], first_roll), "valid card and seven-stat roll should start D1")
	_expect(flow.get_phase() == MysticDiceModalFlow.PHASE_ROLLING, "start should enter D1 rolling")
	_expect(not bool(flow.update(1.99).get("entered_result", true)), "D1 should remain rolling before two seconds")
	_expect(bool(flow.update(0.01).get("entered_result", false)), "D1 should enter D2 at two seconds")
	_expect(flow.get_phase() == MysticDiceModalFlow.PHASE_RESULT, "roll completion should enter D2")
	_expect(int(flow.get_snapshot().get("selected_action", -1)) == MysticDiceModalFlow.ACTION_CONFIRM, "D2 should default to confirm, not accidental reroll")

	flow.set_selected_action(MysticDiceModalFlow.ACTION_REROLL)
	_expect(bool(flow.request_selected_action().get("reroll_requested", false)), "D2 reroll selection should request one reroll")
	var second_roll := _roll(0.5)
	_expect(flow.begin_reroll(second_roll), "first reroll should re-enter D1")
	_expect(int(flow.get_snapshot().get("rerolls_remaining", -1)) == 1, "first reroll should leave one reroll")
	_expect((flow.get_snapshot().get("current_roll", {}) as Dictionary) == second_roll, "reroll should fully replace, not accumulate, the prior roll")
	flow.update(2.0)
	flow.set_selected_action(MysticDiceModalFlow.ACTION_REROLL)
	_expect(flow.begin_reroll(_roll(1.0)), "second reroll should be accepted")
	flow.update(2.0)
	_expect(int(flow.get_snapshot().get("rerolls_remaining", -1)) == 0, "second reroll should exhaust the budget")
	_expect(int(flow.get_snapshot().get("selected_action", -1)) == MysticDiceModalFlow.ACTION_CONFIRM, "exhausted D2 should select confirm")
	_expect(not flow.set_selected_action(MysticDiceModalFlow.ACTION_REROLL), "exhausted D2 should reject a third reroll selection")
	_expect(not flow.begin_reroll(_roll(0.25)), "exhausted D2 should reject a third reroll payload")

	var commit_request: Dictionary = flow.request_selected_action()
	_expect(bool(commit_request.get("commit_requested", false)), "D2 confirm should request one commit")
	_expect(not bool(flow.request_selected_action().get("commit_requested", true)), "repeated D2 confirm should not request a second commit")
	var committed_choice := {"id": "mystic_dice", "mystic_dice_revision": 1}
	_expect(flow.mark_committed({"accepted": true, "revision": 1}, committed_choice), "accepted commit should enter transient D3")
	_expect(flow.get_phase() == MysticDiceModalFlow.PHASE_COMMITTED, "accepted commit should enter D3 committed")

	var snapshot: Dictionary = flow.get_snapshot()
	(snapshot.get("current_roll", {}) as Dictionary).clear()
	_expect(not (flow.get_snapshot().get("current_roll", {}) as Dictionary).is_empty(), "modal snapshot should not alias the active roll")
	flow.reset()
	_expect(not flow.is_active() and flow.get_snapshot().get("current_roll", {}) == {}, "reset should clear all modal state")

	if _failures.is_empty():
		print("mystic_dice_modal_flow_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _roll(unit: float) -> Dictionary:
	var units: Array = []
	for _index: int in range(MysticDiceRoller.STAT_KEYS.size()):
		units.append(unit)
	return MysticDiceRoller.new().roll(units)


func _card() -> Dictionary:
	return {"id": "mystic_dice", "is_mystic_dice": true}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
