extends SceneTree

# Seals the shared skill-card reorder "shuffle" motion, v2 timed tween
# (BossSkillCardHudSpec.advance_card_shuffle / prune_shuffle_store).
# v2 replaced the v1 damped spring after live feedback: v1's |vy|-coupled lift
# double-pumped at the overshoot peak (mid-travel stutter). v2 must therefore
# guarantee: monotone travel with ZERO overshoot, a SINGLE-ARC lift (rise once,
# fall once — the anti-stutter property), exact rest identity, retarget
# continuity (no position jump when the sort changes mid-flight), and
# time-jump safety (a stall just completes the tween).

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

const FRAME_DT := 1.0 / 72.0  # shipped Stable Monitor render cadence

var _failures: Array[String] = []


func _init() -> void:
	_verify_new_key_snaps()
	_verify_monotone_travel_single_arc_lift()
	_verify_swap_direction_bias_separates()
	_verify_retarget_continuity()
	_verify_time_jump_completes()
	_verify_prune()

	if _failures.is_empty():
		print("boss_skill_card_shuffle_motion_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_new_key_snaps() -> void:
	var store := {}
	var r := BossSkillCardHudSpec.advance_card_shuffle(store, "a", 40.0, 100.0, 1.0, 0.0)
	_expect(_near(float(r.get("x")), 40.0), "new key must snap x to target_x")
	_expect(_near(float(r.get("y")), 100.0), "new key must snap y to target_y")
	_expect(_near(float(r.get("motion")), 0.0), "new key must report no motion")
	_expect(store.has("a"), "new key must register state in the store")


func _verify_monotone_travel_single_arc_lift() -> void:
	var store := {}
	var target_x := 40.0
	# Establish at y=100 (snap), then reorder down to y=160.
	BossSkillCardHudSpec.advance_card_shuffle(store, "c", target_x, 100.0, 1.0, 0.0)
	var t := 0.0
	var prev_y := 100.0
	var prev_lift := 0.0
	var lift_direction_flips := 0
	var lift_rising := true
	var peak_lift := 0.0
	var last := {}
	for _i in range(60):
		t += FRAME_DT
		last = BossSkillCardHudSpec.advance_card_shuffle(store, "c", target_x, 160.0, 1.0, t)
		var x := float(last.get("x"))
		var y := float(last.get("y"))
		_expect(is_finite(x) and is_finite(y), "positions must stay finite")
		# ZERO overshoot: travel is bounded to [from, target] the whole way.
		_expect(y >= 100.0 - 0.001 and y <= 160.0 + 0.001, "travel must never leave [from, target] (no overshoot), got %f" % y)
		# Monotone: never moves back up during a downward reorder.
		_expect(y >= prev_y - 0.001, "downward travel must be monotone (no direction reversal), %f -> %f" % [prev_y, y])
		prev_y = y
		# Lift is only ever leftward (into the pillar).
		var lift := target_x - x
		_expect(lift >= -0.001, "lift must never push the card right of target_x")
		peak_lift = maxf(peak_lift, lift)
		# Count lift direction changes: a clean single arc flips exactly once
		# (rise -> fall). A second rise = the v1 double-pump stutter.
		if lift_rising and lift < prev_lift - 0.01:
			lift_rising = false
			lift_direction_flips += 1
		elif not lift_rising and lift > prev_lift + 0.01:
			lift_rising = true
			lift_direction_flips += 1
		prev_lift = lift
	_expect(peak_lift > 1.0, "a full-slot reorder must visibly lift out of the stack mid-travel")
	_expect(lift_direction_flips <= 1, "lift must be a single arc (rise once, fall once) — %d direction flips = stutter" % lift_direction_flips)
	# Exact rest identity after the tween: still frames match pre-change pixels.
	_expect(_near(float(last.get("y")), 160.0), "card must settle exactly on target_y")
	_expect(_near(float(last.get("x")), target_x), "lift must return to exactly 0 at rest")
	_expect(_near(float(last.get("motion")), 0.0), "motion must be 0 at rest")


func _verify_swap_direction_bias_separates() -> void:
	# Two cards trading places: "up" moves 100 -> 40, "down" moves 40 -> 100.
	# The upward mover gets extra lift so the pair bows apart while passing.
	var store := {}
	var target_x := 40.0
	BossSkillCardHudSpec.advance_card_shuffle(store, "up", target_x, 100.0, 1.0, 0.0)
	BossSkillCardHudSpec.advance_card_shuffle(store, "down", target_x, 40.0, 1.0, 0.0)
	var t := FRAME_DT
	# Trigger both retargets on the same frame (real reorder is one sort flip).
	BossSkillCardHudSpec.advance_card_shuffle(store, "up", target_x, 40.0, 1.0, t)
	BossSkillCardHudSpec.advance_card_shuffle(store, "down", target_x, 100.0, 1.0, t)
	var separated := false
	for _i in range(40):
		t += FRAME_DT
		var up := BossSkillCardHudSpec.advance_card_shuffle(store, "up", target_x, 40.0, 1.0, t)
		var down := BossSkillCardHudSpec.advance_card_shuffle(store, "down", target_x, 100.0, 1.0, t)
		var up_x := float(up.get("x"))
		var down_x := float(down.get("x"))
		if up_x < down_x - 0.5 and up_x <= target_x and down_x <= target_x:
			separated = true
	_expect(separated, "swapping cards must separate horizontally (up-mover lifts further left)")


func _verify_retarget_continuity() -> void:
	# Mid-flight sort flip: the tween must restart from the CURRENT displayed
	# position — a visible jump here reads as exactly the stutter being fixed.
	var store := {}
	var target_x := 40.0
	BossSkillCardHudSpec.advance_card_shuffle(store, "r", target_x, 100.0, 1.0, 0.0)
	var t := 0.0
	var prev := {"x": target_x, "y": 100.0}
	for i in range(40):
		t += FRAME_DT
		# Flip the target mid-flight (frame 8: ~30% into the first tween).
		var target_y := 160.0 if i < 8 else 100.0
		var r := BossSkillCardHudSpec.advance_card_shuffle(store, "r", target_x, target_y, 1.0, t)
		var dy: float = absf(float(r.get("y")) - float(prev.get("y")))
		var dx: float = absf(float(r.get("x")) - float(prev.get("x")))
		# One 72fps frame can legitimately move a few px; a retarget jump would
		# be tens of px. 6px/frame is far above the tween's real max step (~4).
		_expect(dy <= 6.0, "y must stay continuous across a mid-flight retarget (jump %f px)" % dy)
		_expect(dx <= 6.0, "lift must stay continuous across a mid-flight retarget (jump %f px)" % dx)
		prev = r
	_expect(_near(float(prev.get("y")), 100.0), "after the flip-back the card must settle on the restored slot")


func _verify_time_jump_completes() -> void:
	# A huge time jump (tab regained focus / stall) just completes the tween:
	# exact target, zero lift, no fling, no NaN.
	var store := {}
	var target_x := 40.0
	BossSkillCardHudSpec.advance_card_shuffle(store, "s", target_x, 100.0, 1.0, 0.0)
	BossSkillCardHudSpec.advance_card_shuffle(store, "s", target_x, 160.0, 1.0, 0.01)
	var r := BossSkillCardHudSpec.advance_card_shuffle(store, "s", target_x, 160.0, 1.0, 100.0)
	_expect(_near(float(r.get("y")), 160.0), "a stalled tween must complete exactly on target")
	_expect(_near(float(r.get("x")), target_x), "a stalled tween must land with zero lift")
	# Reverse/equal timestamps must also stay finite and in-range.
	var r2 := BossSkillCardHudSpec.advance_card_shuffle(store, "s", target_x, 160.0, 1.0, 100.0)
	_expect(is_finite(float(r2.get("y"))) and is_finite(float(r2.get("x"))), "same-timestamp re-poll must stay finite")


func _verify_prune() -> void:
	var store := {"a": {"from_y": 1.0}, "b": {"from_y": 2.0}, "c": {"from_y": 3.0}}
	BossSkillCardHudSpec.prune_shuffle_store(store, [{"id": "a"}, {"id": "c"}])
	_expect(store.has("a") and store.has("c"), "prune must keep still-present cards")
	_expect(not store.has("b"), "prune must drop cards missing from the sorted entries")


func _near(value: float, target: float) -> bool:
	return absf(value - target) <= 0.001


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
