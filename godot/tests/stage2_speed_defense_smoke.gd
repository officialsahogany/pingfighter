extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const EffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PaddleBounceRallyFeedbackRouter := preload("res://scripts/ball/paddle_bounce_rally_feedback_router.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage2BossActorRenderer := preload("res://scripts/stages/stage2/stage2_boss_actor_renderer.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


class FakeAudio:
	var start_count := 0
	var hit_count := 0
	var block_count := 0
	var paddle_hit_count := 0

	func play_stage2_speed_defense_start() -> void:
		start_count += 1

	func play_stage2_speed_defense_hit() -> void:
		hit_count += 1

	func play_stage2_speed_defense_block() -> void:
		block_count += 1

	func play_paddle_hit(_source_x: float = 380.0) -> void:
		paddle_hit_count += 1


class FakeRegistry:
	var instances := {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class BossDisableDrawSource:
	func get_actor_draw_context() -> Dictionary:
		return {
			"active_item_boss_stun_active": true,
			"active_item_boss_stun_frame": 3,
			"active_item_boss_confusion_active": true,
			"ragnarok_hammer_boss_stun_active": true,
			"ragnarok_hammer_electric_stun_active": true,
			"ragnarok_hammer_boss_knockback_active": true,
		}


class SpeedDefenseProbe:
	extends Node2D

	var renderer: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		renderer.draw(self, {
			"current_stage": 2,
			"boss_pos": Vector2(330.0, 25.0),
			"boss_paddle_size": Vector2(110.0, 18.0),
			"boss_hitbox_height": 40.0,
			"boss_facing": 1,
			"stage2_speed_defense_active": true,
			"stage2_speed_defense_progress": 0.5,
			"stage2_speed_defense_trails": [
				{"center": Vector2(374.0, 76.0), "alpha": 0.55},
				{"center": Vector2(352.0, 76.0), "alpha": 0.32},
			],
		}, Vector2.ZERO)


var probe: SpeedDefenseProbe = null
var frame_count := 0


func _init() -> void:
	var texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/stage2/boss_stage2_speed_imagegen_v4.png")
	_expect(texture != null, "Stage 2 speed defense shield texture should load")
	_expect(texture.get_size().x >= 160.0 and texture.get_size().y >= 80.0, "Stage 2 speed defense texture should be usable")
	var skillcard_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/hud/stage2_speed_defense_skillcard_imagegen_v3.png")
	_expect(skillcard_texture != null, "Stage 2 speed defense skill card texture should load")
	var run_left_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/stage2/stage2_boss_run_left_angled_autosprite_v1_16f.png")
	var run_right_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/stage2/stage2_boss_run_right_angled_autosprite_v1_16f.png")
	var attack_texture: Texture2D = ProjectResourceLoader.load_texture("res://assets/sprites/stage2/stage2_boss_attack_front_paddle_autosprite_v1_16f.png")
	_expect(run_left_texture != null, "Stage 2 angled left run sheet should load")
	_expect(run_right_texture != null, "Stage 2 angled right run sheet should load")
	_expect(attack_texture != null, "Stage 2 front paddle attack sheet should load")
	_expect(run_left_texture.get_size() == Vector2(2048.0, 2048.0), "Stage 2 angled left run sheet should be a 4x4 512px sheet")
	_expect(run_right_texture.get_size() == Vector2(2048.0, 2048.0), "Stage 2 angled right run sheet should be a 4x4 512px sheet")
	_expect(attack_texture.get_size() == Vector2(2048.0, 2048.0), "Stage 2 front paddle attack sheet should be a 4x4 512px sheet")
	var stage2_textures: Dictionary = BattleResources.new().load_all({
		"current_stage": 2,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	_expect(stage2_textures.get("boss_attack_sheet", null) is Texture2D, "Stage 2 resources should expose the attack sheet")
	var sprite_context: Dictionary = EffectsSpriteContextBuilder.new().build_context(stage2_textures, "smasher")
	_expect(bool(sprite_context.get("boss_has_hit_sprite", false)), "Stage 2 attack sheet should arm boss hit animation")
	_expect(int(sprite_context.get("boss_hit_frame_count", 0)) == 16, "Stage 2 attack sheet should animate over 16 hit frames")

	var state: Object = Stage2BossSkillState.new()
	var audio := FakeAudio.new()
	var activation_context := {
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 110.0,
		"boss_hitbox_height": 40.0,
	}
	state._activate_speed_defense(520.0, {"audio": audio}, activation_context)
	_expect(audio.start_count == 1, "Speed defense should play the start sound on activation")
	state.register_boss_hit(Vector2(0.0, 9.0), {"current_stage": 2}, {"audio": audio})
	_expect(audio.hit_count == 1, "Speed defense boss hit should play the dedicated defense hit sound")
	_expect(audio.block_count == 0, "Speed defense boss hit should not layer the block sound")
	var rally_router := PaddleBounceRallyFeedbackRouter.new()
	rally_router.register(
		Vector2(380.0, 65.0),
		Vector2(0.0, 9.0),
		false,
		false,
		{"audio": audio, "stage2_boss_skill_state": state},
		{"current_stage": 2}
	)
	_expect(audio.paddle_hit_count == 0, "Speed defense boss hit should suppress the generic paddle hit sound")
	var ai_context: Dictionary = state.get_boss_ai_context(null)
	_expect(bool(ai_context.get("stage2_speed_defense_active", false)), "Speed defense should expose active AI context")
	_expect(bool(ai_context.get("stage2_speed_defense_status_immunity_active", false)), "Speed defense should expose boss status immunity")
	_expect(is_equal_approx(float(ai_context.get("stage2_speed_defense_speed_multiplier", 0.0)), 1.7), "Speed defense should expose 1.7x boss speed")
	_expect(is_equal_approx(float(ai_context.get("stage2_speed_defense_turn_multiplier", 0.0)), 2.0), "Speed defense should expose 2x turn speed")

	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect(bool(draw_context.get("stage2_speed_defense_active", false)), "Speed defense should expose active draw context")
	_expect(bool(draw_context.get("stage2_speed_defense_status_immunity_active", false)), "Speed defense should expose draw status immunity")
	_expect(Array(draw_context.get("stage2_speed_defense_trails", [])).size() > 0, "Speed defense should seed a boss trail")

	var hud_context: Dictionary = state.get_hud_context(null)
	var skill_ids := []
	for skill in Array(hud_context.get("stage2_boss_skill_hud_skills", [])):
		if skill is Dictionary:
			skill_ids.append(str(skill.get("id", "")))
	_expect(skill_ids.has("speed_defense"), "Stage 2 boss skill HUD should include speed defense")

	var ai := BossAiState.new()
	var base_ai_context := {
		"current_stage": 2,
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"boss_max_speed": 6.3175,
		"ball_active": true,
		"waiting_for_serve": false,
		"player_serves": true,
		"ball_pos": Vector2(110.0, 170.0),
		"ball_vel": Vector2(-8.0, -6.0),
		"ball_impact_boost": 1.0,
	}
	var normal_result: Dictionary = ai.update(1.0 / 60.0, Vector2(330.0, 25.0), 0.0, base_ai_context)
	ai.reset()
	var boosted_context: Dictionary = base_ai_context.duplicate()
	boosted_context.merge(ai_context, true)
	var boosted_result: Dictionary = ai.update(1.0 / 60.0, Vector2(330.0, 25.0), 0.0, boosted_context)
	_expect(abs(float(boosted_result.get("boss_vel", 0.0))) > abs(float(normal_result.get("boss_vel", 0.0))) * 1.5, "Speed defense should boost boss movement")
	_expect_speed_defense_status_immunity(state, base_ai_context, ai_context)
	_expect_speed_defense_duration(activation_context)

	var renderer: Object = Stage2BossActorRenderer.new()
	renderer.prewarm_assets()
	probe = SpeedDefenseProbe.new()
	probe.renderer = renderer
	get_root().add_child(probe)
	probe.queue_redraw()


func _expect_speed_defense_status_immunity(state: Object, base_ai_context: Dictionary, ai_context: Dictionary) -> void:
	var immune_context: Dictionary = base_ai_context.duplicate()
	immune_context["ball_active"] = false
	immune_context["waiting_for_serve"] = true
	immune_context.merge(ai_context, true)
	immune_context["active_item_grenade_stun_active"] = true
	immune_context["active_item_grenade_knockback_active"] = true
	immune_context["active_item_grenade_knockback_vel"] = 38.0
	immune_context["active_item_flare_confusion_active"] = true
	immune_context["ragnarok_hammer_boss_stun_active"] = true
	immune_context["ragnarok_hammer_boss_knockback_active"] = true
	immune_context["ragnarok_hammer_boss_knockback_vel"] = -44.0
	var immune_ai := BossAiState.new()
	immune_ai.start_paddle_hit_knockback(42.0, 36.0, 0.88, true)
	var immune_result: Dictionary = immune_ai.update(1.0 / 60.0, Vector2(330.0, 25.0), 0.0, immune_context)
	_expect(abs(float(immune_result.get("boss_vel", 0.0))) < 0.01, "Speed defense should ignore stun, confusion, and knockback velocity")
	_expect(immune_ai.paddle_hit_knockback_timer <= 0.0, "Speed defense should clear pending paddle-hit knockback")

	var registry := FakeRegistry.new()
	registry.instances["stage2_boss_skill_state"] = state
	var active_item_runtime := ActiveItemThrowController.new()
	active_item_runtime.grenade_boss_stun_timer_frames = 60.0
	active_item_runtime.grenade_boss_knockback_timer_frames = 60.0
	active_item_runtime.grenade_boss_knockback_vel = 25.0
	active_item_runtime.flare_boss_confused_timer_frames = 60.0
	active_item_runtime._clear_boss_disable_effects_if_stage2_speed_defense(registry)
	_expect(active_item_runtime.grenade_boss_stun_timer_frames <= 0.0, "Speed defense should clear active-item boss stun")
	_expect(active_item_runtime.grenade_boss_knockback_timer_frames <= 0.0, "Speed defense should clear active-item boss knockback")
	_expect(abs(active_item_runtime.grenade_boss_knockback_vel) <= 0.01, "Speed defense should zero active-item boss knockback velocity")
	_expect(active_item_runtime.flare_boss_confused_timer_frames <= 0.0, "Speed defense should clear flare confusion")

	var mythic_item_runtime := MythicItemRuntime.new()
	mythic_item_runtime.ragnarok_boss_stun_timer_frames = 60.0
	mythic_item_runtime.ragnarok_boss_knockback_timer_frames = 60.0
	mythic_item_runtime.ragnarok_boss_knockback_vel = -25.0
	mythic_item_runtime.ragnarok_boss_electric_drift_vel = 0.36
	mythic_item_runtime.update(null, registry, 1.0 / 60.0)
	_expect(mythic_item_runtime.ragnarok_boss_stun_timer_frames <= 0.0, "Speed defense should clear Ragnarok stun")
	_expect(mythic_item_runtime.ragnarok_boss_knockback_timer_frames <= 0.0, "Speed defense should clear Ragnarok knockback")
	_expect(abs(mythic_item_runtime.ragnarok_boss_knockback_vel) <= 0.01, "Speed defense should zero Ragnarok knockback velocity")

	var viper_runtime := ViperSkillRuntime.new()
	var viper_ai := BossAiState.new()
	viper_runtime.phantom_kick_knockback_pending = true
	viper_runtime.phantom_kick_speed_limit_disabled = true
	var phantom_result: Dictionary = viper_runtime.consume_phantom_kick_knockback(
		Vector2(390.0, 70.0),
		Vector2(330.0, 25.0),
		100.0,
		{"stage2_boss_skill_state": state, "ai_state": viper_ai}
	)
	_expect(phantom_result.is_empty(), "Speed defense should consume Phantom Kick knockback without moving the boss")
	_expect(not bool(viper_runtime.is_phantom_kick_speed_limit_disabled()), "Speed defense guard should still restore Phantom Kick's speed cap")
	_expect(viper_ai.paddle_hit_knockback_timer <= 0.0, "Speed defense should not arm Phantom Kick knockback")
	viper_runtime.kick_skill_knockback_pending_pct = 35
	var kick_result: Dictionary = viper_runtime.consume_kick_skill_knockback(
		Vector2(390.0, 70.0),
		Vector2(330.0, 25.0),
		100.0,
		immune_context,
		{"stage2_boss_skill_state": state, "ai_state": viper_ai}
	)
	_expect(not kick_result.has("boss_vel"), "Speed defense should consume Viper guard knockback without a boss velocity override")

	var draw_builder := BattleDrawActorContext.new()
	var actor_context: Dictionary = draw_builder.build({
		"current_stage": 2,
		"selected_character_type": "smasher",
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
	}, {
		"stage2_boss_skill_state": state,
		"active_item_runtime": BossDisableDrawSource.new(),
		"mythic_item_runtime": BossDisableDrawSource.new(),
	})
	_expect(not bool(actor_context.get("active_item_boss_stun_active", false)), "Speed defense shield should suppress boss stun draw context")
	_expect(not bool(actor_context.get("active_item_boss_confusion_active", false)), "Speed defense shield should suppress boss confusion draw context")
	_expect(not bool(actor_context.get("ragnarok_hammer_electric_stun_active", false)), "Speed defense shield should suppress Ragnarok stun draw context")


func _expect_speed_defense_duration(activation_context: Dictionary) -> void:
	var duration_state: Object = Stage2BossSkillState.new()
	duration_state._activate_speed_defense(520.0, {}, activation_context)
	duration_state._update_speed_defense_timers(2.1, activation_context)
	_expect(duration_state.is_speed_defense_active(), "Speed defense should stay active beyond the previous 2.0 second duration")
	duration_state._update_speed_defense_timers(1.41, activation_context)
	_expect(not duration_state.is_speed_defense_active(), "Speed defense should expire after 3.5 seconds")


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 2:
		return false
	_expect(probe.draw_count > 0, "Stage 2 speed defense renderer should receive a draw callback")
	print("stage2_speed_defense_smoke: ok")
	quit(0)
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
