extends SceneTree

const SelectionFeedbackState := preload("res://scripts/hud/pause_menu_selection_feedback_state.gd")

var failure_count := 0


func _init() -> void:
	_verify_overlay_single_owner_contract()
	var state := SelectionFeedbackState.new()
	_expect(not bool(state.build_slide_projection("main").get("active", true)), "settled initial state should not expose a slide")
	var settled_pop := state.build_pop_projection("main", 0.28)
	_expect(float(settled_pop.get("pop_amount", -1.0)) == 0.0 and float(settled_pop.get("flash_alpha", -1.0)) == 0.0, "settled initial state should not expose pop feedback")

	state.begin("options:sound", 0, 2)
	_expect(state.scope == "options:sound" and state.from_index == 0 and state.to_index == 2, "begin should capture scope and index transition")
	_expect(state.slide_time == 0.0 and state.pop_time == 0.0, "begin should reset both feedback clocks")
	var snapshot := state.get_snapshot()
	_expect(str(snapshot.get("scope", "")) == "options:sound", "snapshot should expose the owned scope")
	_expect(int(snapshot.get("from_index", -1)) == 0 and int(snapshot.get("to_index", -1)) == 2, "snapshot should expose transition endpoints")
	_expect(float(snapshot.get("slide_time", -1.0)) == 0.0 and float(snapshot.get("pop_time", -1.0)) == 0.0, "snapshot should expose feedback clocks")
	var initial_slide := state.build_slide_projection("options:sound")
	_expect(bool(initial_slide.get("active", false)), "matching scope should expose an active slide")
	_expect(int(initial_slide.get("from_index", -1)) == 0 and int(initial_slide.get("to_index", -1)) == 2, "slide projection should retain transition endpoints")
	_expect(is_equal_approx(float(initial_slide.get("weight", -1.0)), 0.0), "slide should begin at its source rect")
	var initial_pop := state.build_pop_projection("options:sound", 0.28)
	_expect(is_zero_approx(float(initial_pop.get("pop_amount", -1.0))), "pop scale should begin at zero")
	_expect(is_equal_approx(float(initial_pop.get("flash_alpha", 0.0)), 0.28), "pop flash should begin at the requested peak")

	state.advance(SelectionFeedbackState.POP_DURATION * 0.5)
	var mid_pop := state.build_pop_projection("options:sound", 0.28)
	_expect(is_equal_approx(float(mid_pop.get("pop_amount", 0.0)), SelectionFeedbackState.POP_SCALE), "halfway pop should reach the configured peak scale")
	_expect(is_equal_approx(float(mid_pop.get("flash_alpha", 0.0)), 0.14), "halfway pop should fade to half flash alpha")
	_expect(not bool(state.build_slide_projection("main").get("active", true)), "different scope should not reuse another tab's slide")

	state.advance(1.0)
	_expect(is_equal_approx(state.slide_time, SelectionFeedbackState.SLIDE_DURATION), "advance should clamp slide time")
	_expect(is_equal_approx(state.pop_time, SelectionFeedbackState.POP_DURATION), "advance should clamp pop time")
	_expect(not bool(state.build_slide_projection("options:sound").get("active", true)), "settled transition should stop sliding")

	_expect(state.consume_hover_change("main", 1), "new hover target should be consumed")
	_expect(not state.consume_hover_change("main", 1), "identical hover target should be suppressed")
	_expect(state.consume_hover_change("main", -1), "leaving the hover target should be consumed once")
	state.reset_hover_tracking()
	_expect(state.last_hover_scope == "" and state.last_hover_index == -1, "hover reset should clear its dedupe key")

	state.reset("main", 3)
	_expect(state.scope == "main" and state.from_index == 3 and state.to_index == 3, "reset should settle on the supplied selection")
	_expect(state.slide_time == SelectionFeedbackState.SLIDE_DURATION and state.pop_time == SelectionFeedbackState.POP_DURATION, "reset should settle both clocks")

	if failure_count > 0:
		quit(1)
		return
	print("pause_menu_selection_feedback_state_smoke: ok")
	quit(0)


func _verify_overlay_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	for mirror_name in [
		"_selection_feedback_scope",
		"_selection_from_index",
		"_selection_to_index",
		"_selection_slide_time",
		"_selection_pop_time",
		"_last_hover_scope",
		"_last_hover_index",
	]:
		_expect(source.find("var %s" % mirror_name) == -1, "%s mirror should be removed" % mirror_name)
	_expect(source.find("func _sync_selection_feedback_facade") == -1, "overlay should not synchronize feedback mirrors")
	_expect(source.find("var _selection_feedback_state: PauseMenuSelectionFeedbackState") >= 0, "overlay should keep one typed feedback owner")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
