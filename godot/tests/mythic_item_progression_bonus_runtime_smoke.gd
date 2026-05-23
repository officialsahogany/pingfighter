extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var sage_ring_equipped := false
	var sage_ring_active := false
	var sage_ring_count := 0
	var sage_ring_perk_level_bonus := 0
	var sage_ring_speed_penalty_pct := 0.0
	var sage_ring_body_penalty_pct := 0.0
	var sage_ring_speed_multiplier := 1.0
	var sacred_laurel_equipped := false
	var sacred_laurel_leaf_bonus := 0
	var sacred_laurel_context: Dictionary = {}
	var transcendent_crown_equipped := false
	var transcendent_crown_skill_bonus := 0
	var transcendent_crown_context: Dictionary = {}
	var item_perk_level_bonus := 0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var runtime_perk_state: Object
	var mythic_item_runtime: Object

	func _init(perk_state: Object, runtime: Object) -> void:
		runtime_perk_state = perk_state
		mythic_item_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	var perk_state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(perk_state, runtime)

	_expect(
		runtime.acquire_item("sage_ring", owner, registry, {"sage_speed_penalty_pct": 10.0, "sage_body_penalty_pct": 12.0}, true, false) >= 0,
		"Sage Ring should acquire and equip"
	)
	_expect(owner.sage_ring_equipped and owner.sage_ring_active, "owner should expose Sage Ring active state")
	_expect(owner.sage_ring_count == 1, "one Sage Ring should count as one equipped ring")
	_expect(owner.sage_ring_perk_level_bonus == 1, "one Sage Ring should grant +1 item perk level")
	_expect(perk_state.get_item_perk_level_bonus() == 1, "runtime perk state should receive Sage Ring bonus")
	_expect_close(owner.sage_ring_speed_penalty_pct, 10.0, "Sage Ring speed penalty should sync")
	_expect_close(owner.sage_ring_body_penalty_pct, 12.0, "Sage Ring body penalty should sync")
	_expect_close(runtime.get_sage_ring_speed_multiplier(), 0.9, "Sage Ring speed multiplier should use the speed penalty")

	_expect(
		runtime.acquire_item("sacred_laurel", owner, registry, {"leaf_count": 4.0}, true, false) >= 0,
		"Sacred Laurel should acquire and equip"
	)
	_expect(owner.sacred_laurel_equipped, "owner should expose Sacred Laurel equipped state")
	_expect(owner.sacred_laurel_leaf_bonus == 4, "Sacred Laurel should sync the leaf bonus")
	_expect(int(owner.sacred_laurel_context.get("leaf_bonus", 0)) == 4, "Sacred Laurel context should include leaf bonus")
	_expect(runtime.get_sacred_laurel_leaf_bonus() == 4, "runtime should expose Sacred Laurel leaf bonus")

	_expect(
		runtime.acquire_item("transcendent_crown", owner, registry, {"skill_bonus": 2.0}, true, false) >= 0,
		"Transcendent Crown should acquire and equip"
	)
	_expect(owner.transcendent_crown_equipped, "owner should expose Transcendent Crown equipped state")
	_expect(owner.transcendent_crown_skill_bonus == 2, "Transcendent Crown should sync its skill bonus")
	_expect(int(owner.transcendent_crown_context.get("skill_bonus", 0)) == 2, "Transcendent Crown context should include skill bonus")
	_expect(runtime.get_total_item_perk_level_bonus() == 3, "Sage Ring and Transcendent Crown bonuses should stack")
	_expect(perk_state.get_item_perk_level_bonus() == 3, "runtime perk state should receive stacked item perk levels")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(int(snapshot.get("item_perk_level_bonus", 0)) == 3, "snapshot should expose stacked item perk levels")
	_expect(int(snapshot.get("sacred_laurel_leaf_bonus", 0)) == 4, "snapshot should expose Sacred Laurel leaf bonus")

	print("mythic_item_progression_bonus_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
