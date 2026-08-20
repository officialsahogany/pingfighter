extends SceneTree

const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const Stage2BossVariantSkillState := preload("res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")

const EXPECTED_LEG_COUNT := 10

var _failures: Array[String] = []
var _leg_count := 0


class FakeOwner:
	extends RefCounted

	var values: Dictionary

	func _init(stage_id: int, variant_id: String) -> void:
		values = {
			"current_stage": stage_id,
			"stage_boss_variant": variant_id,
			"ball_pos": Vector2(380.0, 360.0),
			"ball_vel": Vector2(4.0, -8.0),
			"ball_active": true,
			"player_pos": Vector2(302.5, 680.0),
			"boss_pos": Vector2(330.0, 25.0),
		}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)


func _init() -> void:
	_run_leg(_verify_molewang_first_hit_result)
	_run_leg(_verify_molewang_gauge_gain)
	_run_leg(_verify_arachne_result)
	_run_leg(_verify_teddy_bear_result)
	_run_leg(_verify_alice_result)
	_run_leg(_verify_stage2_missing_key_fails_closed)
	_run_leg(_verify_stage3_missing_key_fails_closed)
	_run_leg(_verify_default_boss_route_is_intact)
	_run_leg(_verify_stage2_campaign_empty_variant_keeps_default_boss)
	_run_leg(_verify_stage3_campaign_empty_variant_keeps_default_boss)
	_expect(_leg_count == EXPECTED_LEG_COUNT, "leg count must remain %d" % EXPECTED_LEG_COUNT)

	if _failures.is_empty():
		print("variant_boss_ball_path_snapshot_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run_leg(leg: Callable) -> void:
	_leg_count += 1
	leg.call()


func _verify_molewang_first_hit_result() -> void:
	var context := _build_snapshot_context(2, "molewang")
	var state := Stage2BossVariantSkillState.new()
	state.update(0.0, context, {})
	var incoming := Vector2(4.0, -8.0)
	var result: Dictionary = state.register_boss_hit(incoming, context, {})
	var draw_context: Dictionary = state.get_actor_draw_context()
	var returned_velocity: Vector2 = result.get("ball_vel", incoming)

	_expect(
		is_equal_approx(returned_velocity.length(), incoming.length() * 0.8),
		"Molewang first hit must apply Spinning Claw's 0.8 ball-speed result"
	)
	_expect(
		is_equal_approx(float(result.get("ball_spin_strength", 0.0)), 0.55),
		"Molewang first hit must apply Spinning Claw spin"
	)
	_expect(
		bool(draw_context.get("molewang_spinning_claw_active", false)),
		"Molewang first hit must expose an active Spinning Claw draw state"
	)
	_expect(state.active_variant == "molewang", "Molewang active_variant must survive update -> hit")


func _verify_molewang_gauge_gain() -> void:
	var context := _build_snapshot_context(2, "molewang")
	var state := Stage2BossVariantSkillState.new()
	state.update(0.0, context, {})
	state.molewang_state.spinning_claw_cooldown = 1.0
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), context, {})

	_expect(
		is_equal_approx(state.molewang_state.boss_special_gauge, 60.0),
		"Molewang boss hit must raise the real gauge by 60 when spending is blocked"
	)
	_expect(
		is_equal_approx(float(result.get("stage2_boss_gauge_gain", 0.0)), 60.0),
		"Molewang boss hit result must report the real +60 gain"
	)


func _verify_arachne_result() -> void:
	var context := _build_snapshot_context(2, "arachne")
	var state := Stage2BossVariantSkillState.new()
	state.update(0.0, context, {})
	state.arachne_state.boss_special_gauge = 440.0
	state.register_boss_hit(Vector2(4.0, -8.0), context, {})
	var draw_context: Dictionary = state.get_actor_draw_context()
	var projectile: Dictionary = draw_context.get("arachne_web_trap_projectile", {})

	_expect(not projectile.is_empty(), "Arachne hit must create the real web-trap projectile")
	_expect(state.active_variant == "arachne", "Arachne active_variant must survive update -> hit")


func _verify_teddy_bear_result() -> void:
	var context := _build_snapshot_context(3, "teddy_bear")
	var state := Stage3BossVariantSkillState.new()
	state.update(0.0, context, {})
	state.teddy_bear_state.boss_special_gauge = 150.0
	var passing_seed := _find_first_roll_seed(0.15)
	_expect(passing_seed >= 0, "Teddy deterministic cotton-throw seed must exist")
	state.teddy_bear_state.rng.seed = passing_seed
	state.register_boss_hit(Vector2(4.0, -8.0), context, {})
	var snapshot: Dictionary = state.get_snapshot()

	_expect(
		float(snapshot.get("stage3_teddy_cotton_throw_windup_ratio", 0.0)) > 0.0,
		"Teddy hit must enter the real cotton-throw windup"
	)
	_expect(state.active_variant == "teddy_bear", "Teddy active_variant must survive update -> hit")


func _verify_alice_result() -> void:
	var context := _build_snapshot_context(3, "alice")
	var state := Stage3BossVariantSkillState.new()
	state.update(0.0, context, {})
	state.alice_state.boss_special_gauge = 450.0
	state.alice_state.size_shift_cooldown = 99.0
	state.alice_state.rabbit_cooldown = 99.0
	state.register_boss_hit(Vector2(4.0, -8.0), context, {})
	var snapshot: Dictionary = state.get_snapshot()

	_expect(bool(snapshot.get("stage3_alice_mirror_active", false)), "Alice hit must activate the real mirror state")
	_expect(float(snapshot.get("mirror_cooldown", 0.0)) > 0.0, "Alice mirror activation must arm its real cooldown")
	_expect(state.active_variant == "alice", "Alice active_variant must survive update -> hit")


func _verify_stage2_missing_key_fails_closed() -> void:
	var context := _build_snapshot_context(2, "molewang")
	var state := Stage2BossVariantSkillState.new()
	state.update(0.0, context, {})
	var stripped_context := context.duplicate(true)
	stripped_context.erase("stage_boss_variant")
	var gauge_before: float = state.molewang_state.boss_special_gauge
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), stripped_context, {})

	_expect(result.is_empty(), "Stage 2 hit without the snapshot variant key must no-op")
	_expect(
		is_equal_approx(state.molewang_state.boss_special_gauge, gauge_before),
		"Stage 2 missing-key hit must not mutate the variant gauge"
	)
	_expect(state.active_variant == "molewang", "Stage 2 missing-key hit must preserve the last valid variant")


func _verify_stage3_missing_key_fails_closed() -> void:
	var context := _build_snapshot_context(3, "alice")
	var state := Stage3BossVariantSkillState.new()
	state.update(0.0, context, {})
	var stripped_context := context.duplicate(true)
	stripped_context.erase("stage_boss_variant")
	var gauge_before: float = state.alice_state.boss_special_gauge
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), stripped_context, {})

	_expect(result.is_empty(), "Stage 3 hit without the snapshot variant key must no-op")
	_expect(
		is_equal_approx(state.alice_state.boss_special_gauge, gauge_before),
		"Stage 3 missing-key hit must not mutate the variant gauge"
	)
	_expect(state.active_variant == "alice", "Stage 3 missing-key hit must preserve the last valid variant")


func _verify_default_boss_route_is_intact() -> void:
	var context := _build_snapshot_context(2, "cheongringwi")
	var state := Stage2BossVariantSkillState.new()
	state.update(0.0, context, {})
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), context, {})

	_expect(state.active_variant == "cheongringwi", "explicit Cheongringwi must retain the default Stage 2 route")
	_expect(state.boss_launch_guard_pending, "explicit Cheongringwi hit must execute the base boss-hit result")
	_expect(result.has("stage2_water_cannon_interrupted"), "default boss hit must retain its production result shape")


func _verify_stage2_campaign_empty_variant_keeps_default_boss() -> void:
	# Campaign shape: the battle scene writes stage_boss_variant exactly once at
	# _ready, and normalize_variant(1, "") is "". No non-tower stage transition
	# rewrites that owner field, so Stage 2 is reached with an EMPTY value that
	# is still present in the snapshot. Cheongringwi must stay alive.
	var context := _build_snapshot_context(2, "")
	var state := Stage2BossVariantSkillState.new()
	state.update(1.0 / 72.0, context, {})
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), context, {})

	_expect(state.active_variant == "cheongringwi", "empty campaign variant must resolve to the Stage 2 default boss")
	_expect(not result.is_empty(), "empty campaign variant must still run the Stage 2 base boss hit")
	_expect(state.boss_launch_guard_pending, "empty campaign variant hit must execute the base boss-hit result")
	_expect(
		result.has("stage2_water_cannon_interrupted"),
		"empty campaign variant hit must retain the production result shape"
	)


func _verify_stage3_campaign_empty_variant_keeps_default_boss() -> void:
	var context := _build_snapshot_context(3, "")
	var state := Stage3BossVariantSkillState.new()
	state.update(1.0 / 72.0, context, {})
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), context, {})

	_expect(state.active_variant == "yeonmyo", "empty campaign variant must resolve to the Stage 3 default boss")
	_expect(not result.is_empty(), "empty campaign variant must still run the Stage 3 base boss hit")


func _build_snapshot_context(stage_id: int, variant_id: String) -> Dictionary:
	var owner := FakeOwner.new(stage_id, variant_id)
	var context: Dictionary = BallUpdateOwnerSnapshot.new().build(owner)
	_expect(int(context.get("current_stage", -1)) == stage_id, "owner snapshot must carry current_stage")
	_expect(
		str(context.get("stage_boss_variant", "")) == variant_id,
		"owner snapshot must carry stage_boss_variant=%s" % variant_id
	)
	return context


func _find_first_roll_seed(max_roll: float) -> int:
	for seed_value in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() <= max_roll:
			return seed_value
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
