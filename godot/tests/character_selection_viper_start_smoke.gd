extends SceneTree

const CharacterSelectScene := preload("res://scenes/character_select.tscn")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const BattleSceneStartupController := preload("res://scripts/core/battle_scene_startup_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const CHARACTER_SELECT_BGM_PATH := "res://assets/bgm/character select.wav"


class FakeBattleOwner:
	extends Node

	var data: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func queue_redraw() -> void:
		pass


var failure_count: int = 0
var ran: bool = false


func _process(_delta: float) -> bool:
	if ran:
		return true
	ran = true
	_run()
	return true


func _run() -> void:
	@warning_ignore("shadowed_variable_base_class")
	var root: Window = get_root()
	var state: Node = _get_or_create_selection_state(root)
	var characters: Array = CharacterSelectData.get_characters()
	var smasher: Dictionary = _find_character(characters, "ufo_player")
	var commando: Dictionary = _find_character(characters, "soldier")
	var baltor: Dictionary = _find_character(characters, "blacksmith")
	var optimus: Dictionary = _find_character(characters, "optimus")
	var viper: Dictionary = _find_character(characters, "viper")
	_expect(not smasher.is_empty(), "character data should include smasher")
	_expect(not commando.is_empty(), "character data should include commando")
	_expect(not baltor.is_empty(), "character data should include baltor")
	_expect(not optimus.is_empty(), "character data should include optimus")
	_expect(not viper.is_empty(), "character data should include viper")
	_expect(str(smasher.get("character_name", "")) == "미카", "Smasher select card should expose Mika as the character name")
	_expect(str(commando.get("character_name", "")) == "레나", "Commando select card should expose Rena as the character name")
	_expect(str(baltor.get("character_name", "")) == "코하쿠", "Baltor select card should expose Kohaku as the character name")
	_expect(str(optimus.get("character_name", "")) == "이오", "Optimus select card should expose Io as the character name")
	_expect(str(viper.get("character_name", "")) == "세린", "Viper select card should expose Serin as the character name")
	_expect(str(smasher.get("class_name", "")) == "스매셔", "Smasher select card should keep Smasher as the class name")
	_expect(str(commando.get("class_name", "")) == "코만도", "Commando select card should keep Commando as the class name")
	_expect(str(baltor.get("class_name", "")) == "발토르", "Baltor select card should keep Baltor as the class name")
	_expect(str(optimus.get("class_name", "")) == "옵티머스", "Optimus select card should keep Optimus as the class name")
	_expect(str(viper.get("class_name", "")) == "바이퍼", "Viper select card should keep Viper as the class name")
	_expect(bool(smasher.get("unlocked", false)), "Smasher should remain playable from a fresh character-select state")
	_expect(bool(commando.get("unlocked", false)), "Commando should remain playable from a fresh character-select state")
	_expect(bool(baltor.get("unlocked", false)), "Kohaku should start unlocked for Blacksmith runtime QA")
	_expect(not bool(optimus.get("unlocked", true)), "Io should start locked until explicitly unlocked")
	_expect(bool(viper.get("unlocked", false)), "Viper should remain playable from a fresh character-select state")
	var rena_cutline_ratio: float = float(commando.get("live2d_card_cutline_ratio", -1.0))
	_expect(is_equal_approx(rena_cutline_ratio, 0.79), "Rena should define the shared character-select bottom cutline baseline")
	_expect(is_equal_approx(float(smasher.get("live2d_card_cutline_ratio", -1.0)), rena_cutline_ratio), "smasher preview bottom cutline should match Rena")
	_expect(is_equal_approx(float(baltor.get("live2d_card_cutline_ratio", -1.0)), rena_cutline_ratio), "baltor preview bottom cutline should match Rena")
	_expect(is_equal_approx(float(optimus.get("live2d_card_cutline_ratio", -1.0)), rena_cutline_ratio), "optimus preview bottom cutline should match Rena")
	_expect(is_equal_approx(float(viper.get("live2d_card_cutline_ratio", -1.0)), rena_cutline_ratio), "viper preview bottom cutline should match Rena")
	_expect(
		str(smasher.get("portrait_path", "")).ends_with("smasher_card_female_bionic_paddle_helmet_imagegen_v1_cutout_clean_padded.png"),
		"smasher portrait should use the helmet-holding card asset"
	)
	_expect(
		str(smasher.get("live2d_preview_still_path", "")).ends_with("smasher_card_female_bionic_paddle_helmet_imagegen_v1_cutout_clean_padded.png"),
		"smasher preview still should use the helmet-holding card asset"
	)
	_expect(
		str(smasher.get("live2d_fullframe_sheet_path", "")).ends_with("smasher_female_bionic_white_chest_no_fins_smooth_menu_idle_loop49_autosprite_v8_realesrgan_animev3_hq1536_safe.png"),
		"smasher preview should use the Real-ESRGAN high-resolution white_chest smooth_menu idle AutoSprite loop first"
	)
	_expect(int(smasher.get("live2d_fullframe_cols", 0)) == 7, "smasher helmet preview should use the 7-column runtime sheet")
	_expect(int(smasher.get("live2d_fullframe_rows", 0)) == 7, "smasher helmet preview should use the 7-row runtime sheet")
	_expect(int(smasher.get("live2d_fullframe_count", 0)) == 49, "smasher helmet preview should expose the native 49-frame loop")
	_expect(float(smasher.get("live2d_fullframe_interval", 1.0)) <= 0.034, "smasher selection Live2D should run near 30 FPS to avoid choppy frame pacing")
	_expect(int(smasher.get("live2d_trim_sample_frame_limit", 0)) == 49, "smasher true-motion preview should trim against every helmet-loop frame to avoid apparent scale drift")
	_expect(smasher.get("live2d_trim_rect", null) is Rect2, "smasher idle preview should have a precomputed trim rect to avoid first-click image scans")
	var smasher_full_body_path := str(smasher.get("full_body_live2d_path", ""))
	var smasher_full_body_sheet_path := str(smasher.get("full_body_live2d_sheet_path", ""))
	_expect(not smasher_full_body_path.contains("optimus"), "smasher should not use the optimus full-body panel asset")
	_expect(not smasher_full_body_sheet_path.contains("optimus"), "smasher should not prewarm or render an optimus full-body sheet")
	_expect(is_equal_approx(float(smasher.get("full_body_live2d_stage_x_scale", 1.0)), 0.90), "smasher full-body panel should slim the pressed full-body read")
	_expect(is_equal_approx(float(smasher.get("full_body_live2d_stage_y_scale", 1.0)), 1.12), "smasher full-body panel should stretch vertically to avoid a pressed full-body read")
	var smasher_texture := load(str(smasher.get("portrait_path", ""))) as Texture2D
	_expect(smasher_texture != null, "smasher female card asset should load")
	var smasher_sheet := load(str(smasher.get("live2d_fullframe_sheet_path", ""))) as Texture2D
	_expect(smasher_sheet != null, "smasher active AutoSprite sheet should load")
	_expect(
		str(smasher.get("confirm_intro_sheet_path", "")).ends_with("smasher_select_confirm_swing_bada_loop98_autosprite_v2_stable_realesrgan_animev3_hq1152_safe.png"),
		"smasher confirm intro should use the original accepted 98-frame click Live2D sheet"
	)
	_expect(int(smasher.get("confirm_intro_cols", 0)) == 14, "smasher confirm intro should use the 14-column runtime sheet")
	_expect(int(smasher.get("confirm_intro_rows", 0)) == 7, "smasher confirm intro should use the 7-row runtime sheet")
	_expect(int(smasher.get("confirm_intro_count", 0)) == 98, "smasher confirm intro should expose all 98 frames")
	_expect(float(smasher.get("confirm_intro_interval", 0.0)) <= 0.022, "smasher confirm intro should use faster frame pacing to offset held duplicate frames")
	_expect(float(smasher.get("confirm_intro_min_duration", 0.0)) >= 2.30, "smasher confirm intro should hold long enough for the full voice-timed swing")
	_expect(bool(smasher.get("confirm_intro_trim_transparent_source", false)), "smasher original confirm intro should use its stable all-frame trim")
	_expect(smasher.get("confirm_intro_trim_rect", null) is Rect2, "smasher original confirm intro should use a precomputed trim rect")
	_expect(not bool(smasher.get("confirm_intro_float_motion_enabled", true)), "smasher confirm intro should not layer runtime bob/scale over the AutoSprite motion")
	_expect(float(smasher.get("confirm_intro_transition_duration", 0.0)) > 0.0, "smasher confirm intro should crossfade from idle to avoid a hard Live2D sheet cut")
	_expect(is_equal_approx(float(smasher.get("confirm_intro_return_transition_duration", 0.18)), 0.0), "smasher preview click should not use the temporary final-frame return ghost")
	_expect(str(smasher.get("confirm_intro_return_sheet_path", "")) == "", "smasher preview click should not play a separate reverse return Live2D sheet")
	_expect(str(smasher.get("click_motion_sheet_path", "")) == "", "smasher preview click should keep the original confirm Live2D as the click sheet")
	_expect(float(smasher.get("confirm_intro_stage_scale", 0.0)) > 1.0, "smasher original confirm intro should scale up slightly to match idle apparent size")
	_expect(is_equal_approx(float(smasher.get("confirm_intro_stage_x_offset_ratio", 0.0)), -0.034), "smasher original confirm intro should align horizontally with the idle Live2D preview")
	var smasher_confirm_y_offset := float(smasher.get("confirm_intro_stage_y_offset_ratio", 1.0))
	_expect(
		smasher_confirm_y_offset >= -0.007 and smasher_confirm_y_offset <= -0.005,
		"smasher original confirm intro should lift slightly so the click Live2D does not sit below the idle preview"
	)
	_expect(
		str(smasher.get("confirm_intro_voice_path", "")).ends_with("voice/smasherselect.mp3"),
		"smasher confirm intro should use the accepted local smasher select voice file"
	)
	_expect(float(smasher.get("confirm_intro_voice_delay", 0.0)) >= 0.75, "smasher confirm voice should wait for the mouth-open frames")
	_expect(is_equal_approx(float(smasher.get("confirm_intro_voice_volume_db", 0.0)), -6.0), "smasher confirm voice should sit under the character-select BGM without jumping too loud")
	_expect(bool(smasher.get("confirm_intro_exit_flash_enabled", false)), "smasher confirm intro should hide the one-shot-to-battle cut with an exit flash")
	_expect(str(smasher.get("confirm_intro_exit_flash_style", "")) == "burst", "smasher exit flash should use the bright burst style")
	_expect(float(smasher.get("confirm_intro_exit_flash_duration", 0.0)) >= 0.50, "smasher exit flash should sustain the modular VFX through the white wash bridge")
	_expect(float(smasher.get("confirm_intro_exit_flash_white_wash_target", 0.0)) > 0.85, "smasher exit flash should bridge into the next scene with a near-full white wash")
	_expect(float(smasher.get("confirm_intro_exit_flash_field_intensity", 0.0)) > 0.0, "smasher exit flash should expose a field intensity tuning hook")
	_expect(float(smasher.get("confirm_intro_exit_flash_card_intensity", 0.0)) > 0.0, "smasher exit flash should expose a card intensity tuning hook")
	var smasher_intro_sheet := load(str(smasher.get("confirm_intro_sheet_path", ""))) as Texture2D
	_expect(smasher_intro_sheet != null, "smasher confirm intro AutoSprite sheet should load")
	var smasher_voice := load(str(smasher.get("confirm_intro_voice_path", ""))) as AudioStream
	_expect(smasher_voice != null, "smasher confirm intro voice should load")
	var prewarm: Object = CharacterSelectPrewarm.new()
	prewarm.begin("res://scenes/character_select.tscn")
	_expect(
		_prewarm_has_job(prewarm, str(smasher.get("confirm_intro_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the smasher confirm intro sheet"
	)
	_expect(
		_prewarm_has_job(prewarm, str(smasher.get("confirm_intro_voice_path", "")), "AudioStream"),
		"character-select loading screen should prewarm the smasher confirm intro voice"
	)
	_expect(FileAccess.file_exists(CHARACTER_SELECT_BGM_PATH), "character-select BGM asset should exist")
	_expect(ProjectResourceLoader.load_audio_stream(CHARACTER_SELECT_BGM_PATH) != null, "character-select BGM should load")
	_expect(
		_prewarm_has_job(prewarm, CHARACTER_SELECT_BGM_PATH, "AudioStream"),
		"character-select loading screen should prewarm the character select BGM"
	)
	_expect(
		str(optimus.get("portrait_path", "")).ends_with("optimus_engineer_glasses_manual_fishnet_l2d_samecrop_cutout_v1.png"),
		"optimus portrait should use the accepted engineer glasses manual fishnet cutout"
	)
	_expect(
		str(optimus.get("live2d_preview_still_path", "")).ends_with("optimus_engineer_glasses_manual_fishnet_l2d_samecrop_cutout_v1.png"),
		"optimus preview still should use the accepted engineer glasses manual fishnet cutout"
	)
	_expect(
		str(optimus.get("live2d_fullframe_sheet_path", "")).ends_with("optimus_engineer_glasses_manual_fishnet_idle_loop49_autosprite_v1_realesrgan_animev3_hq1536_safe.png"),
		"optimus preview should use the Real-ESRGAN HQ engineer glasses manual fishnet AutoSprite loop first"
	)
	_expect(int(optimus.get("live2d_fullframe_cols", 0)) == 7, "optimus preview should use the 7-column runtime sheet")
	_expect(int(optimus.get("live2d_fullframe_rows", 0)) == 7, "optimus preview should use the 7-row runtime sheet")
	_expect(int(optimus.get("live2d_fullframe_count", 0)) == 49, "optimus preview should expose the native 49-frame loop")
	_expect(bool(optimus.get("live2d_trim_transparent_source", false)), "optimus cutout loop should trim its transparent source")
	_expect(optimus.get("live2d_trim_rect", null) is Rect2, "optimus idle preview should have a precomputed trim rect")
	var optimus_idle_trim: Rect2 = optimus.get("live2d_trim_rect", Rect2())
	_expect(optimus_idle_trim.size.y >= 1460.0, "optimus HQ idle trim should use the 1536-cell Real-ESRGAN source")
	var optimus_texture := load(str(optimus.get("portrait_path", ""))) as Texture2D
	_expect(optimus_texture != null, "optimus engineer glasses manual cutout asset should load")
	var optimus_sheet := load(str(optimus.get("live2d_fullframe_sheet_path", ""))) as Texture2D
	_expect(optimus_sheet != null, "optimus engineer glasses manual AutoSprite sheet should load")
	_expect(
		_prewarm_has_job(prewarm, str(optimus.get("live2d_fullframe_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the optimus AutoSprite card loop"
	)
	_expect(
		str(optimus.get("full_body_live2d_sheet_path", "")).ends_with("optimus_fullbody_capsule_mecha_idle_micro_loop49_autosprite_v4_realesrgan_animev3_hq1024_safe.png"),
		"optimus right-side full-body panel should use the regenerated no-racket capsule mecha Live2D loop"
	)
	_expect(int(optimus.get("full_body_live2d_cols", 0)) == 7, "optimus full-body Live2D should use the 7-column runtime sheet")
	_expect(int(optimus.get("full_body_live2d_rows", 0)) == 7, "optimus full-body Live2D should use the 7-row runtime sheet")
	_expect(int(optimus.get("full_body_live2d_count", 0)) == 49, "optimus full-body Live2D should expose the native 49-frame hover loop")
	_expect(optimus.get("full_body_live2d_trim_rect", null) is Rect2, "optimus full-body Live2D should use a precomputed trim rect")
	var optimus_full_body_trim: Rect2 = optimus.get("full_body_live2d_trim_rect", Rect2())
	_expect(optimus_full_body_trim.position.y <= 1.0, "optimus full-body Live2D trim should keep full-height top margin for ears and hair tips")
	_expect(optimus_full_body_trim.size.y >= 1024.0, "optimus full-body Live2D trim should preserve the full source height to avoid top or foot clipping")
	var optimus_full_body_sheet := load(str(optimus.get("full_body_live2d_sheet_path", ""))) as Texture2D
	_expect(optimus_full_body_sheet != null, "optimus full-body Live2D sheet should load")
	_expect(
		_prewarm_has_job(prewarm, str(optimus.get("full_body_live2d_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the optimus full-body Live2D sheet"
	)
	_expect(
		str(optimus.get("confirm_intro_sheet_path", "")).ends_with("optimus_select_confirm_glasses_book_mumble_happy_loop98_autosprite_v4_xfit73_realesrgan_animev3_hq1152_safe.png"),
		"optimus confirm intro should use the glasses-book mumble happy 98-frame click one-shot"
	)
	_expect(int(optimus.get("confirm_intro_cols", 0)) == 14, "optimus confirm intro should use the 14-column runtime sheet")
	_expect(int(optimus.get("confirm_intro_rows", 0)) == 7, "optimus confirm intro should use the 7-row runtime sheet")
	_expect(int(optimus.get("confirm_intro_count", 0)) == 98, "optimus confirm intro should expose the held 49-frame AutoSprite motion")
	_expect(float(optimus.get("confirm_intro_interval", 0.0)) <= 0.022, "optimus confirm intro should keep smasher-style duplicate-frame pacing")
	_expect(float(optimus.get("confirm_intro_min_duration", 0.0)) >= 2.30, "optimus confirm intro should hold long enough for the glasses-book reaction")
	_expect(bool(optimus.get("confirm_intro_trim_transparent_source", false)), "optimus confirm intro should trim its transparent source for stable scale")
	_expect(optimus.get("confirm_intro_trim_rect", null) is Rect2, "optimus confirm intro should use a precomputed trim rect")
	var optimus_confirm_trim: Rect2 = optimus.get("confirm_intro_trim_rect", Rect2())
	_expect(optimus_confirm_trim.size.x <= 620.0, "optimus confirm intro trim should keep the click art close to the idle preview width")
	_expect(optimus_confirm_trim.size.y >= 1000.0, "optimus confirm intro trim should preserve the accepted tall card crop")
	_expect(not bool(optimus.get("confirm_intro_float_motion_enabled", true)), "optimus confirm intro should not layer runtime bob over the AutoSprite motion")
	_expect(float(optimus.get("confirm_intro_transition_duration", 0.0)) > 0.0, "optimus confirm intro should crossfade from idle")
	_expect(abs(float(optimus.get("confirm_intro_stage_x_offset_ratio", 1.0))) <= 0.001, "optimus confirm intro should stay horizontally aligned with the idle preview")
	_expect(abs(float(optimus.get("confirm_intro_stage_y_offset_ratio", 1.0))) <= 0.001, "optimus confirm intro should stay vertically aligned with the idle preview")
	_expect(
		str(optimus.get("confirm_intro_voice_path", "")).ends_with("voice/optimusselect.mp3"),
		"optimus confirm intro should use the accepted Io select voice"
	)
	_expect(is_equal_approx(float(optimus.get("confirm_intro_voice_delay", 0.0)), 0.80), "optimus confirm voice should wait for the mouth-open frames")
	_expect(is_equal_approx(float(optimus.get("confirm_intro_voice_volume_db", 0.0)), -5.0), "optimus confirm voice should sit under the character-select BGM")
	_expect(
		str(optimus.get("click_motion_voice_path", "")).ends_with("voice/optimusselect.mp3"),
		"optimus click Live2D should reuse the accepted Io select voice"
	)
	_expect(is_equal_approx(float(optimus.get("click_motion_voice_delay", 0.0)), 0.80), "optimus click Live2D voice should start 0.8 seconds after click")
	_expect(is_equal_approx(float(optimus.get("click_motion_voice_volume_db", 0.0)), -5.0), "optimus click Live2D voice should use the tuned select volume")
	_expect(bool(optimus.get("confirm_intro_exit_flash_enabled", false)), "optimus confirm intro should hide the one-shot-to-battle cut with an exit flash")
	var optimus_intro_sheet := load(str(optimus.get("confirm_intro_sheet_path", ""))) as Texture2D
	_expect(optimus_intro_sheet != null, "optimus confirm intro AutoSprite sheet should load")
	var optimus_voice := load(str(optimus.get("confirm_intro_voice_path", ""))) as AudioStream
	_expect(optimus_voice != null, "optimus select voice should load")
	_expect(
		_prewarm_has_job(prewarm, str(optimus.get("confirm_intro_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the optimus confirm intro sheet"
	)
	_expect(
		_prewarm_has_job(prewarm, str(optimus.get("click_motion_voice_path", "")), "AudioStream"),
		"character-select loading screen should prewarm the optimus click Live2D voice"
	)
	_expect(
		str(commando.get("portrait_path", "")).ends_with("commando_card_pistol_close_smasher_pose_imagegen_v4_cutout_clean_padded.png"),
		"commando portrait should use the clean close pistol card asset"
	)
	_expect(
		str(commando.get("live2d_fullframe_sheet_path", "")).ends_with("commando_pistol_close_card_idle_loop49_autosprite_v1_realesrgan_animev3_hq1536_safe.png"),
		"commando preview should use the Real-ESRGAN polished pistol close 49-frame AutoSprite card loop first"
	)
	_expect(int(commando.get("live2d_fullframe_count", 0)) == 49, "commando preview should expose the native 49-frame loop")
	_expect(not bool(commando.get("live2d_deform_fullframe_sheet", true)), "commando preview should draw the full-frame sheet as one piece")
	_expect(not bool(commando.get("live2d_motion_regions_enabled", true)), "commando preview should not use separated chest/torso overlays")
	_expect(float(commando.get("live2d_float_bob", 0.0)) >= 2.5, "commando preview should keep a visible upper-body bob")
	var commando_texture := load(str(commando.get("portrait_path", ""))) as Texture2D
	_expect(commando_texture != null, "commando clean padded card asset should load")
	var commando_sheet := load(str(commando.get("live2d_fullframe_sheet_path", ""))) as Texture2D
	_expect(commando_sheet != null, "commando pistol AutoSprite sheet should load")
	_expect(
		str(commando.get("confirm_intro_sheet_path", "")).ends_with("commando_select_confirm_radio_ready_loop98_autosprite_v1_stable_realesrgan_animev3_hq1152_safe.png"),
		"commando confirm intro should use the Real-ESRGAN polished 98-frame radio-ready click one-shot"
	)
	_expect(int(commando.get("confirm_intro_cols", 0)) == 14, "commando confirm intro should use the 14-column runtime sheet")
	_expect(int(commando.get("confirm_intro_rows", 0)) == 7, "commando confirm intro should use the 7-row runtime sheet")
	_expect(int(commando.get("confirm_intro_count", 0)) == 98, "commando confirm intro should expose the held 49-frame AutoSprite motion")
	_expect(float(commando.get("confirm_intro_interval", 0.0)) <= 0.022, "commando confirm intro should use smasher-style duplicate-frame pacing")
	_expect(float(commando.get("confirm_intro_min_duration", 0.0)) >= 2.75, "commando confirm intro should hold long enough for the shoot-all voice line")
	_expect(bool(commando.get("confirm_intro_trim_transparent_source", false)), "commando confirm intro should trim its transparent source for stable scale")
	_expect(commando.get("confirm_intro_trim_rect", null) is Rect2, "commando confirm intro should use a precomputed trim rect")
	var commando_confirm_trim: Rect2 = commando.get("confirm_intro_trim_rect", Rect2())
	_expect(commando_confirm_trim.size.x >= 760.0 and commando_confirm_trim.size.y >= 975.0, "commando confirm intro trim should preserve idle-sized padding")
	_expect(not bool(commando.get("confirm_intro_float_motion_enabled", true)), "commando confirm intro should not layer runtime bob over the AutoSprite motion")
	_expect(float(commando.get("confirm_intro_transition_duration", 0.0)) > 0.0, "commando confirm intro should crossfade from idle")
	_expect(is_equal_approx(float(commando.get("confirm_intro_stage_x_offset_ratio", 0.0)), -0.018), "commando confirm intro should apply the slight leftward click Live2D offset")
	_expect(abs(float(commando.get("confirm_intro_stage_y_offset_ratio", 1.0))) <= 0.001, "commando confirm intro should stay vertically aligned with the idle preview")
	_expect(
		str(commando.get("confirm_intro_voice_path", "")).ends_with("voice/commandoselect.mp3"),
		"commando confirm intro should use the shoot-all voice line"
	)
	_expect(float(commando.get("confirm_intro_voice_delay", 0.0)) >= 0.20 and float(commando.get("confirm_intro_voice_delay", 0.0)) <= 0.32, "commando confirm voice should line up with the early mouth motion")
	_expect(is_equal_approx(float(commando.get("confirm_intro_voice_volume_db", 0.0)), -5.0), "commando confirm voice should blend with the character-select BGM")
	_expect(bool(commando.get("confirm_intro_exit_flash_enabled", false)), "commando confirm intro should hide the one-shot-to-battle cut with an exit flash")
	_expect(str(commando.get("confirm_intro_exit_flash_style", "")) == "burst", "commando exit flash should use a tactical green burst")
	_expect(float(commando.get("confirm_intro_exit_flash_duration", 0.0)) >= 0.30, "commando exit flash should be long enough to mask the scene cut")
	var commando_intro_sheet := load(str(commando.get("confirm_intro_sheet_path", ""))) as Texture2D
	_expect(commando_intro_sheet != null, "commando confirm intro AutoSprite sheet should load")
	var commando_voice := load(str(commando.get("confirm_intro_voice_path", ""))) as AudioStream
	_expect(commando_voice != null, "commando confirm intro tang voice should load")
	_expect(
		_prewarm_has_job(prewarm, str(commando.get("confirm_intro_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the commando confirm intro sheet"
	)
	_expect(
		_prewarm_has_job(prewarm, str(commando.get("confirm_intro_voice_path", "")), "AudioStream"),
		"character-select loading screen should prewarm the commando confirm intro voice"
	)
	_expect(
		str(baltor.get("portrait_path", "")).ends_with("baltor_card_kohaku_moe_hammerbehind_l2d_imagegen_v9_cutout_clean_padded.png"),
		"baltor portrait should use the accepted hammer-behind Kohaku Live2D asset"
	)
	_expect(
		str(baltor.get("live2d_fullframe_sheet_path", "")).ends_with("baltor_kohaku_upperthigh_redraw_idle_loop49_autosprite_v1_realesrgan_animev3_hq1024_safe.png"),
		"baltor preview should use the upper-thigh Kohaku AutoSprite v1 Live2D loop as the idle base"
	)
	_expect(int(baltor.get("live2d_fullframe_cols", 0)) == 7, "baltor redraw preview should use the native 7-column AutoSprite loop")
	_expect(int(baltor.get("live2d_fullframe_rows", 0)) == 7, "baltor redraw preview should use the native 7-row AutoSprite loop")
	_expect(int(baltor.get("live2d_fullframe_count", 0)) == 49, "baltor redraw preview should expose the native 49-frame loop")
	_expect(not bool(baltor.get("live2d_deform_still", true)), "baltor upper-body redraw should use the generated AutoSprite loop")
	var baltor_idle_stage_scale := float(baltor.get("live2d_stage_scale", 1.0))
	_expect(is_equal_approx(baltor_idle_stage_scale, 0.784), "baltor upper-thigh preview should render at 80 percent of the previous 0.98 scale")
	_expect(is_equal_approx(float(baltor.get("live2d_stage_x_scale", 1.0)), 0.729), "baltor upper-thigh preview should be horizontally compressed by another 10 percent")
	_expect(is_equal_approx(float(baltor.get("live2d_stage_y_scale", 1.0)), 1.15), "baltor upper-thigh preview should stretch vertically by 15 percent without widening")
	_expect(is_equal_approx(float(baltor.get("live2d_card_cutline_ratio", 0.0)), 0.79), "baltor preview apron should use the same bottom cutline height as Rena")
	var baltor_stage_y_offset := float(baltor.get("live2d_stage_y_offset", 1.0))
	_expect(
		is_zero_approx(baltor_stage_y_offset),
		"baltor bottom-line alignment should not depend on a fixed viewport y offset"
	)
	_expect(bool(baltor.get("live2d_align_bottom_to_cutline", false)), "baltor preview should align its rendered bottom to the card cutline")
	var baltor_texture := load(str(baltor.get("portrait_path", ""))) as Texture2D
	_expect(baltor_texture != null, "baltor dwarf maid card asset should load")
	var baltor_sheet := load(str(baltor.get("live2d_fullframe_sheet_path", ""))) as Texture2D
	_expect(baltor_sheet != null, "baltor full-body-based AutoSprite idle sheet should load")
	if baltor_sheet != null:
		_expect(baltor_sheet.get_size() == Vector2(7168, 7168), "baltor full-body-based idle sheet should use 1024 px cells in a 7x7 grid")
	var baltor_idle_candidates: Array = baltor.get("live2d_fullframe_sheet_candidates", [])
	_expect(not baltor_idle_candidates.is_empty(), "baltor idle Live2D should expose fallback candidates")
	if not baltor_idle_candidates.is_empty():
		var first_baltor_idle_candidate: Dictionary = baltor_idle_candidates[0]
		_expect(
			str(first_baltor_idle_candidate.get("path", "")).ends_with("baltor_kohaku_upperthigh_redraw_idle_loop49_autosprite_v1_realesrgan_animev3_hq1024_safe.png"),
			"baltor idle candidate order should prefer the upper-thigh redraw recommendation"
		)
		_expect(first_baltor_idle_candidate.get("trim_rect", null) is Rect2, "baltor upper-thigh idle candidate should use a precomputed upper-thigh trim rect")
		var first_baltor_idle_trim: Rect2 = first_baltor_idle_candidate.get("trim_rect", Rect2())
		_expect(first_baltor_idle_trim.position.y <= 10.0, "baltor upper-thigh idle trim should preserve the hair and hammer top margin")
		_expect(first_baltor_idle_trim.size.y >= 790.0, "baltor upper-thigh idle trim should preserve the upper-thigh area")
		_expect(first_baltor_idle_trim.size.x >= 820.0, "baltor upper-thigh idle trim should keep the hammer and shield read wide enough")
	_expect(
		str(baltor.get("full_body_live2d_sheet_path", "")).ends_with("baltor_kohaku_fullbody_proportionfix_idle_loop49_autosprite_asset_v8b_realesrgan_animev3_hq1024_safe.png"),
		"baltor full-body panel should use the proportion-fixed Kohaku AutoSprite sheet"
	)
	_expect(
		str(baltor.get("full_body_live2d_path", "")).ends_with("baltor_kohaku_fullbody_proportionfix_idle_loop49_autosprite_asset_v8b_frame0_safe.png"),
		"baltor full-body panel should keep a frame0 fallback still"
	)
	_expect(int(baltor.get("full_body_live2d_cols", 0)) == 7, "baltor full-body Live2D should use the 7-column runtime sheet")
	_expect(int(baltor.get("full_body_live2d_rows", 0)) == 7, "baltor full-body Live2D should use the 7-row runtime sheet")
	_expect(int(baltor.get("full_body_live2d_count", 0)) == 49, "baltor full-body Live2D should expose the native 49-frame idle loop")
	_expect(baltor.get("full_body_live2d_trim_rect", null) is Rect2, "baltor full-body Live2D should use a precomputed trim rect")
	var baltor_full_body_trim: Rect2 = baltor.get("full_body_live2d_trim_rect", Rect2())
	_expect(is_equal_approx(baltor_full_body_trim.position.y, 0.0), "baltor full-body trim should preserve the new top headroom")
	_expect(baltor_full_body_trim.size.y >= 1000.0, "baltor full-body trim should preserve the full headroom-safe pose")
	_expect(baltor_full_body_trim.size.x >= 900.0, "baltor full-body trim should keep the hammer and shield read wide enough")
	_expect(is_equal_approx(float(baltor.get("full_body_live2d_stage_scale", 1.0)), 1.08), "baltor full-body panel should enlarge Kohaku after the wide prop-safe trim")
	_expect(is_equal_approx(float(baltor.get("full_body_live2d_stage_x_scale", 1.0)), 0.782), "baltor full-body panel should slim the wide prop-safe trim horizontally")
	_expect(is_equal_approx(float(baltor.get("full_body_live2d_stage_y_scale", 1.0)), 1.20), "baltor full-body panel should stretch Kohaku vertically so the right panel does not look pressed")
	var baltor_full_body_sheet := load(str(baltor.get("full_body_live2d_sheet_path", ""))) as Texture2D
	_expect(baltor_full_body_sheet != null, "baltor full-body Live2D sheet should load")
	if baltor_full_body_sheet != null:
		_expect(baltor_full_body_sheet.get_size() == Vector2(7168, 7168), "baltor full-body Real-ESRGAN sheet should use 1024 px cells in a 7x7 grid")
	_expect(
		_prewarm_has_job(prewarm, str(baltor.get("full_body_live2d_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the baltor full-body Live2D sheet"
	)
	_expect(
		str(baltor.get("confirm_intro_sheet_path", "")).ends_with("baltor_kohaku_select_click_escape_talk_loop98_autosprite_v4_cleanedge_realesrgan_animev3_hq1024_safe.png"),
		"baltor confirm intro should use the clean-edge 98-frame Kohaku smile-talk click sheet"
	)
	_expect(int(baltor.get("confirm_intro_cols", 0)) == 14, "baltor confirm intro should use the 14-column runtime sheet")
	_expect(int(baltor.get("confirm_intro_rows", 0)) == 7, "baltor confirm intro should use the 7-row 98-frame runtime sheet")
	_expect(int(baltor.get("confirm_intro_count", 0)) == 98, "baltor confirm intro should expose the held 49-frame smile-talk motion")
	_expect(float(baltor.get("confirm_intro_interval", 0.0)) <= 0.022, "baltor confirm intro should use smasher-style duplicate-frame pacing")
	_expect(float(baltor.get("confirm_intro_min_duration", 0.0)) >= 1.95, "baltor confirm intro should last through all 98 smile-talk frames")
	_expect(bool(baltor.get("confirm_intro_trim_transparent_source", false)), "baltor confirm intro should trim its transparent source for stable scale")
	_expect(baltor.get("confirm_intro_trim_rect", null) is Rect2, "baltor confirm intro should use a precomputed trim rect")
	var baltor_confirm_trim: Rect2 = baltor.get("confirm_intro_trim_rect", Rect2())
	_expect(baltor_confirm_trim.position.y <= 14.0 and baltor_confirm_trim.size.y >= 980.0, "baltor confirm trim should preserve the clean upper-thigh click talk motion")
	_expect(not bool(baltor.get("confirm_intro_float_motion_enabled", true)), "baltor confirm intro should not layer runtime bob over the AutoSprite hop")
	_expect(float(baltor.get("confirm_intro_transition_duration", 0.0)) > 0.0, "baltor confirm intro should crossfade from idle")
	var baltor_confirm_stage_scale := float(baltor.get("confirm_intro_stage_scale", 0.0))
	_expect(is_equal_approx(baltor_confirm_stage_scale, 1.0), "baltor confirm intro should inherit the resized idle stage scale without extra click scaling")
	_expect(is_equal_approx(float(baltor.get("confirm_intro_stage_x_offset_ratio", 0.0)), 0.0), "baltor confirm intro should not apply an extra horizontal offset over the bottom-aligned idle stage")
	_expect(is_equal_approx(float(baltor.get("confirm_intro_stage_y_offset_ratio", 0.0)), 0.0), "baltor confirm intro should not apply an extra vertical offset over the bottom-aligned idle stage")
	_expect(bool(baltor.get("confirm_intro_align_bottom_to_cutline", false)), "baltor confirm intro should align to the same bottom cutline as the idle Live2D")
	_expect(is_equal_approx(float(baltor.get("confirm_intro_return_transition_duration", 1.0)), 0.0), "baltor confirm intro should not ghost-fade after the 98-frame talk sheet")
	_expect(str(baltor.get("confirm_intro_restore_elapsed_mode", "")) == "restart", "baltor preview click should restart the idle loop after the talk sheet finishes")
	_expect(
		str(baltor.get("confirm_intro_voice_path", "")).ends_with("kohaku_select_confirm_naneun_domangchilggeoya_v4.mp3"),
		"baltor confirm intro should use the accepted Kohaku escape voice"
	)
	_expect(float(baltor.get("confirm_intro_voice_delay", -1.0)) >= 0.12 and float(baltor.get("confirm_intro_voice_delay", -1.0)) <= 0.16, "baltor confirm voice should start with the early smile-talk mouth motion")
	_expect(is_equal_approx(float(baltor.get("confirm_intro_voice_volume_db", 0.0)), -5.0), "baltor confirm voice should sit under the character-select BGM")
	_expect(bool(baltor.get("confirm_intro_exit_flash_enabled", false)), "baltor confirm intro should hide the one-shot-to-battle cut with an exit flash")
	_expect(str(baltor.get("confirm_intro_exit_flash_style", "")) == "burst", "baltor exit flash should use a warm gold burst")
	var baltor_intro_sheet := load(str(baltor.get("confirm_intro_sheet_path", ""))) as Texture2D
	_expect(baltor_intro_sheet != null, "baltor confirm intro AutoSprite sheet should load")
	var baltor_voice := load(str(baltor.get("confirm_intro_voice_path", ""))) as AudioStream
	_expect(baltor_voice != null, "baltor confirm intro escape voice should load")
	_expect(
		_prewarm_has_job(prewarm, str(baltor.get("confirm_intro_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the baltor confirm intro sheet"
	)
	_expect(
		_prewarm_has_job(prewarm, str(baltor.get("confirm_intro_voice_path", "")), "AudioStream"),
		"character-select loading screen should prewarm the baltor confirm intro voice"
	)
	_expect(
		str(viper.get("live2d_preview_still_path", "")).ends_with("viper_card_headhand_blade_lips_pose_imagegen_v4_cutout_clean_padded.png"),
		"viper preview still should use the close head-hand blade-lips card asset"
	)
	_expect(
		str(viper.get("live2d_fullframe_sheet_path", "")).ends_with("viper_blade_lips_headhand_idle_loop49_autosprite_v1_realesrgan_animev3_hq1536_safe.png"),
		"viper preview should show the calm head-hand blade-lips Real-ESRGAN hq1536 AutoSprite loop first"
	)
	_expect(int(viper.get("live2d_fullframe_count", 0)) == 49, "viper blade-lick loop preview should expose the native 49-frame loop")
	var viper_idle_stage_scale := float(viper.get("live2d_stage_scale", 0.0))
	_expect(viper_idle_stage_scale >= 1.04 and viper_idle_stage_scale <= 1.06, "viper idle Live2D should scale up slightly while preserving the confirm one-shot apparent-size match")
	var viper_idle_stage_y_offset := float(viper.get("live2d_stage_y_offset", 0.0))
	_expect(viper_idle_stage_y_offset >= 0.055 and viper_idle_stage_y_offset <= 0.065, "viper idle Live2D should sit low enough for the thigh crop to meet the bottom line")
	_expect(float(viper.get("live2d_stage_min_top_ratio", -1.0)) > 0.0, "viper preview should reserve top margin against hair clipping")
	var viper_idle_candidates: Array = viper.get("live2d_fullframe_sheet_candidates", [])
	var viper_idle_trim := Rect2()
	if viper_idle_candidates.size() > 0 and viper_idle_candidates[0] is Dictionary:
		var viper_idle_candidate: Dictionary = viper_idle_candidates[0]
		if viper_idle_candidate.get("trim_rect", null) is Rect2:
			viper_idle_trim = viper_idle_candidate.get("trim_rect")
	_expect(is_equal_approx(viper_idle_trim.position.x, 0.0) and is_equal_approx(viper_idle_trim.position.y, 0.0), "viper idle trim should use the full intact-head source canvas")
	_expect(is_equal_approx(viper_idle_trim.size.x, 1536.0) and is_equal_approx(viper_idle_trim.size.y, 1536.0), "viper idle trim should keep the full 1536 px source canvas against hair clipping")
	_expect(
		str(viper.get("full_body_live2d_sheet_path", "")).ends_with("viper_serin_fullbody_closed_suit_idle_loop49_autosprite_asset_v2_realesrgan_animev3_hq1024_safe.png"),
		"viper right-side full-body panel should use the Real-ESRGAN hq1024 closed-suit full-body Live2D loop"
	)
	_expect(int(viper.get("full_body_live2d_cols", 0)) == 7, "viper full-body Live2D should use the 7-column runtime sheet")
	_expect(int(viper.get("full_body_live2d_rows", 0)) == 7, "viper full-body Live2D should use the 7-row runtime sheet")
	_expect(int(viper.get("full_body_live2d_count", 0)) == 49, "viper full-body Live2D should expose the native 49-frame idle loop")
	_expect(viper.get("full_body_live2d_trim_rect", null) is Rect2, "viper full-body Live2D should use a precomputed trim rect")
	var viper_full_body_trim: Rect2 = viper.get("full_body_live2d_trim_rect", Rect2())
	_expect(is_equal_approx(viper_full_body_trim.position.x, 256.0) and is_equal_approx(viper_full_body_trim.position.y, 32.0), "viper full-body trim should remove the wide transparent source padding without clipping hair tips")
	_expect(is_equal_approx(viper_full_body_trim.size.x, 568.0) and is_equal_approx(viper_full_body_trim.size.y, 960.0), "viper full-body trim should use the measured alpha-safe crop for the accepted Real-ESRGAN asset")
	var viper_full_body_stage_scale := float(viper.get("full_body_live2d_stage_scale", 0.0))
	_expect(viper_full_body_stage_scale >= 0.975 and viper_full_body_stage_scale <= 0.985, "viper full-body AutoSprite Live2D should use the cropped source scale to match the other full-body panels")
	var viper_full_body_sheet := load(str(viper.get("full_body_live2d_sheet_path", ""))) as Texture2D
	_expect(viper_full_body_sheet != null, "viper full-body Live2D sheet should load")
	if viper_full_body_sheet != null:
		_expect(viper_full_body_sheet.get_size() == Vector2(7168, 7168), "viper full-body Real-ESRGAN asset sheet should use 1024 px cells in a 7x7 grid")
	_expect(
		_prewarm_has_job(prewarm, str(viper.get("full_body_live2d_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the viper full-body Live2D sheet"
	)
	_expect(
		str(viper.get("confirm_intro_sheet_path", "")).ends_with("viper_select_confirm_idle_to_mumble_slash_loop98_autosprite_v13_jetpackflame_clean_realesrgan_animev3_hq1152_safe.png"),
		"viper confirm intro should use the Real-ESRGAN hq1152 unified idle-to-mumble-slash click one-shot with cleaned idle jetpack flame detail"
	)
	_expect(int(viper.get("confirm_intro_cols", 0)) == 14, "viper confirm intro should use the 14-column runtime sheet")
	_expect(int(viper.get("confirm_intro_rows", 0)) == 7, "viper confirm intro should use the 7-row runtime sheet")
	_expect(int(viper.get("confirm_intro_count", 0)) == 98, "viper confirm intro should expose the unified 49-frame AutoSprite motion held twice")
	_expect(float(viper.get("confirm_intro_interval", 0.0)) <= 0.022, "viper confirm intro should keep smasher-style duplicate-frame pacing")
	_expect(float(viper.get("confirm_intro_min_duration", 0.0)) >= 1.95, "viper confirm intro should last through all 98 frames")
	var viper_confirm_stage_scale := float(viper.get("confirm_intro_stage_scale", 0.0))
	_expect(viper_confirm_stage_scale >= 0.905 and viper_confirm_stage_scale <= 0.915, "viper confirm intro should stay slightly smaller than the idle Live2D after the latest click-size reduction")
	_expect(viper_idle_stage_scale * viper_confirm_stage_scale >= 0.95 and viper_idle_stage_scale * viper_confirm_stage_scale <= 0.96, "viper confirm intro should render below the idle apparent size without changing the idle Live2D")
	_expect(bool(viper.get("confirm_intro_trim_transparent_source", false)), "viper confirm intro should trim its transparent source for stable scale")
	_expect(viper.get("confirm_intro_trim_rect", null) is Rect2, "viper confirm intro should use a precomputed trim rect")
	var viper_confirm_trim: Rect2 = viper.get("confirm_intro_trim_rect", Rect2())
	_expect(viper_confirm_trim.size.x >= 810.0 and viper_confirm_trim.size.y >= 1020.0, "viper confirm intro trim should preserve the upscaled unified blade-slash motion")
	_expect(is_equal_approx(float(viper.get("confirm_intro_stage_x_offset_ratio", 0.0)), -0.042), "viper confirm intro should apply the refined rightward offset")
	var viper_confirm_effective_y_offset := viper_idle_stage_y_offset + float(viper.get("confirm_intro_stage_y_offset_ratio", 0.0))
	_expect(viper_confirm_effective_y_offset >= 0.041 and viper_confirm_effective_y_offset <= 0.043, "viper confirm intro should apply the refined upward offset")
	_expect(
		str(viper.get("confirm_intro_voice_path", "")).ends_with("viper_select_confirm_puppy_clean_v7_ang_wang.mp3"),
		"viper confirm intro should use the short clean puppy voice candidate"
	)
	_expect(float(viper.get("confirm_intro_voice_delay", -1.0)) <= 0.30, "viper confirm voice should start with the early unified mouth motion")
	_expect(is_equal_approx(float(viper.get("confirm_intro_voice_volume_db", 0.0)), -5.0), "viper confirm voice should sit under the character-select BGM")
	_expect(bool(viper.get("confirm_intro_exit_flash_enabled", false)), "viper confirm intro should hide the one-shot-to-battle cut with an exit flash")
	_expect(str(viper.get("confirm_intro_exit_flash_style", "")) == "slash", "viper exit flash should use the blade-slash style")
	_expect(float(viper.get("confirm_intro_exit_flash_duration", 0.0)) >= 0.50, "viper exit flash should sustain the modular VFX through the white wash bridge")
	_expect(float(viper.get("confirm_intro_exit_flash_white_wash_target", 0.0)) > 0.85, "viper exit flash should bridge into the next scene with a near-full white wash")
	_expect(float(viper.get("confirm_intro_exit_flash_field_intensity", 0.0)) > 0.0, "viper exit flash should expose a field intensity tuning hook")
	_expect(float(viper.get("confirm_intro_exit_flash_chroma", 0.0)) > 0.0, "viper exit flash should expose a chromatic aberration tuning hook")
	_expect(not bool(viper.get("confirm_intro_float_motion_enabled", true)), "viper confirm intro should not layer runtime bob over the AutoSprite swing")
	var viper_texture := load(str(viper.get("live2d_preview_still_path", ""))) as Texture2D
	_expect(viper_texture != null, "viper padded cutout card asset should load")
	var viper_sheet := load(str(viper.get("live2d_fullframe_sheet_path", ""))) as Texture2D
	_expect(viper_sheet != null, "viper Real-ESRGAN blade-lick AutoSprite sheet should load")
	if viper_sheet != null:
		_expect(viper_sheet.get_size() == Vector2(10752, 10752), "viper Real-ESRGAN idle sheet should use 1536 px cells in a 7x7 grid")
	var viper_intro_sheet := load(str(viper.get("confirm_intro_sheet_path", ""))) as Texture2D
	_expect(viper_intro_sheet != null, "viper Real-ESRGAN confirm intro AutoSprite sheet should load")
	if viper_intro_sheet != null:
		_expect(viper_intro_sheet.get_size() == Vector2(16128, 8064), "viper Real-ESRGAN confirm intro sheet should use 1152 px cells in a 14x7 grid")
	var viper_voice := load(str(viper.get("confirm_intro_voice_path", ""))) as AudioStream
	_expect(viper_voice != null, "viper confirm intro puppy voice should load")
	_expect(
		_prewarm_has_job(prewarm, str(viper.get("confirm_intro_sheet_path", "")), "Texture2D"),
		"character-select loading screen should prewarm the viper confirm intro sheet"
	)
	_expect(
		_prewarm_has_job(prewarm, str(viper.get("confirm_intro_voice_path", "")), "AudioStream"),
		"character-select loading screen should prewarm the viper confirm intro voice"
	)

	state.set_character(smasher)
	state.set_league_mode("champion")
	state.set_stage(1)

	var screen: Control = CharacterSelectScene.instantiate()
	screen.auto_start_battle = false
	root.add_child(screen)
	_expect(str(screen.get("main_menu_scene_path")) == "res://scenes/main_menu.tscn", "character select back button should target the main menu scene by default")
	_expect(FileAccess.file_exists(str(screen.get("main_menu_scene_path"))), "character select back target scene should exist")
	_expect_character_select_bgm_loop(screen)
	var layout_size := Vector2(2048.0, 1365.0)
	var card_rects_value: Variant = screen._layout_cards(layout_size)
	_expect(card_rects_value is Dictionary, "character select should produce card rects for the visible characters")
	if card_rects_value is Dictionary:
		var card_rects: Dictionary = card_rects_value
		_expect(not card_rects.is_empty(), "character select should lay out at least one card")
	var preview_rect: Rect2 = screen._preview_rect(layout_size)
	_expect(preview_rect.size.x >= 280.0, "character select preview panel should keep a usable center width")
	var info_rect: Rect2 = screen._info_panel_rect(layout_size, preview_rect)
	_expect(preview_rect.size.x > info_rect.size.x * 1.55, "character select upper-body preview grid should be much wider than the full-body info grid")
	_expect(info_rect.size.x <= 510.0, "character select full-body info grid should keep the narrow screenshot-style width")
	_expect(preview_rect.end.x <= info_rect.position.x - 18.0, "character select preview and info grids should keep a clean gap")
	_expect_full_body_floor_matches_rena(screen, info_rect)
	var preview_node: Control = screen.get_node_or_null("LivePreview")
	_expect(preview_node != null and preview_node.clip_contents, "card-style character preview should clip inside its frame")
	_expect_click_motion_voice(screen, smasher, "smasher", "voice/smasherselect.mp3", 0.78, -6.0)
	if preview_node != null:
		var smasher_click_config: Dictionary = screen._build_preview_click_motion_config(smasher)
		_expect(str(smasher_click_config.get("path", "")).ends_with("smasher_select_confirm_swing_bada_loop98_autosprite_v2_stable_realesrgan_animev3_hq1152_safe.png"), "smasher preview click config should route to the original click Live2D")
		_expect(is_equal_approx(float(smasher_click_config.get("min_duration", 0.0)), float(smasher.get("confirm_intro_min_duration", 0.0))), "smasher preview click config should preserve the confirm intro minimum duration")
		_expect(str(smasher_click_config.get("return_sheet_path", "")) == "", "smasher preview click config should omit the reverse return Live2D")
		_expect(is_equal_approx(float(smasher_click_config.get("return_transition_duration", 0.18)), 0.0), "smasher preview click config should disable the old final-frame return ghost")
	_expect_click_motion_voice(screen, commando, "commando", "voice/commandoselect.mp3", 0.25, -5.0)
	var baltor_index: int = _find_character_index(screen.characters, "blacksmith")
	_expect(baltor_index >= 0, "character select screen should expose the baltor card")
	_expect(screen.visible_indices.has(baltor_index), "unlocked Kohaku should stay visible in character select")
	_expect_face_card_crop(screen, baltor_index, "baltor")
	_expect(screen.full_body_live2d_textures.has(baltor_index), "baltor right panel should preload the full-body Live2D sheet")
	screen._select_index(baltor_index)
	var _before_locked_confirm: Dictionary = state.get_selection()
	screen._confirm_selection()
	var after_locked_confirm: Dictionary = state.get_selection()
	_expect(str(after_locked_confirm.get("character_id", "")) == "blacksmith", "unlocked Kohaku confirm should store Blacksmith as the selected playable character")
	_expect(float(screen.get("locked_character_feedback_timer")) <= 0.0, "unlocked Kohaku confirm should not arm unlock-required feedback")
	if preview_node != null:
		var baltor_one_shot_config := _confirm_intro_config(screen.characters[baltor_index])
		_expect(bool(preview_node.call("play_fullframe_one_shot", baltor_one_shot_config)), "baltor confirm intro should play through the Live2D preview one-shot path")
		_expect(bool(preview_node.call("is_one_shot_playing")), "baltor confirm intro should remain active after starting")
		_expect(is_equal_approx(float(preview_node.get("one_shot_min_duration")), float(screen.characters[baltor_index].get("confirm_intro_min_duration", 0.0))), "baltor confirm intro should preserve the configured minimum duration in the preview runtime")
		_expect(int(preview_node.get("fullframe_cols")) == 14, "baltor confirm intro should use the 14-column click sheet")
		_expect(int(preview_node.get("fullframe_rows")) == 7, "baltor confirm intro should use the 7-row 98-frame click sheet")
		_expect(int(preview_node.get("fullframe_count")) == 98, "baltor confirm intro should expose all 98 smile-talk frames")
		_expect(preview_node.get("fullframe_sheet_texture") is Texture2D, "baltor confirm intro should load the clean-edge smile-talk Texture2D")
		var baltor_stage_offset_value: Variant = preview_node.get("one_shot_stage_offset_ratio")
		_expect(baltor_stage_offset_value is Vector2 and is_zero_approx(float(baltor_stage_offset_value.x)), "baltor confirm intro should keep zero extra runtime x offset")
		_expect(baltor_stage_offset_value is Vector2 and is_zero_approx(float(baltor_stage_offset_value.y)), "baltor confirm intro should keep zero extra runtime y offset")
		_expect(is_equal_approx(float(preview_node.get("one_shot_stage_scale")), 1.0), "baltor confirm intro should inherit the idle runtime scale")
		_expect(bool(preview_node.get("one_shot_align_bottom_to_cutline")), "baltor confirm intro should pass bottom cutline alignment into the one-shot preview")
	var optimus_index: int = _find_character_index(screen.characters, "optimus")
	_expect(optimus_index >= 0, "character select screen should expose the optimus card")
	_expect(screen.visible_indices.has(optimus_index), "locked Io should stay visible in character select")
	var viper_index: int = _find_character_index(screen.characters, "viper")
	_expect(viper_index >= 0, "character select screen should expose the viper card")
	_expect_face_card_crop(screen, viper_index, "viper")
	_expect(screen.full_body_live2d_textures.has(viper_index), "viper right panel should preload the full-body Live2D sheet")
	_expect_click_motion_voice(screen, viper, "viper", "viper_select_confirm_puppy_clean_v7_ang_wang.mp3", 0.22, -5.0)
	screen._select_index(viper_index)
	if preview_node != null:
		var click_motion_config: Dictionary = screen._build_preview_click_motion_config(screen.characters[viper_index])
		_expect(str(click_motion_config.get("path", "")).ends_with("viper_select_confirm_idle_to_mumble_slash_loop98_autosprite_v13_jetpackflame_clean_realesrgan_animev3_hq1152_safe.png"), "viper preview click should route to the accepted upper-body Live2D one-shot")
		_expect(bool(click_motion_config.get("restore_after_finish", false)), "preview click Live2D should restore to the idle upper-body loop after playback")
		_expect(is_equal_approx(float(click_motion_config.get("min_duration", 0.0)), float(screen.characters[viper_index].get("confirm_intro_min_duration", 0.0))), "viper preview click config should preserve the confirm intro minimum duration")
		_expect(bool(preview_node.call("play_fullframe_one_shot", click_motion_config)), "viper preview click Live2D should start through the LivePreview one-shot path")
		_expect(bool(preview_node.call("is_one_shot_playing")), "viper preview click Live2D should remain active immediately after starting")
		var one_shot_config := _confirm_intro_config(screen.characters[viper_index])
		_expect(bool(preview_node.call("play_fullframe_one_shot", one_shot_config)), "viper confirm intro should play through the Live2D preview one-shot path")
		_expect(bool(preview_node.call("is_one_shot_playing")), "viper confirm intro should remain active after starting")
		_expect(is_equal_approx(float(preview_node.get("one_shot_min_duration")), float(screen.characters[viper_index].get("confirm_intro_min_duration", 0.0))), "viper confirm intro should preserve the configured minimum duration in the preview runtime")
		_expect(int(preview_node.get("fullframe_cols")) == 14, "viper confirm intro should use the 14-column click sheet")
		_expect(int(preview_node.get("fullframe_rows")) == 7, "viper confirm intro should use the 7-row click sheet")
		_expect(int(preview_node.get("fullframe_count")) == 98, "viper confirm intro should expose all 98 held frames")
		_expect(preview_node.get("fullframe_sheet_texture") is Texture2D, "viper confirm intro should load the v13 flame-clean Texture2D")
		_expect(is_equal_approx(float(preview_node.get("one_shot_stage_scale")), 0.91), "viper confirm intro should apply the reduced one-shot scale")
		var stage_offset_value: Variant = preview_node.get("one_shot_stage_offset_ratio")
		_expect(stage_offset_value is Vector2 and is_equal_approx(float(stage_offset_value.x), -0.042), "viper confirm intro should apply the refined rightward one-shot offset")
		_expect(stage_offset_value is Vector2 and is_equal_approx(float(stage_offset_value.y), -0.018), "viper confirm intro should apply the refined upward one-shot offset")
	if preview_node != null:
		_expect(bool(screen._try_begin_confirm_intro(screen.characters[viper_index], "")), "viper live confirm intro should start through the character-select gate")
		_expect(is_equal_approx(float(preview_node.get("one_shot_min_duration")), float(viper.get("confirm_intro_min_duration", 0.0))), "viper live confirm intro should pass min duration to the preview runtime")
		screen._finish_confirm_intro()
	screen._confirm_selection()
	var selection: Dictionary = state.get_selection()
	_expect(str(selection.get("character_id", "")) == "viper", "confirming viper should store the viper character id")
	_expect(str(selection.get("runtime_character_id", "")) == "viper", "confirming viper should store the viper runtime id")
	_expect(str(selection.get("character_name", "")) != "", "confirming viper from character select should store Serin as the display name")

	_expect(int(screen.selected_index) == viper_index, "selection screen should keep viper selected after confirmation")

	var owner := FakeBattleOwner.new()
	root.add_child(owner)
	var startup: Object = BattleSceneStartupController.new()
	startup._apply_selection_state(owner)
	_expect(str(owner.data.get("selected_character_id", "")) == "viper", "battle startup should receive viper character id")
	_expect(str(owner.data.get("selected_runtime_character_id", "")) == "viper", "battle startup should receive viper runtime id")
	_expect(str(owner.data.get("selected_character_type", "")) == "viper", "battle startup should start as viper")

	state.set_character({"id": "soldier", "runtime_id": "soldier", "name": "Soldier"})
	selection = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "soldier", "confirming soldier should keep the Commando runtime id")
	state.set_character({"id": "commando", "name": "Commando"})
	selection = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "soldier", "commando alias handoffs should select the Soldier runtime")
	state.set_character({"id": "viper", "name": "Viper"})
	selection = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "viper", "viper id-only handoffs should still select the viper runtime")

	_flush_current_prewarm_job(prewarm)
	if preview_node != null and preview_node.has_method("clear_runtime_state"):
		preview_node.call("clear_runtime_state")
	preview_node = null
	screen.free()
	screen = null
	owner.free()
	owner = null
	prewarm = null
	startup = null
	if state != null and state.get_parent() == root:
		state.free()
	state = null
	ProjectResourceLoader.clear_caches()
	if failure_count > 0:
		call_deferred("_quit_with_code", 1)
		return
	print("character_selection_viper_start_smoke: ok")
	call_deferred("_quit_with_code", 0)


func _quit_with_code(exit_code: int) -> void:
	for _i in range(3):
		await process_frame
	quit(exit_code)


@warning_ignore("shadowed_variable_base_class")
func _get_or_create_selection_state(root: Node) -> Node:
	var state: Node = root.get_node_or_null("GameSelectionState")
	if state != null:
		return state
	state = GameSelectionState.new()
	state.name = "GameSelectionState"
	root.add_child(state)
	return state


func _find_character(characters: Array, character_id: String) -> Dictionary:
	for value in characters:
		if value is Dictionary:
			var character: Dictionary = value
			if str(character.get("id", "")) == character_id:
				return character
	return {}


func _find_character_index(characters: Array, character_id: String) -> int:
	for i in range(characters.size()):
		var character: Variant = characters[i]
		if character is Dictionary and str(character.get("id", "")) == character_id:
			return i
	return -1


func _confirm_intro_config(character: Dictionary) -> Dictionary:
	return {
		"path": str(character.get("confirm_intro_sheet_path", "")),
		"cols": int(character.get("confirm_intro_cols", 1)),
		"rows": int(character.get("confirm_intro_rows", 1)),
		"count": int(character.get("confirm_intro_count", 1)),
		"interval": float(character.get("confirm_intro_interval", 0.02)),
		"min_interval": float(character.get("confirm_intro_min_interval", 0.01)),
		"min_duration": float(character.get("confirm_intro_min_duration", 0.0)),
		"trim_transparent_source": bool(character.get("confirm_intro_trim_transparent_source", true)),
		"trim_rect": character.get("confirm_intro_trim_rect", Rect2()),
		"transition_duration": float(character.get("confirm_intro_transition_duration", 0.0)),
		"stage_scale": float(character.get("confirm_intro_stage_scale", 1.0)),
		"stage_x_offset_ratio": float(character.get("confirm_intro_stage_x_offset_ratio", 0.0)),
		"stage_y_offset_ratio": float(character.get("confirm_intro_stage_y_offset_ratio", 0.0)),
		"float_motion_enabled": bool(character.get("confirm_intro_float_motion_enabled", false)),
		"align_bottom_to_cutline": bool(character.get("confirm_intro_align_bottom_to_cutline", false)),
		"restore_after_finish": true,
	}


func _prewarm_has_job(prewarm: Object, path: String, type_hint: String) -> bool:
	if prewarm == null or path == "":
		return false
	var current_job_value: Variant = prewarm.get("current_job")
	if current_job_value is Dictionary:
		var current_job: Dictionary = current_job_value
		if str(current_job.get("path", "")) == path and str(current_job.get("type", "")) == type_hint:
			return true
	var jobs_value: Variant = prewarm.get("jobs")
	if not (jobs_value is Array):
		return false
	var jobs: Array = jobs_value
	for job_value in jobs:
		if not (job_value is Dictionary):
			continue
		var job: Dictionary = job_value
		if str(job.get("path", "")) == path and str(job.get("type", "")) == type_hint:
			return true
	return false


func _flush_current_prewarm_job(prewarm: Object) -> void:
	if prewarm == null:
		return
	var current_path := str(prewarm.get("current_path"))
	if current_path == "":
		return
	ResourceLoader.load_threaded_get(current_path)
	prewarm.set("current_path", "")
	prewarm.set("current_job", {})
	prewarm.set("active", false)
	prewarm.set("finished", true)


func _expect_modular_exit_flash_overlay(flash_overlay: Control, label: String) -> void:
	var field_rect_value: Variant = flash_overlay.get("_field_rect") if flash_overlay != null else null
	_expect(field_rect_value is ColorRect, "%s exit flash should build the field aurora ColorRect with a shader" % label)
	var halo_rect_value: Variant = flash_overlay.get("_halo_rect") if flash_overlay != null else null
	_expect(halo_rect_value is ColorRect, "%s exit flash should build the card halo ColorRect with a shader" % label)
	var white_rect_value: Variant = flash_overlay.get("_white_rect") if flash_overlay != null else null
	_expect(white_rect_value is ColorRect, "%s exit flash should build the white-wash ColorRect for the scene bridge" % label)
	if field_rect_value is ColorRect:
		var field_rect: ColorRect = field_rect_value
		_expect(field_rect.material is ShaderMaterial, "%s exit flash field rect should be driven by a ShaderMaterial" % label)
	if halo_rect_value is ColorRect:
		var halo_rect: ColorRect = halo_rect_value
		_expect(halo_rect.material is ShaderMaterial, "%s exit flash halo rect should be driven by a ShaderMaterial" % label)


func _expect_face_card_crop(screen: Control, character_index: int, label: String) -> void:
	if character_index < 0:
		return
	var character_value: Variant = screen.characters[character_index]
	_expect(character_value is Dictionary, "%s left card should have character data" % label)
	if not (character_value is Dictionary):
		return
	var texture: Texture2D = screen.portrait_textures.get(character_index, null) as Texture2D
	_expect(texture != null, "%s left card portrait texture should load" % label)
	if texture == null:
		return
	var character: Dictionary = character_value
	var source: Rect2 = screen._character_card_face_source_rect(
		texture,
		Rect2(Vector2.ZERO, Vector2(220.0, 180.0)),
		character
	)
	var texture_size := texture.get_size()
	_expect(source.size.y <= texture_size.y * 0.46, "%s left card should crop to a face portrait instead of the full body image" % label)
	_expect(source.position.y <= texture_size.y * 0.36, "%s left card face crop should stay near the upper portrait" % label)
	_expect(source.end.y <= texture_size.y * 0.66, "%s left card face crop should avoid lower-body framing" % label)


func _expect_full_body_floor_matches_rena(screen: Control, info_rect: Rect2) -> void:
	var full_body_rect := Rect2(
		info_rect.position + Vector2(22.0, 252.0),
		Vector2(info_rect.size.x - 44.0, max(180.0, info_rect.size.y - 272.0))
	)
	var target := full_body_rect.grow(-10.0)
	var reference_bottom := -1.0
	for character_value in screen.characters:
		if not (character_value is Dictionary):
			continue
		var character: Dictionary = character_value
		if str(character.get("id", "")) != "soldier":
			continue
		reference_bottom = _full_body_draw_bottom(screen, target, character)
		break
	_expect(reference_bottom > 0.0, "Rena full-body panel should provide the shared floor baseline")
	if reference_bottom <= 0.0:
		return
	for character_value in screen.characters:
		if not (character_value is Dictionary):
			continue
		var character: Dictionary = character_value
		var draw_rect: Rect2 = _full_body_draw_rect(screen, target, character)
		var draw_bottom := draw_rect.end.y
		if draw_bottom <= 0.0:
			continue
		var display_name := str(character.get("character_name", character.get("name", "")))
		_expect(abs(draw_bottom - reference_bottom) <= 0.05, "%s full-body foot baseline should match Rena" % display_name)
		_expect(draw_rect.position.y >= target.position.y - 0.05, "%s full-body art should stay inside the top of the right panel after floor alignment" % display_name)


func _full_body_draw_bottom(screen: Control, target: Rect2, character: Dictionary) -> float:
	var draw_rect := _full_body_draw_rect(screen, target, character)
	return draw_rect.end.y


func _full_body_draw_rect(screen: Control, target: Rect2, character: Dictionary) -> Rect2:
	var trim_value: Variant = character.get("full_body_live2d_trim_rect", Rect2())
	if not (trim_value is Rect2):
		return Rect2()
	var trim: Rect2 = trim_value
	if trim.size.x <= 1.0 or trim.size.y <= 1.0:
		return Rect2()
	return screen._build_full_body_live2d_fit_rect(trim.size, target, character)


func _expect_click_motion_voice(screen: Control, character: Dictionary, label: String, expected_suffix: String, expected_delay: float, expected_volume: float) -> void:
	screen._stop_click_motion_voice()
	var configured_path := str(character.get("click_motion_voice_path", ""))
	if configured_path == "":
		configured_path = str(character.get("confirm_intro_voice_path", ""))
	_expect(configured_path.ends_with(expected_suffix), "%s click Live2D voice should resolve to the accepted select voice asset" % label)
	screen._prepare_click_motion_voice(character)
	var player := screen.get("click_motion_voice_player") as AudioStreamPlayer
	_expect(player != null, "%s click Live2D voice should have an AudioStreamPlayer" % label)
	if player == null:
		return
	_expect(player.stream != null, "%s click Live2D voice should load a stream" % label)
	_expect(bool(screen.get("click_motion_voice_pending")), "%s click Live2D voice should arm delayed playback" % label)
	_expect(is_equal_approx(float(screen.get("click_motion_voice_delay_remaining")), expected_delay), "%s click Live2D voice should inherit the tuned delay" % label)
	_expect(is_equal_approx(player.volume_db, expected_volume), "%s click Live2D voice should inherit the tuned volume" % label)
	screen._stop_click_motion_voice()


func _expect_character_select_bgm_loop(screen: Control) -> void:
	var player := screen.get("character_select_bgm_player") as AudioStreamPlayer
	_expect(player != null, "character-select BGM player should be created")
	if player == null:
		return
	_expect(player.stream != null, "character-select BGM player should load the BGM stream")
	var callback := Callable(screen, "_on_character_select_bgm_finished")
	_expect(player.is_connected("finished", callback), "character-select BGM should reconnect through the finished signal for looping")
	player.stop()
	screen._on_character_select_bgm_finished()
	_expect(player.playing, "character-select BGM should restart when the stream finishes")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
