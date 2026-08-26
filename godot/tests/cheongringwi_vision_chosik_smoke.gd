extends SceneTree

const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const BallRoundCleanup := preload("res://scripts/ball/ball_round_cleanup.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BattleFeedbackState := preload("res://scripts/effects/battle_feedback_state.gd")
const BattleSkillIconPaths := preload("res://scripts/resources/battle_skill_icon_paths.gd")
const BattleUpdateEffectsCharacterDepsBuilder := preload(
	"res://scripts/core/battle_update_effects_character_deps_builder.gd"
)
const BattleUpdatePlayerControlDepsBuilder := preload(
	"res://scripts/core/battle_update_player_control_deps_builder.gd"
)
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const CheongringwiVisionChosikState := preload("res://scripts/characters/cheongringwi_vision_chosik_state.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const OptimusSkillConfig := preload("res://scripts/characters/optimus_skill_config.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const Stage2PillarAssets := preload("res://scripts/stages/stage2/stage2_pillar_assets.gd")
const Stage2QuakeCoordinator := preload("res://scripts/stages/stage2/stage2_quake_coordinator.gd")
const Stage2QuakeRuntimeState := preload("res://scripts/stages/stage2/stage2_quake_runtime_state.gd")
const Stage2WaterCannonPayloadFactory := preload(
	"res://scripts/stages/stage2/stage2_water_cannon_payload_factory.gd"
)
const Stage2WaterFragmentPlayerHitApplier := preload(
	"res://scripts/stages/stage2/stage2_water_fragment_player_hit_applier.gd"
)
const TowerRewardPickOfferBuilder := preload("res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")

const SKILL_ID := CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID
const UNLOCK_ID := CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID
const CHANGED_SCRIPT_PATHS: Array[String] = [
	"res://scripts/ball/ball_dependency_context.gd",
	"res://scripts/ball/ball_round_cleanup.gd",
	"res://scripts/ball/ball_update_controller.gd",
	"res://scripts/characters/cheongringwi_vision_chosik_renderer.gd",
	"res://scripts/characters/cheongringwi_vision_chosik_state.gd",
	"res://scripts/characters/common_skill_catalog.gd",
	"res://scripts/characters/runtime_perk_catalog.gd",
	"res://scripts/core/battle_playfield_effects_drawer.gd",
	"res://scripts/core/battle_playfield_scene_drawer.gd",
	"res://scripts/core/battle_scene_actor_update_driver.gd",
	"res://scripts/core/battle_scene_update_prewarm_driver.gd",
	"res://scripts/core/battle_scene_update_prewarm_key_sets.gd",
	"res://scripts/core/battle_update_effects_character_deps_builder.gd",
	"res://scripts/core/battle_update_player_control_deps_builder.gd",
	"res://scripts/effects/battle_effects_update_controller.gd",
	"res://scripts/core/match_reset_controller.gd",
	"res://scripts/core/victory_loot_phase_state.gd",
	"res://scripts/hud/runtime_perk_icon_renderer.gd",
	"res://scripts/hud/skill_orb_tooltip_effect_preview_renderer.gd",
	"res://scripts/hud/smasher_skill_orb_slot_renderer.gd",
	"res://scripts/hud/smasher_skill_orb_symbol_renderer.gd",
	"res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd",
	"res://scripts/resources/battle_skill_icon_paths.gd",
	"res://scripts/resources/gameplay_actor_module_catalog.gd",
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd",
	"res://scripts/stages/stage2/stage2_pillar_background.gd",
	"res://scripts/stages/stage2/stage2_quake_coordinator.gd",
	"res://scripts/stages/stage2/stage2_rock_feedback_coordinator.gd",
	"res://scripts/stages/stage2/stage2_rock_fragment_payload_factory.gd",
	"res://scripts/stages/stage2/stage2_water_cannon_payload_factory.gd",
	"res://tests/cheongringwi_vision_chosik_visual_qa.gd",
	"res://tests/cheongringwi_vision_reward_box_visual_qa.gd",
	"res://tests/victory_loot_phase_state_smoke.gd",
]

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var current_stage := 2
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := "dalji"
	var selected_character_type := "smasher"
	var special_gauge := 250.0
	var boss_pos := Vector2(330.0, 80.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeSkillConfig:
	extends RefCounted
	func is_skill_equipped(skill_id: String) -> bool:
		return skill_id == SKILL_ID

	func get_cooldown_seconds(_skill_id: String) -> float:
		return 40.0


class FakeAudio:
	extends RefCounted
	var rock_spawn_calls := 0
	var rockhit_calls := 0
	var stonebreak_calls := 0
	var stonebreak_size := 0.0
	var whipcrack_calls := 0
	var quake_start_calls := 0
	var quake_stop_calls := 0
	var quake_playing := false

	func play_stage2_rock_spawn() -> void:
		rock_spawn_calls += 1

	func play_stage2_rockhit() -> void:
		rockhit_calls += 1

	func play_stage2_stonebreak_for_size(size: float) -> void:
		stonebreak_calls += 1
		stonebreak_size = size

	func play_whipcrack(_volume: float = 1.0) -> void:
		whipcrack_calls += 1

	func play_stage2_quake_loop() -> void:
		if quake_playing:
			return
		quake_playing = true
		quake_start_calls += 1

	func stop_stage2_quake_loop() -> void:
		if not quake_playing:
			return
		quake_playing = false
		quake_stop_calls += 1


class FakeFeedback:
	extends RefCounted
	var fixed_offsets: Array[Vector2] = []
	var hit_shake_calls := 0

	func push_fixed_shake_offset(offset: Vector2) -> void:
		fixed_offsets.append(offset)

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		hit_shake_calls += 1


class FakeBallEffects:
	extends RefCounted
	var pulse_calls := 0
	var pulse_kind := ""

	func register_hit_pulse(_pos: Vector2, _vel: Vector2, _intensity: float, kind: String) -> void:
		pulse_calls += 1
		pulse_kind = kind


class FakeImpactEffects:
	extends RefCounted
	var hit_particle_calls := 0
	var last_hit_pos := Vector2.ZERO

	func spawn_hit_particles(
		pos: Vector2,
		_color: Color,
		_velocity: Vector2,
		_scale: float,
		_speed: float
	) -> void:
		hit_particle_calls += 1
		last_hit_pos = pos


class FakeBossAi:
	extends RefCounted
	var knockback_calls := 0
	var velocity := 0.0
	var frames := 0.0
	var decay := 0.0
	var replace_current := false

	func start_paddle_hit_knockback(
		new_velocity: float,
		new_frames: float,
		new_decay: float,
		new_replace_current: bool
	) -> void:
		knockback_calls += 1
		velocity = new_velocity
		frames = new_frames
		decay = new_decay
		replace_current = new_replace_current


class FakeRuntimePerkState:
	extends RefCounted
	var runtime_skill_levels: Dictionary = {}


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeUnlockStore:
	extends RefCounted
	var allowed_id := ""

	func _init(new_allowed_id: String = "") -> void:
		allowed_id = new_allowed_id

	func is_unlocked(content_type: String, content_id: String) -> bool:
		return content_type == "runtime_perk" and content_id == allowed_id


func _init() -> void:
	_verify_changed_scripts_reload_clean()
	_verify_catalog_localization_and_assets()
	_verify_all_character_equip_contract()
	_verify_randomized_rock_count_contract()
	_verify_shared_stage2_quake_presentation_contract()
	_verify_real_frame_shake_contract()
	_verify_strict_command_and_quake_rockfall()
	_verify_fragment_boss_knockback_contract()
	_verify_real_ball_update_contract()
	_verify_stage2_tower_reward_pick_contract()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("cheongringwi_vision_chosik_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_changed_scripts_reload_clean() -> void:
	for path: String in CHANGED_SCRIPT_PATHS:
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(resource is GDScript, "%s should load as GDScript" % path)
		if resource is GDScript:
			var reload_error: Error = (resource as GDScript).reload(true)
			_expect_eq(reload_error, OK, "%s should reload without parse errors" % path)


func _verify_catalog_localization_and_assets() -> void:
	var localized_names: Dictionary = {}
	for language: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(language)
		var data: Dictionary = CommonSkillCatalog.get_skill_data(SKILL_ID)
		var unlock: Dictionary = CommonSkillCatalog.get_unlock_perk_data(UNLOCK_ID)
		var localized_name := str(data.get("korean", ""))
		_expect(not localized_name.is_empty(), "%s skill name should be localized" % language)
		_expect(not str(data.get("description", "")).is_empty(), "%s skill description should be localized" % language)
		_expect(str(data.get("how_to_use", "")).contains("A → D → A"), "%s input copy should publish A-D-A" % language)
		_expect(not str(unlock.get("name", "")).is_empty(), "%s manual name should be localized" % language)
		localized_names[localized_name] = true
	_expect_eq(localized_names.size(), LanguageSettings.SUPPORTED_LANGUAGES.size(), "all seven locales should have distinct Vision names")
	LanguageSettings.set_test_locale_override("ko")
	var control_rows: Array = SmasherSkillOrbTooltipRenderer.COMMON_CONTROL_ROWS.get(SKILL_ID, [])
	_expect(control_rows.size() == 2 and str(control_rows).contains("A") and str(control_rows).contains("D"), "Cheongringwi Vision tooltip should show Shift+A-D-A and arrow equivalents")
	var skill_data: Dictionary = CommonSkillCatalog.get_skill_data(SKILL_ID)
	var unlock_data: Dictionary = CommonSkillCatalog.get_unlock_perk_data(UNLOCK_ID)
	_expect_eq(str(skill_data.get("korean", "")), "청린귀 비전 · 지맥진동", "confirmed Korean Chosik name")
	_expect(str(skill_data.get("description", "")).contains("3~5개"), "Korean tooltip should publish the randomized three-to-five rock count")
	_expect_close(float(skill_data.get("cost", 0.0)), 250.0, "activation vigor cost")
	# GRT-054 sibling: derive from the catalog constant so a cooldown retune does
	# not turn this leg RED for a deliberate balance change.
	_expect_close(
		float(skill_data.get("cooldown", 0.0)),
		CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN,
		"base cooldown"
	)
	_expect_eq(str(skill_data.get("effect_type", "")), "cheongringwi_vision_dragon_torrent", "tooltip effect preview route")
	_expect(bool(unlock_data.get("vision_chosik", false)), "manual should be classified as Vision Chosik")
	_expect_eq(str(unlock_data.get("boss_id", "")), "cheongringwi", "manual should retain Stage 2 boss identity")
	_expect_eq(CommonSkillCatalog.get_skill_id_for_unlock(UNLOCK_ID), SKILL_ID, "manual-to-skill mapping")
	_expect_eq(CommonSkillCatalog.get_unlock_id_for_skill(SKILL_ID), UNLOCK_ID, "skill-to-manual mapping")

	var manual_path := str(RuntimePerkIconRenderer.MANUAL_ICON_PATHS.get(UNLOCK_ID, ""))
	var orb_path := str(RuntimePerkIconRenderer.SKILL_ICON_PATHS.get(SKILL_ID, ""))
	_expect_eq(manual_path, "res://assets/sprites/perks/cheongringwi_vision_earth_vein_quake_manual_icon_imagegen_v1.png", "manual icon route")
	_expect_eq(orb_path, "res://assets/sprites/skills/cheongringwi_vision_earth_vein_quake_skill_orb_imagegen_v1.png", "orb icon route")
	_expect(manual_path != orb_path, "manual and equipped orb should use separate art")
	_expect_eq(str(BattleSkillIconPaths.SMASHER_SKILL_ICON_PATHS.get(SKILL_ID, "")), orb_path, "Smasher HUD icon route")
	_expect_eq(str(BattleSkillIconPaths.VIPER_SKILL_ICON_PATHS.get(SKILL_ID, "")), orb_path, "Viper HUD icon route")
	_expect_eq(str(BattleSkillIconPaths.COMMANDO_SKILL_ICON_PATHS.get(SKILL_ID, "")), orb_path, "Commando HUD icon route")
	_verify_transparent_icon(manual_path, Vector2i(256, 256), "Cheongringwi manual")
	_verify_transparent_icon(orb_path, Vector2i(512, 512), "Cheongringwi orb")


func _verify_all_character_equip_contract() -> void:
	for config: Object in [
		SmasherSkillConfig.new(),
		ViperSkillConfig.new(),
		CommandoSkillConfig.new(),
		BlacksmithSkillConfig.new(),
		OptimusSkillConfig.new(),
	]:
		_expect(config.unlock_and_equip_skill(SKILL_ID), "every character config should equip the shared Stage 2 Vision Chosik")
		_expect(config.is_skill_equipped(SKILL_ID), "equipped Stage 2 Vision Chosik should pass the activation gate")
		_expect_close(config.get_cooldown_seconds(SKILL_ID), CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN, "every character should expose the common cooldown")
		config.set_runtime_cooldown_multiplier(0.60)
		_expect_close(config.get_cooldown_seconds(SKILL_ID), CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN * 0.6, "Breath-Regulating Inner Art Lv.5 should reduce Cheongringwi Vision cooldown by 40 percent")
		var snapshot: Dictionary = config.get_snapshot()
		_expect_close(float((snapshot.get("cooldown_seconds", {}) as Dictionary).get(SKILL_ID, 0.0)), CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN * 0.6, "Cheongringwi Vision HUD metadata should publish the reduced live cooldown")


func _verify_randomized_rock_count_contract() -> void:
	var state := CheongringwiVisionChosikState.new()
	var observed_counts: Dictionary = {}
	var config := _make_control_config(250.0)
	_expect_close(CheongringwiVisionChosikState.ROCK_TARGET_Y_MIN, 50.0, "Vision rock target minimum Y should match the Stage 2 boss")
	_expect_close(CheongringwiVisionChosikState.ROCK_TARGET_Y_MAX, 700.0, "Vision rock target maximum Y should match the Stage 2 boss")
	_expect_close(CheongringwiVisionChosikState.ROCK_START_Y_MIN, -300.0, "Vision rock start minimum Y should match the Stage 2 boss")
	_expect_close(CheongringwiVisionChosikState.ROCK_START_Y_MAX, -100.0, "Vision rock start maximum Y should match the Stage 2 boss")
	for _sample_index in range(40):
		var sampled_rocks: Array = state._build_rocks(config)
		var rock_count: int = sampled_rocks.size()
		_expect(rock_count >= 3 and rock_count <= 5, "every rockfall roll should stay inside the inclusive three-to-five range")
		observed_counts[rock_count] = true
		for rock_value: Variant in sampled_rocks:
			var rock := rock_value as Dictionary
			var target_pos: Vector2 = _get_vector2(rock.get("target_pos", Vector2.ZERO))
			var start_pos: Vector2 = _get_vector2(rock.get("start_pos", Vector2.ZERO))
			_expect(target_pos.y >= 50.0 and target_pos.y <= 700.0, "every Vision rock target Y should stay inside the exact Stage 2 boss range")
			_expect(start_pos.y >= -300.0 and start_pos.y <= -100.0, "every Vision rock start Y should stay inside the exact Stage 2 boss range")
	_expect(observed_counts.has(3), "the deterministic roll sweep should reach the three-rock lower bound")
	_expect(observed_counts.has(4), "the deterministic roll sweep should reach the four-rock middle value")
	_expect(observed_counts.has(5), "the deterministic roll sweep should reach the five-rock upper bound")


func _verify_shared_stage2_quake_presentation_contract() -> void:
	_expect_close(
		CheongringwiVisionChosikState.QUAKE_DURATION_SEC,
		Stage2QuakeCoordinator.DEFAULT_DURATION_SEC,
		"Vision quake duration should use the exact Stage 2 boss duration"
	)
	var state := CheongringwiVisionChosikState.new()
	state.prewarm_assets()
	var snapshot: Dictionary = state.get_snapshot()
	var rock_texture: Texture2D = snapshot.get("rock_texture", null) as Texture2D
	_expect(rock_texture != null, "Vision quake should prewarm the Stage 2 boss rock atlas")
	if rock_texture != null:
		_expect_eq(rock_texture.resource_path, Stage2PillarAssets.ROCK_TEXTURE_PATH, "Vision rocks should use the exact Stage 2 boss atlas")
	_expect_eq(snapshot.get("rock_source_regions", []), Stage2PillarAssets.ROCK_SOURCE_REGION_DATA, "Vision rocks should use the exact Stage 2 atlas regions")
	var debris_texture: Texture2D = snapshot.get("rock_debris_texture", null) as Texture2D
	_expect(debris_texture != null, "Vision rock breaks should prewarm the Stage 2 boss debris atlas")
	if debris_texture != null:
		_expect_eq(debris_texture.resource_path, Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH, "Vision fragments should use the exact Stage 2 boss debris atlas")
	_expect_eq(snapshot.get("rock_debris_source_regions", []), Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA, "Vision fragments should use the exact Stage 2 debris regions")

	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var config := _make_control_config(owner.special_gauge)
	_expect(_input_command(state, [-1, 1, -1], owner, audio, config), "shared quake fixture should activate")
	state._quake_runtime_state.timer = Stage2QuakeCoordinator.DEFAULT_DURATION_SEC
	state._quake_runtime_state.ball_velocity_backup = Vector2.ZERO
	state._quake_runtime_state.ball_velocity_backup_valid = false
	state._quake_runtime_state.ball_rng.seed = 7788

	var boss_quake_state := Stage2QuakeRuntimeState.new()
	boss_quake_state.reset(Stage2QuakeCoordinator.DEFAULT_DURATION_SEC, 0.0)
	boss_quake_state.seed_random_sources(7787, 7788)
	boss_quake_state.activate(
		Stage2QuakeCoordinator.DEFAULT_DURATION_SEC,
		Stage2QuakeCoordinator.MINIMUM_DURATION_SEC,
		Stage2QuakeCoordinator.REPEAT_COOLDOWN_SEC,
		0.0,
		true
	)
	var boss_coordinator := Stage2QuakeCoordinator.new()
	boss_coordinator.configure(boss_quake_state, null, null, null, null, null)
	var motion_context := {
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 80.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_impact_boost": 1.0,
		"max_ball_speed": 18.0,
		"impact_boost_max_ball_speed": 18.0,
	}
	var boss_scene := {
		"ball_pos": Vector2(740.0, 40.0),
		"ball_vel": Vector2(7.0, -9.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 18.0,
		"impact_boost_max_ball_speed": 18.0,
	}
	_expect(boss_coordinator.apply_active_ball_motion(boss_scene, motion_context, 1.0), "boss shared motion fixture should apply")
	var vision_result: Dictionary = state.apply_ball_motion(
		Vector2(740.0, 40.0),
		Vector2(7.0, -9.0),
		28.0,
		Vector2(330.0, 80.0),
		100.0,
		40.0,
		"player",
		motion_context,
		1.0
	)
	_expect(not bool(vision_result.get("cheongringwi_vision_reflected", false)), "player-owned parity probe must not collide with Vision rocks")
	_expect_eq(vision_result.get("ball_vel", Vector2.ZERO), boss_scene.get("ball_vel", Vector2.ZERO), "Vision ball shake should exactly match the Stage 2 boss path")
	_expect_eq(vision_result.get("max_ball_speed", 0.0), boss_scene.get("max_ball_speed", 0.0), "Vision quake should share the boss speed cap")
	_expect_eq(vision_result.get("impact_boost_max_ball_speed", 0.0), boss_scene.get("impact_boost_max_ball_speed", 0.0), "Vision quake should share the boss impact cap")
	state.reset_round()


func _verify_real_frame_shake_contract() -> void:
	var state := CheongringwiVisionChosikState.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var config := _make_control_config(owner.special_gauge)
	_expect(_input_command(state, [-1, 1, -1], owner, audio, config), "real-frame shake fixture should activate")
	state.update(1.0 / 60.0, {}, true, Vector2(300.0, 700.0), config, {"audio": audio})
	var feedback := BattleFeedbackState.new()
	feedback.push_fixed_shake_offset(Vector2(99.0, 99.0))
	var controller := BattleEffectsUpdateController.new()
	controller.update(1.0 / 60.0, {"current_msec": 1000}, {
		"feedback": feedback,
		"cheongringwi_vision_chosik_state": state,
	})
	var published_offset: Vector2 = feedback.get_shake_offset()
	_expect(published_offset.length() > 0.05, "Vision quake shake should survive the real feedback reset order")
	_expect(published_offset.distance_to(Vector2(99.0, 99.0)) > 100.0, "the real feedback update should clear stale offsets before publishing Vision shake")
	var deps_builder := BattleUpdateEffectsCharacterDepsBuilder.new()
	var built_deps: Dictionary = deps_builder.build_deps(FakeRegistry.new({
		"cheongringwi_vision_chosik_state": state,
	}), "smasher")
	_expect_eq(built_deps.get("cheongringwi_vision_chosik_state", null), state, "effects deps should expose the Vision state after feedback reset")
	state.reset_round()


func _verify_strict_command_and_quake_rockfall() -> void:
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var state := CheongringwiVisionChosikState.new()
	var config := _make_control_config(owner.special_gauge)
	var deps := {"owner": owner, "skill_config": FakeSkillConfig.new(), "audio": audio, "feedback": feedback}
	_expect(not state.is_ready(249.9), "vigor below 250 should not be ready")
	_expect(state.is_ready(250.0), "250 vigor should meet the activation cost")
	state.update(0.01, {"left_pressed": true}, false, Vector2(300.0, 700.0), config, deps)
	_expect_eq(state.command_step, 0, "A without Shift must not begin the command")
	state.update(0.01, {}, false, Vector2(300.0, 700.0), config, deps)
	var wrong_activation := _input_command(state, [1, -1, 1], owner, audio, config, feedback)
	_expect(not wrong_activation, "Shift+D-A-D must not activate the Stage 2 A-D-A Chosik")
	state.update(0.01, {}, false, Vector2(300.0, 700.0), config, deps)
	var activated := _input_command(state, [-1, 1, -1], owner, audio, config, feedback)
	_expect(activated, "Shift+A-D-A should activate Earth-Vein Quake")
	_expect_close(owner.special_gauge, 0.0, "activation should spend exactly 250 vigor")
	_expect_eq(state.phase, "quake", "activation should immediately enter the quake phase")
	_expect(not state.is_movement_locked(), "the quake should not lock player movement")
	var spawned_rock_count := state.rocks.size()
	_expect(spawned_rock_count >= 3 and spawned_rock_count <= 5, "the Chosik should create three to five falling rocks")
	_expect_eq(audio.rock_spawn_calls, 1, "activation should play one rockfall launch cue")
	_expect_eq(audio.quake_start_calls, 1, "activation should start the exact Stage 2 quake loop")
	_expect(audio.quake_playing, "the Stage 2 quake loop should remain active for the quake duration")
	for _frame_index in range(4):
		state.update(0.25, {}, true, Vector2(300.0, 700.0), config, deps)
		state.publish_screen_shake(feedback)
	_expect_eq(audio.rockhit_calls, 0, "boss-parity rock landings should not invent per-rock hit cues")
	_expect(feedback.fixed_offsets.size() > 2, "the quake should keep shaking across physics frames")
	var first_rock: Dictionary = state.rocks[0] as Dictionary
	_expect(not bool(first_rock.get("falling", true)), "the first rock should land after one second")
	_expect(_get_vector2(first_rock.get("quake_offset", Vector2.ZERO)).length() > 0.0, "Vision rocks should share the Stage 2 quake wobble")
	var contact_pos: Vector2 = _get_vector2(first_rock.get("pos", Vector2.ZERO)) \
		+ _get_vector2(first_rock.get("quake_offset", Vector2.ZERO))
	var rock_count_before_hit := state.rocks.size()
	var survivor_seeds_before: Array[int] = []
	for rock_index in range(1, state.rocks.size()):
		survivor_seeds_before.append(int((state.rocks[rock_index] as Dictionary).get("rock_seed", -1)))
	var player_owned := state.apply_ball_motion(
		contact_pos, Vector2(0.0, -12.0), 28.0,
		Vector2(330.0, 80.0), 100.0, 40.0, "player"
	)
	_expect(not bool(player_owned.get("cheongringwi_vision_reflected", false)), "a player-owned outgoing ball should pass through the landed rocks")
	_expect(player_owned.has("ball_vel"), "player-owned balls should still receive the shared Stage 2 quake motion")
	var reflected := state.apply_ball_motion(
		contact_pos, Vector2(0.0, 12.0), 28.0,
		Vector2(330.0, 80.0), 100.0, 40.0, "boss"
	)
	_expect(bool(reflected.get("cheongringwi_vision_reflected", false)), "a boss-owned ball touching a landed rock should reflect")
	var reflected_velocity: Vector2 = reflected.get("ball_vel", Vector2.ZERO)
	_expect_close(reflected_velocity.length(), Stage2QuakeCoordinator.BALL_EFFECTIVE_SPEED_CAP, "rock reflection should preserve the boss-quake-capped ball speed")
	_expect(reflected_velocity.y < 0.0, "rock reflection should travel toward the boss")
	_expect_eq(state.rocks.size(), rock_count_before_hit - 1, "one ball hit should destroy exactly one rock")
	var survivor_seeds_after: Array[int] = []
	for survivor_value: Variant in state.rocks:
		if survivor_value is Dictionary:
			survivor_seeds_after.append(int((survivor_value as Dictionary).get("rock_seed", -1)))
	_expect_eq(survivor_seeds_after, survivor_seeds_before, "destroying one rock must preserve every other rock")
	var fragments: Array = state._rock_fragment_state.fragments
	_expect(
		fragments.size() >= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_MIN_COUNT
		and fragments.size() <= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_MAX_COUNT,
		"a destroyed Vision rock should emit the original water-cannon fragment count"
	)
	var upward_fragment_count := 0
	var total_vertical_velocity := 0.0
	var fragments_match_original_payload := true
	var fragments_ignore_player := true
	var fragment_start_positions: Array[Vector2] = []
	for fragment_value: Variant in fragments:
		if not fragment_value is Dictionary:
			fragments_match_original_payload = false
			continue
		var fragment: Dictionary = fragment_value as Dictionary
		var fragment_velocity: Vector2 = _get_vector2(fragment.get("vel", Vector2.ZERO))
		fragment_start_positions.append(_get_vector2(fragment.get("pos", Vector2.ZERO)))
		if fragment_velocity.y < 0.0:
			upward_fragment_count += 1
		total_vertical_velocity += fragment_velocity.y
		fragments_match_original_payload = fragments_match_original_payload \
			and fragment_velocity.length() >= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SPEED_MIN_PER_FRAME * 60.0 - 0.01 \
			and fragment_velocity.length() <= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SPEED_MAX_PER_FRAME * 60.0 + 0.01 \
			and float(fragment.get("size", 0.0)) >= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SIZE_MIN \
			and float(fragment.get("size", 0.0)) <= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SIZE_MAX \
			and is_equal_approx(
				float(fragment.get("max_life", 0.0)),
				Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_LIFE_SEC
			) \
			and float(fragment.get("gravity", 0.0)) < 0.0
		fragments_ignore_player = fragments_ignore_player and not bool(fragment.get("can_hit_player", false))
	_expect_eq(upward_fragment_count, fragments.size(), "every Vision rock fragment should launch into the boss field")
	_expect(total_vertical_velocity < 0.0, "the Vision fragment burst should have a bossward upward net velocity")
	_expect(fragments_match_original_payload, "Vision fragments should reuse the water-cannon payload with mirrored gravity")
	_expect(fragments_ignore_player, "Vision rock fragments should remain harmless to the player")
	state._rock_fragment_state.advance(0.25, 700.0)
	var every_fragment_continued_bossward := true
	for fragment_index in range(state._rock_fragment_state.fragments.size()):
		var advanced_fragment: Dictionary = state._rock_fragment_state.fragments[fragment_index] as Dictionary
		every_fragment_continued_bossward = every_fragment_continued_bossward \
			and _get_vector2(advanced_fragment.get("pos", Vector2.ZERO)).y < fragment_start_positions[fragment_index].y \
			and _get_vector2(advanced_fragment.get("vel", Vector2.ZERO)).y < 0.0
	_expect(every_fragment_continued_bossward, "Vision fragments should keep travelling bossward instead of falling back at the player")
	_expect_eq(audio.rockhit_calls, 0, "direct state motion should leave contact audio to the production controller")
	_expect_eq(state.phase, "quake", "a reflection should not consume the remaining rockfall")
	state.update(0.5, {}, true, Vector2(300.0, 700.0), config, deps)
	_expect_eq(audio.quake_stop_calls, 1, "the exact Stage 2 quake loop should stop when its 80-frame duration ends")
	_expect(not audio.quake_playing, "the quake loop must not outlive the quake timer")
	var surviving_rock_count := state.rocks.size()
	state.update(3.0, {}, true, Vector2(300.0, 700.0), config, deps)
	_expect_eq(state.rocks.size(), surviving_rock_count, "unhit rocks should persist individually like the Stage 2 boss rocks")
	var preserved_rock_positions: Array[Vector2] = []
	for rock_value: Variant in state.rocks:
		preserved_rock_positions.append(_get_vector2((rock_value as Dictionary).get("pos", Vector2.ZERO)))
	state.impacts.append({"pos": Vector2(300.0, 300.0), "life": 0.2, "max_life": 0.2})
	state._rock_fragment_state.fragments.append({"pos": Vector2(300.0, 300.0), "life": 0.2})
	var cooldown_before_reset := state.cooldown_remaining
	BallRoundCleanup.new().reset_power_and_drive({"cheongringwi_vision_chosik_state": state}, true)
	_expect_close(state.cooldown_remaining, cooldown_before_reset, "round cleanup should preserve cooldown")
	_expect_eq(state.rocks.size(), surviving_rock_count, "the production round cleanup path should preserve every unbroken rock")
	for rock_index in range(state.rocks.size()):
		var preserved_rock: Dictionary = state.rocks[rock_index] as Dictionary
		_expect_eq(_get_vector2(preserved_rock.get("pos", Vector2.ZERO)), preserved_rock_positions[rock_index], "round cleanup should preserve each rock position")
		_expect_eq(_get_vector2(preserved_rock.get("quake_offset", Vector2.ONE)), Vector2.ZERO, "round cleanup should clear transient quake wobble")
	_expect_eq(state.phase, "idle", "round cleanup should end the old quake phase")
	_expect_close(state.quake_timer, 0.0, "round cleanup should end the old screen shake")
	_expect(state.impacts.is_empty(), "round cleanup should clear transient impact rings")
	_expect(state._rock_fragment_state.fragments.is_empty(), "round cleanup should clear already-flying debris")
	_expect(state.has_visible_effects(), "preserved rocks should remain visible in the next round")
	state.reset()
	_expect_close(state.cooldown_remaining, 0.0, "full reset should clear cooldown")
	_expect(state.rocks.is_empty(), "full match reset should remove the round-persistent rocks")
	_expect(not state.has_visible_effects(), "full match reset should tear down every Vision effect")


func _verify_fragment_boss_knockback_contract() -> void:
	var state := CheongringwiVisionChosikState.new()
	var boss_hit_pos := Vector2(352.0, 101.0)
	state._rock_fragment_state.fragments = [
		{
			"pos": boss_hit_pos,
			"vel": Vector2(160.0, -420.0),
			"size": 20.0,
			"gravity": -1800.0,
			"life": 1.0,
			"max_life": 1.0,
			"can_hit_boss": true,
		},
		{
			"pos": Vector2(80.0, 500.0),
			"vel": Vector2(-120.0, -360.0),
			"size": 18.0,
			"gravity": -1800.0,
			"life": 1.0,
			"max_life": 1.0,
			"can_hit_boss": true,
		},
	]
	var ai_state := FakeBossAi.new()
	var impact_effects := FakeImpactEffects.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"boss_ai_state": ai_state,
		"impact_effects": impact_effects,
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})
	var deps: Dictionary = BattleUpdatePlayerControlDepsBuilder.new().build_deps(registry, "smasher")
	_expect_eq(deps.get("ai_state", null), ai_state, "player-control deps should expose the real boss knockback owner")
	_expect_eq(deps.get("impact_effects", null), impact_effects, "player-control deps should expose fragment hit particles")
	state.update(0.0, {}, false, Vector2(300.0, 700.0), _make_control_config(0.0), deps)
	_expect_eq(state._rock_fragment_state.fragments.size(), 1, "only the fragment touching the boss should be consumed")
	_expect_eq(ai_state.knockback_calls, 1, "one fragment contact should start one boss knockback")
	_expect_close(ai_state.velocity, Stage2WaterFragmentPlayerHitApplier.KNOCKBACK_SPEED, "boss knockback should reuse the original water-fragment speed")
	_expect_close(ai_state.frames, Stage2WaterFragmentPlayerHitApplier.KNOCKBACK_FRAMES, "boss knockback should reuse the original water-fragment duration")
	_expect_close(ai_state.decay, Stage2WaterFragmentPlayerHitApplier.KNOCKBACK_DECAY, "boss knockback should reuse the original water-fragment decay")
	_expect(ai_state.replace_current, "fragment knockback should replace a weaker current boss knockback")
	_expect_eq(audio.rockhit_calls, 1, "boss fragment contact should play the original rock-hit cue once")
	_expect_eq(feedback.hit_shake_calls, 1, "boss fragment contact should emit the original hit shake once")
	_expect_eq(impact_effects.hit_particle_calls, 1, "boss fragment contact should emit the original hit particles once")
	_expect_eq(impact_effects.last_hit_pos, boss_hit_pos, "fragment hit particles should originate at the boss contact")
	_expect_eq(state.impacts.size(), 1, "boss fragment contact should add one local impact ring")
	state.update(0.0, {}, false, Vector2(300.0, 700.0), _make_control_config(0.0), deps)
	_expect_eq(ai_state.knockback_calls, 1, "a consumed fragment must not knock the boss twice")


func _verify_real_ball_update_contract() -> void:
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var state := CheongringwiVisionChosikState.new()
	var config := _make_control_config(owner.special_gauge)
	_expect(_input_command(state, [-1, 1, -1], owner, audio, config), "real controller fixture should activate")
	var deps_for_state := {"owner": owner, "skill_config": FakeSkillConfig.new(), "audio": audio}
	state.update(1.0, {}, true, Vector2(300.0, 700.0), config, deps_for_state)
	var live_rock: Dictionary = state.rocks[0] as Dictionary
	var rock_pos: Vector2 = live_rock.get("pos", Vector2.ZERO)
	var controller := BallUpdateController.new()
	var intensity := BallIntensity.new()
	intensity.register_hit("boss")
	var effects := FakeBallEffects.new()
	var deps := {
		"cheongringwi_vision_chosik_state": state,
		"ball_intensity": intensity,
		"audio": audio,
		"ball_effects": effects,
		"feedback": FakeFeedback.new(),
	}
	var context := {
		"last_hit_by": "boss",
		"boss_pos": Vector2(330.0, 80.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var held_pos := rock_pos
	var held_vel := Vector2(0.0, 12.0)
	var held_scene := {
		"ball_pos": held_pos,
		"ball_vel": held_vel,
		"ball_size": 28.0,
		"skip_ball_motion_step": true,
	}
	_expect(not controller._apply_cheongringwi_vision_chosik(held_scene, context, deps), "owner-controlled hold should skip the reflection hook")
	_expect_eq(held_scene.get("ball_pos", Vector2.ZERO), held_pos, "hold frame should preserve projected position")
	_expect_eq(held_scene.get("ball_vel", Vector2.ZERO), held_vel, "hold frame should preserve owner-controlled velocity")
	_expect_eq(intensity.get_last_hit_by(), "boss", "hold frame must not corrupt rally ownership")
	_expect_eq(intensity.get_rally_exchange_count(), 0, "hold frame must not invent an exchange")
	_expect_eq(intensity.get_rally_contact_count(), 1, "hold frame must not register a fake contact")
	_expect_eq(audio.whipcrack_calls, 0, "hold frame should remain silent")
	_expect_eq(effects.pulse_calls, 0, "hold frame should not emit a hit pulse")
	_expect_eq(state.phase, "quake", "hold frame must not consume the live rockfall")

	var rock_count_before_hit := state.rocks.size()
	var live_scene := held_scene.duplicate(true)
	live_scene["skip_ball_motion_step"] = false
	_expect(controller._apply_cheongringwi_vision_chosik(live_scene, context, deps), "live controller path should commit the reflection")
	_expect_eq(intensity.get_last_hit_by(), "player", "live reflection should hand rally ownership to the player")
	_expect_eq(intensity.get_rally_exchange_count(), 1, "live reflection should add one exchange")
	_expect_eq(audio.rockhit_calls, 0, "destroyed rocks should not play the non-breaking rock-hit cue")
	_expect_eq(audio.stonebreak_calls, 1, "live reflection should play the exact Stage 2 rock-break cue")
	_expect(audio.stonebreak_size > 0.0, "rock-break audio should retain the destroyed rock size")
	_expect_eq(audio.whipcrack_calls, 0, "live reflection should not substitute Dalji's whip cue")
	_expect_eq(effects.pulse_calls, 1, "live reflection should emit one impact pulse")
	_expect_eq(effects.pulse_kind, SKILL_ID, "impact pulse should retain the Chosik actor identity")
	_expect((_get_vector2(live_scene.get("ball_vel", Vector2.ZERO))).y < 0.0, "committed ball velocity should point bossward")
	_expect_eq(state.rocks.size(), rock_count_before_hit - 1, "the production controller should remove only the contacted rock")
	_expect(
		state._rock_fragment_state.fragments.size() >= Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_MIN_COUNT,
		"the production controller should leave the original water-cannon-scale debris burst"
	)
	_expect_eq((deps.get("feedback") as FakeFeedback).hit_shake_calls, 1, "the rock break should request the Stage 2 boss hit shake")


func _verify_stage2_tower_reward_pick_contract() -> void:
	var boss_slot_id := "floor_02_cheongringwi"
	var builder := TowerRewardPickOfferBuilder.new()
	var owner := FakeOwner.new()
	# Tower reward identity is strict to the arrived map encounter. The shared
	# FakeOwner intentionally keeps the legacy campaign's stale Dalji value;
	# this focused Tower fixture opts into its actually selected boss.
	owner.stage_boss_variant = "cheongringwi"
	var registry := FakeRegistry.new({
		"tower_ascent_unlock_store": FakeUnlockStore.new(UNLOCK_ID),
		"smasher_skill_config": SmasherSkillConfig.new(),
	})
	var choice: Dictionary = builder._build_vision_choice(
		boss_slot_id,
		{"skipped_boss_ids": [], "burned_vision_boss_ids": []},
		owner,
		registry,
		{}
	)
	_expect_eq(str(choice.get("id", "")), UNLOCK_ID, "Cheongringwi boss slot should build the live Tower Vision choice")
	_expect_eq(str(choice.get("boss_slot_id", "")), boss_slot_id, "Stage 2 Vision choice should retain the selected map boss slot")
	_expect_eq(str(choice.get("reward_pick_kind", "")), "vision", "Stage 2 Vision choice should use the Tower reward-pick lane")
	_expect_eq(int(choice.get("current_level", -1)), 0, "unowned Stage 2 Vision choice should begin at level zero")
	_expect_eq(int(choice.get("next_level", -1)), 1, "unowned Stage 2 Vision choice should grant level one")
	_expect(builder._build_vision_choice("floor_01_dalji", {}, owner, registry, {}).is_empty(), "a different selected boss slot must not leak Cheongringwi's Vision reward")
	var locked_registry := FakeRegistry.new({
		"tower_ascent_unlock_store": FakeUnlockStore.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
	})
	_expect(builder._build_vision_choice(boss_slot_id, {}, owner, locked_registry, {}).is_empty(), "locked Cheongringwi Vision content must not enter the Tower reward pick")
	_expect(builder._build_vision_choice(boss_slot_id, {"burned_vision_boss_ids": [boss_slot_id]}, owner, registry, {}).is_empty(), "a burned Cheongringwi boss reward must not return")
	_expect(builder._build_vision_choice(boss_slot_id, {}, owner, registry, {SKILL_ID: 1}).is_empty(), "an owned Stage 2 Vision Chosik must not be offered again")


func _input_command(
	state: Object,
	directions: Array[int],
	owner: Object,
	audio: Object,
	config: Dictionary,
	feedback: Object = null
) -> bool:
	var activated := false
	var deps := {"owner": owner, "skill_config": FakeSkillConfig.new(), "audio": audio}
	if feedback != null:
		deps["feedback"] = feedback
	for direction: int in directions:
		var result: Dictionary = state.update(
			0.01,
			{"left_pressed": direction < 0, "right_pressed": direction > 0},
			true,
			Vector2(300.0, 700.0),
			config,
			deps
		)
		activated = activated or bool(result.get("activated", false))
		state.update(0.01, {}, true, Vector2(300.0, 700.0), config, deps)
	return activated


func _make_control_config(special_gauge: float) -> Dictionary:
	return {
		"ball_active": true,
		"ball_pos": Vector2(380.0, 360.0),
		"special_gauge": special_gauge,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 80.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"width": 760.0,
		"height": 750.0,
	}


func _verify_transparent_icon(path: String, expected_size: Vector2i, label: String) -> void:
	var texture: Texture2D = load(path) as Texture2D
	_expect(texture != null, "%s should load as Texture2D" % label)
	if texture == null:
		return
	var image: Image = texture.get_image()
	_expect(image != null and not image.is_empty(), "%s should expose image data" % label)
	if image == null or image.is_empty():
		return
	_expect_eq(image.get_size(), expected_size, "%s dimensions" % label)
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(expected_size.x - 1, 0), Vector2i(0, expected_size.y - 1), expected_size - Vector2i.ONE]:
		_expect(image.get_pixelv(corner).a <= 0.01, "%s corners should be transparent" % label)
	var used_rect := image.get_used_rect()
	_expect(used_rect.position.x > 0 and used_rect.position.y > 0, "%s alpha should not touch top or left" % label)
	_expect(used_rect.end.x < expected_size.x and used_rect.end.y < expected_size.y, "%s alpha should not touch bottom or right" % label)


func _get_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.3f, got %.3f" % [message, expected, actual])
