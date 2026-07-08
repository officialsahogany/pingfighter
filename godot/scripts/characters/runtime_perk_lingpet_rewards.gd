extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

const DEFAULT_FEEDBACK_TIMER := 1.1


func apply_affinity_chip(
	owner: Object,
	registry: Object,
	get_instance: Callable,
	choice_name: String = ""
) -> Dictionary:
	var runtime: Object = get_instance.call(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("add_enhancement_chip"):
		return {"accepted": false, "blocked_reason": "missing_lingpet_runtime"}
	var result: Variant = runtime.add_enhancement_chip(owner, registry)
	var response: Dictionary
	if result is Dictionary:
		response = (result as Dictionary).duplicate(true)
	else:
		response = {"accepted": bool(result)}
	if bool(response.get("accepted", false)):
		response["feedback_text"] = format_affinity_chip_feedback(
			choice_name,
			int(response.get("chip_count", 0)),
			int(response.get("max_chips", 0))
		)
		response["feedback_timer"] = DEFAULT_FEEDBACK_TIMER
	return response


func apply_affinity_chip_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	choice_name: String = ""
) -> Dictionary:
	var get_instance := _build_runtime_state_get_instance(runtime_state)
	if not get_instance.is_valid():
		return {"accepted": false, "blocked_reason": "missing_get_instance_callback"}
	return apply_affinity_chip(owner, registry, get_instance, choice_name)


func apply_ring_core_upgrade(
	owner: Object,
	registry: Object,
	requested_tier: int,
	get_instance: Callable,
	choice_name: String = ""
) -> Dictionary:
	# R5 / per-run: upgrades THIS run's tier through egg_runtime, not the
	# dropped permanent store path.
	var runtime: Object = get_instance.call(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("upgrade_run_ring_core_tier"):
		return {"accepted": false, "blocked_reason": "missing_lingpet_runtime"}
	var max_tier := LingpetRingCoreRules.MAX_RING_CORE_TIER
	var current_tier := 0
	if runtime.has_method("get_run_ring_core_tier"):
		current_tier = clampi(int(runtime.get_run_ring_core_tier()), 0, max_tier)
	var target_tier := requested_tier if requested_tier > 0 else current_tier + 1
	target_tier = clampi(target_tier, 1, max_tier)
	if target_tier <= current_tier:
		return {
			"accepted": false,
			"blocked_reason": "max_ring_core_tier" if current_tier >= max_tier else "not_higher_ring_core_tier",
			"current_tier": current_tier,
			"target_tier": target_tier,
			"max_tier": max_tier,
		}
	var upgrade_result: Dictionary = runtime.upgrade_run_ring_core_tier(target_tier, owner, registry)
	if not bool(upgrade_result.get("accepted", false)):
		return {
			"accepted": false,
			"blocked_reason": str(upgrade_result.get("blocked_reason", "ring_core_upgrade_failed")),
			"current_tier": current_tier,
			"target_tier": target_tier,
			"max_tier": max_tier,
		}
	return {
		"accepted": true,
		"current_tier": current_tier,
		"target_tier": target_tier,
		"new_tier": int(upgrade_result.get("new_tier", target_tier)),
		"max_tier": max_tier,
		"ring_core_name": get_ring_core_tier_name(target_tier),
		"feedback_text": format_ring_core_upgrade_feedback(choice_name, get_ring_core_tier_name(target_tier)),
		"feedback_timer": DEFAULT_FEEDBACK_TIMER,
	}


func apply_ring_core_upgrade_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	requested_tier: int,
	choice_name: String = ""
) -> Dictionary:
	var get_instance := _build_runtime_state_get_instance(runtime_state)
	if not get_instance.is_valid():
		return {"accepted": false, "blocked_reason": "missing_get_instance_callback"}
	return apply_ring_core_upgrade(
		owner,
		registry,
		requested_tier,
		get_instance,
		choice_name
	)


func build_debug_ring_core_upgrade_update(perk_id: String, target_level: int, perk_data: Dictionary) -> Dictionary:
	var clean_id: String = perk_id.strip_edges()
	if clean_id == "" or perk_data.is_empty():
		return {"accepted": false}
	var max_tier: int = int(perk_data.get("max_level", LingpetRingCoreRules.MAX_RING_CORE_TIER))
	max_tier = clampi(max_tier, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	var next_tier: int = clampi(target_level, 1, max_tier)
	return {
		"accepted": true,
		"choice_id": clean_id,
		"next_tier": next_tier,
		"max_tier": max_tier,
	}


func format_affinity_chip_feedback(choice_name: String, chip_count: int, max_chips: int) -> String:
	return "%s %d/%d" % [
		choice_name,
		max(0, int(chip_count)),
		max(0, int(max_chips)),
	]


func format_ring_core_upgrade_feedback(choice_name: String, ring_core_name: String) -> String:
	return "%s %s" % [
		choice_name,
		str(ring_core_name),
	]


func get_ring_core_tier_name(tier: int) -> String:
	var clamped_tier := clampi(tier, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		match clamped_tier:
			1:
				return "Standard"
			2:
				return "Boost"
			3:
				return "Hyper"
			4:
				return "Overdrive"
			5:
				return "Ultimate"
			6:
				return "Zenith"
		return ""
	match clamped_tier:
		1:
			return "\uc2a4\ud0e0\ub2e4\ub4dc"
		2:
			return "\ubd80\uc2a4\ud2b8"
		3:
			return "\ud558\uc774\ud37c"
		4:
			return "\uc624\ubc84\ub4dc\ub77c\uc774\ube0c"
		5:
			return "\uc5bc\ud2f0\ubc0b"
		6:
			return "\uc81c\ub2c8\uc2a4"
	return ""


func tick_ring_core_offer_cooldown(registry: Object, get_instance: Callable) -> void:
	var runtime: Object = get_instance.call(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("tick_ring_core_offer_cooldown"):
		runtime.tick_ring_core_offer_cooldown()


func tick_ring_core_offer_cooldown_from_runtime_state(runtime_state: Object, registry: Object) -> void:
	var get_instance := _build_runtime_state_get_instance(runtime_state)
	if get_instance.is_valid():
		tick_ring_core_offer_cooldown(registry, get_instance)


func _build_runtime_state_get_instance(runtime_state: Object) -> Callable:
	if runtime_state != null and runtime_state.has_method("_get_instance"):
		return Callable(runtime_state, "_get_instance")
	return Callable()
