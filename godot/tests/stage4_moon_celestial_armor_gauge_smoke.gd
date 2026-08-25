extends SceneTree

# Seals the ball-path 부동갑주(celestial_armor) behaviors on the Stage 4 moon
# fragment hit that unit-level armor smokes miss because they never run the
# production ball_update_controller -> apply_snapshot round-trip:
#
#  P1-B  gauge REFUND: the armor deducts owner.special_gauge, but the frame-end
#        ball snapshot writes scene[special_gauge] back to owner. If the moon
#        fragment reads the STALE frame-start scene gauge, the armor's cost is
#        refunded. This seal drives _apply_player_fragment_hit THEN applies the
#        scene snapshot to owner and asserts the deduction survived.
#  P2-A  cleanse = FULL-hit immunity: an active cleanse window must skip the
#        WHOLE hit (burn + timer + knockback + gauge + counter), checked BEFORE
#        any effect — not bundled into the knockback-only armor gate.

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const Stage4MoonEvent := preload("res://scripts/stages/stage4/stage4_moon_event.gd")
const BallSnapshotApplier := preload("res://scripts/core/battle_scene_ball_snapshot_applier.gd")

const ARMOR_GAUGE_COST := 20.0
const FRAGMENT_GAUGE_DRAIN := 2.0


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(220.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var celestial_armor_equipped := false
	var celestial_armor_active := false
	var celestial_armor_trigger_chance_pct := 0.0
	var celestial_armor_gauge_cost := 0.0
	var celestial_armor_context: Dictionary = {}
	var celestial_armor_wave_active := false
	var stage4_player_burn_active := false
	var stage4_player_burn_timer_frames := 0.0
	var stage4_moon_fragment_player_hits := 0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class CleanseImmune:
	func is_immune() -> bool:
		return true


class StatusCapture:
	var calls: Array = []

	func apply_status(target: String, effect: String, frames: float, meta: Dictionary = {}, source: String = "") -> void:
		calls.append({"target": target, "effect": effect, "frames": frames, "source": source})


class MovementCapture:
	var calls: Array = []

	func start_knockback(velocity: float, frames: float, decay: float = 0.85, _interrupt_dash: bool = true, _allow_stack: bool = true) -> void:
		calls.append({"velocity": velocity, "frames": frames})


func _init() -> void:
	_test_armor_block_deduction_survives_snapshot()
	_test_no_armor_only_fragment_drain()
	_test_cleanse_skips_whole_hit()
	print("stage4_moon_celestial_armor_gauge_smoke: ok")
	quit(0)


func _equip_armor(owner: Object, registry: Object, runtime: Object) -> void:
	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 100.0, "gauge_cost": ARMOR_GAUGE_COST},
			false
		),
		"celestial armor should equip"
	)


func _run_fragment_hit(moon: Object, owner: Object, deps: Dictionary) -> Dictionary:
	# scene = the frame-start ball snapshot dict (seeded from owner). It is a
	# SEPARATE dict from the frame_context the armor gate mutates — exactly the
	# production divergence that hid the refund.
	var scene := {"special_gauge": owner.special_gauge}
	var context := {"special_gauge": owner.special_gauge, "owner": owner}
	moon._apply_player_fragment_hit(
		{"x": 300.0},
		Rect2(Vector2(200.0, 690.0), Vector2(155.0, 50.0)),
		scene,
		context,
		deps
	)
	# Frame end: the ball update driver writes the scene snapshot back onto owner.
	BallSnapshotApplier.new().apply_snapshot(owner, scene)
	return scene


func _test_armor_block_deduction_survives_snapshot() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = MythicItemRuntime.new()
	_equip_armor(owner, registry, runtime)
	owner.special_gauge = 100.0
	var status := StatusCapture.new()
	var movement := MovementCapture.new()
	var deps := {
		"mythic_item_runtime": runtime,
		"registry": registry,
		"owner": owner,
		"status_effect_state": status,
		"movement_state": movement,
	}
	var moon: Object = Stage4MoonEvent.new()
	_run_fragment_hit(moon, owner, deps)

	# knockback-only hit: burn stays (outside contract), knockback blocked by armor.
	_expect(_has_burn(status), "armor-blocked fragment should still apply burn (burn is outside the armor contract)")
	_expect(movement.calls.is_empty(), "armor should block the fragment knockback")
	# The armor's 20 cost AND the fragment's own 2 drain must both survive the
	# frame-end snapshot: 100 - 20 - 2 = 78 (NOT 98 = refunded armor).
	_expect(
		is_equal_approx(owner.special_gauge, 100.0 - ARMOR_GAUGE_COST - FRAGMENT_GAUGE_DRAIN),
		"armor gauge cost must survive the ball snapshot (expected 78, refund bug leaves 98). got %s" % owner.special_gauge
	)


func _test_no_armor_only_fragment_drain() -> void:
	var owner := FakeOwner.new()
	owner.special_gauge = 100.0
	var status := StatusCapture.new()
	var movement := MovementCapture.new()
	# No mythic runtime -> armor gate is a no-op, knockback lands normally.
	var deps := {
		"status_effect_state": status,
		"movement_state": movement,
	}
	var moon: Object = Stage4MoonEvent.new()
	_run_fragment_hit(moon, owner, deps)
	_expect(_has_burn(status), "unarmored fragment should apply burn")
	_expect(movement.calls.size() == 1, "unarmored fragment should apply exactly one knockback")
	_expect(
		is_equal_approx(owner.special_gauge, 100.0 - FRAGMENT_GAUGE_DRAIN),
		"unarmored fragment should only drain its own 2 gauge (expected 98). got %s" % owner.special_gauge
	)


func _test_cleanse_skips_whole_hit() -> void:
	var owner := FakeOwner.new()
	owner.special_gauge = 100.0
	var status := StatusCapture.new()
	var movement := MovementCapture.new()
	var deps := {
		"smasher_cleanse_state": CleanseImmune.new(),
		"status_effect_state": status,
		"movement_state": movement,
	}
	var moon: Object = Stage4MoonEvent.new()
	var scene := _run_fragment_hit(moon, owner, deps)
	# Cleanse = full-hit immunity: NOTHING of the hit applies.
	_expect(status.calls.is_empty(), "cleanse must skip the burn (whole-hit immunity)")
	_expect(movement.calls.is_empty(), "cleanse must skip the knockback")
	_expect(is_zero_approx(moon.player_burn_timer_frames), "cleanse must not arm the burn timer")
	_expect(is_equal_approx(owner.special_gauge, 100.0), "cleanse must not drain gauge")
	_expect(not scene.has("stage4_player_burn_active"), "cleanse must not flag burn active")
	_expect(int(scene.get("stage4_moon_fragment_player_hits", 0)) == 0, "cleanse must not count the hit")


func _has_burn(status: Object) -> bool:
	for call in status.calls:
		if String(call.get("effect", "")) == "burn":
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
