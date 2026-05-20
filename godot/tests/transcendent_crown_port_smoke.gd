extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
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
	var runtime_accessory_slot_bonus := 0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(300.0, 700.0)
	var player_speed_multiplier := 1.0
	var item_perk_level_bonus := 0
	var transcendent_crown_equipped := false
	var transcendent_crown_skill_bonus := 0
	var transcendent_crown_context: Dictionary = {}
	var sage_ring_equipped := false
	var sage_ring_active := false
	var sage_ring_count := 0
	var sage_ring_perk_level_bonus := 0
	var sage_ring_speed_penalty_pct := 0.0
	var sage_ring_body_penalty_pct := 0.0
	var sage_ring_speed_multiplier := 1.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var runtime_perk_state: Object = null
	var mythic_item_runtime: Object = null
	var dash_state: Object = null

	func _init(perk_state: Object, item_runtime: Object, smasher_dash_state: Object = null) -> void:
		runtime_perk_state = perk_state
		mythic_item_runtime = item_runtime
		dash_state = smasher_dash_state

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"mythic_item_runtime":
				return mythic_item_runtime
			"smasher_dash_state":
				return dash_state
		return null


class FakeDashState:
	var max_tokens := 1

	func set_max_tokens(value: int, _refill: bool = true) -> bool:
		max_tokens = max(1, value)
		return true

	func get_snapshot() -> Dictionary:
		return {"tokens": max_tokens}


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("transcendent_crown")
	_expect(not item_data.is_empty(), "Transcendent Crown should build from the mythic catalog")
	_expect(str(item_data.get("display_name", "")) == "초월자의 관", "Transcendent Crown should expose Korean display text")
	_expect(str(item_data.get("type", "")) == "mythic", "Transcendent Crown should be a mythic item")
	_expect(str(item_data.get("rarity", "")) == "mythic", "Transcendent Crown rarity should be mythic")
	_expect(str(item_data.get("slot", "")) == "head", "Transcendent Crown should use the head slot")
	_expect(is_equal_approx(float(item_data.get("chance", 0.0)), 0.00008), "Transcendent Crown field chance should match the Python mythic chance")
	var static_icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(static_icon != null and static_icon.get_size() == Vector2(32.0, 32.0), "Transcendent Crown original static icon should load as a 32px render")
	var icon_sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(icon_sheet != null and icon_sheet.get_size() == Vector2(1024.0, 32.0), "Transcendent Crown original icon sheet should load as 32 smooth 32px frames")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "Transcendent Crown should expose a 32-frame mythic icon sheet")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "transcendent_crown"), "Transcendent Crown should be in the field-spawn mythic pool")
	_expect(_array_has_item(catalog.get_debug_items(), "transcendent_crown"), "Transcendent Crown should be in the debug item list")

	var roll_option: Dictionary = _find_roll_option(catalog.get_roll_options("transcendent_crown"), "skill_bonus")
	_expect(is_equal_approx(float(roll_option.get("min", 0.0)), 1.0), "Transcendent Crown skill bonus roll should start at +1")
	_expect(is_equal_approx(float(roll_option.get("max", 0.0)), 2.0), "Transcendent Crown skill bonus roll should cap at +2")
	_expect(is_equal_approx(float(roll_option.get("default", 0.0)), 2.0), "Transcendent Crown skill bonus roll should default to +2")

	var runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["item_polish"] = 5
	perk_state.runtime_skill_levels["common_swiftness"] = 1
	perk_state.runtime_skill_levels["common_bulk_up"] = 1
	perk_state.runtime_skill_levels["common_expansion"] = 1
	perk_state.runtime_skill_levels["common_training"] = 1
	perk_state.runtime_skill_levels["dash_amplification"] = 1
	perk_state.runtime_skill_levels["perk_laurel_shield"] = 1
	perk_state.runtime_skill_levels["unlock_ghost_shot"] = 1
	var owner := FakeOwner.new()
	var dash_state := FakeDashState.new()
	var registry := FakeRegistry.new(perk_state, runtime, dash_state)

	_expect(
		runtime.acquire_item("transcendent_crown", owner, registry, {"skill_bonus": 2.0}, true, false) >= 0,
		"Transcendent Crown should acquire and auto-equip through mythic_item_runtime"
	)
	_expect(owner.equipment_slots.has("head"), "Transcendent Crown should occupy the head slot")
	_expect(str(owner.equipment_slots["head"].get("name", "")) == "transcendent_crown", "head slot should hold Transcendent Crown")
	_expect(owner.transcendent_crown_equipped, "owner should expose Transcendent Crown equipped state")
	_expect(owner.transcendent_crown_skill_bonus == 3, "base Polish Lv.5 should raise a +2 crown roll to +3 without recursive scaling")
	_expect(int(owner.transcendent_crown_context.get("skill_bonus", 0)) == 3, "owner context should include the crown skill bonus")
	_expect(runtime.get_transcendent_crown_skill_bonus() == 3, "runtime getter should expose the polished crown skill bonus")
	_expect(perk_state.get_item_perk_level_bonus() == 3, "runtime perk state should receive the crown level bonus")
	_expect(perk_state.get_runtime_skill_level("common_swiftness") == 4, "Transcendent Crown should raise invested scaling perk levels")
	_expect(perk_state.get_runtime_skill_level("common_bulk_up") == 4, "Transcendent Crown should raise paddle-size perk levels")
	_expect(perk_state.get_runtime_skill_level("common_expansion") == 4, "Transcendent Crown should raise accessory-slot perk levels")
	_expect(perk_state.get_runtime_skill_level("dash_amplification") == 4, "Transcendent Crown should raise dash amplification levels")
	_expect(perk_state.get_runtime_skill_level("unlock_ghost_shot") == 1, "Transcendent Crown should not inflate boolean unlock gates")
	_expect(dash_state.max_tokens == 5, "dash token capacity should resync from crown-boosted effective levels")
	_expect(owner.runtime_accessory_slot_bonus == 4, "owner accessory bonus should sync from crown-boosted effective level")
	_expect(is_equal_approx(owner.runtime_paddle_scale, 1.24), "owner runtime paddle scale should use crown-boosted Bulk Up level")
	_expect(is_equal_approx(perk_state.get_base_polish_multiplier(), 1.60), "base Polish multiplier should ignore Transcendent Crown feedback")
	_expect(is_equal_approx(perk_state.get_effective_polish_multiplier(), 1.96), "effective Polish multiplier should receive the crown bonus after crown sync")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("transcendent_crown_equipped", false)), "snapshot should expose equipped Transcendent Crown")
	_expect(int(snapshot.get("transcendent_crown_skill_bonus", 0)) == 3, "snapshot should expose the polished crown bonus")
	_expect(int(snapshot.get("item_perk_level_bonus", 0)) == 3, "snapshot should expose the total item perk-level bonus")

	_expect(
		runtime.acquire_item("sage_ring", owner, registry, {"sage_speed_penalty_pct": 10.0, "sage_body_penalty_pct": 10.0}, true, false) >= 0,
		"Sage Ring should still equip while Transcendent Crown is active"
	)
	_expect(perk_state.get_item_perk_level_bonus() == 4, "Transcendent Crown should stack with Sage Ring's item perk-level bonus")
	_expect(perk_state.get_runtime_skill_level("common_swiftness") == 5, "combined item level bonuses should recompute effective perk levels")
	_expect(dash_state.max_tokens == 6, "dash capacity should resync after stacking Sage Ring and Transcendent Crown")

	var spawn_pool := ActiveItemFieldSpawnPool.new()
	var candidate_names: Dictionary = spawn_pool.get_field_spawn_candidate_names(registry, owner)
	_expect(candidate_names.has("transcendent_crown"), "owned Transcendent Crown should remain in field candidates for roll farming")
	var treasure_runtime := TreasureHuntRuntime.new()
	_expect(treasure_runtime._get_mythic_reward_pool(registry).has("transcendent_crown"), "owned Transcendent Crown should remain in treasure-hunt mythic rewards for roll farming")

	_expect(runtime.unequip_item("transcendent_crown", owner, registry), "Transcendent Crown should unequip cleanly")
	_expect(not owner.transcendent_crown_equipped, "owner should clear Transcendent Crown equipped state after unequip")
	_expect(runtime.get_transcendent_crown_skill_bonus() == 0, "unequipped Transcendent Crown should stop contributing perk levels")
	_expect(perk_state.get_item_perk_level_bonus() == 1, "Sage Ring should remain as the only item perk-level bonus after crown unequip")
	_expect(perk_state.get_runtime_skill_level("common_swiftness") == 2, "effective perk level should recompute after crown unequip")
	_expect(dash_state.max_tokens == 3, "dash capacity should shrink after crown unequip")

	print("transcendent_crown_port_smoke: ok")
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
