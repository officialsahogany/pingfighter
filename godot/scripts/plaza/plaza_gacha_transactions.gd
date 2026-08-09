extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LingpetItemOfferPolicy := preload("res://scripts/lingpet/lingpet_item_offer_policy.gd")

const PULL_COST := 150
const EXTRA_GACHA_ACTIVE_ITEM_NAMES: Array[String] = []

var _catalog: Object = ActiveItemCatalog.new()
var _rng := RandomNumberGenerator.new()
var _forced_item_for_test := ""


func _init() -> void:
	_rng.randomize()


static func get_menu_action_labels() -> Array[String]:
	return ["액티브 캡슐 뽑기 %dG" % PULL_COST]


func force_next_item_for_test(item_name: String) -> void:
	_forced_item_for_test = item_name.strip_edges()


func perform_action(
	action_index: int,
	save_store: Object,
	owner: Object,
	registry: Object,
	consume_ap: bool
) -> Dictionary:
	if action_index != 0:
		return _build_summary("", "", "", 0, false, "unknown_gacha_action")
	return _pull_active_capsule(save_store, owner, registry, consume_ap)


func _pull_active_capsule(save_store: Object, owner: Object, registry: Object, consume_ap: bool) -> Dictionary:
	if not _has_plaza_gold(save_store, PULL_COST):
		return _build_summary("pull", "", "", PULL_COST, false, "not_enough_gold")
	if _is_ap_blocked(save_store, consume_ap):
		return _build_summary("pull", "", "", PULL_COST, false, "no_ap")
	var active_item_runtime := _get_active_item_runtime(registry)
	if active_item_runtime == null or not active_item_runtime.has_method("grant_item_to_slot"):
		return _build_summary("pull", "", "", PULL_COST, false, "missing_item_runtime")
	if owner == null:
		return _build_summary("pull", "", "", PULL_COST, false, "missing_owner")

	var pulled_item := _pick_active_item(owner, registry)
	var item_name := str(pulled_item.get("name", ""))
	var display_name := str(pulled_item.get("display_name", item_name))
	if item_name == "":
		return _build_summary("pull", "", "", PULL_COST, false, "empty_gacha_pool")
	if not bool(active_item_runtime.grant_item_to_slot(item_name, owner, registry, false)):
		return _build_summary("pull", item_name, display_name, PULL_COST, false, "active_slots_full")

	var payment := _perform_gacha_payment(save_store, PULL_COST, consume_ap)
	if not bool(payment.get("changed", false)):
		_rollback_granted_item(active_item_runtime, item_name, owner, registry)
		return _merge_wallet_summary(
			_build_summary("pull", item_name, display_name, PULL_COST, false, str(payment.get("reason", "payment_failed"))),
			payment
		)
	return _merge_wallet_summary(
		_build_summary("pull", item_name, display_name, PULL_COST, true, "ok"),
		payment
	)


# owner / registry are required for the offer-policy filter. Without it the capsule
# can roll a Guardian Spirit item the player has no access to; the grant then fails
# at the slot controller and the pull is reported as "active_slots_full" — a wrong
# reason for a pull that should never have rolled that item. Filter at CANDIDATE
# time so the failure reasons downstream stay truthful.
func _pick_active_item(owner: Object = null, registry: Object = null) -> Dictionary:
	if _forced_item_for_test != "":
		var forced_item: Dictionary = _catalog.build_item_by_name(_forced_item_for_test)
		_forced_item_for_test = ""
		if _is_offerable_gacha_item(forced_item, owner, registry):
			return forced_item
	var candidates: Array[Dictionary] = []
	for item_name_value in _get_gacha_item_names():
		var item_name := str(item_name_value)
		var candidate: Dictionary = _catalog.build_item_by_name(item_name)
		if _is_offerable_gacha_item(candidate, owner, registry):
			candidates.append(candidate)
	if candidates.is_empty():
		return {}

	var total_weight := 0.0
	for candidate in candidates:
		total_weight += max(0.0, float(candidate.get("chance", 0.0)))
	var roll: float = _rng.randf() * max(0.001, total_weight)
	for candidate in candidates:
		roll -= max(0.0, float(candidate.get("chance", 0.0)))
		if roll <= 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func _get_gacha_item_names() -> Array:
	var result: Array = ActiveItemCatalog.FIELD_SPAWN_ORDER.duplicate()
	for item_name in EXTRA_GACHA_ACTIVE_ITEM_NAMES:
		if not result.has(item_name):
			result.append(item_name)
	return result


func _is_valid_gacha_item(item_data: Dictionary) -> bool:
	return (
		not item_data.is_empty()
		and str(item_data.get("name", "")) != ""
		and str(item_data.get("type", "")) == "active"
	)


func _is_offerable_gacha_item(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	if not _is_valid_gacha_item(item_data):
		return false
	return LingpetItemOfferPolicy.can_offer_item(str(item_data.get("name", "")), owner, registry)


func _has_plaza_gold(save_store: Object, amount: int) -> bool:
	return save_store != null and save_store.has_method("get_plaza_gold") and int(save_store.get_plaza_gold()) >= amount


func _is_ap_blocked(save_store: Object, consume_ap: bool) -> bool:
	return consume_ap and (save_store == null or not save_store.has_method("get_ap_current") or int(save_store.get_ap_current()) <= 0)


func _perform_gacha_payment(save_store: Object, cost: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_gacha_pull_payment"):
		return _build_wallet_summary(0, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_gacha_pull_payment(cost, consume_ap)
	if result is Dictionary:
		return result
	return _build_wallet_summary(0, false, "invalid_wallet_result")


func _get_active_item_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("active_item_runtime")


func _rollback_granted_item(active_item_runtime: Object, item_name: String, owner: Object, registry: Object) -> void:
	if active_item_runtime != null and active_item_runtime.has_method("debug_remove_item_from_slot"):
		active_item_runtime.debug_remove_item_from_slot(item_name, owner, registry)


func _merge_wallet_summary(summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["delta_gold"] = int(wallet_summary.get("delta_gold", summary.get("delta_gold", 0)))
	summary["ap_spent"] = int(wallet_summary.get("ap_spent", summary.get("ap_spent", 0)))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
	summary["reason"] = str(wallet_summary.get("reason", summary.get("reason", "")))
	summary["changed"] = bool(wallet_summary.get("changed", summary.get("changed", false)))
	return summary


func _build_wallet_summary(delta_gold: int, changed: bool, reason: String) -> Dictionary:
	return {
		"action": "pull",
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"ap_spent": 0,
	}


func _build_summary(
	action_id: String,
	item_name: String,
	display_name: String,
	cost: int,
	changed: bool,
	reason: String
) -> Dictionary:
	return {
		"action": action_id,
		"item_name": item_name,
		"display_name": display_name,
		"cost": cost,
		"handled": action_id == "pull",
		"changed": changed,
		"reason": reason,
		"delta_gold": 0,
		"ap_spent": 0,
	}
