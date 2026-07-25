extends SceneTree

const TimelineState := preload("res://scripts/items/mythic_item_acquisition_timeline_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_exact_phase_and_input_timeline()
	_verify_cancel_is_not_natural_completion()
	if _failures.is_empty():
		print("mythic_item_acquisition_timeline_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_exact_phase_and_input_timeline() -> void:
	var state := TimelineState.new()
	state.begin()
	_expect(state.active, "begin should activate the timeline")
	_expect(state.phase == TimelineState.PHASE_BUILDUP, "begin should enter buildup")
	_expect(state.request_absorb() == "", "input before reveal should not start absorption")

	_expect(state.advance_clocks(1.2).is_empty(), "buildup should not emit clock events")
	_expect(state.phase == TimelineState.PHASE_BUILDUP, "clock advance alone should preserve the render phase")
	var events: Array[String] = state.finish_phase_step()
	_expect(events == [TimelineState.EVENT_START_IGNITE], "buildup deadline should emit ignite once")
	_expect(state.phase == TimelineState.PHASE_IGNITE and is_zero_approx(state.phase_timer), "ignite should reset the phase clock")
	_expect(state.legend_after_played, "ignite should arm the legendary after cue lifecycle")

	state.advance_clocks(0.4)
	events = state.finish_phase_step()
	_expect(events == [TimelineState.EVENT_ENTER_WHITE_FADE], "ignite deadline should enter white fade")
	state.advance_clocks(0.5)
	events = state.finish_phase_step()
	_expect(events == [TimelineState.EVENT_ENTER_REVEAL], "white fade deadline should enter reveal")
	_expect(not state.is_waiting_for_click(), "reveal should not accept input before the arm delay")

	state.advance_clocks(TimelineState.REVEAL_CLICK_DELAY - 0.01)
	_expect(state.request_absorb() == "", "early reveal click should stay rejected")
	state.advance_clocks(0.01)
	_expect(state.is_waiting_for_click(), "reveal should arm exactly at the click delay")
	_expect(state.request_absorb() == TimelineState.EVENT_START_ABSORB, "armed reveal click should emit absorption once")
	_expect(state.phase == TimelineState.PHASE_ABSORB and state.absorb_started, "accepted click should enter absorption")
	_expect(is_equal_approx(state.legend_after_stop_timer, TimelineState.LEGEND_AFTER_STOP_DELAY), "absorption should arm the delayed after-cue stop")
	_expect(state.request_absorb() == "", "repeated click should not restart absorption")

	events = state.advance_clocks(TimelineState.ABSORB_DURATION)
	_expect(events == [TimelineState.EVENT_STOP_LEGEND_AFTER], "absorb deadline should stop the after cue before impact")
	events = state.finish_phase_step()
	_expect(events == [TimelineState.EVENT_START_IMPACT], "absorb deadline should enter impact")
	state.advance_clocks(TimelineState.IMPACT_DURATION)
	events = state.finish_phase_step()
	_expect(events == [TimelineState.EVENT_COMPLETE], "impact deadline should emit natural completion")
	_expect(not state.active, "natural completion should deactivate the timeline")
	_expect(state.finish_phase_step().is_empty(), "completion should not repeat on later steps")


func _verify_cancel_is_not_natural_completion() -> void:
	var state := TimelineState.new()
	state.begin()
	state.advance_clocks(-1.0)
	_expect(is_zero_approx(state.elapsed), "negative delta should not rewind or advance the clock")
	state.cancel()
	_expect(not state.active, "cancel should deactivate the timeline")
	_expect(state.phase == TimelineState.PHASE_BUILDUP, "cancel should restore the initial phase")
	_expect(state.advance_clocks(99.0).is_empty(), "canceled timeline should emit no events")
	_expect(state.finish_phase_step().is_empty(), "cancel must not forge a natural completion event")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
