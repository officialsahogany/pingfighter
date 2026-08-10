extends SceneTree

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StageClearResultNavigationActionHandler := preload("res://scripts/ui/stage_clear_result_navigation_action_handler.gd")
const StageClearResultNavigationSceneHandler := preload("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var confirm_calls := 0
	var plaza_calls := 0
	var exit_calls := 0

	func confirm() -> void:
		confirm_calls += 1

	func enter_plaza() -> void:
		plaza_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1


class RetryablePlazaSink:
	extends RefCounted

	var plaza_calls := 0

	func enter_plaza() -> bool:
		plaza_calls += 1
		return false


func _init() -> void:
	_verify_navigation_action_contract()
	_verify_navigation_scene_handler_contract()
	_verify_preparation_notice_localization()
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
		"plaza button should enter the active production plaza"
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
	_expect(str(plaza_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA, "scroll-button apply helper should map plaza to the active entry route")
	_expect(bool(plaza_apply.get("handled", false)), "scroll-button apply helper should handle plaza clicks")

	var missed_apply: Dictionary = StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result({
		"clicked_button": StageClearResultInteractionState.BUTTON_NONE,
	})
	_expect(str(missed_apply.get("action", "")) == StageClearResultNavigationActionHandler.ACTION_NONE, "scroll-button apply helper should keep missed clicks actionless")
	_expect(not bool(missed_apply.get("handled", true)), "scroll-button apply helper should not handle missed clicks")


func _verify_navigation_scene_handler_contract() -> void:
	var sink := CallbackSink.new()
	var scene := StageClearResultScene.new()
	scene.set("_scroll_phase", StageClearResultScrollState.PHASE_VISIBLE)
	scene.confirmed_callback = Callable(sink, "confirm")
	_expect(StageClearResultNavigationSceneHandler.handle_advance_input(scene), "navigation scene handler should consume visible-scroll advance")
	_expect(sink.confirm_calls == 1, "visible-scroll advance should invoke the confirm callback")

	scene.set("_scroll_phase", StageClearResultScrollState.PHASE_VISIBLE)
	scene.exit_to_menu_callback = Callable(sink, "exit_to_menu")
	_expect(StageClearResultNavigationSceneHandler.handle_escape_input(scene), "navigation scene handler should consume visible-scroll escape")
	_expect(sink.exit_calls == 1, "visible-scroll escape should invoke the exit callback")

	scene.set("_scroll_phase", StageClearResultScrollState.PHASE_VISIBLE)
	scene.set("_starpoint_choice_gate_active", true)
	scene.confirmed_callback = Callable(sink, "confirm")
	_expect(StageClearResultNavigationSceneHandler.handle_advance_input(scene), "blocked advance should still be consumed")
	_expect(sink.confirm_calls == 1, "blocked advance should not invoke confirm callbacks")
	scene.set("_starpoint_choice_gate_active", false)

	scene.enter_plaza_callback = Callable(sink, "enter_plaza")
	scene.set("_plaza_notice_until", -1.0)
	_expect(StageClearResultNavigationSceneHandler.apply_navigation_action_result(
		scene,
		{
			"action": StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA,
			"handled": true,
		}
	), "navigation scene handler should report handled plaza actions")
	_expect(sink.plaza_calls == 1, "plaza actions should invoke the plaza callback")
	_expect(float(scene.get("_plaza_notice_until")) < 0.0, "successful plaza entry must not arm the readiness notice")
	_expect(not scene.enter_plaza_callback.is_valid(), "successful plaza entry should consume its callback")

	var retryable_sink := RetryablePlazaSink.new()
	scene.enter_plaza_callback = Callable(retryable_sink, "enter_plaza")
	scene.set("timer", 5.0)
	scene.set("_plaza_notice_until", -1.0)
	_expect(StageClearResultNavigationSceneHandler.apply_navigation_action_result(
		scene,
		{
			"action": StageClearResultNavigationActionHandler.ACTION_ENTER_PLAZA,
			"handled": true,
		}
	), "readiness-yield plaza actions should remain handled")
	_expect(retryable_sink.plaza_calls == 1, "readiness-yield plaza actions should invoke the callback once")
	_expect(scene.enter_plaza_callback.is_valid(), "readiness-yield plaza actions should preserve the callback for retry")
	_expect(float(scene.get("_plaza_notice_until")) > 5.0, "readiness-yield plaza actions should arm visible preparation feedback")

	# 광장 준비중 계약: 안내 액션은 진입 콜백을 부르지 않고 만료 시각만 심는다.
	scene.set("timer", 5.0)
	scene.set("_plaza_notice_until", -1.0)
	_expect(StageClearResultNavigationSceneHandler.apply_navigation_action_result(
		scene,
		{
			"action": StageClearResultNavigationActionHandler.ACTION_PLAZA_NOTICE,
			"handled": true,
		}
	), "navigation scene handler should report handled plaza-notice actions")
	_expect(float(scene.get("_plaza_notice_until")) > 5.0, "plaza-notice action should arm the notice past the current timer")
	_expect(sink.plaza_calls == 1, "plaza-notice action must NOT invoke the plaza entry callback")

	_expect(StageClearResultNavigationSceneHandler.apply_navigation_action_result(
		scene,
		{
			"action": StageClearResultNavigationActionHandler.ACTION_CONSUME,
			"handled": true,
		}
	), "consume-only navigation actions should report handled")
	_expect(sink.confirm_calls == 1 and sink.plaza_calls == 1 and sink.exit_calls == 1, "consume-only navigation actions should not invoke callbacks")
	scene.free()


func _verify_preparation_notice_localization() -> void:
	var expected := {
		"ko": "준비 중입니다",
		"en": "Preparing...",
		"zh": "准备中",
		"ja": "準備中です",
		"es": "Preparando...",
		"pt-BR": "Preparando...",
		"ru": "Подготовка...",
	}
	for locale in expected.keys():
		LanguageSettings.set_test_locale_override(str(locale))
		_expect(
			LanguageSettings.translate_text("준비 중입니다") == str(expected[locale]),
			"plaza preparation notice should localize for %s" % locale
		)
	LanguageSettings.set_test_locale_override("")


func _verify_scene_delegates_navigation_actions() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var input_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
	var draw_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var static_draw_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_static_draw_helper.gd")
	_expect(input_scene_handler_source.find("StageClearResultNavigationSceneHandler.handle_advance_input") >= 0, "input scene handler should delegate advance input scene glue")
	_expect(input_scene_handler_source.find("StageClearResultNavigationSceneHandler.handle_escape_input") >= 0, "input scene handler should delegate escape input scene glue")
	_expect(input_scene_handler_source.find("StageClearResultNavigationSceneHandler.handle_button_click") >= 0, "input scene handler should delegate scroll button click scene glue")
	_expect(source.find("StageClearResultNavigationSceneHandler.handle_advance_input") < 0, "result scene should not keep advance input scene glue")
	_expect(source.find("StageClearResultNavigationSceneHandler.handle_escape_input") < 0, "result scene should not keep escape input scene glue")
	_expect(source.find("StageClearResultNavigationSceneHandler.handle_button_click") < 0, "result scene should not keep scroll button click scene glue")
	_expect(source.find("StageClearResultNavigationActionHandler.") < 0, "result scene should not call the navigation action policy helper directly")
	_expect(source.find("func _apply_navigation_action_result") < 0, "result scene should not keep navigation action result application")
	_expect(source.find("func _apply_navigation_action") < 0, "result scene should not keep navigation action side-effect dispatch")
	_expect(scene_handler_source.find("StageClearResultNavigationActionHandler.get_advance_action") >= 0, "navigation scene handler should delegate advance action policy")
	_expect(scene_handler_source.find("StageClearResultNavigationActionHandler.get_escape_action") >= 0, "navigation scene handler should delegate escape action policy")
	_expect(scene_handler_source.find("StageClearResultNavigationActionHandler.get_navigation_action_apply_result") >= 0, "navigation scene handler should delegate navigation action apply payloads")
	_expect(scene_handler_source.find("StageClearResultNavigationActionHandler.get_scroll_button_click_apply_result") >= 0, "navigation scene handler should delegate scroll button click apply payloads")
	_expect(scene_handler_source.find("static func apply_navigation_action_result") >= 0, "navigation scene handler should apply navigation action result payloads in one helper")
	_expect(scene_handler_source.find("static func apply_navigation_action") >= 0, "navigation scene handler should apply navigation action side effects in one helper")
	_expect(scene_handler_source.find("StageClearResultBoxSceneHandler.open_next_idle_box") >= 0, "navigation scene handler should route open-box actions through the box scene handler")
	_expect(scene_handler_source.find("StageClearResultCallbackSceneHandler.confirm") >= 0, "navigation scene handler should route confirm actions through the callback scene handler")
	_expect(scene_handler_source.find("StageClearResultCallbackSceneHandler.enter_plaza") >= 0, "navigation scene handler should route plaza actions through the callback scene handler")
	_expect(scene_handler_source.find("StageClearResultCallbackHandler.RESULT_NONE") >= 0, "navigation scene handler should distinguish explicit plaza readiness yields")
	_expect(draw_handler_source.find("StageClearResultStaticDrawHelper.draw_plaza_notice") >= 0, "result draw handler should render armed plaza preparation feedback")
	_expect(static_draw_source.find("LanguageSettings.translate_text(\"준비 중입니다\")") >= 0, "plaza preparation feedback should use the spaced Korean localization key")
	_expect(scene_handler_source.find("StageClearResultCallbackSceneHandler.exit_to_menu") >= 0, "navigation scene handler should route exit actions through the callback scene handler")
	_expect(scene_handler_source.find("StageClearResultScrollSceneHandler.apply_scroll_button_layout") >= 0, "navigation scene handler should route scroll button layout through the scroll scene handler")
	_expect(scene_handler_source.find("StageClearResultRuntimeOverlaySceneHandler.is_interaction_blocked") >= 0, "navigation scene handler should route interaction blocking through the runtime overlay scene handler")
	_expect(scene_handler_source.find("_call_scene_method") < 0, "navigation scene handler should not use a generic scene wrapper dispatcher")
	_expect(scene_handler_source.find("scene.call(\"_apply_scroll_button_layout\"") < 0, "navigation scene handler should not bounce scroll layout through the result scene wrapper")
	_expect(scene_handler_source.find("scene.call(\"_is_result_interaction_blocked\"") < 0, "navigation scene handler should not bounce interaction blocking through the result scene wrapper")
	_expect(scene_handler_source.find("&\"_open_next_idle_box\"") < 0, "navigation scene handler should not route open-box actions through the result scene wrapper")
	_expect(scene_handler_source.find("&\"_confirm\"") < 0, "navigation scene handler should not route confirm actions through the result scene wrapper")
	_expect(scene_handler_source.find("&\"_enter_plaza\"") < 0, "navigation scene handler should not route plaza actions through the result scene wrapper")
	_expect(scene_handler_source.find("&\"_exit_to_menu\"") < 0, "navigation scene handler should not route exit actions through the result scene wrapper")
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
