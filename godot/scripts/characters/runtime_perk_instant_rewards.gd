extends RefCounted

const FULL_GAUGE_FEEDBACK_TEXT := "\uac8c\uc774\uc9c0 \uc644\ucda9"
const DIMENSION_GATE_FEEDBACK_TEXT := "\ucc28\uc6d0\uac1c\ubc29"
const IMMEDIATE_FEEDBACK_TIMER := 1.2
const MONKEY_BLESSING_FEEDBACK_TIMER := 1.1
const TREASURE_HUNT_FALLBACK_FEEDBACK_TEXT := "\ubcf4\ubb3c\ud0d0\uc0c9"
const TREASURE_HUNT_FEEDBACK_TIMER := 1.6


func apply_bookkeeping_choice(
	choice: Dictionary,
	pending_skill_choices: int,
	starpoint_for_skills: int,
	starpoint_per_choice: int
) -> Dictionary:
	var choice_id: String = str(choice.get("id", ""))
	var next_pending: int = max(0, int(pending_skill_choices))
	var next_starpoints: int = max(0, int(starpoint_for_skills))
	var choice_cost: int = max(1, int(starpoint_per_choice))

	if choice_id == "common_refresh":
		return {
			"handled": true,
			"accepted": true,
			"pending_skill_choices": next_pending + 1,
			"starpoint_for_skills": next_starpoints,
			"feedback_key": "common_refresh",
			"feedback_text": "\uc120\ud0dd\uc9c0 \uc0c8\ub85c\uace0\uce68",
			"feedback_timer": 1.0,
		}

	if choice_id == "star_change":
		next_starpoints += 3
		while next_starpoints >= choice_cost:
			next_starpoints -= choice_cost
			next_pending += 1
		return {
			"handled": true,
			"accepted": true,
			"pending_skill_choices": next_pending,
			"starpoint_for_skills": next_starpoints,
			"feedback_key": "star_change",
			"feedback_text": "\uc2a4\ud0c0\ud3ec\uc778\ud2b8 +3",
			"feedback_timer": 1.0,
		}

	if str(choice.get("is_instant", "")) == "true" or bool(choice.get("is_instant", false)):
		return {
			"handled": true,
			"accepted": true,
			"pending_skill_choices": next_pending,
			"starpoint_for_skills": next_starpoints,
			"feedback_key": "choice_name",
			"feedback_text": str(choice.get("name", choice_id)),
			"feedback_timer": 1.0,
		}

	return {"handled": false}


func build_bookkeeping_state_update(
	result: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	return {
		"handled": bool(result.get("handled", false)),
		"accepted": bool(result.get("accepted", false)),
		"next_pending_skill_choices": int(result.get("pending_skill_choices", current_pending_skill_choices)),
		"next_starpoint_for_skills": int(result.get("starpoint_for_skills", current_starpoint_for_skills)),
		"feedback_result": result,
	}


func build_debug_instant_choice_update(perk_id: String, perk_data: Dictionary) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or perk_data.is_empty():
		return {"accepted": false}
	return {
		"accepted": true,
		"choice_id": clean_id,
		"current_level": 0,
		"next_level": 0,
	}


func apply_full_gauge_choice(
	owner: Object,
	registry: Object,
	skill_state_key: String,
	special_gauge_max: float,
	get_instance: Callable
) -> Dictionary:
	apply_full_gauge(owner, registry, skill_state_key, special_gauge_max, get_instance)
	return {
		"accepted": true,
		"feedback_text": FULL_GAUGE_FEEDBACK_TEXT,
		"feedback_timer": IMMEDIATE_FEEDBACK_TIMER,
	}


func apply_owner_full_gauge_choice(
	owner: Object,
	registry: Object,
	character_context: Object,
	special_gauge_max: float,
	get_instance: Callable
) -> Dictionary:
	return apply_full_gauge_choice(
		owner,
		registry,
		_get_owner_skill_state_key(owner, character_context),
		special_gauge_max,
		get_instance
	)


func apply_full_gauge(
	owner: Object,
	registry: Object,
	skill_state_key: String,
	special_gauge_max: float,
	get_instance: Callable
) -> void:
	if owner != null:
		owner.set("special_gauge", special_gauge_max)
	var dash_state: Object = get_instance.call(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("refill_tokens"):
		dash_state.refill_tokens()
	var skill_state: Object = get_instance.call(registry, skill_state_key)
	if skill_state != null and skill_state.has_method("reset_cooldowns"):
		skill_state.reset_cooldowns()


func apply_owner_full_gauge(
	owner: Object,
	registry: Object,
	character_context: Object,
	special_gauge_max: float,
	get_instance: Callable
) -> void:
	apply_full_gauge(
		owner,
		registry,
		_get_owner_skill_state_key(owner, character_context),
		special_gauge_max,
		get_instance
	)


func apply_dimension_gate_choice(registry: Object, get_instance: Callable) -> Dictionary:
	if not apply_dimension_gate(registry, get_instance):
		return {"accepted": false}
	return {
		"accepted": true,
		"feedback_text": DIMENSION_GATE_FEEDBACK_TEXT,
		"feedback_timer": IMMEDIATE_FEEDBACK_TIMER,
	}


func apply_dimension_gate(registry: Object, get_instance: Callable) -> bool:
	var active_item_runtime: Object = get_instance.call(registry, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("activate_dimension_gate"):
		return false
	return bool(active_item_runtime.activate_dimension_gate(registry))


func apply_monkey_blessing(owner: Object, registry: Object, get_instance: Callable) -> bool:
	if owner == null:
		return false
	var delivery_state: Object = get_instance.call(registry, "monkey_blessing_delivery_state")
	if delivery_state != null and delivery_state.has_method("start"):
		return bool(delivery_state.start(owner, registry))
	var active_item_runtime: Object = get_instance.call(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("fill_empty_slots_with_item"):
		active_item_runtime.fill_empty_slots_with_item("banana", owner, registry)
	return true


func apply_monkey_blessing_choice(
	owner: Object,
	registry: Object,
	get_instance: Callable,
	choice_name: String = ""
) -> Dictionary:
	if not apply_monkey_blessing(owner, registry, get_instance):
		return {"accepted": false}
	return {
		"accepted": true,
		"feedback_text": choice_name,
		"feedback_timer": MONKEY_BLESSING_FEEDBACK_TIMER,
	}


func apply_treasure_hunt(owner: Object, registry: Object, get_instance: Callable) -> Dictionary:
	var treasure_runtime: Object = get_instance.call(registry, "treasure_hunt_runtime")
	if treasure_runtime == null or not treasure_runtime.has_method("start"):
		return {"ok": false}
	return treasure_runtime.start(owner, registry)


func apply_treasure_hunt_choice(owner: Object, registry: Object, get_instance: Callable) -> Dictionary:
	var result: Dictionary = apply_treasure_hunt(owner, registry, get_instance)
	if not bool(result.get("ok", false)):
		result["accepted"] = false
		return result
	var response := result.duplicate(true)
	response["accepted"] = true
	response["feedback_text"] = str(response.get("feedback_text", TREASURE_HUNT_FALLBACK_FEEDBACK_TEXT))
	response["feedback_timer"] = TREASURE_HUNT_FEEDBACK_TIMER
	return response


func _get_owner_skill_state_key(owner: Object, character_context: Object) -> String:
	if character_context == null:
		return "smasher_skill_state"
	var character_type := "smasher"
	if character_context.has_method("get_owner_character_type"):
		character_type = str(character_context.get_owner_character_type(owner))
	if character_context.has_method("get_skill_state_key"):
		return str(character_context.get_skill_state_key(character_type))
	return "smasher_skill_state"
