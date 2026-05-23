extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var smartphone_equipped := false
	var smartphone_active := false
	var smartphone_count := 0
	var smartphone_auto_cooldown_frames := 0.0
	var smartphone_last_auto_item := ""
	var neural_helmet_equipped := false
	var neural_helmet_active := false
	var neural_helmet_count := 0
	var neural_helmet_aipill_gauge_reduction := 0.0
	var neural_helmet_aipill_spawn_bonus_pct := 0.0
	var aipill_gauge_drain := 90.0
	var aipill_item_spawn_multiplier := 1.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var runtime: Object

	func _init(mythic_runtime: Object) -> void:
		runtime = mythic_runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		return null


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)

	_expect(
		runtime.acquire_item("smartphone", owner, registry, {}, true, false) >= 0,
		"Smartphone should acquire and equip"
	)
	_expect(owner.smartphone_equipped and owner.smartphone_active, "owner should expose Smartphone active state")
	_expect(owner.smartphone_count == 1, "runtime should count one equipped Smartphone")
	_expect(runtime.is_smartphone_active(), "runtime should report Smartphone active")

	runtime.smartphone_cooldown_frames = 13.0
	runtime.smartphone_last_auto_item = "stopwatch"
	runtime._clear_smartphone_runtime()
	_expect_close(runtime.smartphone_cooldown_frames, 0.0, "Smartphone clear should reset cooldown")
	_expect(runtime.smartphone_last_auto_item == "", "Smartphone clear should reset last auto item")

	_expect(
		runtime.equip_item("neural_helmet", owner, registry, {
			"aipill_gauge_reduction": 120.0,
			"aipill_spawn_bonus_pct": 2500.0,
		}, false),
		"Neural Helmet should equip"
	)
	_expect(owner.neural_helmet_equipped and owner.neural_helmet_active, "owner should expose Neural Helmet active state")
	_expect(owner.neural_helmet_count == 1, "runtime should count one equipped Neural Helmet")
	_expect_close(owner.neural_helmet_aipill_gauge_reduction, 90.0, "Neural Helmet gauge reduction should clamp")
	_expect_close(owner.neural_helmet_aipill_spawn_bonus_pct, 2000.0, "Neural Helmet spawn bonus should clamp")
	_expect_close(runtime.get_aipill_gauge_drain(90.0), 0.0, "Neural Helmet should clamp AI Pill drain at zero")
	_expect_close(runtime.get_aipill_item_spawn_multiplier(), 21.0, "Neural Helmet spawn multiplier should use clamped bonus")
	_expect_close(runtime.get_aipill_item_spawn_chance(0.006), 0.126, "Neural Helmet should scale AI Pill spawn chance")
	_expect(runtime.should_cancel_aipill_on_direction_key(), "Neural Helmet should enable direction-key AI Pill cancel")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("smartphone_active", false)), "snapshot should expose Smartphone active")
	_expect(bool(snapshot.get("neural_helmet_active", false)), "snapshot should expose Neural Helmet active")
	_expect_close(float(snapshot.get("aipill_gauge_drain", -1.0)), 0.0, "snapshot should expose clamped AI Pill drain")
	_expect_close(float(snapshot.get("aipill_item_spawn_multiplier", 0.0)), 21.0, "snapshot should expose AI Pill spawn multiplier")

	print("mythic_item_ai_assist_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
