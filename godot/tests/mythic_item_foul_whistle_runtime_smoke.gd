extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var foul_whistle_equipped := false
	var foul_whistle_active := false
	var foul_whistle_negate_chance_pct := 0.0
	var foul_whistle_negate_chance := 0.0
	var foul_whistle_effect_active := false
	var foul_whistle_pending_round_reset := false

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var foul_whistle_count := 0

	func play_foul_whistle() -> void:
		foul_whistle_count += 1


func _init() -> void:
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()

	_expect(
		runtime.equip_item("foul_whistle", owner, null, {"negate_chance_pct": 100.0}, false),
		"Foul Whistle should equip"
	)
	_expect(owner.foul_whistle_equipped and owner.foul_whistle_active, "owner should expose Foul Whistle active state")
	_expect_close(owner.foul_whistle_negate_chance_pct, 100.0, "owner should sync Foul Whistle negate pct")
	_expect_close(owner.foul_whistle_negate_chance, 1.0, "owner should sync Foul Whistle negate chance")
	_expect(runtime.try_trigger_foul_whistle("round", audio), "100% Foul Whistle should trigger")
	_expect(audio.foul_whistle_count == 1, "Foul Whistle should play its dedicated sound")
	_expect(runtime.is_foul_whistle_effect_active(), "Foul Whistle should start its animation")
	_expect(runtime.foul_whistle_state.pending_round_reset, "Foul Whistle should mark a pending round reset")
	_expect(not runtime.consume_foul_whistle_reset_ready(), "reset should not be ready before the reset frame")

	runtime._update_foul_whistle_runtime(70.0)
	_expect(runtime.consume_foul_whistle_reset_ready(), "reset should become consumable at the reset frame")
	_expect(not runtime.is_foul_whistle_effect_active(), "consume should clear the animation state")

	_expect(runtime.try_trigger_foul_whistle("score", audio), "Foul Whistle should trigger again after clear")
	runtime.foul_whistle_runtime.clear_runtime(runtime)
	_expect(not runtime.is_foul_whistle_effect_active(), "clear should stop the animation")
	_expect(not runtime.foul_whistle_state.pending_round_reset, "clear should remove pending round reset")

	print("mythic_item_foul_whistle_runtime_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
