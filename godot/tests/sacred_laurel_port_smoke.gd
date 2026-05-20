extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const LaurelLeafShieldState := preload("res://scripts/characters/laurel_leaf_shield_state.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TreasureHuntRuntime := preload("res://scripts/items/treasure_hunt_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var selected_character_type := "smasher"
	var player_pos := Vector2(302.5, 675.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var sacred_laurel_equipped := false
	var sacred_laurel_leaf_bonus := 0
	var sacred_laurel_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_item_runtime: Object
	var runtime_perk_state: Object

	func _init(item_runtime: Object, perk_state: Object) -> void:
		mythic_item_runtime = item_runtime
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
		return null


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("sacred_laurel")
	_expect(not item_data.is_empty(), "Sacred Laurel should build from the mythic catalog")
	_expect(str(item_data.get("display_name", "")) == "신성 월계수", "Sacred Laurel should expose Korean display text")
	_expect(str(item_data.get("type", "")) == "mythic", "Sacred Laurel should be a mythic item")
	_expect(str(item_data.get("rarity", "")) == "mythic", "Sacred Laurel rarity should be mythic")
	_expect(str(item_data.get("slot", "")) == "accessory", "Sacred Laurel should use accessory slots")
	_expect(is_equal_approx(float(item_data.get("chance", 0.0)), 0.00008), "Sacred Laurel field chance should match the Python mythic chance")
	var static_icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(static_icon != null and static_icon.get_size() == Vector2(32.0, 32.0), "Sacred Laurel original static icon should load as a 32px render")
	var icon_sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(icon_sheet != null and icon_sheet.get_size() == Vector2(1024.0, 32.0), "Sacred Laurel original icon sheet should load as 32 smooth 32px frames")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "Sacred Laurel should expose a 32-frame mythic icon sheet")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "sacred_laurel"), "Sacred Laurel should be in the field-spawn mythic pool")
	_expect(_array_has_item(catalog.get_debug_items(), "sacred_laurel"), "Sacred Laurel should be in the debug item list")

	var roll_option: Dictionary = _find_roll_option(catalog.get_roll_options("sacred_laurel"), "leaf_count")
	_expect(is_equal_approx(float(roll_option.get("min", 0.0)), 4.0), "Sacred Laurel leaf roll should start at 4")
	_expect(is_equal_approx(float(roll_option.get("max", 0.0)), 8.0), "Sacred Laurel leaf roll should cap at 8")
	_expect(is_equal_approx(float(roll_option.get("default", 0.0)), 6.0), "Sacred Laurel leaf roll should default to 6")

	var runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, perk_state)
	_expect(
		runtime.acquire_item("sacred_laurel", owner, registry, {"leaf_count": 8.0}, true, false) >= 0,
		"Sacred Laurel should acquire and auto-equip through mythic_item_runtime"
	)
	_expect(owner.equipment_slots.has("accessory1"), "Sacred Laurel should occupy the first open accessory slot")
	_expect(str(owner.equipment_slots["accessory1"].get("name", "")) == "sacred_laurel", "accessory1 should hold Sacred Laurel")
	_expect(owner.sacred_laurel_equipped, "owner should expose Sacred Laurel equipped state")
	_expect(owner.sacred_laurel_leaf_bonus == 8, "owner should sync the rolled Sacred Laurel leaf bonus")
	_expect(int(owner.sacred_laurel_context.get("leaf_bonus", 0)) == 8, "owner context should include the leaf bonus")
	_expect(runtime.get_sacred_laurel_leaf_bonus() == 8, "runtime getter should expose the rolled leaf count")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("sacred_laurel_equipped", false)), "snapshot should expose equipped Sacred Laurel")
	_expect(int(snapshot.get("sacred_laurel_leaf_bonus", 0)) == 8, "snapshot should expose the leaf bonus")

	perk_state.runtime_skill_levels["perk_laurel_shield"] = 2
	_expect(perk_state.get_laurel_leaf_count(registry) == 10, "Sacred Laurel should stack with invested Laurel Leaf levels")
	var shield_state := LaurelLeafShieldState.new()
	shield_state.update_from_runtime(owner, registry, 0.0)
	var shield_snapshot: Dictionary = shield_state.get_snapshot()
	_expect(int(shield_snapshot.get("leaf_count", 0)) == 10, "Laurel shield state should consume the mythic leaf bonus")
	_expect(int(shield_snapshot.get("active_leaf_count", 0)) == 10, "all mythic-boosted Laurel leaves should start active")

	var spawn_pool := ActiveItemFieldSpawnPool.new()
	var fresh_registry := FakeRegistry.new(MythicItemRuntime.new(), RuntimePerkState.new())
	_expect(spawn_pool.get_field_spawn_candidate_names(fresh_registry, owner).has("sacred_laurel"), "fresh field-spawn candidates should include Sacred Laurel")
	_expect(not spawn_pool.get_field_spawn_candidate_names(registry, owner).has("sacred_laurel"), "owned Sacred Laurel should be excluded from one-time field spawns")
	var treasure_runtime := TreasureHuntRuntime.new()
	_expect(not treasure_runtime._get_mythic_reward_pool(registry).has("sacred_laurel"), "owned Sacred Laurel should be excluded from treasure-hunt mythic rewards")

	_expect(runtime.unequip_item("sacred_laurel", owner, registry), "Sacred Laurel should unequip cleanly")
	_expect(not owner.sacred_laurel_equipped, "owner should clear Sacred Laurel equipped state after unequip")
	_expect(runtime.get_sacred_laurel_leaf_bonus() == 0, "unequipped Sacred Laurel should stop contributing leaves")
	_expect(perk_state.get_laurel_leaf_count(registry) == 2, "unequipping Sacred Laurel should restore base Laurel Leaf count")

	print("sacred_laurel_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _find_roll_option(options: Array, key: String) -> Dictionary:
	for option_value in options:
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if str(option.get("key", "")) == key:
			return option
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
