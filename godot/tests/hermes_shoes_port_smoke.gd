extends SceneTree

const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
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
	var hermes_shoes_equipped := false
	var hermes_shoes_active := false
	var hermes_shoes_speed_bonus_pct := 0.0
	var hermes_shoes_speed_multiplier := 1.0
	var hermes_shoes_context: Dictionary = {}
	var speedboots_equipped := false
	var speedboots_speed_bonus_pct := 0.0

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
			"paddle_speed": 10.0,
			"paddle_max_speed": 20.0,
			"paddle_accel": 1.0,
			"paddle_decel": 2.0,
			"paddle_turn_decel": 3.0,
			"paddle_width": 155.0,
		}


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("hermes_shoes")
	_expect(not item_data.is_empty(), "Hermes Shoes should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "헤르메스의 신발", "Hermes Shoes should keep Korean display name")
	_expect(str(item_data.get("slot", "")) == "shoes", "Hermes Shoes should use the shoes slot")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "Hermes Shoes should expose 32 smooth icon frames")
	_expect_original_icon_assets(item_data, "Hermes Shoes")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "hermes_shoes"), "Hermes Shoes should be in the field spawn pool")
	_expect_rolls(catalog)

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	_expect(
		runtime.equip_item("hermes_shoes", owner, registry, {"speed_bonus": 50.0}, false),
		"Hermes Shoes should equip"
	)
	_expect(str(owner.equipment_slots.get("shoes", {}).get("name", "")) == "hermes_shoes", "Hermes Shoes should sync into shoes slot")
	_expect(owner.hermes_shoes_equipped, "owner should expose Hermes equipped state")
	_expect(owner.hermes_shoes_active, "owner should expose Hermes active state")
	_expect_close(owner.hermes_shoes_speed_bonus_pct, 50.0, "owner should sync Hermes speed bonus")
	_expect_close(runtime.get_hermes_shoes_speed_multiplier(), 1.5, "Hermes speed multiplier should match 50 percent")
	_expect_close(runtime.get_player_speed_multiplier(), 1.5, "player speed multiplier should include Hermes")

	var config_builder: Object = BattleScenePlayerControlConfigBuilder.new()
	var config: Dictionary = config_builder.build_config(owner, registry, "smasher", FakeControlContextBuilder.new())
	_expect_close(float(config.get("paddle_speed", 0.0)), 15.0, "control config should receive Hermes speed multiplier")
	_expect_close(float(config.get("paddle_max_speed", 0.0)), 30.0, "control max speed should receive Hermes speed multiplier")

	runtime.update(owner, registry, 1.0 / 60.0)
	owner.player_pos.x += 12.0
	runtime.update(owner, registry, 1.0 / 60.0)
	var hermes_context: Dictionary = runtime.get_hermes_shoes_context()
	_expect(int(hermes_context.get("trail_count", 0)) >= 1, "Hermes should keep a short movement trail after paddle motion")

	_expect(
		runtime.equip_item("speedboots", owner, registry, {"speed_bonus_pct": 10.0}, false),
		"Speedboots should equip into the same shoes slot"
	)
	_expect(str(owner.equipment_slots.get("shoes", {}).get("name", "")) == "speedboots", "Speedboots should replace Hermes in the shoes slot")
	_expect(not owner.hermes_shoes_equipped, "Hermes should clear equipped state after shoes-slot replacement")
	_expect_close(runtime.get_player_speed_multiplier(), 1.1, "player speed multiplier should fall back to Speedboots after replacement")

	print("hermes_shoes_port_smoke: ok")
	quit(0)


func _expect_rolls(catalog: Object) -> void:
	var rolls: Array = catalog.get_roll_options("hermes_shoes")
	_expect(rolls.size() == 1, "Hermes Shoes should expose one roll option")
	var roll: Dictionary = rolls[0] if rolls[0] is Dictionary else {}
	_expect(str(roll.get("key", "")) == "speed_bonus", "Hermes roll key should be speed_bonus")
	_expect_close(float(roll.get("min", 0.0)), 30.0, "Hermes speed min should match Python")
	_expect_close(float(roll.get("max", 0.0)), 60.0, "Hermes speed max should match Python")
	_expect_close(float(roll.get("default", 0.0)), 50.0, "Hermes speed default should match Python")


func _expect_original_icon_assets(item_data: Dictionary, item_label: String) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "%s static icon should load" % item_label)
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "%s static icon should be the original 32px render" % item_label)

	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null, "%s animated icon sheet should load" % item_label)
	if sheet != null:
		_expect(sheet.get_width() == 1024 and sheet.get_height() == 32, "%s animated icon sheet should be the smooth 32-frame render" % item_label)


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
