extends SceneTree

const StageClearResultCallbackHandler := preload("res://scripts/ui/stage_clear_result_callback_handler.gd")
const StageClearResultCallbackSceneHandler := preload("res://scripts/ui/stage_clear_result_callback_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

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
	var ready := false

	func enter_plaza() -> bool:
		plaza_calls += 1
		return ready


func _init() -> void:
	_verify_callback_handler_contract()
	_verify_callback_scene_handler_contract()
	_verify_scene_delegates_callbacks()

	if _failures.is_empty():
		print("stage_clear_result_callback_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_callback_handler_contract() -> void:
	var sink := CallbackSink.new()
	var result: String = StageClearResultCallbackHandler.invoke_confirm(Callable(sink, "confirm"))
	_expect(result == StageClearResultCallbackHandler.RESULT_CONFIRMED, "confirm handler should report confirmed callback")
	_expect(sink.confirm_calls == 1, "confirm handler should invoke the confirmed callback once")
	_expect(sink.exit_calls == 0, "confirm handler should not invoke exit callback")

	result = StageClearResultCallbackHandler.invoke_confirm(Callable())
	_expect(result == StageClearResultCallbackHandler.RESULT_NONE, "confirm handler should report none for invalid callbacks")
	_expect(sink.confirm_calls == 1, "invalid confirm callback should not change call count")

	result = StageClearResultCallbackHandler.invoke_enter_plaza(Callable(sink, "enter_plaza"))
	_expect(result == StageClearResultCallbackHandler.RESULT_ENTER_PLAZA, "plaza handler should report plaza callback")
	_expect(sink.plaza_calls == 1, "plaza handler should invoke the plaza callback once")
	_expect(sink.confirm_calls == 1, "plaza handler should not invoke confirm callback")

	result = StageClearResultCallbackHandler.invoke_enter_plaza(Callable())
	_expect(result == StageClearResultCallbackHandler.RESULT_NONE, "plaza handler should report none for invalid callbacks")
	_expect(sink.plaza_calls == 1, "invalid plaza callback should not change call count")

	var retryable_sink := RetryablePlazaSink.new()
	result = StageClearResultCallbackHandler.invoke_enter_plaza(Callable(retryable_sink, "enter_plaza"))
	_expect(result == StageClearResultCallbackHandler.RESULT_NONE, "explicit false plaza callbacks should yield without consuming entry")
	_expect(retryable_sink.plaza_calls == 1, "readiness-yield callback should run exactly once per attempt")
	retryable_sink.ready = true
	result = StageClearResultCallbackHandler.invoke_enter_plaza(Callable(retryable_sink, "enter_plaza"))
	_expect(result == StageClearResultCallbackHandler.RESULT_ENTER_PLAZA, "ready plaza callbacks should consume entry")
	_expect(retryable_sink.plaza_calls == 2, "ready retry should invoke the same callback a second time")

	result = StageClearResultCallbackHandler.invoke_exit_to_menu(
		Callable(sink, "exit_to_menu"),
		Callable(sink, "confirm")
	)
	_expect(result == StageClearResultCallbackHandler.RESULT_EXIT_TO_MENU, "exit handler should prefer exit callback")
	_expect(sink.exit_calls == 1, "exit handler should invoke exit callback once")
	_expect(sink.confirm_calls == 1, "exit handler should not invoke confirm when exit is valid")

	result = StageClearResultCallbackHandler.invoke_exit_to_menu(Callable(), Callable(sink, "confirm"))
	_expect(result == StageClearResultCallbackHandler.RESULT_CONFIRMED, "exit handler should fall back to confirmed callback")
	_expect(sink.confirm_calls == 2, "exit fallback should invoke confirm once")

	result = StageClearResultCallbackHandler.invoke_exit_to_menu(Callable(), Callable())
	_expect(result == StageClearResultCallbackHandler.RESULT_NONE, "exit handler should report none when no callback is valid")


func _verify_callback_scene_handler_contract() -> void:
	var sink := CallbackSink.new()
	var scene := StageClearResultScene.new()

	scene.confirmed_callback = Callable(sink, "confirm")
	var result: String = StageClearResultCallbackSceneHandler.confirm(scene)
	_expect(result == StageClearResultCallbackHandler.RESULT_CONFIRMED, "callback scene handler should report confirmed callbacks")
	_expect(sink.confirm_calls == 1, "callback scene handler should invoke confirmed callback once")
	_expect(not scene.confirmed_callback.is_valid(), "callback scene handler should clear confirmed callback after confirm")

	scene.enter_plaza_callback = Callable(sink, "enter_plaza")
	result = StageClearResultCallbackSceneHandler.enter_plaza(scene)
	_expect(result == StageClearResultCallbackHandler.RESULT_ENTER_PLAZA, "callback scene handler should report plaza callbacks")
	_expect(sink.plaza_calls == 1, "callback scene handler should invoke plaza callback once")
	_expect(not scene.enter_plaza_callback.is_valid(), "callback scene handler should clear plaza callback after enter plaza")

	var retryable_sink := RetryablePlazaSink.new()
	scene.enter_plaza_callback = Callable(retryable_sink, "enter_plaza")
	result = StageClearResultCallbackSceneHandler.enter_plaza(scene)
	_expect(result == StageClearResultCallbackHandler.RESULT_NONE, "callback scene handler should report readiness yields as none")
	_expect(retryable_sink.plaza_calls == 1, "callback scene handler should invoke the first readiness attempt once")
	_expect(scene.enter_plaza_callback.is_valid(), "readiness-yield callback must be restored for a later click")
	retryable_sink.ready = true
	result = StageClearResultCallbackSceneHandler.enter_plaza(scene)
	_expect(result == StageClearResultCallbackHandler.RESULT_ENTER_PLAZA, "callback scene handler should consume the ready retry")
	_expect(retryable_sink.plaza_calls == 2, "ready callback scene retry should invoke the same callback twice in total")
	_expect(not scene.enter_plaza_callback.is_valid(), "successful plaza retry should consume the restored callback")

	scene.confirmed_callback = Callable(sink, "confirm")
	scene.exit_to_menu_callback = Callable(sink, "exit_to_menu")
	result = StageClearResultCallbackSceneHandler.exit_to_menu(scene)
	_expect(result == StageClearResultCallbackHandler.RESULT_EXIT_TO_MENU, "callback scene handler should prefer valid exit callbacks")
	_expect(sink.exit_calls == 1, "callback scene handler should invoke exit callback once")
	_expect(sink.confirm_calls == 1, "callback scene handler should not invoke confirm when exit callback is valid")
	_expect(not scene.exit_to_menu_callback.is_valid(), "callback scene handler should clear exit callback after exit")
	_expect(not scene.confirmed_callback.is_valid(), "callback scene handler should clear fallback confirm after exit")

	scene.confirmed_callback = Callable(sink, "confirm")
	result = StageClearResultCallbackSceneHandler.exit_to_menu(scene)
	_expect(result == StageClearResultCallbackHandler.RESULT_CONFIRMED, "callback scene handler should fall back to confirm when exit callback is invalid")
	_expect(sink.confirm_calls == 2, "callback scene handler should invoke fallback confirm once")
	_expect(not scene.confirmed_callback.is_valid(), "callback scene handler should clear fallback confirm after fallback exit")
	scene.free()


func _verify_scene_delegates_callbacks() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_callback_scene_handler.gd")
	var navigation_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_navigation_scene_handler.gd")
	_expect(navigation_scene_handler_source.find("StageClearResultCallbackSceneHandler.confirm") >= 0, "navigation scene handler should delegate confirm callback scene glue")
	_expect(navigation_scene_handler_source.find("StageClearResultCallbackSceneHandler.enter_plaza") >= 0, "navigation scene handler should delegate plaza callback scene glue")
	_expect(navigation_scene_handler_source.find("StageClearResultCallbackSceneHandler.exit_to_menu") >= 0, "navigation scene handler should delegate exit callback scene glue")
	_expect(source.find("StageClearResultCallbackSceneHandler.confirm") < 0, "result scene should not keep confirm callback scene glue")
	_expect(source.find("StageClearResultCallbackSceneHandler.enter_plaza") < 0, "result scene should not keep plaza callback scene glue")
	_expect(source.find("StageClearResultCallbackSceneHandler.exit_to_menu") < 0, "result scene should not keep exit callback scene glue")
	_expect(source.find("StageClearResultCallbackHandler.") < 0, "result scene should not call callback handler directly")
	_expect(scene_handler_source.find("StageClearResultCallbackHandler.invoke_confirm") >= 0, "callback scene handler should delegate confirm callback invocation")
	_expect(scene_handler_source.find("StageClearResultCallbackHandler.invoke_enter_plaza") >= 0, "callback scene handler should delegate plaza callback invocation")
	_expect(scene_handler_source.find("StageClearResultCallbackHandler.invoke_exit_to_menu") >= 0, "callback scene handler should delegate exit callback invocation")
	_expect(scene_handler_source.find("StageClearResultAudioSceneHandler.stop_dalji_click_voice") >= 0, "callback scene handler should stop Dalji click voice before callbacks")
	_expect(source.find("confirmed_callback.call()") < 0, "result scene should not call confirmed callback directly")
	_expect(source.find("enter_plaza_callback.call()") < 0, "result scene should not call plaza callback directly")
	_expect(source.find("exit_to_menu_callback.call()") < 0, "result scene should not call exit callback directly")
	_expect(source.find("func _confirm") < 0 and source.find("func _enter_plaza") < 0 and source.find("func _exit_to_menu") < 0, "result scene should not keep callback route wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
