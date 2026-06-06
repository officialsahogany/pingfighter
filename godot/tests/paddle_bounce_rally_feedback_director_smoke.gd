extends SceneTree

const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")

var _failures: Array[String] = []


class FakeBallIntensity:
	extends RefCounted

	var fixed_intensity := 0.0
	var tier := 0
	var tier_advanced := false
	var last_hit := ""

	func _init(new_intensity: float = 0.0, new_tier: int = 0, new_tier_advanced: bool = false) -> void:
		fixed_intensity = new_intensity
		tier = new_tier
		tier_advanced = new_tier_advanced

	func register_hit(source: String) -> void:
		last_hit = source

	func calculate(_ball_vel: Vector2) -> float:
		return fixed_intensity

	func did_rally_tier_advance() -> bool:
		return tier_advanced

	func get_rally_tier() -> int:
		return tier


class FakeFeedback:
	extends RefCounted

	var shake_calls: Array[Dictionary] = []
	var vibration_calls := 0

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_calls.append({
			"amount": amount,
			"intensity": intensity,
		})

	func trigger_paddle_hit_vibration(
		_ball_speed: float,
		_is_player: bool = true,
		_drive_activated: bool = false,
		_power_activated: bool = false
	) -> bool:
		vibration_calls += 1
		return true


class FakeAudio:
	extends RefCounted

	var paddle_hit_count := 0
	var rally_accent_tiers: Array[int] = []

	func play_paddle_hit() -> void:
		paddle_hit_count += 1

	func play_rally_tier_accent(tier: int) -> void:
		rally_accent_tiers.append(tier)


class FakeBaseAudioOnly:
	extends RefCounted

	var paddle_hit_count := 0

	func play_paddle_hit() -> void:
		paddle_hit_count += 1


class FakeStage2SkillState:
	extends RefCounted

	var active := false

	func _init(new_active: bool) -> void:
		active = new_active

	func is_speed_defense_active() -> bool:
		return active


func _init() -> void:
	_verify_shake_uses_narrow_raw_intensity_band()
	_verify_tier_accent_fires_only_on_real_tier_edges()
	_verify_audio_gates_suppress_base_and_accent_together()
	_verify_no_accent_without_audio_method()

	if _failures.is_empty():
		print("paddle_bounce_rally_feedback_director_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shake_uses_narrow_raw_intensity_band() -> void:
	var low_feedback := FakeFeedback.new()
	var high_feedback := FakeFeedback.new()
	_register_with({
		"feedback": low_feedback,
		"audio": FakeAudio.new(),
		"ball_intensity": FakeBallIntensity.new(0.0),
	}, Vector2(0.0, -8.0))
	_register_with({
		"feedback": high_feedback,
		"audio": FakeAudio.new(),
		"ball_intensity": FakeBallIntensity.new(1.0),
	}, Vector2(0.0, -35.0))
	var low: Dictionary = low_feedback.shake_calls[0]
	var high: Dictionary = high_feedback.shake_calls[0]
	_expect(is_equal_approx(float(low.get("amount", 0.0)), 0.075), "raw 0 shake amount should keep the shipped floor")
	_expect(is_equal_approx(float(low.get("intensity", 0.0)), 2.2), "raw 0 shake intensity should keep the shipped floor")
	_expect(is_equal_approx(float(high.get("amount", 0.0)), 0.10), "raw 1 shake amount should clamp at the nausea guard")
	_expect(is_equal_approx(float(high.get("intensity", 0.0)), 2.6), "raw 1 shake intensity should clamp at the nausea guard")
	_expect(float(high.get("amount", 0.0)) > float(low.get("amount", 0.0)), "high raw intensity should gently raise shake amount")
	_expect(float(high.get("intensity", 0.0)) > float(low.get("intensity", 0.0)), "high raw intensity should gently raise shake intensity")


func _verify_tier_accent_fires_only_on_real_tier_edges() -> void:
	var router := PaddleBounceRallyFeedbackRouter.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var ball_intensity := BallIntensity.new()
	var deps := {
		"feedback": feedback,
		"audio": audio,
		"ball_intensity": ball_intensity,
	}
	var is_player := true
	for _index in range(6):
		router.register(Vector2(320.0, 600.0), Vector2(0.0, -18.0), is_player, false, deps, {})
		is_player = not is_player
	_expect(audio.paddle_hit_count == 6, "base paddle hit should still play on every non-suppressed rally hit")
	_expect(audio.rally_accent_tiers == [1], "rally accent should fire once on the tier 1 edge only")
	router.register(Vector2(320.0, 600.0), Vector2(0.0, -18.0), is_player, false, deps, {})
	_expect(audio.paddle_hit_count == 7, "base paddle hit should continue after tier edge")
	_expect(audio.rally_accent_tiers == [1], "rally accent should not repeat on non-edge hits")


func _verify_audio_gates_suppress_base_and_accent_together() -> void:
	var power_audio := FakeAudio.new()
	_register_with({
		"feedback": FakeFeedback.new(),
		"audio": power_audio,
		"ball_intensity": FakeBallIntensity.new(1.0, 3, true),
	}, Vector2(0.0, -30.0), true, true)
	_expect(power_audio.paddle_hit_count == 0, "power-activated hits should keep base paddle audio suppressed")
	_expect(power_audio.rally_accent_tiers.is_empty(), "power-activated hits should suppress rally tier accents too")

	var stage2_audio := FakeAudio.new()
	_register_with({
		"feedback": FakeFeedback.new(),
		"audio": stage2_audio,
		"ball_intensity": FakeBallIntensity.new(1.0, 2, true),
		"stage2_boss_skill_state": FakeStage2SkillState.new(true),
	}, Vector2(0.0, 30.0), false, false, {"current_stage": 2, "stage2_speed_defense_active": true})
	_expect(stage2_audio.paddle_hit_count == 0, "stage2 speed-defense suppression should keep base paddle audio muted")
	_expect(stage2_audio.rally_accent_tiers.is_empty(), "stage2 speed-defense suppression should mute rally tier accents too")


func _verify_no_accent_without_audio_method() -> void:
	var feedback := FakeFeedback.new()
	var ball_intensity := FakeBallIntensity.new(1.0, 1, true)
	var audio_without_accent := FakeBaseAudioOnly.new()
	_register_with({
		"feedback": feedback,
		"audio": audio_without_accent,
		"ball_intensity": ball_intensity,
	}, Vector2(0.0, -20.0))
	_expect(audio_without_accent.paddle_hit_count == 1, "audio without rally accent method should still play base paddle hit")


func _register_with(
	deps: Dictionary,
	ball_vel: Vector2,
	is_player: bool = true,
	power_activated: bool = false,
	context: Dictionary = {}
) -> void:
	PaddleBounceRallyFeedbackRouter.new().register(Vector2(320.0, 600.0), ball_vel, is_player, power_activated, deps, context)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
