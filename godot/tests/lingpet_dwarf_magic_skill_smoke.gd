extends SceneTree

const DwarfMagicSkill := preload("res://scripts/lingpet/lingpet_dwarf_magic_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const PayloadBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")

const SKILL_ID := "orbi_dwarf_magic"

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

	var cast_count := 0
	var hit_count := 0

	func play_lingpet_dwarf_magic_cast() -> void:
		cast_count += 1

	func play_lingpet_dwarf_magic_hit() -> void:
		hit_count += 1

	func play_active_item() -> void:
		pass


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
	_verify_dispatcher_and_catalog()
	_verify_projectile_level_scaling()
	_verify_catalog_tuning_reaches_launch_payload()
	_verify_schema_keys_and_round_reset()
	_verify_hit_publishes_owner_flags_and_contexts()
	_verify_boss_ai_consumes_dwarf_magic_slow()
	_verify_collision_detector_uses_centered_shrink()
	_verify_draw_context_uses_centered_shrink()
	_verify_lingering_particles_do_not_block_recast_after_miss()
	_verify_restore_clears_owner_flags()
	_verify_ownerless_cancel_self_heals_on_next_owner_update()
	_verify_host_routes_and_resets_dwarf_magic()
	_verify_audio_parity_cast_and_hit()

	if _failures.is_empty():
		print("lingpet_dwarf_magic_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("dwarf_magic"), "dwarf_magic should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.is_dwarf_magic(SKILL_ID), "dispatcher should route Orbi's Dwarf Magic to the dwarf_magic runtime")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "orbi_dwarf_magic should resolve to a supported runtime")

	var meta: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not meta.is_empty(), "catalog should expose Dwarf Magic metadata")
	_expect(str(meta.get("runtime_kind", "")) == "dwarf_magic", "Dwarf Magic metadata should use the dwarf_magic runtime kind")
	var lv1: Dictionary = LingpetCatalog.get_active_skill("orbi", SKILL_ID, 1)
	var lv5: Dictionary = LingpetCatalog.get_active_skill("orbi", SKILL_ID, 5)
	_expect(float(lv5.get("shrink_scale", 1.0)) < float(lv1.get("shrink_scale", 1.0)), "higher Dwarf Magic level should shrink the boss more")
	_expect(float(lv5.get("shrink_duration", 0.0)) > float(lv1.get("shrink_duration", 0.0)), "higher Dwarf Magic level should last longer")
	_expect(float(lv5.get("boss_slow_multiplier", 1.0)) < float(lv1.get("boss_slow_multiplier", 1.0)), "higher Dwarf Magic level should slow the boss more")
	_expect(float(lv5.get("proj_speed", 0.0)) > float(lv1.get("proj_speed", 0.0)), "higher Dwarf Magic level should fire a faster projectile")
	_expect(float(lv5.get("proj_homing", 0.0)) > float(lv1.get("proj_homing", 0.0)), "higher Dwarf Magic level should home harder")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "Orbi Dwarf Magic metadata should validate cleanly")
	# Serabi must now be a TWO-active pool — the affinity 2nd-active unlock keys off pool size.
	_expect(LingpetCatalog.get_active_skill_pool("orbi").size() == 2, "Serabi should expose a 2-skill active pool (gravity_accel + dwarf_magic)")


func _verify_projectile_level_scaling() -> void:
	# Lv.1 -> Lv.5: faster projectile AND stronger homing must reach the live skill.
	var lv1 := DwarfMagicSkill.new()
	lv1.launch(Vector2(380.0, 640.0), FakeOwner.new(), {"active_skill_level": 1})
	var lv5 := DwarfMagicSkill.new()
	lv5.launch(Vector2(380.0, 640.0), FakeOwner.new(), {"active_skill_level": 5})
	var s1: Dictionary = lv1.get_snapshot()
	var s5: Dictionary = lv5.get_snapshot()
	_expect(float(s5.get("dwarf_magic_proj_speed", 0.0)) > float(s1.get("dwarf_magic_proj_speed", 0.0)), "Lv.5 should fire a faster projectile than Lv.1")
	_expect(float(s5.get("dwarf_magic_proj_homing", 0.0)) > float(s1.get("dwarf_magic_proj_homing", 0.0)), "Lv.5 should home harder than Lv.1")


func _verify_catalog_tuning_reaches_launch_payload() -> void:
	# The REAL launch path runs the flattened catalog skill through the payload
	# builder whitelist. If a tuning key isn't whitelisted, catalog edits are
	# silently dropped and only the skill's internal fallback table is used.
	var active: Dictionary = LingpetCatalog.get_active_skill("orbi", SKILL_ID, 5)
	var payload: Dictionary = PayloadBuilder.new().build(active, SKILL_ID, 5, Vector2(380.0, 640.0), 32.0, null)
	for key in ["shrink_scale", "shrink_duration", "boss_slow_multiplier", "proj_speed", "proj_homing"]:
		_expect(payload.has(key), "launch payload must carry Dwarf Magic tuning key '%s'" % key)
		_expect(is_equal_approx(float(payload.get(key, -999.0)), float(active.get(key, -998.0))), "launch payload '%s' must equal the flattened catalog value (whitelist drop = catalog edits ignored)" % key)

	# Consumption proof: a payload value DISTINCT from every fallback-table entry
	# must reach the live skill (so a future catalog!=fallback tuning lands).
	var skill := DwarfMagicSkill.new()
	skill.launch(Vector2(380.0, 640.0), FakeOwner.new(), {
		"active_skill_level": 3,
		"shrink_scale": 0.33,
		"shrink_duration": 7.0,
		"boss_slow_multiplier": 0.11,
		"proj_speed": 999.0,
		"proj_homing": 9.0,
	})
	var snap: Dictionary = skill.get_snapshot()
	_expect(is_equal_approx(float(snap.get("dwarf_magic_shrink_target", 0.0)), 0.33), "skill must honor a payload shrink_scale distinct from the fallback table")
	_expect(is_equal_approx(float(snap.get("dwarf_magic_hold_seconds", 0.0)), 7.0), "skill must honor a payload shrink_duration distinct from the fallback table")
	_expect(is_equal_approx(float(snap.get("dwarf_magic_slow_multiplier", 0.0)), 0.11), "skill must honor a payload boss_slow_multiplier distinct from the fallback table")
	_expect(is_equal_approx(float(snap.get("dwarf_magic_proj_speed", 0.0)), 999.0), "skill must honor a payload proj_speed distinct from the fallback table")
	_expect(is_equal_approx(float(snap.get("dwarf_magic_proj_homing", 0.0)), 9.0), "skill must honor a payload proj_homing distinct from the fallback table")


func _verify_schema_keys_and_round_reset() -> void:
	# Owner-Field Schema Trap: every owner.set() key must be declared, or it silently no-ops.
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_dwarf_magic_shrink_active"), "BattleSceneState must declare dwarf magic shrink active")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_dwarf_magic_shrink_scale"), "BattleSceneState must declare dwarf magic shrink scale")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_dwarf_magic_boss_slow_active"), "BattleSceneState must declare dwarf magic boss slow active")
	_expect(BattleSceneState.DEFAULT_VALUES.has("lingpet_dwarf_magic_boss_slow_multiplier"), "BattleSceneState must declare dwarf magic boss slow multiplier")
	_expect(is_equal_approx(float(BattleSceneState.DEFAULT_VALUES.get("lingpet_dwarf_magic_shrink_scale", 0.0)), 1.0), "dwarf magic shrink scale default should be 1.0")
	_expect(is_equal_approx(float(BattleSceneState.DEFAULT_VALUES.get("lingpet_dwarf_magic_boss_slow_multiplier", 0.0)), 1.0), "dwarf magic boss slow multiplier default should be 1.0")
	# Round normalization: no boss shrink/slow ownership may survive a round boundary.
	var common: Dictionary = BallRoundState.new().build_common_snapshot()
	_expect(common.has("lingpet_dwarf_magic_shrink_active") and not bool(common.get("lingpet_dwarf_magic_shrink_active", true)), "round common snapshot must clear dwarf magic shrink ownership")
	_expect(common.has("lingpet_dwarf_magic_shrink_scale") and is_equal_approx(float(common.get("lingpet_dwarf_magic_shrink_scale", 0.0)), 1.0), "round common snapshot must restore dwarf magic shrink scale")
	_expect(common.has("lingpet_dwarf_magic_boss_slow_active") and not bool(common.get("lingpet_dwarf_magic_boss_slow_active", true)), "round common snapshot must clear dwarf magic boss slow ownership")
	_expect(common.has("lingpet_dwarf_magic_boss_slow_multiplier") and is_equal_approx(float(common.get("lingpet_dwarf_magic_boss_slow_multiplier", 0.0)), 1.0), "round common snapshot must restore dwarf magic boss slow multiplier")


func _verify_hit_publishes_owner_flags_and_contexts() -> void:
	var skill: Object = DwarfMagicSkill.new()
	var owner := FakeOwner.new()
	skill.set_force_hit_next_for_tests(true)
	_expect(skill.launch(Vector2(380.0, 640.0), owner, _ctx()), "Dwarf Magic should launch")
	skill.update(1.0 / 60.0, owner)
	_expect(bool(owner.lingpet_dwarf_magic_shrink_active), "Dwarf Magic hit should publish the boss shrink flag")
	_expect(bool(owner.lingpet_dwarf_magic_boss_slow_active), "Dwarf Magic hit should publish the boss slow flag")
	_expect(owner.lingpet_dwarf_magic_shrink_scale <= 1.0 and owner.lingpet_dwarf_magic_shrink_scale >= 0.2, "Dwarf Magic shrink scale should stay in a safe range")
	_expect(is_equal_approx(owner.lingpet_dwarf_magic_boss_slow_multiplier, 0.42), "Dwarf Magic should publish the launched slow multiplier")

	var ai_context: Dictionary = BossAiContextBuilder.new().build_context(owner, FakeRegistry.new())
	_expect(bool(ai_context.get("lingpet_dwarf_magic_boss_slow_active", false)), "boss AI context should receive Dwarf Magic slow active")
	_expect(is_equal_approx(float(ai_context.get("lingpet_dwarf_magic_boss_slow_multiplier", 1.0)), 0.42), "boss AI context should receive Dwarf Magic slow multiplier")

	var ball_context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(float(ball_context.get("boss_collision_shrink_scale", 1.0)) <= 1.0, "ball collision context should receive Dwarf Magic shrink scale")


func _verify_boss_ai_consumes_dwarf_magic_slow() -> void:
	var boss_ai: Object = BossAiState.new()
	var dwarf_only: float = float(boss_ai._get_active_item_slow_multiplier({
		"lingpet_dwarf_magic_boss_slow_active": true,
		"lingpet_dwarf_magic_boss_slow_multiplier": 0.42,
	}))
	_expect(is_equal_approx(dwarf_only, 0.42), "boss AI slow resolver should consume Dwarf Magic's multiplier")
	var dwarf_with_molotov: float = float(boss_ai._get_active_item_slow_multiplier({
		"lingpet_dwarf_magic_boss_slow_active": true,
		"lingpet_dwarf_magic_boss_slow_multiplier": 0.42,
		"active_item_molotov_slow_active": true,
		"active_item_molotov_slow_factor": 0.50,
	}))
	_expect(is_equal_approx(dwarf_with_molotov, 0.42), "Molotov linger should not stack over an active Dwarf Magic boss slow")


func _verify_collision_detector_uses_centered_shrink() -> void:
	var detector: Object = BallMotionCollisionDetector.new()
	var base_context := {
		"hitbox_padding": 5.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_collision_cooldown": 0.0,
	}
	var edge_ball_pos := Vector2(332.0, 40.0)
	var full_hit: Dictionary = detector.check_paddles(edge_ball_pos, Vector2(0.0, -8.0), 10.0, base_context)
	_expect(str(full_hit.get("event", "")) == "boss_paddle", "baseline boss collision should hit the full-width left edge")
	var shrunk_context := base_context.duplicate(true)
	shrunk_context["boss_collision_shrink_scale"] = 0.5
	var shrunk_edge_hit: Dictionary = detector.check_paddles(edge_ball_pos, Vector2(0.0, -8.0), 10.0, shrunk_context)
	_expect(shrunk_edge_hit.is_empty(), "Dwarf Magic shrink should remove the old full-width edge from boss collision")
	var center_hit: Dictionary = detector.check_paddles(Vector2(380.0, 40.0), Vector2(0.0, -8.0), 10.0, shrunk_context)
	_expect(str(center_hit.get("event", "")) == "boss_paddle", "Dwarf Magic shrink should keep centered boss collision active")
	_expect(is_equal_approx(float(center_hit.get("paddle_x", 0.0)), 355.0), "shrunk boss collision should remain centered on the original boss paddle")
	_expect(is_equal_approx(float(center_hit.get("paddle_w", 0.0)), 50.0), "shrunk boss collision should report the effective width")


func _verify_draw_context_uses_centered_shrink() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_dwarf_magic_shrink_active = true
	owner.lingpet_dwarf_magic_shrink_scale = 0.5
	var scene_context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, FakeRegistry.new())
	_expect(is_equal_approx(float(scene_context.get("boss_paddle_shrink_scale", 1.0)), 0.5), "playfield draw context should expose Dwarf Magic boss render shrink")
	_expect(scene_context.get("boss_paddle_size", Vector2.ZERO) == Vector2(100.0, 40.0), "Dwarf Magic render shrink should keep the logical boss paddle size full")
	var actor_context: Dictionary = BattleDrawActorContext.new().build(scene_context, {})
	_expect(actor_context.get("boss_sprite_draw_size", Vector2.ZERO) == Vector2(48.0, 56.0), "actor draw context should scale the boss sprite around the centered paddle")


func _verify_lingering_particles_do_not_block_recast_after_miss() -> void:
	var skill: Object = DwarfMagicSkill.new()
	var owner := FakeOwner.new()
	_expect(skill.launch(Vector2(380.0, 640.0), owner, _ctx()), "Dwarf Magic miss setup should launch")
	skill.update(2.1, owner)
	_expect(skill.get_miss_count_for_tests() == 1, "large-step Dwarf Magic setup should expire as a miss")
	_expect(skill.has_visible_effects(), "Dwarf Magic miss should leave brief dust particles visible")
	_expect(not skill.is_active(), "Dwarf Magic miss dust should not keep the skill logically active")
	_expect(skill.can_arm({"ball_active": true, "companion_visible": true}), "Dwarf Magic miss dust must not block recast")

	var host: Object = LingpetSkillRuntimeHost.new()
	var host_owner := FakeOwner.new()
	_expect(host.launch(SKILL_ID, Vector2(380.0, 640.0), host_owner, _ctx()), "host Dwarf Magic miss setup should launch")
	host.update(2.1, host_owner, FakeRegistry.new(), SKILL_ID, _ctx())
	_expect(not host.is_launch_blocked(SKILL_ID), "host launch block should ignore Dwarf Magic miss dust")
	_expect(host.can_arm(SKILL_ID, {"ball_active": true, "companion_visible": true}), "host can_arm should allow Dwarf Magic recast while only miss dust remains")


func _verify_restore_clears_owner_flags() -> void:
	var skill: Object = DwarfMagicSkill.new()
	var owner := FakeOwner.new()
	skill.set_force_hit_next_for_tests(true)
	skill.launch(Vector2(380.0, 640.0), owner, _ctx())
	skill.update(1.0 / 60.0, owner)
	for _i in range(12):
		skill.update(0.1, owner)
	_expect(not bool(owner.lingpet_dwarf_magic_shrink_active), "Dwarf Magic restore should clear boss shrink active")
	_expect(is_equal_approx(owner.lingpet_dwarf_magic_shrink_scale, 1.0), "Dwarf Magic restore should reset boss shrink scale")
	_expect(not bool(owner.lingpet_dwarf_magic_boss_slow_active), "Dwarf Magic restore should clear boss slow active")
	_expect(is_equal_approx(owner.lingpet_dwarf_magic_boss_slow_multiplier, 1.0), "Dwarf Magic restore should reset boss slow multiplier")


func _verify_ownerless_cancel_self_heals_on_next_owner_update() -> void:
	var skill: Object = DwarfMagicSkill.new()
	var owner := FakeOwner.new()
	skill.set_force_hit_next_for_tests(true)
	skill.launch(Vector2(380.0, 640.0), owner, _ctx())
	skill.update(1.0 / 60.0, owner)
	_expect(bool(owner.lingpet_dwarf_magic_shrink_active), "Dwarf Magic setup should mark the owner before cancel")
	skill.cancel()
	_expect(bool(owner.lingpet_dwarf_magic_shrink_active), "ownerless cancel cannot mutate the previous owner immediately")
	skill.update(0.0, owner)
	_expect(not bool(owner.lingpet_dwarf_magic_shrink_active), "next owner update should self-heal an ownerless Dwarf Magic cancel")
	_expect(not bool(owner.lingpet_dwarf_magic_boss_slow_active), "next owner update should self-heal Dwarf Magic slow")


func _verify_host_routes_and_resets_dwarf_magic() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	_expect(not host.is_launch_blocked(SKILL_ID), "fresh host should not block Dwarf Magic")
	host.set_dwarf_magic_force_hit_next_for_tests(true)
	_expect(host.launch(SKILL_ID, Vector2(380.0, 640.0), owner, _ctx()), "host should launch Dwarf Magic through the dispatcher")
	host.update(1.0 / 60.0, owner, FakeRegistry.new(), SKILL_ID, _ctx())
	_expect(host.is_launch_blocked(SKILL_ID), "Dwarf Magic should block relaunch while its shrink window is active")
	var snap: Dictionary = host.get_snapshot()
	_expect(bool(snap.get("dwarf_magic_shrink_active", false)), "host snapshot should expose Dwarf Magic shrink state")
	host.reset_round(owner, FakeRegistry.new())
	_expect(not bool(owner.lingpet_dwarf_magic_shrink_active), "host round reset should clear Dwarf Magic boss shrink")
	_expect(not bool(owner.lingpet_dwarf_magic_boss_slow_active), "host round reset should clear Dwarf Magic boss slow")


func _verify_audio_parity_cast_and_hit() -> void:
	# Original parity (downtown/hero_skills.py): smallboyshoot on cast, smallboyhit on hit.
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.audio = audio
	var host: Object = LingpetSkillRuntimeHost.new()
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.cast_count == 1, "Dwarf Magic cast feedback should play the dedicated cast cue (smallboyshoot parity)")

	var skill: Object = DwarfMagicSkill.new()
	skill.set_force_hit_next_for_tests(true)
	skill.launch(Vector2(380.0, 640.0), FakeOwner.new(), _ctx())
	skill.update(1.0 / 60.0, FakeOwner.new(), registry)
	_expect(audio.hit_count == 1, "Dwarf Magic boss hit should play the dedicated hit cue (smallboyhit parity)")


func _ctx() -> Dictionary:
	return {
		"active_skill_level": 5,
		"shrink_scale": 0.5,
		"shrink_duration": 0.2,
		"boss_slow_multiplier": 0.42,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
