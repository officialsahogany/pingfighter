extends RefCounted

const LESSON_COST := 200


static func get_menu_action_labels() -> Array[String]:
	return ["초식 수련 %dG" % LESSON_COST, "초식 교환"]


func perform_action(
	action_index: int,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if action_index == 0:
		return _buy_skill_lesson(save_store, owner, registry, consume_ap)
	if action_index == 1:
		return _build_summary("exchange", LESSON_COST, false, "exchange_stub")
	return _build_summary("", LESSON_COST, false, "unknown_academy_action")


func _buy_skill_lesson(save_store: Object, owner: Object, registry: Object, consume_ap: bool) -> Dictionary:
	if not _has_plaza_gold(save_store, LESSON_COST):
		return _build_summary("lesson", LESSON_COST, false, "not_enough_gold")
	if _is_ap_blocked(save_store, consume_ap):
		return _build_summary("lesson", LESSON_COST, false, "no_ap")
	if owner == null:
		return _build_summary("lesson", LESSON_COST, false, "missing_owner")
	var runtime_state := _get_runtime_perk_state(registry)
	if runtime_state == null or not runtime_state.has_method("collect_star_points"):
		return _build_summary("lesson", LESSON_COST, false, "missing_runtime_perk_state")
	var catalog := _get_runtime_perk_catalog(registry)
	if catalog == null or not catalog.has_method("get_choices"):
		return _build_summary("lesson", LESSON_COST, false, "missing_runtime_perk_catalog")
	if _is_choice_modal_busy(runtime_state):
		return _build_summary("lesson", LESSON_COST, false, "choice_already_active")

	var character_type := _get_character_type(owner)
	var preview_choices := _get_lesson_choices(catalog, character_type, runtime_state, owner, registry)
	if preview_choices.is_empty():
		return _build_summary("lesson", LESSON_COST, false, "no_academy_choices")

	var payment := _perform_lesson_payment(save_store, LESSON_COST, consume_ap)
	if not bool(payment.get("changed", false)):
		return _merge_wallet_summary(
			_build_summary("lesson", LESSON_COST, false, str(payment.get("reason", "payment_failed"))),
			payment
		)

	runtime_state.collect_star_points(1, character_type, catalog, owner, registry, true)
	if runtime_state.has_method("open_next_choice"):
		runtime_state.open_next_choice(
			character_type,
			catalog,
			true,
			owner,
			registry,
			null,
			{"source": "plaza_academy", "cost": LESSON_COST}
		)
	var snapshot := _get_runtime_snapshot(runtime_state)
	var opened := bool(snapshot.get("choice_active", false)) and not _get_array(snapshot.get("current_choices", [])).is_empty()
	return _merge_wallet_summary(
		_merge_choice_summary(_build_summary("lesson", LESSON_COST, opened, "ok" if opened else "choice_open_failed"), snapshot),
		payment
	)


func _has_plaza_gold(save_store: Object, amount: int) -> bool:
	return save_store != null and save_store.has_method("get_plaza_gold") and int(save_store.get_plaza_gold()) >= amount


func _is_ap_blocked(save_store: Object, consume_ap: bool) -> bool:
	return consume_ap and (save_store == null or not save_store.has_method("get_ap_current") or int(save_store.get_ap_current()) <= 0)


func _perform_lesson_payment(save_store: Object, cost: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_academy_lesson_payment"):
		return _build_wallet_summary(0, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_academy_lesson_payment(cost, consume_ap)
	if result is Dictionary:
		return result
	return _build_wallet_summary(0, false, "invalid_wallet_result")


func _get_runtime_perk_state(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("runtime_perk_state")


func _get_runtime_perk_catalog(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("runtime_perk_catalog")


func _get_lesson_choices(catalog: Object, character_type: String, runtime_state: Object, owner: Object, registry: Object) -> Array:
	var snapshot := _get_runtime_snapshot(runtime_state)
	var runtime_levels_value: Variant = snapshot.get("runtime_skill_levels", {})
	var runtime_levels: Dictionary = runtime_levels_value if runtime_levels_value is Dictionary else {}
	var result_value: Variant = catalog.get_choices(character_type, runtime_levels, true, 3, owner, registry)
	var result: Array = result_value if result_value is Array else []
	var filtered: Array = []
	for choice_value in result:
		if not (choice_value is Dictionary):
			continue
		var choice: Dictionary = choice_value
		var choice_id := str(choice.get("id", ""))
		if choice_id == "" or choice_id == "convert_to_gold":
			continue
		if bool(choice.get("is_instant", false)):
			continue
		filtered.append(choice)
	return filtered


func _is_choice_modal_busy(runtime_state: Object) -> bool:
	var snapshot := _get_runtime_snapshot(runtime_state)
	if bool(snapshot.get("choice_active", false)):
		return true
	if runtime_state.has_method("has_pending_unlock_swap") and bool(runtime_state.has_pending_unlock_swap()):
		return true
	if runtime_state.has_method("is_choice_flight_active") and bool(runtime_state.is_choice_flight_active()):
		return true
	return false


func _get_runtime_snapshot(runtime_state: Object) -> Dictionary:
	if runtime_state != null and runtime_state.has_method("get_snapshot"):
		var result: Variant = runtime_state.get_snapshot()
		if result is Dictionary:
			return result
	return {}


func _get_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var raw := str(owner.get("selected_character_type")).strip_edges().to_lower()
	match raw:
		"viper":
			return "viper"
		"soldier", "commando":
			return "soldier"
		_:
			return "smasher"


func _merge_wallet_summary(summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["delta_gold"] = int(wallet_summary.get("delta_gold", summary.get("delta_gold", 0)))
	summary["ap_spent"] = int(wallet_summary.get("ap_spent", summary.get("ap_spent", 0)))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
	summary["reason"] = str(wallet_summary.get("reason", summary.get("reason", "")))
	if bool(wallet_summary.get("changed", false)) and bool(summary.get("choice_opened", false)):
		summary["changed"] = true
	return summary


func _merge_choice_summary(summary: Dictionary, snapshot: Dictionary) -> Dictionary:
	var choices := _get_array(snapshot.get("current_choices", []))
	var choice_ids: Array[String] = []
	for choice_value in choices:
		if choice_value is Dictionary:
			choice_ids.append(str((choice_value as Dictionary).get("id", "")))
	summary["choice_opened"] = bool(snapshot.get("choice_active", false)) and not choices.is_empty()
	summary["pending_skill_choices"] = int(snapshot.get("pending_skill_choices", 0))
	summary["choice_count"] = choices.size()
	summary["choice_ids"] = choice_ids
	return summary


func _build_wallet_summary(delta_gold: int, changed: bool, reason: String) -> Dictionary:
	return {
		"action": "lesson",
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"ap_spent": 0,
	}


func _build_summary(action_id: String, cost: int, changed: bool, reason: String) -> Dictionary:
	return {
		"action": action_id,
		"cost": cost,
		"handled": ["lesson", "exchange"].has(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
		"choice_opened": false,
		"pending_skill_choices": 0,
		"choice_count": 0,
		"choice_ids": [],
	}


func _get_array(value: Variant) -> Array:
	return value if value is Array else []
