extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(300.0, 700.0)
	var speedboots_speed_bonus_pct := 0.0

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
	var catalog := RuntimePerkCatalog.new()
	var polish_data: Dictionary = catalog.get_perk_data("item_polish")
	_expect(not polish_data.is_empty(), "catalog should register Polish")
	_expect(int(polish_data.get("max_level", 0)) == 5, "Polish should have five base levels")
	_expect(str(polish_data.get("tree", "")) == "item", "Polish should live in the item tree")

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["item_polish"] = 2
	_expect_close(perk_state.get_runtime_skill_bonus("item_polish"), 0.24, "Lv.2 Polish bonus should match Python")
	_expect_close(perk_state.get_effective_polish_multiplier(), 1.24, "Lv.2 Polish multiplier should match Python")

	perk_state.runtime_skill_levels["item_polish"] = 5
	perk_state.item_perk_level_bonus = 1
	_expect(int(perk_state.get_runtime_skill_level("item_polish")) == 6, "effective Lv.6 Polish should keep scaling")
	_expect_close(perk_state.get_effective_polish_multiplier(), 1.72, "effective Lv.6 Polish multiplier should stay uncapped")
	_expect_close(perk_state.get_base_polish_multiplier(), 1.60, "base Polish multiplier should ignore effective-level bonuses")

	perk_state.item_perk_level_bonus = 0
	perk_state.runtime_skill_levels["item_polish"] = 2
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, perk_state)

	var speed_index: int = int(runtime.acquire_item("speedboots", owner, registry, {"speed_bonus_pct": 10.0}, true, false))
	_expect(speed_index >= 0, "Speedboots should acquire and equip")
	_expect_close(runtime.get_speedboots_speed_bonus_pct(), 12.4, "Polish should boost normal passive rolls")
	_expect_close(owner.speedboots_speed_bonus_pct, 12.4, "owner sync should expose polished Speedboots value")

	var speed_item: Dictionary = runtime.get_inventory_item(speed_index)
	_expect_close(runtime.get_item_roll_value(speed_item, "speed_bonus_pct", false, registry), 10.0, "public roll helper should expose base value")
	_expect_close(runtime.get_item_roll_value(speed_item, "speed_bonus_pct", true, registry), 12.4, "public roll helper should expose polished value")
	var overlay := CharacterInfoOverlay.new()
	var roll_entries: Array = overlay._build_passive_item_roll_entries(speed_item, registry)
	_expect(_entries_contain(roll_entries, "(+2%)"), "passive-item tooltip should show the Polish bonus lane")
	var roll_entries_again: Array = overlay._build_passive_item_roll_entries(speed_item, registry)
	_expect(roll_entries_again == roll_entries, "passive-item tooltip roll entry cache should preserve repeated output")

	_expect(runtime.acquire_item("dowsing_pendulum", owner, registry, {"attraction_range": 200.0}, true, false) >= 0, "Dowsing Pendulum should equip")
	_expect_close(runtime.get_dowsing_pendulum_range(), 248.0, "Polish should boost Dowsing Pendulum range")

	_expect(runtime.acquire_item("megingjord", owner, registry, {"extra_pick_chance": 40.0}, true, false) >= 0, "Megingjord should equip")
	_expect_close(runtime.get_megingjord_extra_pick_chance(), 49.6, "Polish should boost Megingjord extra-pick chance")

	_expect(runtime.acquire_item("ragnarok_hammer", owner, registry, {"gauge_cost": 30.0}, true, false) >= 0, "Ragnarok Hammer should equip")
	_expect_close(runtime.get_ragnarok_gauge_cost(), 30.0 / 1.24, "Polish should reduce reverse roll values")
	var hammer_item: Dictionary = _find_inventory_item(runtime, "ragnarok_hammer")
	var hammer_entries: Array = overlay._build_passive_item_roll_entries(hammer_item, registry)
	_expect(_entries_contain(hammer_entries, "(-6)"), "reverse-roll tooltip should show the reduced cost delta")

	perk_state.runtime_skill_levels["item_polish"] = 5
	_expect(runtime.acquire_item("sage_ring", owner, registry, {"sage_speed_penalty_pct": 10.0, "sage_body_penalty_pct": 10.0}, true, false) >= 0, "Sage Ring should equip")
	_expect(perk_state.get_item_perk_level_bonus() == 1, "Sage Ring should feed Polish effective-level scaling")
	_expect_close(runtime.get_speedboots_speed_bonus_pct(), 17.2, "Polish should resync item rolls when effective levels change")

	print("item_polish_perk_port_smoke: ok")
	quit(0)


func _find_inventory_item(runtime: Object, item_name: String) -> Dictionary:
	var snapshot: Dictionary = runtime.get_snapshot()
	for item_value in snapshot.get("inventory_items", []):
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return item_data
	return {}


func _entries_contain(entries: Array, needle: String) -> bool:
	for entry_value in entries:
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		if str(entry.get("text", "")).find(needle) >= 0:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
