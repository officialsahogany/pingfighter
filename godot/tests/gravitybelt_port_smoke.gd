extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_speed_multiplier := 1.0
	var player_turn_decel_multiplier := 1.0
	var gravitybelt_equipped := false
	var gravitybelt_active := false
	var gravitybelt_instant_movement := false
	var speedgear_equipped := false
	var speedgear_turn_decel_multiplier := 1.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_item_runtime: Object

	func _init(runtime: Object) -> void:
		mythic_item_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


class FakeControlContextBuilder:
	func build_player_control_config(_character_type: String) -> Dictionary:
		return {
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
			"paddle_width": 155.0,
		}


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	_verify_catalog(catalog)

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	var config_builder: Object = BattleScenePlayerControlConfigBuilder.new()

	_expect(runtime.equip_item("gravitybelt", owner, registry, {}, false), "Gravity Belt should equip")
	_expect(str(owner.equipment_slots.get("belt", {}).get("name", "")) == "gravitybelt", "Gravity Belt should sync into the belt slot")
	_expect(owner.gravitybelt_equipped, "owner should expose Gravity Belt equipped state")
	_expect(owner.gravitybelt_active, "owner should expose Gravity Belt active state")
	_expect(owner.gravitybelt_instant_movement, "owner should expose instant movement flag")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("gravitybelt_instant_movement", false)), "snapshot should expose instant movement flag")

	var config: Dictionary = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect(bool(config.get("gravitybelt_instant_movement", false)), "control config should receive Gravity Belt instant movement")
	_expect_close(float(config.get("paddle_turn_decel", 0.0)), 1.0, "Gravity Belt should not need a turn-decel multiplier")
	_verify_instant_movement(config)

	_expect(runtime.equip_item("speedgear", owner, registry, {}, false), "Speedgear should replace Gravity Belt in the belt slot")
	_expect(str(owner.equipment_slots.get("belt", {}).get("name", "")) == "speedgear", "Speedgear should own the belt slot after replacement")
	_expect(not owner.gravitybelt_equipped, "Gravity Belt state should clear after belt-slot replacement")
	_expect(owner.speedgear_equipped, "Speedgear should become equipped after replacement")
	config = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect(not bool(config.get("gravitybelt_instant_movement", false)), "Gravity Belt flag should clear after replacement")
	_expect_close(float(config.get("paddle_turn_decel", 0.0)), 2.5, "Speedgear turn decel should return after Gravity Belt replacement")

	var field_runtime: Object = MythicItemRuntime.new()
	var field_owner := FakeOwner.new()
	var field_registry := FakeRegistry.new(field_runtime)
	var active_runtime: Object = ActiveItemRuntime.new()
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": catalog.build_item_by_name("gravitybelt")}, active_slots, field_registry, field_owner),
		"field Gravity Belt pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "field Gravity Belt pickup should not occupy an active item slot")
	_expect(field_owner.gravitybelt_active, "field Gravity Belt pickup should activate instant movement")

	print("gravitybelt_port_smoke: ok")
	quit(0)


func _verify_catalog(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("gravitybelt")
	_expect(not item_data.is_empty(), "Gravity Belt should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "무중력벨트", "Gravity Belt should keep Korean display name")
	_expect(str(item_data.get("type", "")) == "passive", "Gravity Belt should be passive")
	_expect(str(item_data.get("slot", "")) == "belt", "Gravity Belt should use the belt slot")
	_expect_close(float(item_data.get("chance", 0.0)), 0.002, "Gravity Belt field chance should match Python")
	_expect(catalog.get_roll_options("gravitybelt").is_empty(), "Gravity Belt should not expose roll options")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "gravitybelt"), "Gravity Belt should be in the field spawn pool")
	_expect(_array_has_item(catalog.get_debug_items(), "gravitybelt"), "Gravity Belt should be in the debug passive item list")
	_expect_icon_asset(item_data)


func _verify_instant_movement(config: Dictionary) -> void:
	var movement_state: Object = PlayerMovementState.new()
	var right_result: Dictionary = movement_state.update_horizontal(
		1.0 / 60.0,
		Vector2(300.0, 700.0),
		-3.0,
		1.0,
		0.0,
		760.0,
		155.0,
		config
	)
	_expect_close(float(right_result.get("player_speed", 0.0)), 6.0, "Gravity Belt should instantly switch to right max speed")
	var stop_result: Dictionary = movement_state.update_horizontal(
		1.0 / 60.0,
		Vector2(300.0, 700.0),
		6.0,
		0.0,
		0.0,
		760.0,
		155.0,
		config
	)
	_expect_close(float(stop_result.get("player_speed", 0.0)), 0.0, "Gravity Belt should stop immediately when input is released")


func _expect_icon_asset(item_data: Dictionary) -> void:
	var icon_path: String = str(item_data.get("icon_path", ""))
	var icon: Texture2D = ProjectResourceLoader.load_texture(icon_path)
	_expect(icon != null, "Gravity Belt static icon should load")
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "Gravity Belt icon should be the padded 32px runtime render")

	var image: Image = icon.get_image()
	_expect(image != null, "Gravity Belt icon image should be readable")
	if image == null:
		return
	for corner in [Vector2i(0, 0), Vector2i(31, 0), Vector2i(0, 31), Vector2i(31, 31)]:
		_expect(image.get_pixelv(corner).a <= 0.01, "Gravity Belt icon corners should remain transparent")
	var bbox: Rect2i = _alpha_bbox(image)
	_expect(bbox.position.x > 0 and bbox.position.y > 0, "Gravity Belt icon alpha bbox should not touch the top-left edge")
	_expect(bbox.end.x < image.get_width() and bbox.end.y < image.get_height(), "Gravity Belt icon alpha bbox should not touch the bottom-right edge")


func _alpha_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var field_item: Dictionary = item_value if item_value is Dictionary else {}
		if str(field_item.get("name", "")) == item_name:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
