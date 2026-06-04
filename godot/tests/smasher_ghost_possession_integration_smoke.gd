extends SceneTree

# Integration smoke for the ghost-smashing possession layer hosted on
# smasher_power_smash_state, plus a parse/load check of every file edited to
# wire the paddle hide + player-return fly-back.

const PowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
# Force-compile the render / physics integration files (catches syntax errors
# in the actor-context wiring, the paddle-hide renderer gate, and the
# player-return fly-back hook).
const ActorContextBuilder := preload("res://scripts/core/battle_draw_actor_context.gd")
const Stage1PlayerRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const PostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")

const FREEZE := 1.65

var _failures: Array[String] = []


func _init() -> void:
	_test_integration_files_compile()
	_test_ghost_activation_hides_paddle()
	_test_actor_context_reads_power_state_alias()
	_test_boss_return_waits_until_player_counter()
	_test_near_player_zone_returns_before_contact()
	_test_player_counter_triggers_return_with_upward_ball()
	_test_power_smash_does_not_possess()
	_test_reset_clears_possession()

	if _failures.is_empty():
		print("smasher_ghost_possession_integration_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _test_integration_files_compile() -> void:
	_expect(ActorContextBuilder != null, "battle_draw_actor_context should compile")
	_expect(Stage1PlayerRenderer != null, "stage1_player_actor_renderer should compile")
	_expect(PostHitHandler != null, "paddle_bounce_post_hit_handler should compile")


func _test_ghost_activation_hides_paddle() -> void:
	var ps := PowerSmashState.new()
	ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)  # ghost_shot = true
	_expect(ps.is_ghost_possession_active(), "ghost activation should start possession")
	_expect(ps.is_ghost_possession_paddle_hidden(), "paddle should be hidden while riding the ball")
	_expect(ps.get_ghost_possession_player_override().is_empty(), "no fly-back override while riding")
	# A boss bounce before the ghost ball is fired must not end possession.
	_expect(not ps.trigger_ghost_possession_fly_back(Vector2(380.0, 60.0)),
		"fly-back before the ball fire should be rejected")
	_expect(ps.is_ghost_possession_paddle_hidden(), "paddle stays hidden after a rejected fly-back")


func _test_actor_context_reads_power_state_alias() -> void:
	var ps := PowerSmashState.new()
	ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	var actor_context: Dictionary = ActorContextBuilder.new().build(
		_make_draw_context(),
		{"power_state": ps}
	)
	_expect(
		bool(actor_context.get("ghost_possession_paddle_hidden", false)),
		"actor draw context should read possession from power_state deps"
	)
	ps.ghost_possession_state.notify_ball_fired()
	ps.notify_ghost_possession_boss_returned()
	_expect(ps.trigger_ghost_possession_fly_back(Vector2(380.0, 60.0)), "test setup should enter fly-back")
	actor_context = ActorContextBuilder.new().build(
		_make_draw_context(),
		{"power_state": ps}
	)
	_expect(
		not bool(actor_context.get("ghost_possession_paddle_hidden", true)),
		"actor draw context should unhide during fly-back"
	)
	_expect(
		not _as_dict(actor_context.get("ghost_possession_player_override", {})).is_empty(),
		"actor draw context should expose the fly-back visual override"
	)


func _test_boss_return_waits_until_player_counter() -> void:
	var ps := PowerSmashState.new()
	ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	# The motion path calls notify_ball_fired() when the ghost ball is fired at
	# the boss; mirror that here so a boss return can arm the player-side pop.
	ps.ghost_possession_state.notify_ball_fired()
	_expect(ps.is_ghost_possession_paddle_hidden(), "paddle still hidden after the ball is fired (extended window)")
	var handler := PostHitHandler.new()
	handler.apply(
		false,
		Vector2(380.0, 60.0),
		Vector2(0.0, 10.0),
		0.0,
		120.0,
		false,
		false,
		false,
		0.0,
		0.0,
		false,
		false,
		0.0,
		_make_hit_context(),
		{"power_state": ps}
	)
	_expect(ps.has_ghost_possession_boss_returned(), "boss return should arm the player-side rematerialization")
	_expect(ps.is_ghost_possession_paddle_hidden(), "paddle should stay hidden after boss return")
	_expect(ps.get_ghost_possession_player_override().is_empty(), "boss return should not start fly-back yet")
	var player_result: Dictionary = handler.apply(
		true,
		Vector2(380.0, 690.0),
		Vector2(0.0, -11.0),
		0.0,
		84.0,
		false,
		false,
		false,
		0.0,
		0.0,
		false,
		false,
		0.0,
		_make_hit_context(),
		{"power_state": ps}
	)
	_expect(not ps.is_ghost_possession_paddle_hidden(), "paddle is shown (flying back), not hidden")
	_expect(not ps.get_ghost_possession_player_override().is_empty(), "fly-back exposes a visual override")
	_expect(_as_vec2(player_result.get("ball_vel", Vector2.ZERO)).y < 0.0, "player counter should keep the upward ball velocity")
	# Drive the fly-back to completion: update_effects feeds fps_scale/60 seconds.
	# fps_scale 15 -> 0.25s > 0.2s fly-back.
	ps.update_effects(15.0, Vector2(380.0, 710.0), true, 28.0)
	_expect(not ps.is_ghost_possession_active(), "possession should end after the fly-back lands")
	_expect(not ps.is_ghost_possession_paddle_hidden(), "paddle visible again after landing")


func _test_near_player_zone_returns_before_contact() -> void:
	var far_ps := PowerSmashState.new()
	far_ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	far_ps.ghost_possession_state.notify_ball_fired()
	far_ps.notify_ghost_possession_boss_returned()
	var far_context: Dictionary = _make_hit_context()
	far_context["ball_vel"] = Vector2(0.0, 18.0)
	far_ps.update_effects(1.0, Vector2(380.0, 470.0), true, 28.0, far_context)
	_expect(far_ps.is_ghost_possession_paddle_hidden(), "far return should keep Mika riding the ball")
	_expect(far_ps.get_ghost_possession_player_override().is_empty(), "far return should not expose fly-back")

	var near_ps := PowerSmashState.new()
	near_ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	near_ps.ghost_possession_state.notify_ball_fired()
	near_ps.notify_ghost_possession_boss_returned()
	var near_context: Dictionary = _make_hit_context()
	near_context["ball_vel"] = Vector2(0.0, 18.0)
	near_ps.update_effects(1.0, Vector2(380.0, 545.0), true, 28.0, near_context)
	_expect(not near_ps.is_ghost_possession_paddle_hidden(), "near player zone should start fly-back before contact")
	_expect(
		not near_ps.get_ghost_possession_player_override().is_empty(),
		"near player zone should expose a visual return override"
	)


func _test_player_counter_triggers_return_with_upward_ball() -> void:
	var ps := PowerSmashState.new()
	ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	ps.ghost_possession_state.notify_ball_fired()
	ps.notify_ghost_possession_boss_returned()
	var controller := PaddleBounceController.new()
	var context: Dictionary = _make_hit_context()
	context["ball_pos"] = Vector2(380.0, 690.0)
	context["ball_vel"] = Vector2(0.0, 11.0)
	var result: Dictionary = controller.bounce(
		338.0,
		84.0,
		true,
		context,
		{
			"power_state": ps,
			"paddle_bounce_state": PaddleBounceState.new(),
		}
	)
	_expect(_as_vec2(result.get("ball_vel", Vector2.ZERO)).y < 0.0, "player paddle should counter the returned ghost ball upward")
	_expect(not ps.is_ghost_possession_paddle_hidden(), "player counter should unhide Mika into fly-back")
	_expect(not ps.get_ghost_possession_player_override().is_empty(), "player counter should expose the fly-back override")


func _test_power_smash_does_not_possess() -> void:
	var ps := PowerSmashState.new()
	ps.begin_activation(1, 0.5, 0, 48.0, false, 1000, FREEZE)  # plain power smash
	_expect(not ps.is_ghost_possession_active(), "plain power smash must not possess")
	_expect(not ps.is_ghost_possession_paddle_hidden(), "plain power smash must not hide the paddle")


func _test_reset_clears_possession() -> void:
	var ps := PowerSmashState.new()
	ps.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	ps.reset()
	_expect(not ps.is_ghost_possession_active(), "reset (round/match/game-end path) should clear possession")
	_expect(not ps.is_ghost_possession_paddle_hidden(), "reset restores the paddle")

	# Boss-counter scatter dismissal must also restore the paddle.
	var ps2 := PowerSmashState.new()
	ps2.begin_activation(1, 0.5, 0, 48.0, true, 1000, FREEZE)
	ps2.finish_after_boss_counter(Vector2(300.0, 200.0))
	_expect(ps2.is_ghost_possession_active(), "boss counter flies Mika back (still active mid fly-back)")
	_expect(not ps2.is_ghost_possession_paddle_hidden(), "boss counter unhides the paddle (flying back)")
	ps2.update_effects(15.0, Vector2(380.0, 710.0), true, 28.0)
	_expect(not ps2.is_ghost_possession_active(), "boss-counter fly-back completes back to normal")


func _expect(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append(message if message != "" else "assertion failed")


func _make_draw_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"width": 760.0,
		"height": 750.0,
		"player_pos": Vector2(320.0, 690.0),
		"player_paddle_size": Vector2(84.0, 16.0),
		"boss_pos": Vector2(320.0, 58.0),
		"boss_paddle_size": Vector2(120.0, 28.0),
		"textures": {},
	}


func _make_hit_context() -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"width": 760.0,
		"height": 750.0,
		"player_y": 690.0,
		"player_pos": Vector2(338.0, 690.0),
		"player_paddle_size": Vector2(84.0, 16.0),
		"boss_y": 50.0,
		"boss_pos": Vector2(320.0, 50.0),
		"boss_paddle_size": Vector2(120.0, 28.0),
		"boss_hitbox_height": 28.0,
		"ball_size": 28.0,
		"max_bounce_angle": 60.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 24.0,
		"gauge_max": 500.0,
		"gauge_charge_per_hit": 0.0,
		"player_speed": 0.0,
		"boss_vel": 0.0,
	}


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
