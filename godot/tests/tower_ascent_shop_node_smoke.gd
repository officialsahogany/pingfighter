extends SceneTree

const ActiveItemRaritySchema := preload(
	"res://scripts/items/active_item_rarity_schema.gd"
)
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
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

var _failures: Array[String] = []
var _transaction_effect_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var active_item_slots: Array = []
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


func _init() -> void:
	_verify_inventory_contract_purchase_and_snapshot()
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


func _verify_inventory_contract_purchase_and_snapshot() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := _build_registry(active_runtime)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-contract",
		"map_seed": 7331,
		"node_modal_kind": "shop",
		"run_state": {"gold": 1000, "muhon": 0, "chance_gems": 2},
		"registry": registry,
	}), "shop fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "shop", owner), "shop fixture must reach the shop only after route serve and map arrival")
	var inventories := flow.get_generated_shop_inventory()
	_expect(inventories.size() == 1, "opening one shop must generate exactly one node-owned inventory")
	var inventory: Dictionary = inventories[0]
	var stock: Array = inventory.get("stock", [])
	_expect(stock.size() == 6, "shop stock must contain regular 3, premium 1, capsule 1, and chance gem 1")
	var kind_counts := _count_stock_kinds(stock)
	_expect(int(kind_counts.get("regular", 0)) == 3, "shop must expose exactly three regular active items")
	_expect(int(kind_counts.get("premium", 0)) == 1, "shop must expose exactly one premium active item")
	_expect(int(kind_counts.get("capsule", 0)) == 1, "shop must expose exactly one capsule pull")
	_expect(int(kind_counts.get("chance_gem", 0)) == 1, "shop must expose exactly one chance gem")
	for stock_value in stock:
		var entry := stock_value as Dictionary
		if str(entry.get("kind", "")) == "regular":
			_expect(int(entry.get("price", -1)) == TowerAscentTuning.TEMP_PHASE_C_SHOP_COMMON_ACTIVE_PRICE, "regular active price must use the Phase C tuning constant")
			_expect(TowerAscentActiveItemAcquisitionPolicy.get_allowed_rarities(TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_REGULAR).has(str(entry.get("rarity", ""))), "regular stock must come from the Phase A regular shelf")
		elif str(entry.get("kind", "")) == "premium":
			_expect(TowerAscentActiveItemAcquisitionPolicy.get_allowed_rarities(TowerAscentActiveItemAcquisitionPolicy.CHANNEL_SHOP_PREMIUM).has(str(entry.get("rarity", ""))), "premium stock must come from the Phase A premium shelf")
			var expected_price := TowerAscentTuning.TEMP_PHASE_C_SHOP_LEGENDARY_ACTIVE_PRICE if str(entry.get("rarity", "")) == ActiveItemRaritySchema.RARITY_LEGENDARY else TowerAscentTuning.TEMP_PHASE_C_SHOP_MYTHIC_ACTIVE_PRICE
			_expect(int(entry.get("price", -1)) == expected_price, "premium price must follow its canonical rarity")
		elif str(entry.get("kind", "")) == "capsule":
			_expect(int(entry.get("price", -1)) == TowerAscentTuning.TEMP_PHASE_C_SHOP_CAPSULE_PRICE, "capsule price must use the Phase C tuning constant")
		elif str(entry.get("kind", "")) == "chance_gem":
			_expect(int(entry.get("price", -1)) == TowerAscentTuning.TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE, "chance-gem price must use the high-price contract")
	var model := flow.get_node_modal_view_model()
	var actions: Array = model.get("actions", [])
	_expect(actions.size() == 7, "shop modal must render six stock actions plus the shared end-work action")
	_expect(_has_action_label(actions, "액티브 캡슐"), "capsule stock must stay concealed until purchase")
	var card_kind_counts: Dictionary = {}
	for action_value in actions:
		if not (action_value is Dictionary) or str((action_value as Dictionary).get("id", "")) == "end_work":
			continue
		var choice: Dictionary = (action_value as Dictionary).get("payload", {}).get("choice", {})
		var card_kind := str(choice.get("card_content_kind", ""))
		card_kind_counts[card_kind] = int(card_kind_counts.get(card_kind, 0)) + 1
		_expect(not str(choice.get("name", "")).is_empty(), "every shop card must project a visible name")
		_expect(not str(choice.get("description", "")).is_empty(), "every shop card must project a visible description")
		_expect(not str(choice.get("level_text", "")).is_empty(), "every shop card must project an item-kind rank line")
		if card_kind == "active_item":
			_expect(not str(choice.get("item_data", {}).get("icon_path", "")).is_empty(), "active-item cards must project their canonical icon path")
	_expect(int(card_kind_counts.get("active_item", 0)) == 4, "three regular and one premium stock must use active-item card icons")
	_expect(int(card_kind_counts.get("capsule", 0)) == 1, "capsule stock must use the concealed supply-card symbol")
	_expect(int(card_kind_counts.get("chance_gem", 0)) == 1, "chance gem stock must use the run-supply card symbol")

	var pre_purchase_snapshot := flow.export_persistable_snapshot()
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(pre_purchase_snapshot, Callable(), null, registry), "stable shop snapshot must restore")
	_expect(var_to_bytes(restored.get_generated_shop_inventory()) == var_to_bytes(inventories), "snapshot restore must preserve exact stock without rerolling")

	var regular_stock := _find_stock_by_kind(flow.get_generated_shop_inventory()[0].get("stock", []), "regular")
	var stock_id := str(regular_stock.get("stock_id", ""))
	var purchase_result := flow.execute_node_action("shop_purchase:%s" % stock_id, "shop-contract:purchase:regular")
	_expect(bool(purchase_result.get("accepted", false)) and bool(purchase_result.get("applied", false)), "affordable regular stock must purchase atomically")
	_expect(int(flow.get_run_state_snapshot().get("gold", -1)) == 1000 - TowerAscentTuning.TEMP_PHASE_C_SHOP_COMMON_ACTIVE_PRICE, "successful purchase must debit run-state gold immediately")
	_expect(active_runtime.grant_calls == 1 and owner.active_item_slots.size() == 1, "purchase must call the existing active-item grant path exactly once")
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


func _verify_insufficient_funds_and_capacity_fail_without_transaction() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := _build_registry(active_runtime)
	var owner := FakeOwner.new()
	var poor_flow := TowerAscentFlowOwner.new()
	_expect(poor_flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "shop-poor",
		"map_seed": 7331,
		"node_modal_kind": "shop",
		"run_state": {"gold": 59, "chance_gems": 0},
		"registry": registry,
	}), "insufficient-funds fixture must open")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(poor_flow, "shop", owner), "insufficient-funds fixture must arrive at the shop")
	var poor_stock := _find_stock_by_kind(poor_flow.get_generated_shop_inventory()[0].get("stock", []), "regular")
	var poor_action := _find_action(poor_flow.get_node_modal_view_model().get("actions", []), "shop_purchase:%s" % str(poor_stock.get("stock_id", "")))
	_expect(not bool(poor_action.get("enabled", true)), "insufficient funds must disable the purchase button")
	_expect(str(poor_action.get("unavailable_reason", "")).contains("60") and str(poor_action.get("unavailable_reason", "")).contains("1 부족"), "disabled purchase must show required gold and exact shortfall")
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
		"map_seed": 7331,
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
		"map_seed": 7331,
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
	var renderer_source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
	var card_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(flow_source.find("grant_item_to_slot") >= 0, "shop purchase must call the existing active-item grant path")
	_expect(inventory_source.find("TowerAscentShopShelfBuilder") >= 0 and inventory_source.find("TowerAscentUnlockFilter") >= 0, "shop stock must consume the Phase A shelf and unlock owners")
	_expect(flow_source.find("plaza_save_store") < 0 and flow_source.find("add_plaza_gold") < 0, "tower shop must never reuse plaza wallet ownership")
	_expect(renderer_source.find('["shop", "training", "fallen_monk"]') >= 0 and renderer_source.find('"draw_tower_node_card"') >= 0, "shop and training must route through the exact same tower card drawer")
	_expect(card_source.find("func _draw_shop_card(") < 0, "shop must not fork a private card drawer")


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
