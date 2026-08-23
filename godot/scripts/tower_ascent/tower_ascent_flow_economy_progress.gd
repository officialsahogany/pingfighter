extends "res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"

const TowerTrainingTimingJudgmentPolicy := preload(
	"res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

func get_run_state_snapshot() -> Dictionary:
	return _run_state.export_economy()


func collect_gold(amount: int) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if amount <= 0:
		return {"accepted": false, "reason": "invalid_amount"}
	# Battle gold must join an already-started run. Unlike the stage-entry Muhon
	# prewarm path below, an award must never create Tower state in a normal
	# campaign merely because the flow module is cached.
	if not _run_state.has_started():
		return {"accepted": false, "reason": "run_unavailable"}
	var apply_result: Dictionary = _run_state.apply_reward_bundle({"gold": amount})
	return {
		"accepted": true,
		"reason": "collected",
		"amount": amount,
		"balances": apply_result.get("balances", {}),
	}


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

func prewarm_muhon_collection(owner: Object = null) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var already_started: bool = bool(_run_state.has_started())
	var accepted: bool = ensure_run_started(owner)
	return {
		"accepted": accepted,
		"already_started": already_started,
		"elapsed_usec": maxi(0, Time.get_ticks_usec() - started_usec),
		"run_id": _run_state.get_run_id() if accepted else "",
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


func get_reward_pick_history() -> Array[Dictionary]:
	return _reward_pick_history.duplicate(true)


func apply_reward_pick_purchase(
	slot_index: int,
	choice: Dictionary,
	cost: int,
	effect_callback: Callable,
	rollback_callback: Callable = Callable()
) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or not _prepared:
		return {"accepted": false, "applied": false, "reason": "reward_pick_unprepared"}
	if slot_index < 0 or slot_index >= 4:
		return {"accepted": false, "applied": false, "reason": "invalid_reward_pick_slot"}
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	if choice_id.is_empty():
		return {"accepted": false, "applied": false, "reason": "invalid_reward_pick_choice"}
	var resolution_id := "%s:reward_pick:slot_%d" % [_prepared_resolution_id, slot_index]
	var result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{"muhon": maxi(0, cost)},
		{},
		_run_state,
		_resolution_ids,
		effect_callback,
		rollback_callback
	)
	if bool(result.get("accepted", false)) and bool(result.get("applied", false)):
		var record := {
			"node_id": _current_node_id,
			"node_resolution_id": resolution_id,
			"slot_index": slot_index,
			"choice_id": choice_id,
			"choice_kind": str(choice.get("reward_pick_kind", "")),
			"cost": maxi(0, cost),
		}
		_reward_pick_history.append(record)
		result["record"] = record.duplicate(true)
	return result


func finalize_reward_pick(vision_boss_slot_id: String = "") -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or not _prepared:
		return {"accepted": false, "applied": false, "reason": "reward_pick_unprepared"}
	var resolution_id := "%s:reward_pick:continue" % _prepared_resolution_id
	var effect_callback := Callable()
	if not vision_boss_slot_id.strip_edges().is_empty():
		effect_callback = Callable(self, "_commit_reward_pick_vision_burn").bind(
			vision_boss_slot_id
		)
	var result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{},
		{},
		_run_state,
		_resolution_ids,
		effect_callback
	)
	if bool(result.get("accepted", false)) and bool(result.get("applied", false)):
		_reward_pick_history.append({
			"node_id": _current_node_id,
			"node_resolution_id": resolution_id,
			"choice_kind": "continue",
			"vision_boss_slot_id": vision_boss_slot_id.strip_edges(),
		})
	return result


func mark_reward_pick_vision_burned(boss_slot_id: String) -> bool:
	var normalized := boss_slot_id.strip_edges()
	if normalized.is_empty():
		return false
	if _run_state.get_burned_vision_boss_ids().has(normalized):
		return true
	return _run_state.mark_vision_boss_burned(normalized)


func _commit_reward_pick_vision_burn(boss_slot_id: String) -> bool:
	return mark_reward_pick_vision_burned(boss_slot_id)

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
			"payload": {
				"stock_id": str(stock.get("stock_id", "")),
				"choice": _shop_card_choice(stock),
				"presentation": {
					"current": TowerAscentNodeModalLocalization.text(
						TowerAscentNodeModalLocalization.KEY_STATE_OWNED
						if sold
						else TowerAscentNodeModalLocalization.KEY_STATE_LISTED
					),
					"result": TowerAscentNodeModalLocalization.text(
						TowerAscentNodeModalLocalization.KEY_STATE_OWNED
					),
					"target": _shop_stock_label(stock),
				},
			},
		})
	return result


func _shop_card_choice(stock: Dictionary) -> Dictionary:
	var stock_kind := str(stock.get("kind", ""))
	var rarity := str(stock.get("rarity", "common"))
	var choice := {
		"id": str(stock.get("item_name", stock.get("stock_id", ""))),
		"name": _shop_stock_label(stock),
		"description": str(stock.get("description", "")),
		"rarity": rarity,
		"is_unique": stock_kind == "premium",
		"tree": "item",
		"icon_color": stock.get("color", Color(0.78, 0.78, 0.78)),
		"card_content_kind": "active_item",
		"level_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_ACTIVE_RANK,
			{"rarity": _shop_rarity_label(rarity)}
		),
		"item_data": {
			"name": str(stock.get("item_name", "")),
			"display_name": str(stock.get("display_name", "")),
			"icon_path": str(stock.get("icon_path", "")),
			"icon_sheet_path": str(stock.get("icon_sheet_path", "")),
			"icon_frame_count": maxi(1, int(stock.get("icon_frame_count", 1))),
			"color": stock.get("color", Color(0.78, 0.78, 0.78)),
		},
	}
	if stock_kind == "capsule":
		choice["description"] = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE_DESCRIPTION
		)
		choice["card_content_kind"] = "capsule"
		choice["level_text"] = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE_RANK
		)
		choice["item_data"] = {}
	elif stock_kind == "chance_gem":
		choice["description"] = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_CHANCE_GEM_DESCRIPTION
		)
		choice["card_content_kind"] = "chance_gem"
		choice["level_text"] = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_RUN_SUPPLY_RANK
		)
		choice["item_data"] = {}
		choice["icon_color"] = Color(0.33, 0.72, 1.0)
	return choice


func _shop_rarity_label(rarity: String) -> String:
	match rarity:
		"mythic":
			return "신화"
		"legendary":
			return "전설"
		"rare":
			return "희귀"
	return "일반"

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
	var result: Array[Dictionary] = []
	for choice_value in offer.get("stat_choices", []):
		if choice_value is Dictionary:
			result.append(_build_training_action(
				"stat",
				choice_value as Dictionary,
				TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST,
				balances
			))
	return result

func _build_training_action(
	choice_kind: String,
	choice: Dictionary,
	cost: int,
	balances: Dictionary
) -> Dictionary:
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	var live_choice: Dictionary = _training_offer_builder.build_live_choice_projection(
		choice_kind,
		choice,
		runtime_state
	)
	var choice_id := str(live_choice.get(
		"id",
		live_choice.get("perk_id", "")
	)).strip_edges()
	var action_id := "training_%s:%s" % [choice_kind, choice_id]
	var affordable := int(balances.get("muhon", 0)) >= cost
	var at_maximum: bool = bool(_training_offer_builder.is_live_choice_at_maximum(
		choice_kind,
		live_choice,
		runtime_state,
		_active_registry
	))
	var enabled: bool = not at_maximum and affordable
	live_choice["training_timing_luck_percent"] = (
		TowerTrainingTimingJudgmentPolicy.BASE_LUCK_PERCENT
	)
	if choice_id == TowerTrainingTimingJudgmentPolicy.STORAGE_TRAINING_ID:
		# Storage is the one structural exception: timing quality never changes
		# its fixed +1-slot result, so the card keeps this anti-confusion badge.
		live_choice["bonus_badge_text"] = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_STORAGE_BADGE
		)
	var unavailable_reason := ""
	var disabled_reason := ""
	if at_maximum:
		disabled_reason = "training_maximum_reached"
		unavailable_reason = _training_maximum_message(live_choice)
	elif not affordable:
		disabled_reason = "insufficient_muhon"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": cost - int(balances.get("muhon", 0)),
			}
		)
	var display_name := str(live_choice.get("name", choice_id))
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_STAT_OPTION,
			{"name": display_name}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_MUHON,
			{"amount": cost}
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"choice_kind": choice_kind,
			"choice_id": choice_id,
			"choice": live_choice,
			"presentation": {
				"target": display_name,
			},
		},
	}

func _begin_training_timing_action(
	action: Dictionary,
	requested_resolution_id: String = ""
) -> Dictionary:
	var action_id := str(action.get("id", "")).strip_edges()
	var prepared := _prepare_training_timing_action(action_id, requested_resolution_id)
	if not bool(prepared.get("prepared", false)):
		return prepared
	var roll_index := _training_timing_roll_count
	var target_roll := TowerTrainingTimingJudgmentPolicy.roll_target(
		_map_seed,
		_current_node_id,
		action_id,
		roll_index,
		float(prepared.get(
			"luck_percent",
			TowerTrainingTimingJudgmentPolicy.BASE_LUCK_PERCENT
		))
	)
	# Exactly one authoritative target sample belongs to one valid card
	# press/release. Presentation frames and presentation RNG never enter here.
	_training_timing_roll_count += int(target_roll.get("roll_count", 0))
	var pending := prepared.duplicate(true)
	pending["action"] = action.duplicate(true)
	pending["target_roll"] = target_roll.duplicate(true)
	pending["gameplay_rng_state_before"] = _gameplay_rng_state.duplicate(true)
	if not _node_modal_state.begin_training_timing(pending, target_roll):
		_training_timing_roll_count = roll_index
		return {
			"accepted": false,
			"prepared": false,
			"reason": "training_timing_presentation_unavailable",
		}
	_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_PROMPT
	))
	return {
		"accepted": true,
		"prepared": true,
		"action_id": action_id,
		"node_resolution_id": str(prepared.get("node_resolution_id", "")),
		"target_roll_count": int(target_roll.get("roll_count", 0)),
		"target_position": float(target_roll.get("target_position", 0.5)),
		"training_timing_roll_count": _training_timing_roll_count,
	}


func _prepare_training_timing_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var parsed := _parse_training_action_id(action_id)
	if parsed.is_empty():
		return {
			"accepted": false,
			"prepared": false,
			"reason": "invalid_training_action",
		}
	var choice_kind := str(parsed.get("choice_kind", ""))
	var choice_id := str(parsed.get("choice_id", ""))
	var choice := _find_training_choice(choice_kind, choice_id)
	if choice.is_empty():
		return {
			"accepted": false,
			"prepared": false,
			"reason": "unknown_training_choice",
		}
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	var live_choice: Dictionary = _training_offer_builder.build_live_choice_projection(
		choice_kind,
		choice,
		runtime_state
	)
	if _training_offer_builder.is_live_choice_at_maximum(
		choice_kind,
		live_choice,
		runtime_state,
		_active_registry
	):
		var maximum_message := _training_maximum_message(live_choice)
		_refresh_training_modal(maximum_message)
		return {
			"accepted": false,
			"prepared": false,
			"reason": "training_maximum_reached",
			"message": maximum_message,
		}
	var cost := TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST
	var affordability: Dictionary = _run_state.can_afford({"muhon": cost})
	if not bool(affordability.get("accepted", false)):
		var insufficient_message := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": int(affordability.get("shortfall", cost)),
			}
		)
		affordability["prepared"] = false
		affordability["message"] = insufficient_message
		_refresh_training_modal(insufficient_message)
		return affordability
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(
			_current_node_id,
			"%s:%d" % [action_id, _training_history.size()]
		)
	if _resolution_ids.has(resolution_id):
		return {
			"accepted": true,
			"prepared": false,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": resolution_id,
		}
	return {
		"accepted": true,
		"prepared": true,
		"action_id": action_id,
		"choice_kind": choice_kind,
		"choice_id": choice_id,
		"node_resolution_id": resolution_id,
		"cost": cost,
		"luck_percent": float(live_choice.get(
			"training_timing_luck_percent",
			TowerTrainingTimingJudgmentPolicy.BASE_LUCK_PERCENT
		)),
	}


func _execute_training_action(
	action_id: String,
	requested_resolution_id: String = "",
	judgment_result: Dictionary = {}
) -> Dictionary:
	var parsed := _parse_training_action_id(action_id)
	if parsed.is_empty():
		return {"accepted": false, "reason": "invalid_training_action"}
	var choice_kind := str(parsed.get("choice_kind", ""))
	var choice_id := str(parsed.get("choice_id", ""))
	var choice := _find_training_choice(choice_kind, choice_id)
	if choice.is_empty():
		return {"accepted": false, "reason": "unknown_training_choice"}
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	var live_choice: Dictionary = _training_offer_builder.build_live_choice_projection(
		choice_kind,
		choice,
		runtime_state
	)
	if _training_offer_builder.is_live_choice_at_maximum(
		choice_kind,
		live_choice,
		runtime_state,
		_active_registry
	):
		var maximum_message := _training_maximum_message(live_choice)
		_refresh_training_modal(maximum_message)
		return {
			"accepted": false,
			"reason": "training_maximum_reached",
			"message": maximum_message,
		}
	var cost := TowerAscentTuning.TEMP_PHASE_C_TRAINING_STAT_COST
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
		resolution_id = _make_resolution_id(
			_current_node_id,
			"%s:%d" % [action_id, _training_history.size()]
		)
	var effect_receipt: Dictionary = {}
	var transaction_result: Dictionary = _node_action_transaction.apply_once(
		resolution_id,
		{"muhon": cost},
		{},
		_run_state,
		_resolution_ids,
		Callable(self, "_grant_training_choice").bind(
			live_choice,
			effect_receipt,
			judgment_result
		),
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
		# Compatibility fields remain inert so old snapshots do not infer a
		# stackable random bonus after the timing game replaced it.
		"lucky_triggered": false,
		"lucky_roll_count": 0,
		"timing_judgment_kind": str(effect_receipt.get(
			"judgment_kind",
			TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
		)),
		"timing_target_roll_count": int(judgment_result.get(
			"target_roll_count",
			0
		)),
		"effect_multiplier": float(effect_receipt.get("effect_multiplier", 1.0)),
	}
	_training_history.append(record)
	_capture_runtime_perk_build_state()
	var build_entries: Array = _build_state.get("training", [])
	build_entries.append(record.duplicate(true))
	_build_state["training"] = build_entries
	var success_message := _build_training_receipt_message(live_choice, effect_receipt)
	# The authoritative training commit has already crossed into runtime state.
	# Refresh the canonical character-info row projection now so the very next
	# draw frame shows the applied value instead of a one-frame stale receipt.
	_prepare_training_stats_panel()
	# The stat and balance commit is immediate, but the confirmed result copy is
	# owned by the staged strike and must not appear before the dummy reaction.
	_refresh_training_modal("")
	transaction_result["training"] = record.duplicate(true)
	transaction_result["message"] = success_message
	return transaction_result

func _resolve_training_timing() -> Dictionary:
	var stopped: Dictionary = _node_modal_state.stop_training_timing()
	if not bool(stopped.get("accepted", false)):
		return stopped
	var pending_value: Variant = stopped.get("pending_action", {})
	var pending: Dictionary = (
		pending_value as Dictionary if pending_value is Dictionary else {}
	)
	var action_value: Variant = pending.get("action", {})
	var action: Dictionary = (
		action_value as Dictionary if action_value is Dictionary else {}
	)
	var action_id := str(pending.get("action_id", action.get("id", "")))
	var resolution_id := str(pending.get("node_resolution_id", ""))
	var result := _execute_training_action(action_id, resolution_id, stopped)
	result["timing_target_roll_count"] = int(stopped.get("target_roll_count", 0))
	result["timing_judgment_kind"] = str(stopped.get(
		"judgment_kind",
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
	))
	result["gameplay_rng_unchanged"] = (
		_dictionary_copy(pending.get("gameplay_rng_state_before", {}))
		== _gameplay_rng_state
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		if not action.is_empty():
			_node_modal_state.record_action_feedback(action, result)
		_node_modal_state.cancel_training_timing()
		return result
	var message := str(result.get("message", ""))
	if not action.is_empty():
		var silent_feedback := result.duplicate(true)
		silent_feedback["message"] = ""
		_node_modal_state.record_action_feedback(action, silent_feedback)
	if not _node_modal_state.begin_training_strike(
		str(result.get("timing_judgment_kind", "")),
		message
	):
		# The authoritative result is already committed, so a presentation failure
		# may only clean up the retained timing state; it must never roll back stats.
		_node_modal_state.cancel_training_timing()
		_node_modal_state.set_status_text(message)
	return result


func _cancel_training_timing() -> Dictionary:
	var result: Dictionary = _node_modal_state.cancel_training_timing()
	if bool(result.get("accepted", false)):
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_CANCELLED
		))
	return result


func _get_or_create_training_offer() -> Dictionary:
	var existing := _get_training_offer_entry()
	if not existing.is_empty():
		return existing
	var generated: Dictionary = _training_offer_builder.build_offer(
		_current_node_id,
		_map_seed,
		_active_owner,
		_active_registry,
		TowerAscentTrainingOfferBuilder.OFFER_KIND_TRAINING
	)
	if not bool(generated.get("accepted", false)):
		return {}
	_generated_training_offers.append(generated)
	return _generated_training_offers.back()

func _get_training_offer_entry() -> Dictionary:
	for offer in _generated_training_offers:
		if (
			str(offer.get("node_id", "")) == _current_node_id
			and _training_offer_builder.is_current_training_offer(offer)
		):
			return offer
	return {}

func _find_training_choice(choice_kind: String, choice_id: String) -> Dictionary:
	if choice_kind != "stat":
		return {}
	var offer := _get_or_create_training_offer()
	for choice_value in offer.get("stat_choices", []):
		if (
			choice_value is Dictionary
			and str((choice_value as Dictionary).get("id", (choice_value as Dictionary).get("perk_id", ""))) == choice_id
		):
			return choice_value as Dictionary
	return {}

func _parse_training_action_id(action_id: String) -> Dictionary:
	var prefix := "training_stat:"
	if action_id.begins_with(prefix):
		var choice_id := action_id.trim_prefix(prefix).strip_edges()
		if not choice_id.is_empty():
			return {"choice_kind": "stat", "choice_id": choice_id}
	return {}

func _grant_training_choice(
	choice: Dictionary,
	effect_receipt: Dictionary,
	judgment_result: Dictionary = {}
) -> bool:
	var runtime_state := _get_registry_instance(_active_registry, "runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("apply_choice"):
		return false
	var training_id := str(choice.get("id", "")).strip_edges()
	# Recheck the production final-consumer gate inside the transaction callback.
	# A stale card cannot commit after the visible timing judgment was stopped.
	if (
		runtime_state.has_method("is_physique_training_saturated")
		and bool(runtime_state.call(
			"is_physique_training_saturated",
			training_id,
			_active_registry
		))
	):
		return false
	_pending_runtime_perk_rollback_snapshot.clear()
	if runtime_state.has_method("build_unlock_save_snapshot"):
		var snapshot_value: Variant = runtime_state.call("build_unlock_save_snapshot")
		if snapshot_value is Dictionary:
			_pending_runtime_perk_rollback_snapshot = (snapshot_value as Dictionary).duplicate(true)
	var applied_choice := choice.duplicate(true)
	var judgment_kind := str(judgment_result.get(
		"judgment_kind",
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
	))
	var effect_multiplier := TowerTrainingTimingJudgmentPolicy.applied_multiplier(
		training_id,
		judgment_kind
	)
	applied_choice["training_effect_multiplier"] = effect_multiplier
	if not bool(runtime_state.call(
		"apply_choice",
		applied_choice,
		_active_owner,
		_active_registry
	)):
		_rollback_training_choice()
		return false
	effect_receipt["judgment_kind"] = judgment_kind
	effect_receipt["effect_multiplier"] = effect_multiplier
	effect_receipt["base_value"] = _training_base_increment(choice)
	effect_receipt["applied_value"] = (
		float(effect_receipt.get("base_value", 0.0)) * effect_multiplier
	)
	return true

func _rollback_training_choice(gameplay_rng_snapshot: Dictionary = {}) -> void:
	if not gameplay_rng_snapshot.is_empty():
		_gameplay_rng_state = gameplay_rng_snapshot.duplicate(true)
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


func _training_maximum_message(choice: Dictionary) -> String:
	if str(choice.get("id", "")) == TowerTrainingTimingJudgmentPolicy.STORAGE_TRAINING_ID:
		return str(choice.get("level_text", "3/3"))
	return TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_TRAINING_MAXIMUM
	)


func _training_base_increment(choice: Dictionary) -> float:
	return (
		float(choice.get("training_amount", 0.0))
		* float(choice.get("training_multiplier", 1.0))
	)


func _build_training_receipt_message(
	choice: Dictionary,
	effect_receipt: Dictionary
) -> String:
	var applied_text := _format_training_value(
		float(effect_receipt.get("applied_value", 0.0)),
		choice
	)
	var judgment_kind := str(effect_receipt.get(
		"judgment_kind",
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
	))
	var judgment_key := TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_BASE
	if judgment_kind == TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL:
		judgment_key = TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_CRITICAL
	elif judgment_kind == TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT:
		judgment_key = TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_GREAT
	return TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_RESULT,
		{
			"judgment": TowerAscentNodeModalLocalization.text(judgment_key),
			"name": str(choice.get(
				"training_value_label",
				choice.get("name", choice.get("id", ""))
			)),
			"applied": applied_text,
		}
	)


func _format_training_value(value: float, choice: Dictionary) -> String:
	var number_text := (
		str(int(roundf(value)))
		if is_equal_approx(value, roundf(value))
		else "%.1f" % value
	)
	var unit := str(choice.get("training_unit", ""))
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		unit = str(choice.get("training_unit_ko", unit))
	return "%s%s" % [number_text, unit]


func set_training_gameplay_rng_state_for_tests(value: Dictionary) -> void:
	_gameplay_rng_state = value.duplicate(true)


func get_training_gameplay_rng_state_for_tests() -> Dictionary:
	return _gameplay_rng_state.duplicate(true)


func get_training_timing_roll_count_for_tests() -> int:
	return _training_timing_roll_count


func set_training_timing_roll_count_for_tests(value: int) -> void:
	_training_timing_roll_count = maxi(0, value)

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


func _prepare_training_stats_panel() -> Dictionary:
	if _node_modal_kind != "training" or _active_owner == null or _active_registry == null:
		return {"prepared": false, "row_count": 0}
	var renderer := _get_registry_instance(_active_registry, "runtime_perk_overlay_renderer")
	if renderer == null or not renderer.has_method("prepare_tower_training_stats_panel"):
		return {"prepared": false, "row_count": 0}
	var result: Variant = renderer.call(
		"prepare_tower_training_stats_panel",
		_active_owner,
		_active_registry
	)
	return result as Dictionary if result is Dictionary else {
		"prepared": false,
		"row_count": 0,
	}
