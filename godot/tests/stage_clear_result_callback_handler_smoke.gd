extends SceneTree

const StageClearResultCallbackHandler := preload("res://scripts/ui/stage_clear_result_callback_handler.gd")

var _failures: Array[String] = []


class CallbackSink:
	extends RefCounted

	var confirm_calls := 0
	var exit_calls := 0

	func confirm() -> void:
		confirm_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1


func _init() -> void:
	_verify_callback_handler_contract()
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


func _verify_scene_delegates_callbacks() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultCallbackHandler.invoke_confirm") >= 0, "result scene should delegate confirm callback invocation")
	_expect(source.find("StageClearResultCallbackHandler.invoke_exit_to_menu") >= 0, "result scene should delegate exit callback invocation")
	_expect(source.find("confirmed_callback.call()") < 0, "result scene should not call confirmed callback directly")
	_expect(source.find("exit_to_menu_callback.call()") < 0, "result scene should not call exit callback directly")
	_expect(source.find("_stop_dalji_click_voice()") >= 0, "result scene should keep voice cleanup before callbacks")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
