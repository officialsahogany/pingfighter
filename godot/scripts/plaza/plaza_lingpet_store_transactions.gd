extends RefCounted

const EGG_COST := 250
static func get_menu_action_labels(_registry: Object = null) -> Array[String]:
	return ["공명 알 뽑기 %dG" % EGG_COST]


func perform_action(
	action_index: int,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if action_index == 0:
		return _buy_resonance_egg(save_store, owner, registry, consume_ap)
	return _build_summary("", 0, false, "unknown_lingpet_store_action")


func _buy_resonance_egg(save_store: Object, owner: Object, registry: Object, consume_ap: bool) -> Dictionary:
	if not _has_plaza_gold(save_store, EGG_COST):
		return _build_summary("buy_egg", EGG_COST, false, "not_enough_gold")
	if _is_ap_blocked(save_store, consume_ap):
		return _build_summary("buy_egg", EGG_COST, false, "no_ap")
	var lingpet_runtime := _get_lingpet_runtime(registry)
	if lingpet_runtime == null or not lingpet_runtime.has_method("spawn_plaza_resonance_egg"):
		return _build_summary("buy_egg", EGG_COST, false, "missing_lingpet_runtime")
	if owner == null:
		return _build_summary("buy_egg", EGG_COST, false, "missing_owner")
	var offer := _get_egg_offer(lingpet_runtime, owner)
	if not bool(offer.get("can_spawn", false)):
		return _merge_runtime_summary(
			_build_summary("buy_egg", EGG_COST, false, str(offer.get("reason", "egg_unavailable"))),
			offer
		)

	var rollback_snapshot := _capture_runtime_snapshot(lingpet_runtime)
	var runtime_summary := _spawn_resonance_egg(lingpet_runtime, owner, registry)
	if not bool(runtime_summary.get("changed", false)):
		return _merge_runtime_summary(
			_build_summary("buy_egg", EGG_COST, false, str(runtime_summary.get("reason", "egg_unavailable"))),
			runtime_summary
		)

	var payment := _perform_egg_payment(save_store, EGG_COST, consume_ap)
	if not bool(payment.get("changed", false)):
		_restore_runtime_snapshot(lingpet_runtime, owner, registry, rollback_snapshot)
		return _merge_wallet_summary(
			_merge_runtime_summary(
				_build_summary("buy_egg", EGG_COST, false, str(payment.get("reason", "payment_failed"))),
				runtime_summary
			),
			payment
		)
	return _merge_wallet_summary(
		_merge_runtime_summary(_build_summary("buy_egg", EGG_COST, true, "ok"), runtime_summary),
		payment
	)


func _get_egg_offer(lingpet_runtime: Object, owner: Object) -> Dictionary:
	if lingpet_runtime != null and lingpet_runtime.has_method("get_plaza_resonance_egg_offer"):
		var result: Variant = lingpet_runtime.get_plaza_resonance_egg_offer(owner)
		if result is Dictionary:
			return result
	return _build_runtime_summary(false, "missing_lingpet_runtime")


func _spawn_resonance_egg(lingpet_runtime: Object, owner: Object, registry: Object) -> Dictionary:
	var result: Variant = lingpet_runtime.spawn_plaza_resonance_egg(owner, registry)
	if result is Dictionary:
		return result
	return _build_runtime_summary(false, "invalid_lingpet_runtime_result")


func _capture_runtime_snapshot(lingpet_runtime: Object) -> Dictionary:
	if lingpet_runtime == null or not lingpet_runtime.has_method("get_save_snapshot"):
		return {}
	var snapshot_value: Variant = lingpet_runtime.get_save_snapshot()
	if snapshot_value is Dictionary:
		return (snapshot_value as Dictionary).duplicate(true)
	return {}


func _restore_runtime_snapshot(lingpet_runtime: Object, owner: Object, registry: Object, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if lingpet_runtime != null and lingpet_runtime.has_method("apply_save_snapshot"):
		lingpet_runtime.apply_save_snapshot(snapshot, owner, registry)


func _has_plaza_gold(save_store: Object, amount: int) -> bool:
	return save_store != null and save_store.has_method("get_plaza_gold") and int(save_store.get_plaza_gold()) >= amount


func _is_ap_blocked(save_store: Object, consume_ap: bool) -> bool:
	return consume_ap and (save_store == null or not save_store.has_method("get_ap_current") or int(save_store.get_ap_current()) <= 0)


func _perform_egg_payment(save_store: Object, cost: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_lingpet_egg_payment"):
		return _build_wallet_summary(0, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_lingpet_egg_payment(cost, consume_ap)
	if result is Dictionary:
		return result
	return _build_wallet_summary(0, false, "invalid_wallet_result")


func _get_lingpet_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("lingpet_egg_runtime")


func _merge_wallet_summary(summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["delta_gold"] = int(wallet_summary.get("delta_gold", summary.get("delta_gold", 0)))
	summary["ap_spent"] = int(wallet_summary.get("ap_spent", summary.get("ap_spent", 0)))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
	summary["reason"] = str(wallet_summary.get("reason", summary.get("reason", "")))
	summary["changed"] = bool(wallet_summary.get("changed", summary.get("changed", false)))
	return summary


func _merge_runtime_summary(summary: Dictionary, runtime_summary: Dictionary) -> Dictionary:
	summary["runtime_summary"] = runtime_summary.duplicate(true)
	summary["hatch_hits"] = int(runtime_summary.get("hatch_hits", summary.get("hatch_hits", 0)))
	summary["required_hits"] = int(runtime_summary.get("required_hits", summary.get("required_hits", 0)))
	summary["lingpet_state"] = str(runtime_summary.get("state", summary.get("lingpet_state", "")))
	summary["reason"] = str(runtime_summary.get("reason", summary.get("reason", "")))
	summary["changed"] = bool(runtime_summary.get("changed", summary.get("changed", false)))
	return summary


func _build_wallet_summary(delta_gold: int, changed: bool, reason: String, action_id: String = "buy_egg") -> Dictionary:
	return {
		"action": action_id,
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"ap_spent": 0,
	}


func _build_runtime_summary(changed: bool, reason: String) -> Dictionary:
	return {
		"handled": true,
		"changed": changed,
		"reason": reason,
		"state": "",
		"hatch_hits": 0,
		"required_hits": 0,
	}


func _build_summary(action_id: String, cost: int, changed: bool, reason: String) -> Dictionary:
	return {
		"action": action_id,
		"cost": cost,
		"handled": action_id == "buy_egg",
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
		"hatch_hits": 0,
		"required_hits": 0,
		"lingpet_state": "",
	}
