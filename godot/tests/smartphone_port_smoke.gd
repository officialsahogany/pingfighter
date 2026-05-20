extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
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
	var smartphone_equipped := false
	var smartphone_active := false
	var smartphone_count := 0
	var smartphone_auto_cooldown_frames := 0.0
	var smartphone_last_auto_item := ""
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var ball_active := true
	var ball_pos := Vector2(420.0, 710.0)
	var ball_vel := Vector2(1.0, 22.0)
	var player_pos := Vector2(20.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_collision_cooldown := 0.0
	var boss_collision_cooldown := 0.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	seed(24680)
	var passive_catalog: Object = MythicItemCatalog.new()
	var active_catalog: Object = ActiveItemCatalog.new()
	var item_data: Dictionary = passive_catalog.build_item_by_name("smartphone")
	_expect(not item_data.is_empty(), "Smartphone should build from catalog")
	_expect(str(item_data.get("slot", "")) == "arm", "Smartphone should use the shared arm slot")
	_expect(str(item_data.get("display_name", "")) == "스마트폰", "Smartphone should expose Korean display name")
	_expect(is_equal_approx(float(item_data.get("chance", 0.0)), 0.004), "Smartphone should keep Python field chance")
	_expect(passive_catalog.get_roll_options("smartphone").is_empty(), "Smartphone should not have roll options")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Smartphone icon should load")
	_expect(_array_has_item(passive_catalog.get_field_spawn_items(), "smartphone"), "Smartphone should be in passive field-spawn list")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var registry := FakeRegistry.new({
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": runtime,
	})
	var first_smartphone_index: int = runtime.acquire_item("smartphone", owner, registry, {}, true, false)
	var second_smartphone_index: int = runtime.acquire_item("smartphone", owner, registry, {}, true, false)
	_expect(first_smartphone_index >= 0, "first Smartphone should acquire and equip")
	_expect(second_smartphone_index >= 0, "second Smartphone should acquire into inventory")
	_expect(owner.equipment_slots.has("left_arm"), "first Smartphone should resolve to left arm")
	_expect(not owner.equipment_slots.has("right_arm"), "second Smartphone should not auto-equip into the other arm")
	_expect(owner.smartphone_equipped and owner.smartphone_active, "owner should expose Smartphone active state")
	_expect(owner.smartphone_count == 1, "runtime should count only one equipped Smartphone")
	_expect(_count_inventory_item(owner.passive_item_inventory, "smartphone") == 2, "both Smartphones should remain in passive inventory")
	_expect(not runtime.equip_inventory_item(second_smartphone_index, owner, registry), "manual equip should reject a second Smartphone while one is equipped")
	_expect(owner.smartphone_count == 1 and not owner.equipment_slots.has("right_arm"), "rejected second Smartphone should leave one equipped copy")

	var pickup_runtime: Object = MythicItemRuntime.new()
	var pickup_owner := FakeOwner.new()
	var pickup_registry := FakeRegistry.new({"mythic_item_runtime": pickup_runtime})
	var pickup_active_runtime: Object = ActiveItemRuntime.new()
	var active_slots: Array = []
	_expect(
		pickup_active_runtime._store_active_item({"item_data": item_data}, active_slots, pickup_registry, pickup_owner),
		"field Smartphone pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "Smartphone pickup should not consume an active slot")
	_expect(pickup_owner.smartphone_equipped, "field pickup should auto-equip Smartphone")

	var recovery_runtime: Object = MythicItemRuntime.new()
	var recovery_active: Object = ActiveItemRuntime.new()
	var recovery_owner := FakeOwner.new()
	recovery_owner.special_gauge = 100.0
	recovery_owner.active_item_slots = [
		active_catalog.build_item_by_name("life_elixir"),
		active_catalog.build_item_by_name("gauge_charge"),
	]
	var recovery_registry := FakeRegistry.new({
		"active_item_runtime": recovery_active,
		"mythic_item_runtime": recovery_runtime,
	})
	_expect(recovery_runtime.equip_item("smartphone", recovery_owner, recovery_registry, {}, false), "recovery runtime should equip Smartphone")
	recovery_runtime.update(recovery_owner, recovery_registry, 1.0 / 60.0)
	_expect(is_equal_approx(recovery_owner.special_gauge, 500.0), "Smartphone should use Life Elixir first when gauge is low")
	_expect(recovery_owner.active_item_slots.size() == 1, "Life Elixir should be consumed by Smartphone")
	_expect(str(recovery_owner.active_item_slots[0].get("name", "")) == "gauge_charge", "Energy Drink should remain after Life Elixir priority")
	_expect(recovery_owner.smartphone_last_auto_item == "life_elixir", "Smartphone should record the recovery item it used")

	var gauge_runtime: Object = MythicItemRuntime.new()
	var gauge_active: Object = ActiveItemRuntime.new()
	var gauge_owner := FakeOwner.new()
	gauge_owner.special_gauge = 100.0
	gauge_owner.active_item_slots = [active_catalog.build_item_by_name("gauge_charge")]
	var gauge_registry := FakeRegistry.new({
		"active_item_runtime": gauge_active,
		"mythic_item_runtime": gauge_runtime,
	})
	_expect(gauge_runtime.equip_item("smartphone", gauge_owner, gauge_registry, {}, false), "gauge fallback runtime should equip Smartphone")
	gauge_runtime.update(gauge_owner, gauge_registry, 1.0 / 60.0)
	_expect(is_equal_approx(gauge_owner.special_gauge, 320.0), "Smartphone should use Energy Drink when Life Elixir is absent")

	var defense_runtime: Object = MythicItemRuntime.new()
	var defense_active: Object = ActiveItemRuntime.new()
	var defense_owner := FakeOwner.new()
	defense_owner.active_item_slots = [
		active_catalog.build_item_by_name("stopwatch"),
		active_catalog.build_item_by_name("holy_barrier"),
	]
	var defense_registry := FakeRegistry.new({
		"active_item_runtime": defense_active,
		"mythic_item_runtime": defense_runtime,
	})
	_expect(defense_runtime.equip_item("smartphone", defense_owner, defense_registry, {}, false), "defense runtime should equip Smartphone")
	defense_runtime.update(defense_owner, defense_registry, 1.0 / 60.0)
	var stopwatch_context: Dictionary = defense_active.get_ball_collision_context()
	_expect(bool(stopwatch_context.get("stopwatch_score_blocking", false)), "Smartphone should activate Stopwatch before a bottom loss")
	_expect(_get_vector2(stopwatch_context.get("stopwatch_original_ball_vel", Vector2.ZERO)).y < 0.0, "Smartphone Stopwatch recovery should be forced upward")
	_expect(defense_owner.active_item_slots.size() == 1 and str(defense_owner.active_item_slots[0].get("name", "")) == "holy_barrier", "Stopwatch should be consumed before Holy Barrier")
	_expect(defense_owner.smartphone_last_auto_item == "stopwatch", "Smartphone should prefer Stopwatch for defense")

	var barrier_runtime: Object = MythicItemRuntime.new()
	var barrier_active: Object = ActiveItemRuntime.new()
	var barrier_owner := FakeOwner.new()
	barrier_owner.active_item_slots = [active_catalog.build_item_by_name("holy_barrier")]
	var barrier_registry := FakeRegistry.new({
		"active_item_runtime": barrier_active,
		"mythic_item_runtime": barrier_runtime,
	})
	_expect(barrier_runtime.equip_item("smartphone", barrier_owner, barrier_registry, {}, false), "Holy Barrier fallback runtime should equip Smartphone")
	barrier_runtime.update(barrier_owner, barrier_registry, 1.0 / 60.0)
	_expect(bool(barrier_active.get_ball_collision_context().get("holy_barrier_active", false)), "Smartphone should activate Holy Barrier when Stopwatch is absent")
	_expect(barrier_owner.active_item_slots.is_empty(), "Holy Barrier fallback should be consumed")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("smartphone"), "field spawn candidates should include Smartphone")
	_expect(
		_array_has_item(field_spawn_controller._build_spawn_candidates(defense_registry), "smartphone"),
		"owned Smartphone should remain spawnable for duplicate inventory pickup"
	)

	print("smartphone_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _count_inventory_item(items: Array, item_name: String) -> int:
	var count := 0
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			count += 1
	return count


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
