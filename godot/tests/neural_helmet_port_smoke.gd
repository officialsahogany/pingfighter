extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var special_gauge := 500.0
	var neural_helmet_equipped := false
	var neural_helmet_aipill_gauge_reduction := 0.0
	var neural_helmet_aipill_spawn_bonus_pct := 0.0
	var aipill_gauge_drain := 90.0
	var aipill_item_spawn_multiplier := 1.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_runtime: Object

	func _init(runtime: Object) -> void:
		mythic_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		return null


func _init() -> void:
	var mythic_catalog: Object = MythicItemCatalog.new()
	var _active_catalog: Object = ActiveItemCatalog.new()
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)

	var item_data: Dictionary = mythic_catalog.build_item_by_name("neural_helmet")
	_expect(not item_data.is_empty(), "Neural Helmet should build from the passive catalog")
	_expect(str(item_data.get("slot", "")) == "head", "Neural Helmet should use the head slot")
	_expect(str(item_data.get("effect", "")) == "neural_helmet", "Neural Helmet effect id should be stable")
	_expect(abs(float(item_data.get("chance", 0.0)) - 0.005) <= 0.000001, "Neural Helmet field chance should match Python")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Neural Helmet icon should load")
	_expect(_array_has_item(mythic_catalog.get_field_spawn_items(), "neural_helmet"), "Neural Helmet should spawn as a passive field item")
	_expect(_roll_option_has_range(mythic_catalog, "aipill_gauge_reduction", 40.0, 60.0), "AI Pill gauge reduction roll should match Python")
	_expect(_roll_option_has_range(mythic_catalog, "aipill_spawn_bonus_pct", 150.0, 300.0), "AI Pill spawn roll should match Python")

	_expect(runtime.equip_item("neural_helmet", owner, registry, {
		"aipill_gauge_reduction": 60.0,
		"aipill_spawn_bonus_pct": 300.0,
	}, false), "Neural Helmet should equip into the head slot")
	_expect(owner.equipment_slots.has("head"), "Neural Helmet should sync into the head slot")
	_expect(str(owner.equipment_slots["head"].get("name", "")) == "neural_helmet", "Neural Helmet should occupy head")
	_expect(owner.neural_helmet_equipped, "owner should expose Neural Helmet equipped")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("neural_helmet_equipped", false)), "snapshot should expose Neural Helmet equipped")
	_expect_close(float(snapshot.get("neural_helmet_aipill_gauge_reduction", 0.0)), 60.0, "snapshot should expose AI Pill gauge reduction")
	_expect_close(float(snapshot.get("neural_helmet_aipill_spawn_bonus_pct", 0.0)), 300.0, "snapshot should expose AI Pill spawn bonus")
	_expect_close(float(snapshot.get("aipill_gauge_drain", 0.0)), 30.0, "AI Pill drain should be reduced from 90 to 30")
	_expect_close(float(snapshot.get("aipill_item_spawn_multiplier", 0.0)), 4.0, "AI Pill spawn multiplier should be 1 + 300%")
	_expect(runtime.should_cancel_aipill_on_direction_key(), "Neural Helmet should allow direction-key AI Pill cancel")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var aipill_candidate: Dictionary = _find_item(field_spawn_controller._build_spawn_candidates(registry), "aipill")
	_expect(not aipill_candidate.is_empty(), "AI Pill should remain in active field candidates")
	_expect_close(float(aipill_candidate.get("chance", 0.0)), 0.006 * 4.0, "AI Pill field chance should receive Neural Helmet spawn multiplier")

	var effect_controller: Object = ActiveItemEffectController.new()
	effect_controller.aipill_active = true
	effect_controller.aipill_phase = 1.25
	var reduced_gauge: float = effect_controller.apply_aipill_guard_drain(
		100.0,
		{"selected_character_type": "smasher"},
		{"mythic_item_runtime": runtime}
	)
	_expect_close(reduced_gauge, 70.0, "AI Pill guard drain should subtract reduced 30 gauge")
	_expect(effect_controller.aipill_active, "AI Pill should remain active while gauge remains")
	_expect(effect_controller.cancel_aipill_if_neural_helmet_direction_pressed(runtime, true), "direction input should cancel AI Pill while Neural Helmet is equipped")
	_expect(not effect_controller.aipill_active, "direction cancel should clear AI Pill state")

	var no_helmet_runtime: Object = MythicItemRuntime.new()
	effect_controller.aipill_active = true
	_expect(not effect_controller.cancel_aipill_if_neural_helmet_direction_pressed(no_helmet_runtime, true), "direction input should not cancel AI Pill without Neural Helmet")
	_expect(effect_controller.aipill_active, "AI Pill should stay active without Neural Helmet")

	var active_runtime: Object = ActiveItemRuntime.new()
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": item_data}, active_slots, registry, owner),
		"Neural Helmet field pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "Neural Helmet pickup should not consume active slots")
	_expect(_inventory_has_item(runtime, "neural_helmet"), "Neural Helmet should be owned after passive pickup")

	_expect(runtime.equip_item("bulletproof_hat", owner, registry, {"stun_resist_pct": 20.0}, false), "another head item should replace Neural Helmet")
	_expect(str(owner.equipment_slots["head"].get("name", "")) == "bulletproof_hat", "head slot replacement should work")
	_expect(not bool(runtime.get_snapshot().get("neural_helmet_equipped", true)), "replaced Neural Helmet should stop applying effects")

	print("neural_helmet_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	return not _find_item(items, item_name).is_empty()


func _find_item(items: Array, item_name: String) -> Dictionary:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return item_value
	return {}


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	var snapshot: Dictionary = runtime.get_snapshot()
	for item_value in snapshot.get("inventory_items", []):
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _roll_option_has_range(catalog: Object, option_key: String, minimum: float, maximum: float) -> bool:
	for option_value in catalog.get_roll_options("neural_helmet"):
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		if str(option.get("key", "")) != option_key:
			continue
		return (
			abs(float(option.get("min", 0.0)) - minimum) <= 0.000001
			and abs(float(option.get("max", 0.0)) - maximum) <= 0.000001
		)
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
