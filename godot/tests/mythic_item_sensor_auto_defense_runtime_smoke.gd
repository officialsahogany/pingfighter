extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const AutoDefenseRuntime := preload("res://scripts/items/mythic_item_auto_defense_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var sensor_equipped := false
	var sensor_enabled := false
	var sensor_ready := false
	var sensor_cooldown_sec := 0.0
	var sensor_cooldown_remaining_sec := 0.0
	var sensor_cooldown_progress := 0.0
	var sensor_auto_dash_effect_active := false
	var sensor_last_dash_direction := 0.0
	var sensor_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()

	_expect_close(
		AutoDefenseRuntime.SENSOR_AUTO_DASH_EFFECT_FRAMES,
		34.0,
		"auto-defense helper should own sensor dash effect timing"
	)
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_auto_defense_runtime.gd")
	_expect(
		not runtime_source.contains("AUTO_DEFENSE_CONSTANTS"),
		"runtime facade should not regain AUTO_DEFENSE_CONSTANTS"
	)
	_expect(
		helper_source.contains("const SMARTPHONE_DEFENSE_COOLDOWN_FRAMES"),
		"auto-defense helper should keep Smartphone defense constants"
	)

	_expect(
		runtime.equip_item("sensor", owner, null, {"sensor_cooldown_sec": 13.0}, false),
		"Danger Sensor Belt should equip"
	)
	_expect(owner.sensor_equipped, "owner should expose sensor equipped")
	_expect(owner.sensor_enabled and owner.sensor_ready, "sensor should start enabled and ready")
	_expect_close(owner.sensor_cooldown_sec, 13.0, "rolled cooldown should sync")
	_expect_close(runtime.get_sensor_cooldown_frames(), 780.0, "cooldown frames should derive from rolled seconds")

	runtime.sensor_cooldown_timer_frames = 390.0
	runtime.sensor_last_dash_direction = -1.0
	runtime.sensor_auto_dash_effect_timer_frames = 10.0
	runtime.sensor_auto_dash_center = Vector2(120.0, 640.0)
	runtime.set_sensor_enabled(false, owner, null)
	_expect(not owner.sensor_enabled, "owner should sync disabled sensor flag")
	_expect(not runtime.is_sensor_auto_dash_ready(), "disabled sensor should not be ready")
	_expect_close(runtime.get_sensor_cooldown_remaining_seconds(), 6.5, "remaining cooldown should use timer frames")
	_expect_close(runtime.get_sensor_cooldown_progress(), 0.5, "cooldown progress should use rolled cooldown")
	var context: Dictionary = runtime.get_sensor_context()
	_expect(not bool(context.get("enabled", true)), "context should expose disabled sensor flag")
	_expect(bool(context.get("auto_dash_effect_active", false)), "context should expose active sensor effect")
	_expect_close(float(context.get("last_dash_direction", 0.0)), -1.0, "context should expose last dash direction")

	runtime.auto_defense_runtime.clear_sensor_round_state(runtime)
	_expect_close(runtime.sensor_cooldown_timer_frames, 390.0, "round clear should preserve cooldown")
	_expect_close(runtime.sensor_auto_dash_effect_timer_frames, 0.0, "round clear should reset effect timer")
	_expect_close(runtime.sensor_last_dash_direction, 0.0, "round clear should reset last dash direction")
	runtime.auto_defense_runtime.clear_sensor_runtime(runtime, false)
	_expect(runtime.sensor_enabled, "runtime clear should re-enable sensor")
	_expect_close(runtime.sensor_cooldown_timer_frames, 390.0, "runtime clear without cooldown flag should preserve timer")
	runtime.auto_defense_runtime.clear_sensor_runtime(runtime, true)
	_expect_close(runtime.sensor_cooldown_timer_frames, 0.0, "full runtime clear should reset cooldown")

	print("mythic_item_sensor_auto_defense_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
