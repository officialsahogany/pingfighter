extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const DaljiVisionChosikState := preload("res://scripts/characters/dalji_vision_chosik_state.gd")
const DaljiVisionChosikRenderer := preload("res://scripts/characters/dalji_vision_chosik_renderer.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const WallBounceController := preload("res://scripts/ball/wall_bounce_controller.gd")
const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const VisionModifierInputProxy := preload("res://scripts/characters/vision_modifier_input_proxy.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const BattleSkillIconPaths := preload("res://scripts/resources/battle_skill_icon_paths.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const OptimusSkillConfig := preload("res://scripts/characters/optimus_skill_config.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var selected_character_type := "smasher"
	var special_gauge := 250.0
	var boss_pos := Vector2(330.0, 80.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeSkillConfig:
	extends RefCounted
	func is_skill_equipped(skill_id: String) -> bool:
		return skill_id == CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID

	func get_cooldown_seconds(_skill_id: String) -> float:
		return 32.0


class FakeAudio:
	extends RefCounted
	var whip_calls := 0
	var whipcrack_calls := 0
	func play_whip() -> void:
		whip_calls += 1
	func play_whipcrack(_volume: float = 1.0) -> void:
		whipcrack_calls += 1


class FakeBallIntensity:
	extends RefCounted
	var actor_id := ""
	var side := ""
	var tags: Dictionary = {}
	func register_contact(new_actor_id: String, new_side: String, new_tags: Dictionary = {}) -> void:
		actor_id = new_actor_id
		side = new_side
		tags = new_tags.duplicate(true)


class FakeBallEffects:
	extends RefCounted
	var pulse_kind := ""
	var pulse_calls := 0
	func register_hit_pulse(_pos: Vector2, _vel: Vector2, _intensity: float, kind: String) -> void:
		pulse_kind = kind
		pulse_calls += 1


class FakePaddleBounceController:
	extends RefCounted
	var result: Dictionary

	func _init(next_result: Dictionary) -> void:
		result = next_result

	func bounce(
		_paddle_x: float,
		_paddle_w: float,
		_is_player: bool,
		_context: Dictionary,
		_deps: Dictionary,
		_callbacks: Dictionary
	) -> Dictionary:
		return result.duplicate(true)


class FakeVisionReflectionState:
	extends RefCounted
	var observed_last_hit_by := ""
	func apply_ball_motion(
		ball_pos: Vector2,
		ball_vel: Vector2,
		_ball_size: float,
		_boss_pos: Vector2,
		_boss_width: float,
		_boss_height: float,
		last_hit_by: String
	) -> Dictionary:
		observed_last_hit_by = last_hit_by
		if last_hit_by != "boss":
			return {}
		return {
			"ball_pos": ball_pos + Vector2.UP,
			"ball_vel": Vector2(ball_vel.x + 2.0, -absf(ball_vel.y)),
			"dalji_vision_reflected": true,
			"dalji_vision_impact_pos": ball_pos,
		}


class FakeRuntimePerkState:
	extends RefCounted
	var runtime_skill_levels: Dictionary = {}
	var collected := 0
	func collect_star_points(amount: int, _character: String, _catalog: Object, _owner: Object, _registry: Object, _defer: bool) -> void:
		collected += amount


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


class FakeInputReader:
	extends RefCounted
	var suppress_calls := 0
	func get_snapshot() -> Dictionary:
		return {
			"left_pressed": true,
			"right_pressed": true,
			"up_pressed": true,
			"direction": 1.0,
			"power_smash_direction": -1,
			"blacksmith_swing_direction": 1,
		}
	func suppress_primary_pointer_until_release() -> void:
		suppress_calls += 1


func _init() -> void:
	_verify_seven_language_copy_and_timer_units()
	_verify_catalog_and_all_character_equip()
	_verify_strict_shift_command_and_ball_return()
	_verify_ball_update_owner_integration()
	_verify_real_ball_update_contract()
	_verify_reserved_offer_and_reward_box()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("dalji_vision_chosik_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_seven_language_copy_and_timer_units() -> void:
	var expected_names := {
		"ko": "달지 비전 · 연환팽이",
		"en": "Dalji Vision · Linked Tops",
		"zh": "达尔吉秘传 · 连环陀螺",
		"ja": "ダルジ秘伝・連環独楽",
		"es": "Visión de Dalji · Peonzas enlazadas",
		"pt-BR": "Visão de Dalji · Piões encadeados",
		"ru": "Тайное искусство Дальджи · Связанные волчки",
	}
	var expected_labels := {
		"ko": "연환팽이",
		"en": "Linked Tops",
		"zh": "连环陀螺",
		"ja": "連環独楽",
		"es": "Peonzas enlazadas",
		"pt-BR": "Piões encadeados",
		"ru": "Связанные волчки",
	}
	var expected_seconds := {
		"ko": "3.4초",
		"en": "3.4s",
		"zh": "3.4秒",
		"ja": "3.4秒",
		"es": "3.4s",
		"pt-BR": "3.4s",
		"ru": "3.4с",
	}
	var expected_any_ball_copy := {
		"ko": "누가 친 공이든",
		"en": "Any ball",
		"zh": "任何球",
		"ja": "どちらの球も",
		"es": "Cualquier pelota",
		"pt-BR": "Qualquer bola",
		"ru": "Любой мяч",
	}
	var effect_renderer := DaljiVisionChosikRenderer.new()
	var tooltip_renderer := SmasherSkillOrbTooltipRenderer.new()
	for language: String in expected_names:
		LanguageSettings.set_test_locale_override(language)
		var skill_data := CommonSkillCatalog.get_skill_data(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID)
		var unlock_data := CommonSkillCatalog.get_unlock_perk_data(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID)
		_expect_eq(str(skill_data.get("korean", "")), str(expected_names[language]), "%s Vision name should not fall back to English" % language)
		_expect(str(skill_data.get("description", "")).contains("7"), "%s skill tooltip should publish the seven-second duration" % language)
		_expect(str(skill_data.get("description", "")).contains("50%"), "%s skill tooltip should publish the top-hit speed boost" % language)
		_expect(str(skill_data.get("description", "")).contains("30%"), "%s skill tooltip should publish the first-wall speed boost" % language)
		_expect(str(skill_data.get("description", "")).contains(str(expected_any_ball_copy[language])), "%s skill tooltip should say that either side's ball can hit a top" % language)
		var manual_description := str((unlock_data.get("descriptions", {}) as Dictionary).get(1, ""))
		_expect(manual_description.to_lower().contains(str(expected_any_ball_copy[language]).to_lower()), "%s manual tooltip should say that either side's ball can hit a top" % language)
		var rendered_description: Array[String] = tooltip_renderer._wrap_text(
			str(skill_data.get("description", "")),
			ThemeDB.fallback_font,
			12,
			SmasherSkillOrbTooltipRenderer.TOOLTIP_WIDTH - SmasherSkillOrbTooltipRenderer.PADDING * 2.0,
			int(skill_data.get("description_max_lines", 3))
		)
		_expect("\n".join(rendered_description).contains("30%"), "%s rendered three-line tooltip should keep the first-wall speed boost visible" % language)
		_expect(str(skill_data.get("how_to_use", "")).contains("W"), "%s input copy should publish Shift+W" % language)
		_expect(manual_description.contains("7"), "%s manual tooltip should publish the seven-second duration" % language)
		_expect_eq(CommonSkillCatalog.get_dalji_vision_timer_label(), str(expected_labels[language]), "%s timer label" % language)
		_expect_eq(effect_renderer._format_seconds(3.4), str(expected_seconds[language]), "%s timer seconds unit" % language)
	LanguageSettings.set_test_locale_override("ko")
	var control_rows: Array = SmasherSkillOrbTooltipRenderer.COMMON_CONTROL_ROWS.get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID, [])
	_expect(control_rows.size() == 1 and str(control_rows).contains("W") and str(control_rows).contains("↑"), "Dalji Vision tooltip should show one Shift+W/Up command row")


func _verify_catalog_and_all_character_equip() -> void:
	var optimus_owner := FakeOwner.new()
	optimus_owner.selected_character_type = "io"
	_expect_eq(RuntimePerkCharacterContext.new().get_owner_character_type(optimus_owner), "optimus", "Io owner aliases should route common unlocks to the Optimus config")
	var skill_data := CommonSkillCatalog.get_skill_data(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID)
	_expect_eq(str(skill_data.get("korean", "")), "달지 비전 · 연환팽이", "confirmed Korean name")
	_expect_close(float(skill_data.get("cost", 0.0)), 120.0, "skill cost")
	_expect_close(float(skill_data.get("cooldown", 0.0)), 32.0, "skill cooldown")
	var unlock_data := CommonSkillCatalog.get_unlock_perk_data(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID)
	_expect(bool(unlock_data.get("vision_chosik", false)), "unlock should be classified as Vision Chosik")
	_expect_eq(str(unlock_data.get("character_restriction", "")), "", "Vision Chosik should have no character restriction")
	var manual_path := str(RuntimePerkIconRenderer.MANUAL_ICON_PATHS.get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID, ""))
	var orb_path := str(RuntimePerkIconRenderer.SKILL_ICON_PATHS.get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID, ""))
	_expect_eq(manual_path, "res://assets/sprites/perks/dalji_vision_chain_top_manual_icon_imagegen_v1.png", "unlock card should use the dedicated manual-book art")
	_expect_eq(orb_path, "res://assets/sprites/skills/dalji_vision_chain_top_skill_orb_imagegen_v1.png", "equipped skill should use the dedicated orb art")
	_expect(manual_path != orb_path, "manual and equipped skill must remain separate visual assets")
	_expect_eq(str(BattleSkillIconPaths.SMASHER_SKILL_ICON_PATHS.get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID, "")), orb_path, "Smasher battle HUD should route to the Vision orb PNG")
	_expect_eq(str(BattleSkillIconPaths.VIPER_SKILL_ICON_PATHS.get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID, "")), orb_path, "Viper battle HUD should route to the Vision orb PNG")
	_expect_eq(str(BattleSkillIconPaths.COMMANDO_SKILL_ICON_PATHS.get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID, "")), orb_path, "Commando battle HUD should route to the Vision orb PNG")
	_verify_transparent_icon(manual_path, Vector2i(256, 256), "manual-book")
	_verify_transparent_icon(orb_path, Vector2i(512, 512), "skill-orb")
	for compatibility_config: Object in [BlacksmithSkillConfig.new(), OptimusSkillConfig.new()]:
		var empty_snapshot: Dictionary = compatibility_config.get_snapshot()
		_expect(not bool(empty_snapshot.get("cooldown_reduction_eligible", true)), "a compatibility config without an equipped timed Chosik should remain cooldown-ineligible")
		_expect((empty_snapshot.get("cooldown_seconds", {}) as Dictionary).is_empty(), "an empty compatibility config must not invent a live cooldown")
	for config: Object in [SmasherSkillConfig.new(), ViperSkillConfig.new(), CommandoSkillConfig.new(), BlacksmithSkillConfig.new(), OptimusSkillConfig.new()]:
		_expect(config.unlock_and_equip_skill(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID), "every character config should equip Dalji Vision Chosik")
		_expect(config.is_skill_equipped(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID), "equipped common skill should pass the final activation gate")
		_expect_close(config.get_cooldown_seconds(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID), 32.0, "every character should expose the common cooldown")
		config.set_runtime_cooldown_multiplier(0.60)
		_expect_close(config.get_cooldown_seconds(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID), 19.2, "Breath-Regulating Inner Art Lv.5 should reduce Dalji Vision cooldown by 40 percent")
		var equipped_snapshot: Dictionary = config.get_snapshot()
		_expect_close(float((equipped_snapshot.get("cooldown_seconds", {}) as Dictionary).get(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID, 0.0)), 19.2, "Dalji Vision HUD metadata should publish the reduced live cooldown")


func _verify_strict_shift_command_and_ball_return() -> void:
	var base_input_reader := FakeInputReader.new()
	var modifier_proxy: Object = VisionModifierInputProxy.new().configure(base_input_reader)
	var locked_snapshot: Dictionary = modifier_proxy.get_snapshot()
	_expect(not bool(locked_snapshot.get("left_pressed", true)), "Vision modifier should consume left input before the character command pool")
	_expect(not bool(locked_snapshot.get("right_pressed", true)), "Vision modifier should consume right input before the character command pool")
	_expect(not bool(locked_snapshot.get("up_pressed", true)), "Vision modifier should consume W/Up input before the character command pool")
	_expect_close(float(locked_snapshot.get("direction", 1.0)), 0.0, "Vision modifier should lock horizontal movement")
	_expect_eq(int(locked_snapshot.get("power_smash_direction", 1)), 0, "Vision modifier should suppress Smasher direction commands")
	_expect_eq(int(locked_snapshot.get("blacksmith_swing_direction", 1)), 0, "Vision modifier should suppress Blacksmith direction commands")
	modifier_proxy.suppress_primary_pointer_until_release()
	_expect_eq(base_input_reader.suppress_calls, 1, "Vision modifier proxy should forward pointer-release suppression to the real input reader")
	var state := DaljiVisionChosikState.new()
	_expect(not state.is_ready(119.0), "119 vigor should remain below the activation cost")
	_expect(state.is_ready(120.0), "120 vigor should meet the activation cost")
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var config := {
		"ball_active": true,
		"special_gauge": owner.special_gauge,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}
	var deps := {"owner": owner, "skill_config": FakeSkillConfig.new(), "audio": audio}
	var without_shift := state.update(0.01, {"up_pressed": true}, false, Vector2(300.0, 700.0), config, deps)
	_expect(not bool(without_shift.get("activated", false)), "W without Shift must not activate the Vision Chosik")
	state.update(0.01, {}, false, Vector2(300.0, 700.0), config, deps)
	var lateral_input := state.update(0.01, {"left_pressed": true}, true, Vector2(300.0, 700.0), config, deps)
	_expect(not bool(lateral_input.get("activated", false)), "Shift+A must not activate Linked Tops")
	var activation := state.update(0.01, {"up_pressed": true}, true, Vector2(300.0, 700.0), config, deps)
	_expect(bool(activation.get("activated", false)), "Shift+W/Up should activate")
	_expect(state.is_movement_locked(), "activation should lock movement for the cast")
	_expect_close(owner.special_gauge, 130.0, "activation should consume 120 vigor")
	_expect_eq(state.tops.size(), 2, "activation should launch two tops")
	_expect_eq(audio.whip_calls, 1, "activation should play the whip launch cue once")
	var first_top: Dictionary = state.tops[0]
	_expect(bool(first_top.get("launched", false)), "tops should use Dalji's launched-top payload")
	_expect_close(float(first_top.get("lifetime", 0.0)), 7.0, "tops should remain for seven seconds")
	_expect_close(state.get_active_duration_ratio(), 1.0, "seven-second field duration should publish a full timer ratio on activation")
	_expect_close(state.get_active_duration_remaining_sec(), 7.0, "duration HUD should publish seven remaining seconds on activation")
	_expect(not bool(first_top.get("is_golden", true)), "the inherited player Chosik should use Dalji's normal top design")
	_expect_close(float(first_top.get("y", 0.0)), 650.0, "production-height spawn should align with the roaming band")
	_expect(float(first_top.get("vy", 0.0)) < 0.0, "spawn should retain its upward Dalji-style launch velocity")
	state.update(1.0 / 60.0, {}, false, Vector2(300.0, 700.0), config, deps)
	first_top = state.tops[0] as Dictionary
	_expect(float(first_top.get("y", 650.0)) < 650.0, "the first launch frame should rise instead of clamping at the band edge")
	_expect(float(first_top.get("vy", 0.0)) < 0.0, "the first launch frame must not flip vertical direction")
	var first_top_pos := Vector2(float(first_top.get("x", 0.0)), float(first_top.get("y", 0.0)))
	var player_ball_state := DaljiVisionChosikState.new()
	player_ball_state.tops = [
		_make_runtime_top(first_top_pos),
		_make_runtime_top(first_top_pos + Vector2(120.0, 0.0)),
	]
	player_ball_state.set_reflection_roll_for_tests(func() -> float: return 1.0)
	var outgoing := player_ball_state.apply_ball_motion(
		first_top_pos,
		Vector2(0.0, -10.0),
		28.0,
		Vector2(330.0, 80.0),
		100.0,
		40.0,
		"player"
	)
	_expect(bool(outgoing.get("dalji_vision_reflected", false)), "a player-hit outgoing ball should collide with a top")
	var outgoing_velocity: Vector2 = outgoing.get("ball_vel", Vector2.ZERO)
	_expect_close(outgoing_velocity.length(), 15.0, "a player-owned ball should receive the same 50-percent top boost")
	_expect(outgoing_velocity.x > 0.0, "a player-owned ball should begin the same wallward bank shot")
	var chained := player_ball_state.apply_ball_motion(
		first_top_pos + Vector2(120.0, 0.0),
		outgoing_velocity,
		28.0,
		Vector2(330.0, 80.0),
		100.0,
		40.0,
		"player"
	)
	var chained_velocity: Vector2 = chained.get("ball_vel", Vector2.ZERO)
	_expect_close(chained_velocity.length(), 22.5, "two top contacts may stack their 50-percent boosts")
	player_ball_state.consume_wall_rebound_speed_boost(
		chained_velocity,
		"right",
		22.5,
		1.0
	)
	_expect_close(
		float(player_ball_state.get_snapshot().get("boss_guard_restore_effective_speed", 0.0)),
		10.0,
		"stacked player-ball top hits should still restore the speed from before the first top"
	)
	state.set_reflection_roll_for_tests(func() -> float: return 1.0)
	var reflected := state.apply_ball_motion(
		first_top_pos,
		Vector2(0.0, 10.0),
		28.0,
		Vector2(330.0, 80.0),
		100.0,
		40.0,
		"boss"
	)
	_expect(bool(reflected.get("dalji_vision_reflected", false)), "a boss-hit incoming ball should reflect on contact")
	var reflected_velocity: Vector2 = reflected.get("ball_vel", Vector2.ZERO)
	_expect_close(reflected_velocity.length(), 15.0, "top contact should increase the incoming ball speed by exactly 50 percent")
	_expect(reflected_velocity.x > 0.0 and reflected_velocity.y < 0.0, "the deterministic right-bank roll should begin a strong wallward curve")
	_expect_eq(str(state.get_snapshot().get("pending_wall_boost_side", "")), "right", "top contact should arm exactly the targeted wall")
	_expect(state.consume_wall_rebound_speed_boost(reflected_velocity, "left").is_empty(), "the opposite wall must not consume the armed rebound boost")
	var frame_motion_controller := BallFrameMotionController.new()
	var held_curve_scene := {
		"ball_vel": reflected_velocity,
		"skip_ball_motion_step": true,
	}
	frame_motion_controller.update_dalji_vision_ball_modifiers(
		held_curve_scene,
		1.0,
		{"dalji_vision_chosik_state": state}
	)
	_expect_eq(held_curve_scene.get("ball_vel", Vector2.ZERO), reflected_velocity, "owner-controlled hold frames must not advance the curve")
	var curve_scene := {"ball_vel": reflected_velocity}
	var curve_duration := float(state.get_snapshot().get("wall_curve_duration_frames", 10.0))
	for _curve_frame in range(ceili(curve_duration * 0.68)):
		frame_motion_controller.update_dalji_vision_ball_modifiers(
			curve_scene,
			1.0,
			{"dalji_vision_chosik_state": state}
		)
	var curved_velocity: Vector2 = curve_scene.get("ball_vel", Vector2.ZERO)
	_expect_close(curved_velocity.length(), reflected_velocity.length(), "the wallward curve should preserve the top-contact speed")
	_expect(curved_velocity.x > 0.0 and curved_velocity.y > 0.0, "the wallward path should visibly bend across its arc without turning away from the target wall")
	_expect(curved_velocity.normalized().dot(reflected_velocity.normalized()) < 0.75, "the pre-wall trajectory should form a strong curve instead of a nearly straight line")

	var wall_scene := {
		"ball_pos": Vector2(746.0, first_top_pos.y),
		"ball_vel": curved_velocity,
		"ball_impact_boost": 1.25,
	}
	var wall_processor := BallMotionEventProcessor.new()
	var wall_controller := WallBounceController.new()
	_expect(not wall_processor._process_wall({
		"side": "right",
		"impact_pos": Vector2(760.0, first_top_pos.y),
	}, wall_scene, {"height": 750.0}, {
		"wall_bounce_controller": wall_controller,
		"dalji_vision_chosik_state": state,
	}), "the linked-top bank shot should not request a rematch")
	var first_wall_velocity: Vector2 = wall_scene.get("ball_vel", Vector2.ZERO)
	_expect_close(first_wall_velocity.length(), 15.0 * 1.30, "the armed first wall rebound should leave the wall at exactly 30 percent more speed")
	_expect(first_wall_velocity.x < 0.0 and first_wall_velocity.y < 0.0, "the first wall rebound should leave the wall and travel bossward")
	_expect(bool(wall_scene.get("dalji_vision_wall_rebound_boosted", false)), "the production wall path should publish the one-shot linked-top boost")
	_expect_close(BallFrameMotionController.new()._get_effective_speed_cap(
		{"max_ball_speed": 10.0},
		1.0,
		{"dalji_vision_chosik_state": state}
	), 19.5, "the temporary linked-top cap should preserve the explicit speed multipliers")
	_expect_close(
		float(state.get_snapshot().get("boss_guard_restore_effective_speed", 0.0)),
		10.0 * 1.25,
		"the wall hit should remember the effective speed from before both linked-top boosts"
	)
	var straight_scene := {"ball_vel": first_wall_velocity}
	for _straight_frame in range(8):
		frame_motion_controller.update_dalji_vision_ball_modifiers(
			straight_scene,
			1.0,
			{"dalji_vision_chosik_state": state}
		)
	var straight_velocity: Vector2 = straight_scene.get("ball_vel", Vector2.ZERO)
	_expect_close(straight_velocity.length(), first_wall_velocity.length(), "post-wall straight flight should preserve the boosted speed")
	_expect(straight_velocity.normalized().dot(first_wall_velocity.normalized()) > 0.999, "the wall rebound should disable curvature and continue as a straight shot")
	var guard_scene := wall_scene.duplicate(true)
	var guarded_direction := Vector2(0.25, 1.0).normalized()
	var guard_committed := wall_processor._process_paddle({
		"is_player": false,
		"paddle_x": 330.0,
		"paddle_w": 100.0,
	}, guard_scene, {"paddle_width": 100.0}, {
		"paddle_bounce_controller": FakePaddleBounceController.new({
			"ball_vel": guarded_direction * 27.0,
			"normal_boss_bounce_committed": true,
		}),
		"dalji_vision_chosik_state": state,
	}, {})
	_expect(guard_committed, "the production boss-guard path should commit the linked-top return")
	var restored_guard_velocity: Vector2 = guard_scene.get("ball_vel", Vector2.ZERO)
	_expect_close(restored_guard_velocity.length(), 10.0, "boss guard should remove both the top-contact and first-wall speed gains")
	_expect(restored_guard_velocity.normalized().dot(guarded_direction) > 0.999, "boss guard speed restore should preserve the committed rebound direction")
	_expect_close(float(state.get_snapshot().get("boss_guard_restore_effective_speed", -1.0)), 0.0, "boss guard should consume the stored speed exactly once")
	_expect_close(state.get_boosted_ball_speed_cap(), 0.0, "boss guard should close the linked-top temporary speed cap")

	wall_scene.erase("dalji_vision_wall_rebound_boosted")
	wall_scene["ball_pos"] = Vector2(14.0, first_top_pos.y)
	wall_processor._process_wall({
		"side": "left",
		"impact_pos": Vector2(0.0, first_top_pos.y),
	}, wall_scene, {"height": 750.0}, {
		"wall_bounce_controller": wall_controller,
		"dalji_vision_chosik_state": state,
	})
	var second_wall_velocity: Vector2 = wall_scene.get("ball_vel", Vector2.ZERO)
	_expect_close(second_wall_velocity.length(), first_wall_velocity.length() * 0.95, "later wall rebounds should receive only normal wall damping")
	_expect(not bool(wall_scene.get("dalji_vision_wall_rebound_boosted", false)), "the 30-percent wall boost must be consumed exactly once")
	var start_positions: Array[Vector2] = []
	for top_value: Variant in state.tops:
		var top := top_value as Dictionary
		start_positions.append(Vector2(float(top.get("x", 0.0)), float(top.get("y", 0.0))))
	for _frame in range(406):
		state.update(1.0 / 60.0, {}, false, Vector2(300.0, 700.0), config, deps)
	_expect_eq(state.tops.size(), 2, "both tops should still exist just before seven seconds")
	_expect(state.get_active_duration_ratio() > 0.0 and state.get_active_duration_ratio() < 0.06, "duration timer should track the last fraction of the seven-second field")
	for index in range(state.tops.size()):
		var roaming_top := state.tops[index] as Dictionary
		var roaming_pos := Vector2(float(roaming_top.get("x", 0.0)), float(roaming_top.get("y", 0.0)))
		_expect(roaming_pos.distance_to(start_positions[index]) > 20.0, "tops should roam after their Dalji-style launch")
		_expect(roaming_pos.x >= 40.0 and roaming_pos.x <= 720.0, "roaming tops should stay inside the horizontal field")
		_expect(roaming_pos.y >= 70.0 and roaming_pos.y <= 650.0, "roaming tops should stay inside the vertical field")
	for _frame in range(20):
		state.update(1.0 / 60.0, {}, false, Vector2(300.0, 700.0), config, deps)
	_expect(state.tops.is_empty(), "tops should disappear after about seven seconds")
	var cooldown_before_reset := state.cooldown_remaining
	state.reset_round()
	_expect_close(state.cooldown_remaining, cooldown_before_reset, "round cleanup should preserve cooldown")
	_expect(state.tops.is_empty(), "round cleanup should clear detached tops")
	_expect_close(state.get_boosted_ball_speed_cap(), 0.0, "round cleanup should clear the linked-top overspeed cap")
	state.reset()
	_expect_close(state.cooldown_remaining, 0.0, "full reset should clear cooldown")


func _verify_ball_update_owner_integration() -> void:
	var controller := BallUpdateController.new()
	var state := FakeVisionReflectionState.new()
	var intensity := FakeBallIntensity.new()
	var audio := FakeAudio.new()
	var effects := FakeBallEffects.new()
	var scene := {
		"ball_pos": Vector2(320.0, 360.0),
		"ball_vel": Vector2(1.0, 10.0),
		"ball_size": 28.0,
		"ball_serve_origin": "boss",
	}
	controller._apply_dalji_vision_chosik(scene, {
		"last_hit_by": "",
		"boss_pos": Vector2(330.0, 80.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}, {
		"dalji_vision_chosik_state": state,
		"ball_intensity": intensity,
		"audio": audio,
		"ball_effects": effects,
	})
	_expect_eq(state.observed_last_hit_by, "boss", "ball update should treat a boss serve as boss-owned until the first rally contact")
	_expect_eq(intensity.side, "player", "a top reflection should become the next player-side rally contact")
	_expect_eq(intensity.actor_id, "dalji_vision_chain_top", "rally contact should retain the Chosik actor identity")
	_expect(bool(intensity.tags.get("reflection", false)), "rally contact should identify the reflection event")
	_expect_eq(audio.whipcrack_calls, 1, "production reflection hook should play one impact cue")
	_expect_eq(effects.pulse_kind, "dalji_vision_chain_top", "production reflection hook should emit the Chosik hit pulse")
	var committed_velocity: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	_expect(committed_velocity.y < 0.0, "production hook should commit the reflected velocity")


func _verify_real_ball_update_contract() -> void:
	var controller := BallUpdateController.new()
	var state := DaljiVisionChosikState.new()
	state.set_reflection_roll_for_tests(func() -> float: return 0.5)
	state.tops = [
		_make_runtime_top(Vector2(320.0, 360.0)),
		_make_runtime_top(Vector2(500.0, 360.0)),
	]
	var intensity := BallIntensity.new()
	intensity.register_hit("boss")
	var audio := FakeAudio.new()
	var effects := FakeBallEffects.new()
	var deps := {
		"dalji_vision_chosik_state": state,
		"ball_intensity": intensity,
		"audio": audio,
		"ball_effects": effects,
	}
	var context := {
		"last_hit_by": "boss",
		"boss_pos": Vector2(330.0, 80.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var held_pos := Vector2(320.0, 360.0)
	var held_vel := Vector2(1.0, 10.0)
	var held_scene := {
		"ball_pos": held_pos,
		"ball_vel": held_vel,
		"ball_size": 28.0,
		"skip_ball_motion_step": true,
	}
	controller._apply_dalji_vision_chosik(held_scene, context, deps)
	_expect_eq(held_scene.get("ball_pos", Vector2.ZERO), held_pos, "owned-ball hold should preserve its projected position")
	_expect_eq(held_scene.get("ball_vel", Vector2.ZERO), held_vel, "owned-ball hold should preserve its owner-controlled velocity")
	_expect_eq(intensity.get_last_hit_by(), "boss", "owned-ball hold must not corrupt rally ownership")
	_expect_eq(intensity.get_rally_exchange_count(), 0, "owned-ball hold must not invent a rally exchange")
	_expect_eq(intensity.get_rally_contact_count(), 1, "owned-ball hold must not register a fake contact")
	_expect_eq(audio.whipcrack_calls, 0, "owned-ball hold must remain silent")
	_expect_eq(effects.pulse_calls, 0, "owned-ball hold must not emit a hit pulse")
	_expect_close(float((state.tops[0] as Dictionary).get("collision_cooldown", -1.0)), 0.0, "owned-ball hold must not consume top collision cooldown")

	var live_scene := held_scene.duplicate(true)
	live_scene["skip_ball_motion_step"] = false
	controller._apply_dalji_vision_chosik(live_scene, context, deps)
	_expect_eq(intensity.get_last_hit_by(), "player", "real top reflection should hand rally ownership to the player")
	_expect_eq(intensity.get_rally_exchange_count(), 1, "real top reflection should add exactly one exchange")
	_expect_eq(audio.whipcrack_calls, 1, "real top reflection should play one crack")
	_expect_eq(effects.pulse_calls, 1, "real top reflection should emit one pulse")
	_expect(float((state.tops[0] as Dictionary).get("collision_cooldown", 0.0)) > 0.0, "the colliding top should arm its own cooldown")

	var player_state := DaljiVisionChosikState.new()
	player_state.set_reflection_roll_for_tests(func() -> float: return 0.0)
	player_state.tops = [_make_runtime_top(Vector2(500.0, 360.0))]
	var player_intensity := BallIntensity.new()
	player_intensity.register_hit("player")
	var player_audio := FakeAudio.new()
	var player_effects := FakeBallEffects.new()
	var player_scene := {
		"ball_pos": Vector2(500.0, 360.0),
		"ball_vel": Vector2(0.0, -10.0),
		"ball_size": 28.0,
		"skip_ball_motion_step": false,
	}
	var player_context := context.duplicate(true)
	player_context["last_hit_by"] = "player"
	controller._apply_dalji_vision_chosik(player_scene, player_context, {
		"dalji_vision_chosik_state": player_state,
		"ball_intensity": player_intensity,
		"audio": player_audio,
		"ball_effects": player_effects,
	})
	var player_reflected_velocity: Vector2 = player_scene.get("ball_vel", Vector2.ZERO)
	_expect_close(player_reflected_velocity.length(), 15.0, "production player-owned contact should receive the 50-percent top boost")
	_expect_eq(player_intensity.get_last_hit_by(), "player", "player-owned top contact should preserve player rally ownership")
	_expect_eq(player_intensity.get_rally_exchange_count(), 0, "player-owned top contact must not invent a side exchange")
	_expect_eq(player_intensity.get_rally_contact_count(), 2, "player-owned top contact should register one real skill contact")
	_expect_eq(player_audio.whipcrack_calls, 1, "player-owned top contact should play its impact cue")
	_expect_eq(player_effects.pulse_calls, 1, "player-owned top contact should emit its hit pulse")

	intensity.register_hit("boss")
	var cooldown_scene := {
		"ball_pos": Vector2(320.0, 360.0),
		"ball_vel": Vector2(0.0, 10.0),
		"ball_size": 28.0,
		"skip_ball_motion_step": false,
	}
	var cooldown_scene_before := cooldown_scene.duplicate(true)
	controller._apply_dalji_vision_chosik(cooldown_scene, context, deps)
	_expect_eq(cooldown_scene, cooldown_scene_before, "a top on collision cooldown should not reflect again")
	_expect_eq(audio.whipcrack_calls, 1, "collision cooldown should suppress repeat audio")

	var second_top_scene := {
		"ball_pos": Vector2(500.0, 360.0),
		"ball_vel": Vector2(0.0, 10.0),
		"ball_size": 28.0,
		"skip_ball_motion_step": false,
	}
	controller._apply_dalji_vision_chosik(second_top_scene, context, deps)
	_expect_eq(audio.whipcrack_calls, 2, "the independent second top should still reflect")
	_expect(float((state.tops[1] as Dictionary).get("collision_cooldown", 0.0)) > 0.0, "the second top should own an independent collision cooldown")


func _make_runtime_top(pos: Vector2) -> Dictionary:
	return {
		"x": pos.x,
		"y": pos.y,
		"launched": true,
		"collision_cooldown": 0.0,
		"tilt": 0.0,
		"rotation": 0.0,
		"rotation_speed": 20.0,
		"alpha": 255.0,
		"is_golden": false,
	}


func _verify_reserved_offer_and_reward_box() -> void:
	var catalog := RuntimePerkCatalog.new()
	var unreserved_choices := catalog.get_choices("smasher", {}, false, 3)
	_expect(not _has_choice(unreserved_choices, CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID), "Vision manual must not enter the ordinary random pool")
	_expect(catalog.reserve_boss_vision_offer(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID), "boss reward should reserve a valid Vision manual")
	var choices := catalog.get_choices("smasher", {}, false, 3)
	_expect_eq(str((choices[0] as Dictionary).get("id", "")), CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID, "reserved Vision manual should be the first card")
	_expect_eq(str((choices[0] as Dictionary).get("offer_lane", "")), "boss_vision_reserved", "reserved card should expose its boss reward lane")
	var full_catalog := RuntimePerkCatalog.new()
	full_catalog.set_full_chosik_swap_offer_roll_for_tests(func() -> float: return 1.0)
	full_catalog.reserve_boss_vision_offer(CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID)
	var full_choices := full_catalog.get_choices("smasher", {
		"unlock_plasma": 1,
		"unlock_recovery_skill": 1,
		"unlock_cleanse": 1,
	}, false, 3)
	_expect_eq(str((full_choices[0] as Dictionary).get("id", "")), CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID, "boss reservation must bypass the ordinary full-Chosik random gate")

	var loot_state := VictoryLootPhaseState.new()
	loot_state._plan_builder = FakePlanBuilder.new()
	loot_state.set_vision_offer_roll_for_tests(func() -> float: return 0.1999)
	var runtime_state := FakeRuntimePerkState.new()
	var reward_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({"runtime_perk_state": runtime_state, "runtime_perk_catalog": reward_catalog})
	var owner := FakeOwner.new()
	_expect(loot_state.start(owner, registry, 3, 0, Callable()), "Dalji victory should start loot phase")
	_expect_eq(int(loot_state.get_status_for_tests().get("vision_offer_box_count", 0)), 1, "one screen-level success roll should mark exactly one box")
	var vision_box: Dictionary = {}
	for box_value: Variant in loot_state.boxes:
		if box_value is Dictionary and str((box_value as Dictionary).get("boss_vision_offer_id", "")) != "":
			vision_box = box_value as Dictionary
			break
	var vision_box_sheet_path := loot_state.get_box_sheet_path_for_tests(vision_box)
	_expect_eq(vision_box_sheet_path, VictoryLootPhaseState.DALJI_VISION_BOX_SHEET_PATH, "Vision reward box should use the dedicated Dalji opening sheet")
	_verify_transparent_sheet(vision_box_sheet_path, Vector2i(4, 4), Vector2i(256, 256), "vision reward box")
	var threshold_miss_loot_state := VictoryLootPhaseState.new()
	threshold_miss_loot_state._plan_builder = FakePlanBuilder.new()
	threshold_miss_loot_state.set_vision_offer_roll_for_tests(func() -> float: return 0.20)
	threshold_miss_loot_state.start(FakeOwner.new(), registry, 3, 0, Callable())
	_expect_eq(int(threshold_miss_loot_state.get_status_for_tests().get("vision_offer_box_count", 0)), 0, "a roll at the exclusive 20-percent upper bound must miss")
	var gaksi_loot_state := VictoryLootPhaseState.new()
	gaksi_loot_state._plan_builder = FakePlanBuilder.new()
	gaksi_loot_state.set_vision_offer_roll_for_tests(func() -> float: return 0.0)
	var gaksi_owner := FakeOwner.new()
	gaksi_owner.stage1_boss_variant = "gaksi"
	gaksi_loot_state.start(gaksi_owner, registry, 3, 0, Callable())
	_expect_eq(int(gaksi_loot_state.get_status_for_tests().get("vision_offer_box_count", 0)), 0, "Gaksi victory must not drop Dalji's manual")
	var owned_loot_state := VictoryLootPhaseState.new()
	owned_loot_state._plan_builder = FakePlanBuilder.new()
	owned_loot_state.set_vision_offer_roll_for_tests(func() -> float: return 0.0)
	runtime_state.runtime_skill_levels[CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID] = 1
	owned_loot_state.start(FakeOwner.new(), registry, 3, 0, Callable())
	_expect_eq(int(owned_loot_state.get_status_for_tests().get("vision_offer_box_count", 0)), 0, "owned Vision manual must not drop again")
	runtime_state.runtime_skill_levels.clear()

	var resolver := StageClearRewardResolver.new()
	var summary := resolver.grant_rewards([{
		"type": "starpoint",
		"amount": 1,
		"reserved_perk_offer_id": CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID,
	}], owner, registry)
	_expect_eq(int(summary.get("granted", 0)), 1, "Vision manual reward should grant one perk choice point")
	_expect(reward_catalog.has_reserved_boss_vision_offer(), "reward resolver should reserve the boss Vision choice before opening it")
	_expect_eq(runtime_state.collected, 1, "reward should collect exactly one choice point")


func _has_choice(choices: Array, choice_id: String) -> bool:
	for value: Variant in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _verify_transparent_icon(path: String, expected_size: Vector2i, label: String) -> void:
	var texture: Texture2D = load(path) as Texture2D
	_expect(texture != null, "%s PNG should load as Texture2D" % label)
	if texture == null:
		return
	var image: Image = texture.get_image()
	_expect(image != null and not image.is_empty(), "%s texture should expose image data" % label)
	if image == null or image.is_empty():
		return
	_expect_eq(image.get_size(), expected_size, "%s PNG dimensions" % label)
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(expected_size.x - 1, 0), Vector2i(0, expected_size.y - 1), expected_size - Vector2i.ONE]:
		_expect(image.get_pixelv(corner).a <= 0.01, "%s PNG corners must be transparent" % label)
	var used_rect := image.get_used_rect()
	_expect(used_rect.position.x > 0 and used_rect.position.y > 0, "%s visible alpha bounds should not touch the top or left edge" % label)
	_expect(used_rect.end.x < expected_size.x and used_rect.end.y < expected_size.y, "%s visible alpha bounds should not touch the bottom or right edge" % label)


func _verify_transparent_sheet(path: String, grid: Vector2i, cell_size: Vector2i, label: String) -> void:
	var texture: Texture2D = load(path) as Texture2D
	_expect(texture != null, "%s sheet should load as Texture2D" % label)
	if texture == null:
		return
	var image: Image = texture.get_image()
	_expect(image != null and not image.is_empty(), "%s sheet should expose image data" % label)
	if image == null or image.is_empty():
		return
	_expect_eq(image.get_size(), grid * cell_size, "%s sheet dimensions" % label)
	for row in range(grid.y):
		for column in range(grid.x):
			var cell := image.get_region(Rect2i(Vector2i(column, row) * cell_size, cell_size))
			var used_rect := cell.get_used_rect()
			_expect(not used_rect.has_area() or (used_rect.position.x > 0 and used_rect.position.y > 0), "%s frame %d,%d alpha should not touch top or left" % [label, column, row])
			_expect(not used_rect.has_area() or (used_rect.end.x < cell_size.x and used_rect.end.y < cell_size.y), "%s frame %d,%d alpha should not touch bottom or right" % [label, column, row])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.3f, got %.3f" % [message, expected, actual])
