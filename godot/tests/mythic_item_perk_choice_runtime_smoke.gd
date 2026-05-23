extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	runtime.equipped_items["megingjord"] = {
		"name": "megingjord",
		"rolls": {"extra_pick_chance": 120.0},
	}
	_expect_close(runtime.get_megingjord_extra_pick_chance(), 95.0, "Megingjord extra-pick chance should stay clamped")
	_expect(not runtime.should_check_extra_pick("common_refresh"), "common refresh should not spend Megingjord extra-pick checks")
	_expect(runtime.should_check_extra_pick("smash_power"), "normal perk choices should check Megingjord extra-pick")

	runtime.megingjord_extra_pick_count = 2
	_expect(not runtime.try_after_perk_choice("smash_power", null, null), "Megingjord should stop at its extra-pick cap")

	runtime.megingjord_extra_pick_count = 1
	runtime.dowsing_goggles_bonus_triggered = true
	runtime.on_new_perk_choice_batch()
	_expect(runtime.megingjord_extra_pick_count == 0, "new perk-choice batch should reset Megingjord count")
	_expect(not runtime.dowsing_goggles_bonus_triggered, "new perk-choice batch should reset Dowsing bonus trigger")

	print("mythic_item_perk_choice_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
