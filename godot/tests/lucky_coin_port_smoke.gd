extends SceneTree

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
	var accessory_slot_count := 2
	var lucky_coin_equipped := false
	var lucky_coin_active := false
	var lucky_coin_double_spawn_pct := 0.0
	var lucky_coin_double_spawn_chance := 0.0

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var lucky_spawn_count := 0
	var active_item_count := 0

	func play_lucky_coin_spawn() -> void:
		lucky_spawn_count += 1

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	var mythic_runtime: Object
	var game_audio: Object

	func _init(runtime: Object, audio: Object = null) -> void:
		mythic_runtime = runtime
		game_audio = audio

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		if key == "game_audio":
			return game_audio
		return null


func _init() -> void:
	seed(12345)

	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("lucky_coin")
	_expect(not item_data.is_empty(), "Lucky Coin should build from catalog")
	_expect(str(item_data.get("slot", "")) == "accessory", "Lucky Coin should use accessory slots")
	_expect(str(item_data.get("display_name", "")) == "럭키코인", "Lucky Coin should keep Korean display name")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Lucky Coin icon should load")
	_expect(ResourceLoader.exists("res://assets/sounds/lucky_coin_spawn.wav"), "Lucky Coin spawn sound should exist")
	_expect(ResourceLoader.load("res://assets/sounds/lucky_coin_spawn.wav") != null, "Lucky Coin spawn sound should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "lucky_coin"), "Lucky Coin should be in passive field-spawn list")
	_expect(_catalog_item_has_chance(catalog.get_field_spawn_items(), "lucky_coin"), "Lucky Coin should have non-zero field chance")

	var roll_options: Array = catalog.get_roll_options("lucky_coin")
	_expect(roll_options.size() == 1, "Lucky Coin should have one roll option")
	var option: Dictionary = roll_options[0]
	_expect(str(option.get("key", "")) == "double_spawn_pct", "Lucky Coin roll key should match Python reference")
	_expect(is_equal_approx(float(option.get("min", 0.0)), 5.0), "Lucky Coin roll min should be 5%")
	_expect(is_equal_approx(float(option.get("max", 0.0)), 15.0), "Lucky Coin roll max should be 15%")
	_expect(is_equal_approx(float(option.get("default", 0.0)), 10.0), "Lucky Coin default roll should be 10%")

	var pickup_runtime: Object = MythicItemRuntime.new()
	var pickup_owner := FakeOwner.new()
	var pickup_registry := FakeRegistry.new(pickup_runtime, FakeAudio.new())
	var active_runtime: Object = ActiveItemRuntime.new()
	var pickup_item: Dictionary = item_data.duplicate(true)
	pickup_item["rolls"] = {"double_spawn_pct": 15.0}
	pickup_item = catalog.sync_roll_fields(pickup_item, false)
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": pickup_item}, active_slots, pickup_registry, pickup_owner),
		"field Lucky Coin pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "Lucky Coin pickup should not consume an active slot")
	_expect(pickup_owner.lucky_coin_equipped, "field pickup should auto-equip Lucky Coin")
	_expect(is_equal_approx(pickup_owner.lucky_coin_double_spawn_pct, 15.0), "field pickup should preserve Lucky Coin roll")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, audio)
	_expect(runtime.equip_item("lucky_coin", owner, registry, {"double_spawn_pct": 100.0}, false), "Lucky Coin should equip")
	_expect(owner.equipment_slots.has("accessory1"), "Lucky Coin should resolve into the first accessory slot")
	_expect(owner.lucky_coin_equipped, "owner should expose Lucky Coin equipped")
	_expect(owner.lucky_coin_active, "owner should expose Lucky Coin active")
	_expect(is_equal_approx(owner.lucky_coin_double_spawn_pct, 100.0), "owner should sync Lucky Coin double spawn pct")
	_expect(is_equal_approx(owner.lucky_coin_double_spawn_chance, 1.0), "owner should sync Lucky Coin double spawn chance")
	_expect(runtime.should_lucky_coin_double_spawn(), "100% Lucky Coin roll should force double spawn")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("lucky_coin"), "field spawn candidates should include Lucky Coin before ownership filtering")
	_expect(
		not _array_has_item(field_spawn_controller._build_spawn_candidates(registry), "lucky_coin"),
		"owned Lucky Coin should be excluded from normal field-spawn candidates"
	)

	field_spawn_controller._queue_item_after_portal(registry)
	var pending_items: Array = field_spawn_controller.get_pending_spawn_items()
	_expect(pending_items.size() == 2, "100% Lucky Coin should queue the main item plus one bonus item")
	var bonus_item: Dictionary = _find_lucky_bonus_pending_item(pending_items)
	_expect(not bonus_item.is_empty(), "Lucky Coin bonus pending item should be marked")
	var bonus_item_data: Dictionary = bonus_item.get("item_data", {})
	_expect(str(bonus_item_data.get("name", "")) != "lucky_coin", "Lucky Coin bonus should not spawn another Lucky Coin")
	_expect(is_equal_approx(float(bonus_item.get("lucky_glow_timer", -1.0)), 0.0), "Lucky Coin bonus should carry glow state")
	_expect(field_spawn_controller.get_item_spawn_portals().size() == 2, "Lucky Coin bonus should get its own spawn portal")
	_expect(audio.lucky_spawn_count == 1, "Lucky Coin bonus should play the dedicated spawn cue")

	print("lucky_coin_port_smoke: ok")
	quit(0)


func _find_lucky_bonus_pending_item(pending_items: Array) -> Dictionary:
	for pending_value in pending_items:
		var pending: Dictionary = pending_value if pending_value is Dictionary else {}
		var field_item: Dictionary = pending.get("item", {}) if pending.get("item", {}) is Dictionary else {}
		if bool(field_item.get("lucky_bonus", false)):
			return field_item
	return {}


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
