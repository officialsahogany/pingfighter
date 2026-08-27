extends SceneTree

const CommandoSupplyDropAircraftCollisionResolver := preload("res://scripts/characters/commando_supply_drop_aircraft_collision_resolver.gd")
const CommandoSupplyDropCrashImpactState := preload("res://scripts/characters/commando_supply_drop_crash_impact_state.gd")
const CommandoSupplyDropCrashResponse := preload("res://scripts/characters/commando_supply_drop_crash_response.gd")

const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"
const RESPONSE_PATH := "res://scripts/characters/commando_supply_drop_crash_response.gd"

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var calls := 0
	var last_amount := 0.0
	var last_intensity := 0.0

	func max_screen_shake(amount: float, intensity: float) -> void:
		calls += 1
		last_amount = amount
		last_intensity = intensity


class FakeMovementState:
	extends RefCounted

	var calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false
	var last_cleansable := false

	func start_knockback(
		velocity: float,
		frames: float,
		decay: float,
		replace: bool,
		cleansable: bool
	) -> bool:
		calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay
		last_replace = replace
		last_cleansable = cleansable
		return true


func _init() -> void:
	_verify_owner_boundary()
	_verify_screen_shake_adapter()
	_verify_ball_impulse_is_consumed_before_aircraft_hit_gates()
	_verify_player_knockback_direction_and_one_shot_gate()
	_verify_player_can_enter_an_active_blast_late()

	if _failures.is_empty():
		print("commando_supply_drop_crash_response_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(RESPONSE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropCrashResponse := preload(\"%s\")" % RESPONSE_PATH) >= 0,
		"Supply Drop host should preload the focused crash-response adapter"
	)
	_expect(
		host_source.find("var _crash_response: Object = CommandoSupplyDropCrashResponse.new(_crash_impact_state, _collision_resolver)") >= 0,
		"Supply Drop host should retain one crash-response adapter"
	)
	for moved_marker in [
		"func _apply_crash_impact_screen_shake(",
		"func _try_apply_crash_blast_player_knockback(",
		"func _get_player_movement_state(",
		"func _apply_pending_crash_ball_impulse(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain crash-response marker %s" % moved_marker)
	for delegation in [
		"_crash_response.apply_screen_shake(",
		"_crash_response.try_apply_player_knockback(",
		"_crash_response.apply_pending_ball_impulse(",
	]:
		_expect(host_source.find(delegation) >= 0, "Supply Drop host should delegate %s" % delegation)
	for owner_marker in [
		"func apply_screen_shake(",
		"func try_apply_player_knockback(",
		"func apply_pending_ball_impulse(",
		"func _get_player_movement_state(",
	]:
		_expect(owner_source.find(owner_marker) >= 0, "crash-response adapter should implement %s" % owner_marker)


func _verify_screen_shake_adapter() -> void:
	var response: Object = _new_response()
	var feedback := FakeFeedback.new()
	_expect(response.apply_screen_shake({"feedback": feedback}, 0.2, 7.0), "valid feedback should receive the crash shake")
	_expect(feedback.calls == 1, "crash shake should be emitted exactly once per adapter call")
	_expect(is_equal_approx(feedback.last_amount, 0.2), "crash shake should retain its amount")
	_expect(is_equal_approx(feedback.last_intensity, 7.0), "crash shake should retain its intensity")
	_expect(not response.apply_screen_shake({}, 0.2, 7.0), "missing feedback should be a safe no-op")


func _verify_ball_impulse_is_consumed_before_aircraft_hit_gates() -> void:
	var impact_state: Object = CommandoSupplyDropCrashImpactState.new()
	var response: Object = CommandoSupplyDropCrashResponse.new(
		impact_state,
		CommandoSupplyDropAircraftCollisionResolver.new()
	)
	var center := Vector2(300.0, 660.0)
	impact_state.arm(center, 0.6)
	var initial_velocity := Vector2(0.0, 5.0)
	var scene := {
		"ball_pos": center + Vector2(0.0, -40.0),
		"ball_vel": initial_velocity,
	}
	_expect(
		response.apply_pending_ball_impulse(scene, 180.0, 16.0, 22.0, 0.35),
		"armed in-radius crash should mutate the ball even after aircraft hit gates close"
	)
	var knocked_velocity: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	_expect(knocked_velocity != initial_velocity, "crash response should change an in-radius ball velocity")
	_expect(knocked_velocity.y < 0.0, "crash response should bias the ball upward")
	var second_scene := {
		"ball_pos": center + Vector2(0.0, -40.0),
		"ball_vel": initial_velocity,
	}
	_expect(
		not response.apply_pending_ball_impulse(second_scene, 180.0, 16.0, 22.0, 0.35),
		"crash ball impulse should be consumed on its first response attempt"
	)
	_expect(second_scene.get("ball_vel", Vector2.ZERO) == initial_velocity, "consumed crash impulse must not mutate a later ball frame")


func _verify_player_knockback_direction_and_one_shot_gate() -> void:
	var impact_state: Object = CommandoSupplyDropCrashImpactState.new()
	var response: Object = CommandoSupplyDropCrashResponse.new(
		impact_state,
		CommandoSupplyDropAircraftCollisionResolver.new()
	)
	var movement := FakeMovementState.new()
	var center := Vector2(300.0, 660.0)
	impact_state.arm(center, 0.6)
	var centered_context := {
		"player_paddle_rect": Rect2(Vector2(250.0, 635.0), Vector2(100.0, 50.0)),
	}
	_expect(
		response.try_apply_player_knockback(
			centered_context,
			{"movement_state": movement},
			"right_to_left",
			5.0,
			180.0,
			36.0,
			12.0,
			0.85
		),
		"centered paddle should use aircraft direction as its blast fallback"
	)
	_expect(movement.calls == 1, "successful player crash response should start one knockback")
	_expect(is_equal_approx(movement.last_velocity, -36.0), "right-to-left fallback should shove a centered paddle left")
	_expect(is_equal_approx(movement.last_frames, 12.0), "crash response should preserve knockback frames")
	_expect(is_equal_approx(movement.last_decay, 0.85), "crash response should preserve knockback decay")
	_expect(movement.last_replace and movement.last_cleansable, "crash response should preserve replace and cleansable flags")
	_expect(
		not response.try_apply_player_knockback(
			centered_context,
			{"movement_state": movement},
			"right_to_left",
			5.0,
			180.0,
			36.0,
			12.0,
			0.85
		),
		"successful player knockback should consume the blast gate"
	)
	_expect(movement.calls == 1, "consumed player crash response must stay one-shot")


func _verify_player_can_enter_an_active_blast_late() -> void:
	var impact_state: Object = CommandoSupplyDropCrashImpactState.new()
	var response: Object = CommandoSupplyDropCrashResponse.new(
		impact_state,
		CommandoSupplyDropAircraftCollisionResolver.new()
	)
	var movement := FakeMovementState.new()
	var center := Vector2(300.0, 660.0)
	impact_state.arm(center, 0.6)
	var far_context := {
		"player_paddle_rect": Rect2(Vector2(-100.0, 635.0), Vector2(100.0, 50.0)),
	}
	_expect(
		not response.try_apply_player_knockback(far_context, {"movement_state": movement}, "left_to_right", 5.0, 180.0, 36.0, 12.0, 0.85),
		"paddle outside the live blast should not be shoved"
	)
	_expect(impact_state.is_player_knockback_pending(), "a miss should keep the live blast gate open for a later walk-in")
	var near_context := {
		"player_paddle_rect": Rect2(Vector2(340.0, 635.0), Vector2(100.0, 50.0)),
	}
	_expect(
		response.try_apply_player_knockback(near_context, {"movement_state": movement}, "left_to_right", 5.0, 180.0, 36.0, 12.0, 0.85),
		"paddle entering before blast expiry should be shoved"
	)
	_expect(movement.calls == 1 and movement.last_velocity > 0.0, "late right-side entrant should be shoved away to the right")


func _new_response() -> Object:
	return CommandoSupplyDropCrashResponse.new(
		CommandoSupplyDropCrashImpactState.new(),
		CommandoSupplyDropAircraftCollisionResolver.new()
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
