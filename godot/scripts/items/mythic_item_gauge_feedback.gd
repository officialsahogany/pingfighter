extends RefCounted


func trigger_gauge_flash(runtime: Object, deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		feedback = runtime._get_instance(deps.get("registry", null), "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func trigger_orb_gauge_spin(_runtime: Object, deps: Dictionary) -> void:
	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null and orb_hud_state.has_method("trigger_gauge_spin"):
		orb_hud_state.trigger_gauge_spin(Time.get_ticks_msec())
