extends SceneTree

const CommandoFirearmPistolFeedbackState := preload("res://scripts/characters/commando_firearm_pistol_feedback_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_pistol_feedback_state()
	_verify_runtime_delegates_pistol_feedback_state()

	if _failures.is_empty():
		print("commando_firearm_pistol_feedback_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pistol_feedback_state() -> void:
	_expect(CommandoFirearmPistolFeedbackState.is_supported_hit_kind("headshot"), "headshot should be supported")
	_expect(CommandoFirearmPistolFeedbackState.is_supported_hit_kind("legshot"), "legshot should be supported")
	_expect(not CommandoFirearmPistolFeedbackState.is_supported_hit_kind("normal"), "normal hit should not be supported")

	var boss_rect := Rect2(Vector2(330.0, 50.0), Vector2(100.0, 40.0))
	var head_feedback: Dictionary = CommandoFirearmPistolFeedbackState.build_feedback(
		"headshot",
		boss_rect,
		Vector2(760.0, 750.0),
		60.0,
		"헤드샷!",
		"레그샷!"
	)
	_expect(str(head_feedback.get("text", "")) == "헤드샷!", "headshot feedback should use Korean text")
	_expect(head_feedback.get("text_pos", Vector2.ZERO) == Vector2(300.0, 70.0), "feedback text position should preserve legacy clamp math")
	_expect(head_feedback.get("wave_pos", Vector2.ZERO) == Vector2(380.0, 56.0), "feedback wave position should preserve legacy clamp math")
	_expect(is_equal_approx(float(head_feedback.get("timer_frames", 0.0)), 60.0), "feedback should preserve timer")

	var leg_feedback: Dictionary = CommandoFirearmPistolFeedbackState.build_feedback(
		"legshot",
		boss_rect,
		Vector2(760.0, 750.0),
		60.0,
		"헤드샷!",
		"레그샷!"
	)
	_expect(str(leg_feedback.get("text", "")) == "레그샷!", "legshot feedback should use Korean text")
	_expect(CommandoFirearmPistolFeedbackState.build_feedback("normal", boss_rect, Vector2(760.0, 750.0), 60.0, "H", "L").is_empty(), "unsupported feedback should return empty")

	var advanced: Dictionary = CommandoFirearmPistolFeedbackState.advance_feedback(head_feedback, 15.0)
	_expect(bool(advanced.get("active", false)), "active feedback should stay active while timer remains")
	_expect(is_equal_approx(float((advanced.get("feedback", {}) as Dictionary).get("timer_frames", 0.0)), 45.0), "feedback timer should tick down")
	_expect(not bool(CommandoFirearmPistolFeedbackState.advance_feedback(head_feedback, 60.0).get("active", true)), "feedback should expire at zero timer")


func _verify_runtime_delegates_pistol_feedback_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var feedback: Dictionary = runtime._build_pistol_hit_feedback(
		"headshot",
		{"boss_pos": Vector2(330.0, 50.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0}
	)
	_expect(str(feedback.get("text", "")) == "헤드샷!", "runtime feedback builder should delegate")
	runtime._spawn_pistol_hit_feedback(
		"legshot",
		{"boss_pos": Vector2(330.0, 50.0), "boss_paddle_width": 100.0, "boss_hitbox_height": 40.0}
	)
	var feedbacks: Array = runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", [])
	_expect(feedbacks.size() == 1, "runtime spawn should append supported feedback")
	runtime._update_pistol_feedbacks(60.0)
	feedbacks = runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", [])
	_expect(feedbacks.is_empty(), "runtime update should expire feedback through helper")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
