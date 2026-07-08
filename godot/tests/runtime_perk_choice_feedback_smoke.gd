extends SceneTree

const RuntimePerkChoiceFeedback := preload("res://scripts/characters/runtime_perk_choice_feedback.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_apply_failure_feedback()
	_verify_bonus_pick_feedback()
	_verify_feedback_visibility_query()
	_verify_result_feedback()
	_verify_feedback_tick()
	_verify_feedback_state_application()
	_verify_state_consumes_helper()

	if _failures.is_empty():
		print("runtime_perk_choice_feedback_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_apply_failure_feedback() -> void:
	var helper := RuntimePerkChoiceFeedback.new()
	var failure: Dictionary = helper.build_apply_failure_feedback(false)
	_expect(not bool(failure.get("suppressed", true)), "ordinary apply failure should not be suppressed")
	_expect(str(failure.get("feedback_text", "")) == RuntimePerkChoiceFeedback.APPLY_FAILURE_TEXT, "ordinary apply failure should use helper text")
	_expect(is_equal_approx(float(failure.get("feedback_timer", 0.0)), RuntimePerkChoiceFeedback.APPLY_FAILURE_TIMER), "ordinary apply failure should use helper timer")

	var suppressed: Dictionary = helper.build_apply_failure_feedback(true)
	_expect(bool(suppressed.get("suppressed", false)), "pending swap apply failure should be suppressed")
	_expect(str(suppressed.get("feedback_text", "")) == "", "suppressed apply failure should clear text")
	_expect(is_equal_approx(float(suppressed.get("feedback_timer", -1.0)), 0.0), "suppressed apply failure should clear timer")

	var state := FakeFeedbackState.new()
	var applied: Dictionary = helper.apply_failure_feedback_state_update(state, false)
	_expect(bool(applied.get("accepted", false)), "failure feedback application should accept valid state")
	_expect(str(state.feedback_text) == RuntimePerkChoiceFeedback.APPLY_FAILURE_TEXT, "failure feedback application should write helper text")
	_expect(is_equal_approx(float(state.feedback_timer), RuntimePerkChoiceFeedback.APPLY_FAILURE_TIMER), "failure feedback application should write helper timer")
	helper.apply_failure_feedback_state_update(state, true)
	_expect(str(state.feedback_text) == "", "suppressed failure feedback application should clear text")
	_expect(is_equal_approx(float(state.feedback_timer), 0.0), "suppressed failure feedback application should clear timer")

	state.pending_unlock_swap = false
	helper.apply_failure_feedback_from_runtime_state(state)
	_expect(str(state.feedback_text) == RuntimePerkChoiceFeedback.APPLY_FAILURE_TEXT, "runtime-state failure wrapper should read swap state through helper")
	state.pending_unlock_swap = true
	helper.apply_failure_feedback_from_runtime_state(state)
	_expect(str(state.feedback_text) == "", "runtime-state failure wrapper should suppress while swap is pending")


func _verify_bonus_pick_feedback() -> void:
	var helper := RuntimePerkChoiceFeedback.new()
	var dowsing: Dictionary = helper.build_dowsing_goggles_bonus_feedback(0.25)
	_expect(str(dowsing.get("feedback_text", "")) == RuntimePerkChoiceFeedback.DOWSING_GOGGLES_BONUS_TEXT, "Dowsing bonus text should be helper-owned")
	_expect(is_equal_approx(float(dowsing.get("feedback_timer", 0.0)), RuntimePerkChoiceFeedback.DOWSING_GOGGLES_BONUS_TIMER), "Dowsing bonus should raise short timers")
	var dowsing_long: Dictionary = helper.build_dowsing_goggles_bonus_feedback(2.0)
	_expect(is_equal_approx(float(dowsing_long.get("feedback_timer", 0.0)), 2.0), "Dowsing bonus should preserve longer timers")
	var state := FakeFeedbackState.new()
	var applied_dowsing: Dictionary = helper.apply_dowsing_goggles_bonus_feedback_state_update(state, 0.25)
	_expect(bool(applied_dowsing.get("accepted", false)), "Dowsing feedback application should accept valid state")
	_expect(str(state.feedback_text) == RuntimePerkChoiceFeedback.DOWSING_GOGGLES_BONUS_TEXT, "Dowsing feedback application should write helper text")
	_expect(is_equal_approx(float(state.feedback_timer), RuntimePerkChoiceFeedback.DOWSING_GOGGLES_BONUS_TIMER), "Dowsing feedback application should write raised timer")

	var megingjord: Dictionary = helper.build_megingjord_extra_pick_feedback(0.25)
	_expect(str(megingjord.get("feedback_text", "")) == RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TEXT, "Megingjord bonus text should be helper-owned")
	_expect(is_equal_approx(float(megingjord.get("feedback_timer", 0.0)), RuntimePerkChoiceFeedback.MEGINGJORD_EXTRA_PICK_TIMER), "Megingjord bonus should raise short timers")


func _verify_feedback_visibility_query() -> void:
	var helper := RuntimePerkChoiceFeedback.new()
	_expect(helper.has_feedback("visible", 0.1), "feedback helper should treat positive timer plus text as visible")
	_expect(not helper.has_feedback("", 0.1), "feedback helper should reject empty text")
	_expect(not helper.has_feedback("expired", 0.0), "feedback helper should reject expired timers")
	_expect(not helper.has_feedback("negative", -0.1), "feedback helper should reject negative timers")
	var state := FakeFeedbackState.new()
	state.feedback_text = "visible"
	state.feedback_timer = 0.1
	_expect(helper.has_feedback_from_runtime_state(state), "runtime-state feedback query should read live feedback fields")
	state.feedback_timer = 0.0
	_expect(not helper.has_feedback_from_runtime_state(state), "runtime-state feedback query should reject expired live fields")


func _verify_result_feedback() -> void:
	var helper := RuntimePerkChoiceFeedback.new()
	var fallback: Dictionary = helper.build_result_feedback(
		{"accepted": true},
		{"id": "bulk", "name": "Bulk"},
		0.9
	)
	_expect(bool(fallback.get("accepted", false)), "accepted helper result should stay accepted")
	_expect(str(fallback.get("feedback_text", "")) == "Bulk", "result feedback should fall back to choice name")
	_expect(is_equal_approx(float(fallback.get("feedback_timer", 0.0)), 0.9), "result feedback should fall back to caller timer")

	var explicit: Dictionary = helper.build_result_feedback(
		{"accepted": true, "feedback_text": "Done", "feedback_timer": 1.7},
		{"id": "bulk", "name": "Bulk"},
		0.9
	)
	_expect(str(explicit.get("feedback_text", "")) == "Done", "result feedback should preserve explicit helper text")
	_expect(is_equal_approx(float(explicit.get("feedback_timer", 0.0)), 1.7), "result feedback should preserve explicit helper timer")
	_expect(not bool(helper.build_result_feedback({"accepted": false}, {"id": "bulk"}, 0.9).get("accepted", false)), "rejected helper result should stay rejected")

	var state := FakeFeedbackState.new()
	var applied: Dictionary = helper.apply_result_feedback_state_update(
		state,
		{"accepted": true},
		{"id": "bulk", "name": "Bulk"},
		0.9
	)
	_expect(bool(applied.get("accepted", false)), "result feedback application should accept valid helper results")
	_expect(str(state.feedback_text) == "Bulk", "result feedback application should write fallback choice name")
	_expect(is_equal_approx(float(state.feedback_timer), 0.9), "result feedback application should write fallback timer")
	_expect(not bool(helper.apply_result_feedback_state_update(state, {"accepted": false}, {"id": "bulk"}, 0.9).get("accepted", true)), "result feedback application should reject failed helper results")
	var applied_runtime: Dictionary = helper.apply_result_feedback_from_runtime_state(
		state,
		{"accepted": true, "feedback_text": "Runtime"},
		{"id": "bulk", "name": "Bulk"},
		0.7
	)
	_expect(bool(applied_runtime.get("accepted", false)), "runtime-state result wrapper should accept valid helper results")
	_expect(str(state.feedback_text) == "Runtime", "runtime-state result wrapper should write feedback text")
	_expect(is_equal_approx(float(state.feedback_timer), 0.7), "runtime-state result wrapper should use fallback timer")


func _verify_feedback_tick() -> void:
	var helper := RuntimePerkChoiceFeedback.new()
	var ticking: Dictionary = helper.build_tick_feedback_state_update("keep", 1.0, 0.25)
	_expect(bool(ticking.get("accepted", false)), "active feedback tick should build a state update")
	_expect(str(ticking.get("feedback_text", "")) == "keep", "active feedback tick should preserve text before expiry")
	_expect(is_equal_approx(float(ticking.get("feedback_timer", 0.0)), 0.75), "active feedback tick should reduce timer")

	var expired: Dictionary = helper.build_tick_feedback_state_update("clear", 0.2, 0.25)
	_expect(str(expired.get("feedback_text", "missing")) == "", "expired feedback tick should clear text")
	_expect(is_equal_approx(float(expired.get("feedback_timer", -1.0)), 0.0), "expired feedback tick should clamp timer to zero")
	_expect(not bool(helper.build_tick_feedback_state_update("off", 0.0, 0.1).get("accepted", false)), "inactive feedback tick should not build an update")

	var state := FakeFeedbackState.new()
	state.feedback_text = "tick"
	state.feedback_timer = 0.5
	var applied_tick: Dictionary = helper.apply_tick_feedback_state_update(state, state.feedback_text, state.feedback_timer, 0.2)
	_expect(bool(applied_tick.get("accepted", false)), "feedback tick application should accept active feedback")
	_expect(str(state.feedback_text) == "tick", "feedback tick application should preserve text before expiry")
	_expect(is_equal_approx(float(state.feedback_timer), 0.3), "feedback tick application should write reduced timer")
	_expect(not bool(helper.apply_tick_feedback_state_update(state, state.feedback_text, 0.0, 0.1).get("accepted", false)), "feedback tick application should reject inactive feedback")


func _verify_feedback_state_application() -> void:
	var helper := RuntimePerkChoiceFeedback.new()
	var state := FakeFeedbackState.new()
	var applied: Dictionary = helper.apply_feedback_state_update(
		state,
		{"accepted": true, "feedback_text": "Applied", "feedback_timer": 1.4},
		0.5
	)
	_expect(bool(applied.get("accepted", false)), "feedback state application should accept valid state updates")
	_expect(str(state.feedback_text) == "Applied", "feedback state application should write feedback text")
	_expect(is_equal_approx(float(state.feedback_timer), 1.4), "feedback state application should write feedback timer")

	helper.apply_feedback_state_update(state, {"accepted": true, "feedback_text": "Fallback"}, 0.75)
	_expect(str(state.feedback_text) == "Fallback", "feedback state application should write fallback-text updates")
	_expect(is_equal_approx(float(state.feedback_timer), 0.75), "feedback state application should use fallback timer when missing")
	_expect(not bool(helper.apply_feedback_state_update(null, {"accepted": true}).get("accepted", true)), "feedback state application should reject missing state")
	_expect(not bool(helper.apply_feedback_state_update(state, {"accepted": false}).get("accepted", true)), "feedback state application should reject rejected updates")


func _verify_state_consumes_helper() -> void:
	var state := RuntimePerkState.new()
	state._apply_choice_failure_feedback()
	_expect(str(state.feedback_text) == RuntimePerkChoiceFeedback.APPLY_FAILURE_TEXT, "state failure wrapper should apply helper text")
	_expect(is_equal_approx(float(state.feedback_timer), RuntimePerkChoiceFeedback.APPLY_FAILURE_TIMER), "state failure wrapper should apply helper timer")

	state.pending_unlock_swap = {"choice_id": "soldier_unlock_bowling_trap"}
	state._apply_choice_failure_feedback()
	_expect(str(state.feedback_text) == "", "state should suppress apply-failure text while swap is pending")
	_expect(is_equal_approx(float(state.feedback_timer), 0.0), "state should suppress apply-failure timer while swap is pending")

	state.feedback_text = "tick"
	state.feedback_timer = 0.2
	_expect(state.has_feedback(), "state has_feedback should delegate visible feedback query")
	state.update(0.25, Vector2(760.0, 750.0))
	_expect(str(state.feedback_text) == "", "state update should clear expired feedback text through helper")
	_expect(is_equal_approx(float(state.feedback_timer), 0.0), "state update should clamp expired feedback timer")
	_expect(not state.has_feedback(), "state has_feedback should reject expired feedback through helper")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var feedback_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_feedback.gd")
	var instant_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
	var open_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	var finish_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
	var update_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_update_flow.gd")
	_expect(state_source.find("RuntimePerkChoiceFeedback") >= 0, "state should preload the choice feedback helper")
	_expect(state_source.find("_choice_feedback.has_feedback_from_runtime_state") >= 0, "state should delegate visible feedback query runtime-state assembly to helper")
	_expect(state_source.find("feedback_timer > 0.0 and feedback_text != \"\"") < 0, "state should not inline visible feedback query")
	_expect(state_source.find("RuntimePerkUpdateFlow") >= 0, "state should preload update-flow helper for feedback ticking")
	_expect(update_flow_source.find("apply_tick_feedback_state_update") >= 0, "update-flow helper should consume helper-owned feedback timer tick application")
	_expect(instant_flow_source.find("apply_feedback_state_update") >= 0, "instant-flow helper should consume helper-owned feedback state application")
	_expect(feedback_source.find("apply_result_feedback_state_update") >= 0, "choice feedback helper should own result feedback application")
	_expect(state_source.find("apply_result_feedback_from_runtime_state") >= 0, "state should consume helper-owned runtime-state result feedback application")
	_expect(state_source.find("RuntimePerkChoiceOpenFlow") >= 0, "state should preload choice open-flow helper for Dowsing feedback")
	_expect(open_flow_source.find("apply_dowsing_goggles_bonus_feedback_state_update") >= 0, "open-flow should consume helper-owned Dowsing feedback application")
	_expect(state_source.find("feedback_timer = max(0.0, feedback_timer - delta)") < 0, "state should not inline feedback timer decrement")
	_expect(state_source.find("feedback_text = str(failure_feedback.get") < 0, "state should not inline failure feedback text application")
	_expect(state_source.find("feedback_timer = float(failure_feedback.get") < 0, "state should not inline failure feedback timer application")
	_expect(state_source.find("feedback_text = str(feedback.get") < 0, "state should not inline result feedback text application")
	_expect(state_source.find("feedback_timer = float(feedback.get") < 0, "state should not inline result feedback timer application")
	_expect(state_source.find("feedback_text = str(feedback_result.get") < 0, "state should not inline swap feedback text application")
	_expect(state_source.find("feedback_timer = float(feedback_result.get") < 0, "state should not inline swap feedback timer application")
	_expect(state_source.find("feedback_text = str(collection_update.get") < 0, "state should not inline starpoint collection feedback text application")
	_expect(state_source.find("feedback_timer = float(collection_update.get") < 0, "state should not inline starpoint collection feedback timer application")
	_expect(state_source.find("feedback_text = str(dowsing_feedback.get") < 0, "state should not inline Dowsing feedback text application")
	_expect(state_source.find("feedback_timer = float(dowsing_feedback.get") < 0, "state should not inline Dowsing feedback timer application")
	_expect(state_source.find("feedback_text = str(feedback_tick_update.get") < 0, "state should not inline feedback tick text application")
	_expect(state_source.find("feedback_timer = float(feedback_tick_update.get") < 0, "state should not inline feedback tick timer application")
	_expect(state_source.find("feedback_text = str(state_update.get") < 0, "state should not inline generic state-update feedback text application")
	_expect(state_source.find("feedback_timer = float(state_update.get") < 0, "state should not inline generic state-update feedback timer application")
	_expect(feedback_source.find("apply_failure_feedback_state_update") >= 0, "choice feedback helper should own apply failure feedback application")
	_expect(state_source.find("apply_failure_feedback_from_runtime_state") >= 0, "state should consume helper-owned runtime-state apply failure feedback application")
	_expect(state_source.find("build_dowsing_goggles_bonus_feedback") < 0, "state should not build Dowsing feedback inline")
	_expect(state_source.find("_choice_finish_flow.finish_successful_choice") >= 0, "state should route Megingjord finish feedback through finish-flow helper")
	_expect(finish_flow_source.find("build_megingjord_extra_pick_feedback") >= 0, "finish-flow helper should consume helper-owned Megingjord feedback")
	var result_feedback_body: String = _function_body(state_source, "func _apply_choice_feedback_result(")
	_expect(result_feedback_body.find("apply_result_feedback_from_runtime_state") >= 0, "state result-feedback wrapper should delegate runtime-state assembly to helper")
	_expect(result_feedback_body.find("apply_result_feedback_state_update") < 0, "state result-feedback wrapper should not pass feedback internals inline")
	_expect(result_feedback_body.find("build_result_feedback") < 0, "state result-feedback wrapper should not build result feedback inline")
	_expect(result_feedback_body.find("apply_feedback_state_update") < 0, "state result-feedback wrapper should not apply result feedback inline")
	var failure_feedback_body: String = _function_body(state_source, "func _apply_choice_failure_feedback(")
	_expect(failure_feedback_body.find("apply_failure_feedback_from_runtime_state") >= 0, "state failure-feedback wrapper should delegate runtime-state assembly to helper")
	_expect(failure_feedback_body.find("apply_failure_feedback_state_update") < 0, "state failure-feedback wrapper should not pass swap-state dependencies inline")
	_expect(failure_feedback_body.find("has_pending_unlock_swap") < 0, "state failure-feedback wrapper should not resolve pending-swap state inline")
	_expect(failure_feedback_body.find("build_apply_failure_feedback") < 0, "state failure-feedback wrapper should not build failure feedback inline")
	_expect(failure_feedback_body.find("apply_feedback_state_update") < 0, "state failure-feedback wrapper should not apply failure feedback inline")
	var open_body: String = _function_body(state_source, "func open_next_choice(")
	_expect(open_body.find("dowsing_feedback") < 0, "open-next body should not retain Dowsing feedback payload inline")
	_expect(open_body.find("build_dowsing_goggles_bonus_feedback") < 0, "open-next body should not build Dowsing feedback inline")
	_expect(open_body.find("apply_feedback_state_update(self, dowsing") < 0, "open-next body should not apply Dowsing feedback inline")
	var update_body: String = _function_body(state_source, "func _update_internal(")
	_expect(update_body.find("build_tick_feedback_state_update") < 0, "update body should not build feedback tick updates inline")
	_expect(update_body.find("feedback_tick_update") < 0, "update body should not retain feedback tick payloads inline")
	_expect(state_source.find("선택을 적용할 수 없습니다") < 0, "state should not own apply-failure text literal")
	_expect(state_source.find("다우징 고글: 추가 퍽 등장!") < 0, "state should not own Dowsing bonus text literal")
	_expect(state_source.find("메긴기요르드 발동") < 0, "state should not own Megingjord bonus text literal")


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


class FakeFeedbackState:
	var feedback_text := ""
	var feedback_timer := 0.0
	var pending_unlock_swap := false

	func has_pending_unlock_swap() -> bool:
		return pending_unlock_swap
