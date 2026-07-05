extends RefCounted

const StageClearResultAudioSceneHandler := preload("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
const StageClearResultCallbackHandler := preload("res://scripts/ui/stage_clear_result_callback_handler.gd")


static func confirm(scene: Object) -> String:
	if scene == null:
		return StageClearResultCallbackHandler.RESULT_NONE
	StageClearResultAudioSceneHandler.stop_dalji_click_voice(scene)
	var confirm_callback: Callable = _get_scene_callable(scene, &"confirmed_callback")
	scene.set("confirmed_callback", Callable())
	return StageClearResultCallbackHandler.invoke_confirm(confirm_callback)


static func enter_plaza(scene: Object) -> String:
	if scene == null:
		return StageClearResultCallbackHandler.RESULT_NONE
	StageClearResultAudioSceneHandler.stop_dalji_click_voice(scene)
	var plaza_callback: Callable = _get_scene_callable(scene, &"enter_plaza_callback")
	scene.set("enter_plaza_callback", Callable())
	return StageClearResultCallbackHandler.invoke_enter_plaza(plaza_callback)


static func exit_to_menu(scene: Object) -> String:
	if scene == null:
		return StageClearResultCallbackHandler.RESULT_NONE
	StageClearResultAudioSceneHandler.stop_dalji_click_voice(scene)
	var exit_callback: Callable = _get_scene_callable(scene, &"exit_to_menu_callback")
	var confirm_callback: Callable = _get_scene_callable(scene, &"confirmed_callback")
	var fallback_confirm_callback: Callable = confirm_callback if not exit_callback.is_valid() else Callable()
	scene.set("exit_to_menu_callback", Callable())
	scene.set("confirmed_callback", Callable())
	return StageClearResultCallbackHandler.invoke_exit_to_menu(exit_callback, fallback_confirm_callback)


static func _get_scene_callable(scene: Object, field_name: StringName) -> Callable:
	var value: Variant = scene.get(field_name)
	return value if value is Callable else Callable()
