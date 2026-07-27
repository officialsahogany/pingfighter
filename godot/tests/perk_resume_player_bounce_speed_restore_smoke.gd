extends SceneTree

# Seals the perk-choice (starpoint) resume safety's INPUT half:
#
# The resume ramp overwrites the descending ball's ball_vel MAGNITUDE every frame
# (original * ratio, floor 0.30) and runs BEFORE update_ball, so the existing
# "release the moment the ball moves upward" path (runtime_perk_resume_safety.gd)
# is structurally one frame late — the hit frame still reads the suppressed speed.
# Power smash (천뢰격) / drive (벽력타) seed target_speed + original_speed from that
# incoming speed, so the safety turned into a penalty: post-modal attack skills
# launch/cruise slower and the boss-counter restore speed is polluted too.
#
# paddle_bounce_controller.bounce() now restores the magnitude to the pre-modal
# original for PLAYER returns only (direction untouched, never overshoots).
# Because the restore reproduces the pre-modal vector EXACTLY, a suppressed run
# must be numerically identical to a control run that never saw the modal — that
# equality is what these legs assert, through the real bounce path with the real
# PaddleBounceState / BallPhysics / SmasherPowerSmashState.
#
# Legs:
#  A  control vs suppressed -> identical launch velocity / target_speed / original_speed
#  A2 same, but the context is built by the REAL producer (RuntimePerkResumeSafety
#     .get_context()) and pushed through the duplicate()+merge(scene) shape that
#     ball_motion_event_processor._process_paddle uses (key-name + survival seal)
#  B  combo-amplifier-chip launch (smash_speed_amp > 0, where the launch magnitude
#     itself diverges, not only the cruise target)
#  C  no-op when the key is absent (a suppressed ball with no ramp key must stay
#     suppressed — proves the restore is gated, not unconditional)
#  D  overshoot guard: a stored original SLOWER than the live ball never speeds it up
#  E  stopwatch handoff isolation: Vector2.ZERO key is a full no-op
#  F  boss returns are never restored (player re-engagement only)
#  G  freeze-exit normalizes player_collision_cooldown to the intended +4 frames
#     instead of the ~24-frame window that "can neither be blocked nor score-blocked"

const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const RuntimePerkResumeSafety := preload("res://scripts/characters/runtime_perk_resume_safety.gd")

const FRAME_DELTA := 1.0 / 60.0
const EPS := 0.05

# ball_update_static_config.POWER_SMASH_{GRAVITY_EFFECT,BOOST_DURATION}
const POWER_SMASH_GRAVITY_EFFECT := 0.035
const POWER_SMASH_BOOST_DURATION := 0.50
const CRUISE_FRAMES := 40

# A realistic post-modal rally: the ball descends at ~15.8 px/frame when the perk
# modal opens, and the ramp floor (0.30) crawls it back in at ~4.74.
const PRE_MODAL_VEL := Vector2(3.0, 15.5)
const SUPPRESSED_VEL := PRE_MODAL_VEL * 0.30

var _failures: Array[String] = []


func _init() -> void:
	_test_control_vs_suppressed_launch_matches()
	_test_real_resume_context_survives_paddle_context_merge()
	_test_combo_amplifier_launch_matches()
	_test_absent_key_is_noop()
	_test_never_overshoots_live_speed()
	_test_stopwatch_zero_key_is_noop()
	_test_boss_return_is_not_restored()
	_test_freeze_exit_normalizes_player_collision_cooldown()

	if _failures.is_empty():
		print("perk_resume_player_bounce_speed_restore_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_context(ball_vel: Vector2) -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"ball_active": true,
		"ball_pos": Vector2(352.0, 686.0),
		"ball_vel": ball_vel,
		"ball_size": 28.6,
		"player_pos": Vector2(300.0, 700.0),
		"player_y": 700.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"max_bounce_angle": 60.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 26.0,
		"base_ball_speed": 7.65,
		"combo_min_count": 2,
		"ai_mode": "champion",
		"special_gauge": 0.0,
	}


func _build_power_state(_combo_consumed: int) -> Object:
	# Activation itself happens inside the bounce, through the fake activation
	# controller, exactly like the live router does.
	return SmasherPowerSmashState.new()


func _run_bounce(
	context: Dictionary,
	power_state: Object,
	is_player: bool = true,
	smash_speed_amp: float = 0.0,
	combo_consumed: int = 0
) -> Dictionary:
	# paddle_bounce_velocity_resolver.gd:67-69 rolls a random curve rotation, so
	# control vs suppressed runs must draw the SAME sequence for the comparison to
	# isolate the incoming-speed difference.
	seed(20260727)
	var controller: Object = PaddleBounceController.new()
	var deps: Dictionary = {
		"paddle_bounce_state": PaddleBounceState.new(),
		"ball_physics": BallPhysics.new(),
		"power_state": power_state,
	}
	if smash_speed_amp > 0.0:
		deps["runtime_perk_state"] = FakeComboAmplifierPerkState.new(smash_speed_amp)
	if power_state != null:
		# Stand in for the input / gauge / combo gate only. Everything downstream —
		# post-hit handler, power hit handler, SmasherPowerSmashState.apply_hit_velocity,
		# smasher_power_smash_hit_velocity_resolver — is the real runtime.
		deps["power_activation_controller"] = FakePowerActivationController.new(combo_consumed)
	return controller.bounce(300.0, 155.0, is_player, context, deps)


# 발사 직후 초기부스트 창(0.5s)을 넘겨 실제 "순항 속도"까지 밟는다. 억제된 입력은
# target_speed를 낮게 시딩하므로 발사 크기가 캡으로 같아 보여도 여기서 갈라진다.
func _simulate_cruise_speed(power_state: Object, launch_vel: Vector2) -> float:
	var vel: Vector2 = launch_vel
	for _i in range(CRUISE_FRAMES):
		vel = power_state.apply_motion(
			vel,
			1.0,
			POWER_SMASH_GRAVITY_EFFECT,
			POWER_SMASH_BOOST_DURATION
		)
	return vel.length()


# ---------------------------------------------------------------- leg A

func _test_control_vs_suppressed_launch_matches() -> void:
	var control_state: Object = _build_power_state(0)
	var control_result: Dictionary = _run_bounce(_build_context(PRE_MODAL_VEL), control_state)
	var control_vel: Vector2 = control_result.get("ball_vel", Vector2.ZERO)

	var suppressed_context: Dictionary = _build_context(SUPPRESSED_VEL)
	suppressed_context["perk_resume_original_ball_vel"] = PRE_MODAL_VEL
	suppressed_context["perk_resume_recovery_active"] = true
	var suppressed_state: Object = _build_power_state(0)
	var suppressed_result: Dictionary = _run_bounce(suppressed_context, suppressed_state)
	var suppressed_vel: Vector2 = suppressed_result.get("ball_vel", Vector2.ZERO)

	_expect(
		control_vel.length() > 1.0,
		"test setup: the control power smash should actually launch (got %.3f)" % control_vel.length()
	)
	_expect(
		suppressed_vel.distance_to(control_vel) <= EPS,
		"post-modal power smash launch must match the un-suppressed control (control %s vs suppressed %s)"
			% [str(control_vel), str(suppressed_vel)]
	)
	var control_cruise: float = _simulate_cruise_speed(control_state, control_vel)
	var suppressed_cruise: float = _simulate_cruise_speed(suppressed_state, suppressed_vel)
	_expect(
		abs(suppressed_cruise - control_cruise) <= EPS,
		"post-modal power smash cruise speed must match the control (control %.3f vs suppressed %.3f)"
			% [control_cruise, suppressed_cruise]
	)
	_expect(
		abs(float(suppressed_state.get_original_speed()) - float(control_state.get_original_speed())) <= EPS,
		"post-modal power smash original_speed (boss-counter restore seed) must match the control (control %.3f vs suppressed %.3f)"
			% [float(control_state.get_original_speed()), float(suppressed_state.get_original_speed())]
	)


# --------------------------------------------------------------- leg A2

func _test_real_resume_context_survives_paddle_context_merge() -> void:
	# Build the ramp context through the real producer so a renamed / dropped key
	# fails here instead of silently reverting to "no restore".
	var safety: Object = RuntimePerkResumeSafety.new()
	var owner := FakeOwner.new()
	owner.ball_vel = PRE_MODAL_VEL
	safety.try_arm(owner, null)
	for _i in range(11):
		safety.update(owner, null, FRAME_DELTA)
	var resume_context: Dictionary = safety.get_context()
	_expect(
		bool(resume_context.get("perk_resume_recovery_active", false)),
		"test setup: the resume ramp should be in its recovery phase after the freeze"
	)
	_expect(
		owner.ball_vel.length() < PRE_MODAL_VEL.length() - 0.05,
		"test setup: the ramp should have suppressed the live ball speed (got %.3f)" % owner.ball_vel.length()
	)

	# ball_motion_event_processor._process_paddle: context.duplicate() then
	# merge(scene, true) — scene carries the live (suppressed) ball_vel and must
	# NOT wipe the resume keys.
	var frame_context: Dictionary = _build_context(PRE_MODAL_VEL)
	frame_context.merge(resume_context, true)
	var scene: Dictionary = {"ball_vel": owner.ball_vel, "ball_pos": Vector2(352.0, 686.0)}
	var paddle_context: Dictionary = frame_context.duplicate()
	paddle_context.merge(scene, true)

	_expect(
		paddle_context.has("perk_resume_original_ball_vel"),
		"the resume original-velocity key must survive duplicate() + merge(scene) into the paddle context"
	)
	_expect(
		Vector2(paddle_context.get("ball_vel", Vector2.ZERO)).length() < PRE_MODAL_VEL.length() - 0.05,
		"test setup: the merged paddle context should carry the suppressed live velocity"
	)

	var control_state: Object = _build_power_state(0)
	var control_result: Dictionary = _run_bounce(_build_context(PRE_MODAL_VEL), control_state)
	var live_state: Object = _build_power_state(0)
	var live_result: Dictionary = _run_bounce(paddle_context, live_state)

	_expect(
		Vector2(live_result.get("ball_vel", Vector2.ZERO)).distance_to(control_result.get("ball_vel", Vector2.ZERO)) <= EPS,
		"a live ramp context routed through the real paddle-context shape must launch like the control (control %s vs live %s)"
			% [str(control_result.get("ball_vel", Vector2.ZERO)), str(live_result.get("ball_vel", Vector2.ZERO))]
	)
	# The launch magnitude saturates the smash cap, so the discriminating values
	# are the seeded speeds — assert those too or this leg silently stops proving
	# that the real producer's key reached the consumer.
	_expect(
		abs(float(live_state.get_original_speed()) - float(control_state.get_original_speed())) <= EPS,
		"a live ramp context must seed the same original_speed as the control (control %.3f vs live %.3f)"
			% [float(control_state.get_original_speed()), float(live_state.get_original_speed())]
	)
	_expect(
		abs(
			_simulate_cruise_speed(live_state, live_result.get("ball_vel", Vector2.ZERO))
				- _simulate_cruise_speed(control_state, control_result.get("ball_vel", Vector2.ZERO))
		) <= EPS,
		"a live ramp context must cruise like the control"
	)


# ---------------------------------------------------------------- leg B

func _test_combo_amplifier_launch_matches() -> void:
	# With the combo amplifier chip the launch cap is relaxed, so the launch
	# MAGNITUDE itself (not just the cruise target) diverges when suppressed.
	var control_state: Object = _build_power_state(4)
	var control_result: Dictionary = _run_bounce(_build_context(PRE_MODAL_VEL), control_state, true, 0.45, 4)

	var suppressed_context: Dictionary = _build_context(SUPPRESSED_VEL)
	suppressed_context["perk_resume_original_ball_vel"] = PRE_MODAL_VEL
	var suppressed_state: Object = _build_power_state(4)
	var suppressed_result: Dictionary = _run_bounce(suppressed_context, suppressed_state, true, 0.45, 4)

	_expect(
		Vector2(suppressed_result.get("ball_vel", Vector2.ZERO)).distance_to(control_result.get("ball_vel", Vector2.ZERO)) <= EPS,
		"combo power smash launch velocity must match the control (control %s vs suppressed %s)"
			% [str(control_result.get("ball_vel", Vector2.ZERO)), str(suppressed_result.get("ball_vel", Vector2.ZERO))]
	)


# ---------------------------------------------------------------- leg C

func _test_absent_key_is_noop() -> void:
	# No ramp key -> a genuinely slow ball must stay slow. This is what keeps the
	# restore from becoming an unconditional "always hit at full speed" buff.
	var slow_state: Object = _build_power_state(0)
	var slow_result: Dictionary = _run_bounce(_build_context(SUPPRESSED_VEL), slow_state)
	var fast_state: Object = _build_power_state(0)
	var fast_result: Dictionary = _run_bounce(_build_context(PRE_MODAL_VEL), fast_state)

	var slow_cruise: float = _simulate_cruise_speed(slow_state, slow_result.get("ball_vel", Vector2.ZERO))
	var fast_cruise: float = _simulate_cruise_speed(fast_state, fast_result.get("ball_vel", Vector2.ZERO))
	_expect(
		slow_cruise < fast_cruise - EPS,
		"without the resume key a slow incoming ball must keep its slower cruise speed (slow %.3f vs fast %.3f)"
			% [slow_cruise, fast_cruise]
	)
	_expect(
		Vector2(slow_result.get("ball_vel", Vector2.ZERO)).length() > 0.0,
		"the un-keyed control run should still produce a launch"
	)


# ---------------------------------------------------------------- leg D

func _test_never_overshoots_live_speed() -> void:
	# A stored original SLOWER than the live ball (rally acceleration already
	# outran it) must never drag the live ball up or down.
	var plain_state: Object = _build_power_state(0)
	var plain_result: Dictionary = _run_bounce(_build_context(PRE_MODAL_VEL), plain_state)

	var stale_context: Dictionary = _build_context(PRE_MODAL_VEL)
	stale_context["perk_resume_original_ball_vel"] = PRE_MODAL_VEL * 0.5
	var stale_state: Object = _build_power_state(0)
	var stale_result: Dictionary = _run_bounce(stale_context, stale_state)

	_expect(
		Vector2(stale_result.get("ball_vel", Vector2.ZERO)).distance_to(plain_result.get("ball_vel", Vector2.ZERO)) <= 0.001,
		"a stored original slower than the live ball must be a no-op (plain %s vs stale %s)"
			% [str(plain_result.get("ball_vel", Vector2.ZERO)), str(stale_result.get("ball_vel", Vector2.ZERO))]
	)


# ---------------------------------------------------------------- leg E

func _test_stopwatch_zero_key_is_noop() -> void:
	# After consume_velocity_for_stopwatch() the ramp publishes Vector2.ZERO, so
	# a stopwatch-owned slowdown must not be undone by this restore.
	var plain_state: Object = _build_power_state(0)
	var plain_result: Dictionary = _run_bounce(_build_context(SUPPRESSED_VEL), plain_state)

	var zero_context: Dictionary = _build_context(SUPPRESSED_VEL)
	zero_context["perk_resume_original_ball_vel"] = Vector2.ZERO
	var zero_state: Object = _build_power_state(0)
	var zero_result: Dictionary = _run_bounce(zero_context, zero_state)

	_expect(
		Vector2(zero_result.get("ball_vel", Vector2.ZERO)).distance_to(plain_result.get("ball_vel", Vector2.ZERO)) <= 0.001,
		"a Vector2.ZERO resume key (stopwatch handoff / cleared ramp) must be a full no-op"
	)


# ---------------------------------------------------------------- leg F

func _test_boss_return_is_not_restored() -> void:
	var ascending: Vector2 = Vector2(3.0, -15.5)
	var plain_result: Dictionary = _run_bounce(_build_context(ascending * 0.30), null, false)

	var keyed_context: Dictionary = _build_context(ascending * 0.30)
	keyed_context["perk_resume_original_ball_vel"] = ascending
	var keyed_result: Dictionary = _run_bounce(keyed_context, null, false)

	_expect(
		Vector2(keyed_result.get("ball_vel", Vector2.ZERO)).distance_to(plain_result.get("ball_vel", Vector2.ZERO)) <= 0.001,
		"boss returns must never consume the player-re-engagement restore (plain %s vs keyed %s)"
			% [str(plain_result.get("ball_vel", Vector2.ZERO)), str(keyed_result.get("ball_vel", Vector2.ZERO))]
	)


# ---------------------------------------------------------------- leg G

func _test_freeze_exit_normalizes_player_collision_cooldown() -> void:
	var safety: Object = RuntimePerkResumeSafety.new()
	var owner := FakeOwner.new()
	owner.ball_vel = PRE_MODAL_VEL
	safety.try_arm(owner, null)
	_expect(
		owner.player_collision_cooldown >= RuntimePerkResumeSafety.FREEZE_FRAMES + 4.0 - 0.001,
		"test setup: arming should block the paddle for the freeze plus the intended grace"
	)

	# ball_update_controller returns before the cooldown tick-down while the
	# freeze is active, so the smoke must not decrement it either.
	for _i in range(10):
		safety.update(owner, null, FRAME_DELTA)

	_expect(
		safety.freeze_timer_frames <= 0.0,
		"test setup: the freeze should be over after FREEZE_FRAMES ticks"
	)
	_expect(
		owner.player_collision_cooldown <= 4.0 + 0.001,
		"freeze exit must normalize player_collision_cooldown to the intended +4 frames, not carry the full freeze block (got %.2f)"
			% owner.player_collision_cooldown
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	extends RefCounted

	var ball_vel := Vector2.ZERO
	var player_collision_cooldown := 0.0


# paddle_bounce_post_hit_handler resolves the combo-amplifier chip's smash-speed
# amp from deps["runtime_perk_state"], not from the context dict.
class FakeComboAmplifierPerkState:
	extends RefCounted

	var _smash_speed: float = 0.0

	func _init(smash_speed: float) -> void:
		_smash_speed = smash_speed

	func get_combo_amplifier_chip_bonus() -> Dictionary:
		return {"smash_speed": _smash_speed}


class FakePowerActivationController:
	extends RefCounted

	var _combo_consumed: int = 0

	func _init(combo_consumed: int) -> void:
		_combo_consumed = combo_consumed

	func try_activate(payload: Dictionary, deps: Dictionary, _callbacks: Dictionary) -> Dictionary:
		var power_state: Object = deps.get("power_state", null)
		if power_state != null:
			power_state.begin_activation(0, 0.0, _combo_consumed, 30.0, false, 1000)
			# No freeze in this fixture: step straight into the launch frame.
			power_state.update_freeze(1.0, 0.0)
		return {
			"activated": true,
			"special_gauge": float(payload.get("special_gauge", 0.0)),
		}
