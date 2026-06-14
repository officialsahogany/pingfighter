extends RefCounted

const EGG_COST := 250
const RING_CORE_TIER_COSTS := {
	1: 150,
	2: 300,
	3: 600,
	4: 1000,
	5: 1500,
	6: 2200,
}
const RING_CORE_TIER_NAMES := [
	"",
	"스탠다드",
	"부스트",
	"하이퍼",
	"오버드라이브",
	"얼티밋",
	"제니스",
]


static func get_menu_action_labels(registry: Object = null) -> Array[String]:
	return ["공명 알 뽑기 %dG" % EGG_COST, _build_ring_core_action_label(registry)]


static func get_ring_core_upgrade_offer(registry: Object) -> Dictionary:
	var affinity_store := _get_affinity_store(registry)
	if affinity_store == null:
		return _build_ring_core_offer(0, 0, 0, false, "missing_affinity_store")
	var current_tier := _get_ring_core_tier(affinity_store)
	var max_tier := _get_max_ring_core_tier(affinity_store)
	if current_tier >= max_tier:
		return _build_ring_core_offer(current_tier, 0, 0, false, "max_ring_core_tier")
	var next_tier := clampi(current_tier + 1, 1, max_tier)
	var cost := get_ring_core_tier_cost(next_tier)
	if cost <= 0:
		return _build_ring_core_offer(current_tier, next_tier, 0, false, "missing_ring_core_price")
	return _build_ring_core_offer(current_tier, next_tier, cost, true, "ok")


static func get_ring_core_tier_cost(tier: int) -> int:
	return maxi(0, int(RING_CORE_TIER_COSTS.get(clampi(tier, 0, RING_CORE_TIER_NAMES.size() - 1), 0)))


static func get_ring_core_tier_name(tier: int) -> String:
	var clamped_tier := clampi(tier, 0, RING_CORE_TIER_NAMES.size() - 1)
	return str(RING_CORE_TIER_NAMES[clamped_tier])


func perform_action(
	action_index: int,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if action_index == 0:
		return _buy_resonance_egg(save_store, owner, registry, consume_ap)
	if action_index == 1:
		return _buy_ring_core_upgrade(save_store, registry, consume_ap)
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


func _buy_ring_core_upgrade(save_store: Object, registry: Object, consume_ap: bool) -> Dictionary:
	var offer := get_ring_core_upgrade_offer(registry)
	var cost := int(offer.get("cost", 0))
	var next_tier := int(offer.get("next_tier", 0))
	if not bool(offer.get("can_upgrade", false)):
		return _merge_ring_core_offer(
			_build_summary("ring_core", cost, false, str(offer.get("reason", "ring_core_unavailable"))),
			offer
		)
	if not _has_plaza_gold(save_store, cost):
		return _merge_ring_core_offer(_build_summary("ring_core", cost, false, "not_enough_gold"), offer)
	if _is_ap_blocked(save_store, consume_ap):
		return _merge_ring_core_offer(_build_summary("ring_core", cost, false, "no_ap"), offer)

	var payment := _perform_ring_core_payment(save_store, cost, consume_ap)
	if not bool(payment.get("changed", false)):
		return _merge_wallet_summary(
			_merge_ring_core_offer(
				_build_summary("ring_core", cost, false, str(payment.get("reason", "payment_failed"))),
				offer
			),
			payment
		)

	var affinity_store := _get_affinity_store(registry)
	if affinity_store == null or not affinity_store.has_method("upgrade_ring_core_tier"):
		var refund := _refund_ring_core_payment(save_store, cost, int(payment.get("ap_spent", 0)))
		return _merge_refund_summary(
			_merge_ring_core_offer(_build_summary("ring_core", cost, false, "missing_affinity_store"), offer),
			payment,
			refund
		)
	if not bool(affinity_store.upgrade_ring_core_tier(next_tier)):
		var refund := _refund_ring_core_payment(save_store, cost, int(payment.get("ap_spent", 0)))
		return _merge_refund_summary(
			_merge_ring_core_offer(_build_summary("ring_core", cost, false, "ring_core_upgrade_failed"), offer),
			payment,
			refund
		)

	offer["new_tier"] = next_tier
	offer["new_cap"] = _get_ring_core_cap_for_tier(affinity_store, next_tier)
	return _merge_wallet_summary(
		_merge_ring_core_offer(_build_summary("ring_core", cost, true, "ok"), offer),
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


func _perform_ring_core_payment(save_store: Object, cost: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_lingpet_ring_core_payment"):
		return _build_wallet_summary(0, false, "missing_plaza_save_store", "ring_core")
	var result: Variant = save_store.perform_lingpet_ring_core_payment(cost, consume_ap)
	if result is Dictionary:
		return result
	return _build_wallet_summary(0, false, "invalid_wallet_result", "ring_core")


func _refund_ring_core_payment(save_store: Object, cost: int, ap_spent: int) -> Dictionary:
	if save_store == null or not save_store.has_method("refund_lingpet_ring_core_payment"):
		return _build_wallet_summary(0, false, "missing_plaza_save_store", "ring_core")
	var result: Variant = save_store.refund_lingpet_ring_core_payment(cost, ap_spent)
	if result is Dictionary:
		return result
	return _build_wallet_summary(0, false, "invalid_wallet_result", "ring_core")


func _get_lingpet_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("lingpet_egg_runtime")


static func _get_affinity_store(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("lingpet_affinity_store")


static func _get_ring_core_tier(affinity_store: Object) -> int:
	if affinity_store == null or not affinity_store.has_method("get_ring_core_tier"):
		return 0
	return clampi(int(affinity_store.get_ring_core_tier()), 0, RING_CORE_TIER_NAMES.size() - 1)


static func _get_max_ring_core_tier(affinity_store: Object) -> int:
	if affinity_store != null:
		var value: Variant = affinity_store.get("MAX_RING_CORE_TIER")
		if value != null:
			return clampi(int(value), 1, RING_CORE_TIER_NAMES.size() - 1)
	return RING_CORE_TIER_NAMES.size() - 1


static func _get_ring_core_cap_for_tier(affinity_store: Object, tier: int) -> int:
	if affinity_store != null and affinity_store.has_method("get_ring_core_cap_for_tier"):
		return int(affinity_store.get_ring_core_cap_for_tier(tier))
	return clampi(tier * 5, 0, 30)


static func _build_ring_core_action_label(registry: Object) -> String:
	var offer := get_ring_core_upgrade_offer(registry)
	if bool(offer.get("can_upgrade", false)):
		return "%s 링코어 강화 %dG" % [
			str(offer.get("next_tier_name", "링코어")),
			int(offer.get("cost", 0)),
		]
	match str(offer.get("reason", "")):
		"max_ring_core_tier":
			return "링코어 최대 단계"
		"missing_affinity_store":
			return "링코어 강화 준비 중"
		_:
			return "링코어 강화"


static func _build_ring_core_offer(
	current_tier: int,
	next_tier: int,
	cost: int,
	can_upgrade: bool,
	reason: String
) -> Dictionary:
	var next_tier_name := get_ring_core_tier_name(next_tier)
	return {
		"can_upgrade": can_upgrade,
		"reason": reason,
		"current_tier": current_tier,
		"next_tier": next_tier,
		"new_tier": next_tier if can_upgrade else current_tier,
		"cost": cost,
		"next_tier_name": next_tier_name,
		"ring_core_name": next_tier_name,
		"next_cap": clampi(next_tier * 5, 0, 30),
		"new_cap": clampi(next_tier * 5, 0, 30) if can_upgrade else clampi(current_tier * 5, 0, 30),
	}


func _merge_wallet_summary(summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["delta_gold"] = int(wallet_summary.get("delta_gold", summary.get("delta_gold", 0)))
	summary["ap_spent"] = int(wallet_summary.get("ap_spent", summary.get("ap_spent", 0)))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
	summary["reason"] = str(wallet_summary.get("reason", summary.get("reason", "")))
	summary["changed"] = bool(wallet_summary.get("changed", summary.get("changed", false)))
	return summary


func _merge_ring_core_offer(summary: Dictionary, offer: Dictionary) -> Dictionary:
	summary["current_tier"] = int(offer.get("current_tier", summary.get("current_tier", 0)))
	summary["next_tier"] = int(offer.get("next_tier", summary.get("next_tier", 0)))
	summary["new_tier"] = int(offer.get("new_tier", summary.get("new_tier", summary.get("next_tier", 0))))
	summary["next_cap"] = int(offer.get("next_cap", summary.get("next_cap", 0)))
	summary["new_cap"] = int(offer.get("new_cap", summary.get("new_cap", summary.get("next_cap", 0))))
	summary["ring_core_name"] = str(offer.get("ring_core_name", summary.get("ring_core_name", "")))
	summary["next_tier_name"] = str(offer.get("next_tier_name", summary.get("next_tier_name", "")))
	return summary


func _merge_refund_summary(summary: Dictionary, payment: Dictionary, refund: Dictionary) -> Dictionary:
	var wallet_summary := refund if bool(refund.get("changed", false)) else payment
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["payment_summary"] = payment.duplicate(true)
	summary["refund_summary"] = refund.duplicate(true)
	summary["delta_gold"] = 0 if bool(refund.get("changed", false)) else int(payment.get("delta_gold", 0))
	summary["ap_spent"] = 0 if bool(refund.get("changed", false)) else int(payment.get("ap_spent", 0))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
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
		"handled": ["buy_egg", "ring_core"].has(action_id),
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
		"hatch_hits": 0,
		"required_hits": 0,
		"lingpet_state": "",
	}
