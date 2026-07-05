extends SceneTree

# Seals the staggered spinning-top hit sequence: Dalji whips one top forward per
# hit instead of releasing every top at once after a single whip. Outcome-level
# asserts (position advance, launch counts) plus falsification anchors that fail
# on the old "release all tops together" behavior. Frame checkpoints are derived
# from PER_HIT_WHIP_FRAMES / STRIKE_FRAME_RATIO so they survive timing re-tuning.
# Also seals the launch feel: struck tops must fling WIDE sideways to
# alternating left / right sides (the pre-2026-07 tune capped total launch
# travel at ~79px with a steep-downward angle branch, which read as a narrow
# downward drop instead of a left/right scatter).

const SpinningTop := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd")

var _failures: Array[String] = []
# Frames per whip cycle, and updates-into-a-cycle when that cycle's strike fires.
var _cyc: int = int(SpinningTop.PER_HIT_WHIP_FRAMES)
var _strike: int = int(ceil(SpinningTop.PER_HIT_WHIP_FRAMES * SpinningTop.STRIKE_FRAME_RATIO))
var _elapsed := 0


func _init() -> void:
	_verify_normal_staggers_two_hits()
	_verify_launched_top_advances_while_others_wait()
	_verify_enraged_staggers_four_hits()
	_verify_launch_scatters_wide_alternating()

	if _failures.is_empty():
		print("stage1_dalji_spinning_top_stagger_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _base_ctx(enraged: bool = false) -> Dictionary:
	var ctx := {
		"current_stage": 1,
		"width": 760.0,
		"height": 750.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		# Ball inactive so top<->ball collision cannot perturb the tops mid-test.
		"ball_active": false,
	}
	if enraged:
		ctx["enraged_boss_active"] = true
	return ctx


func _scene() -> Dictionary:
	return {"ball_pos": Vector2(380.0, 400.0), "ball_vel": Vector2.ZERO}


# Absolute-frame cursor: advance the state until `_elapsed` reaches `target`.
func _advance_to(top: Object, ctx: Dictionary, target: int) -> void:
	while _elapsed < target:
		top.update_and_collide(1.0, _scene(), ctx, {})
		_elapsed += 1


func _launched_count(top: Object) -> int:
	var count := 0
	for entry in top.tops:
		if entry is Dictionary and bool((entry as Dictionary).get("launched", false)):
			count += 1
	return count


func _is_launched(top: Object, index: int) -> bool:
	if index < 0 or index >= top.tops.size():
		return false
	return bool((top.tops[index] as Dictionary).get("launched", false))


func _whip_target(top: Object) -> int:
	return int(top.get_draw_context()["stage1_spinning_top_whip_target_index"])


# Just past the strike of the (1-based) k-th top's whip cycle.
func _after_strike(k: int) -> int:
	return (k - 1) * _cyc + _strike + 2


func _verify_normal_staggers_two_hits() -> void:
	seed(20260701)
	_elapsed = 0
	var top := SpinningTop.new()
	var ctx := _base_ctx()
	_expect(top.activate(ctx, {}), "spinning top should activate on Stage 1")
	_expect(top.tops.size() == 2, "normal activation should spawn two tops")
	_expect(_launched_count(top) == 0, "no top should be launched at activation (they wait for their whip)")
	_expect(bool(top.get_ai_context()["stage1_dalji_spinning_top_freeze_active"]), "freeze active while hit sequence runs")
	_expect(_whip_target(top) == 0, "whip cord targets the first top before its strike")

	# Before the first strike, nothing has launched. Falsification anchor: an
	# "all at once" implementation launches at activation and fails here.
	_advance_to(top, ctx, _strike - 3)
	_expect(_launched_count(top) == 0, "before the first strike no top has launched")

	# After the first strike, EXACTLY one top is launched. This is the core
	# staggering guarantee; a single-whip release would launch both here.
	_advance_to(top, ctx, _after_strike(1))
	_expect(_launched_count(top) == 1, "after the first strike exactly one top is launched")
	_expect(_is_launched(top, 0), "the first struck top is index 0")
	_expect(_whip_target(top) == -1, "cord detaches once the first top is struck")

	# The second whip cycle re-arms the cord onto the second top before its strike.
	_advance_to(top, ctx, _cyc + 4)
	_expect(_whip_target(top) == 1, "whip cord retargets the second top for its cycle")
	_expect(_launched_count(top) == 1, "second top still waits until its own strike")

	# Second strike launches the remaining top.
	_advance_to(top, ctx, _after_strike(2))
	_expect(_launched_count(top) == 2, "after the second strike both tops are launched")

	# Whole hit sequence completes at 2 x PER_HIT_WHIP_FRAMES; Dalji frees up.
	_advance_to(top, ctx, 2 * _cyc + 4)
	_expect(not bool(top.get_ai_context()["stage1_dalji_spinning_top_freeze_active"]), "freeze releases once every top has been struck")


func _verify_launched_top_advances_while_others_wait() -> void:
	seed(20260701)
	_elapsed = 0
	var top := SpinningTop.new()
	var ctx := _base_ctx()
	top.activate(ctx, {})
	var spawn0 := Vector2(float((top.tops[0] as Dictionary).get("x", 0.0)), float((top.tops[0] as Dictionary).get("y", 0.0)))
	var spawn1 := Vector2(float((top.tops[1] as Dictionary).get("x", 0.0)), float((top.tops[1] as Dictionary).get("y", 0.0)))

	# Past the first strike, only top 0 is moving.
	_advance_to(top, ctx, _strike + 6)
	_expect(_is_launched(top, 0) and not _is_launched(top, 1), "only the first top is struck at this point")
	var pos0 := Vector2(float((top.tops[0] as Dictionary).get("x", 0.0)), float((top.tops[0] as Dictionary).get("y", 0.0)))
	var pos1 := Vector2(float((top.tops[1] as Dictionary).get("x", 0.0)), float((top.tops[1] as Dictionary).get("y", 0.0)))
	# The struck top skids away from its spawn (diagonally, not straight down).
	_expect(pos0.distance_to(spawn0) > 10.0, "the struck top skids forward as if hit")
	_expect(absf(pos0.x - spawn0.x) > 5.0, "the struck top gains sideways (diagonal) travel, not a pure vertical drop")
	_expect(spawn1.distance_to(pos1) < 0.001, "the un-struck top stays parked at its spawn position")


func _verify_enraged_staggers_four_hits() -> void:
	seed(20260701)
	_elapsed = 0
	var top := SpinningTop.new()
	var ctx := _base_ctx(true)
	_expect(top.activate(ctx, {}), "enraged spinning top should activate on Stage 1")
	_expect(top.tops.size() == 4, "enraged activation should spawn four tops")

	# One top launches per strike, ~PER_HIT_WHIP_FRAMES apart.
	_advance_to(top, ctx, _after_strike(1))
	_expect(_launched_count(top) == 1, "enraged: one top launched after the first strike")
	_advance_to(top, ctx, _after_strike(2))
	_expect(_launched_count(top) == 2, "enraged: two tops launched after the second strike")
	_advance_to(top, ctx, _after_strike(3))
	_expect(_launched_count(top) == 3, "enraged: three tops launched after the third strike")
	_advance_to(top, ctx, _after_strike(4))
	_expect(_launched_count(top) == 4, "enraged: all four tops launched after the fourth strike")
	# The fourth whip cycle only finishes its recovery ~PER_HIT_WHIP_FRAMES after
	# its strike, so freeze is still active immediately after the last launch.
	_expect(bool(top.get_ai_context()["stage1_dalji_spinning_top_freeze_active"]), "enraged freeze still held during the final cycle recovery")
	_advance_to(top, ctx, 4 * _cyc + 4)
	_expect(not bool(top.get_ai_context()["stage1_dalji_spinning_top_freeze_active"]), "enraged freeze releases only after all four hits complete")


func _verify_launch_scatters_wide_alternating() -> void:
	seed(20260703)
	_elapsed = 0
	var top := SpinningTop.new()
	var ctx := _base_ctx()
	top.activate(ctx, {})
	var spawns: Array[Vector2] = []
	for entry in top.tops:
		spawns.append(Vector2(float((entry as Dictionary).get("x", 0.0)), float((entry as Dictionary).get("y", 0.0))))

	# Record each top's horizontal displacement at the end of its own launch
	# boost window (spawn -> boost-end), before post-boost zigzag drift can
	# erode the measurement. Checkpoints derive from the state constants so a
	# timing re-tune keeps this seal meaningful.
	var boost := int(SpinningTop.LAUNCH_BOOST_FRAMES)
	var launch_frame := {}
	var boost_end_dx := {}
	var deadline := 2 * _cyc + boost + 8
	while _elapsed < deadline:
		top.update_and_collide(1.0, _scene(), ctx, {})
		_elapsed += 1
		for i in range(top.tops.size()):
			if _is_launched(top, i) and not launch_frame.has(i):
				launch_frame[i] = _elapsed
			if launch_frame.has(i) and not boost_end_dx.has(i) and _elapsed >= int(launch_frame[i]) + boost:
				boost_end_dx[i] = float((top.tops[i] as Dictionary).get("x", 0.0)) - spawns[i].x

	_expect(boost_end_dx.has(0) and boost_end_dx.has(1), "both struck tops complete their launch boost inside the skill window")
	if not (boost_end_dx.has(0) and boost_end_dx.has(1)):
		return
	var dx0 := float(boost_end_dx[0])
	var dx1 := float(boost_end_dx[1])
	# Wide-scatter falsification anchor: the old launch impulse (speed 9, decay
	# 0.90, 20 frames) capped TOTAL travel at ~71px, so >90px of horizontal
	# travel is impossible on the old code for ANY angle roll. The current tune
	# (~179px total, angles <= 48 deg from horizontal) guarantees >= ~119px for
	# any roll, so these asserts are deterministic in both directions.
	_expect(absf(dx0) > 90.0, "first struck top flings wide sideways (>90px horizontal travel)")
	_expect(absf(dx1) > 90.0, "second struck top flings wide sideways (>90px horizontal travel)")
	_expect(signf(dx0) != signf(dx1), "consecutive struck tops fling to opposite sides (left/right alternation)")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
