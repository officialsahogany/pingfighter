extends SceneTree

const PlazaTransitionState := preload("res://scripts/plaza/plaza_transition_state.gd")

var failure_count := 0


func _init() -> void:
	var state := PlazaTransitionState.new()
	var target := {"type": "shop", "nested": {"id": 7}}
	_expect(state.start_building("enter", target, Vector2(100.0, 200.0), Vector2(70.0, 210.0)), "building entry should start while idle")
	target["type"] = "mutated"
	(target["nested"] as Dictionary)["id"] = 99
	_expect(str(state.building_target.get("type", "")) == "shop" and int((state.building_target.get("nested", {}) as Dictionary).get("id", 0)) == 7, "building target should be deep-copied")
	_expect(not state.start_building("return", {}, Vector2.ZERO, Vector2.ZERO), "active building transition should reject reentry")
	_expect(not state.advance_building(0.4), "building transition should remain active before its duration")
	_expect(is_equal_approx(state.get_building_progress(), 0.4), "building progress should follow its clamped timer")
	_expect(is_equal_approx(state.get_building_actor_alpha(0.0), 1.0) and is_zero_approx(state.get_building_actor_alpha(1.0)), "entry actor should fade out")
	_expect(is_zero_approx(state.get_building_actor_lift(0.0)) and is_equal_approx(state.get_building_actor_lift(1.0), -42.0), "entry actor should lift upward")
	_expect(state.advance_building(2.0), "building transition should complete at its duration")
	_expect(is_equal_approx(state.building_timer, PlazaTransitionState.BUILDING_DURATION), "building timer should clamp at duration")
	state.clear_building()
	_expect(not state.building_active and state.building_phase == "" and state.building_target.is_empty(), "building clear should reset logical state")

	_expect(state.start_building("return", {}, Vector2.ZERO, Vector2.ZERO), "return transition should start after clear")
	_expect(is_zero_approx(state.get_building_actor_alpha(0.0)) and is_equal_approx(state.get_building_actor_alpha(1.0), 1.0), "return actor should fade in")
	_expect(is_equal_approx(state.get_building_actor_lift(0.0), -34.0) and is_zero_approx(state.get_building_actor_lift(1.0)), "return actor should settle from its raised position")
	state.clear_building()

	_expect(state.start_warp("arrive"), "arrival warp should start while idle")
	_expect(not state.start_warp("exit"), "active warp should reject reentry")
	_expect(not state.advance_warp(-1.0) and state.warp_timer == 0.0, "negative delta should not rewind warp time")
	_expect(not state.advance_warp(0.5) and is_equal_approx(state.get_warp_progress(), 0.5), "arrival warp should expose mid-progress")
	_expect(is_zero_approx(state.get_warp_actor_alpha(0.0)) and is_equal_approx(state.get_warp_actor_alpha(1.0), 1.0), "arrival actor should fade in")
	_expect(is_equal_approx(state.get_warp_actor_lift(0.0), -42.0) and is_zero_approx(state.get_warp_actor_lift(1.0)), "arrival actor should settle from the pillar")
	_expect(state.advance_warp(0.5), "arrival warp should complete at its duration")
	state.clear_warp()
	_expect(state.start_warp("exit"), "exit warp should start after clear")
	_expect(is_equal_approx(state.get_warp_actor_alpha(0.0), 1.0) and is_zero_approx(state.get_warp_actor_alpha(1.0)), "exit actor should fade out")
	_expect(is_zero_approx(state.get_warp_actor_lift(0.0)) and is_equal_approx(state.get_warp_actor_lift(1.0), -48.0), "exit actor should rise through the pillar")
	state.reset()
	_expect(not state.building_active and not state.warp_active and state.get_warp_progress() == 0.0, "full reset should clear both transition channels")

	if failure_count > 0:
		quit(1)
		return
	print("plaza_transition_state_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
