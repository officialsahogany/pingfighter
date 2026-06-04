extends RefCounted

const SmasherPowerSmashActivationFeedbackController := preload("res://scripts/characters/smasher_power_smash_activation_feedback_controller.gd")

const POWER_SMASH_EFFECT_MULT := 1.0

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
	if power_state == null:
		return result

	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	var activated_skill: String = _get_activatable_skill(context, deps, current_msec)
	if activated_skill == "":
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

	var gauge_cost: float = _get_skill_cost(activated_skill, context, deps)
	result["special_gauge"] = max(
		0.0,
		float(context.get("special_gauge", 0.0)) - gauge_cost
	)

	feedback_controller.apply_pre_activation_feedback(context, deps, callbacks, current_msec, activated_skill)

	power_state.begin_activation(
		activation_direction,
		activation_arc_strength,
		combo_consumed,
		float(context.get("text_duration_frames", 0.0)),
		activated_skill == "ghost_shot",
		current_msec,
		float(context.get("power_smash_freeze_duration", 0.0))
	)
	_play_skill_cutin_voice(activated_skill, context, deps)

	var combo_bonus_count: int = combo_consumed if combo_consumed >= combo_min_count else 0
	feedback_controller.apply_post_activation_feedback(context, deps, power_state, combo_bonus_count)

	result["activated"] = true
	result["activated_skill"] = activated_skill
	return result


func can_activate(context: Dictionary, deps: Dictionary) -> bool:
	return _get_activatable_skill(context, deps, int(context.get("current_msec", Time.get_ticks_msec()))) != ""


func _get_activatable_skill(context: Dictionary, deps: Dictionary, current_msec: int) -> String:
	if _can_activate_skill("ghost_shot", context, deps, current_msec):
		return "ghost_shot"
	if _can_activate_skill("power_smashing", context, deps, current_msec):
		return "power_smashing"
	return ""


func _can_activate_skill(skill_name: String, context: Dictionary, deps: Dictionary, current_msec: int) -> bool:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null:
		return false

	var skill_config: Object = deps.get("skill_config", null)
	if skill_name == "ghost_shot":
		if skill_config == null or not skill_config.has_method("is_skill_equipped"):
			return false
		if not bool(skill_config.is_skill_equipped("ghost_shot")):
			return false

	var round_state: Object = deps.get("round_state", null)
	var drive_input_state: Object = deps.get("drive_input_state", null)
	var frame_cooldown_blocked: bool = drive_input_state != null and bool(drive_input_state.is_frame_cooldown_blocked())
	var cooldown_remaining: float = 0.0
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null:
		cooldown_remaining = skill_state.get_configured_cooldown_remaining(
			skill_name,
			current_msec,
			skill_config
		)

	return power_state.can_activate(
		round_state == null or round_state.is_waiting_for_serve(),
		bool(context.get("ball_active", false)),
		float(context.get("special_gauge", 0.0)),
		_get_skill_cost(skill_name, context, deps),
		frame_cooldown_blocked,
		cooldown_remaining
	)


func _get_activation_arc_strength(direction: int) -> float:
	if direction < 0:
		return (-0.68 + randf_range(-0.08, 0.08)) * POWER_SMASH_EFFECT_MULT
	if direction > 0:
		return (0.68 + randf_range(-0.08, 0.08)) * POWER_SMASH_EFFECT_MULT
	return 0.0


func _get_skill_cost(skill_name: String, context: Dictionary, deps: Dictionary) -> float:
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(skill_name))
	if skill_name == "ghost_shot":
		return 420.0
	return float(context.get("gauge_cost", 0.0))


func _play_skill_cutin_voice(skill_name: String, context: Dictionary, deps: Dictionary) -> void:
	# Only the freezing cut-in carries a Mika voice line; mirror power-smash for ghost-smash.
	if float(context.get("power_smash_freeze_duration", 0.0)) <= 0.0:
		return
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if skill_name == "ghost_shot":
		if audio.has_method("play_ghost_smashing_cutin_voice"):
			audio.play_ghost_smashing_cutin_voice()
	elif skill_name == "power_smashing":
		if audio.has_method("play_power_smashing_cutin_voice"):
			audio.play_power_smashing_cutin_voice()
