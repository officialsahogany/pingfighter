extends SceneTree

const LingpetStarCoilSkill := preload("res://scripts/lingpet/lingpet_star_coil_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const BattleUpdateBossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BattleUpdateEffectsOwnerContextBuilder := preload("res://scripts/core/battle_update_effects_owner_context_builder.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

const SKILL_ID := "orosha_star_coil"
const CARD_PATH := "res://assets/sprites/lingpet/orosha_star_coil_skillcard_imagegen_v1.png"
const ICON_PATH := "res://assets/sprites/lingpet/orosha_star_coil_skill_icon_imagegen_v1.png"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var ai_mode := "champion"
	var selected_character_type := "smasher"
	var boss_pos := Vector2(210.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var player_pos := Vector2(300.0, 675.0)
	var ball_active := true
	var waiting_for_serve := false
	var ball_pos := Vector2(520.0, 300.0)
	var ball_vel := Vector2(0.0, -8.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var ball_boost_decay_rate := 0.975
	var ball_min_boost := 0.70
	var lingpet_puppet_grab_active := false
	var lingpet_star_coil_boss_slow_active := false
	var lingpet_star_coil_boss_slow_multiplier := 1.0
	var lingpet_star_coil_block_boss_dash := false
	var lingpet_star_coil_freeze_boss_skill_cd := false


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


class FakeRegistry:
	extends RefCounted

	var round_flow_state: Object = FakeRoundFlowState.new()
	var boss_ai_state: Object = null

	func _init(boss_ai: Object = null) -> void:
		boss_ai_state = boss_ai

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		match key:
			"round_flow_state":
				return round_flow_state
			"game_audio":
				return null
			"lingpet_egg_runtime":
				return null
			"boss_ai_state":
				return boss_ai_state
		return null


class FakeBossAiState:
	extends RefCounted

	var boss_dash_active := false


class FakeAudio:
	extends RefCounted

	var bind_play_count := 0
	var bind_stop_count := 0
	var move_play_count := 0
	var move_stop_count := 0

	func play_lingpet_star_coil_bind() -> void:
		bind_play_count += 1

	func stop_lingpet_star_coil_bind() -> void:
		bind_stop_count += 1

	func play_lingpet_star_coil_move() -> void:
		move_play_count += 1

	func stop_lingpet_star_coil_move() -> void:
		move_stop_count += 1

	func play_active_item() -> void:
		pass


class FakeAudioRegistry:
	extends RefCounted

	var audio: Object

	func _init(audio_double: Object) -> void:
		audio = audio_double

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	seed(20260621)
	_verify_boss_slow_keys_are_schema_declared()
	_verify_round_snapshots_normalize_lingpet_owner_flags()
	_verify_catalog_dispatcher_and_levels()
	_verify_can_arm_has_no_ball_descending_gate()
	_verify_fsm_reaches_bind_and_slow_owner()
	_verify_slow_self_heals_after_cancel_without_owner()
	_verify_release_crosses_to_opposite_wall()
	_verify_boss_ai_context_and_motion_slow()
	_verify_star_coil_level_tier_cc_policy()
	_verify_host_wiring_and_cleanup_guards()
	_verify_bind_render_integration()
	_verify_roll_uses_path_distance()
	_verify_bind_plays_and_stops_audio()
	_verify_move_audio_loops_during_travel()
	_verify_continuous_star_emission_while_rolling()

	if _failures.is_empty():
		print("lingpet_star_coil_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_boss_slow_keys_are_schema_declared() -> void:
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_star_coil_boss_slow_active"), "BattleSceneState should declare Star Coil slow active or owner.set() silently no-ops it")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_star_coil_boss_slow_multiplier"), "BattleSceneState should declare Star Coil slow multiplier or owner.set() silently no-ops it")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_star_coil_block_boss_dash"), "BattleSceneState should declare Star Coil dash block or owner.set() silently no-ops it")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_star_coil_freeze_boss_skill_cd"), "BattleSceneState should declare Star Coil boss skill cooldown freeze or owner.set() silently no-ops it")
	_expect(bool(BattleSceneState.DEFAULT_VALUES.get("lingpet_star_coil_boss_slow_active", true)) == false, "Star Coil slow active default should be false")
	_expect(is_equal_approx(float(BattleSceneState.DEFAULT_VALUES.get("lingpet_star_coil_boss_slow_multiplier", 0.0)), 1.0), "Star Coil slow multiplier default should be 1.0")
	_expect(bool(BattleSceneState.DEFAULT_VALUES.get("lingpet_star_coil_block_boss_dash", true)) == false, "Star Coil dash block default should be false")
	_expect(bool(BattleSceneState.DEFAULT_VALUES.get("lingpet_star_coil_freeze_boss_skill_cd", true)) == false, "Star Coil boss skill cooldown freeze default should be false")


func _verify_round_snapshots_normalize_lingpet_owner_flags() -> void:
	var common: Dictionary = BallRoundState.new().build_common_snapshot()
	_expect(common.has("lingpet_puppet_grab_active") and not bool(common.get("lingpet_puppet_grab_active", true)), "round common snapshot must clear Puppet Grab boss-freeze ownership")
	_expect(common.has("lingpet_star_coil_boss_slow_active") and not bool(common.get("lingpet_star_coil_boss_slow_active", true)), "round common snapshot must clear Star Coil boss slow ownership")
	_expect(common.has("lingpet_star_coil_boss_slow_multiplier") and is_equal_approx(float(common.get("lingpet_star_coil_boss_slow_multiplier", 0.0)), 1.0), "round common snapshot must restore Star Coil slow multiplier")
	_expect(common.has("lingpet_star_coil_block_boss_dash") and not bool(common.get("lingpet_star_coil_block_boss_dash", true)), "round common snapshot must clear Star Coil boss dash block")
	_expect(common.has("lingpet_star_coil_freeze_boss_skill_cd") and not bool(common.get("lingpet_star_coil_freeze_boss_skill_cd", true)), "round common snapshot must clear Star Coil boss skill cooldown freeze")


func _verify_catalog_dispatcher_and_levels() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_star_coil_skill.gd"), "Star Coil skill module should exist")
	_expect(LingpetSkillDispatcher.is_supported_kind("star_coil"), "dispatcher should mark star_coil as supported")
	_expect(LingpetSkillDispatcher.is_star_coil(SKILL_ID), "dispatcher helper should recognize Orosha Star Coil")
	_expect(LingpetSkillDispatcher.has_exclusive_resource_class(SKILL_ID, LingpetSkillDispatcher.RESOURCE_CLASS_POS_OVERRIDE), "Star Coil should reserve the companion position override resource")

	var expected_cooldowns := [40.0, 35.0, 30.0, 30.0, 30.0]
	var expected_durations := [1.5, 2.0, 2.5, 3.0, 3.5]
	for index in range(expected_cooldowns.size()):
		var level := index + 1
		var skill: Dictionary = LingpetCatalog.get_active_skill("orosha", SKILL_ID, level)
		_expect(str(skill.get("id", "")) == SKILL_ID, "Orosha active pool should expose Star Coil at Lv.%d" % level)
		_expect(str(skill.get("runtime_kind", "")) == "star_coil", "Star Coil should use star_coil runtime kind at Lv.%d" % level)
		_expect(str(skill.get("name", "")) == "별똬리", "Star Coil should use the requested Korean display name")
		_expect(bool(skill.get("cooldown_by_level_authoritative", false)), "Star Coil cooldown_by_level should be authoritative")
		_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), expected_cooldowns[index]), "Star Coil cooldown should flatten by level")
		_expect(is_equal_approx(float(skill.get("slow_duration", 0.0)), expected_durations[index]), "Star Coil slow duration should flatten by level")
		_expect(is_equal_approx(float(skill.get("slow_multiplier", 0.0)), 0.4), "Star Coil slow multiplier should stay 0.4")
	_expect(str(LingpetCatalog.get_active_skill("orosha", SKILL_ID, 5).get("card_texture_path", "")) == CARD_PATH, "Star Coil card path should be reserved for S0 art")
	_expect(str(LingpetCatalog.get_active_skill("orosha", SKILL_ID, 5).get("icon_texture_path", "")) == ICON_PATH, "Star Coil icon path should be reserved for S0 art")


func _verify_can_arm_has_no_ball_descending_gate() -> void:
	var skill := LingpetStarCoilSkill.new()
	var params := _launch_context(FakeOwner.new(), 1)
	params["ball_vel"] = Vector2(0.0, -8.0)
	_expect(bool(skill.can_arm(params)), "Star Coil should arm during upward ball motion")
	params["ball_vel"] = Vector2(0.0, 8.0)
	_expect(bool(skill.can_arm(params)), "Star Coil should arm during downward ball motion too")
	params["ball_active"] = false
	_expect(not bool(skill.can_arm(params)), "Star Coil should not arm while the ball is inactive")


func _verify_fsm_reaches_bind_and_slow_owner() -> void:
	var owner := FakeOwner.new()
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 5)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil should launch")
	_expect(bool(skill.has_companion_position_override()), "Star Coil should move the Orosha companion body, not a separate projectile")
	_expect(not bool(skill.is_projectile_active()), "Star Coil should not expose a separate projectile as active")
	_expect(skill.get_companion_position_override(Vector2(-99.0, -99.0)) != Vector2(-99.0, -99.0), "Star Coil should expose a live companion body override position")
	_expect(_advance_until_phase(skill, owner, context, "bind", 240), "Star Coil should reach bind phase")
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(bool(snapshot.get("star_coil_companion_override_active", false)), "Star Coil bind snapshot should report companion override active")
	_expect(skill.get_companion_position_override(Vector2.ZERO) == snapshot.get("star_coil_body_pos", Vector2.INF), "Star Coil override position should follow the FSM body position")
	_expect(bool(owner.lingpet_star_coil_boss_slow_active), "Star Coil bind should write boss slow active")
	_expect(is_equal_approx(float(owner.lingpet_star_coil_boss_slow_multiplier), 0.4), "Star Coil bind should write 0.4 slow multiplier")
	_expect(is_equal_approx(float(snapshot.get("star_coil_bind_duration", 0.0)), 3.5), "Star Coil Lv.5 bind should last 3.5s")
	_expect(str(snapshot.get("star_coil_wall_side", "")) == "left", "Star Coil should select the nearest left wall for this boss position")
	var bind_frame := int(snapshot.get("star_coil_bind_frame", -1))
	_expect(bind_frame >= 0 and bind_frame < 16, "Star Coil bind snapshot should expose a 0..15 body-sheet frame")


func _verify_slow_self_heals_after_cancel_without_owner() -> void:
	var owner := FakeOwner.new()
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 1)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil self-heal scenario should launch")
	_expect(_advance_until_phase(skill, owner, context, "bind", 240), "Star Coil self-heal scenario should reach bind")
	_expect(bool(owner.lingpet_star_coil_boss_slow_active), "Star Coil should have slow active before cancel(null)")
	skill.cancel(null, null)
	_expect(bool(owner.lingpet_star_coil_boss_slow_active), "cancel(null) should leave the last owner value untouched until the next owner update")
	_expect(bool(skill.has_visible_effects()), "cancel(null) should keep a pending owner slow sync visible to the host")
	skill.update(1.0 / 60.0, owner, null, {"ball_active": true})
	_expect(not bool(owner.lingpet_star_coil_boss_slow_active), "Star Coil should self-heal slow flags on the next owner update")
	_expect(is_equal_approx(float(owner.lingpet_star_coil_boss_slow_multiplier), 1.0), "Star Coil self-heal should restore slow multiplier to 1.0")


func _verify_release_crosses_to_opposite_wall() -> void:
	var owner := FakeOwner.new()
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 1)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil release scenario should launch")
	_expect(_advance_until_phase(skill, owner, context, "bind", 240), "Star Coil release scenario should reach bind")
	for _frame in range(320):
		skill.update(1.0 / 60.0, owner, null, context)
		if str(skill.get_snapshot().get("star_coil_phase", "")) == "idle":
			break
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(str(snapshot.get("star_coil_phase", "")) == "idle", "Star Coil should return to idle after bind/cross/descend")
	_expect(not bool(skill.has_companion_position_override()), "Star Coil should release companion position override after returning to idle")
	_expect(not bool(owner.lingpet_star_coil_boss_slow_active), "Star Coil should clear slow after release")
	_expect(str(snapshot.get("star_coil_wall_side", "")) == "left", "Star Coil should remember the launch wall")
	_expect(str(snapshot.get("star_coil_opposite_wall_side", "")) == "right", "Star Coil should cross toward the opposite wall")


func _verify_boss_ai_context_and_motion_slow() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var builder := BattleUpdateBossAiContextBuilder.new()
	owner.lingpet_star_coil_boss_slow_active = true
	owner.lingpet_star_coil_boss_slow_multiplier = 0.4
	var slow_context: Dictionary = builder.build_context(owner, registry)
	_tune_ai_test_context(slow_context)
	_expect(bool(slow_context.get("lingpet_star_coil_boss_slow_active", false)), "boss AI context should include Star Coil slow active")
	_expect(is_equal_approx(float(slow_context.get("lingpet_star_coil_boss_slow_multiplier", 0.0)), 0.4), "boss AI context should include Star Coil slow multiplier")

	owner.lingpet_star_coil_boss_slow_active = false
	owner.lingpet_star_coil_boss_slow_multiplier = 1.0
	var base_context: Dictionary = builder.build_context(owner, registry)
	_tune_ai_test_context(base_context)
	var base_result: Dictionary = BossAiState.new().update(1.0 / 60.0, owner.boss_pos, 0.0, base_context)
	var slow_result: Dictionary = BossAiState.new().update(1.0 / 60.0, owner.boss_pos, 0.0, slow_context)
	var base_vel := absf(float(base_result.get("boss_vel", 0.0)))
	var slow_vel := absf(float(slow_result.get("boss_vel", 0.0)))
	_expect(base_vel > 0.01, "boss AI baseline velocity should be non-zero for the slow comparison")
	_expect(slow_vel > 0.0, "Star Coil should slow boss movement without freezing it")
	_expect(absf(slow_vel - base_vel * 0.4) <= 0.02, "Star Coil boss AI velocity should be approximately 0.4x baseline")


func _verify_star_coil_level_tier_cc_policy() -> void:
	_verify_lv1_2_dash_breaks_bind()
	_verify_lv3_plus_blocks_boss_dash()
	_verify_lv5_freezes_boss_skill_cooldown()


func _verify_lv1_2_dash_breaks_bind() -> void:
	for level in [1, 2]:
		var owner := FakeOwner.new()
		var boss_ai := FakeBossAiState.new()
		var registry := FakeRegistry.new(boss_ai)
		var skill := LingpetStarCoilSkill.new()
		var context := _launch_context(owner, level)
		_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil Lv.%d dash-break scenario should launch" % level)
		_expect(_advance_until_phase_with_registry(skill, owner, registry, context, "bind", 240), "Star Coil Lv.%d dash-break scenario should reach bind" % level)
		_expect(bool(owner.lingpet_star_coil_boss_slow_active), "Star Coil Lv.%d should slow while bind holds before dash" % level)
		_expect(not bool(owner.lingpet_star_coil_block_boss_dash), "Star Coil Lv.%d should not block boss dash" % level)
		boss_ai.boss_dash_active = true
		skill.update(1.0 / 60.0, owner, registry, context)
		var snapshot: Dictionary = skill.get_snapshot()
		_expect(str(snapshot.get("star_coil_phase", "")) == "cross", "Star Coil Lv.%d should release into cross when the boss dashes during bind" % level)
		_expect(not bool(snapshot.get("star_coil_bind_active", false)), "Star Coil Lv.%d bind should be broken by boss dash" % level)
		_expect(not bool(owner.lingpet_star_coil_boss_slow_active), "Star Coil Lv.%d dash break should clear boss slow" % level)
		_expect(not bool(owner.lingpet_star_coil_block_boss_dash), "Star Coil Lv.%d dash break should leave dash block false" % level)
		_expect(not bool(owner.lingpet_star_coil_freeze_boss_skill_cd), "Star Coil Lv.%d dash break should leave boss skill cooldown freeze false" % level)


func _verify_lv3_plus_blocks_boss_dash() -> void:
	for level in [3, 4, 5]:
		var owner := FakeOwner.new()
		var boss_ai := FakeBossAiState.new()
		var registry := FakeRegistry.new(boss_ai)
		var skill := LingpetStarCoilSkill.new()
		var context := _launch_context(owner, level)
		_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil Lv.%d dash-block scenario should launch" % level)
		_expect(_advance_until_phase_with_registry(skill, owner, registry, context, "bind", 240), "Star Coil Lv.%d dash-block scenario should reach bind" % level)
		boss_ai.boss_dash_active = true
		skill.update(1.0 / 60.0, owner, registry, context)
		var snapshot: Dictionary = skill.get_snapshot()
		_expect(str(snapshot.get("star_coil_phase", "")) == "bind", "Star Coil Lv.%d should keep binding even if a fake boss dash flag appears" % level)
		_expect(bool(owner.lingpet_star_coil_block_boss_dash), "Star Coil Lv.%d should write dash-block owner flag while binding" % level)
		_expect(bool(snapshot.get("star_coil_block_boss_dash", false)), "Star Coil Lv.%d snapshot should expose dash-block while binding" % level)
		_expect(bool(owner.lingpet_star_coil_freeze_boss_skill_cd) == (level >= 5), "Star Coil Lv.%d cooldown-freeze owner flag should match Lv.5 threshold" % level)

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var builder := BattleUpdateBossAiContextBuilder.new()
	owner.lingpet_star_coil_block_boss_dash = true
	var blocked_context: Dictionary = builder.build_context(owner, registry)
	_tune_dash_start_test_context(blocked_context)
	_expect(bool(blocked_context.get("lingpet_star_coil_block_boss_dash", false)), "boss AI context should forward Star Coil dash block")
	var blocked_state := BossAiState.new()
	var blocked_started := bool(blocked_state.call("_try_start_boss_dash", owner.boss_pos, blocked_context, 650.0, true))
	_expect(not blocked_started, "boss AI should refuse to start dash while Star Coil Lv.3+ dash block is active")

	owner.lingpet_star_coil_block_boss_dash = false
	var baseline_context: Dictionary = builder.build_context(owner, registry)
	_tune_dash_start_test_context(baseline_context)
	var baseline_state := BossAiState.new()
	var baseline_started := bool(baseline_state.call("_try_start_boss_dash", owner.boss_pos, baseline_context, 650.0, true))
	_expect(baseline_started, "boss AI dash test baseline should be able to force-start a dash without Star Coil block")


func _verify_lv5_freezes_boss_skill_cooldown() -> void:
	var owner := FakeOwner.new()
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 5)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil Lv.5 cooldown-freeze scenario should launch")
	_expect(_advance_until_phase(skill, owner, context, "bind", 240), "Star Coil Lv.5 cooldown-freeze scenario should reach bind")
	_expect(bool(owner.lingpet_star_coil_freeze_boss_skill_cd), "Star Coil Lv.5 should write boss skill cooldown freeze while binding")
	_expect(bool(skill.get_snapshot().get("star_coil_freeze_boss_skill_cd", false)), "Star Coil Lv.5 snapshot should expose boss skill cooldown freeze")

	var effects_context: Dictionary = BattleUpdateEffectsOwnerContextBuilder.new().build_context(owner, FakeRegistry.new(), "smasher", {})
	_expect(bool(effects_context.get("lingpet_star_coil_freeze_boss_skill_cd", false)), "effects owner context should forward Star Coil Lv.5 cooldown freeze")
	BattleEffectsUpdateController.new().update(1.0 / 60.0, effects_context, {})
	_expect(bool(effects_context.get("active_item_boss_skill_cooldown_paused", false)), "effects controller should OR Star Coil Lv.5 into the shared boss skill cooldown pause flag")

	var owner_lv4 := FakeOwner.new()
	var skill_lv4 := LingpetStarCoilSkill.new()
	var context_lv4 := _launch_context(owner_lv4, 4)
	_expect(bool(skill_lv4.launch(Vector2(380.0, 650.0), owner_lv4, context_lv4)), "Star Coil Lv.4 cooldown-freeze guard scenario should launch")
	_expect(_advance_until_phase(skill_lv4, owner_lv4, context_lv4, "bind", 240), "Star Coil Lv.4 cooldown-freeze guard scenario should reach bind")
	_expect(not bool(owner_lv4.lingpet_star_coil_freeze_boss_skill_cd), "Star Coil Lv.4 should not freeze boss skill cooldown")


func _verify_host_wiring_and_cleanup_guards() -> void:
	var owner := FakeOwner.new()
	var host := LingpetSkillRuntimeHost.new()
	var context := _launch_context(owner, 5)
	_expect(bool(host.can_arm(SKILL_ID, context)), "host should delegate Star Coil can_arm")
	_expect(bool(host.launch(SKILL_ID, Vector2(380.0, 650.0), owner, context)), "host should launch Star Coil")
	_expect(bool(host.has_companion_position_override(SKILL_ID)), "host should expose Star Coil companion position override immediately after launch")
	var override_owner: Dictionary = host.get_active_position_override_owner([SKILL_ID], Vector2.ZERO)
	_expect(bool(override_owner.get("has", false)), "host active override owner should select Star Coil")
	_expect(str(override_owner.get("skill_id", "")) == SKILL_ID, "host active override owner should report Star Coil skill id")
	_expect(_advance_host_until_phase(host, owner, context, "bind", 240), "host should update Star Coil to bind")
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("star_coil_bind_active", false)), "host snapshot should merge Star Coil bind state")
	_expect(bool(snapshot.get("star_coil_companion_override_active", false)), "host snapshot should merge Star Coil companion override state")
	_expect(host.get_companion_position_override(SKILL_ID, Vector2.ZERO) == snapshot.get("star_coil_body_pos", Vector2.INF), "host override position should follow Star Coil body position")
	var bind_sheet_state: Dictionary = host.get_companion_bind_sheet_state(SKILL_ID)
	_expect(bool(bind_sheet_state.get("active", false)), "host bind-sheet state should be active while Star Coil binds (orosha body sheet)")
	_expect(int(bind_sheet_state.get("frame", -1)) >= 0, "host bind-sheet state should expose a sheet frame")
	_expect(host.get_companion_bind_sheet_state("not_a_real_skill").is_empty(), "host bind-sheet state must be empty for a non-Star-Coil skill")
	_expect(bool(host.is_launch_blocked(SKILL_ID)), "host should block another Star Coil launch while active")
	_expect(bool(owner.lingpet_star_coil_boss_slow_active), "host-driven Star Coil should write owner slow")
	host.reset(null, null)
	_expect(not bool(host.has_companion_position_override(SKILL_ID)), "host reset should release Star Coil companion position override")
	_expect(bool(owner.lingpet_star_coil_boss_slow_active), "host reset without owner should preserve pending Star Coil cleanup")
	host.update(1.0 / 60.0, owner, null, SKILL_ID, {"ball_active": true})
	_expect(not bool(owner.lingpet_star_coil_boss_slow_active), "host should allow Star Coil deferred slow cleanup on next update")
	_verify_source_does_not_script_boss()


func _launch_context(owner: FakeOwner, level: int) -> Dictionary:
	var skill: Dictionary = LingpetCatalog.get_active_skill("orosha", SKILL_ID, level)
	return {
		"companion_pos": Vector2(380.0, 650.0),
		"companion_radius": 32.0,
		"companion_visible": true,
		"active_skill_id": SKILL_ID,
		"active_skill_level": level,
		"slow_duration": float(skill.get("slow_duration", -1.0)),
		"slow_multiplier": float(skill.get("slow_multiplier", -1.0)),
		"ball_active": owner.ball_active,
		"ball_pos": owner.ball_pos,
		"ball_vel": owner.ball_vel,
		"boss_pos": owner.boss_pos,
		"boss_paddle_width": owner.boss_paddle_width,
		"boss_hitbox_height": owner.boss_hitbox_height,
	}


func _advance_until_phase(skill: Object, owner: FakeOwner, context: Dictionary, expected_phase: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		skill.update(1.0 / 60.0, owner, null, context)
		if str(skill.get_snapshot().get("star_coil_phase", "")) == expected_phase:
			return true
	return false


func _advance_until_phase_with_registry(skill: Object, owner: FakeOwner, registry: Object, context: Dictionary, expected_phase: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		skill.update(1.0 / 60.0, owner, registry, context)
		if str(skill.get_snapshot().get("star_coil_phase", "")) == expected_phase:
			return true
	return false


func _advance_host_until_phase(host: Object, owner: FakeOwner, context: Dictionary, expected_phase: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		host.update(1.0 / 60.0, owner, null, SKILL_ID, context)
		if str(host.get_snapshot().get("star_coil_phase", "")) == expected_phase:
			return true
	return false


func _tune_ai_test_context(context: Dictionary) -> void:
	context["waiting_for_serve"] = false
	context["player_serves"] = true
	context["ball_active"] = true
	context["ball_pos"] = Vector2(520.0, 300.0)
	context["ball_vel"] = Vector2(0.0, -8.0)
	context["boss_dash_enabled"] = false
	context["boss_dash_trigger_chance"] = 0.0
	context["boss_mistake_chance"] = 0.0
	context["boss_mistake_error_min"] = 0.0
	context["boss_mistake_error_max"] = 0.0


func _tune_dash_start_test_context(context: Dictionary) -> void:
	context["waiting_for_serve"] = false
	context["player_serves"] = true
	context["ball_active"] = true
	context["ball_pos"] = Vector2(650.0, 120.0)
	context["ball_vel"] = Vector2(0.0, -12.0)
	context["boss_dash_enabled"] = true
	context["boss_dash_trigger_chance"] = 1.0
	context["boss_dash_max_tokens"] = 1
	context["boss_dash_chain_enabled"] = false
	context["active_item_banana_slip_active"] = false
	context["stage2_monkey_banana_boss_slip_active"] = false
	context["lingpet_banana_slice_boss_slip_active"] = false
	context["stage1_dalji_whip_active"] = false
	context["stage1_dalji_whip_deactivation_active"] = false
	context["active_item_flare_confusion_active"] = false


func _verify_source_does_not_script_boss() -> void:
	var file := FileAccess.open("res://scripts/lingpet/lingpet_star_coil_skill.gd", FileAccess.READ)
	if file == null:
		_expect(false, "Star Coil source should be readable for guard checks")
		return
	var source := file.get_as_text()
	_expect(source.find("skip_ball_motion_step") < 0, "Star Coil should not pause ball motion")
	_expect(source.find("owner.set(\"boss_pos\"") < 0, "Star Coil should not script boss_pos")
	_expect(source.find("owner.set(\"boss_vel\"") < 0, "Star Coil should not script boss_vel")
	_expect(source.find("func _draw_projectile") < 0, "Star Coil should not draw a separate projectile body")


func _verify_bind_render_integration() -> void:
	var renderer := LingpetCompanionRenderer.new()
	var placeholder := PlaceholderTexture2D.new()
	placeholder.size = Vector2(2048.0, 2048.0)
	var bind_config := {
		"casting_windup": false,
		"bind_sheet_active": true,
		"bind_sheet_texture": placeholder,
		"bind_sheet_frame": 5,
		"companion_star_coil_bind_cols": 4,
		"companion_star_coil_bind_rows": 4,
		"companion_star_coil_bind_frame_count": 16,
		"companion_distance_roll_enabled": 1.0,
		"distance_roll_source_texture": placeholder,
	}
	var bind_state: Dictionary = renderer.resolve_companion_sprite_state_for_tests(bind_config)
	_expect(bool(bind_state.get("bind_sheet", false)), "renderer should pick the orosha bind sheet while binding")
	_expect(not bool(bind_state.get("distance_roll", false)), "bind sheet must take priority over the rolling-hoop sprite (no double-draw)")
	_expect(int(bind_state.get("bind_frame", -1)) == 5, "renderer should forward the bind sheet frame")
	_expect(int(bind_state.get("bind_cols", 0)) == 4, "renderer should forward the bind grid cols")
	var roll_config := bind_config.duplicate()
	roll_config["bind_sheet_active"] = false
	var roll_state: Dictionary = renderer.resolve_companion_sprite_state_for_tests(roll_config)
	_expect(not bool(roll_state.get("bind_sheet", false)), "renderer must NOT bind when not binding")
	_expect(bool(roll_state.get("distance_roll", false)), "renderer should fall back to the rolling-hoop sprite when not binding")


func _verify_roll_uses_path_distance() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	# Vertical wall climb (x≈0): the old x-only code returned 0 (no roll); the path-distance fix must advance.
	var vertical := float(runtime.signed_roll_distance_for_tests(Vector2(0.0, -10.0)))
	_expect(absf(vertical) >= 9.99, "vertical climb must still roll (path distance, not x-only)")
	# Horizontal travel keeps the original signed-x behavior exactly.
	var horizontal := float(runtime.signed_roll_distance_for_tests(Vector2(12.0, 0.0)))
	_expect(is_equal_approx(horizontal, 12.0), "horizontal roll distance should equal moved.x (unchanged)")


func _verify_bind_plays_and_stops_audio() -> void:
	# OUTCOME seal: the BIND constrict squish plays exactly once when the bind starts
	# and is stopped once when the bind releases (so the ~6.5s clip never trails into
	# the roll-away). Drives the real update path WITH a recording game_audio double.
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeAudioRegistry.new(audio)
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 1)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil audio scenario should launch")

	var reached_bind := false
	for _frame in range(240):
		skill.update(1.0 / 60.0, owner, registry, context)
		if str(skill.get_snapshot().get("star_coil_phase", "")) == "bind":
			reached_bind = true
			break
	_expect(reached_bind, "Star Coil audio scenario should reach bind")
	_expect(audio.bind_play_count == 1, "Star Coil should play the bind squish exactly once when the bind begins")
	_expect(audio.bind_stop_count == 0, "Star Coil bind squish should not stop while the bind is still holding")

	# Stay in bind a few more frames: still a single play, no per-frame replay.
	for _frame in range(10):
		if str(skill.get_snapshot().get("star_coil_phase", "")) != "bind":
			break
		skill.update(1.0 / 60.0, owner, registry, context)
	_expect(audio.bind_play_count == 1, "Star Coil bind squish must be one-shot, not re-played every bind frame")

	# Run until release returns to idle.
	for _frame in range(400):
		skill.update(1.0 / 60.0, owner, registry, context)
		if str(skill.get_snapshot().get("star_coil_phase", "")) == "idle":
			break
	_expect(str(skill.get_snapshot().get("star_coil_phase", "")) == "idle", "Star Coil audio scenario should return to idle after release")
	_expect(audio.bind_stop_count == 1, "Star Coil should stop the bind squish exactly once when the bind releases")

	# Mid-bind ball loss must also stop the squish (retire path).
	var owner_retire := FakeOwner.new()
	var audio_retire := FakeAudio.new()
	var registry_retire := FakeAudioRegistry.new(audio_retire)
	var skill_retire := LingpetStarCoilSkill.new()
	var context_retire := _launch_context(owner_retire, 5)
	_expect(bool(skill_retire.launch(Vector2(380.0, 650.0), owner_retire, context_retire)), "Star Coil retire scenario should launch")
	var reached_retire_bind := false
	for _frame in range(240):
		skill_retire.update(1.0 / 60.0, owner_retire, registry_retire, context_retire)
		if str(skill_retire.get_snapshot().get("star_coil_phase", "")) == "bind":
			reached_retire_bind = true
			break
	_expect(reached_retire_bind, "Star Coil retire scenario should reach bind")
	_expect(audio_retire.bind_play_count == 1, "Star Coil retire scenario should have played the bind squish")
	context_retire["ball_active"] = false
	skill_retire.update(1.0 / 60.0, owner_retire, registry_retire, context_retire)
	_expect(audio_retire.bind_stop_count == 1, "Star Coil should stop the bind squish when the ball goes inactive mid-bind")

	# cancel(owner, registry) mid-bind must stop too.
	var owner_cancel := FakeOwner.new()
	var audio_cancel := FakeAudio.new()
	var registry_cancel := FakeAudioRegistry.new(audio_cancel)
	var skill_cancel := LingpetStarCoilSkill.new()
	var context_cancel := _launch_context(owner_cancel, 5)
	_expect(bool(skill_cancel.launch(Vector2(380.0, 650.0), owner_cancel, context_cancel)), "Star Coil cancel scenario should launch")
	for _frame in range(240):
		skill_cancel.update(1.0 / 60.0, owner_cancel, registry_cancel, context_cancel)
		if str(skill_cancel.get_snapshot().get("star_coil_phase", "")) == "bind":
			break
	_expect(audio_cancel.bind_play_count == 1, "Star Coil cancel scenario should have played the bind squish")
	skill_cancel.cancel(owner_cancel, registry_cancel)
	_expect(audio_cancel.bind_stop_count == 1, "Star Coil cancel(owner, registry) mid-bind should stop the bind squish")


func _verify_move_audio_loops_during_travel() -> void:
	# OUTCOME seal: the starmoving loop starts ONCE when Orosha begins traveling, stays on
	# through continuous roll/climb (no per-frame restart), stops when the bind begins, and
	# stops on a mid-travel ball loss (retire).
	# 반증: drop the `_move_audio_active` guard (start every frame) and play_count > 1 FAILS.
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeAudioRegistry.new(audio)
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 5)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil move-audio scenario should launch")

	var rolled_frames := 0
	for _frame in range(60):
		skill.update(1.0 / 60.0, owner, registry, context)
		var phase := str(skill.get_snapshot().get("star_coil_phase", ""))
		if phase == "bind":
			break
		if phase == "roll_to_wall" or phase == "climb" or phase == "lunge":
			rolled_frames += 1
	_expect(rolled_frames > 0, "Star Coil should spend frames traveling before bind")
	_expect(audio.move_play_count == 1, "starmoving loop should start exactly once for a continuous travel (no per-frame restart)")
	_expect(audio.move_stop_count == 0, "starmoving loop should not stop while still traveling")

	var reached_bind := false
	for _frame in range(240):
		skill.update(1.0 / 60.0, owner, registry, context)
		if str(skill.get_snapshot().get("star_coil_phase", "")) == "bind":
			reached_bind = true
			break
	_expect(reached_bind, "Star Coil move-audio scenario should reach bind")
	_expect(audio.move_stop_count == 1, "starmoving loop should stop once when the bind begins")

	var owner_retire := FakeOwner.new()
	var audio_retire := FakeAudio.new()
	var registry_retire := FakeAudioRegistry.new(audio_retire)
	var skill_retire := LingpetStarCoilSkill.new()
	var context_retire := _launch_context(owner_retire, 1)
	_expect(bool(skill_retire.launch(Vector2(380.0, 650.0), owner_retire, context_retire)), "Star Coil retire move-audio scenario should launch")
	skill_retire.update(1.0 / 60.0, owner_retire, registry_retire, context_retire)
	_expect(audio_retire.move_play_count == 1, "starmoving loop should be playing during early travel")
	context_retire["ball_active"] = false
	skill_retire.update(1.0 / 60.0, owner_retire, registry_retire, context_retire)
	_expect(audio_retire.move_stop_count == 1, "starmoving loop should stop when the ball goes inactive mid-travel")


func _verify_continuous_star_emission_while_rolling() -> void:
	# OUTCOME seal: while Orosha is rolling/climbing (pre-bind), it must KEEP spraying
	# stars off its body — not just emit the one launch burst and go bare. After 60
	# frames the launch burst (life <= ~44 frames) has fully expired, so a sustained
	# spark count can only come from the per-frame rolling emission.
	# 반증: with `_emit_roll_stars` removed the count collapses to ~0 here and this FAILS.
	var owner := FakeOwner.new()
	var skill := LingpetStarCoilSkill.new()
	var context := _launch_context(owner, 3)
	_expect(bool(skill.launch(Vector2(380.0, 650.0), owner, context)), "Star Coil emission scenario should launch")
	var phase := ""
	for _frame in range(60):
		skill.update(1.0 / 60.0, owner, null, context)
		phase = str(skill.get_snapshot().get("star_coil_phase", ""))
		if phase == "bind":
			break
	var snapshot: Dictionary = skill.get_snapshot()
	phase = str(snapshot.get("star_coil_phase", ""))
	_expect(
		phase == "roll_to_wall" or phase == "climb" or phase == "lunge",
		"emission scenario should still be rolling/climbing after 60 frames (got '%s')" % phase
	)
	_expect(
		int(snapshot.get("star_coil_spark_count", 0)) >= 10,
		"rolling Orosha should continuously spray stars from its body (launch burst alone would have decayed)"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
