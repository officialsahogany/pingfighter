extends SceneTree

const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
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
	var speedboots_equipped := false
	var speedboots_speed_bonus_pct := 0.0
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

	_expect(runtime.equip_item("speedgear", owner, registry, {}, false), "Speedgear should equip")
	_expect(str(owner.equipment_slots.get("belt", {}).get("name", "")) == "speedgear", "Speedgear should sync into the belt slot")
	_expect(owner.speedgear_equipped, "owner should expose Speedgear equipped state")
	_expect_close(owner.speedgear_turn_decel_multiplier, 2.5, "owner should sync Speedgear turn decel multiplier")
	_expect_close(runtime.get_player_speed_multiplier(), 1.0, "Speedgear should not change general movement speed")
	_expect_close(runtime.get_player_turn_decel_multiplier(), 2.5, "Speedgear should expose the Python turn-deceleration multiplier")

	var speedgear_config: Dictionary = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect_close(float(speedgear_config.get("paddle_speed", 0.0)), 6.0, "Speedgear should leave paddle speed unchanged")
	_expect_close(float(speedgear_config.get("paddle_max_speed", 0.0)), 6.0, "Speedgear should leave max speed unchanged")
	_expect_close(float(speedgear_config.get("paddle_accel", 0.0)), 0.5, "Speedgear should leave acceleration unchanged")
	_expect_close(float(speedgear_config.get("paddle_decel", 0.0)), 0.5, "Speedgear should leave idle deceleration unchanged")
	_expect_close(float(speedgear_config.get("paddle_turn_decel", 0.0)), 2.5, "Speedgear should boost only turn deceleration")
	_verify_turn_reversal(1.0, 2.5)

	_expect(runtime.unequip_item("speedgear", owner, registry), "Speedgear should unequip")
	_expect(not owner.speedgear_equipped, "owner should clear Speedgear state after unequip")
	_expect_close(runtime.get_player_turn_decel_multiplier(), 1.0, "turn-deceleration multiplier should be equip-gated")
	var base_config: Dictionary = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect_close(float(base_config.get("paddle_turn_decel", 0.0)), 1.0, "turn decel should return to base after unequip")

	_expect(runtime.equip_item("speedgear", owner, registry, {}, false), "Speedgear should re-equip")
	_expect(
		runtime.equip_item("speedboots", owner, registry, {"speed_bonus_pct": 10.0}, false),
		"Speedboots should equip beside Speedgear"
	)
	var combo_config: Dictionary = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect_close(float(combo_config.get("paddle_speed", 0.0)), 6.6, "Speedboots should still own the general speed lane")
	_expect_close(float(combo_config.get("paddle_turn_decel", 0.0)), 2.75, "Speedgear should stack on top of the existing speed multiplier lane")

	print("speedgear_port_smoke: ok")
	quit(0)


func _verify_catalog(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("speedgear")
	_expect(not item_data.is_empty(), "Speedgear should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "보정벨트", "Speedgear should keep the Python Korean display name")
	_expect(str(item_data.get("type", "")) == "passive", "Speedgear should be passive")
	_expect(str(item_data.get("slot", "")) == "belt", "Speedgear should use the belt slot")
	_expect_close(float(item_data.get("chance", 0.0)), 0.005, "Speedgear field chance should match Python")
	_expect(catalog.get_roll_options("speedgear").is_empty(), "Speedgear should not expose roll options")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "speedgear"), "Speedgear should be in the field spawn pool")
	_expect(_array_has_item(catalog.get_debug_items(), "speedgear"), "Speedgear should be in the debug passive item list")
	_expect_icon_asset(item_data)


func _expect_icon_asset(item_data: Dictionary) -> void:
	var icon_path: String = str(item_data.get("icon_path", ""))
	var icon: Texture2D = ProjectResourceLoader.load_texture(icon_path)
	_expect(icon != null, "Speedgear static icon should load")
	if icon != null:
		_expect(icon.get_width() >= 32 and icon.get_height() >= 32, "Speedgear icon should have usable source resolution")

	var image: Image = icon.get_image()
	_expect(image != null, "Speedgear icon image should be readable")
	if image == null:
		return
	var width := image.get_width()
	var height := image.get_height()
	var corners := [
		Vector2i(0, 0),
		Vector2i(width - 1, 0),
		Vector2i(0, height - 1),
		Vector2i(width - 1, height - 1),
	]
	for corner in corners:
		_expect(image.get_pixelv(corner).a <= 0.01, "Speedgear icon corners should remain transparent")
	var bbox: Rect2i = _alpha_bbox(image)
	_expect(bbox.position.x > 0 and bbox.position.y > 0, "Speedgear icon alpha bbox should not touch the top-left edge")
	_expect(bbox.end.x < width and bbox.end.y < height, "Speedgear icon alpha bbox should not touch the bottom-right edge")


func _verify_turn_reversal(base_turn_decel: float, boosted_turn_decel: float) -> void:
	var base_speed := _speed_after_left_turn(base_turn_decel)
	var boosted_speed := _speed_after_left_turn(boosted_turn_decel)
	_expect_close(base_speed, 1.5, "base reversal should keep rightward momentum after one frame")
	_expect_close(boosted_speed, 0.0, "Speedgear reversal should shed the same momentum in one frame")
	_expect(boosted_speed < base_speed, "Speedgear should reverse direction faster than the base config")


func _speed_after_left_turn(turn_decel: float) -> float:
	var movement_state: Object = PlayerMovementState.new()
	var result: Dictionary = movement_state.update_horizontal(
		1.0 / 60.0,
		Vector2(300.0, 700.0),
		3.0,
		-1.0,
		0.0,
		760.0,
		155.0,
		{
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": turn_decel,
		}
	)
	return float(result.get("player_speed", 0.0))


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
