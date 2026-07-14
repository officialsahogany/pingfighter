extends RefCounted


func is_intro_or_warmup_blocking(
	module_getter: Callable,
	battle_initialized: bool,
	stage_landing_intro_started: bool
) -> bool:
	return (
		is_logo_intro_active(module_getter)
		or not battle_initialized
		or not is_boot_warmup_finished(module_getter)
		or not stage_landing_intro_started
	)


func is_mobile_touch_scene_ready(
	module_getter: Callable,
	battle_initialized: bool,
	stage_landing_intro_started: bool
) -> bool:
	return (
		not is_logo_intro_active(module_getter)
		and battle_initialized
		and is_boot_warmup_finished(module_getter)
		and stage_landing_intro_started
		and not is_stage_landing_intro_active(module_getter)
		and not is_ball_spawn_intro_active(module_getter)
		and not is_stage_transition_loading_active(module_getter)
		and not is_stage7_prebattle_pending(module_getter)
	)


func is_logo_intro_active(module_getter: Callable) -> bool:
	var logo_intro: Object = _get_module(module_getter, "penguin_logo_intro")
	return _is_module_active(logo_intro)


func is_boot_warmup_finished(module_getter: Callable) -> bool:
	var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
	if warmup == null or not warmup.has_method("is_finished"):
		return true
	return bool(warmup.is_finished())


func is_stage_landing_intro_active(module_getter: Callable) -> bool:
	var landing_intro: Object = _get_module(module_getter, "stage_landing_intro")
	return _is_module_active(landing_intro)


func is_ball_spawn_intro_active(module_getter: Callable) -> bool:
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	return _is_module_active(ball_spawn_intro)


func is_stage7_prebattle_pending(module_getter: Callable) -> bool:
	var presentation: Object = _get_module(module_getter, "stage7_akamu_prebattle_presentation")
	return _is_module_active(presentation)


func is_stage_transition_loading_active(module_getter: Callable) -> bool:
	var match_event_driver: Object = _get_module(module_getter, "battle_scene_match_event_driver")
	return (
		match_event_driver != null
		and match_event_driver.has_method("is_stage_transition_loading_active")
		and bool(match_event_driver.is_stage_transition_loading_active())
	)


func _is_module_active(module: Object) -> bool:
	return module != null and module.has_method("is_active") and bool(module.is_active())


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
