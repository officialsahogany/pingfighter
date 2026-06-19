extends SceneTree

const BattleFeedbackState := preload("res://scripts/effects/battle_feedback_state.gd")
const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")

var _failed := false


class FakeBallIntensity:
	var last_hit := ""

	func register_hit(source: String) -> void:
		last_hit = source

	func calculate(ball_vel: Vector2) -> float:
		return clamp(ball_vel.length() / 35.0, 0.0, 1.0)


class FakeBallEffects:
	var pulse_count := 0

	func register_hit_pulse(_pos: Vector2, _velocity: Vector2, _intensity: float = 0.0, _kind: String = "hit") -> void:
		pulse_count += 1


class FakeAudio:
	var paddle_hit_count := 0

	func play_paddle_hit(_source_x: float = 380.0) -> void:
		paddle_hit_count += 1


class FakeFeedback:
	var vibration_calls: Array = []
	var shake_calls := 0

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1

	func trigger_paddle_hit_vibration(
		ball_speed: float,
		is_player: bool = true,
		drive_activated: bool = false,
		power_activated: bool = false
	) -> bool:
		vibration_calls.append({
			"ball_speed": ball_speed,
			"is_player": is_player,
			"drive_activated": drive_activated,
			"power_activated": power_activated,
		})
		return true


func _init() -> void:
	_verify_vibration_payload_scales_with_ball_speed()
	_verify_vibration_sensitivity_scales_from_middle_baseline()
	_verify_rally_feedback_routes_player_hit_vibration()
	if _failed:
		quit(1)
	else:
		print("gamepad_vibration_feedback_smoke: ok")
		quit()


func _verify_vibration_payload_scales_with_ball_speed() -> void:
	var feedback := BattleFeedbackState.new()
	var slow: Dictionary = feedback.build_paddle_hit_vibration(8.0, true)
	var fast: Dictionary = feedback.build_paddle_hit_vibration(30.0, true)
	var capped: Dictionary = feedback.build_paddle_hit_vibration(99.0, true)
	var drive: Dictionary = feedback.build_paddle_hit_vibration(12.0, true, true, false)
	var power: Dictionary = feedback.build_paddle_hit_vibration(12.0, true, false, true)
	_expect(not slow.is_empty(), "slow player paddle hits should still produce a light vibration payload")
	_expect(float(fast.get("strong", 0.0)) > float(slow.get("strong", 0.0)), "faster balls should produce stronger motor vibration")
	_expect(float(fast.get("weak", 0.0)) > float(slow.get("weak", 0.0)), "faster balls should raise weak motor vibration too")
	_expect(float(fast.get("duration", 0.0)) > float(slow.get("duration", 0.0)), "faster balls should last slightly longer")
	_expect(float(slow.get("strong", 0.0)) >= 0.45, "even baseline player paddle hits should feel punchy")
	_expect(float(slow.get("duration", 0.0)) >= 0.08, "baseline player paddle vibration should be long enough to feel")
	_expect(is_equal_approx(float(capped.get("speed_ratio", -1.0)), 1.0), "very fast balls should clamp vibration strength")
	_expect(is_equal_approx(float(capped.get("strong", 0.0)), 1.0), "very fast balls should reach full strong motor vibration")
	_expect(str(drive.get("profile", "")) == "drive", "drive activation should use the drive vibration profile")
	_expect(float(drive.get("strong", 0.0)) >= float(fast.get("strong", 0.0)), "drive activation should feel stronger than normal fast hits")
	_expect(float(drive.get("duration", 0.0)) > float(capped.get("duration", 0.0)), "drive activation should last longer than normal hits")
	_expect(str(power.get("profile", "")) == "power_smash", "Power Smashing should use the power-smash vibration profile")
	_expect(is_equal_approx(float(power.get("strong", 0.0)), 1.0), "Power Smashing should max out the strong motor")
	_expect(is_equal_approx(float(power.get("weak", 0.0)), 1.0), "Power Smashing should max out the weak motor")
	_expect(float(power.get("duration", 0.0)) > float(drive.get("duration", 0.0)), "Power Smashing should be heavier than drive activation")
	_expect(feedback.build_paddle_hit_vibration(18.0, false).is_empty(), "boss paddle hits should not rumble the player's controller")
	_expect(feedback.build_paddle_hit_vibration(0.0, true).is_empty(), "zero-speed hits should not request vibration")


func _verify_vibration_sensitivity_scales_from_middle_baseline() -> void:
	var feedback := BattleFeedbackState.new()
	var baseline: Dictionary = feedback.build_paddle_hit_vibration(12.0, true)
	var low: Dictionary = GamepadVibrationSettings.apply_vibration_sensitivity(baseline, 1)
	var middle: Dictionary = GamepadVibrationSettings.apply_vibration_sensitivity(baseline, 3)
	var high: Dictionary = GamepadVibrationSettings.apply_vibration_sensitivity(baseline, 5)
	_expect(is_equal_approx(float(middle.get("strong", 0.0)), float(baseline.get("strong", 0.0))), "vibration level 3 should preserve the shipped strong-motor baseline")
	_expect(is_equal_approx(float(middle.get("weak", 0.0)), float(baseline.get("weak", 0.0))), "vibration level 3 should preserve the shipped weak-motor baseline")
	_expect(float(low.get("strong", 0.0)) < float(middle.get("strong", 0.0)), "vibration level 1 should soften the strong motor")
	_expect(float(high.get("strong", 0.0)) > float(middle.get("strong", 0.0)), "vibration level 5 should strengthen non-capped strong motor hits")
	_expect(float(low.get("duration", 0.0)) < float(middle.get("duration", 0.0)), "vibration level 1 should shorten feedback")
	_expect(float(high.get("duration", 0.0)) > float(middle.get("duration", 0.0)), "vibration level 5 should lengthen feedback slightly")
	_expect(str(high.get("vibration_level", "")) == "5", "scaled payload should carry the applied vibration level")


func _verify_rally_feedback_routes_player_hit_vibration() -> void:
	var router := PaddleBounceRallyFeedbackRouter.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var ball_intensity := FakeBallIntensity.new()
	var ball_effects := FakeBallEffects.new()
	var deps := {
		"feedback": feedback,
		"audio": audio,
		"ball_intensity": ball_intensity,
		"ball_effects": ball_effects,
	}
	router.register(Vector2(320.0, 704.0), Vector2(2.0, -12.0), true, false, deps, {})
	_expect(feedback.vibration_calls.size() == 1, "player paddle hit should request one gamepad vibration")
	_expect(bool((feedback.vibration_calls[0] as Dictionary).get("is_player", false)), "vibration request should keep the player-hit flag")
	_expect(is_equal_approx(float((feedback.vibration_calls[0] as Dictionary).get("ball_speed", 0.0)), Vector2(2.0, -12.0).length()), "vibration request should use post-hit ball speed")
	router.register(Vector2(320.0, 48.0), Vector2(2.0, 12.0), false, false, deps, {})
	_expect(feedback.vibration_calls.size() == 1, "boss paddle hit should leave the player's controller quiet")
	router.register(Vector2(320.0, 704.0), Vector2(0.0, -16.0), true, false, deps, {}, true)
	_expect(bool((feedback.vibration_calls[1] as Dictionary).get("drive_activated", false)), "drive paddle hit should preserve the drive vibration flag")
	router.register(Vector2(320.0, 704.0), Vector2(0.0, -18.0), true, true, deps, {}, false)
	_expect(bool((feedback.vibration_calls[2] as Dictionary).get("power_activated", false)), "Power Smashing paddle hit should preserve the power vibration flag")
	_expect(audio.paddle_hit_count == 3, "vibration routing should not disturb existing paddle-hit audio")
	_expect(ball_effects.pulse_count == 4, "vibration routing should not disturb existing hit pulses")
	_expect(ball_intensity.last_hit == "player", "existing ball intensity registration should still run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
