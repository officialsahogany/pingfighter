extends SceneTree

# Seals the Koyora 꼭두각시 조종 rope-cut visual upgrade: when the live ball cuts
# the puppet strings the break must read as a stretched rubber band SNAPPING —
# each severed end frays into several strands splaying in different directions
# AND the free ends recoil toward their anchors over the RETURN window — not the
# old clean two-stub "knife cut". Asserts the structural OUTCOME (fray bundles
# populated, wide splay fan, monotonic elastic snap-back), so a regression back
# to a clean cut (no fray) or a static gap (no recoil) turns this red.

const PuppetGrabSkill := preload("res://scripts/lingpet/lingpet_puppet_grab_skill.gd")
const PayloadFactory := preload("res://scripts/lingpet/lingpet_puppet_grab_payload_factory.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var boss_pos := Vector2(330.0, 25.0)
	var ball_active := true
	var ball_pos := Vector2(10.0, 740.0)       # parked off the rope until we aim it
	var ball_pos_prev := Vector2(12.0, 738.0)
	var ball_size := 28.6
	var lingpet_puppet_grab_active := false


func _init() -> void:
	seed(20260623)
	_verify_recoil_is_elastic_snap_back()
	_verify_fray_bundle_structure()
	_verify_live_cut_populates_fray_and_recoils()
	if _failures.is_empty():
		print("lingpet_puppet_grab_rope_snap_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_recoil_is_elastic_snap_back() -> void:
	var skill: Object = PuppetGrabSkill.new()
	var anchor := Vector2(380.0, 634.0)
	var brk := Vector2(380.0, 300.0)
	var p0: Vector2 = skill.get_cut_recoil_free_point_for_tests(anchor, brk, 0.0)
	var p_mid: Vector2 = skill.get_cut_recoil_free_point_for_tests(anchor, brk, 0.5)
	var p1: Vector2 = skill.get_cut_recoil_free_point_for_tests(anchor, brk, 1.0)
	var d0 := anchor.distance_to(p0)
	var d_mid := anchor.distance_to(p_mid)
	var d1 := anchor.distance_to(p1)
	# At the instant of the cut the free end sits at the break...
	_expect(p0.distance_to(brk) < 0.5, "cut free end should start at the break point (rp=0)")
	# ...then snaps back toward the anchor (monotonic retraction, not a static gap).
	_expect(d0 > d_mid + 1.0, "free end should recoil toward the anchor by mid-snap")
	_expect(d_mid > d1 + 1.0, "free end should keep recoiling through the snap")
	# A short dangling stub survives at the end (never collapses into the anchor).
	var full := anchor.distance_to(brk)
	_expect(d1 > full * 0.10 and d1 < full * 0.45, "snap should leave a short dangling stub, not vanish")
	# The ease itself is monotonic and bounded.
	_expect(is_zero_approx(skill._cut_recoil_retract(0.0)), "recoil retract should be 0 at the cut")
	_expect(is_equal_approx(skill._cut_recoil_retract(1.0), 1.0), "recoil retract should reach 1 at settle")
	_expect(skill._cut_recoil_retract(0.3) < skill._cut_recoil_retract(0.7), "recoil retract should increase monotonically")


func _verify_fray_bundle_structure() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var bundle: Array = PayloadFactory.build_cut_fray_bundle(rng)
	_expect(bundle.size() == PayloadFactory.CUT_FIBERS_PER_END, "fray bundle should carry several distinct strands")
	_expect(bundle.size() >= 3, "a frayed end needs more than one strand to read as a torn cord, not a clean stub")
	var splays: Array[float] = []
	var min_len := 1.0e9
	var max_len := 0.0
	var long_count := 0
	for fiber in bundle:
		splays.append(float(fiber.get("splay", 0.0)))
		var flen := float(fiber.get("len", 0.0))
		_expect(flen > 0.0, "each fray strand should have positive length")
		_expect(float(fiber.get("wob_amp", 0.0)) > 0.0, "each fray strand should lash (nonzero wobble amplitude)")
		min_len = minf(min_len, flen)
		max_len = maxf(max_len, flen)
		if bool(fiber.get("long", false)):
			long_count += 1
			_expect(float(fiber.get("droop", 0.0)) > 0.3, "long streamers should droop/drape under gravity")
	var lo := splays[0]
	var hi := splays[0]
	for s in splays:
		lo = minf(lo, s)
		hi = maxf(hi, s)
	# The strands must fan out across a WIDE angular spread — multiple directions.
	_expect(hi - lo > 1.0, "fray strands should splay across a wide fan (multiple directions, not collinear)")
	# A mix of short torn stubs AND a few long flowing streamers (not all equal).
	_expect(long_count >= 2, "the snapped end should sprout a few long streamer strands")
	_expect(max_len > 45.0, "at least one strand should stream out long, not just short stubs")
	_expect(min_len < 26.0, "the torn cross-section should still keep short stubs alongside the long streamers")
	_expect(max_len > min_len * 2.0, "fray strand lengths should vary widely (long flowing threads + short stubs)")
	# Determinism: same seed → identical bundle (stable strand identity per cut).
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var bundle2: Array = PayloadFactory.build_cut_fray_bundle(rng2)
	_expect(is_equal_approx(float(bundle2[0].get("splay", 999.0)), float(bundle[0].get("splay", -999.0))), "same seed should rebuild an identical fray bundle")


func _verify_live_cut_populates_fray_and_recoils() -> void:
	var skill: Object = PuppetGrabSkill.new()
	var owner := FakeOwner.new()
	var origin := Vector2(380.0, 640.0)
	_expect(bool(skill.launch(origin, owner, {"active_skill_level": 1})), "puppet grab should launch")

	var delta := 1.0 / 60.0
	# Step through EXTENDING (boss stays put → HIT) and into PULLING past the
	# arming window, keeping the ball parked off the rope so it doesn't cut early.
	var guard := 0
	while int(skill.get_snapshot().get("puppet_grab_phase", -1)) != 1 and guard < 120:
		skill.update(delta, owner, null, {})
		guard += 1
	_expect(int(skill.get_snapshot().get("puppet_grab_phase", -1)) == 1, "puppet grab should reach the PULLING phase on a HIT")
	# Advance past ROPE_CUT_ARMING_SECONDS so the rope is cuttable.
	for _i in range(12):
		skill.update(delta, owner, null, {})

	var snap: Dictionary = skill.get_snapshot()
	var tip: Vector2 = snap.get("puppet_grab_boss_center", Vector2.ZERO)
	var cast_pos: Vector2 = snap.get("puppet_grab_cast_pos", origin)
	var hand := cast_pos + Vector2(0.0, -6.0)
	var mid := hand.lerp(tip, 0.5)
	# Drive the ball onto the rope mid-segment to trigger the cut.
	owner.ball_pos_prev = mid + Vector2(0.0, -4.0)
	owner.ball_pos = mid + Vector2(0.0, 4.0)
	skill.update(delta, owner, null, {})

	var cut_snap: Dictionary = skill.get_snapshot()
	_expect(bool(cut_snap.get("puppet_grab_cut_by_ball", false)), "ball on the rope should cut it")
	_expect(int(cut_snap.get("puppet_grab_phase", -1)) == 3, "a cut should drop the skill into RETURNING")
	_expect(int(cut_snap.get("puppet_grab_cut_fray_hand_strings", 0)) == 5, "every hand-side string should get a fray bundle")
	_expect(int(cut_snap.get("puppet_grab_cut_fray_boss_strings", 0)) == 5, "every boss-side string should get a fray bundle")

	var fray: Dictionary = skill.get_cut_fray_for_tests()
	var hand_bundles: Array = fray.get("hand", [])
	var boss_bundles: Array = fray.get("boss", [])
	_expect(hand_bundles.size() == 5 and boss_bundles.size() == 5, "both severed ends should fray for all strings")
	var total_fibers := 0
	for b in hand_bundles:
		total_fibers += (b as Array).size()
	_expect(total_fibers >= 15, "the snapped end should splay into many strands, not one clean stub")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
