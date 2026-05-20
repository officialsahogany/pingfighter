extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var star_detector_equipped := false
	var star_detector_active := false
	var star_detector_star_bonus_pct := 0.0
	var star_detector_bonus_chance := 0.0

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
	seed(24680)

	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("star_detector")
	_expect(not item_data.is_empty(), "Star Detector should build from catalog")
	_expect(str(item_data.get("slot", "")) == "accessory", "Star Detector should use accessory slots")
	_expect(str(item_data.get("display_name", "")) != "", "Star Detector should expose a display name")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Star Detector icon should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "star_detector"), "Star Detector should be in passive field-spawn list")
	_expect(_catalog_item_has_chance(catalog.get_field_spawn_items(), "star_detector"), "Star Detector should have non-zero field chance")

	var roll_options: Array = catalog.get_roll_options("star_detector")
	_expect(roll_options.size() == 1, "Star Detector should have one roll option")
	var option: Dictionary = roll_options[0]
	_expect(str(option.get("key", "")) == "star_bonus_pct", "Star Detector roll key should match Python reference")
	_expect(is_equal_approx(float(option.get("min", 0.0)), 10.0), "Star Detector roll min should be 10%")
	_expect(is_equal_approx(float(option.get("max", 0.0)), 20.0), "Star Detector roll max should be 20%")
	_expect(is_equal_approx(float(option.get("default", 0.0)), 15.0), "Star Detector default roll should be 15%")

	var pickup_runtime: Object = MythicItemRuntime.new()
	var pickup_owner := FakeOwner.new()
	var pickup_registry := FakeRegistry.new(pickup_runtime)
	var active_runtime: Object = ActiveItemRuntime.new()
	var pickup_item: Dictionary = item_data.duplicate(true)
	pickup_item["rolls"] = {"star_bonus_pct": 20.0}
	pickup_item = catalog.sync_roll_fields(pickup_item, false)
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": pickup_item}, active_slots, pickup_registry, pickup_owner),
		"field Star Detector pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "Star Detector pickup should not consume an active slot")
	_expect(pickup_owner.star_detector_equipped, "field pickup should auto-equip Star Detector")
	_expect(is_equal_approx(pickup_owner.star_detector_star_bonus_pct, 20.0), "field pickup should preserve Star Detector roll")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	_expect(runtime.equip_item("star_detector", owner, registry, {"star_bonus_pct": 100.0}, false), "Star Detector should equip")
	_expect(owner.equipment_slots.has("accessory1"), "Star Detector should resolve into the first accessory slot")
	_expect(owner.star_detector_equipped, "owner should expose Star Detector equipped")
	_expect(owner.star_detector_active, "owner should expose Star Detector active")
	_expect(is_equal_approx(owner.star_detector_star_bonus_pct, 100.0), "owner should sync Star Detector star bonus pct")
	_expect(is_equal_approx(owner.star_detector_bonus_chance, 1.0), "owner should sync Star Detector bonus chance")
	_expect(runtime.roll_star_detector_bonus_drop_count() == 1, "100% Star Detector roll should force one bonus drop")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("star_detector"), "field spawn candidates should include Star Detector before ownership filtering")
	_expect(
		not _array_has_item(field_spawn_controller._build_spawn_candidates(registry), "star_detector"),
		"owned Star Detector should be excluded from normal field-spawn candidates"
	)

	var balloon_event: Object = Stage1BalloonEvent.new()
	balloon_event.spawn_starpoint_drop(Vector2(320.0, 320.0), "test", {"mythic_item_runtime": runtime})
	_expect(balloon_event.starpoint_drops.size() == 2, "100% Star Detector should add exactly one bonus starpoint drop")
	_expect(_count_star_detector_bonus_drops(balloon_event.starpoint_drops) == 1, "bonus drop should be marked as Star Detector bonus")

	print("star_detector_port_smoke: ok")
	quit(0)


func _count_star_detector_bonus_drops(drops: Array) -> int:
	var count := 0
	for drop_value in drops:
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		if bool(drop.get("star_detector_bonus", false)):
			count += 1
	return count


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _catalog_item_has_chance(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return float(item.get("chance", 0.0)) > 0.0
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
