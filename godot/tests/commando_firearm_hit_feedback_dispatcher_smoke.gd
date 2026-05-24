extends SceneTree

const CommandoFirearmHitFeedbackDispatcher := preload("res://scripts/characters/commando_firearm_hit_feedback_dispatcher.gd")

var _failures: Array[String] = []


class FakeImpactEffects:
	extends RefCounted

	var particles: Array = []

	func spawn_hit_particles(pos: Vector2, color: Color, velocity: Vector2, intensity: float, speed: float) -> void:
		particles.append({
			"pos": pos,
			"color": color,
			"velocity": velocity,
			"intensity": intensity,
			"speed": speed,
		})


class FakeFeedback:
	extends RefCounted

	var max_calls: Array = []
	var set_calls: Array = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		max_calls.append({"amount": amount, "intensity": intensity})

	func set_screen_shake(amount: float, intensity: float) -> void:
		set_calls.append({"amount": amount, "intensity": intensity})


class FakeFallbackFeedback:
	extends RefCounted

	var set_calls: Array = []

	func set_screen_shake(amount: float, intensity: float) -> void:
		set_calls.append({"amount": amount, "intensity": intensity})


class FakeAnimationState:
	extends RefCounted

	var calls: Array = []

	func trigger_boss_hit(boss_vel: float, has_hit_sprite: bool) -> void:
		calls.append({"boss_vel": boss_vel, "has_hit_sprite": has_hit_sprite})


class FakeBallEffects:
	extends RefCounted

	var pulses: Array = []

	func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float, kind: String) -> void:
		pulses.append({
			"pos": pos,
			"velocity": velocity,
			"intensity": intensity,
			"kind": kind,
		})


func _init() -> void:
	_verify_impact_particles()
	_verify_hit_feedback()
	_verify_boss_hit_animation()
	_verify_ball_hit_pulse()
	_verify_missing_deps_are_noops()
	_verify_removed_runtime_feedback_bridges()

	if _failures.is_empty():
		print("commando_firearm_hit_feedback_dispatcher_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_impact_particles() -> void:
	var impact_effects := FakeImpactEffects.new()
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(
		Vector2(12.0, 34.0),
		Color(0.1, 0.2, 0.3),
		Vector2(3.0, 4.0),
		0.75,
		{"impact_effects": impact_effects}
	)
	_expect(impact_effects.particles.size() == 1, "impact dispatcher should spawn one particle burst")
	var particle: Dictionary = impact_effects.particles[0]
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(12.0, 34.0), "impact dispatcher should preserve position")
	_expect(is_equal_approx(float(particle.get("speed", 0.0)), 5.0), "impact dispatcher should pass velocity length")


func _verify_hit_feedback() -> void:
	var feedback := FakeFeedback.new()
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback(
		{"shake_amount": 0.08, "shake_intensity": 1.6},
		{"feedback": feedback}
	)
	_expect(feedback.max_calls.size() == 1, "feedback dispatcher should prefer max screen shake")
	_expect(feedback.set_calls.is_empty(), "feedback dispatcher should not call fallback shake after max shake")

	var fallback_feedback := FakeFallbackFeedback.new()
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback({}, {"feedback": fallback_feedback})
	_expect(fallback_feedback.set_calls.size() == 1, "feedback dispatcher should fall back to set screen shake")
	_expect(is_equal_approx(float(fallback_feedback.set_calls[0].get("amount", 0.0)), 0.04), "feedback dispatcher should use default shake amount")


func _verify_boss_hit_animation() -> void:
	var animation_state := FakeAnimationState.new()
	CommandoFirearmHitFeedbackDispatcher.trigger_boss_hit_animation(
		{"boss_vel": -42.0, "boss_has_hit_sprite": true},
		{"animation_state": animation_state}
	)
	_expect(animation_state.calls.size() == 1, "feedback dispatcher should trigger boss hit animation")
	_expect(bool(animation_state.calls[0].get("has_hit_sprite", false)), "feedback dispatcher should preserve hit-sprite flag")


func _verify_ball_hit_pulse() -> void:
	var ball_effects := FakeBallEffects.new()
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(
		Vector2(10.0, 20.0),
		Vector2(5.0, -2.0),
		2.0,
		"ak47",
		{"ball_effects": ball_effects},
		"pistol"
	)
	_expect(ball_effects.pulses.size() == 1, "feedback dispatcher should register one ball hit pulse")
	var pulse: Dictionary = ball_effects.pulses[0]
	_expect(is_equal_approx(float(pulse.get("intensity", 0.0)), 1.0), "feedback dispatcher should clamp pulse intensity")
	_expect(str(pulse.get("kind", "")) == "commando_ak47", "feedback dispatcher should use Commando pulse kind")

	var base_ball_effects := FakeBallEffects.new()
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(
		Vector2.ZERO,
		Vector2.RIGHT,
		0.5,
		"pistol",
		{"ball_effects": base_ball_effects},
		"pistol"
	)
	_expect(str(base_ball_effects.pulses[0].get("kind", "")) == "commando_base_pistol", "feedback dispatcher should use base pistol pulse kind")


func _verify_missing_deps_are_noops() -> void:
	CommandoFirearmHitFeedbackDispatcher.spawn_shared_impact_particles(Vector2.ZERO, Color.WHITE, Vector2.ZERO, 0.0, {})
	CommandoFirearmHitFeedbackDispatcher.trigger_hit_feedback({}, {})
	CommandoFirearmHitFeedbackDispatcher.trigger_boss_hit_animation({}, {})
	CommandoFirearmHitFeedbackDispatcher.register_ball_hit_pulse(Vector2.ZERO, Vector2.ZERO, 0.0, "pistol", {}, "pistol")
	_expect(true, "feedback dispatcher missing deps should be no-ops")


func _verify_removed_runtime_feedback_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_spawn_shared_impact_particles",
		"_trigger_hit_feedback",
		"_trigger_boss_hit_animation",
		"_register_ball_hit_pulse",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep hit-feedback bridge %s" % bridge_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
