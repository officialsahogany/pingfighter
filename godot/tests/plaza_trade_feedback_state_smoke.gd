extends SceneTree

const PlazaTradeFeedbackState := preload("res://scripts/plaza/plaza_trade_feedback_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaTradeFeedbackState.new()
	_expect(not state.record({}), "empty summary should not create feedback")
	_expect(not state.record({"changed": false, "action": "purchase"}), "unchanged trade should not create feedback")
	_expect(not state.record({"changed": true, "action": "reorder"}), "reorder should not create gold feedback")

	var purchase := {"changed": true, "action": "purchase", "item_name": "battery", "display_name": "배터리", "delta_gold": -500, "plaza_gold": 1500}
	_expect(state.record(purchase), "purchase should create feedback")
	_expect(state.feedbacks.size() == 1, "purchase should append one feedback")
	_expect(str(state.feedbacks[0].get("text", "")) == "-500G  배터리", "purchase feedback text")
	_expect(not state.record(purchase), "identical state sync should be deduplicated")
	_expect(state.feedbacks.size() == 1, "deduplication should preserve queue size")

	var sale := {"changed": true, "action": "sale", "item_name": "battery", "display_name": "", "delta_gold": 150, "plaza_gold": 1650}
	_expect(state.record(sale), "sale should create feedback")
	_expect(str(state.feedbacks[1].get("text", "")) == "+150G", "sale feedback without a display name")
	for index in range(4):
		state.record({"changed": true, "action": "purchase", "item_name": "item_%d" % index, "display_name": "I%d" % index, "delta_gold": -index - 1, "plaza_gold": 1600 - index})
	_expect(state.feedbacks.size() == PlazaTradeFeedbackState.MAX_FEEDBACKS, "feedback queue should cap at four")
	_expect(str(state.feedbacks[0].get("text", "")).find("I0") >= 0, "queue cap should discard oldest feedbacks")

	_expect(state.advance(0.4), "active feedbacks should request redraw while advancing")
	_expect_close(float(state.feedbacks[0].get("age", 0.0)), 0.4, "feedback age advance")
	_expect(state.advance(PlazaTradeFeedbackState.DEFAULT_DURATION), "expiry pass should still report prior activity")
	_expect(state.feedbacks.is_empty(), "expired feedbacks should be removed")
	_expect(not state.advance(0.1), "empty feedback state should not request redraw")
	state.record(purchase)
	state.reset()
	_expect(state.feedbacks.is_empty() and state.last_signature == "", "reset should clear queue and dedup signature")
	_expect(state.record(purchase), "reset should allow the same summary again")

	if _failures.is_empty():
		print("plaza_trade_feedback_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])
