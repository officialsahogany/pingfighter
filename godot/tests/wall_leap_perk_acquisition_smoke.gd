extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const ViperSkillState := preload("res://scripts/characters/viper_skill_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	var support := Support.new()
	var catalog := RuntimePerkCatalog.new()
	var choice: Dictionary = catalog.get_perk_data("unlock_wall_leap_raid")
	_expect(str(choice.get("unlocks_skill", "")) == "wall_leap_raid", "catalog unlock must target wall_leap_raid")

	var fixture: Dictionary = support.make_fixture()
	var config: Object = fixture["skill_config"]
	config.equipped_skills = []
	var state := RuntimePerkState.new()
	fixture["registry"].instances["runtime_perk_catalog"] = catalog
	fixture["registry"].instances["runtime_perk_state"] = state
	var accepted: bool = state.apply_choice(choice, fixture["owner"], fixture["registry"])
	_expect(accepted, "perk acquisition must traverse the standard apply-choice unlock path")
	_expect(config.is_skill_equipped("wall_leap_raid"), "acquisition must equip wall leap when a slot is open")
	_expect(int(state.runtime_skill_levels.get("unlock_wall_leap_raid", 0)) == 1, "acquisition must record the unlock level")

	var full_fixture: Dictionary = support.make_fixture()
	var full_config: Object = full_fixture["skill_config"]
	full_config.equipped_skills = ["shadow_step", "marshal_kick", "blade_rush", "nerve_strike", "dive_strike"]
	var full_state := RuntimePerkState.new()
	full_fixture["registry"].instances["runtime_perk_catalog"] = catalog
	full_fixture["registry"].instances["runtime_perk_state"] = full_state
	var original_equipped: Array = full_config.equipped_skills.duplicate()
	var pending_result: bool = full_state.apply_choice(choice, full_fixture["owner"], full_fixture["registry"])
	_expect(not pending_result and full_state.has_pending_unlock_swap(), "full slots must open the standard swap dialog")
	_expect(not full_state.runtime_skill_levels.has("unlock_wall_leap_raid"), "pending swap must not pre-record unlock ownership")
	_expect(full_state.cancel_pending_unlock_swap(full_fixture["owner"]), "swap cancel must be accepted")
	_expect(full_config.equipped_skills == original_equipped and not full_state.runtime_skill_levels.has("unlock_wall_leap_raid"), "swap cancel must be a true no-op")
	full_state.apply_choice(choice, full_fixture["owner"], full_fixture["registry"])
	full_state.unlock_swap_selected_index = 0
	_expect(full_state.confirm_pending_unlock_swap(full_fixture["owner"], full_fixture["registry"]), "swap confirm must complete through shared flow")
	_expect(full_config.is_skill_equipped("wall_leap_raid"), "swap confirm must equip wall leap")
	_expect(int(full_state.runtime_skill_levels.get("unlock_wall_leap_raid", 0)) == 1, "swap confirm must commit unlock ownership")

	var skill_state := ViperSkillState.new()
	skill_state.trigger_configured_cooldown("wall_leap_raid", Time.get_ticks_msec(), full_config)
	var config_save: Dictionary = full_config.build_save_snapshot()
	var cooldown_save: Dictionary = skill_state.build_save_snapshot()
	var unlock_save: Dictionary = full_state.build_unlock_save_snapshot()
	var restored_config := ViperSkillConfig.new()
	var restored_state := ViperSkillState.new()
	var restored_perks := RuntimePerkState.new()
	_expect(bool(restored_config.apply_save_snapshot(config_save).get("restored", false)), "equipped-slot save must restore")
	_expect(bool(restored_state.apply_save_snapshot(cooldown_save).get("restored", false)), "cooldown save must restore")
	_expect(bool(restored_perks.apply_unlock_save_snapshot(unlock_save).get("restored", false)), "unlock-level save must restore")
	_expect(restored_config.is_skill_equipped("wall_leap_raid"), "load must restore equipped wall leap")
	_expect(restored_state.get_configured_cooldown_remaining("wall_leap_raid", Time.get_ticks_msec(), restored_config) > 0.0, "load must restore live cooldown")
	_expect(int(restored_perks.runtime_skill_levels.get("unlock_wall_leap_raid", 0)) == 1, "load must restore unlock flag")
	_verify_localization(catalog, restored_config)
	_finish()


func _verify_localization(catalog: Object, config: Object) -> void:
	var previous := LanguageSettings.get_language()
	var expected_skill_names := {
		"ko": "월담야습",
		"en": "Wall-Leap Night Raid",
		"zh": "越墙夜袭",
		"ja": "壁越え夜襲",
		"es": "Incursión nocturna sobre el muro",
		"pt-BR": "Incursão noturna sobre o muro",
		"ru": "Ночной рейд через стену",
	}
	var expected_perk_names := {
		"ko": "월담야습 비급",
		"en": "Wall-Leap Night Raid Manual",
		"zh": "越墙夜袭秘笈",
		"ja": "壁越え夜襲の秘伝書",
		"es": "Manual de incursión nocturna sobre el muro",
		"pt-BR": "Manual da incursão noturna sobre o muro",
		"ru": "Руководство по ночному рейду через стену",
	}
	for language in expected_skill_names.keys():
		LanguageSettings.set_language(language)
		var perk: Dictionary = catalog.get_perk_data("unlock_wall_leap_raid")
		var skill: Dictionary = config.get_skill_data("wall_leap_raid")
		_expect(str(perk.get("name", "")) == str(expected_perk_names[language]), "%s perk localization must use its authored language" % language)
		_expect(str(skill.get("korean", "")) == str(expected_skill_names[language]), "%s skill localization must use its authored language" % language)
		for control_token in ["잠입", "참격", "폭발", "기력 160 필요 · 100 소모", "60 소모 · 둔화 5초", "150 소모 · 기절 3초"]:
			var translated := LanguageSettings.translate_text(control_token)
			_expect(not translated.is_empty(), "%s control hint localization must exist" % language)
			if language != "ko":
				_expect(translated != control_token, "%s control hint must not fall back to Korean: %s" % [language, control_token])
	LanguageSettings.set_language(previous)


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_perk_acquisition_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
