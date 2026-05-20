extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


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
	var sage_ring_equipped := false
	var sage_ring_active := false
	var sage_ring_count := 0
	var sage_ring_perk_level_bonus := 0
	var sage_ring_speed_penalty_pct := 0.0
	var sage_ring_body_penalty_pct := 0.0
	var sage_ring_speed_multiplier := 1.0
	var item_perk_level_bonus := 0

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
	var item_data: Dictionary = catalog.build_item_by_name("sage_ring")
	_expect(not item_data.is_empty(), "Sage Ring should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "현자의 반지", "Sage Ring should keep Korean display name")
	_expect(str(item_data.get("slot", "")) == "accessory", "Sage Ring should use accessory slots")
	_expect(is_equal_approx(float(item_data.get("chance", 0.0)), 0.001), "Sage Ring field chance should match Python reference")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Sage Ring icon should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "sage_ring"), "Sage Ring should be in passive field-spawn list")

	var roll_options: Array = catalog.get_roll_options("sage_ring")
	_expect(roll_options.size() == 2, "Sage Ring should have two penalty roll options")
	_expect(_has_roll_option(roll_options, "sage_speed_penalty_pct", 10.0, 20.0, 15.0, true), "Sage Ring speed penalty roll should match Python")
	_expect(_has_roll_option(roll_options, "sage_body_penalty_pct", 10.0, 20.0, 15.0, true), "Sage Ring body penalty roll should match Python")
	_expect(_has_fixed_option(item_data, "모든 퍽 레벨", "+1"), "Sage Ring should expose fixed perk-level option")

	var runtime: Object = MythicItemRuntime.new()
	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels["common_swiftness"] = 1
	perk_state.runtime_skill_levels["common_bulk_up"] = 1
	perk_state.runtime_skill_levels["common_expansion"] = 1
	perk_state.runtime_skill_levels["common_training"] = 1
	perk_state.runtime_skill_levels["dash_amplification"] = 1
	perk_state.runtime_skill_levels["unlock_ghost_shot"] = 1
	var owner := FakeOwner.new()
	var dash_state := FakeDashState.new()
	var registry := FakeRegistry.new(perk_state, runtime, dash_state)

	_expect(runtime.acquire_item("sage_ring", owner, registry, {"sage_speed_penalty_pct": 10.0, "sage_body_penalty_pct": 10.0}, true, false) >= 0, "first Sage Ring should acquire and equip")
	_expect(runtime.acquire_item("sage_ring", owner, registry, {"sage_speed_penalty_pct": 15.0, "sage_body_penalty_pct": 15.0}, true, false) >= 0, "second Sage Ring should acquire and equip")
	_expect(owner.equipment_slots.has("accessory1"), "first Sage Ring should resolve to accessory1")
	_expect(owner.equipment_slots.has("accessory2"), "second Sage Ring should resolve to accessory2")
	_expect(str(owner.equipment_slots["accessory1"].get("name", "")) == "sage_ring", "accessory1 should hold Sage Ring")
	_expect(str(owner.equipment_slots["accessory2"].get("name", "")) == "sage_ring", "accessory2 should hold Sage Ring")

	_expect(owner.sage_ring_equipped and owner.sage_ring_active, "owner should expose Sage Ring active state")
	_expect(owner.sage_ring_count == 2, "Sage Ring count should stack across accessory slots")
	_expect(owner.sage_ring_perk_level_bonus == 2, "two Sage Rings should grant +2 effective perk levels")
	_expect(perk_state.get_item_perk_level_bonus() == 2, "runtime perk state should receive Sage Ring level bonus")
	_expect(perk_state.get_runtime_skill_level("common_swiftness") == 3, "Sage Ring should raise invested scaling perk levels")
	_expect(perk_state.get_runtime_skill_level("common_bulk_up") == 3, "Sage Ring should raise paddle-size perk levels")
	_expect(perk_state.get_runtime_skill_level("common_expansion") == 3, "Sage Ring should raise accessory-slot perk levels")
	_expect(perk_state.get_runtime_skill_level("dash_amplification") == 3, "Sage Ring should raise dash amplification levels")
	_expect(perk_state.get_runtime_skill_level("unlock_ghost_shot") == 1, "Sage Ring should not inflate boolean unlock gates")
	_expect(dash_state.max_tokens == 4, "dash token capacity should resync immediately from Sage Ring effective levels")
	_expect(owner.runtime_accessory_slot_bonus == 3, "owner accessory bonus should sync from effective runtime level")
	_expect(is_equal_approx(owner.runtime_paddle_scale, 1.18), "owner runtime paddle scale should use effective Bulk Up level")
	_expect(is_equal_approx(owner.sage_ring_speed_penalty_pct, 25.0), "Sage Ring speed penalty should stack")
	_expect(is_equal_approx(owner.sage_ring_body_penalty_pct, 25.0), "Sage Ring body penalty should stack")
	_expect(is_equal_approx(runtime.get_player_speed_multiplier(), 0.75), "Sage Ring speed multiplier should apply stacked penalty")
	_expect(is_equal_approx(runtime.get_player_paddle_scale(), 0.75), "Sage Ring paddle scale should apply stacked body penalty")
	_expect(is_equal_approx(owner.player_paddle_width, 155.0 * 1.18 * 0.75), "owner paddle width should combine perk scale and Sage Ring body penalty")

	perk_state.set_viper_ignition_aura_active(true)
	_expect(perk_state.get_runtime_skill_level("common_swiftness") == 5, "Sage Ring should stack with Ignition Aura effective level bonus")
	perk_state.set_viper_ignition_aura_active(false)

	_expect(runtime.unequip_slot("accessory2", owner, registry), "Sage Ring should unequip from a concrete accessory slot")
	_expect(owner.sage_ring_count == 1, "unequipping one ring should leave one Sage Ring active")
	_expect(perk_state.get_item_perk_level_bonus() == 1, "Sage Ring level bonus should shrink after unequip")
	_expect(perk_state.get_runtime_skill_level("common_swiftness") == 2, "effective perk level should recompute after unequip")
	_expect(dash_state.max_tokens == 3, "dash token capacity should shrink after unequipping one Sage Ring")
	_expect(is_equal_approx(owner.sage_ring_speed_penalty_pct, 10.0), "remaining Sage Ring speed penalty should persist")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("sage_ring"), "field spawn candidates should include Sage Ring")

	print("sage_ring_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _has_roll_option(options: Array, key: String, min_value: float, max_value: float, default_value: float, reverse: bool) -> bool:
	for option_value in options:
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if str(option.get("key", "")) != key:
			continue
		return (
			is_equal_approx(float(option.get("min", 0.0)), min_value)
			and is_equal_approx(float(option.get("max", 0.0)), max_value)
			and is_equal_approx(float(option.get("default", 0.0)), default_value)
			and bool(option.get("reverse", false)) == reverse
		)
	return false


func _has_fixed_option(item_data: Dictionary, label: String, value: String) -> bool:
	for option_value in item_data.get("fixed_options", []):
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if str(option.get("label", "")) == label and str(option.get("value", "")) == value:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
