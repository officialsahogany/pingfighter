extends SceneTree

# Seals the flight-pet feed-bowl RETURN glide: after a flight companion finishes
# eating at the ground bowl, it must fly back up to its pre-feed air spot before the
# position override releases, instead of teleporting straight to its air lane
# ("먹이 다 먹은 뒤 갑자기 시야에서 사라짐"). Ground (patrol) pets keep their lane Y,
# so they must still release immediately with no extra return phase.

const LingpetFeedBowlState := preload("res://scripts/lingpet/lingpet_feed_bowl_state.gd")

const GROUND_BOWL_POS := Vector2(400.0, 700.0)
const FLIGHT_AIR_POS := Vector2(400.0, 250.0)
const GROUND_AIR_POS := Vector2(300.0, 700.0)
const DT := 1.0 / 60.0

var _failures: Array[String] = []


func _init() -> void:
	_test_flight_pet_glides_home_after_eating()
	_test_ground_pet_releases_immediately_after_eating()

	if _failures.is_empty():
		print("lingpet_feed_bowl_return_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_flight_pet_glides_home_after_eating() -> void:
	var state := LingpetFeedBowlState.new()
	_expect(state.arm(GROUND_BOWL_POS, FLIGHT_AIR_POS, "sortie_flight"), "flight feed should arm")

	var completed_count := 0
	var saw_return_after_eat := false
	var return_start_y := 0.0
	var min_y_during_return := 9999.0
	var final_override := Vector2.ZERO
	var released := false

	for _i in range(600):
		var result: Dictionary = state.advance(DT, state.get_companion_position_override(FLIGHT_AIR_POS), "sortie_flight")
		if bool(result.get("completed", false)):
			completed_count += 1
			# The instant eating ends, satiety is granted (completed) but the flight
			# pet has NOT yet released — it enters the return glide with the override live.
			_expect_str(str(result.get("phase", "")), "return", "flight feed should enter the return phase when eating completes")
			_expect(state.is_active(), "flight feed should stay active during the return glide")
			_expect(not state.has_visible_effects(), "the eaten bowl should stop drawing during the return glide")
			_expect(state.has_companion_position_override(), "flight feed should keep the position override through the return glide")
			saw_return_after_eat = true
			return_start_y = float(state.get_companion_position_override(FLIGHT_AIR_POS).y)
		if str(state.get_snapshot().get("feed_bowl_phase", "")) == "return":
			min_y_during_return = minf(min_y_during_return, float(state.get_companion_position_override(FLIGHT_AIR_POS).y))
		if not state.is_active():
			released = true
			final_override = float_pos(state.get_snapshot().get("feed_bowl_companion_pos", Vector2.ZERO))
			break

	_expect(saw_return_after_eat, "flight feed should report a single eating->return transition")
	_expect_eq(completed_count, 1, "flight feed must grant satiety exactly once (at eating end)")
	_expect(released, "flight feed should eventually release after the return glide")
	# The pet must actually travel UP (toward the air spot) during the return, not snap.
	_expect(min_y_during_return < return_start_y - 40.0, "flight feed should glide the companion up toward its air spot during the return")
	_expect(final_override.distance_to(FLIGHT_AIR_POS) <= 1.0, "flight feed should release at the pre-feed air spot")


func _test_ground_pet_releases_immediately_after_eating() -> void:
	var state := LingpetFeedBowlState.new()
	_expect(state.arm(GROUND_BOWL_POS, GROUND_AIR_POS, "patrol"), "ground feed should arm")

	var completed_count := 0
	var active_at_completion := true

	for _i in range(600):
		var result: Dictionary = state.advance(DT, GROUND_AIR_POS, "patrol")
		if bool(result.get("completed", false)):
			completed_count += 1
			active_at_completion = state.is_active()
		if not state.is_active():
			break

	_expect_eq(completed_count, 1, "ground feed must complete exactly once")
	_expect(not active_at_completion, "ground feed should release immediately on completion (no return phase)")
	_expect_str(str(state.get_snapshot().get("feed_bowl_phase", "")), "", "ground feed should clear its phase on release")


func float_pos(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected '%s', got '%s')" % [message, expected, actual])
