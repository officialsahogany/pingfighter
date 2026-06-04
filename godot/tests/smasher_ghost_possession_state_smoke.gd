extends SceneTree

const GhostPossessionState := preload("res://scripts/characters/smasher_ghost_possession_state.gd")

const BOSS_RETURN := Vector2(380.0, 60.0)

var _failures: Array[String] = []


func _init() -> void:
	_test_begin_hides_paddle()
	_test_riding_survives_ball_fire()
	_test_fly_back_requires_fire()
	_test_player_zone_return_requires_boss_return()
	_test_player_zone_return_starts_before_contact()
	_test_fly_back_progress()
	_test_fly_back_completes_to_none()
	_test_riding_safety_timeout()
	_test_release_with_fly_back_ignores_fire_guard()
	_test_reset_releases_mid_fly_back()
	_test_idle_update_is_noop()

	if _failures.is_empty():
		print("smasher_ghost_possession_state_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _test_begin_hides_paddle() -> void:
	var s := GhostPossessionState.new()
	_expect(not s.is_active(), "fresh state should be inactive")
	_expect(not s.is_paddle_hidden(), "fresh state should not hide the paddle")
	s.begin()
	_expect(s.is_active(), "begin should activate possession")
	_expect(s.get_phase() == "riding", "begin should enter riding")
	_expect(s.is_paddle_hidden(), "paddle should be hidden while riding")
	_expect(s.get_player_visual_override().is_empty(), "no fly-back override while riding")


func _test_riding_survives_ball_fire() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	# The ghost ball motion can run well over a second before it reaches the boss.
	s.update(1.5, Vector2(300.0, 400.0))
	_expect(s.get_phase() == "riding", "riding should persist past the ball fire (extended window)")
	_expect(s.is_paddle_hidden(), "paddle stays hidden until the boss returns the ball")
	_expect(s.has_ball_fired(), "ball-fired flag should be set")


func _test_fly_back_requires_fire() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	# A boss bounce BEFORE the fire (e.g. a stray chaos-phase contact) must not
	# end possession.
	_expect(not s.notify_boss_returned(), "boss return before the ball fire should be rejected")
	var triggered := s.trigger_fly_back(BOSS_RETURN)
	_expect(not triggered, "fly-back before the ball fire should be rejected")
	_expect(s.get_phase() == "riding", "should still be riding after a rejected fly-back")
	_expect(s.is_paddle_hidden(), "paddle stays hidden after rejected fly-back")

	s.notify_ball_fired()
	triggered = s.trigger_fly_back(BOSS_RETURN)
	_expect(not triggered, "fly-back after fire but before boss return should be rejected")
	_expect(s.notify_boss_returned(), "boss return after fire should arm fly-back")


func _test_player_zone_return_requires_boss_return() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	var triggered := s.maybe_trigger_player_zone_return(
		Vector2(380.0, 545.0),
		Vector2(0.0, 18.0),
		true,
		28.0,
		Vector2(338.0, 690.0),
		Vector2(84.0, 16.0)
	)
	_expect(not triggered, "near player zone should wait for the boss return signal")
	_expect(s.is_paddle_hidden(), "paddle should stay hidden before boss return")


func _test_player_zone_return_starts_before_contact() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	s.notify_boss_returned()
	var far_triggered := s.maybe_trigger_player_zone_return(
		Vector2(380.0, 470.0),
		Vector2(0.0, 18.0),
		true,
		28.0,
		Vector2(338.0, 690.0),
		Vector2(84.0, 16.0)
	)
	_expect(not far_triggered, "far downward return should not trigger yet")
	_expect(s.is_paddle_hidden(), "far downward return should keep the paddle hidden")
	var near_triggered := s.maybe_trigger_player_zone_return(
		Vector2(380.0, 545.0),
		Vector2(0.0, 18.0),
		true,
		28.0,
		Vector2(338.0, 690.0),
		Vector2(84.0, 16.0)
	)
	_expect(near_triggered, "near downward return should trigger before contact")
	_expect(s.get_phase() == "fly_back", "near downward return should enter fly_back")
	_expect(not s.is_paddle_hidden(), "near downward return should draw the paddle")


func _test_fly_back_progress() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	s.notify_boss_returned()
	var triggered := s.trigger_fly_back(BOSS_RETURN)
	_expect(triggered, "fly-back after the fire should trigger")
	_expect(s.get_phase() == "fly_back", "should enter fly_back")
	_expect(not s.is_paddle_hidden(), "paddle is drawn (not hidden) while flying back")

	var o0 := s.get_player_visual_override()
	_expect(not o0.is_empty(), "fly-back should expose a visual override")
	var from0: Vector2 = o0.get("from", Vector2.ZERO)
	_expect(from0.distance_to(BOSS_RETURN) < 1.0, "fly-back origin is the boss-return point")
	_expect(float(o0.get("t", 1.0)) <= 0.01, "fly-back starts at t=0")
	_expect(float(o0.get("alpha", 1.0)) <= 0.01, "Mika starts fully faded out at pop-out")

	# Advance to ~half of the 0.2s fly-back; ease-out means t is already past 0.5.
	s.update(0.1, Vector2.ZERO)
	var o_mid := s.get_player_visual_override()
	_expect(float(o_mid.get("t", 0.0)) > 0.5, "ease-out fly-back is past halfway by mid-time")
	_expect(float(o_mid.get("t", 0.0)) < 1.0, "fly-back has not landed yet at mid-time")
	_expect(float(o_mid.get("alpha", 0.0)) > 0.0, "Mika is rematerializing during fly-back")


func _test_fly_back_completes_to_none() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	s.notify_boss_returned()
	s.trigger_fly_back(BOSS_RETURN)
	s.update(0.25, Vector2.ZERO)  # > FLY_BACK_SECONDS (0.2)
	_expect(not s.is_active(), "fly-back should complete back to NONE")
	_expect(s.get_phase() == "none", "phase should be none after landing")
	_expect(not s.is_paddle_hidden(), "paddle visible again after landing")
	_expect(s.get_player_visual_override().is_empty(), "no override after landing")


func _test_riding_safety_timeout() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	# Boss never returns the ball: the safety backstop must release the paddle.
	s.update(6.5, Vector2.ZERO)  # > MAX_RIDING_SECONDS (6.0)
	_expect(not s.is_active(), "riding safety timeout should force release")
	_expect(not s.is_paddle_hidden(), "paddle must not be left permanently hidden")


func _test_release_with_fly_back_ignores_fire_guard() -> void:
	# Boss counter dismisses the ghost shot during the chaos phase (before fire).
	var s := GhostPossessionState.new()
	s.begin()
	_expect(not s.has_ball_fired(), "precondition: ball not fired yet")
	s.release_with_fly_back(BOSS_RETURN)
	_expect(s.get_phase() == "fly_back", "forced dismiss flies back even before the fire")
	_expect(not s.get_player_visual_override().is_empty(), "forced dismiss exposes a fly-back override")
	# And it lands back to normal.
	s.update(0.25, Vector2.ZERO)
	_expect(not s.is_active(), "forced fly-back completes back to none")


func _test_reset_releases_mid_fly_back() -> void:
	var s := GhostPossessionState.new()
	s.begin()
	s.notify_ball_fired()
	s.notify_boss_returned()
	s.trigger_fly_back(BOSS_RETURN)
	s.reset()
	_expect(not s.is_active(), "reset mid fly-back should clear possession")
	_expect(not s.is_paddle_hidden(), "reset restores paddle visibility")
	_expect(s.get_player_visual_override().is_empty(), "reset clears the override")

	var s2 := GhostPossessionState.new()
	s2.begin()
	s2.force_release()
	_expect(not s2.is_active(), "force_release should clear possession")


func _test_idle_update_is_noop() -> void:
	var s := GhostPossessionState.new()
	s.update(1.0, Vector2.ZERO)
	_expect(not s.is_active(), "updating an idle state should stay inactive")
	_expect(s.get_phase() == "none", "idle update keeps phase none")


func _expect(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append(message if message != "" else "assertion failed")
