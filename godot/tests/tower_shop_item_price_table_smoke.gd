extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowEconomyProgress := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd"
)
const TowerAscentShopInventory := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_inventory.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const EXPECTED_ACTIVE_ITEM_PRICES := {
	"gauge_charge": 200,
	"life_elixir": 400,
	"vitamin_pill": 300,
	"lingpet_spirit_water": 500,
	"lingpet_egg": 700,
	"aipill": 300,
	"pandora_box": 800,
	"mystic_dice": 500,
	"grenade": 250,
	"flare": 300,
	"tear_gas": 200,
	"dynamite": 400,
	"molotov": 300,
	"stopwatch": 350,
	"magnet_field": 300,
	"long_boost": 250,
	"regeneration_potion": 350,
	"holy_barrier": 400,
	"dash_boost": 300,
	"wall": 200,
	"trampoline": 300,
	"campfire": 150,
	"boomerang": 250,
	"banana": 300,
	"soap": 250,
	"spider_mine": 300,
	"elixir_of_mastery": 1500,
}
const EXPECTED_DISPLAY_NAMES_BY_ID := {
	"gauge_charge": "탕약",
	"life_elixir": "오색약수",
	"vitamin_pill": "경신단",
	"lingpet_spirit_water": "심령수",
	"lingpet_egg": "수호령 알",
	"aipill": "신령환",
	"pandora_box": "도깨비 보따리",
	"mystic_dice": "팔자윷",
	"grenade": "폭화탄",
	"flare": "환광탄",
	"tear_gas": "최루탄",
	"dynamite": "폭렬화통",
	"molotov": "열화병",
	"stopwatch": "요술 회중시계",
	"magnet_field": "흡인진",
	"long_boost": "거신단",
	"regeneration_potion": "원기탕",
	"holy_barrier": "금강결계",
	"dash_boost": "축지부",
	"wall": "토벽패",
	"trampoline": "널뛰기",
	"campfire": "모닥불",
	"boomerang": "부메랑",
	"banana": "바나나",
	"soap": "비누",
	"spider_mine": "귀주뢰",
	"elixir_of_mastery": "대성영단",
}
const REGULAR_FILLER_IDS := [
	"gauge_charge",
	"life_elixir",
	"vitamin_pill",
	"aipill",
	"grenade",
	"flare",
]

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "soldier"
	var current_stage := 4
	var active_item_slots: Array = []
	var passive_item_inventory: Array = []
	var equipment_slots: Dictionary = {}
	var chance_gems_count := 0
	var chance_gems_max := 3

	func request_battle_redraw() -> void:
		pass


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeActiveItemRuntime:
	extends RefCounted

	var granted_item_names: Array[String] = []

	func grant_item_to_slot(
		item_name: String,
		owner: Object,
		_registry: Object,
		_allow_overflow: bool = false
	) -> bool:
		if owner == null:
			return false
		granted_item_names.append(item_name)
		var slots: Array = owner.get("active_item_slots")
		slots.append({"name": item_name})
		owner.set("active_item_slots", slots)
		return true

	func debug_remove_item_from_slot(item_name: String, owner: Object, _registry: Object) -> void:
		if owner == null:
			return
		var slots: Array = owner.get("active_item_slots")
		for slot_index in range(slots.size() - 1, -1, -1):
			if str((slots[slot_index] as Dictionary).get("name", "")) == item_name:
				slots.remove_at(slot_index)
				break
		owner.set("active_item_slots", slots)


class FakeRegistry:
	extends RefCounted

	var unlock_store := FakeUnlockStore.new()
	var active_item_runtime := FakeActiveItemRuntime.new()

	func get_instance(key: String) -> Variant:
		match key:
			"tower_ascent_unlock_store":
				return unlock_store
			"active_item_runtime":
				return active_item_runtime
		return null

	func get_cached_instance(key: String) -> Variant:
		return get_instance(key)


class SingleItemShelfBuilder:
	extends RefCounted

	var target_item_name := ""
	var catalog := ActiveItemCatalog.new()

	func _init(item_name: String) -> void:
		target_item_name = item_name

	func build_candidate_shelves(_registry: Object = null, _owner: Object = null) -> Dictionary:
		var regular_ids: Array[String] = [target_item_name]
		for filler_id_value in REGULAR_FILLER_IDS:
			var filler_id := str(filler_id_value)
			if regular_ids.size() >= TowerAscentShopInventory.REGULAR_STOCK_COUNT:
				break
			if not regular_ids.has(filler_id):
				regular_ids.append(filler_id)
		var regular: Array[Dictionary] = []
		for item_name in regular_ids:
			regular.append(catalog.build_item_by_name(item_name))
		return {
			"regular": regular,
			"premium": [catalog.build_item_by_name("elixir_of_mastery")],
		}


class MissingPriceShelfBuilder:
	extends RefCounted

	var catalog := ActiveItemCatalog.new()

	func build_candidate_shelves(_registry: Object = null, _owner: Object = null) -> Dictionary:
		var regular: Array[Dictionary] = []
		for item_name_value in REGULAR_FILLER_IDS:
			regular.append(catalog.build_item_by_name(str(item_name_value)))
		regular.append({
			"name": "unpriced_probe",
			"display_name": "미등재 가격 표본",
			"type": "active",
			"rarity": "common",
			"chance": 1.0,
		})
		return {
			"regular": regular,
			"premium": [catalog.build_item_by_name("elixir_of_mastery")],
		}


class MissingPriceCapsuleCatalog:
	extends RefCounted

	var catalog := ActiveItemCatalog.new()

	func build_item_by_name(item_name: String) -> Dictionary:
		if item_name == "gauge_charge":
			return {
				"name": "unpriced_capsule_probe",
				"display_name": "unpriced capsule probe",
				"type": "active",
				"rarity": "common",
				"chance": 1.0,
			}
		return catalog.build_item_by_name(item_name)


class SupplyOnlyCapsuleCatalog:
	extends RefCounted

	var catalog := ActiveItemCatalog.new()

	func build_item_by_name(item_name: String) -> Dictionary:
		if item_name == "gauge_charge":
			return {
				"name": "supply_only_capsule_probe",
				"display_name": "supply-only capsule probe",
				"type": "active",
				"rarity": "common",
				"chance": 1.0,
				"supply_drop_only": true,
			}
		return catalog.build_item_by_name(item_name)


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_all_twenty_seven_prices_reach_generated_stock()
	_verify_unpriced_sale_candidate_fails_closed()
	_verify_unpriced_capsule_candidate_fails_closed()
	_verify_supply_only_capsule_candidate_is_filtered()
	_verify_mystic_dice_debits_five_hundred_gold_on_real_transaction_owner()
	_verify_restored_unpriced_stock_closes_before_purchase()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_shop_item_price_table_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_all_twenty_seven_prices_reach_generated_stock() -> void:
	_expect(EXPECTED_ACTIVE_ITEM_PRICES.size() == 27, "approved active-item price table must contain exactly 27 entries")
	var approved_ids: Array[String] = []
	for item_name_value in EXPECTED_ACTIVE_ITEM_PRICES.keys():
		approved_ids.append(str(item_name_value))
	approved_ids.sort()
	var field_spawn_ids: Array[String] = []
	for item_name_value in ActiveItemCatalog.FIELD_SPAWN_ORDER:
		field_spawn_ids.append(str(item_name_value))
	field_spawn_ids.sort()
	_expect(
		field_spawn_ids == approved_ids,
		"the complete field-active catalog and approved 27-entry price table must have identical ids"
	)
	_expect(
		TowerAscentTuning.SHOP_ACTIVE_ITEM_GOLD_PRICE_BY_ID == EXPECTED_ACTIVE_ITEM_PRICES,
		"production tuning data must match the approved 27-entry table with no missing or extra ids"
	)
	var catalog := ActiveItemCatalog.new()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	for item_name_value in EXPECTED_ACTIVE_ITEM_PRICES.keys():
		var item_name := str(item_name_value)
		var item_data: Dictionary = catalog.build_item_by_name(item_name)
		_expect(not item_data.is_empty(), "approved shop id must resolve through the active catalog: %s" % item_name)
		_expect(
			str(item_data.get("display_name", "")) == str(EXPECTED_DISPLAY_NAMES_BY_ID[item_name]),
			"approved Korean display name must map to %s through the active catalog" % item_name
		)
		var inventory_builder := TowerAscentShopInventory.new()
		inventory_builder.set("_shelf_builder", SingleItemShelfBuilder.new(item_name))
		var inventory: Dictionary = inventory_builder.build_inventory(
			"price-table-%s" % item_name,
			20260830,
			owner,
			registry
		)
		_expect(bool(inventory.get("accepted", false)), "priced fixture must generate for %s" % item_name)
		var stock := _find_stock(inventory.get("stock", []), item_name, "regular")
		_expect(not stock.is_empty(), "priced fixture must place %s on a real regular stock card" % item_name)
		_expect(
			int(stock.get("price", -1)) == int(EXPECTED_ACTIVE_ITEM_PRICES[item_name]),
			"%s must cost exactly %d gold, got %d" % [
				item_name,
				int(EXPECTED_ACTIVE_ITEM_PRICES[item_name]),
				int(stock.get("price", -1)),
			]
		)


func _verify_unpriced_sale_candidate_fails_closed() -> void:
	var inventory_builder := TowerAscentShopInventory.new()
	inventory_builder.set("_shelf_builder", MissingPriceShelfBuilder.new())
	var inventory: Dictionary = inventory_builder.build_inventory(
		"missing-price",
		20260830,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(not bool(inventory.get("accepted", true)), "an unpriced sale candidate must close the whole inventory")
	_expect(str(inventory.get("reason", "")) == "missing_active_item_price", "unpriced candidate rejection must publish its stable reason")
	_expect(
		(inventory.get("missing_item_names", []) as Array) == ["unpriced_probe"],
		"fail-closed result must report the complete deterministic missing-id list"
	)
	_expect((inventory.get("stock", []) as Array).is_empty(), "fail-closed inventory must expose zero stock")


func _verify_unpriced_capsule_candidate_fails_closed() -> void:
	var inventory_builder := TowerAscentShopInventory.new()
	inventory_builder.set("_shelf_builder", SingleItemShelfBuilder.new("gauge_charge"))
	inventory_builder.set("_catalog", MissingPriceCapsuleCatalog.new())
	var inventory: Dictionary = inventory_builder.build_inventory(
		"missing-capsule-price",
		20260830,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(not bool(inventory.get("accepted", true)), "an unpriced capsule candidate must close the whole inventory")
	_expect(str(inventory.get("reason", "")) == "missing_active_item_price", "an unpriced capsule must publish the common fail-closed reason")
	_expect(
		(inventory.get("missing_item_names", []) as Array) == ["unpriced_capsule_probe"],
		"capsule membership validation must report its deterministic missing id"
	)
	_expect((inventory.get("stock", []) as Array).is_empty(), "an unpriced capsule candidate must expose zero stock")


func _verify_supply_only_capsule_candidate_is_filtered() -> void:
	var inventory_builder := TowerAscentShopInventory.new()
	inventory_builder.set("_catalog", SupplyOnlyCapsuleCatalog.new())
	var capsule_candidates: Array = inventory_builder.call(
		"_build_capsule_candidates",
		FakeOwner.new(),
		FakeRegistry.new()
	)
	var candidate_ids: Array[String] = []
	for candidate_value in capsule_candidates:
		if candidate_value is Dictionary:
			candidate_ids.append(str((candidate_value as Dictionary).get("name", "")))
	_expect(
		not candidate_ids.has("supply_only_capsule_probe"),
		"the concealed shop capsule pool must honor supply_drop_only before its roll"
	)


func _verify_mystic_dice_debits_five_hundred_gold_on_real_transaction_owner() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var inventory_builder := TowerAscentShopInventory.new()
	inventory_builder.set("_shelf_builder", SingleItemShelfBuilder.new("mystic_dice"))
	var inventory: Dictionary = inventory_builder.build_inventory(
		"mystic-price-shop",
		20260830,
		owner,
		registry
	)
	var mystic_stock := _find_stock(inventory.get("stock", []), "mystic_dice", "regular")
	_expect(int(mystic_stock.get("price", -1)) == 500, "mystic dice production stock must carry the approved 500-gold price")
	if mystic_stock.is_empty():
		return

	var economy := TowerAscentFlowEconomyProgress.new()
	economy.set("_active_owner", owner)
	economy.set("_active_registry", registry)
	economy.set("_current_node_id", "mystic-price-shop")
	economy.set("_node_modal_kind", "shop")
	_expect(economy.ensure_run_started(owner, {
		"run_id": "mystic-price-transaction",
		"run_state": {"gold": 1000, "chance_gems": 0},
	}), "mystic dice transaction fixture must start a real Tower run state")
	var restored_inventory := inventory.duplicate(true)
	restored_inventory["inventory_version"] = "tower_shop_inventory_v3"
	var restored_mystic_stock := _find_stock(
		restored_inventory.get("stock", []),
		"mystic_dice",
		"regular"
	)
	restored_mystic_stock["price"] = 60
	_expect(
		int(restored_mystic_stock.get("price", -1)) == 60,
		"the restore fixture must begin with the legacy 60-gold mystic price"
	)
	var restored_inventories: Array[Dictionary] = [restored_inventory]
	economy.set("_generated_shop_inventory", restored_inventories)
	var result: Dictionary = economy.call(
		"_execute_shop_purchase",
		str(mystic_stock.get("stock_id", "")),
		"mystic-price-transaction:purchase"
	)
	_expect(
		bool(result.get("accepted", false)) and bool(result.get("applied", false)),
		"mystic dice purchase must commit through the real shop transaction owner"
	)
	_expect(
		int(economy.get_run_state_snapshot().get("gold", -1)) == 500,
		"mystic dice purchase must debit exactly 500 gold from the 1000-gold run balance, got balance=%s source=%s restored=%s inventories=%s result=%s" % [
			economy.get_run_state_snapshot(),
			mystic_stock,
			restored_mystic_stock,
			economy.get_generated_shop_inventory(),
			result,
		]
	)
	_expect(
		registry.active_item_runtime.granted_item_names.size() == 1
		and registry.active_item_runtime.granted_item_names[0] == "mystic_dice"
		and owner.active_item_slots.size() == 1,
		"restored mystic dice transaction must reprice 60 to 500 and grant exactly one slot entry: grants=%s slots=%s" % [
			registry.active_item_runtime.granted_item_names,
			owner.active_item_slots,
		]
	)


func _verify_restored_unpriced_stock_closes_before_purchase() -> void:
	for stock_kind in ["regular", "capsule"]:
		var owner := FakeOwner.new()
		var registry := FakeRegistry.new()
		var economy := TowerAscentFlowEconomyProgress.new()
		var item_name := "unpriced_%s_probe" % stock_kind
		var node_id := "restored-unpriced-%s-shop" % stock_kind
		var stock_id := "unpriced_%s_1" % stock_kind
		economy.set("_active_owner", owner)
		economy.set("_active_registry", registry)
		economy.set("_current_node_id", node_id)
		economy.set("_node_modal_kind", "shop")
		_expect(economy.ensure_run_started(owner, {
			"run_id": "restored-unpriced-%s-transaction" % stock_kind,
			"run_state": {"gold": 1000, "chance_gems": 0},
		}), "restored unpriced %s fixture must start a real Tower run state" % stock_kind)
		var restored_inventories: Array[Dictionary] = [{
			"accepted": true,
			"inventory_version": "tower_shop_inventory_v3",
			"node_id": node_id,
			"stock": [{
				"stock_id": stock_id,
				"kind": stock_kind,
				"item_name": item_name,
				"display_name": "unpriced restore probe",
				"price": 1,
				"sold": false,
			}],
		}]
		economy.set("_generated_shop_inventory", restored_inventories)
		var result: Dictionary = economy.call(
			"_execute_shop_purchase",
			stock_id,
			"restored-unpriced-%s-transaction:purchase" % stock_kind
		)
		_expect(not bool(result.get("accepted", true)), "restored unpriced %s stock must close before its sale attempt" % stock_kind)
		_expect(str(result.get("reason", "")) == "missing_active_item_price", "restored unpriced %s stock must preserve the fail-closed reason" % stock_kind)
		_expect(
			(result.get("missing_item_names", []) as Array) == [item_name],
			"restored unpriced %s stock must report its missing id" % stock_kind
		)
		_expect(int(economy.get_run_state_snapshot().get("gold", -1)) == 1000, "closed restored %s stock must debit zero gold" % stock_kind)
		_expect(
			registry.active_item_runtime.granted_item_names.is_empty()
			and owner.active_item_slots.is_empty(),
			"closed restored %s stock must grant no active item" % stock_kind
		)
		var closed_inventories := economy.get_generated_shop_inventory()
		var closed_inventory: Dictionary = (
			closed_inventories[0]
			if closed_inventories.size() == 1
			else {}
		)
		_expect(
			not bool(closed_inventory.get("accepted", true))
			and str(closed_inventory.get("reason", "")) == "missing_active_item_price"
			and (closed_inventory.get("missing_item_names", []) as Array) == [item_name]
			and (closed_inventory.get("stock", []) as Array).is_empty(),
			"closed restored %s inventory must persist its stable reason, missing id, and zero stock" % stock_kind
		)


func _find_stock(stock_values: Variant, item_name: String, kind: String) -> Dictionary:
	if not (stock_values is Array):
		return {}
	for stock_value in stock_values as Array:
		if not (stock_value is Dictionary):
			continue
		var stock := stock_value as Dictionary
		if str(stock.get("item_name", "")) == item_name and str(stock.get("kind", "")) == kind:
			return stock
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
