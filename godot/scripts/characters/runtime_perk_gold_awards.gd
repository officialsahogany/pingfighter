extends RefCounted

const RALLY_BASE := 4
const RALLY_SPEED_BONUS_8 := 2
const RALLY_SPEED_BONUS_12 := 4
const RALLY_SPEED_BONUS_16 := 6
const RALLY_SPEED_BONUS_20 := 8
const ENRAGED_BOSS_MULTIPLIER := 1.50
const SMASHER_COMBO_BONUS_PER_STACK := 0.08
const BLACKSMITH_STRUCTURE_BONUS := 0.15
const VIPER_IGNITION_AURA_GOLD_BONUS := 50
const DEFAULT_FEEDBACK_TEMPLATE := "\ud37d \uace8\ub4dc +%d"


static func get_viper_ignition_aura_gold_bonus(viper_ignition_aura_active: bool) -> int:
	return VIPER_IGNITION_AURA_GOLD_BONUS if viper_ignition_aura_active else 0


static func build_item_gold_gain_multiplier_update(current_multiplier: float, multiplier: float) -> Dictionary:
	var next_multiplier: float = max(0.0, float(multiplier))
	return {
		"changed": not is_equal_approx(max(0.0, current_multiplier), next_multiplier),
		"multiplier": next_multiplier,
	}


static func apply_item_gold_gain_multiplier_update(runtime_state: Object, update: Dictionary) -> Dictionary:
	if runtime_state == null or not update.has("multiplier"):
		return {"accepted": false}
	runtime_state.set("item_gold_gain_multiplier", float(update.get("multiplier", runtime_state.get("item_gold_gain_multiplier"))))
	return {
		"accepted": true,
		"changed": bool(update.get("changed", false)),
		"multiplier": float(runtime_state.get("item_gold_gain_multiplier")),
	}


static func calculate_rally_gold(ball_vel: Vector2) -> int:
	var speed: float = ball_vel.length()
	var speed_bonus := 0
	if speed < 8.0:
		speed_bonus = 0
	elif speed < 12.0:
		speed_bonus = RALLY_SPEED_BONUS_8
	elif speed < 16.0:
		speed_bonus = RALLY_SPEED_BONUS_12
	elif speed < 20.0:
		speed_bonus = RALLY_SPEED_BONUS_16
	else:
		speed_bonus = RALLY_SPEED_BONUS_20
	return RALLY_BASE + speed_bonus


static func award_rally_gold(
	ball_vel: Vector2,
	current_total: int,
	context: Dictionary = {},
	deps: Dictionary = {},
	item_gold_gain_multiplier: float = 1.0,
	viper_ignition_aura_active: bool = false
) -> Dictionary:
	if bool(context.get("arena_mode_enabled", false)):
		return {
			"total": int(current_total),
			"awarded": 0,
			"show_feedback": false,
			"feedback_timer": 0.0,
			"feedback_text": "",
		}
	var amount: int = calculate_rally_gold(ball_vel)
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("consume_next_rally_gold_multiplier"):
		if bool(dash_state.consume_next_rally_gold_multiplier()):
			amount *= 2
	return award_gold(
		amount,
		current_total,
		context,
		deps,
		item_gold_gain_multiplier,
		viper_ignition_aura_active
	)


static func award_gold(
	amount: int,
	current_total: int,
	context: Dictionary = {},
	deps: Dictionary = {},
	item_gold_gain_multiplier: float = 1.0,
	viper_ignition_aura_active: bool = false,
	feedback_duration: float = 1.0
) -> Dictionary:
	var boosted_amount: int = apply_modifiers(
		amount,
		context,
		deps,
		item_gold_gain_multiplier,
		viper_ignition_aura_active
	)
	return store_gold_gain(boosted_amount, current_total, feedback_duration)


static func award_convert_to_gold_choice(
	choice: Dictionary,
	current_total: int,
	owner: Object,
	combo_state: Object = null,
	item_gold_gain_multiplier: float = 1.0,
	viper_ignition_aura_active: bool = false
) -> Dictionary:
	return award_gold(
		int(choice.get("gold_amount", 500)),
		current_total,
		build_owner_context(owner, combo_state),
		{},
		item_gold_gain_multiplier,
		viper_ignition_aura_active,
		1.2
	)


static func apply_modifiers(
	amount: int,
	context: Dictionary = {},
	deps: Dictionary = {},
	item_gold_gain_multiplier: float = 1.0,
	viper_ignition_aura_active: bool = false
) -> int:
	var base_amount: int = max(0, amount)
	if base_amount <= 0:
		return 0
	if _is_enraged_context(context):
		base_amount = int(float(base_amount) * ENRAGED_BOSS_MULTIPLIER)
	if viper_ignition_aura_active:
		base_amount += VIPER_IGNITION_AURA_GOLD_BONUS
	base_amount = apply_item_bonus(base_amount, item_gold_gain_multiplier)
	var combo_count: int = _get_smasher_combo_count(context, deps)
	if combo_count >= 1:
		base_amount = int(float(base_amount) * (1.0 + float(combo_count) * SMASHER_COMBO_BONUS_PER_STACK))
	var blacksmith_bonus: float = _get_blacksmith_structure_bonus(context)
	if blacksmith_bonus > 0.0:
		base_amount = int(float(base_amount) * (1.0 + blacksmith_bonus))
	return base_amount


static func apply_item_bonus(amount: int, item_gold_gain_multiplier: float) -> int:
	return int(floor(float(max(0, amount)) * max(0.0, item_gold_gain_multiplier)))


static func store_gold_gain(boosted_amount: int, current_total: int, _feedback_duration: float = 1.0) -> Dictionary:
	var stored_amount: int = max(0, int(boosted_amount))
	return {
		"total": int(current_total) + stored_amount,
		"awarded": stored_amount,
		"show_feedback": false,
		"feedback_timer": 0.0,
		"feedback_text": "",
	}


static func build_state_update(result: Dictionary, current_total: int) -> Dictionary:
	var awarded_amount: int = int(result.get("awarded", 0))
	var next_total: int = int(result.get("total", current_total))
	var feedback_text := ""
	var feedback_timer := 0.0
	var has_feedback := bool(result.get("show_feedback", false)) and awarded_amount > 0
	if has_feedback:
		feedback_text = str(result.get("feedback_text", ""))
		if feedback_text == "":
			feedback_text = format_default_gold_feedback(awarded_amount)
		feedback_timer = float(result.get("feedback_timer", 1.0))
	return {
		"gold_from_perks": next_total,
		"awarded": awarded_amount,
		"has_feedback": has_feedback,
		"feedback_text": feedback_text,
		"feedback_timer": feedback_timer,
	}


static func build_state_application(
	result: Dictionary,
	current_total: int,
	current_feedback_text: String = "",
	current_feedback_timer: float = 0.0
) -> Dictionary:
	var update: Dictionary = build_state_update(result, current_total)
	if bool(update.get("has_feedback", false)):
		return {
			"gold_from_perks": int(update.get("gold_from_perks", current_total)),
			"feedback_text": str(update.get("feedback_text", "")),
			"feedback_timer": float(update.get("feedback_timer", current_feedback_timer)),
		}
	return {
		"gold_from_perks": int(update.get("gold_from_perks", current_total)),
		"feedback_text": current_feedback_text,
		"feedback_timer": max(0.0, current_feedback_timer),
	}


static func apply_state_application(runtime_state: Object, state_application: Dictionary) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	runtime_state.set("gold_from_perks", int(state_application.get("gold_from_perks", runtime_state.get("gold_from_perks"))))
	return {
		"accepted": true,
		"gold_from_perks": int(runtime_state.get("gold_from_perks")),
		"feedback_text": str(state_application.get("feedback_text", runtime_state.get("feedback_text"))),
		"feedback_timer": float(state_application.get("feedback_timer", runtime_state.get("feedback_timer"))),
	}


static func apply_award_result_to_runtime_state(
	runtime_state: Object,
	result: Dictionary,
	feedback_apply: Callable = Callable()
) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	var current_total: int = int(runtime_state.get("gold_from_perks"))
	var current_feedback_text: String = str(runtime_state.get("feedback_text"))
	var current_feedback_timer: float = float(runtime_state.get("feedback_timer"))
	var state_application: Dictionary = build_state_application(
		result,
		current_total,
		current_feedback_text,
		current_feedback_timer
	)
	var state_apply_result: Dictionary = apply_state_application(runtime_state, state_application)
	if not bool(state_apply_result.get("accepted", false)):
		return {
			"accepted": false,
			"gold_from_perks": current_total,
		}
	var feedback_result: Dictionary = {}
	if feedback_apply.is_valid():
		var feedback_value: Variant = feedback_apply.call(runtime_state, state_apply_result, current_feedback_timer)
		if feedback_value is Dictionary:
			feedback_result = feedback_value
	return {
		"accepted": true,
		"gold_from_perks": int(state_apply_result.get("gold_from_perks", current_total)),
		"state_application": state_application,
		"state_apply_result": state_apply_result,
		"feedback_result": feedback_result,
	}


static func format_default_gold_feedback(amount: int) -> String:
	return DEFAULT_FEEDBACK_TEMPLATE % max(0, int(amount))


static func build_owner_context(owner: Object, combo_state: Object = null) -> Dictionary:
	var context: Dictionary = {}
	if owner != null:
		for key in [
			"selected_character_type",
			"arena_mode_enabled",
			"enraged_boss_active",
			"boss_enraged",
			"blacksmith_divine_stone_active",
			"blacksmith_divine_active",
			"blacksmith_divine_stone_state",
			"blacksmith_turret_active",
			"blacksmith_turret_state",
		]:
			var value: Variant = owner.get(str(key))
			if value != null:
				context[str(key)] = value
	if combo_state != null and combo_state.has_method("get_combo_count"):
		context["smasher_combo_count"] = max(0, int(combo_state.get_combo_count()))
	return context


static func _is_enraged_context(context: Dictionary) -> bool:
	return bool(context.get("enraged_boss_active", context.get("boss_enraged", false)))


static func _get_smasher_combo_count(context: Dictionary, deps: Dictionary = {}) -> int:
	if str(context.get("selected_character_type", "")).strip_edges().to_lower() != "smasher":
		return 0
	if context.has("smasher_combo_count"):
		return max(0, int(context.get("smasher_combo_count", 0)))
	var combo_state: Object = deps.get("combo_state", null)
	if combo_state != null and combo_state.has_method("get_combo_count"):
		return max(0, int(combo_state.get_combo_count()))
	return 0


static func _get_blacksmith_structure_bonus(context: Dictionary) -> float:
	if str(context.get("selected_character_type", "")).strip_edges().to_lower() != "blacksmith":
		return 0.0
	var bonus := 0.0
	if _has_context_flag(context, [
		"blacksmith_divine_stone_active",
		"blacksmith_divine_active",
		"blacksmith_divine_stone_state",
	]):
		bonus += BLACKSMITH_STRUCTURE_BONUS
	if _has_context_flag(context, [
		"blacksmith_turret_active",
		"blacksmith_turret_state",
	]):
		bonus += BLACKSMITH_STRUCTURE_BONUS
	return bonus


static func _has_context_flag(context: Dictionary, keys: Array) -> bool:
	for key in keys:
		var value: Variant = context.get(str(key), null)
		if value == null:
			continue
		if value is bool:
			if bool(value):
				return true
			continue
		if value is Dictionary:
			if not (value as Dictionary).is_empty():
				return true
			continue
		return true
	return false
