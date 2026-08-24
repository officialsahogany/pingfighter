extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const GaksitalVisionChosikState := preload("res://scripts/characters/gaksital_vision_chosik_state.gd")
const Stage1GaksitalFanProjectileContract := preload(
	"res://scripts/stages/stage1/stage1_gaksital_fan_projectile_contract.gd"
)
const Stage1GaksitalFanThrowSkillState := preload(
	"res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd"
)
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload(
	"res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd"
)
const SkillOrbTooltipEffectPreviewRenderer := preload(
	"res://scripts/hud/skill_orb_tooltip_effect_preview_renderer.gd"
)
const BattleSkillIconPaths := preload("res://scripts/resources/battle_skill_icon_paths.gd")
const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)
const TowerAscentChestContextBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_context_builder.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")
const StageClearRewardResolver := preload(
	"res://scripts/core/stage_clear_reward_resolver.gd"
)
const BattleUpdatePlayerControlDepsBuilder := preload(
	"res://scripts/core/battle_update_player_control_deps_builder.gd"
)
const BattleUpdateMatchPlayerSkillDepsBuilder := preload(
	"res://scripts/core/battle_update_match_player_skill_deps_builder.gd"
)
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const OptimusSkillConfig := preload("res://scripts/characters/optimus_skill_config.gd")

const SKILL_ID := "gaksital_vision_fan_throw"
const UNLOCK_ID := "unlock_gaksital_vision_fan_throw"
const PROJECTILE_PATH := "res://assets/sprites/stage1/gaksital/gaksital_fan_projectile_imagegen_v1.png"

var _failures: Array[String] = []


class Stage1Owner:
	extends RefCounted

	var current_stage := 1
	var stage1_boss_variant := "gaksi"
	var selected_character_type := "smasher"
	var special_gauge := 100.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeSkillConfig:
	extends RefCounted

	func is_skill_equipped(skill_id: String) -> bool:
		return skill_id == SKILL_ID

	func get_cooldown_seconds(skill_id: String) -> float:
		return 5.0 if skill_id == SKILL_ID else 0.0


class FakeAudio:
	extends RefCounted

	var fan_calls := 0
	var hit_calls := 0

	func play_gaksital_fan(_volume: float = 1.0) -> void:
		fan_calls += 1

	func play_whipcrack(_volume: float = 1.0) -> void:
		hit_calls += 1


class FakeImpactEffects:
	extends RefCounted

	var explosion_calls := 0
	var particle_calls := 0

	func create_energy_explosion(_pos: Vector2, _scale: float, _intensity: float) -> void:
		explosion_calls += 1

	func spawn_paddle_hit_particles(
		_pos: Vector2,
		_is_player: bool,
		_direction: Vector2,
		_intensity: float
	) -> void:
		particle_calls += 1


class FakeRuntimePerkState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var collected_star_points := 0

	func collect_star_points(
		amount: int,
		_character_type: String,
		_catalog: Object,
		_owner: Object,
		_registry: Object,
		_defer_choice_open: bool
	) -> void:
		collected_star_points += amount


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakePlanBuilder:
	extends RefCounted

	func build_reward_plan(_player_score: int, _boss_score: int) -> Dictionary:
		return {"boxes": [{"kind": "normal"}, {"kind": "normal"}]}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_localization_and_display()
	_verify_acquisition_paths_and_negative_variants()
	_verify_player_activation_hit_miss_and_immunity()
	_verify_shared_boss_projectile_authority()
	_verify_production_wiring_and_cooldown_contract()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("[GaksitalVisionFanThrowSeal] ACQUISITION=GREEN gaksital-only reserved-lane")
		print("[GaksitalVisionFanThrowSeal] ACTIVATION=GREEN input=Shift+Right cost=80 cooldown=5")
		print("[GaksitalVisionFanThrowSeal] IMPACT=GREEN stun=18 knockback=12 miss=expiry stage2=immune")
		print("[GaksitalVisionFanThrowSeal] PARITY=GREEN boss-player-shared-contract normalized-uv")
		print("[GaksitalVisionFanThrowSeal] DISPLAY=GREEN locales=7 korean-long-dash=absent")
		print("gaksital_vision_fan_throw_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_localization_and_display() -> void:
	_expect_eq(CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID, SKILL_ID, "catalog skill ID")
	_expect_eq(CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID, UNLOCK_ID, "catalog unlock ID")
	var localized_names: Dictionary = {}
	for language in ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]:
		LanguageSettings.set_test_locale_override(language)
		var skill_data := CommonSkillCatalog.get_skill_data(SKILL_ID)
		var unlock_data := CommonSkillCatalog.get_unlock_perk_data(UNLOCK_ID)
		var localized_name := str(skill_data.get("korean", ""))
		localized_names[localized_name] = true
		_expect(not localized_name.is_empty(), "%s skill name must be localized" % language)
		_expect(not str(skill_data.get("description", "")).is_empty(), "%s skill description must be localized" % language)
		_expect(not str(unlock_data.get("name", "")).is_empty(), "%s manual name must be localized" % language)
		_expect(not str((unlock_data.get("descriptions", {}) as Dictionary).get(1, "")).is_empty(), "%s manual description must be localized" % language)
		_expect(str(skill_data.get("how_to_use", "")).contains("D"), "%s input copy must publish the right edge" % language)
	_expect_eq(localized_names.size(), 7, "seven locales must not fall back to one shared name")

	LanguageSettings.set_test_locale_override("ko")
	var skill_data := CommonSkillCatalog.get_skill_data(SKILL_ID)
	var unlock_data := CommonSkillCatalog.get_unlock_perk_data(UNLOCK_ID)
	var korean_copy := "%s\n%s\n%s" % [
		str(skill_data.get("korean", "")),
		str(skill_data.get("description", "")),
		str((unlock_data.get("descriptions", {}) as Dictionary).get(1, "")),
	]
	_expect(not korean_copy.contains("—") and not korean_copy.contains("–"), "Korean copy must not use em/en dashes")
	_expect_close(float(skill_data.get("cost", 0.0)), 80.0, "catalog vigor cost")
	_expect_close(float(skill_data.get("cooldown", 0.0)), 5.0, "catalog cooldown")
	_expect_eq(str(skill_data.get("boss_id", "")), "gaksital", "catalog boss identity")
	_expect_eq(str(skill_data.get("activation_class", "")), "instant", "skill-card activation class")
	_expect_eq(str(skill_data.get("slot_occupancy", "")), "active_orb", "catalog slot occupancy")
	_expect(bool(skill_data.get("exclude_from_perk_fusion", false)), "Vision skill must remain out of perk fusion")
	_expect(bool(unlock_data.get("vision_chosik", false)), "manual must be a Vision Chosik")
	_expect_eq(str(unlock_data.get("activation_class", "")), "instant", "manual-card activation class")
	_expect(CommonSkillCatalog.is_common_skill(SKILL_ID), "fan throw must be shared by all character configs")
	_expect_eq(CommonSkillCatalog.get_skill_id_for_unlock(UNLOCK_ID), SKILL_ID, "unlock-to-skill mapping")
	_expect_eq(CommonSkillCatalog.get_unlock_id_for_skill(SKILL_ID), UNLOCK_ID, "skill-to-unlock mapping")

	var control_rows: Array = SmasherSkillOrbTooltipRenderer.COMMON_CONTROL_ROWS.get(SKILL_ID, [])
	_expect(control_rows.size() == 1 and str(control_rows).contains("Shift") and str(control_rows).contains("D") and str(control_rows).contains("→"), "tooltip must show Shift+D/Right")
	var preview_renderer := SkillOrbTooltipEffectPreviewRenderer.new()
	_expect_eq(preview_renderer.get_effect_preview_family(SKILL_ID), "vision", "tooltip effect preview family")
	_expect_eq(str(RuntimePerkIconRenderer.SKILL_ICON_PATHS.get(SKILL_ID, "")), PROJECTILE_PATH, "perk skill icon must reuse the accepted fan")
	_expect_eq(str(RuntimePerkIconRenderer.MANUAL_ICON_PATHS.get(UNLOCK_ID, "")), PROJECTILE_PATH, "manual icon must reuse the accepted fan")
	for icon_map: Dictionary in [
		BattleSkillIconPaths.SMASHER_SKILL_ICON_PATHS,
		BattleSkillIconPaths.VIPER_SKILL_ICON_PATHS,
		BattleSkillIconPaths.COMMANDO_SKILL_ICON_PATHS,
	]:
		_expect_eq(str(icon_map.get(SKILL_ID, "")), PROJECTILE_PATH, "every battle HUD icon map must expose the fan")
	_expect(load(PROJECTILE_PATH) is Texture2D, "accepted fan projectile texture must load")


func _verify_acquisition_paths_and_negative_variants() -> void:
	_expect_eq(TowerAscentBossRewardCatalog.get_vision_unlock_id("floor_01_gaksital"), UNLOCK_ID, "Gaksital boss slot reward")
	_expect_eq(TowerAscentBossRewardCatalog.get_vision_skill_id("floor_01_gaksital"), SKILL_ID, "Gaksital reward skill mapping")
	var tower_choice := TowerAscentBossRewardCatalog.build_vision_choice("floor_01_gaksital")
	_expect_eq(str(tower_choice.get("id", "")), UNLOCK_ID, "tower reward choice must build the Gaksital manual")
	_expect_eq(str(tower_choice.get("reward_pick_kind", "")), "vision", "tower reward must use the Vision pick lane")
	_expect(TowerAscentBossRewardCatalog.get_vision_unlock_id("floor_01_podo").is_empty(), "Pododaejang boss slot must not offer Gaksital Vision")
	_expect(TowerAscentBossRewardCatalog.get_vision_unlock_id("floor_01_dalji") != UNLOCK_ID, "Dalji boss slot must not offer Gaksital Vision")

	var owner := Stage1Owner.new()
	var chest_builder := TowerAscentChestContextBuilder.new()
	var context := chest_builder.build(owner, null, 1)
	_expect_eq(str(context.get("secret_chosik_id", "")), UNLOCK_ID, "Gaksital chest context must select the manual")
	_expect(bool(context.get("secret_chosik_catalog_available", false)), "Gaksital manual must resolve through the catalog")
	_expect(bool(context.get("secret_chosik_eligible", false)), "unowned Gaksital manual must be chest-eligible")
	var secret_reward := chest_builder.build_secret_chosik_reward(UNLOCK_ID)
	_expect_eq(str(secret_reward.get("reserved_perk_offer_id", "")), UNLOCK_ID, "secret Chosik reward must reserve the manual")
	var resolver_catalog := RuntimePerkCatalog.new()
	var resolver_runtime_state := FakeRuntimePerkState.new()
	var resolver_registry := FakeRegistry.new({
		"runtime_perk_catalog": resolver_catalog,
		"runtime_perk_state": resolver_runtime_state,
	})
	var reward_summary := StageClearRewardResolver.new().grant_rewards(
		[secret_reward],
		owner,
		resolver_registry
	)
	_expect_eq(int(reward_summary.get("granted", 0)), 1, "secret Chosik reward resolver grant")
	_expect(resolver_catalog.has_reserved_boss_vision_offer(), "reward resolver must arm the protected Vision lane")
	_expect_eq(resolver_runtime_state.collected_star_points, 1, "reward resolver must open exactly one perk choice")
	var owned_runtime_state := FakeRuntimePerkState.new()
	owned_runtime_state.runtime_skill_levels[SKILL_ID] = 1
	var owned_context := chest_builder.build(
		owner,
		FakeRegistry.new({"runtime_perk_state": owned_runtime_state}),
		1
	)
	_expect(not bool(owned_context.get("secret_chosik_eligible", true)), "owned fan-throw skill must suppress the duplicate manual through unlock mapping")
	owner.stage1_boss_variant = "podo"
	_expect(str(chest_builder.build(owner, null, 1).get("secret_chosik_id", "")).is_empty(), "Podo chest context must remain empty")
	owner.stage1_boss_variant = "dalji"
	_expect(str(chest_builder.build(owner, null, 1).get("secret_chosik_id", "")) != UNLOCK_ID, "Dalji chest context must retain its own manual")

	# The reserved-card lane and falling-box route are the explicit legacy-campaign
	# route; Tower's default route is sealed above through the boss-slot choice.
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var catalog := RuntimePerkCatalog.new()
	_expect(not _has_choice(catalog.get_choices("smasher", {}, false, 3), UNLOCK_ID), "Gaksital Vision must not leak into ordinary offers")
	_expect(catalog.reserve_boss_vision_offer(UNLOCK_ID), "Gaksital Vision reservation must be accepted")
	var reserved_choices := catalog.get_choices("smasher", {}, false, 3)
	_expect(not reserved_choices.is_empty(), "reserved Gaksital manual choice list must not be empty")
	if not reserved_choices.is_empty():
		_expect_eq(str((reserved_choices[0] as Dictionary).get("id", "")), UNLOCK_ID, "reserved Gaksital manual must be first")
		_expect_eq(str((reserved_choices[0] as Dictionary).get("offer_lane", "")), "boss_vision_reserved", "reserved manual lane")

	var registry := FakeRegistry.new({"runtime_perk_state": FakeRuntimePerkState.new()})
	var loot_state := VictoryLootPhaseState.new()
	loot_state._plan_builder = FakePlanBuilder.new()
	loot_state.set_vision_offer_roll_for_tests(func() -> float: return 0.0)
	owner.stage1_boss_variant = "gaksi"
	_expect(loot_state.start(owner, registry, 3, 0, Callable()), "normal Gaksital victory loot path must start")
	_expect_eq(int(loot_state.get_status_for_tests().get("vision_offer_box_count", 0)), 1, "normal Gaksital victory must mark one Vision box")
	loot_state.reset(owner)
	owner.stage1_boss_variant = "podo"
	loot_state._plan_builder = FakePlanBuilder.new()
	loot_state.set_vision_offer_roll_for_tests(func() -> float: return 0.0)
	_expect(loot_state.start(owner, registry, 3, 0, Callable()), "normal Podo victory loot path must still start")
	_expect_eq(int(loot_state.get_status_for_tests().get("vision_offer_box_count", 0)), 0, "Podo victory must not mark a Gaksital Vision box")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()


func _verify_player_activation_hit_miss_and_immunity() -> void:
	var state := GaksitalVisionChosikState.new()
	state.set_rng_seed_for_tests(4755)
	var owner := Stage1Owner.new()
	var status_state := StatusEffectState.new()
	var audio := FakeAudio.new()
	var impacts := FakeImpactEffects.new()
	var deps := {
		"owner": owner,
		"skill_config": FakeSkillConfig.new(),
		"status_effect_state": status_state,
		"audio": audio,
		"impact_effects": impacts,
	}
	var config := {
		"ball_active": true,
		"player_skill_input_locked": false,
		"special_gauge": 100.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": owner.boss_pos,
		"boss_paddle_width": owner.boss_paddle_width,
		"boss_hitbox_height": owner.boss_hitbox_height,
		"width": 760.0,
		"height": 750.0,
		"current_stage": 1,
	}
	_expect(not state.is_ready(79.9), "79.9 vigor must remain below cost")
	_expect(state.is_ready(80.0), "80 vigor must meet cost")
	var activation := state.update(0.0, {"right_pressed": true}, true, Vector2(300.0, 680.0), config, deps)
	_expect(bool(activation.get("activated", false)), "Shift+Right edge must activate fan throw")
	_expect_eq(str(activation.get("activation_class", "")), "instant", "fan throw activation class")
	_expect_close(float(activation.get("special_gauge", -1.0)), 20.0, "activation result gauge")
	_expect_close(owner.special_gauge, 20.0, "production owner gauge mutation")
	_expect_close(state.cooldown_remaining, 5.0, "activation cooldown")
	_expect_eq(state.fans.size(), 1, "activation must spawn one player fan")
	var held := state.update(0.0, {"right_pressed": true}, true, Vector2(300.0, 680.0), config, deps)
	_expect(not bool(held.get("activated", true)), "held right input must not retrigger without a new edge")
	var preserved_cooldown := state.cooldown_remaining
	state.reset_round()
	_expect_close(state.cooldown_remaining, preserved_cooldown, "round cleanup must preserve cooldown")
	_expect(state.fans.is_empty(), "round cleanup must clear in-flight fans")

	state.reset()
	owner.special_gauge = 100.0
	state.update(0.0, {"right_pressed": false}, true, Vector2(300.0, 680.0), config, deps)
	state.update(0.0, {"right_pressed": true}, true, Vector2(300.0, 680.0), config, deps)
	var fan: Dictionary = state.fans[0]
	fan["x"] = 380.0
	fan["y"] = 45.0
	state.fans[0] = fan
	state.update(0.0, {"right_pressed": false}, false, Vector2(300.0, 680.0), config, deps)
	var stun := status_state.get_status_source("boss", "stun", SKILL_ID)
	_expect_close(float(stun.get("total_frames", 0.0)), Stage1GaksitalFanProjectileContract.STUN_FRAMES, "boss stun duration")
	_expect_close(absf(float(stun.get("knockback_vel", 0.0))), Stage1GaksitalFanProjectileContract.KNOCKBACK_POWER, "boss knockback velocity")
	_expect_close(float(stun.get("knockback_frames", 0.0)), Stage1GaksitalFanProjectileContract.KNOCKBACK_FRAMES, "boss knockback frames")
	_expect_close(float(stun.get("knockback_decay_per_frame", 0.0)), Stage1GaksitalFanProjectileContract.KNOCKBACK_DECAY, "boss knockback decay")
	var boss_ai_context := status_state.get_boss_ai_context()
	_expect(bool(boss_ai_context.get("status_boss_stun_active", false)), "status pipeline must publish boss stun to AI")
	_expect(absf(float(boss_ai_context.get("active_item_grenade_knockback_vel", 0.0))) > 0.0, "status pipeline must publish knockback to AI")
	_expect(state.fans.is_empty(), "hit fan must be consumed")
	_expect_eq(audio.hit_calls, 1, "hit must play the shared whipcrack")
	_expect_eq(impacts.explosion_calls, 1, "hit must spawn its impact effect")

	state.reset()
	status_state.reset()
	owner.special_gauge = 100.0
	state.update(0.0, {"right_pressed": true}, true, Vector2(300.0, 680.0), config, deps)
	var expired_fan: Dictionary = state.fans[0]
	expired_fan["timer"] = 0.0
	state.fans[0] = expired_fan
	state.update(0.0, {"right_pressed": false}, false, Vector2(300.0, 680.0), config, deps)
	_expect(state.fans.is_empty(), "missed fan must expire and be pruned")
	_expect(not status_state.has_status("boss", "stun"), "miss expiry must not stun the boss")

	state.reset()
	status_state.reset()
	owner.special_gauge = 100.0
	config["current_stage"] = 2
	config["stage2_speed_defense_status_immunity_active"] = true
	state.update(0.0, {"right_pressed": true}, true, Vector2(300.0, 680.0), config, deps)
	var immune_fan: Dictionary = state.fans[0]
	immune_fan["x"] = 380.0
	immune_fan["y"] = 45.0
	state.fans[0] = immune_fan
	state.update(0.0, {"right_pressed": false}, false, Vector2(300.0, 680.0), config, deps)
	_expect(not status_state.has_status("boss", "stun"), "Stage 2 speed-defense immunity must reject fan stun")


func _verify_shared_boss_projectile_authority() -> void:
	var contract_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage1/stage1_gaksital_fan_projectile_contract.gd"
	)
	var boss_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd"
	)
	var player_source := FileAccess.get_file_as_string(
		"res://scripts/characters/gaksital_vision_chosik_state.gd"
	)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage1/stage1_gaksital_fan_throw_renderer.gd"
	)
	_expect_eq(Stage1GaksitalFanProjectileContract.PROJECTILE_TEXTURE_PATH, PROJECTILE_PATH, "shared texture authority")
	_expect_close(Stage1GaksitalFanProjectileContract.SPEED, 5.5, "shared fan speed")
	_expect_close(Stage1GaksitalFanProjectileContract.SPIN_PER_FRAME, 0.3, "shared spin speed")
	_expect_close(Stage1GaksitalFanProjectileContract.HIT_RADIUS, 24.0, "shared hit radius")
	_expect(boss_source.contains("Stage1GaksitalFanProjectileContract.build_projectile"), "boss throw must build through shared authority")
	_expect(player_source.contains("Stage1GaksitalFanProjectileContract.build_projectile"), "player throw must build through shared authority")
	for forbidden_sibling in ["const FAN_SPEED", "const FAN_VX_JITTER", "const FAN_SPIN_PER_FRAME", "const FAN_HIT_RADIUS", "const PLAYER_STUN_FRAMES", "const PLAYER_KNOCKBACK_POWER"]:
		_expect(not boss_source.contains(forbidden_sibling), "boss state must not retain sibling authority: %s" % forbidden_sibling)
		_expect(not player_source.contains(forbidden_sibling), "player state must not invent sibling authority: %s" % forbidden_sibling)
	_expect(contract_source.contains("play_gaksital_fan") and contract_source.contains("play_whipcrack"), "shared authority must own both original audio calls")
	_expect(renderer_source.contains("draw_projectiles") and renderer_source.contains("Vector2(0.0, 0.0)") and renderer_source.contains("Vector2(1.0, 1.0)"), "shared renderer must preserve normalized UV rotated quads")

	var boss_state := Stage1GaksitalFanThrowSkillState.new()
	boss_state.rng.seed = 4755
	var boss_context := {
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	_expect(boss_state.activate(boss_context), "baseline Gaksital boss throw must still activate")
	boss_state.update_and_collide(30.0, {}, boss_context, {})
	_expect_eq(boss_state.fans.size(), 1, "baseline boss throw must still launch one normal fan")
	var boss_fan: Dictionary = boss_state.fans[0]
	_expect_close(float(boss_fan.get("timer", 0.0)), Stage1GaksitalFanProjectileContract.DURATION_FRAMES, "boss throw duration remains shared")
	_expect_close(Vector2(float(boss_fan.get("vx", 0.0)), float(boss_fan.get("vy", 0.0))).length(), Stage1GaksitalFanProjectileContract.SPEED, "boss projectile speed remains shared", 0.81)


func _verify_production_wiring_and_cooldown_contract() -> void:
	for config: Object in [
		SmasherSkillConfig.new(),
		ViperSkillConfig.new(),
		CommandoSkillConfig.new(),
		BlacksmithSkillConfig.new(),
		OptimusSkillConfig.new(),
	]:
		_expect(config.unlock_and_equip_skill(SKILL_ID), "every character config must equip Gaksital Vision")
		_expect(config.is_skill_equipped(SKILL_ID), "common skill equip gate must pass")
		_expect_close(config.get_cooldown_seconds(SKILL_ID), 5.0, "base cooldown from common catalog")
		config.set_runtime_cooldown_multiplier(0.60)
		_expect_close(config.get_cooldown_seconds(SKILL_ID), 3.0, "cooldown reduction must apply to Gaksital Vision")

	var state := GaksitalVisionChosikState.new()
	state.cooldown_remaining = 5.0
	state.cooldown_duration = 5.0
	_expect_eq(state.advance_cooldowns_by_msec(1000), 1, "campfire-style millisecond advance must affect cooldown")
	_expect_close(state.cooldown_remaining, 4.0, "millisecond cooldown advance")
	_expect_eq(state.reduce_all_cooldowns_by_fraction(0.20), 1, "fractional cooldown accelerator must affect cooldown")
	_expect_close(state.cooldown_remaining, 3.0, "fractional cooldown reduction")
	state.reset_cooldowns()
	_expect_close(state.cooldown_remaining, 0.0, "instant cooldown reset")

	var registry := FakeRegistry.new({"gaksital_vision_chosik_state": state})
	var control_deps := BattleUpdatePlayerControlDepsBuilder.new().build_deps(registry, "smasher")
	_expect_eq(control_deps.get("gaksital_vision_chosik_state", null), state, "production player-control deps must expose state")
	var match_deps := BattleUpdateMatchPlayerSkillDepsBuilder.new().build_deps(registry, "smasher")
	_expect_eq(match_deps.get("gaksital_vision_chosik_state", null), state, "score/reset deps must expose state")

	var reset_source := FileAccess.get_file_as_string("res://scripts/core/match_reset_controller.gd")
	var score_source := FileAccess.get_file_as_string("res://scripts/core/match_score_event_controller.gd")
	var round_source := FileAccess.get_file_as_string("res://scripts/ball/ball_round_cleanup.gd")
	var campfire_source := FileAccess.get_file_as_string("res://scripts/items/active_item_campfire_runtime.gd")
	var instant_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_instant_rewards.gd")
	for source_text in [reset_source, score_source, round_source, campfire_source, instant_source]:
		_expect(source_text.contains("gaksital_vision_chosik_state"), "all reset/cooldown contracts must include Gaksital Vision")


func _has_choice(choices: Array, choice_id: String) -> bool:
	for value: Variant in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_close(
	actual: float,
	expected: float,
	label: String,
	tolerance: float = 0.001
) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %.4f, got %.4f" % [label, expected, actual])
