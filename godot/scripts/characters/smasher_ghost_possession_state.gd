extends RefCounted

# Ghost-smashing (ghost_shot) "possession" presentation layer.
#
# Distinct from smasher_ghost_shot_state.gd, which drives the ball's
# rise / chaos / teleport / final-fire MOTION. This state only tracks where Mika
# is while she is "inside" the ball and how she returns home, so the renderer can
# hide the player paddle during possession and fly it back when the returned
# ball reaches the player paddle. It never drives ball motion, so it is immune to the
# skip_ball_motion_step release trap that lives in ghost_shot_state.
#
# Why a SEPARATE lifecycle from ghost_shot_state: ghost_shot_state ends
# (finish_motion) the instant the ball is fired at the boss. But the player must
# stay "gone" through the boss's return shot, then rematerialize only when the
# ball reaches the player side and is countered. So this hidden-paddle window
# cannot reuse ghost_shot_state's lifecycle; it deliberately outlives it.
#
# Lifecycle: NONE -> RIDING (begin) -> RIDING+RETURNED -> FLY_BACK -> NONE.
# The dramatic "sucked into the ball" beat is the freeze cut-in that already
# plays on activation; here RIDING simply means the field paddle is hidden.

const PHASE_NONE := "none"
const PHASE_RIDING := "riding"
const PHASE_FLY_BACK := "fly_back"

# Safety backstop: if the boss never returns the ball (missed / scored / stuck)
# and no reset path fires, force the paddle back after this many seconds so the
# player can never be left permanently invisible.
const MAX_RIDING_SECONDS := 6.0
const FLY_BACK_SECONDS := 0.2
# Alpha rematerialization ramp as a fraction of the fly-back: Mika fades back in
# over the first part of the streak home.
const FLY_BACK_FADE_IN_RATIO := 0.4
# Start the return shortly before the normal player-paddle contact. The window
# scales with ball speed so fast boss returns do not score before Mika is visible.
const PLAYER_RETURN_LOOKAHEAD_FRAMES := 8.0
const PLAYER_RETURN_MIN_LEAD_PX := 96.0
const PLAYER_RETURN_MAX_LEAD_PX := 190.0

var _phase: String = PHASE_NONE
var _riding_elapsed: float = 0.0
var _ball_fired: bool = false
var _boss_returned: bool = false
var _fly_from: Vector2 = Vector2.ZERO
var _fly_elapsed: float = 0.0


func reset() -> void:
	_phase = PHASE_NONE
	_riding_elapsed = 0.0
	_ball_fired = false
	_boss_returned = false
	_fly_from = Vector2.ZERO
	_fly_elapsed = 0.0


func begin() -> void:
	reset()
	_phase = PHASE_RIDING


func notify_ball_fired() -> void:
	# The ghost ball has been fired toward the boss; only after this can a boss
	# return arm the player-side rematerialization.
	if _phase == PHASE_RIDING:
		_ball_fired = true


func notify_boss_returned() -> bool:
	# The boss has countered the ghost ball. Keep Mika hidden until the returned
	# ball reaches the player paddle, where trigger_fly_back() will pair the
	# visual return with the actual player counter.
	if _phase != PHASE_RIDING or not _ball_fired:
		return false
	_boss_returned = true
	return true


func trigger_fly_back(from_pos: Vector2) -> bool:
	# The returned ghost ball reached the player. Pop Mika out at the contact
	# position and fly home while the normal paddle-hit path counters the ball.
	if _phase != PHASE_RIDING or not _boss_returned:
		return false
	_phase = PHASE_FLY_BACK
	_fly_from = from_pos
	_fly_elapsed = 0.0
	return true


func maybe_trigger_player_zone_return(
	ball_pos: Vector2,
	ball_vel: Vector2,
	ball_active: bool,
	ball_size: float,
	player_pos: Vector2,
	player_paddle_size: Vector2
) -> bool:
	if _phase != PHASE_RIDING or not _boss_returned:
		return false
	if not ball_active or ball_vel.y <= 0.0:
		return false
	if player_paddle_size.x <= 0.0 or player_paddle_size.y <= 0.0:
		return false

	var lead_px: float = clampf(
		abs(ball_vel.y) * PLAYER_RETURN_LOOKAHEAD_FRAMES + max(0.0, ball_size),
		PLAYER_RETURN_MIN_LEAD_PX,
		PLAYER_RETURN_MAX_LEAD_PX
	)
	if ball_pos.y < player_pos.y - lead_px:
		return false
	return trigger_fly_back(ball_pos)


func force_release() -> void:
	reset()


func release_with_fly_back(from_pos: Vector2) -> void:
	# Forced dismissal (e.g. the boss counters the ghost ball mid-flight). Unlike
	# trigger_fly_back this ignores the ball-fired guard, because the ghost shot
	# is being cancelled outright and the player must visibly return either way.
	if _phase == PHASE_NONE:
		return
	_phase = PHASE_FLY_BACK
	_fly_from = from_pos
	_fly_elapsed = 0.0


func update(delta: float, _ball_pos: Vector2 = Vector2.ZERO) -> void:
	if delta <= 0.0:
		return
	match _phase:
		PHASE_RIDING:
			_riding_elapsed += delta
			if _riding_elapsed >= MAX_RIDING_SECONDS:
				force_release()
		PHASE_FLY_BACK:
			_fly_elapsed += delta
			if _fly_elapsed >= FLY_BACK_SECONDS:
				reset()


func is_active() -> bool:
	return _phase != PHASE_NONE


func get_phase() -> String:
	return _phase


func is_paddle_hidden() -> bool:
	# Fully hidden while riding the ball. During fly-back the paddle IS drawn
	# (flying home), so it is not "hidden" -- the override drives its position.
	return _phase == PHASE_RIDING


func has_ball_fired() -> bool:
	return _ball_fired


func has_boss_returned() -> bool:
	return _boss_returned


func get_player_visual_override() -> Dictionary:
	# During fly-back, returns {from, t, alpha} so the renderer can draw the
	# paddle streaking from the player-side contact point to the LIVE paddle position:
	# pos = from.lerp(live_player_pos, t). Targeting the live position (instead
	# of a captured home) lands seamlessly into normal play with no pop. Empty
	# when not flying back.
	if _phase != PHASE_FLY_BACK:
		return {}
	var raw_t: float = clampf(_fly_elapsed / FLY_BACK_SECONDS, 0.0, 1.0)
	var ease_t: float = 1.0 - pow(1.0 - raw_t, 3.0)  # ease-out: fast pop, settle home
	var alpha: float = clampf(raw_t / FLY_BACK_FADE_IN_RATIO, 0.0, 1.0)
	return {"from": _fly_from, "t": ease_t, "alpha": alpha}
