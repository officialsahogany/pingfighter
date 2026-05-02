extends RefCounted

const SmasherPowerSmashActivationFeedbackController := preload("res://scripts/characters/smasher_power_smash_activation_feedback_controller.gd")

var feedback_controller: Object = SmasherPowerSmashActivationFeedbackController.new()


func try_activate(context: Dictionary, deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"activated": false,
		"special_gauge": float(context.get("special_gauge", 0.0)),
	}

	var input_reader: Object = deps.get("input_reader", null)
	if input_reader == null:
		return result
	var input_snapshot: Dictionary = input_reader.get_snapshot()
	if not bool(input_snapshot.get("action_pressed", false)):
		return result

	var power_state: Object = deps.get("power_state", null)
	if power_state == null or not can_activate(context, deps):
		return result

	var activation_direction: int = int(input_snapshot.get("power_smash_direction", 0))
	var activation_arc_strength: float = _get_activation_arc_strength(activation_direction)

	var combo_state: Object = deps.get("combo_state", null)
	var combo_consumed: int = 0
	var combo_min_count: int = int(context.get("combo_min_count", 2))
	if combo_state != null:
		var effective_combo: int = int(combo_state.get_effective_combo())
		if effective_combo >= combo_min_count:
			combo_consumed = effective_combo
			combo_state.reset_combo()

	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	result["special_gauge"] = max(
		0.0,
		float(context.get("special_gauge", 0.0)) - float(context.get("gauge_cost", 0.0))
	)

	feedback_controller.apply_pre_activation_feedback(context, deps, callbacks, current_msec)

	power_state.begin_activation(
		activation_direction,
		activation_arc_strength,
		combo_consumed,
		float(context.get("text_duration_frames", 0.0))
	)

	var combo_bonus_count: int = combo_consumed if combo_consumed >= combo_min_count else 0
	feedback_controller.apply_post_activation_feedback(context, deps, power_state, combo_bonus_count)

	result["activated"] = true
	return result


func can_activate(context: Dictionary, deps: Dictionary) -> bool:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null:
		return false

	var round_state: Object = deps.get("round_state", null)
	var drive_input_state: Object = deps.get("drive_input_state", null)
	var frame_cooldown_blocked: bool = drive_input_state != null and bool(drive_input_state.is_frame_cooldown_blocked())
	var cooldown_remaining: float = 0.0
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null:
		cooldown_remaining = skill_state.get_configured_cooldown_remaining(
			"power_smashing",
			int(context.get("current_msec", Time.get_ticks_msec())),
			deps.get("skill_config", null)
		)

	return power_state.can_activate(
		round_state == null or round_state.is_waiting_for_serve(),
		bool(context.get("ball_active", false)),
		float(context.get("special_gauge", 0.0)),
		float(context.get("gauge_cost", 0.0)),
		frame_cooldown_blocked,
		cooldown_remaining
	)


func _get_activation_arc_strength(direction: int) -> float:
	if direction < 0:
		return -0.68 + randf_range(-0.08, 0.08)
	if direction > 0:
		return 0.68 + randf_range(-0.08, 0.08)
	return 0.0
