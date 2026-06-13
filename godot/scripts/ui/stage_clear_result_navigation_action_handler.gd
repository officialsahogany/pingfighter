extends RefCounted

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

const ACTION_NONE := "none"
const ACTION_OPEN_NEXT_BOX := "open_next_box"
const ACTION_CONFIRM := "confirm"
const ACTION_ENTER_PLAZA := "enter_plaza"
const ACTION_EXIT_TO_MENU := "exit_to_menu"
const ACTION_CONSUME := "consume"


static func get_advance_action(blocked: bool, scroll_phase: String) -> String:
	if blocked:
		return ACTION_CONSUME
	match scroll_phase:
		StageClearResultScrollState.PHASE_HIDDEN:
			return ACTION_OPEN_NEXT_BOX
		StageClearResultScrollState.PHASE_VISIBLE:
			return ACTION_CONFIRM
	return ACTION_CONSUME


static func get_escape_action(scroll_phase: String) -> String:
	return ACTION_EXIT_TO_MENU if scroll_phase == StageClearResultScrollState.PHASE_VISIBLE else ACTION_CONSUME


static func get_scroll_button_action(clicked_button: String) -> String:
	if clicked_button == StageClearResultInteractionState.BUTTON_NEXT_STAGE:
		return ACTION_CONFIRM
	if clicked_button == StageClearResultInteractionState.BUTTON_PLAZA:
		return ACTION_ENTER_PLAZA
	if clicked_button == StageClearResultInteractionState.BUTTON_EXIT:
		return ACTION_EXIT_TO_MENU
	return ACTION_NONE


static func get_navigation_action_apply_result(action: String) -> Dictionary:
	return {
		"action": action,
		"handled": action != ACTION_NONE,
	}


static func get_scroll_button_click_apply_result(button_click_result: Dictionary) -> Dictionary:
	var clicked_button: String = str(button_click_result.get("clicked_button", StageClearResultInteractionState.BUTTON_NONE))
	var result: Dictionary = get_navigation_action_apply_result(get_scroll_button_action(clicked_button))
	result.merge({
		"next_stage_rect": button_click_result.get("next_stage_rect", Rect2()),
		"plaza_rect": button_click_result.get("plaza_rect", Rect2()),
		"exit_rect": button_click_result.get("exit_rect", Rect2()),
		"clicked_button": clicked_button,
	}, true)
	return result
