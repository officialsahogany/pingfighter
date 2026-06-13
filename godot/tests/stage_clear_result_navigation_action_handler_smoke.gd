extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultNavigationActionHandler := preload("res://scripts/ui/stage_clear_result_navigation_action_handler.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_navigation_action_contract()
	_verify_scene_delegates_navigation_actions()

	if _failures.is_empty():
		print("stage_clear_result_navigation_action_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_navigation_action_contract() -> void:
	_expect(
		StageClearResultNavigationActionHandler.get_advance_action(false, StageClearResultScrollState.PHASE_HIDDEN) == StageClearResultNavigationActionHandler.ACTION_OPEN_NEXT_BOX,
		"advance while hidden should open the next reward box"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_advance_action(false, StageClearResultScrollState.PHASE_VISIBLE) == StageClearResultNavigationActionHandler.ACTION_CONFIRM,
		"advance while visible should confirm the result screen"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_advance_action(true, StageClearResultScrollState.PHASE_VISIBLE) == StageClearResultNavigationActionHandler.ACTION_CONSUME,
		"blocked advance should only consume input"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_escape_action(StageClearResultScrollState.PHASE_VISIBLE) == StageClearResultNavigationActionHandler.ACTION_EXIT_TO_MENU,
		"escape while visible should exit to menu"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_escape_action(StageClearResultScrollState.PHASE_HIDDEN) == StageClearResultNavigationActionHandler.ACTION_CONSUME,
		"escape before visible scroll should only consume input"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_scroll_button_action(StageClearResultInteractionState.BUTTON_NEXT_STAGE) == StageClearResultNavigationActionHandler.ACTION_CONFIRM,
		"next-stage button should confirm"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_scroll_button_action(StageClearResultInteractionState.BUTTON_PLAZA) == StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA,
		"plaza button should enter the plaza"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_scroll_button_action(StageClearResultInteractionState.BUTTON_EXIT) == StageClearResultNavigationActionHandler.ACTION_EXIT_TO_MENU,
		"exit button should exit to menu"
	)
	_expect(
		StageClearResultNavigationActionHandler.get_scroll_button_action(StageClearResultInteractionState.BUTTON_NONE) == StageClearResultNavigationActionHandler.ACTION_NONE,
		"no button should not produce a navigation action"
	)
	var confirm_apply: Dictionary = StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.ACTION_CONFIRM
	)
	_expect(str(confirm_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_CONFIRM, "navigation apply helper should preserve confirm actions")
	_expect(bool(confirm_apply.get("handled", false)), "navigation apply helper should handle concrete actions")

	var consume_apply: Dictionary = StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.ACTION_CONSUME
	)
	_expect(str(consume_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_CONSUME, "navigation apply helper should preserve consume actions")
	_expect(bool(consume_apply.get("handled", false)), "navigation apply helper should handle consume-only actions")

	var none_apply: Dictionary = StageClearResultNavigationActionHandler.get_navigation_action_apply_result(
		StageClearResultNavigationActionHandler.ACTION_NONE
	)
	_expect(str(none_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_NONE, "navigation apply helper should preserve none actions")
	_expect(not bool(none_apply.get("handled", true)), "navigation apply helper should not handle none actions")

	var next_rect := Rect2(Vector2(10.0, 12.0), Vector2(100.0, 40.0))
	var plaza_rect := Rect2(Vector2(130.0, 12.0), Vector2(100.0, 40.0))
	var exit_rect := Rect2(Vector2(250.0, 12.0), Vector2(100.0, 40.0))
	var next_apply: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result({
		"next_stage_rect": next_rect,
		"plaza_rect": plaza_rect,
		"exit_rect": exit_rect,
		"clicked_button": StageClearResultInteractionState.BUTTON_NEXT_STAGE,
	})
	_expect(next_apply.get("next_stage_rect", Rect2()) == next_rect, "scroll-button apply helper should preserve next-stage layout")
	_expect(next_apply.get("plaza_rect", Rect2()) == plaza_rect, "scroll-button apply helper should preserve plaza layout")
	_expect(next_apply.get("exit_rect", Rect2()) == exit_rect, "scroll-button apply helper should preserve exit layout")
	_expect(str(next_apply.get("clicked_button", "")) == StageClearResultInteractionState.BUTTON_NEXT_STAGE, "scroll-button apply helper should preserve clicked button")
	_expect(str(next_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_CONFIRM, "scroll-button apply helper should map next-stage to confirm")
	_expect(bool(next_apply.get("handled", false)), "scroll-button apply helper should handle next-stage clicks")

	var exit_apply: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result({
		"clicked_button": StageClearResultInteractionState.BUTTON_EXIT,
	})
	_expect(str(exit_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_EXIT_TO_MENU, "scroll-button apply helper should map exit to menu")
	_expect(bool(exit_apply.get("handled", false)), "scroll-button apply helper should handle exit clicks")

	var plaza_apply: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result({
		"clicked_button": StageClearResultInteractionState.BUTTON_PLAZA,
	})
	_expect(str(plaza_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA, "scroll-button apply helper should map plaza to plaza entry")
	_expect(bool(plaza_apply.get("handled", false)), "scroll-button apply helper should handle plaza clicks")

	var missed_apply: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result({
		"clicked_button": StageClearResultInteractionState.BUTTON_NONE,
	})
	_expect(str(missed_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_NONE, "scroll-button apply helper should keep missed clicks actionless")
	_expect(not bool(missed_apply.get("handled", true)), "scroll-button apply helper should not handle missed clicks")


func _verify_scene_delegates_navigation_actions() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultNavigationActionHandler.get_advance_action") >= 0, "result scene should delegate advance action policy")
	_expect(source.find("StageClearResultNavigationActionHandler.get_escape_action") >= 0, "result scene should delegate escape action policy")
	_expect(source.find("StageClearResultNavigationActionHandler.get_navigation_action_apply_result") >= 0, "result scene should delegate navigation action apply payloads")
	_expect(source.find("StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result") >= 0, "result scene should delegate scroll button click apply payloads")
	_expect(source.find("func _apply_navigation_action_result") >= 0, "result scene should apply navigation action result payloads in one helper")
	_expect(source.find("func _apply_navigation_action") >= 0, "result scene should apply navigation action side effects in one helper")
	_expect(source.find("_apply_navigation_action(StageClearResultNavigationActionHandler.get_advance_action") < 0, "result scene should not directly apply advance actions")
	_expect(source.find("_apply_navigation_action(StageClearResultNavigationActionHandler.get_escape_action") < 0, "result scene should not directly apply escape actions")
	_expect(source.find("result.get(\"clicked_button\"") < 0, "result scene should not inspect clicked scroll buttons directly")
	_expect(source.find("get_scroll_button_action") < 0, "result scene should not map scroll-button actions directly")
	_expect(source.find("clicked_button == StageClearResultInteractionState.BUTTON_NEXT_STAGE") < 0, "result scene should not map next-stage button inline")
	_expect(source.find("clicked_button == StageClearResultInteractionState.BUTTON_PLAZA") < 0, "result scene should not map plaza button inline")
	_expect(source.find("clicked_button == StageClearResultInteractionState.BUTTON_EXIT") < 0, "result scene should not map exit button inline")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
