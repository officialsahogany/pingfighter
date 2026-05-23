extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeActiveItemRuntime:
	var active := false

	func _init(is_active: bool) -> void:
		active = is_active

	func is_aipill_active() -> bool:
		return active


class FakeFeedback:
	var gauge_flash_count := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


func _init() -> void:
	_expect_slot_add_capacity()
	_expect_chargebag_wall_gauge()
	_expect_battery_stage_transition()
	print("mythic_item_capacity_gauge_runtime_smoke: ok")
	quit(0)


func _expect_slot_add_capacity() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(
		runtime.equip_item("slot_add", null, null, {"slot_add_count": 2.0}, false),
		"Backpack should equip into the belt slot"
	)
	_expect(runtime.is_slot_add_equipped(), "Backpack equipped flag should be true")
	_expect(runtime.get_slot_add_active_item_slot_bonus() == 2, "Backpack should expose the rolled +2 slot bonus")
	_expect(runtime.get_active_item_slot_capacity(3) == 5, "Backpack should raise active item capacity from 3 to 5")


func _expect_chargebag_wall_gauge() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(
		runtime.equip_item("chargebag", null, null, {"chargebag_pct": 200.0}, false),
		"Charge Bag should equip into the belt slot"
	)
	_expect(runtime.is_chargebag_equipped(), "Charge Bag equipped flag should be true")
	_expect_close(runtime.get_chargebag_wall_bounce_gauge_pct(), 200.0, "Charge Bag should expose the rolled wall-bounce gauge percent")
	var feedback := FakeFeedback.new()
	var next_gauge: float = runtime.apply_chargebag_wall_bounce_gauge(
		100.0,
		{"selected_character_type": "smasher", "gauge_max": 500.0},
		{"feedback": feedback}
	)
	_expect_close(next_gauge, 200.0, "Smasher wall bounce should gain floor(50 * 200%) gauge")
	_expect(feedback.gauge_flash_count == 1, "Charge Bag gauge gain should trigger gauge feedback")
	_expect_close(
		runtime.apply_chargebag_wall_bounce_gauge(
			100.0,
			{"selected_character_type": "optimus", "gauge_max": 500.0},
			{}
		),
		100.0,
		"Optimus wall bounce should not gain Charge Bag gauge"
	)
	_expect_close(
		runtime.apply_chargebag_wall_bounce_gauge(
			100.0,
			{"selected_character_type": "smasher", "gauge_max": 500.0},
			{"active_item_runtime": FakeActiveItemRuntime.new(true)}
		),
		100.0,
		"AI Pill active state should suppress Charge Bag wall-bounce gain"
	)


func _expect_battery_stage_transition() -> void:
	var runtime := MythicItemRuntime.new()
	_expect(
		runtime.equip_item("battery", null, null, {"gauge_preserve_pct": 40.0}, false),
		"Battery Pack should equip into the belt slot"
	)
	_expect(runtime.is_battery_equipped(), "Battery Pack equipped flag should be true")
	_expect_close(runtime.get_battery_gauge_preserve_pct(), 40.0, "Battery Pack should expose the rolled preserve percent")
	_expect_close(runtime.get_stage_transition_gauge(250.0, 500.0, false), 100.0, "Battery Pack should preserve floor(250 * 40%) gauge")
	_expect_close(runtime.get_stage_transition_gauge(700.0, 500.0, true), 500.0, "AI Pill stage transition should keep clamped current gauge")
	var empty_runtime := MythicItemRuntime.new()
	_expect_close(empty_runtime.get_stage_transition_gauge(250.0, 500.0, false), 0.0, "No Battery Pack should clear transition gauge")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
