extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const BattleSkillIconPaths := preload("res://scripts/resources/battle_skill_icon_paths.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const YeonmyoVisionChosikState := preload("res://scripts/characters/yeonmyo_vision_chosik_state.gd")

const SKILL_ID := "yeonmyo_vision_bonghongwe"
const UNLOCK_ID := "unlock_yeonmyo_vision_bonghongwe"
const SOURCE := "yeonmyo_vision_bonghongwe"
const RENDERER_SOURCE_PATH := "res://scripts/characters/yeonmyo_vision_chosik_renderer.gd"
const ORB_ICON_PATH := "res://assets/sprites/skills/yeonmyo_vision_bonghongwe_skill_orb_imagegen_v1.png"
const MANUAL_ICON_PATH := "res://assets/sprites/perks/yeonmyo_vision_bonghongwe_manual_icon_imagegen_v1.png"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var selected_character_type := "smasher"
	var current_stage := 3
	var special_gauge := 250.0
	var boss_pos := Vector2(330.0, 42.0)
	var boss_pos_prev := Vector2(330.0, 42.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_interp_last_physics_usec := 0
	var weather_event_active := false


class FakeSkillConfig:
	extends RefCounted
	func is_skill_equipped(skill_id: String) -> bool:
		return skill_id == SKILL_ID

	func get_cooldown_seconds(_skill_id: String) -> float:
		return 35.0


class FakeAudio:
	extends RefCounted
	var whip_calls := 0
	var dollcurse_calls := 0
	var chest_land_calls := 0
	func play_whip() -> void:
		whip_calls += 1
	func play_stage3_dollcurse() -> void:
		dollcurse_calls += 1
	func play_stage3_chest_land() -> void:
		chest_land_calls += 1
	func stop_dash_delay() -> void:
		pass


func _init() -> void:
	_verify_catalog_and_debug_grant()
	_verify_icon_pair_registration()
	_verify_renderer_preserves_parent_transform()
	_verify_activation_landing_and_recast_block()
	_verify_closed_dash_opens_then_smoke_contact_confuses()
	_verify_smoke_requires_contact_and_respects_immunity()
	_verify_fading_smoke_is_visual_only()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("yeonmyo_vision_bonghongwe_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_debug_grant() -> void:
	_expect_eq(CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID, SKILL_ID, "canonical skill id")
	_expect_eq(CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID, UNLOCK_ID, "canonical unlock id")
	var data := CommonSkillCatalog.get_skill_data(SKILL_ID)
	_expect_eq(str(data.get("korean", "")), "연묘 비전 · 봉혼궤", "Korean display name")
	_expect_eq(float(data.get("cost", 0.0)), 200.0, "gauge cost")
	_expect_eq(float(data.get("cooldown", 0.0)), 35.0, "base cooldown")
	_expect(bool(data.get("vision_chosik", false)), "catalog vision marker")
	_expect_eq(CommonSkillCatalog.get_unlock_id_for_skill(SKILL_ID), UNLOCK_ID, "skill to unlock mapping")
	_expect_eq(CommonSkillCatalog.get_skill_id_for_unlock(UNLOCK_ID), SKILL_ID, "unlock to skill mapping")
	var expected_names := {
		"ko": "연묘 비전 · 봉혼궤",
		"en": "Yeonmyo Vision · Soul-Sealing Chest",
		"zh": "莲妙秘传 · 封魂柜",
		"ja": "蓮妙秘伝・封魂櫃",
		"es": "Visión de Yeonmyo · Cofre sellalmas",
		"pt-BR": "Visão de Yeonmyo · Baú sela-almas",
		"ru": "Тайное искусство Ёнмё · Ларец печати душ",
	}
	for language: String in expected_names:
		LanguageSettings.set_test_locale_override(language)
		var localized := CommonSkillCatalog.get_skill_data(SKILL_ID)
		_expect_eq(str(localized.get("korean", "")), str(expected_names[language]), "%s localized display name" % language)
		_expect(not str(localized.get("description", "")).is_empty(), "%s localized description" % language)
	var found_debug_entry := false
	for entry_value in RuntimePerkCatalog.new().get_debug_perk_entries():
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == UNLOCK_ID:
			found_debug_entry = str((entry_value as Dictionary).get("debug_group", "")) == "vision"
	_expect(found_debug_entry, "F4 debug grant should expose the Vision Chosik")


func _verify_icon_pair_registration() -> void:
	_expect(ResourceLoader.exists(ORB_ICON_PATH), "runtime Chosik orb PNG should exist")
	_expect(ResourceLoader.exists(MANUAL_ICON_PATH), "unlock perk manual PNG should exist")
	_expect(ResourceLoader.load(ORB_ICON_PATH) is Texture2D, "runtime Chosik orb PNG should load")
	_expect(ResourceLoader.load(MANUAL_ICON_PATH) is Texture2D, "unlock perk manual PNG should load")
	_expect_eq(str(RuntimePerkIconRenderer.SKILL_ICON_PATHS.get(SKILL_ID, "")), ORB_ICON_PATH, "perk renderer runtime icon path")
	_expect_eq(str(RuntimePerkIconRenderer.MANUAL_ICON_PATHS.get(UNLOCK_ID, "")), MANUAL_ICON_PATH, "perk renderer manual icon path")
	for icon_paths: Dictionary in [
		BattleSkillIconPaths.SMASHER_SKILL_ICON_PATHS,
		BattleSkillIconPaths.VIPER_SKILL_ICON_PATHS,
		BattleSkillIconPaths.COMMANDO_SKILL_ICON_PATHS,
	]:
		_expect_eq(str(icon_paths.get(SKILL_ID, "")), ORB_ICON_PATH, "shared battle icon map")
	var slot_renderer := SmasherSkillOrbSlotRenderer.new()
	_expect(
		slot_renderer._resolve_skill_icon_texture(SKILL_ID, {}) is Texture2D,
		"shared orb slot should select the Chosik PNG before procedural fallback"
	)
	var perk_renderer := RuntimePerkIconRenderer.new()
	_expect(perk_renderer.has_icon(SKILL_ID), "perk renderer should resolve the runtime Chosik PNG")
	_expect(perk_renderer.has_icon(UNLOCK_ID), "perk renderer should resolve the dedicated manual PNG")


func _verify_renderer_preserves_parent_transform() -> void:
	var renderer_source := FileAccess.get_file_as_string(RENDERER_SOURCE_PATH).replace("\r\n", "\n")
	_expect(not renderer_source.is_empty(), "should read Yeonmyo Vision renderer source")
	_expect(
		renderer_source.find("draw_set_transform") < 0,
		"Yeonmyo Vision renderer must not replace the active playfield transform"
	)
	_expect(
		renderer_source.find("draw_colored_polygon") >= 0,
		"Yeonmyo Vision rotated shapes should transform polygon points directly"
	)


func _verify_activation_landing_and_recast_block() -> void:
	var state := YeonmyoVisionChosikState.new()
	var status := StatusEffectState.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var deps := {
		"owner": owner,
		"skill_config": FakeSkillConfig.new(),
		"status_effect_state": status,
		"audio": audio,
	}
	var config := _base_player_config(owner)
	var result: Dictionary = state.update(0.0, {"down_pressed": true}, true, Vector2(300.0, 700.0), config, deps)
	_expect(bool(result.get("activated", false)), "Shift+S should activate")
	_expect_eq(float(result.get("special_gauge", -1.0)), 50.0, "activation spends 200 gauge once")
	_expect_eq(audio.dollcurse_calls, 1, "activation uses the curse-cast cue")
	_expect_eq(audio.whip_calls, 0, "specific curse-cast cue suppresses the whip fallback")
	state.update(0.41, {"down_pressed": false}, false, Vector2.ZERO, config, deps)
	var airborne := state.get_snapshot()
	_expect_eq(str(airborne.get("phase", "")), "throw", "chest remains airborne at half time")
	_expect(float(airborne.get("throw_height", 0.0)) > 140.0, "throw follows a high gravity arc")
	_expect(
		_as_vector2(airborne.get("chest_pos", Vector2.ZERO)).y
		< _as_vector2(airborne.get("throw_ground_pos", Vector2.ZERO)).y,
		"airborne chest is separated from its moving ground projection"
	)
	_expect(absf(float(airborne.get("throw_rotation", 0.0))) > 1.0, "airborne chest visibly tumbles")
	state.update(0.41, {"down_pressed": false}, false, Vector2.ZERO, config, deps)
	var landed := state.get_snapshot()
	_expect_eq(str(landed.get("phase", "")), "closed", "throw should land as a closed chest")
	_expect(not bool(landed.get("chest_opened", true)), "landing alone must not open the chest")
	_expect(not bool(landed.get("smoke_confusion_consumed", true)), "landing alone must not confuse the boss")
	_expect_eq(float(landed.get("active_remaining", 0.0)), 12.0, "chest lifetime")
	_expect_eq(audio.chest_land_calls, 1, "landing impact cue fires once")
	_expect(status.get_status("boss", "confusion").is_empty(), "landing emits no confusion")
	state.reset_cooldowns()
	state.update(0.0, {"down_pressed": false}, true, Vector2.ZERO, config, deps)
	var blocked: Dictionary = state.update(0.0, {"down_pressed": true}, true, Vector2.ZERO, config, deps)
	_expect(not bool(blocked.get("activated", false)), "active chest hard-blocks recast after cooldown reset")
	_expect_eq(owner.special_gauge, 50.0, "blocked recast does not spend gauge")


func _verify_closed_dash_opens_then_smoke_contact_confuses() -> void:
	var ai := BossAiState.new()
	ai.boss_dash_active = true
	ai.boss_dash_timer_frames = 10.0
	var status := StatusEffectState.new()
	var owner := FakeOwner.new()
	owner.boss_pos_prev = Vector2(130.0, 42.0)
	owner.boss_pos = Vector2(330.0, 50.0)
	var state := YeonmyoVisionChosikState.new()
	state.phase = "closed"
	state.active_remaining = 12.0
	state.chest_pos = Vector2(380.0, 70.0)
	var deps := {
		"owner": owner,
		"skill_config": FakeSkillConfig.new(),
		"boss_ai_state": ai,
		"status_effect_state": status,
		"audio": FakeAudio.new(),
	}
	state.update(0.0, {}, false, Vector2.ZERO, _base_player_config(owner), deps)
	_expect_eq(state.phase, "open", "dash contact opens the closed chest")
	_expect(state.chest_opened, "opened chest state is latched")
	_expect(state.smoke_confusion_consumed, "boss touching fresh smoke consumes its one confusion")
	_expect(not ai.boss_dash_active, "smoke contact cancels the active dash without recovery stun")
	_expect_eq(ai.boss_dash_stun_timer_frames, 0.0, "smoke contact adds no recovery stun")
	var confusion := status.get_status("boss", "confusion")
	_expect_eq(float(confusion.get("remaining_frames", 0.0)), 180.0, "smoke contact applies exactly 180 frames")
	_expect(not status.get_status_source("boss", "confusion", SOURCE).is_empty(), "smoke uses the owned status source")
	state.cooldown_remaining = 19.0
	state.reset_round(deps)
	_expect_eq(state.phase, "idle", "round cleanup removes the chest")
	_expect(not state.chest_opened and not state.smoke_confusion_consumed, "round cleanup clears open and exposure flags")
	_expect(status.get_status("boss", "confusion").is_empty(), "round cleanup clears only owned confusion")
	_expect_eq(state.cooldown_remaining, 19.0, "round cleanup preserves cooldown")


func _verify_smoke_requires_contact_and_respects_immunity() -> void:
	var ai := BossAiState.new()
	ai.boss_dash_active = true
	ai.boss_dash_timer_frames = 10.0
	var status := StatusEffectState.new()
	var owner := FakeOwner.new()
	owner.current_stage = 2
	owner.boss_pos_prev = Vector2(100.0, 50.0)
	owner.boss_pos = Vector2(520.0, 50.0)
	var state := YeonmyoVisionChosikState.new()
	state.phase = "closed"
	state.active_remaining = 12.0
	state.chest_pos = Vector2(380.0, 70.0)
	var deps := {
		"owner": owner,
		"skill_config": FakeSkillConfig.new(),
		"boss_ai_state": ai,
		"status_effect_state": status,
		"audio": FakeAudio.new(),
	}
	var config := _base_player_config(owner)
	config["stage2_speed_defense_status_immunity_active"] = true
	state.update(0.0, {}, false, Vector2.ZERO, config, deps)
	_expect_eq(state.phase, "open", "dash segment opens the chest even when it ends outside the smoke")
	_expect(not state.smoke_confusion_consumed, "opening is separate from smoke exposure")
	_expect(status.get_status("boss", "confusion").is_empty(), "no contact means no confusion")
	ai.boss_dash_active = false
	owner.boss_pos = Vector2(330.0, 50.0)
	state.update(0.0, {}, false, Vector2.ZERO, config, deps)
	_expect(not state.smoke_confusion_consumed, "Stage 2 immunity preserves the unconsumed smoke contact")
	config["stage2_speed_defense_status_immunity_active"] = false
	state.update(0.0, {}, false, Vector2.ZERO, config, deps)
	_expect(state.smoke_confusion_consumed, "first valid in-smoke frame applies confusion")
	_expect_eq(
		float(status.get_status("boss", "confusion").get("remaining_frames", 0.0)),
		180.0,
		"late smoke exposure applies three seconds"
	)
	state.update(5.01, {}, false, Vector2.ZERO, config, deps)
	_expect_eq(state.phase, "idle", "opened chest and smoke clean up after emission and fade")


func _verify_fading_smoke_is_visual_only() -> void:
	var status := StatusEffectState.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(330.0, 50.0)
	var state := YeonmyoVisionChosikState.new()
	state.phase = "open"
	state.chest_opened = true
	state.chest_pos = Vector2(380.0, 70.0)
	state.smoke_elapsed = 3.01
	var deps := {
		"owner": owner,
		"status_effect_state": status,
	}
	state.update(0.0, {}, false, Vector2.ZERO, _base_player_config(owner), deps)
	_expect(not state.smoke_confusion_consumed, "two-second smoke fade is not an extended hit window")
	_expect(status.get_status("boss", "confusion").is_empty(), "fading smoke cannot apply confusion")


func _base_player_config(owner: FakeOwner) -> Dictionary:
	return {
		"ball_active": true,
		"player_skill_input_locked": false,
		"special_gauge": owner.special_gauge,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": owner.boss_pos,
		"boss_paddle_width": owner.boss_paddle_width,
		"boss_hitbox_height": 40.0,
		"current_stage": owner.current_stage,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (actual=%s expected=%s)" % [message, actual, expected])


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO
