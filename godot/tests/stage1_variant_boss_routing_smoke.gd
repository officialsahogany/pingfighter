extends SceneTree

const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const DefeatSettlementScreen := preload("res://scripts/core/defeat_settlement_screen.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const ScoreboardOverlayHeaderRenderer := preload("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const Stage1PododaejangArrestRopeSkillState := preload("res://scripts/stages/stage1/stage1_pododaejang_arrest_rope_skill_state.gd")
const Stage1PododaejangBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_cooldown_state.gd")
const Stage1PododaejangBossSkillHudAssets := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_assets.gd")
const Stage1PododaejangBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_renderer.gd")
const Stage1PododaejangPatrolGuardsSkillState := preload("res://scripts/stages/stage1/stage1_pododaejang_patrol_guards_skill_state.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var updates := 0
	var whip_calls := 0
	var whipcrack_calls := 0
	var paddle_hit_calls := 0

	func update(_delta: float) -> void:
		updates += 1

	func sync_dash_delay(_active: bool) -> void:
		pass

	func play_whip() -> void:
		whip_calls += 1

	func play_whipcrack() -> void:
		whipcrack_calls += 1

	func play_paddle_hit() -> void:
		paddle_hit_calls += 1


class FakeImpactEffects:
	extends RefCounted

	var explosions := 0
	var particles := 0

	func update(_delta: float) -> void:
		pass

	func create_energy_explosion(_pos: Vector2, _scale: float, _intensity: float) -> void:
		explosions += 1

	func spawn_paddle_hit_particles(_pos: Vector2, _is_boss: bool, _normal: Vector2, _scale: float) -> void:
		particles += 1


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var stage1_boss_variant := "podo"
	var stage_boss_variant := ""
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var ball_active := true
	var ball_pos := Vector2(380.0, 400.0)
	var ball_vel := Vector2(3.0, 4.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var boss_pos := Vector2(330.0, 40.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var victory_loot_phase_active := false
	var victory_highlight_active := false


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeControlContextBuilder:
	extends RefCounted

	func build_player_control_config(_character_type: String) -> Dictionary:
		return {
			"paddle_width": 155.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 9.0,
			"paddle_accel": 1.2,
			"paddle_decel": 1.0,
			"paddle_turn_decel": 1.4,
		}


func _init() -> void:
	LanguageSettings.set_test_locale_override("ko")
	_verify_pododaejang_production_combat_routes()
	_verify_arrest_rope_reverse_legs()
	_verify_hud_assets_and_names()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("stage1_variant_boss_routing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pododaejang_production_combat_routes() -> void:
	var patrol := Stage1PododaejangPatrolGuardsSkillState.new()
	var rope := Stage1PododaejangArrestRopeSkillState.new()
	var cooldown := Stage1PododaejangBossSkillCooldownState.new()
	var audio := FakeAudio.new()
	var impacts := FakeImpactEffects.new()
	patrol.set_rng_seed_for_test(4417)
	var deps := {
		"stage1_pododaejang_patrol_guards_skill_state": patrol,
		"stage1_pododaejang_arrest_rope_skill_state": rope,
		"stage1_pododaejang_boss_skill_cooldown_state": cooldown,
		"audio": audio,
		"impact_effects": impacts,
	}
	var context := _podo_context()
	var effects := BattleEffectsUpdateController.new()

	# Production effects update: 16 seconds charges and activates Patrol Guards;
	# another 4 seconds makes Arrest Rope ready without advancing gameplay RNG.
	effects.update(16.0, context, deps)
	_expect(patrol.is_active(), "production effects update should activate Patrol Guards at 16 seconds")
	var guard_context: Dictionary = patrol.get_draw_context()
	var guards: Array = guard_context.get("stage1_pododaejang_patrol_guards", [])
	_expect(guards.size() == 2, "Patrol Guards should spawn exactly two guards")
	_expect(audio.whip_calls == 1, "Patrol Guards activation should play its summon cue once")
	effects.update(4.0, context, deps)
	_expect(cooldown.is_ready("arrest_rope"), "production effects update should ready Arrest Rope at 20 seconds")

	# Production boss-hit handler must consume the ready on-hit skill.
	PaddleBounceBossPostHitHandler.new().apply(
		Vector2(380.0, 60.0),
		Vector2(2.0, -5.0),
		0.0,
		0.0,
		false,
		false,
		false,
		context,
		deps,
		null
	)
	_expect(rope.get_phase() == "throwing", "production boss-hit path should start Arrest Rope")
	_expect(audio.whip_calls == 2, "Arrest Rope throw should play its throw cue")
	effects.update(0.75, context, deps)
	_expect(rope.get_phase() == "bound", "Arrest Rope should bind a player who remains at the snapshotted target")
	_expect(audio.whipcrack_calls == 1, "successful Arrest Rope bind should play its bind cue")

	# Production player-control config must apply only the 0.5 movement penalty.
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.instances["stage1_pododaejang_arrest_rope_skill_state"] = rope
	var control_config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeControlContextBuilder.new()
	)
	_expect_close(float(control_config.get("paddle_speed", 0.0)), 3.0, "bound player speed")
	_expect_close(float(control_config.get("paddle_max_speed", 0.0)), 4.5, "bound player max speed")
	_expect(not bool(control_config.get("horizontal_input_locked", false)), "Arrest Rope must not lock horizontal input")

	# Production ball-motion owner applies a collision response while preserving speed.
	var first_guard: Dictionary = guards[0]
	var scene := {
		"ball_pos": Vector2(float(first_guard.get("x", 0.0)), float(first_guard.get("y", 0.0))),
		"ball_vel": Vector2(3.0, 4.0),
	}
	BallFrameMotionController.new().apply_stage1_pododaejang_patrol_guards(scene, 1.0, context, deps)
	_expect(bool(scene.get("stage1_pododaejang_patrol_guard_hit", false)), "production ball-motion path should detect a guard collision")
	_expect_close((scene.get("ball_vel", Vector2.ZERO) as Vector2).length(), 5.0, "guard collision ball speed")
	_expect(audio.paddle_hit_calls == 1, "guard collision should play one impact cue")
	_expect(impacts.explosions == 1 and impacts.particles == 1, "guard collision should emit both impact effects")

	context["dash_snapshot"] = {"active": true}
	effects.update(1.0 / 60.0, context, deps)
	_expect(rope.get_phase() == "releasing", "a player dash should break a bound Arrest Rope")

	# Patrol Guards is once per round even after expiry, then re-arms on reset.
	patrol.update_and_collide(300.0, {}, context, deps)
	_expect(not patrol.is_active(), "Patrol Guards should expire after 300 frames")
	_expect(not patrol.can_activate(context), "Patrol Guards should not reactivate in the same round")
	patrol.reset_round()
	_expect(patrol.can_activate(context), "round reset should re-arm Patrol Guards")


func _verify_arrest_rope_reverse_legs() -> void:
	var rope := Stage1PododaejangArrestRopeSkillState.new()
	var context := _podo_context()
	_expect(rope.activate_for_test(context), "Arrest Rope test seam should activate in Podo context")
	context["player_pos"] = Vector2(520.0, 650.0)
	rope.update(45.0, context)
	_expect(rope.get_phase() == "miss", "moving away from the snapshotted target should evade Arrest Rope")

	rope.reset_round()
	context = _podo_context()
	context["player_in_smoke"] = true
	_expect(rope.activate_for_test(context), "Arrest Rope should launch before smoke immunity resolves")
	rope.update(45.0, context)
	_expect(rope.get_phase() == "miss", "smoke should make Arrest Rope miss")

	rope.reset_round()
	var dalji_context := _podo_context()
	dalji_context["stage1_boss_variant"] = "dalji"
	_expect(not rope.activate_for_test(dalji_context), "Dalji negative leg must not activate Podo Arrest Rope")
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = "dalji"
	var registry := FakeRegistry.new()
	registry.instances["stage1_pododaejang_arrest_rope_skill_state"] = rope
	var dalji_config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeControlContextBuilder.new()
	)
	_expect_close(float(dalji_config.get("paddle_speed", 0.0)), 6.0, "Dalji unmodified player speed")


func _verify_hud_assets_and_names() -> void:
	var cooldown := Stage1PododaejangBossSkillCooldownState.new()
	var hud_context: Dictionary = cooldown.get_hud_context()
	var skills: Array = hud_context.get("stage1_pododaejang_boss_skill_hud_skills", [])
	_expect(str(hud_context.get("stage1_pododaejang_boss_skill_hud_boss_name", "")) == "포도대장", "Podo HUD should expose the Korean boss name")
	_expect(skills.size() == 2, "Podo HUD should expose both production skills")
	_expect(str((skills[0] as Dictionary).get("name", "")) == "포졸소환", "Podo HUD should name Patrol Guards")
	_expect(str((skills[1] as Dictionary).get("name", "")) == "포승줄", "Podo HUD should name Arrest Rope")
	var layout_context := hud_context.duplicate(true)
	layout_context.merge({
		"view_size": Vector2(1280.0, 750.0),
		"game_offset": Vector2(260.0, 0.0),
		"game_size": Vector2(760.0, 750.0),
		"commando_firearm_panel_rect": Rect2(),
	}, true)
	var layout: Dictionary = Stage1PododaejangBossSkillHudRenderer.new().build_card_layout(layout_context)
	_expect((layout.get("rects", []) as Array).size() == 2, "Podo HUD should lay out two skill cards")
	_verify_png(Stage1PododaejangBossSkillHudAssets.PATROL_GUARDS_SKILLCARD_TEXTURE_PATH, "Patrol Guards skill card")
	_verify_png(Stage1PododaejangBossSkillHudAssets.ARREST_ROPE_SKILLCARD_TEXTURE_PATH, "Arrest Rope skill card")

	var scoreboard := ScoreboardOverlayHeaderRenderer.new()
	var settlement := DefeatSettlementScreen.new()
	for case_value in [
		{"variant": "dalji", "name": "달지"},
		{"variant": "gaksi", "name": "각시탈"},
		{"variant": "podo", "name": "포도대장"},
	]:
		var case: Dictionary = case_value
		var variant: String = str(case.get("variant", ""))
		var expected_name: String = str(case.get("name", ""))
		_expect(
			scoreboard.resolve_boss_name({"current_stage": 1, "stage1_boss_variant": variant, "stage_boss_variant": "cheongringwi"}) == expected_name,
			"scoreboard should resolve Stage 1 %s without reading stage_boss_variant" % variant
		)
		var stage_snapshot: Dictionary = settlement._build_stage_snapshot(1, "cheongringwi", variant)
		_expect(str(stage_snapshot.get("current_boss", "")) == expected_name, "defeat settlement should resolve Stage 1 %s" % variant)
		var later_stage_snapshot: Dictionary = settlement._build_stage_snapshot(2, "", variant)
		_expect(
			(later_stage_snapshot.get("cleared_bosses", []) as Array).has(expected_name),
			"later defeat settlement should preserve cleared Stage 1 %s" % variant
		)

	LanguageSettings.set_test_locale_override("en")
	_expect(
		scoreboard.resolve_boss_name({"current_stage": 1, "stage1_boss_variant": "podo"}) == "Pododaejang",
		"scoreboard boss name should use the language catalog"
	)
	# The invariant is that a non-Stage-1 context IGNORES stage1_boss_variant.
	# Stage 2 now resolves its catalog DEFAULT rather than the old generic "BOSS"
	# label, so assert against the catalog instead of a frozen literal.
	var stage2_default_name: String = LanguageSettings.translate_text(
		str(StageBossVariantCatalog.get_entry(2, "").get("display_name", ""))
	)
	var stage2_resolved_name: String = scoreboard.resolve_boss_name(
		{"current_stage": 2, "stage1_boss_variant": "podo"}
	)
	_expect(
		stage2_resolved_name == stage2_default_name and stage2_resolved_name != "Pododaejang",
		"non-Stage-1 scoreboard must ignore stage1_boss_variant (expected %s, got %s)" % [stage2_default_name, stage2_resolved_name]
	)
	LanguageSettings.set_test_locale_override("ko")


func _verify_png(path: String, label: String) -> void:
	_expect(FileAccess.file_exists(path), "%s source PNG should exist" % label)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "%s source PNG should decode" % label)
	if image != null and not image.is_empty():
		_expect(image.get_size() == Vector2i(408, 120), "%s should keep the runtime 408x120 skill-card crop" % label)
	var texture := load(path)
	_expect(texture is Texture2D, "%s should load through the production Texture2D import path" % label)
	if texture is Texture2D:
		_expect((texture as Texture2D).get_size() == Vector2(408.0, 120.0), "%s imported texture should keep the 408x120 crop" % label)


func _podo_context() -> Dictionary:
	return {
		"current_stage": 1,
		"stage1_boss_variant": "podo",
		"ball_active": true,
		"ball_pos": Vector2(380.0, 400.0),
		"ball_vel": Vector2(3.0, 4.0),
		"ball_size": 28.6,
		"boss_pos": Vector2(330.0, 40.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(330.0, 650.0),
		"player_paddle_size": Vector2(100.0, 50.0),
		"dash_snapshot": {"active": false},
	}


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(absf(actual - expected) <= 0.001, "%s should be %.3f (got %.3f)" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
