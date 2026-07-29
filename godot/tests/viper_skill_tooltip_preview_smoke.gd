extends SceneTree

const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


class FakePerkState:
	var levels := {}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))


func _init() -> void:
	var renderer: Object = TooltipRenderer.new()
	var viper_config: Object = ViperSkillConfig.new()
	var viper_snapshot: Dictionary = viper_config.get_snapshot()
	for skill_name in (viper_snapshot.get("skill_data", {}) as Dictionary).keys():
		if str(skill_name) == CommonSkillCatalog.SOUL_SUMMON_ART_ID:
			continue
		var skill_data: Dictionary = (viper_snapshot["skill_data"] as Dictionary)[skill_name]
		var effect_type: String = str(skill_data.get("effect_type", ""))
		_expect(
			renderer._get_effect_preview_family(effect_type) == "viper",
			"Viper effect %s should use the Viper preview family" % effect_type
		)

	var smasher_config: Object = SmasherSkillConfig.new()
	var smasher_snapshot: Dictionary = smasher_config.get_snapshot()
	for skill_name in (smasher_snapshot.get("skill_data", {}) as Dictionary).keys():
		if str(skill_name) == CommonSkillCatalog.SOUL_SUMMON_ART_ID:
			continue
		var skill_data: Dictionary = (smasher_snapshot["skill_data"] as Dictionary)[skill_name]
		var effect_type: String = str(skill_data.get("effect_type", ""))
		_expect(
			renderer._get_effect_preview_family(effect_type) == "smasher",
			"Smasher effect %s should stay on the Smasher preview family" % effect_type
		)
	var drive_rows: Array = renderer._get_control_rows("drive", "smasher")
	_expect(drive_rows.size() == 1, "Drive tooltip should keep a single compact control row")
	_expect(str(drive_rows[0][5][1]) == "동시에 누르기", "Drive tooltip action label should explain simultaneous input")

	var commando_config: Object = CommandoSkillConfig.new()
	var commando_snapshot: Dictionary = commando_config.get_snapshot()
	for skill_name in (commando_snapshot.get("skill_data", {}) as Dictionary).keys():
		if str(skill_name) == CommonSkillCatalog.SOUL_SUMMON_ART_ID:
			continue
		var skill_data: Dictionary = (commando_snapshot["skill_data"] as Dictionary)[skill_name]
		var effect_type: String = str(skill_data.get("effect_type", ""))
		_expect(
			renderer._get_effect_preview_family(effect_type) == "commando",
			"Commando effect %s should use the Commando preview family" % effect_type
		)
	var emergency_data: Dictionary = (commando_snapshot["skill_data"] as Dictionary)["emergency_supply"]
	_expect(
		str(emergency_data.get("description", "")).find("최대치") >= 0
			and str(emergency_data.get("description", "")).find("1발씩") < 0,
		"Commando emergency supply tooltip should describe the full reload behavior"
	)
	_expect(
		renderer._get_control_rows("supply_drop", "soldier").size() > 0,
		"Commando supply drop tooltip should expose control rows"
	)
	_expect(
		renderer._get_control_rows("emergency_supply", "commando").size() > 0,
		"Commando emergency supply tooltip should expose control rows"
	)
	_test_viper_enhancer_bonus_lines_survive_wrap(renderer, viper_config)
	var common_effect_type := str(CommonSkillCatalog.get_skill_data().get("effect_type", ""))
	_expect(
		renderer._get_effect_preview_family(common_effect_type) == "fallback",
		"shared Soul Summoning Art should use the character-neutral fallback preview family"
	)

	_expect(
		renderer._get_effect_preview_family("unknown_preview_key") == "fallback",
		"unknown preview keys should keep the fallback path"
	)
	print("viper_skill_tooltip_preview_smoke: ok")
	quit(0)


func _test_viper_enhancer_bonus_lines_survive_wrap(renderer: Object, viper_config: Object) -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	var font: Font = ThemeDB.fallback_font
	var text_width := 276.0
	var perk_state := FakePerkState.new()
	perk_state.levels = {
		"blade_amp": 5,
		"kick_enhance": 5,
		"four_poisons": 5,
	}
	var hover_context := {"runtime_perk_state": perk_state}

	var blade_data: Dictionary = viper_config.get_skill_data("blade_rush")
	var blade_text: String = renderer._build_description_with_runtime_bonus(blade_data, hover_context)
	var blade_lines: Array[String] = renderer._wrap_text(
		blade_text,
		font,
		12,
		text_width,
		renderer._get_description_max_lines(blade_data, hover_context)
	)
	var blade_rendered := "\n".join(blade_lines)
	_expect(blade_rendered.find("Blade Amp") >= 0, "Air Blade tooltip should keep Blade Amp's main bonus line after wrapping")
	_expect(blade_rendered.find("Lv3+: homing") >= 0, "Air Blade tooltip should keep Blade Amp's Lv3+ bonus line after wrapping")

	var kick_data: Dictionary = viper_config.get_skill_data("core_flip")
	var kick_text: String = renderer._build_description_with_runtime_bonus(kick_data, hover_context)
	var kick_lines: Array[String] = renderer._wrap_text(
		kick_text,
		font,
		12,
		text_width,
		renderer._get_description_max_lines(kick_data, hover_context)
	)
	var kick_rendered := "\n".join(kick_lines)
	_expect(kick_rendered.find("Kick Enhance") >= 0, "Hwarang Kick tooltip should keep Kick Enhance's main bonus line after wrapping")
	_expect(kick_rendered.find("knockback ball") >= 0, "Hwarang Kick tooltip should keep Kick Enhance's Lv3+ knockback line after wrapping")

	var dual_data: Dictionary = viper_config.get_skill_data("dual_glitch")
	var dual_text: String = renderer._build_description_with_runtime_bonus(dual_data, hover_context)
	var dual_lines: Array[String] = renderer._wrap_text(
		dual_text,
		font,
		12,
		text_width,
		renderer._get_description_max_lines(dual_data, hover_context)
	)
	var dual_rendered := "\n".join(dual_lines)
	_expect(dual_rendered.find("Four Poisons") >= 0, "Dual Glitch tooltip should keep Four Poisons' main bonus line after wrapping")
	_expect(dual_rendered.find("clones copy skills") >= 0, "Dual Glitch tooltip should keep Four Poisons' Lv5 clone-copy line after wrapping")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
