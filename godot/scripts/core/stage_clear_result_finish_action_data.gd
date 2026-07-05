extends RefCounted

const ACTION_NEXT_STAGE := "next_stage"
const ACTION_PLAZA_CONTINUE := "plaza_continue"
const ACTION_EXIT_TO_MENU := "exit_to_menu"


static func build_context(
	active: bool,
	reset_callback: Callable,
	exit_callback: Callable,
	grant_pending_rewards: Callable,
	apply_stage_clear_progress: Callable,
	mark_inactive: Callable,
	free_result_scene: Callable,
	free_plaza_scene: Callable
) -> Dictionary:
	return {
		"active": active,
		"reset_callback": reset_callback,
		"exit_callback": exit_callback,
		"grant_pending_rewards": grant_pending_rewards,
		"apply_stage_clear_progress": apply_stage_clear_progress,
		"mark_inactive": mark_inactive,
		"free_result_scene": free_result_scene,
		"free_plaza_scene": free_plaza_scene,
	}


static func finish_context_action(action: String, context: Dictionary) -> void:
	match action:
		ACTION_NEXT_STAGE:
			finish_next_stage(context)
		ACTION_PLAZA_CONTINUE:
			finish_plaza_and_continue(context)
		ACTION_EXIT_TO_MENU:
			finish_exit_to_menu(context)


static func finish_next_stage(context: Dictionary) -> void:
	if not _is_active(context):
		return
	_call(context.get("grant_pending_rewards", Callable()))
	_call(context.get("apply_stage_clear_progress", Callable()), [true])
	_finish_with_callback(context, _get_callable(context, "reset_callback"))


static func finish_plaza_and_continue(context: Dictionary) -> void:
	if not _is_active(context):
		return
	_finish_with_callback(context, _get_callable(context, "reset_callback"))


static func finish_exit_to_menu(context: Dictionary) -> void:
	if not _is_active(context):
		return
	_call(context.get("grant_pending_rewards", Callable()))
	_call(context.get("apply_stage_clear_progress", Callable()), [false])
	var exit_callback: Callable = _get_callable(context, "exit_callback")
	var reset_callback: Callable = _get_callable(context, "reset_callback") if not exit_callback.is_valid() else Callable()
	_finish_with_callback(context, exit_callback if exit_callback.is_valid() else reset_callback)


static func _finish_with_callback(context: Dictionary, callback: Callable) -> void:
	_call(context.get("mark_inactive", Callable()))
	_call(context.get("free_result_scene", Callable()))
	_call(context.get("free_plaza_scene", Callable()))
	if callback.is_valid():
		callback.call()


static func _is_active(context: Dictionary) -> bool:
	return bool(context.get("active", false))


static func _get_callable(context: Dictionary, key: String) -> Callable:
	var value: Variant = context.get(key, Callable())
	return value if value is Callable else Callable()


static func _call(callable_value: Variant, args: Array = []) -> void:
	if not (callable_value is Callable):
		return
	var callback: Callable = callable_value
	if not callback.is_valid():
		return
	callback.callv(args)
