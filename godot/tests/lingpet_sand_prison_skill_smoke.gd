extends SceneTree

const SandPrisonSkill := preload("res://scripts/lingpet/lingpet_sand_prison_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

const SKILL_ID := "rahoset_sand_prison"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var ai_mode := "champion"
	var selected_character_type := "smasher"
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var player_pos := Vector2(300.0, 675.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var ball_active := true
	var waiting_for_serve := false
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(0.0, -8.0)
	var ball_impact_boost := 1.0
	var ball_boost_decay_rate := 0.975
	var ball_min_boost := 0.70
	var lingpet_puppet_grab_active := false
	var lingpet_sand_prison_clamp_active := false
	var lingpet_sand_prison_cage_left := 0.0
	var lingpet_sand_prison_cage_right := 760.0
	var lingpet_star_coil_boss_slow_active := false
	var lingpet_star_coil_boss_slow_multiplier := 1.0
	var lingpet_star_coil_block_boss_dash := false
	var lingpet_dwarf_magic_shrink_active := false
	var lingpet_dwarf_magic_shrink_scale := 1.0
	var lingpet_dwarf_magic_boss_slow_active := false
	var lingpet_dwarf_magic_boss_slow_multiplier := 1.0


class FakeRoundFlowState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false

	func does_player_serve() -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return {
			"serve_timer": 0.0,
			"serve_delay": 1.0,
		}


class FakeAudio:
	extends RefCounted

	var sand_cast_count := 0
	var active_item_count := 0

	func play_lingpet_sand_prison_cast() -> void:
		sand_cast_count += 1

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	extends RefCounted

	var round_flow_state: Object = FakeRoundFlowState.new()
	var audio: Object = null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "round_flow_state":
			return round_flow_state
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_dispatcher_catalog_and_fixed_tuning()
	_verify_visual_parity_tuning()
	_verify_creation_and_imprison_level_tables()
	_verify_escape_miss_and_capture_flag_publish()
	_verify_retry_rolls_are_per_opportunity()
	_verify_level5_retries_cap_at_two()
	_verify_natural_finish_clears_lingering_particles()
	_verify_body_stream_emission_and_direction()
	_verify_miss_wind_sweep_direction()
	_verify_boss_ai_clamps_position_without_killing_velocity()
	_verify_context_builder_schema_and_round_reset()
	_verify_ownerless_cancel_self_heals()
	_verify_host_audio_and_rail_card_routes()
	_verify_can_arm_visible_onscreen_gate()

	if _failures.is_empty():
		print("lingpet_sand_prison_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_catalog_and_fixed_tuning() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("sand_prison"), "sand_prison should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.is_sand_prison(SKILL_ID), "dispatcher should route Rahoset Sand Prison to the sand_prison runtime")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "rahoset_sand_prison should resolve to a supported runtime")
	_expect(LingpetSkillDispatcher.has_exclusive_resource_class(SKILL_ID, LingpetSkillDispatcher.RESOURCE_CLASS_POS_OVERRIDE), "Sand Prison should reserve the companion position override resource")

	var meta: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not meta.is_empty(), "catalog should expose Sand Prison metadata")
	_expect(str(meta.get("runtime_kind", "")) == "sand_prison", "Sand Prison metadata should use the sand_prison runtime kind")
	_expect(is_equal_approx(float(meta.get("cooldown", 0.0)), 30.0), "Sand Prison base cooldown should be 30s")
	_expect(is_equal_approx(float(meta.get("windup_seconds", 0.0)), 0.4), "Sand Prison base windup should be 0.4s")
	var lv5: Dictionary = LingpetCatalog.get_active_skill("rahoset", SKILL_ID, 5)
	_expect(is_equal_approx(float(lv5.get("cooldown", 0.0)), 30.0), "Sand Prison cooldown should stay fixed at Lv.5")
	_expect(is_equal_approx(float(lv5.get("windup_seconds", 0.0)), 0.4), "Sand Prison windup should stay fixed at Lv.5")
	_expect(bool(lv5.get("cooldown_by_level_authoritative", false)), "Sand Prison fixed cooldown should be marked authoritative")
	_expect(bool(lv5.get("windup_seconds_by_level_authoritative", false)), "Sand Prison fixed windup should be marked authoritative")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "Rahoset Sand Prison catalog metadata should validate cleanly")


func _verify_visual_parity_tuning() -> void:
	var tuning: Dictionary = SandPrisonSkill.new().get_visual_tuning_for_tests()
	_expect(is_equal_approx(float(tuning.get("wall_alpha_cap", 0.0)), 200.0 / 255.0), "Sand Prison wall alpha should cap at the Python 200/255 level")
	_expect(int(tuning.get("wall_grain_step", 0)) == 3, "Sand Prison wall grain should use the Python 3px strip cadence")
	_expect(is_equal_approx(float(tuning.get("wall_grain_width", 0.0)), 6.0), "Sand Prison wall grain should use the Python 6px visible strip width")
	_expect(is_equal_approx(float(tuning.get("wall_surface_width", 0.0)), 8.0), "Sand Prison wall surface should match the Python 8px wall surface")
	_expect(is_equal_approx(float(tuning.get("decor_bar_height", 0.0)), 5.0), "Sand Prison top/bottom grain bars should use the Python 5px height")
	_expect(is_equal_approx(float(tuning.get("top_bar_reveal_ratio", 0.0)), 0.9), "Sand Prison top bar should appear only near build completion")
	_expect(is_equal_approx(float(tuning.get("corner_reveal_ratio", 0.0)), 0.8), "Sand Prison corner circles should appear after the Python 80% threshold")
	_expect(is_equal_approx(float(tuning.get("corner_radius", 0.0)), 6.0), "Sand Prison corner circles should use the Python radius")
	_expect(is_equal_approx(float(tuning.get("floor_alpha_cap", 0.0)), 22.0 / 255.0), "Sand Prison floor tint should stay faint like the Python floor fill")


func _verify_creation_and_imprison_level_tables() -> void:
	var lv1 := SandPrisonSkill.new()
	_expect(lv1.launch(Vector2(380.0, 640.0), FakeOwner.new(), {"active_skill_level": 1}), "Sand Prison Lv.1 should launch")
	var s1: Dictionary = lv1.get_snapshot()
	_expect(is_equal_approx(float(s1.get("sand_prison_creation_seconds", 0.0)), 1.5), "Lv.1 creation should be 1.5s")
	_expect(is_equal_approx(float(s1.get("sand_prison_imprison_seconds", 0.0)), 2.3), "Lv.1 imprison should be 2.3s")
	_expect(int(s1.get("sand_prison_retries_remaining", -1)) == 0, "Lv.1 should have no retries")

	var lv5 := SandPrisonSkill.new()
	_expect(lv5.launch(Vector2(380.0, 640.0), FakeOwner.new(), {"active_skill_level": 5}), "Sand Prison Lv.5 should launch")
	var s5: Dictionary = lv5.get_snapshot()
	_expect(is_equal_approx(float(s5.get("sand_prison_creation_seconds", 0.0)), 0.7), "Lv.5 creation should be 0.7s")
	_expect(is_equal_approx(float(s5.get("sand_prison_imprison_seconds", 0.0)), 4.0), "Lv.5 imprison should be 4.0s")
	_expect(int(s5.get("sand_prison_retries_remaining", -1)) == 2, "Lv.5 should have two possible retries")
	_expect(is_equal_approx(float(s5.get("sand_prison_retry_chance_pct", 0.0)), 50.0), "Lv.5 retry chance should be 50%")


func _verify_escape_miss_and_capture_flag_publish() -> void:
	var miss_skill := SandPrisonSkill.new()
	var miss_owner := FakeOwner.new()
	_expect(miss_skill.launch(Vector2(380.0, 640.0), miss_owner, {"active_skill_level": 1}), "Sand Prison miss case should launch")
	_move_boss_outside_current_cage(miss_skill, miss_owner)
	miss_skill.update(float(miss_skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, miss_owner)
	var miss_snap: Dictionary = miss_skill.get_snapshot()
	_expect(bool(miss_snap.get("sand_prison_missing", false)), "boss outside the cage at creation end should MISS")
	_expect(not bool(miss_owner.lingpet_sand_prison_clamp_active), "MISS should not publish the clamp flag")
	_expect(int(miss_snap.get("sand_prison_miss_count", 0)) == 1, "MISS should be counted once")

	var capture_skill := SandPrisonSkill.new()
	var capture_owner := FakeOwner.new()
	_expect(capture_skill.launch(Vector2(380.0, 640.0), capture_owner, {"active_skill_level": 1}), "Sand Prison capture case should launch")
	capture_skill.update(float(capture_skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, capture_owner)
	var capture_snap: Dictionary = capture_skill.get_snapshot()
	_expect(bool(capture_snap.get("sand_prison_imprison", false)), "boss still inside the cage should enter IMPRISON")
	_expect(bool(capture_owner.lingpet_sand_prison_clamp_active), "capture should publish owner clamp active")
	_expect(capture_owner.lingpet_sand_prison_cage_left < capture_owner.lingpet_sand_prison_cage_right, "capture should publish ordered cage bounds")
	_expect(int(capture_snap.get("sand_prison_capture_count", 0)) == 1, "capture should be counted once")


func _verify_retry_rolls_are_per_opportunity() -> void:
	var skill := SandPrisonSkill.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.audio = audio
	skill.set_retry_roll_queue_for_tests([true])
	_expect(skill.launch(Vector2(380.0, 640.0), owner, {"active_skill_level": 3}), "Lv.3 retry test should launch")
	_move_boss_outside_current_cage(skill, owner)
	skill.update(float(skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, owner, registry)
	var retry_wait: Dictionary = skill.get_snapshot()
	_expect(bool(retry_wait.get("sand_prison_retry_wait", false)), "successful Lv.3 miss roll should enter retry wait")
	_expect(int(retry_wait.get("sand_prison_retry_rolls_queued", -1)) == 0, "retry roll should be consumed once at the miss opportunity")
	for _i in range(4):
		skill.update(0.10, owner, registry)
	_expect(int(skill.get_snapshot().get("sand_prison_shot_count", 0)) == 1, "retry wait should not roll or reshoot every frame")
	skill.update(0.11, owner, registry)
	var retry_shot: Dictionary = skill.get_snapshot()
	_expect(int(retry_shot.get("sand_prison_shot_count", 0)) == 2, "retry should create exactly one second summon")
	_expect(int(retry_shot.get("sand_prison_retry_count", 0)) == 1, "retry count should advance once")
	_expect(audio.sand_cast_count == 1, "retry summon should replay the sand prison cast cue once")

	var no_retry := SandPrisonSkill.new()
	var no_retry_owner := FakeOwner.new()
	no_retry.set_retry_roll_queue_for_tests([false])
	_expect(no_retry.launch(Vector2(380.0, 640.0), no_retry_owner, {"active_skill_level": 3}), "Lv.3 no-retry test should launch")
	_move_boss_outside_current_cage(no_retry, no_retry_owner)
	no_retry.update(float(no_retry.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, no_retry_owner)
	var no_retry_snap: Dictionary = no_retry.get_snapshot()
	_expect(bool(no_retry_snap.get("sand_prison_missing", false)), "failed Lv.3 retry roll should go to MISS instead of retry wait")
	_expect(int(no_retry_snap.get("sand_prison_shot_count", 0)) == 1, "failed retry roll should not resummon")


func _verify_level5_retries_cap_at_two() -> void:
	var skill := SandPrisonSkill.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.audio = FakeAudio.new()
	skill.set_retry_roll_queue_for_tests([true, true, true])
	_expect(skill.launch(Vector2(380.0, 640.0), owner, {"active_skill_level": 5}), "Lv.5 retry cap test should launch")
	for expected_shots in [1, 2, 3]:
		_move_boss_outside_current_cage(skill, owner)
		skill.update(float(skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, owner, registry)
		if expected_shots < 3:
			_expect(bool(skill.get_snapshot().get("sand_prison_retry_wait", false)), "Lv.5 miss #%d should enter retry wait" % expected_shots)
			skill.update(0.51, owner, registry)
	var snap: Dictionary = skill.get_snapshot()
	_expect(int(snap.get("sand_prison_shot_count", 0)) == 3, "Lv.5 should cap at initial summon plus two retries")
	_expect(int(snap.get("sand_prison_retry_count", 0)) == 2, "Lv.5 should execute exactly two retries")
	_expect(bool(snap.get("sand_prison_missing", false)), "third Lv.5 miss should end as MISS")


func _verify_natural_finish_clears_lingering_particles() -> void:
	var capture_skill := SandPrisonSkill.new()
	var capture_owner := FakeOwner.new()
	_expect(capture_skill.launch(Vector2(380.0, 640.0), capture_owner, {"active_skill_level": 1}), "particle cleanup capture case should launch")
	capture_skill.update(
		float(capture_skill.get_snapshot().get("sand_prison_creation_seconds", 0.0))
			+ float(capture_skill.get_snapshot().get("sand_prison_imprison_seconds", 0.0))
			+ 0.60,
		capture_owner
	)
	_expect(not capture_skill.has_visible_effects(), "natural capture+dissolve finish should clear lingering sand particles")
	_expect(int(capture_skill.get_snapshot().get("sand_prison_particle_count", -1)) == 0, "natural capture+dissolve finish should empty the sand particle array")
	_expect(int(capture_skill.get_snapshot().get("sand_prison_body_particle_count", -1)) == 0, "natural capture+dissolve finish should empty the body sand stream")

	var miss_skill := SandPrisonSkill.new()
	var miss_owner := FakeOwner.new()
	_expect(miss_skill.launch(Vector2(380.0, 640.0), miss_owner, {"active_skill_level": 1}), "particle cleanup miss case should launch")
	_move_boss_outside_current_cage(miss_skill, miss_owner)
	miss_skill.update(float(miss_skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, miss_owner)
	miss_skill.update(0.46, miss_owner)
	_expect(not miss_skill.has_visible_effects(), "natural MISS finish should clear lingering sand particles")
	_expect(int(miss_skill.get_snapshot().get("sand_prison_particle_count", -1)) == 0, "natural MISS finish should empty the sand particle array")
	_expect(int(miss_skill.get_snapshot().get("sand_prison_body_particle_count", -1)) == 0, "natural MISS finish should empty the body sand stream")


func _verify_body_stream_emission_and_direction() -> void:
	var skill := SandPrisonSkill.new()
	var owner := FakeOwner.new()
	# Cast origin below the top cage so every body grain must fly UPWARD toward it.
	_expect(skill.launch(Vector2(380.0, 640.0), owner, {"active_skill_level": 1}), "body stream test should launch")
	skill.update(0.1, owner)
	var count_creating := int(skill.get_snapshot().get("sand_prison_body_particle_count", 0))
	_expect(count_creating > 0, "body sand stream should emit during CREATING")
	_expect(count_creating <= int(skill.get_snapshot().get("sand_prison_body_particle_cap", 200)), "body stream should respect its particle cap")
	var grains: Array = skill.get_body_particles_for_tests()
	_expect(not grains.is_empty(), "body stream should expose grains for inspection")
	var all_toward_cage := true
	for grain in grains:
		var vel: Vector2 = grain.get("vel", Vector2.ZERO)
		if vel.y >= 0.0:
			all_toward_cage = false
	_expect(all_toward_cage, "every body grain should flow from Rahoset's body up toward the cage (vel.y < 0)")

	# Roll into IMPRISON, let the grains expire, and prove the stream does NOT refill
	# outside CREATING (emission is build-gated).
	skill.update(2.0, owner)
	_expect(bool(skill.get_snapshot().get("sand_prison_imprison", false)), "body stream test should capture into IMPRISON")
	skill.update(0.95, owner)
	_expect(int(skill.get_snapshot().get("sand_prison_body_particle_count", -1)) == 0, "body grains should expire and NOT refill outside CREATING")
	skill.update(0.30, owner)
	_expect(int(skill.get_snapshot().get("sand_prison_body_particle_count", -1)) == 0, "IMPRISON must not re-emit the body stream")


func _verify_miss_wind_sweep_direction() -> void:
	# MISS 세척 연출: 바람 그레인(|vel.x|>=50, 앰비언트는 |vel.x|<=12)은 보스가 도망친
	# 방향으로만 쓸려야 한다. 오른쪽/왼쪽 도주 양방향을 각각 검증.
	var right_skill := SandPrisonSkill.new()
	var right_owner := FakeOwner.new()
	_expect(right_skill.launch(Vector2(380.0, 640.0), right_owner, {"active_skill_level": 1}), "wind sweep right case should launch")
	_move_boss_outside_current_cage(right_skill, right_owner)
	right_skill.update(float(right_skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, right_owner)
	_expect(bool(right_skill.get_snapshot().get("sand_prison_missing", false)), "wind sweep right case should MISS")
	_expect(is_equal_approx(float(right_skill.get_wash_dir_for_tests()), 1.0), "boss escaping right should set wash dir +1")
	var right_wind := _collect_wind_grains(right_skill)
	_expect(right_wind.size() >= 20, "MISS should spawn a wind sweep burst")
	var right_ok := true
	for grain in right_wind:
		if _as_vector2(grain.get("vel", Vector2.ZERO)).x <= 0.0:
			right_ok = false
	_expect(right_ok, "every wind grain should sweep toward the right escape side")

	var left_skill := SandPrisonSkill.new()
	var left_owner := FakeOwner.new()
	_expect(left_skill.launch(Vector2(380.0, 640.0), left_owner, {"active_skill_level": 1}), "wind sweep left case should launch")
	var left_snap: Dictionary = left_skill.get_snapshot()
	left_owner.boss_pos.x = float(left_snap.get("sand_prison_cage_left", 0.0)) - float(left_owner.boss_paddle_width) - 24.0
	left_skill.update(float(left_snap.get("sand_prison_creation_seconds", 0.0)) + 0.01, left_owner)
	_expect(bool(left_skill.get_snapshot().get("sand_prison_missing", false)), "wind sweep left case should MISS")
	_expect(is_equal_approx(float(left_skill.get_wash_dir_for_tests()), -1.0), "boss escaping left should set wash dir -1")
	var left_wind := _collect_wind_grains(left_skill)
	_expect(left_wind.size() >= 20, "left MISS should spawn a wind sweep burst")
	var left_ok := true
	for grain in left_wind:
		if _as_vector2(grain.get("vel", Vector2.ZERO)).x >= 0.0:
			left_ok = false
	_expect(left_ok, "every wind grain should sweep toward the left escape side")


func _collect_wind_grains(skill: Object) -> Array:
	var wind: Array = []
	for grain in skill.get_sand_particles_for_tests():
		if absf(_as_vector2(grain.get("vel", Vector2.ZERO)).x) >= 50.0:
			wind.append(grain)
	return wind


func _verify_boss_ai_clamps_position_without_killing_velocity() -> void:
	var boss_ai := BossAiState.new()
	var result: Dictionary = {
		"boss_pos": Vector2(500.0, 25.0),
		"boss_vel": -6.0,
	}
	var clamped: Dictionary = boss_ai._apply_lingpet_sand_prison_clamp(result, {
		"lingpet_sand_prison_clamp_active": true,
		"lingpet_sand_prison_cage_left": 240.0,
		"lingpet_sand_prison_cage_right": 360.0,
		"boss_paddle_width": 100.0,
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
	})
	_expect(is_equal_approx((_as_vector2(clamped.get("boss_pos", Vector2.ZERO))).x, 260.0), "Sand Prison should clamp boss x into cage-right minus paddle width")
	_expect(is_equal_approx(float(clamped.get("boss_vel", 0.0)), -6.0), "Sand Prison clamp should preserve boss velocity")

	var puppet_wins: Dictionary = boss_ai._apply_lingpet_sand_prison_clamp(result, {
		"lingpet_puppet_grab_active": true,
		"lingpet_sand_prison_clamp_active": true,
		"lingpet_sand_prison_cage_left": 240.0,
		"lingpet_sand_prison_cage_right": 360.0,
		"boss_paddle_width": 100.0,
	})
	_expect(is_equal_approx((_as_vector2(puppet_wins.get("boss_pos", Vector2.ZERO))).x, 500.0), "Puppet Grab's scripted boss position should remain authoritative over stale cage flags")
	_expect(is_equal_approx(float(puppet_wins.get("boss_vel", 0.0)), -6.0), "Puppet guard should leave the original velocity value untouched")


func _verify_context_builder_schema_and_round_reset() -> void:
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_sand_prison_clamp_active"), "BattleSceneState must declare Sand Prison clamp active")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_sand_prison_cage_left"), "BattleSceneState must declare Sand Prison cage left")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_sand_prison_cage_right"), "BattleSceneState must declare Sand Prison cage right")
	_expect(not bool(BattleSceneState.DEFAULT_VALUES.get("lingpet_sand_prison_clamp_active", true)), "Sand Prison clamp default should be inactive")
	_expect(is_equal_approx(float(BattleSceneState.DEFAULT_VALUES.get("lingpet_sand_prison_cage_left", -1.0)), 0.0), "Sand Prison left default should reset to field left")
	_expect(is_equal_approx(float(BattleSceneState.DEFAULT_VALUES.get("lingpet_sand_prison_cage_right", 0.0)), 760.0), "Sand Prison right default should reset to field right")

	var owner := FakeOwner.new()
	owner.lingpet_sand_prison_clamp_active = true
	owner.lingpet_sand_prison_cage_left = 240.0
	owner.lingpet_sand_prison_cage_right = 360.0
	var ai_context: Dictionary = BossAiContextBuilder.new().build_context(owner, FakeRegistry.new())
	_expect(bool(ai_context.get("lingpet_sand_prison_clamp_active", false)), "boss AI context should receive Sand Prison clamp active")
	_expect(is_equal_approx(float(ai_context.get("lingpet_sand_prison_cage_left", 0.0)), 240.0), "boss AI context should receive cage left")
	_expect(is_equal_approx(float(ai_context.get("lingpet_sand_prison_cage_right", 0.0)), 360.0), "boss AI context should receive cage right")

	var common: Dictionary = BallRoundState.new().build_common_snapshot()
	_expect(common.has("lingpet_sand_prison_clamp_active") and not bool(common.get("lingpet_sand_prison_clamp_active", true)), "round common snapshot must clear Sand Prison clamp active")
	_expect(is_equal_approx(float(common.get("lingpet_sand_prison_cage_left", -1.0)), 0.0), "round common snapshot must reset cage left")
	_expect(is_equal_approx(float(common.get("lingpet_sand_prison_cage_right", 0.0)), 760.0), "round common snapshot must reset cage right")


func _verify_ownerless_cancel_self_heals() -> void:
	var skill := SandPrisonSkill.new()
	var owner := FakeOwner.new()
	_expect(skill.launch(Vector2(380.0, 640.0), owner, {"active_skill_level": 1}), "ownerless cancel test should launch")
	skill.update(float(skill.get_snapshot().get("sand_prison_creation_seconds", 0.0)) + 0.01, owner)
	_expect(bool(owner.lingpet_sand_prison_clamp_active), "capture should set owner clamp before ownerless cancel")
	skill.cancel()
	_expect(bool(owner.lingpet_sand_prison_clamp_active), "ownerless cancel should preserve the stale owner flag until an owner update self-heals it")
	skill.update(0.0, owner)
	_expect(not bool(owner.lingpet_sand_prison_clamp_active), "next update with owner should clear ownerless Sand Prison clamp")
	_expect(is_equal_approx(owner.lingpet_sand_prison_cage_left, 0.0), "ownerless self-heal should reset cage left")
	_expect(is_equal_approx(owner.lingpet_sand_prison_cage_right, 760.0), "ownerless self-heal should reset cage right")


func _verify_host_audio_and_rail_card_routes() -> void:
	var host := LingpetSkillRuntimeHost.new()
	var registry := FakeRegistry.new()
	var audio := FakeAudio.new()
	registry.audio = audio
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.sand_cast_count == 1, "runtime host should route Sand Prison launch feedback to the dedicated cast cue")

	var owner := FakeOwner.new()
	_expect(host.launch(SKILL_ID, Vector2(380.0, 640.0), owner, {"active_skill_level": 5}), "runtime host should launch Sand Prison")
	_expect(bool(host.get_snapshot().get("sand_prison_active", false)), "runtime host snapshot should include Sand Prison state")
	_expect(host.has_visible_effects_for_skill(SKILL_ID), "runtime host should report Sand Prison visible effects while active")
	_expect(host.has_companion_position_override(SKILL_ID), "runtime host should expose Sand Prison companion position override")
	host.reset(owner, registry)

	var keys: Array = LingpetRailCard._casting_flag_keys_for_skill(SKILL_ID)
	_expect(keys.has("sand_prison_active"), "rail card should treat sand_prison_active as the Sand Prison casting flag")
	_expect(LingpetRailCard._is_skill_casting({"sand_prison_active": true}, SKILL_ID, ""), "rail card should show Sand Prison casting from its own flag")
	_expect(not LingpetRailCard._is_skill_casting({"gravity_accel_active": true}, SKILL_ID, ""), "rail card should not borrow another lingpet skill's casting flag")


func _verify_can_arm_visible_onscreen_gate() -> void:
	var skill := SandPrisonSkill.new()
	_expect(not skill.can_arm({"companion_visible": false, "companion_pos": Vector2(100.0, 100.0)}), "Sand Prison should not arm while Rahoset is hidden")
	_expect(not skill.can_arm({"companion_visible": true, "companion_pos": Vector2(-8.0, 100.0)}), "Sand Prison should not arm while Rahoset is offscreen")
	_expect(skill.can_arm({"companion_visible": true, "companion_pos": Vector2(100.0, 100.0)}), "Sand Prison should arm when Rahoset is visible and onscreen")


func _move_boss_outside_current_cage(skill: Object, owner: Object) -> void:
	var snap: Dictionary = skill.get_snapshot()
	owner.boss_pos.x = float(snap.get("sand_prison_cage_right", 760.0)) + 24.0


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
