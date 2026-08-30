extends SceneTree

const LingpetItemOfferPolicy := preload(
	"res://scripts/lingpet/lingpet_item_offer_policy.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TowerAscentActiveItemAcquisitionPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_active_item_acquisition_policy.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerAscentShopInventory := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_inventory.gd"
)
const TowerAscentShopShelfBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_shelf_builder.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	"shop"
)
var _transaction_effect_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var active_item_slots: Array = []
	var passive_item_inventory: Array = []
	var equipment_slots: Dictionary = {}
	var chance_gems_count := 0
	var chance_gems_max := 3
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeModalRuntime:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeActiveItemRuntime:
	extends RefCounted

	var allow_grant := true
	var grant_calls := 0
	var rollback_calls := 0

	func grant_item_to_slot(
		item_name: String,
		owner: Object,
		_registry: Object,
		_allow_overflow: bool = false
	) -> bool:
		grant_calls += 1
		if not allow_grant or owner == null:
			return false
		var slots: Array = owner.get("active_item_slots")
		slots.append({"name": item_name})
		owner.set("active_item_slots", slots)
		return true

	func debug_remove_item_from_slot(item_name: String, owner: Object, _registry: Object) -> bool:
		rollback_calls += 1
		if owner == null:
			return false
		var slots: Array = owner.get("active_item_slots")
		for index in range(slots.size() - 1, -1, -1):
			if slots[index] is Dictionary and str((slots[index] as Dictionary).get("name", "")) == item_name:
				slots.remove_at(index)
				owner.set("active_item_slots", slots)
				return true
		return false


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeLingpetOfferRuntime:
	extends RefCounted

	var allow_egg := false
	var allow_spirit_water := false

	func can_offer_egg_item(_owner: Object, _registry: Object) -> bool:
		return allow_egg

	func can_offer_spirit_water_item(_owner: Object, _registry: Object) -> bool:
		return allow_spirit_water


class MissingPriceShelfBuilder:
	extends RefCounted

	var delegate := TowerAscentShopShelfBuilder.new()

	func build_candidate_shelves(registry: Object = null, owner: Object = null) -> Dictionary:
		var shelves: Dictionary = delegate.build_candidate_shelves(registry, owner)
		var regular: Array = (shelves.get("regular", []) as Array).duplicate(true)
		regular.append({
			"name": "unpriced_modal_probe",
			"display_name": "unpriced modal probe",
			"type": "active",
			"rarity": "common",
			"chance": 1.0,
		})
		shelves["regular"] = regular
		return shelves


func _init() -> void:
	_verify_candidate_shelves_exclude_guardian_products_and_obey_offer_gate()
	_verify_lucky_pouch_locales()
	_verify_inventory_contract_purchase_and_snapshot()
	_verify_lucky_pouch_purchase_debit_and_grant()
	_verify_unpriced_inventory_remains_closed_through_modal_snapshot_restore()
	_verify_insufficient_funds_and_capacity_fail_without_transaction()
	_verify_chance_gem_cap_blocks_payment()
	_verify_transaction_idempotency_before_effect()
	_verify_flag_off_is_untouched()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()

	if _failures.is_empty():
		print("tower_ascent_shop_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_candidate_shelves_exclude_guardian_products_and_obey_offer_gate() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var offer_runtime := FakeLingpetOfferRuntime.new()
	var registry := _build_registry(FakeActiveItemRuntime.new())
	registry.instances["lingpet_egg_runtime"] = offer_runtime
	var shelf_builder := TowerAscentShopShelfBuilder.new()
	var blocked_shelves: Dictionary = shelf_builder.build_candidate_shelves(registry, FakeOwner.new())
	var blocked_names := _collect_shelf_item_names(blocked_shelves)
	for generated_item in ["milk_bottle", "cheddar_cheese", "camembert_cheese", "emmental_cheese"]:
		_expect(not blocked_names.has(generated_item), "%s must stay exclusive to Guardian Spirit production" % generated_item)
	for gated_item in [LingpetItemOfferPolicy.LINGPET_EGG, LingpetItemOfferPolicy.LINGPET_SPIRIT_WATER]:
		_expect(not blocked_names.has(gated_item), "%s must not consume a shop shelf when its Guardian Spirit gate rejects" % gated_item)

	offer_runtime.allow_egg = true
	offer_runtime.allow_spirit_water = true
	var allowed_shelves: Dictionary = shelf_builder.build_candidate_shelves(registry, FakeOwner.new())
	var allowed_names := _collect_shelf_item_names(allowed_shelves)
	_expect(allowed_names.has(LingpetItemOfferPolicy.LINGPET_EGG), "shop shelves must retain the egg when its offer gate allows it")
	_expect(allowed_names.has(LingpetItemOfferPolicy.LINGPET_SPIRIT_WATER), "shop shelves must retain spirit water when its offer gate allows it")
	var inventory := TowerAscentShopInventory.new().build_inventory(
		"shop-gated-pool-budget",
		20260824,
		FakeOwner.new(),
		registry
	)
	_expect(bool(inventory.get("accepted", false)), "gated shelf must still satisfy regular and premium stock budgets")
	_expect(str(inventory.get("inventory_version", "")) == TowerAscentShopInventory.INVENTORY_VERSION, "shop inventory must publish the bumped seeded-pool generation")


func _verify_lucky_pouch_locales() -> void:
	var expected_labels := {
		LanguageSettings.LANGUAGE_KOREAN: "복주머니",
		LanguageSettings.LANGUAGE_ENGLISH: "Lucky Pouch",
		LanguageSettings.LANGUAGE_CHINESE: "福袋",
		LanguageSettings.LANGUAGE_JAPANESE: "福袋",
		LanguageSettings.LANGUAGE_SPANISH: "Bolsa de la suerte",
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Bolsa da Sorte",
		LanguageSettings.LANGUAGE_RUSSIAN: "Мешочек удачи",
	}
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var label := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE
		)
		var description := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE_DESCRIPTION
		)
		var rank := TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_CAPSULE_RANK
		)
		_expect(
			label == str(expected_labels.get(locale, "")),
			"%s shop random-pull label must use its Lucky Pouch translation" % locale
		)
		_expect(
			not description.is_empty()
			and not rank.is_empty()
			and not description.to_lower().contains("capsule")
			and not rank.to_lower().contains("capsule")
			and not description.contains("캡슐")
			and not rank.contains("캡슐"),
			"%s Lucky Pouch description and rank must match the renamed product" % locale
		)
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			_expect(
				not label.contains("—")
				and not description.contains("—")
				and not rank.contains("—"),
				"Korean Lucky Pouch copy must not use an em dash"
			)
	LanguageSettings.set_test_locale_override("")


func _verify_inventory_contract_purchase_and_snapshot() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := _build_registry(active_runtime)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-contract",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "shop",
		"run_state": {"gold": 1000, "muhon": 0, "chance_gems": 2},
		"registry": registry,
	}), "shop fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "shop", owner), "shop fixture must reach the shop only after route serve and map arrival")
	var inventories := flow.get_generated_shop_inventory()
	_expect(inventories.size() == 1, "opening one shop must generate exactly one node-owned inventory")
	var inventory: Dictionary = inventories[0]
	var stock: Array = inventory.get("stock", [])
	var capsule_stock := _find_stock_by_kind(stock, "capsule")
	_expect(stock.size() == 8, "shop stock must contain regular 5, premium 1, capsule 1, and chance gem 1")
	var kind_counts := _count_stock_kinds(stock)
	_expect(int(kind_counts.get("regular", 0)) == 5, "shop must expose exactly five regular active items")
	_expect(int(kind_counts.get("premium", 0)) == 1, "shop must expose exactly one premium active item")
	_expect(int(kind_counts.get("capsule", 0)) == 1, "shop must expose exactly one capsule pull")
	_expect(int(kind_counts.get("chance_gem", 0)) == 1, "shop must expose exactly one chance gem")
	_expect(
		TowerAscentTuning.TEMP_PHASE_C_SHOP_CAPSULE_PRICE == 200,
		"the Lucky Pouch canonical price must be 200 Gold"
	)
	for stock_value in stock:
		var entry := stock_value as Dictionary
		if str(entry.get("kind", "")) == "regular":
			_expect(
				int(entry.get("price", -1))
				== TowerAscentTuning.get_shop_active_item_gold_price(str(entry.get("item_name", ""))),
				"regular active price must use the per-item Z18 table"
			)
			_expect(TowerAscentActiveItemAcquisitionPolicy.get_allowed_rarities(TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_REGULAR).has(str(entry.get("rarity", ""))), "regular stock must come from the Phase A regular shelf")
		elif str(entry.get("kind", "")) == "premium":
			_expect(TowerAscentActiveItemAcquisitionPolicy.get_allowed_rarities(TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_PREMIUM).has(str(entry.get("rarity", ""))), "premium stock must come from the Phase A premium shelf")
			_expect(
				int(entry.get("price", -1))
				== TowerAscentTuning.get_shop_active_item_gold_price(str(entry.get("item_name", ""))),
				"premium price must use the same per-item Z18 table instead of rarity"
			)
		elif str(entry.get("kind", "")) == "capsule":
			_expect(
				int(entry.get("price", -1)) == 200
				and int(entry.get("price", -1))
				== TowerAscentTuning.TEMP_PHASE_C_SHOP_CAPSULE_PRICE,
				"Lucky Pouch price must follow the 200-Gold tuning constant"
			)
		elif str(entry.get("kind", "")) == "chance_gem":
			_expect(int(entry.get("price", -1)) == TowerAscentTuning.TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE, "chance-gem price must use the high-price contract")
	var model := flow.get_node_modal_view_model()
	var actions: Array = model.get("actions", [])
	_expect(actions.size() == 9, "shop modal must render eight stock actions plus the shared exit action")
	var shop_flags: Dictionary = model.get("layout_flags", {})
	_expect(bool(shop_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_SHOP_STACKED, false)), "shop must expose the full-screen stacked layout")
	_expect(not bool(shop_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_SHOP_TRADE_PANELS, true)), "shop must retire the split trade-panel layout")
	_expect(int(model.get("shop_stock_columns", 0)) == 8 and int(model.get("shop_stock_rows", 0)) == 1, "eight stock cards must derive one horizontal row")
	_expect(int(model.get("shop_player_columns", -1)) == 3 and int(model.get("shop_player_rows", -1)) == 1, "empty owner must still expose its three active-item capacity slots")
	_expect((model.get("shop_owned_items", []) as Array).size() == 3, "empty owner must project three explicit empty active-item slots")
	for owned_value in model.get("shop_owned_items", []) as Array:
		_expect(bool((owned_value as Dictionary).get("empty_slot", false)), "an unfilled active-item capacity slot must be explicit")
	_expect(not (model.get("shop_player_panel_rect", Rect2()) as Rect2).intersects(model.get("shop_stock_panel_rect", Rect2())), "owned and stock panels must not overlap")
	_expect(str((actions[8] as Dictionary).get("label", "")) == "상점 나가기", "shop footer must use the explicit shop-exit copy")
	_expect(_has_action_label(actions, "복주머니"), "the random-pull stock must use the Lucky Pouch label")
	var card_kind_counts: Dictionary = {}
	for action_value in actions:
		if not (action_value is Dictionary) or str((action_value as Dictionary).get("id", "")) == "end_work":
			continue
		_expect(int((action_value as Dictionary).get("cost_gold", -1)) > 0, "every shop product card must retain its positive gold price")
		var choice: Dictionary = (action_value as Dictionary).get("payload", {}).get("choice", {})
		var card_kind := str(choice.get("card_content_kind", ""))
		card_kind_counts[card_kind] = int(card_kind_counts.get(card_kind, 0)) + 1
		_expect(not str(choice.get("name", "")).is_empty(), "every shop card must project a visible name")
		_expect(not str(choice.get("description", "")).is_empty(), "every shop card must project a visible description")
		_expect(not str(choice.get("level_text", "")).is_empty(), "every shop card must project an item-kind rank line")
		if card_kind == "active_item":
			_expect(not str(choice.get("item_data", {}).get("icon_path", "")).is_empty(), "active-item cards must project their canonical icon path")
	_expect(int(card_kind_counts.get("active_item", 0)) == 6, "five regular and one premium stock must use active-item card icons")
	_expect(int(card_kind_counts.get("capsule", 0)) == 1, "Lucky Pouch stock must use the concealed question-mark symbol")
	_expect(int(card_kind_counts.get("chance_gem", 0)) == 1, "chance gem stock must use the run-supply card symbol")
	var capsule_action := _find_action(
		actions,
		"shop_purchase:%s" % str(capsule_stock.get("stock_id", ""))
	)
	var capsule_choice: Dictionary = capsule_action.get("payload", {}).get("choice", {})
	_expect(
		str(capsule_action.get("label", "")) == "복주머니"
		and int(capsule_action.get("cost_gold", -1)) == 200
		and str(capsule_choice.get("id", ""))
		== str(capsule_stock.get("stock_id", ""))
		and str(capsule_choice.get("name", "")) == "복주머니"
		and str(capsule_choice.get("rarity", "")) == "unknown"
		and (capsule_choice.get("item_data", {}) as Dictionary).is_empty(),
		"the pre-purchase Lucky Pouch surface must expose only generic product metadata"
	)
	var capsule_surface := var_to_str(capsule_action)
	for concealed_key in ["item_name", "display_name", "icon_path", "icon_sheet_path"]:
		var concealed_value := str(capsule_stock.get(concealed_key, "")).strip_edges()
		if not concealed_value.is_empty():
			_expect(
				not capsule_surface.contains(concealed_value),
				"Lucky Pouch surface must conceal its actual %s before purchase" % concealed_key
			)

	var pre_purchase_snapshot := flow.export_persistable_snapshot()
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(pre_purchase_snapshot, Callable(), null, registry), "stable shop snapshot must restore")
	_expect(var_to_bytes(restored.get_generated_shop_inventory()) == var_to_bytes(inventories), "snapshot restore must preserve exact stock without rerolling")

	var regular_stock := _find_stock_by_kind(flow.get_generated_shop_inventory()[0].get("stock", []), "regular")
	var stock_id := str(regular_stock.get("stock_id", ""))
	var regular_price := int(regular_stock.get("price", -1))
	var purchase_result := flow.execute_node_action("shop_purchase:%s" % stock_id, "shop-contract:purchase:regular")
	_expect(bool(purchase_result.get("accepted", false)) and bool(purchase_result.get("applied", false)), "affordable regular stock must purchase atomically")
	_expect(int(flow.get_run_state_snapshot().get("gold", -1)) == 1000 - regular_price, "successful purchase must debit the exact item-table price immediately")
	_expect(active_runtime.grant_calls == 1 and owner.active_item_slots.size() == 1, "purchase must call the existing active-item grant path exactly once")
	var purchased_model := flow.get_node_modal_view_model()
	var purchased_owned: Array = purchased_model.get("shop_owned_items", [])
	_expect(purchased_owned.size() == 3, "purchase must preserve all three capacity-owned slot positions")
	_expect(not bool((purchased_owned[0] as Dictionary).get("empty_slot", false)), "purchased active item must refresh into its read-only owned slot")
	_expect(str(purchased_model.get("shop_player_label", "")) == "소지 아이템", "owned panel must carry the explicit read-only label")
	_expect(flow.get_purchase_history().size() == 1, "successful purchase must persist one node_resolution_id history entry")
	var after_first_gold := int(flow.get_run_state_snapshot().get("gold", -1))
	var duplicate_result := flow.execute_node_action("shop_purchase:%s" % stock_id, "shop-contract:purchase:regular")
	_expect(not bool(duplicate_result.get("accepted", true)), "sold stock must reject repeat execution")
	_expect(int(flow.get_run_state_snapshot().get("gold", -1)) == after_first_gold and active_runtime.grant_calls == 1, "repeat stock execution must neither debit nor grant again")
	var post_purchase_snapshot := flow.export_persistable_snapshot()
	_expect((post_purchase_snapshot.get("purchase_history", []) as Array).size() == 1, "purchase history must be part of the run snapshot")
	_expect((post_purchase_snapshot.get("build_state", {}) as Dictionary).get("active_items", []).size() == 1, "purchased active item must be part of build-state snapshot ownership")
	_finish_flow(flow, owner)
	_finish_flow(restored, null)


func _verify_lucky_pouch_purchase_debit_and_grant() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var active_runtime := FakeActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-lucky-pouch-purchase",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "shop",
		"run_state": {"gold": 500, "muhon": 0, "chance_gems": 0},
		"registry": _build_registry(active_runtime),
	}), "Lucky Pouch purchase fixture must enter through the real Tower flow")
	_expect(
		TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "shop", owner),
		"Lucky Pouch purchase fixture must arrive through the production shop route"
	)
	var stock: Array = flow.get_generated_shop_inventory()[0].get("stock", [])
	var capsule_stock := _find_stock_by_kind(stock, "capsule")
	var stock_id := str(capsule_stock.get("stock_id", ""))
	var actual_item_name := str(capsule_stock.get("item_name", ""))
	var before_actions: Array = flow.get_node_modal_view_model().get("actions", [])
	var before_action := _find_action(
		before_actions,
		"shop_purchase:%s" % stock_id
	)
	_expect(
		int(before_action.get("cost_gold", -1)) == 200
		and str(before_action.get("label", "")) == "복주머니",
		"the production Lucky Pouch action must expose a generic label and 200-Gold cost"
	)
	var purchase_result := flow.execute_node_action(
		"shop_purchase:%s" % stock_id,
		"shop-lucky-pouch-purchase:commit"
	)
	_expect(
		bool(purchase_result.get("accepted", false))
		and bool(purchase_result.get("applied", false)),
		"an affordable Lucky Pouch purchase must commit atomically"
	)
	_expect(
		int(flow.get_run_state_snapshot().get("gold", -1)) == 300,
		"Lucky Pouch purchase must debit exactly 200 Gold"
	)
	_expect(
		active_runtime.grant_calls == 1
		and owner.active_item_slots.size() == 1
		and str((owner.active_item_slots[0] as Dictionary).get("name", ""))
		== actual_item_name,
		"Lucky Pouch purchase must grant the concealed inventory item unchanged"
	)
	var after_model := flow.get_node_modal_view_model()
	var after_owned: Array = after_model.get("shop_owned_items", [])
	_expect(
		after_owned.size() == 3
		and str((after_owned[0] as Dictionary).get("item_data", {}).get("name", ""))
		== actual_item_name,
		"the purchased item may reveal its real identity only in the owned-item row"
	)
	var after_gold := int(flow.get_run_state_snapshot().get("gold", -1))
	var duplicate := flow.execute_node_action(
		"shop_purchase:%s" % stock_id,
		"shop-lucky-pouch-purchase:duplicate"
	)
	_expect(
		not bool(duplicate.get("accepted", true))
		and int(flow.get_run_state_snapshot().get("gold", -1)) == after_gold
		and active_runtime.grant_calls == 1,
		"a sold Lucky Pouch must neither debit nor grant twice"
	)
	_finish_flow(flow, owner)


func _verify_unpriced_inventory_remains_closed_through_modal_snapshot_restore() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var registry := _build_registry(FakeActiveItemRuntime.new())
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-unpriced-closed",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "shop",
		"run_state": {"gold": 1000, "muhon": 0, "chance_gems": 0},
		"registry": registry,
	}), "unpriced modal fixture must enter through the real Tower flow")
	var inventory_builder := TowerAscentShopInventory.new()
	inventory_builder.set("_shelf_builder", MissingPriceShelfBuilder.new())
	flow.set("_shop_inventory_builder", inventory_builder)
	_expect(
		TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "shop", owner),
		"unpriced modal fixture must reach its shop through route serve and map arrival"
	)
	var expected_status := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SHOP_INVENTORY_UNAVAILABLE
	)
	var model := flow.get_node_modal_view_model()
	var actions: Array = model.get("actions", [])
	_expect(
		actions.size() == 1
		and str((actions[0] as Dictionary).get("id", "")) == "end_work",
		"a fail-closed shop modal must expose only its exit action"
	)
	_expect(
		str(model.get("status_text", "")) == expected_status,
		"a fail-closed shop modal must publish the localized inventory-unavailable status"
	)
	var closed_inventories := flow.get_generated_shop_inventory()
	var closed_inventory: Dictionary = (
		closed_inventories[0]
		if closed_inventories.size() == 1
		else {}
	)
	_expect(
		not bool(closed_inventory.get("accepted", true))
		and str(closed_inventory.get("reason", "")) == "missing_active_item_price"
		and (closed_inventory.get("missing_item_names", []) as Array) == ["unpriced_modal_probe"]
		and (closed_inventory.get("stock", []) as Array).is_empty(),
		"the real modal path must persist one deterministic closed inventory record"
	)

	var snapshot := flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "the fail-closed shop must remain a persistable stable boundary")
	_expect(
		var_to_bytes(snapshot.get("generated_shop_inventory", []))
		== var_to_bytes(closed_inventories),
		"the closed inventory record must be present byte-for-byte in the run snapshot"
	)
	var restored_owner := FakeOwner.new()
	var restored_registry := _build_registry(FakeActiveItemRuntime.new())
	var restored := TowerAscentFlowOwner.new()
	_expect(
		restored.restore_snapshot(
			snapshot,
			Callable(),
			restored_owner,
			restored_registry
		),
		"a stable fail-closed shop snapshot must restore"
	)
	var restored_model := restored.get_node_modal_view_model()
	var restored_actions: Array = restored_model.get("actions", [])
	_expect(
		restored_actions.size() == 1
		and str((restored_actions[0] as Dictionary).get("id", "")) == "end_work"
		and str(restored_model.get("status_text", "")) == expected_status,
		"restoring a fail-closed shop must keep purchases absent and its unavailable status visible"
	)
	_expect(
		var_to_bytes(restored.get_generated_shop_inventory())
		== var_to_bytes(closed_inventories),
		"restoring a fail-closed shop must not regenerate or erase its reported missing ids"
	)
	_finish_flow(flow, owner)
	_finish_flow(restored, restored_owner)


func _verify_insufficient_funds_and_capacity_fail_without_transaction() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := _build_registry(active_runtime)
	var owner := FakeOwner.new()
	var poor_flow := TowerAscentFlowOwner.new()
	_expect(poor_flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-poor",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "shop",
		"run_state": {"gold": 59, "chance_gems": 0},
		"registry": registry,
	}), "insufficient-funds fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(poor_flow, "shop", owner), "insufficient-funds fixture must arrive at the shop")
	var poor_stock := _find_stock_by_kind(poor_flow.get_generated_shop_inventory()[0].get("stock", []), "regular")
	var poor_price := int(poor_stock.get("price", -1))
	var poor_action := _find_action(poor_flow.get_node_modal_view_model().get("actions", []), "shop_purchase:%s" % str(poor_stock.get("stock_id", "")))
	_expect(not bool(poor_action.get("enabled", true)), "insufficient funds must disable the purchase button")
	_expect(
		str(poor_action.get("unavailable_reason", "")).contains(str(poor_price))
		and str(poor_action.get("unavailable_reason", "")).contains("%d 부족" % (poor_price - 59)),
		"disabled purchase must show the item-table price and exact shortfall"
	)
	var poor_result := poor_flow.execute_node_action(str(poor_action.get("id", "")), "shop-poor:attempt")
	_expect(not bool(poor_result.get("accepted", true)), "insufficient funds must reject the transaction")
	_expect(int(poor_flow.get_run_state_snapshot().get("gold", -1)) == 59, "insufficient funds must not partially debit gold")
	_expect(poor_flow.get_purchase_history().is_empty() and active_runtime.grant_calls == 0, "insufficient funds must emit no purchase transaction and no grant")
	_finish_flow(poor_flow, owner)

	var full_runtime := FakeActiveItemRuntime.new()
	full_runtime.allow_grant = false
	var full_registry := _build_registry(full_runtime)
	var full_owner := FakeOwner.new()
	var full_flow := TowerAscentFlowOwner.new()
	_expect(full_flow.begin_vertical_slice(full_owner, Callable(), {
		"run_id": "shop-full",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "shop",
		"run_state": {"gold": 1000, "chance_gems": 0},
		"registry": full_registry,
	}), "slot-capacity fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(full_flow, "shop", full_owner), "slot-capacity fixture must arrive at the shop")
	var full_stock := _find_stock_by_kind(full_flow.get_generated_shop_inventory()[0].get("stock", []), "regular")
	var full_result := full_flow.execute_node_action("shop_purchase:%s" % str(full_stock.get("stock_id", "")), "shop-full:attempt")
	_expect(str(full_result.get("reason", "")) == "effect_rejected", "active-slot rejection must surface before payment")
	_expect(int(full_flow.get_run_state_snapshot().get("gold", -1)) == 1000, "failed item grant must not debit gold")
	_expect(full_flow.get_purchase_history().is_empty(), "failed item grant must not emit a purchase transaction")
	_finish_flow(full_flow, full_owner)


func _verify_chance_gem_cap_blocks_payment() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	var registry := _build_registry(FakeActiveItemRuntime.new())
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-gem-cap",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "shop",
		"run_state": {"gold": 1000, "chance_gems": 3},
		"registry": registry,
	}), "gem-cap fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "shop", owner), "gem-cap fixture must arrive at the shop")
	var gem_stock := _find_stock_by_kind(flow.get_generated_shop_inventory()[0].get("stock", []), "chance_gem")
	var gem_action := _find_action(flow.get_node_modal_view_model().get("actions", []), "shop_purchase:%s" % str(gem_stock.get("stock_id", "")))
	_expect(not bool(gem_action.get("enabled", true)), "chance gem at cap must disable its purchase button")
	var result := flow.execute_node_action(str(gem_action.get("id", "")), "shop-gem-cap:attempt")
	_expect(str(result.get("reason", "")) == "chance_gems_full", "chance gem cap must reject direct execution too")
	_expect(int(flow.get_run_state_snapshot().get("gold", -1)) == 1000 and int(flow.get_run_state_snapshot().get("chance_gems", -1)) == 3, "gem-cap rejection must not debit or overfill")
	_finish_flow(flow, owner)


func _verify_transaction_idempotency_before_effect() -> void:
	var run_state := TowerAscentRunState.new()
	_expect(run_state.begin("transaction-idempotency", {"gold": 100, "chance_gems": 0}), "transaction fixture run must begin")
	var committed: Dictionary = {}
	var transaction := TowerAscentNodeActionTransaction.new()
	_transaction_effect_calls = 0
	var first := transaction.apply_once(
		"transaction-idempotency:node:purchase",
		{"gold": 10},
		{},
		run_state,
		committed,
		Callable(self, "_record_transaction_effect")
	)
	var second := transaction.apply_once(
		"transaction-idempotency:node:purchase",
		{"gold": 10},
		{},
		run_state,
		committed,
		Callable(self, "_record_transaction_effect")
	)
	_expect(bool(first.get("applied", false)), "first node_resolution_id execution must apply")
	_expect(bool(second.get("accepted", false)) and not bool(second.get("applied", true)), "duplicate node_resolution_id must be an accepted no-op")
	_expect(_transaction_effect_calls == 1 and int(run_state.export_economy().get("gold", -1)) == 90, "duplicate node_resolution_id must not repeat effect or debit")


func _verify_flag_off_is_untouched() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var active_runtime := FakeActiveItemRuntime.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(FakeOwner.new(), Callable(), {
		"run_id": "shop-off",
		"node_modal_kind": "shop",
		"run_state": {"gold": 1000},
		"registry": _build_registry(active_runtime),
	}), "flag OFF must not enter the tower shop")
	_expect(flow.get_generated_shop_inventory().is_empty() and active_runtime.grant_calls == 0, "flag OFF must not generate tower stock or grant items")


func _verify_source_contract() -> void:
	var flow_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd")
	var inventory_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_shop_inventory.gd")
	var tuning_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_tuning.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
	var card_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(flow_source.find("grant_item_to_slot") >= 0, "shop purchase must call the existing active-item grant path")
	_expect(inventory_source.find("TowerAscentShopShelfBuilder") >= 0 and inventory_source.find("TowerAscentUnlockFilter") >= 0, "shop stock must consume the Phase A shelf and unlock owners")
	_expect(flow_source.find("plaza_save_store") < 0 and flow_source.find("add_plaza_gold") < 0, "tower shop must never reuse plaza wallet ownership")
	for node_kind in ["training", "fallen_monk", "guardian_spring", "rest", "taiji_elder"]:
		_expect(renderer_source.find('"%s"' % node_kind) >= 0, "%s must remain in the shared tower card dispatcher" % node_kind)
	_expect(renderer_source.find('"draw_tower_node_card"') >= 0, "non-shop service nodes must retain the shared tower card drawer")
	_expect(renderer_source.find("draw_tower_shop_product_card") >= 0, "shop draw must delegate product cards to the shared overlay renderer")
	_expect(card_source.find("func draw_tower_shop_product_card(") >= 0, "shop must use the shared stacked product-card renderer")
	_expect(card_source.find("func prewarm_tower_shop_cells(") >= 0, "shop prewarm must remain owned by the shared card renderer")
	_expect(card_source.find("func _draw_shop_card(") < 0, "shop must not fork a private card drawer")
	_expect(
		tuning_source.contains("TEMP_PHASE_C_SHOP_CAPSULE_PRICE := 200"),
		"the one canonical Lucky Pouch tuning constant must be 200 Gold"
	)
	_expect(
		inventory_source.count("TEMP_PHASE_C_SHOP_CAPSULE_PRICE") == 2,
		"both initial-build and restore inventory consumers must follow the tuning constant"
	)
	_expect(
		card_source.contains('const SHOP_LUCKY_POUCH_GLYPH := "?"')
		and card_source.contains("SHOP_LUCKY_POUCH_GLYPH"),
		"the shop card renderer must own a procedural Lucky Pouch question-mark glyph"
	)


func _build_registry(active_runtime: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": FakeModalRuntime.new(),
		"active_item_runtime": active_runtime,
		TowerAscentUnlockFilter.STORE_KEY: FakeUnlockStore.new(),
	}
	return registry


func _finish_flow(flow: Object, owner: Object) -> void:
	if flow == null or not flow.is_active():
		return
	if flow.get_phase_name() == "NODE_MODAL":
		flow.debug_advance_to_route_aim()
	if flow.get_phase_name() == "ROUTE_AIM":
		flow.debug_launch_at_target(0)
		flow.update_selective(1.5, owner)
	if flow.get_phase_name() == "MAP_TRANSITION":
		flow.update_selective(1.0, owner)


func _record_transaction_effect() -> bool:
	_transaction_effect_calls += 1
	return true


func _count_stock_kinds(stock: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in stock:
		if value is Dictionary:
			var kind := str((value as Dictionary).get("kind", ""))
			result[kind] = int(result.get(kind, 0)) + 1
	return result


func _collect_shelf_item_names(shelves: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for shelf_name in ["regular", "premium"]:
		var shelf_value: Variant = shelves.get(shelf_name, [])
		if not (shelf_value is Array):
			continue
		for item_value in shelf_value as Array:
			if not (item_value is Dictionary):
				continue
			var item_name := str((item_value as Dictionary).get("name", ""))
			if not item_name.is_empty() and not result.has(item_name):
				result.append(item_name)
	return result


func _find_stock_by_kind(stock: Array, kind: String) -> Dictionary:
	for value in stock:
		if value is Dictionary and str((value as Dictionary).get("kind", "")) == kind:
			return value as Dictionary
	return {}


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for value in actions:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == action_id:
			return value as Dictionary
	return {}


func _has_action_label(actions: Array, label: String) -> bool:
	for value in actions:
		if value is Dictionary and str((value as Dictionary).get("label", "")) == label:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
