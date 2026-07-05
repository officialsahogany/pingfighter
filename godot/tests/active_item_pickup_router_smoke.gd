extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const ActiveItemPickupRouter := preload("res://scripts/items/active_item_pickup_router.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []
var _pickup_feedback_count := 0


class FakeOwner:
	extends Node

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var lucky_coin_equipped := false
	var lucky_coin_active := false
	var lucky_coin_double_spawn_pct := 0.0
	var lucky_coin_double_spawn_chance := 0.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var mythic_runtime: Object

	func _init(runtime: Object) -> void:
		mythic_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		return null


class FakeCinematicMythicRuntime:
	extends RefCounted

	var inventory: Array = []
	var cinematic_active := false
	var cinematic_snapshot: Dictionary = {}

	func acquire_item(
		item_name: String,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {},
		_auto_equip: bool = true,
		_play_feedback: bool = false,
		source_item_data: Dictionary = {}
	) -> int:
		var stored: Dictionary = source_item_data.duplicate(true)
		if stored.is_empty():
			stored = {"name": item_name, "type": "mythic", "rarity": "mythic"}
		stored["name"] = item_name
		inventory.append(stored)
		return inventory.size() - 1

	func get_inventory_item(index: int) -> Dictionary:
		if index < 0 or index >= inventory.size():
			return {}
		return (inventory[index] as Dictionary).duplicate(true)

	func has_owned_item_name(item_name: String) -> bool:
		for item in inventory:
			if item is Dictionary and str((item as Dictionary).get("name", "")) == item_name:
				return true
		return false

	func start_acquisition_cinematic(
		acquired_item_data: Dictionary,
		pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		target_player_center_override: Vector2 = Vector2.INF
	) -> bool:
		cinematic_active = true
		cinematic_snapshot = {
			"item_name": str(acquired_item_data.get("name", "")),
			"pickup_position": pickup_position,
			"player_center": target_player_center_override,
		}
		return true

	func is_acquisition_cinematic_active() -> bool:
		return cinematic_active

	func get_acquisition_cinematic_snapshot() -> Dictionary:
		return cinematic_snapshot.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_store_field_item_routes()
	_verify_collect_field_item_routes()
	_verify_pickup_feedback_handoff()
	_verify_mythic_pickup_starts_cinematic()
	await _drain_frames(8)
	_clear_runtime_caches_for_test()
	await _drain_frames(30)

	if _failures.is_empty():
		print("active_item_pickup_router_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_store_field_item_routes() -> void:
	var active_catalog: Object = ActiveItemCatalog.new()
	var mythic_catalog: Object = MythicItemCatalog.new()
	var router: Object = ActiveItemPickupRouter.new()
	var slot_controller: Object = ActiveItemSlotController.new()
	var effect_controller: Object = ActiveItemEffectController.new()
	var mythic_runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(mythic_runtime)
	var active_slots: Array = []
	root.add_child(owner)

	var banana_item: Dictionary = active_catalog.build_item_by_name("banana")
	_expect(router.store_field_item(
		{"item_data": banana_item},
		active_slots,
		registry,
		owner,
		slot_controller,
		effect_controller
	), "active pickup router should store active field items")
	_expect(active_slots.size() == 1, "active pickup router should append one active slot")
	_expect(str(active_slots[0].get("name", "")) == "banana", "active pickup router should preserve active item data")

	var magnet_item: Dictionary = active_catalog.build_item_by_name("magnet_field")
	effect_controller.magnet_field_active = true
	_expect(not router.store_field_item(
		{"item_data": magnet_item},
		active_slots,
		registry,
		owner,
		slot_controller,
		effect_controller
	), "active pickup router should honor active-effect store gates")

	var lucky_item: Dictionary = mythic_catalog.build_item_by_name("lucky_coin")
	lucky_item["rolls"] = {"double_spawn_pct": 15.0}
	lucky_item = mythic_catalog.sync_roll_fields(lucky_item, false)
	_expect(router.store_field_item(
		{"item_data": lucky_item},
		active_slots,
		registry,
		owner,
		slot_controller,
		effect_controller
	), "active pickup router should route passive/mythic field items into equipment inventory")
	_expect(active_slots.size() == 1, "passive pickup should not consume an active item slot")
	_expect(owner.lucky_coin_equipped, "passive pickup should auto-equip through mythic runtime")
	_expect(is_equal_approx(owner.lucky_coin_double_spawn_pct, 15.0), "passive pickup should preserve roll overrides")
	_expect(_inventory_has_item(mythic_runtime, "lucky_coin"), "passive pickup should be owned after routing")

	var gold_digger_item: Dictionary = mythic_catalog.build_item_by_name("gold_digger")
	gold_digger_item["rolls"] = {"gold_bonus_pct": 37.0}
	gold_digger_item = mythic_catalog.sync_roll_fields(gold_digger_item, false)
	gold_digger_item["name_prefix"] = "필드고정"
	gold_digger_item["quality_tier"] = "mid"
	gold_digger_item["qualified_display_name"] = "필드고정 골드디거"
	var gold_digger_field_item: Dictionary = {"item_data": gold_digger_item}
	_expect(router.store_field_item(
		gold_digger_field_item,
		active_slots,
		registry,
		owner,
		slot_controller,
		effect_controller
	), "passive pickup router should store Gold Digger from field data")
	var stored_gold_digger: Dictionary = _inventory_item_by_name(mythic_runtime, "gold_digger")
	_expect(str(stored_gold_digger.get("name_prefix", "")) == "필드고정", "passive pickup should preserve the field item's exact prefix")
	_expect(str(stored_gold_digger.get("qualified_display_name", "")) == "필드고정 골드디거", "inventory should preserve the qualified display name")
	var routed_gold_digger: Dictionary = gold_digger_field_item.get("item_data", {})
	_expect(str(routed_gold_digger.get("qualified_display_name", "")) == str(stored_gold_digger.get("qualified_display_name", "")), "stored field item should keep the exact inventory display identity")
	effect_controller.reset()
	_cleanup_mythic_runtime_owner(mythic_runtime, registry, owner)
	registry.mythic_runtime = null


func _verify_collect_field_item_routes() -> void:
	var active_catalog: Object = ActiveItemCatalog.new()
	var mythic_catalog: Object = MythicItemCatalog.new()
	var router: Object = ActiveItemPickupRouter.new()
	var slot_controller: Object = ActiveItemSlotController.new()
	var effect_controller: Object = ActiveItemEffectController.new()

	var active_owner := FakeOwner.new()
	var active_registry := FakeRegistry.new(MythicItemRuntime.new())
	root.add_child(active_owner)
	var banana_item: Dictionary = active_catalog.build_item_by_name("banana")
	_expect(router.collect_field_item_to_owner_slots(
		{"item_data": banana_item},
		active_owner,
		active_registry,
		slot_controller,
		effect_controller,
		Callable(self, "_record_pickup_feedback")
	), "pickup router should collect active boomerang pickups into owner slots")
	_expect(active_owner.active_item_slots.size() == 1, "boomerang active pickup should append owner active slot")
	_expect(str(active_owner.active_item_slots[0].get("name", "")) == "banana", "boomerang active pickup should preserve item data")
	_expect(_pickup_feedback_count == 1, "boomerang active pickup should trigger pickup feedback")

	var passive_owner := FakeOwner.new()
	var passive_runtime: Object = MythicItemRuntime.new()
	var passive_registry := FakeRegistry.new(passive_runtime)
	root.add_child(passive_owner)
	var lucky_item: Dictionary = mythic_catalog.build_item_by_name("lucky_coin")
	lucky_item["rolls"] = {"double_spawn_pct": 12.0}
	lucky_item = mythic_catalog.sync_roll_fields(lucky_item, false)
	_expect(router.collect_field_item_to_owner_slots(
		{"item_data": lucky_item},
		passive_owner,
		passive_registry,
		slot_controller,
		effect_controller,
		Callable(self, "_record_pickup_feedback")
	), "pickup router should collect passive boomerang pickups into inventory")
	_expect(passive_owner.active_item_slots.is_empty(), "boomerang passive pickup should not append active slot")
	_expect(passive_owner.lucky_coin_equipped, "boomerang passive pickup should auto-equip")
	_expect(_inventory_has_item(passive_runtime, "lucky_coin"), "boomerang passive pickup should be owned")
	_expect(_pickup_feedback_count == 2, "boomerang passive pickup should trigger pickup feedback")
	effect_controller.reset()
	_cleanup_mythic_runtime_owner(active_registry.mythic_runtime, active_registry, active_owner)
	_cleanup_mythic_runtime_owner(passive_runtime, passive_registry, passive_owner)
	active_registry.mythic_runtime = null
	passive_registry.mythic_runtime = null


func _verify_pickup_feedback_handoff() -> void:
	var active_catalog: Object = ActiveItemCatalog.new()
	var mythic_catalog: Object = MythicItemCatalog.new()
	var router: Object = ActiveItemPickupRouter.new()
	var feedback: Object = ActiveItemPickupFeedback.new()
	var effect_controller: Object = ActiveItemEffectController.new()
	var banana_item: Dictionary = active_catalog.build_item_by_name("banana")

	router.trigger_pickup_effect(
		{"item_data": banana_item, "position": Vector2(220.0, 310.0)},
		null,
		feedback,
		effect_controller
	)
	_expect(effect_controller.has_pickup_effect(), "pickup router should hand pickup feedback into the effect controller")
	effect_controller.reset()

	var passive_effect_controller: Object = ActiveItemEffectController.new()
	var gold_digger_item: Dictionary = mythic_catalog.build_item_by_name("gold_digger")
	gold_digger_item["name_prefix"] = "필드고정"
	gold_digger_item["quality_tier"] = "mid"
	gold_digger_item["qualified_display_name"] = "필드고정 골드디거"
	router.trigger_pickup_effect(
		{"item_data": gold_digger_item, "position": Vector2(240.0, 320.0)},
		null,
		feedback,
		passive_effect_controller
	)
	_expect(passive_effect_controller.pickup_effect.get("display_name", "") == "골드디거", "passive pickup effect should hide the quality prefix")
	passive_effect_controller.reset()


func _verify_mythic_pickup_starts_cinematic() -> void:
	var mythic_catalog: Object = MythicItemCatalog.new()
	var router: Object = ActiveItemPickupRouter.new()
	var slot_controller: Object = ActiveItemSlotController.new()
	var effect_controller: Object = ActiveItemEffectController.new()
	var runtime: Object = FakeCinematicMythicRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	root.add_child(owner)
	var cape_item: Dictionary = mythic_catalog.build_item_by_name("heavenly_cape")
	cape_item["rolls"] = {"cooldown_reduction": 12.0}
	cape_item = mythic_catalog.sync_roll_fields(cape_item, false)
	var before_pickup_count := _pickup_feedback_count

	_expect(router.collect_field_item_to_owner_slots(
		{"item_data": cape_item, "position": Vector2(260.0, 300.0)},
		owner,
		registry,
		slot_controller,
		effect_controller,
		Callable(self, "_record_pickup_feedback")
	), "mythic pickup should route into mythic runtime")
	_expect(runtime.is_acquisition_cinematic_active(), "mythic field pickup should start the acquisition cinematic")
	_expect(_pickup_feedback_count == before_pickup_count, "mythic field pickup should suppress the small pickup feedback popup")
	effect_controller.reset()
	_cleanup_mythic_runtime_owner(runtime, registry, owner)
	registry.mythic_runtime = null


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _clear_runtime_caches_for_test() -> void:
	ProjectResourceLoader.clear_caches()


func _cleanup_mythic_runtime_owner(runtime: Object, registry: Object, owner: Node) -> void:
	if runtime != null and runtime.has_method("reset_round"):
		runtime.reset_round(registry)
	if runtime != null:
		var cinematic: Variant = runtime.get("acquisition_cinematic")
		if cinematic != null:
			runtime.set("acquisition_cinematic", null)
		if cinematic is Node and is_instance_valid(cinematic):
			(cinematic as Node).free()
	if owner != null:
		owner.queue_free()


func _record_pickup_feedback(_field_item: Dictionary, _registry: Object) -> void:
	_pickup_feedback_count += 1


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	return not _inventory_item_by_name(runtime, item_name).is_empty()


func _inventory_item_by_name(runtime: Object, item_name: String) -> Dictionary:
	var snapshot: Dictionary = runtime.get_snapshot()
	var inventory: Array = snapshot.get("inventory_items", [])
	for item_value in inventory:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return item_value.duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
