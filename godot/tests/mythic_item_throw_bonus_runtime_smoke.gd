extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemRollQuery := preload("res://scripts/items/mythic_item_roll_query.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var reinforced_boomerang_gauntlet_equipped := false
	var reinforced_boomerang_gauntlet_active := false
	var reinforced_boomerang_gauntlet_count := 0
	var reinforced_boomerang_gauntlet_launch_speed_pct := 0.0
	var reinforced_boomerang_gauntlet_homing_pct := 0.0
	var reinforced_boomerang_gauntlet_spawn_bonus_pct := 0.0
	var commando_arm_equipped := false
	var commando_arm_active := false
	var commando_arm_count := 0
	var commando_arm_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


func _init() -> void:
	_verify_roll_query_constant_ownership()
	_verify_reinforced_boomerang_gauntlet()
	_verify_commando_arm()
	print("mythic_item_throw_bonus_runtime_smoke: ok")
	quit(0)


func _verify_roll_query_constant_ownership() -> void:
	_expect(MythicItemRollQuery.COMMANDO_ARM_MAX_STACKS == 2, "roll query should own Commando Arm roll stack cap")
	_expect(MythicItemRollQuery.ITEM_COMMANDO_ARM == "commando_arm", "roll query should own Commando Arm item id")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_roll_query.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "roll query source should be readable")
	_expect(not runtime_source.contains("COMMANDO_ARM_MAX_STACKS"), "runtime facade should not regain Commando Arm stack constants")
	_expect(not runtime_source.contains("item_commando_arm"), "runtime context constants should not regain Commando Arm item-id handoff")
	_expect(not runtime_source.contains("commando_arm_max_stacks"), "runtime context constants should not regain Commando Arm stack handoff")
	_expect(helper_source.contains("const COMMANDO_ARM_MAX_STACKS"), "roll query should keep Commando Arm stack cap")


func _verify_reinforced_boomerang_gauntlet() -> void:
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	_expect(
		runtime.equip_item("reinforced_boomerang_gauntlet", owner, null, {
			"boomerang_launch_speed_pct": 60.0,
			"boomerang_homing_pct": 40.0,
			"boomerang_spawn_bonus_pct": 200.0,
		}, false),
		"first Reinforced Boomerang Gauntlet should equip"
	)
	_expect(
		runtime.acquire_item("reinforced_boomerang_gauntlet", owner, null, {
			"boomerang_launch_speed_pct": 60.0,
			"boomerang_homing_pct": 60.0,
			"boomerang_spawn_bonus_pct": 250.0,
		}, true, false) >= 0,
		"second Reinforced Boomerang Gauntlet should equip"
	)
	_expect(owner.reinforced_boomerang_gauntlet_equipped, "owner should expose gauntlet equipped")
	_expect(owner.reinforced_boomerang_gauntlet_active, "owner should expose gauntlet active")
	_expect(owner.reinforced_boomerang_gauntlet_count == 2, "owner should count both gauntlets")
	_expect_close(runtime.get_boomerang_launch_speed_pct(), 120.0, "launch speed should stack")
	_expect_close(runtime.get_boomerang_homing_pct(), 100.0, "homing should stack")
	_expect_close(runtime.get_boomerang_spawn_bonus_pct(), 450.0, "spawn bonus should stack")
	_expect_close(runtime.get_boomerang_launch_speed_multiplier(), 2.2, "launch speed multiplier should reflect stacked roll")
	_expect_close(runtime.get_boomerang_homing_multiplier(), 2.0, "homing multiplier should reflect stacked roll")
	_expect_close(runtime.get_boomerang_item_spawn_multiplier(), 5.5, "spawn multiplier should reflect stacked roll")
	_expect_close(runtime.get_boomerang_item_spawn_chance(0.006), 0.033, "spawn chance should scale by multiplier")
	_expect_close(runtime.get_boomerang_knockback_multiplier(), 1.4, "gauntlet should expose fixed knockback multiplier")
	_expect_close(runtime.get_boomerang_stun_multiplier(), 1.6, "gauntlet should expose fixed stun multiplier")


func _verify_commando_arm() -> void:
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	_expect(
		runtime.equip_item("commando_arm", owner, null, {
			"throw_speed_pct": 20.0,
			"explosion_range_pct": 15.0,
			"smoke_duration_pct": 30.0,
			"prep_reduction_pct": 30.0,
		}, false),
		"first Commando Arm should equip"
	)
	_expect(
		runtime.acquire_item("commando_arm", owner, null, {
			"throw_speed_pct": 15.0,
			"explosion_range_pct": 10.0,
			"smoke_duration_pct": 40.0,
			"prep_reduction_pct": 40.0,
		}, true, false) >= 0,
		"second Commando Arm should equip"
	)
	_expect(owner.commando_arm_equipped, "owner should expose Commando Arm equipped")
	_expect(owner.commando_arm_active, "owner should expose Commando Arm active")
	_expect(owner.commando_arm_count == 2, "owner should count both Commando Arms")
	_expect_close(runtime.get_commando_arm_throw_speed_pct(), 35.0, "throw speed roll should stack")
	_expect_close(runtime.get_commando_arm_explosion_range_pct(), 25.0, "range roll should stack")
	_expect_close(runtime.get_commando_arm_smoke_duration_pct(), 70.0, "smoke duration roll should stack")
	_expect_close(runtime.get_commando_arm_prep_reduction_pct(), 70.0, "prep reduction display sum should stack")
	_expect_close(runtime.get_commando_arm_prep_multiplier(), 0.42, "prep reduction should compound by stack")
	_expect_close(float(runtime.get_commando_arm_windup_msec(600)), 252.0, "windup should use compounded prep multiplier")
	_expect_close(runtime.get_commando_arm_throw_speed_multiplier(false), 2.0, "generic throw speed should use fixed per-stack bonus")
	_expect_close(runtime.get_commando_arm_throw_speed_multiplier(true), 1.35, "boomerang throw speed should use rolled speed")
	_expect_close(runtime.get_commando_arm_range_value(190.0), 237.5, "range helper should scale base values")
	_expect_close(runtime.get_commando_arm_duration_frames(960.0), 1632.0, "duration helper should scale smoke frames")
	var context: Dictionary = runtime.get_commando_arm_context()
	_expect_close(float(context.get("prep_multiplier", 0.0)), 0.42, "context should expose prep multiplier")
	_expect_close(float(context.get("range_multiplier", 0.0)), 1.25, "context should expose range multiplier")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
