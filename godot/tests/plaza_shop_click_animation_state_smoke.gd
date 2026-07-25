extends SceneTree

const PlazaShopClickAnimationState := preload("res://scripts/plaza/plaza_shop_click_animation_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaShopClickAnimationState.new()
	_expect(not state.is_active(), "new animation should be inactive")
	_expect(not state.start_with_spec({}, 0.2), "empty spec should be rejected")

	var source_spec := {
		"id": "shop_strewn_coin_pile",
		"rect": Rect2(10.0, 20.0, 80.0, 40.0),
		"nested": {"value": 3},
	}
	_expect(state.start_with_spec(source_spec, 0.2), "valid spec should start animation")
	_expect(state.is_active(), "started animation should be active")
	_expect(state.object_id == "shop_strewn_coin_pile", "active object id")
	_expect(state.object_rect == Rect2(10.0, 20.0, 80.0, 40.0), "active object rect")
	_expect(state.get_pending_object_id() == "shop_strewn_coin_pile", "pending spec id")
	(source_spec["nested"] as Dictionary)["value"] = 99
	_expect(int((state.get_pending_spec().get("nested", {}) as Dictionary).get("value", 0)) == 3, "pending spec should be deep-copied")

	_expect(not state.advance(0.10), "partial advance should not complete")
	_expect_close(state.get_progress(), 0.5, "partial progress")
	_expect(not state.has_completed_spec(), "partial animation should not expose completion")
	_expect(state.advance(0.10), "duration boundary should complete")
	_expect(not state.is_active(), "completed animation should be inactive")
	_expect(state.get_pending_object_id() == "", "completion should clear pending spec")
	_expect(state.has_completed_spec(), "completion should retain one consumable spec")
	var completed := state.consume_completed_spec()
	_expect(str(completed.get("id", "")) == "shop_strewn_coin_pile", "completed spec id")
	_expect(not state.has_completed_spec(), "completed spec should be consumed once")
	_expect(state.consume_completed_spec().is_empty(), "second completion consume should be empty")

	state.start("plain", Rect2(1.0, 2.0, 3.0, 4.0), 0.08)
	_expect(state.is_active(), "legacy start API should remain active")
	_expect(state.get_pending_spec().is_empty(), "legacy start should not retain stale spec")
	state.reset()
	_expect(not state.is_active() and not state.has_completed_spec(), "reset should clear all lifecycle state")

	if _failures.is_empty():
		print("plaza_shop_click_animation_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])
