extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(
		runtime.equip_item(
			"master",
			null,
			null,
			{
				"wall_length_pct": 50.0,
				"item_cooldown_pct": 20.0,
				"wall_spawn_bonus_pct": 100.0,
			},
			false
		),
		"Repairman Hammer should equip"
	)
	_expect(runtime.is_master_equipped(), "Repairman Hammer equipped flag should be true")
	_expect_close(runtime.get_master_wall_length_bonus_pct(), 50.0, "Repairman Hammer should expose wall length roll")
	_expect_close(runtime.get_master_item_cooldown_reduction_pct(), 20.0, "Repairman Hammer should expose item cooldown roll")
	_expect_close(runtime.get_master_wall_spawn_bonus_pct(), 100.0, "Repairman Hammer should expose wall spawn roll")
	_expect_close(runtime.get_brick_wall_width(80.0), 120.0, "Repairman Hammer should widen Brick Wall")
	_expect_close(runtime.get_wall_item_spawn_chance(0.25), 0.5, "Repairman Hammer should scale Brick field-spawn chance")
	_expect(runtime.get_active_item_cooldown_msec(10000) == 8000, "Repairman Hammer should reduce active-item cooldown")

	_expect(
		runtime.equip_item("cooltime", null, null, {"active_cooldown_pct": 25.0}, false),
		"Cooling Ball should equip"
	)
	_expect(runtime.is_cooltime_equipped(), "Cooling Ball equipped flag should be true")
	_expect_close(runtime.get_cooltime_active_item_cooldown_reduction_pct(), 25.0, "Cooling Ball should expose active-item cooldown roll")
	_expect_close(runtime.get_total_active_item_cooldown_reduction_pct(), 40.0, "Master and Cooling Ball should stack multiplicatively")
	_expect(runtime.get_active_item_cooldown_msec(10000) == 6000, "Master and Cooling Ball should reduce cooldown to 60%")

	_expect(
		runtime.equip_item("timer_belt", null, null, {"skill_cooldown_pct": 30.0}, false),
		"Timer Belt should equip"
	)
	_expect(runtime.is_timer_belt_equipped(), "Timer Belt equipped flag should be true")
	_expect_close(runtime.get_timer_belt_skill_cooldown_reduction_pct(), 30.0, "Timer Belt should expose player skill cooldown roll")
	_expect_close(runtime.get_player_skill_cooldown_multiplier(), 0.7, "Timer Belt should feed player skill cooldown multiplier")
	_expect_close(runtime.get_player_skill_cooldown_seconds(10.0), 7.0, "Timer Belt should reduce player skill cooldown seconds")

	_expect(runtime.unequip_item("cooltime", null, null), "Cooling Ball should unequip")
	_expect_close(runtime.get_total_active_item_cooldown_reduction_pct(), 20.0, "Cooling Ball unequip should leave only Master cooldown reduction")
	_expect(runtime.get_active_item_cooldown_msec(10000) == 8000, "Cooldown should return to Master-only reduction")

	print("mythic_item_cooldown_gear_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
