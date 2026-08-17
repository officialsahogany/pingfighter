extends "res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"

func get_run_state_snapshot() -> Dictionary:
	return _run_state.export_economy()

func collect_muhon(amount: int, owner: Object = null) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if amount <= 0:
		return {"accepted": false, "reason": "invalid_amount"}
	if not ensure_run_started(owner):
		return {"accepted": false, "reason": "run_unavailable"}
	var apply_result: Dictionary = _run_state.apply_reward_bundle({"muhon": amount})
	return {
		"accepted": true,
		"reason": "collected",
		"amount": amount,
		"balances": apply_result.get("balances", {}),
	}

func ensure_run_started(owner: Object, context: Dictionary = {}) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if _run_state.has_started():
		_sync_owner_chance_gems(owner)
		_guardian_spring_node.sync_owner_projection(owner)
		return true
	var run_id := str(context.get(
		"run_id",
		"tower-run-%d" % Time.get_ticks_msec()
	))
	var economy_variant: Variant = context.get("run_state", {})
	var economy: Dictionary = economy_variant if economy_variant is Dictionary else {}
	if not _run_state.begin(run_id, economy):
		return false
	_sync_owner_chance_gems(owner)
	_guardian_spring_node.sync_owner_projection(owner)
	return true

func get_generated_shop_inventory() -> Array[Dictionary]:
	return _generated_shop_inventory.duplicate(true)

func get_purchase_history() -> Array[Dictionary]:
	return _purchase_history.duplicate(true)

func get_generated_training_offers() -> Array[Dictionary]:
	return _generated_training_offers.duplicate(true)

func get_training_history() -> Array[Dictionary]:
	return _training_history.duplicate(true)

func _build_shop_actions() -> Array[Dictionary]:
	var inventory := _get_or_create_shop_inventory()
	if inventory.is_empty():
		return []
	var balances: Dictionary = _run_state.export_economy()
	var result: Array[Dictionary] = []
	for stock_value in inventory.get("stock", []):
		if not (stock_value is Dictionary):
			continue
		var stock := stock_value as Dictionary
		var sold := bool(stock.get("sold", false))
		var price := maxi(0, int(stock.get("price", 0)))
		var affordable := int(balances.get("gold", 0)) >= price
		var gem_full := (
			str(stock.get("kind", "")) == "chance_gem"
			and int(balances.get("chance_gems", 0)) >= TowerAscentRunState.MAX_CHANCE_GEMS
		)
		var enabled := not sold and affordable and not gem_full
		var unavailable_reason := ""
		if sold:
			unavailable_reason = TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_SOLD_OUT
			)
		elif gem_full:
			unavailable_reason = TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_GEM_FULL
			)
		elif not affordable:
			unavailable_reason = TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_GOLD,
				{
					"required": price,
					"shortfall": price - int(balances.get("gold", 0)),
				}
			)
		result.append({
			"id": "shop_purchase:%s" % str(stock.get("stock_id", "")),
			"label": _shop_stock_label(stock),
			"cost_text": (
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SHOP_SOLD_OUT
				)
				if sold
				else TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_COST_GOLD,
					{"amount": price}
				)
			),
			"enabled": enabled,
			"unavailable_reason": unavailable_reason,
			"payload": {"stock_id": str(stock.get("stock_id", ""))},
		})
	return result

func _shop_stock_label(stock: Dictionary) -> String:
	match str(stock.get("kind", "")):
		"premium":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_PREMIUM_ITEM,
				{"name": str(stock.get("display_name", ""))}
			)
		"capsule":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE
			)
		"chance_gem":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_CHANCE_GEM
			)
	return str(stock.get("display_name", stock.get("item_name", "")))

func _execute_shop_purchase(stock_id: String, requested_resolution_id: String = "") -> Dictionary:
	var stock := _find_shop_stock(stock_id)
	if stock.is_empty():
		return {"accepted": false, "reason": "unknown_shop_stock"}
	if bool(stock.get("sold", false)):
		return {"accepted": false, "reason": "sold_out"}
	var price := maxi(0, int(stock.get("price", 0)))
	var affordability: Dictionary = _run_state.can_afford({"gold": price})
	if not bool(affordability.get("accepted", false)):
		_refresh_shop_modal(str(affordability.get("reason", "insufficient_gold")))
		return affordability
	var stock_kind := str(stock.get("kind", ""))
	if stock_kind == "chance_gem" and _run_state.get_chance_gems() >= TowerAscentRunState.MAX_CHANCE_GEMS:
		var gem_full_result := {
			"accepted": false,
			"reason": "chance_gems_full",
			"message": TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SHOP_GEM_FULL
			),
		}
		_refresh_shop_modal(str(gem_full_result.message))
		return gem_full_result
	var item_name := str(stock.get("item_name", ""))
	var effect_callback := Callable()
	var rollback_callback := Callable()
	var rewards := {}
	if stock_kind == "chance_gem":
		rewards = {"chance_gems": 1}
	else:
		effect_callback = Callable(self, "_grant_shop_active_item").bind(item_name)
		rollback_callback = Callable(self, "_rollback_shop_active_item").bind(item_name)
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(
			_current_node_id,
			"shop_purchase:%s" % stock_id
		)
	var transaction_result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{"gold": price},
		rewards,
		_run_state,
		_resolution_ids,
		effect_callback,
		rollback_callback
	)
	if not bool(transaction_result.get("accepted", false)) or not bool(transaction_result.get("applied", false)):
		var message := (
			TowerAscentNodeModalLocalization.text(TowerAscentNodeModalLocalization.KEY_SHOP_SLOT_FULL)
			if str(transaction_result.get("reason", "")) == "effect_rejected"
			else str(transaction_result.get("reason", "purchase_failed"))
		)
		transaction_result["message"] = message
		_refresh_shop_modal(message)
		return transaction_result
	stock["sold"] = true
	var purchase := {
		"node_id": _current_node_id,
		"node_resolution_id": resolution_id,
		"stock_id": stock_id,
		"kind": stock_kind,
		"item_name": item_name,
		"price": price,
	}
	_purchase_history.append(purchase)
	if stock_kind != "chance_gem":
		var active_items: Array = _build_state.get("active_items", [])
		active_items.append({
			"item_name": item_name,
			"node_resolution_id": resolution_id,
		})
		_build_state["active_items"] = active_items
	_sync_owner_chance_gems(_active_owner)
	var purchased_name := (
		TowerAscentNodeModalLocalization.text(TowerAscentNodeModalLocalization.KEY_SHOP_CHANCE_GEM)
		if stock_kind == "chance_gem"
		else str(stock.get("display_name", item_name))
	)
	var success_message := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SHOP_PURCHASED,
		{"name": purchased_name}
	)
	_refresh_shop_modal(success_message)
	transaction_result["purchase"] = purchase.duplicate(true)
	transaction_result["message"] = success_message
	return transaction_result

func _get_or_create_shop_inventory() -> Dictionary:
	var existing := _get_shop_inventory_entry()
	if not existing.is_empty():
		return existing
	var generated: Dictionary = _shop_inventory_builder.build_inventory(
		_current_node_id,
		_map_seed,
		_active_owner,
		_active_registry
	)
	if not bool(generated.get("accepted", false)):
		return {}
	_generated_shop_inventory.append(generated)
	return _generated_shop_inventory.back()

func _get_shop_inventory_entry() -> Dictionary:
	for inventory in _generated_shop_inventory:
		if str(inventory.get("node_id", "")) == _current_node_id:
			return inventory
	return {}

func _find_shop_stock(stock_id: String) -> Dictionary:
	var inventory := _get_or_create_shop_inventory()
	for stock_value in inventory.get("stock", []):
		if stock_value is Dictionary and str((stock_value as Dictionary).get("stock_id", "")) == stock_id:
			return stock_value as Dictionary
	return {}

func _grant_shop_active_item(item_name: String) -> bool:
	var runtime := _get_registry_instance(_active_registry, "active_item_runtime")
	return (
		runtime != null
		and runtime.has_method("grant_item_to_slot")
		and bool(runtime.call("grant_item_to_slot", item_name, _active_owner, _active_registry, false))
	)

func _rollback_shop_active_item(item_name: String) -> void:
	var runtime := _get_registry_instance(_active_registry, "active_item_runtime")
	if runtime != null and runtime.has_method("debug_remove_item_from_slot"):
		runtime.call("debug_remove_item_from_slot", item_name, _active_owner, _active_registry)

func _refresh_shop_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_shop_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)

func _build_training_actions() -> Array[Dictionary]:
	var offer := _get_or_create_training_offer()
	if offer.is_empty():
		return []
	var balances: Dictionary = _run_state.export_economy()
	var used_count := _get_training_use_count(_current_node_id)
	var visit_complete := used_count >= TowerAscentTuning.TEMP_PHASE_C_TRAINING_USES_PER_VISIT
	var consumed_ids := _get_consumed_training_choice_ids(_current_node_id)
	var result: Array[Dictionary] = []
	for choice_value in offer.get("stat_choices", []):
		if choice_value is Dictionary:
			result.append(_build_training_action(
				"stat",
				choice_value as Dictionary,
				TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST,
				balances,
				visit_complete,
				consumed_ids
			))
	for choice_value in offer.get("mugong_choices", []):
		if choice_value is Dictionary:
			result.append(_build_training_action(
				"mugong",
				choice_value as Dictionary,
				TowerAscentTuning.TEMP_PHASE_C_TRAINING_MUGONG_COST,
				balances,
				visit_complete,
				consumed_ids
			))
	return result

func _build_training_action(
	choice_kind: String,
	choice: Dictionary,
	cost: int,
	balances: Dictionary,
	visit_complete: bool,
	consumed_ids: Dictionary
) -> Dictionary:
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var action_id := "training_%s:%s" % [choice_kind, choice_id]
	var consumed := consumed_ids.has("%s:%s" % [choice_kind, choice_id])
	var affordable := int(balances.get("muhon", 0)) >= cost
	var enabled := not visit_complete and not consumed and affordable
	var unavailable_reason := ""
	if visit_complete:
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_VISIT_COMPLETE
		)
	elif consumed:
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_CHOICE_USED
		)
	elif not affordable:
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": cost - int(balances.get("muhon", 0)),
			}
		)
	var display_name := str(choice.get("name", choice_id))
	var label_key := (
		TowerAscentNodeModalLocalization.KEY_TRAINING_STAT_OPTION
		if choice_kind == "stat"
		else TowerAscentNodeModalLocalization.KEY_TRAINING_MUGONG_OPTION
	)
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(
			label_key,
			{"name": display_name}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_MUHON,
			{"amount": cost}
		),
		"enabled": enabled,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"choice_kind": choice_kind,
			"choice_id": choice_id,
		},
	}

func _execute_training_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var parsed := _parse_training_action_id(action_id)
	if parsed.is_empty():
		return {"accepted": false, "reason": "invalid_training_action"}
	if _get_training_use_count(_current_node_id) >= TowerAscentTuning.TEMP_PHASE_C_TRAINING_USES_PER_VISIT:
		var complete_message := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_VISIT_COMPLETE
		)
		_refresh_training_modal(complete_message)
		return {
			"accepted": false,
			"reason": "training_visit_complete",
			"message": complete_message,
		}
	var choice_kind := str(parsed.get("choice_kind", ""))
	var choice_id := str(parsed.get("choice_id", ""))
	if _get_consumed_training_choice_ids(_current_node_id).has("%s:%s" % [choice_kind, choice_id]):
		return {"accepted": false, "reason": "training_choice_used"}
	var choice := _find_training_choice(choice_kind, choice_id)
	if choice.is_empty():
		return {"accepted": false, "reason": "unknown_training_choice"}
	var cost := (
		TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST
		if choice_kind == "stat"
		else TowerAscentTuning.TEMP_PHASE_C_TRAINING_MUGONG_COST
	)
	var affordability: Dictionary = _run_state.can_afford({"muhon": cost})
	if not bool(affordability.get("accepted", false)):
		var insufficient_message := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": int(affordability.get("shortfall", cost)),
			}
		)
		affordability["message"] = insufficient_message
		_refresh_training_modal(insufficient_message)
		return affordability
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var transaction_result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{"muhon": cost},
		{},
		_run_state,
		_resolution_ids,
		Callable(self, "_grant_training_choice").bind(choice),
		Callable(self, "_rollback_training_choice")
	)
	_pending_runtime_perk_rollback_snapshot.clear()
	if not bool(transaction_result.get("accepted", false)) or not bool(transaction_result.get("applied", false)):
		var failed_message := str(transaction_result.get("reason", "training_failed"))
		transaction_result["message"] = failed_message
		_refresh_training_modal(failed_message)
		return transaction_result
	var display_name := str(choice.get("name", choice_id))
	var record := {
		"node_id": _current_node_id,
		"node_resolution_id": resolution_id,
		"choice_kind": choice_kind,
		"choice_id": choice_id,
		"display_name": display_name,
		"cost": cost,
	}
	_training_history.append(record)
	_capture_runtime_perk_build_state()
	var build_key := "mugong" if choice_kind == "mugong" else "training"
	var build_entries: Array = _build_state.get(build_key, [])
	build_entries.append(record.duplicate(true))
	_build_state[build_key] = build_entries
	var success_message := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_TRAINING_COMPLETED,
		{"name": display_name}
	)
	_refresh_training_modal(success_message)
	transaction_result["training"] = record.duplicate(true)
	transaction_result["message"] = success_message
	return transaction_result

func _get_or_create_training_offer() -> Dictionary:
	var existing := _get_training_offer_entry()
	if not existing.is_empty():
		return existing
	var generated: Dictionary = _training_offer_builder.build_offer(
		_current_node_id,
		_map_seed,
		_active_owner,
		_active_registry
	)
	if not bool(generated.get("accepted", false)):
		return {}
	_generated_training_offers.append(generated)
	return _generated_training_offers.back()

func _get_training_offer_entry() -> Dictionary:
	for offer in _generated_training_offers:
		if str(offer.get("node_id", "")) == _current_node_id:
			return offer
	return {}

func _find_training_choice(choice_kind: String, choice_id: String) -> Dictionary:
	var offer := _get_or_create_training_offer()
	var list_key := "stat_choices" if choice_kind == "stat" else "mugong_choices"
	for choice_value in offer.get(list_key, []):
		if (
			choice_value is Dictionary
			and str((choice_value as Dictionary).get("id", (choice_value as Dictionary).get("perk_id", ""))) == choice_id
		):
			return choice_value as Dictionary
	return {}

func _parse_training_action_id(action_id: String) -> Dictionary:
	for choice_kind in ["stat", "mugong"]:
		var prefix := "training_%s:" % choice_kind
		if action_id.begins_with(prefix):
			var choice_id := action_id.trim_prefix(prefix).strip_edges()
			if not choice_id.is_empty():
				return {"choice_kind": choice_kind, "choice_id": choice_id}
	return {}

func _get_training_use_count(node_id: String) -> int:
	var count := 0
	for record in _training_history:
		if str(record.get("node_id", "")) == node_id:
			count += 1
	return count

func _get_consumed_training_choice_ids(node_id: String) -> Dictionary:
	var result := {}
	for record in _training_history:
		if str(record.get("node_id", "")) != node_id:
			continue
		result["%s:%s" % [
			str(record.get("choice_kind", "")),
			str(record.get("choice_id", "")),
		]] = true
	return result

func _grant_training_choice(choice: Dictionary) -> bool:
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("apply_choice"):
		return false
	_pending_runtime_perk_rollback_snapshot.clear()
	if runtime_state.has_method("build_unlock_save_snapshot"):
		var snapshot_value: Variant = runtime_state.call("build_unlock_save_snapshot")
		if snapshot_value is Dictionary:
			_pending_runtime_perk_rollback_snapshot = (snapshot_value as Dictionary).duplicate(true)
	return bool(runtime_state.call("apply_choice", choice, _active_owner, _active_registry))

func _rollback_training_choice() -> void:
	if _pending_runtime_perk_rollback_snapshot.is_empty():
		return
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("apply_unlock_save_snapshot"):
		runtime_state.call(
			"apply_unlock_save_snapshot",
			_pending_runtime_perk_rollback_snapshot,
			_active_owner,
			_active_registry
		)

func _capture_runtime_perk_build_state() -> void:
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("build_unlock_save_snapshot"):
		return
	var snapshot_value: Variant = runtime_state.call("build_unlock_save_snapshot")
	if snapshot_value is Dictionary:
		_build_state["runtime_perk_snapshot"] = (snapshot_value as Dictionary).duplicate(true)

func _restore_runtime_perk_build_state(owner: Object, registry: Object) -> bool:
	var snapshot_value: Variant = _build_state.get("runtime_perk_snapshot", {})
	if not (snapshot_value is Dictionary) or (snapshot_value as Dictionary).is_empty():
		return true
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("apply_unlock_save_snapshot"):
		return false
	var result_value: Variant = runtime_state.call(
		"apply_unlock_save_snapshot",
		snapshot_value as Dictionary,
		owner,
		registry
	)
	return result_value is Dictionary and bool((result_value as Dictionary).get("restored", false))

func _refresh_training_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_training_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)
