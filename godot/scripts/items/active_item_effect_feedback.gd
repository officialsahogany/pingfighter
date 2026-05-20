extends RefCounted


func trigger_registry_feedback(
	registry: Object,
	gauge_flash: bool = false,
	dash_flash: bool = false,
	shake_amount: float = -1.0,
	shake_duration: float = 0.0
) -> void:
	trigger_feedback_state(
		_get_instance(registry, "battle_feedback_state"),
		gauge_flash,
		dash_flash,
		shake_amount,
		shake_duration
	)


func trigger_feedback_state(
	feedback: Object,
	gauge_flash: bool = false,
	dash_flash: bool = false,
	shake_amount: float = -1.0,
	shake_duration: float = 0.0
) -> void:
	if feedback == null:
		return
	if dash_flash and feedback.has_method("trigger_dash_flash"):
		feedback.trigger_dash_flash()
	if gauge_flash and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()
	if shake_amount >= 0.0 and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(shake_amount, shake_duration)


func play_first_audio(registry: Object, method_names: Array) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	for method_name_value in method_names:
		var method_name := str(method_name_value)
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func play_all_audio(registry: Object, method_names: Array) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	for method_name_value in method_names:
		var method_name := str(method_name_value)
		if audio.has_method(method_name):
			audio.call(method_name)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
