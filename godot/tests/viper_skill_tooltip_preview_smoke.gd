extends SceneTree

const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failed := false


class FakePerkState:
	var levels := {}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))


func _init() -> void:
	var renderer: Object = TooltipRenderer.new()
	var common_skill_ids: Array[String] = CommonSkillCatalog.get_all_skill_ids()
	var viper_config: Object = ViperSkillConfig.new()
	var viper_snapshot: Dictionary = viper_config.get_snapshot()
	var viper_skill_data: Dictionary = viper_snapshot.get("skill_data", {}) as Dictionary
	_assert_character_preview_families(renderer, viper_skill_data, common_skill_ids, "viper", "Viper")
	_assert_common_skill_preview_families(renderer, viper_skill_data, common_skill_ids, "Viper")

	var smasher_config: Object = SmasherSkillConfig.new()
	var smasher_snapshot: Dictionary = smasher_config.get_snapshot()
	var smasher_skill_data: Dictionary = smasher_snapshot.get("skill_data", {}) as Dictionary
	_assert_character_preview_families(renderer, smasher_skill_data, common_skill_ids, "smasher", "Smasher")
	_assert_common_skill_preview_families(renderer, smasher_skill_data, common_skill_ids, "Smasher")
	var drive_rows: Array = renderer._get_control_rows("drive", "smasher")
	_expect(drive_rows.size() == 1, "Drive tooltip should keep a single compact control row")
	_expect(str(drive_rows[0][5][1]) == "동시에 누르기", "Drive tooltip action label should explain simultaneous input")

	var commando_config: Object = CommandoSkillConfig.new()
	var commando_snapshot: Dictionary = commando_config.get_snapshot()
	var commando_skill_data: Dictionary = commando_snapshot.get("skill_data", {}) as Dictionary
	_assert_character_preview_families(renderer, commando_skill_data, common_skill_ids, "commando", "Commando")
	_assert_common_skill_preview_families(renderer, commando_skill_data, common_skill_ids, "Commando")
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
	_expect(
		renderer._get_effect_preview_family("unknown_preview_key") == "fallback",
		"unknown preview keys should keep the fallback path"
	)
	if _failed:
		quit(1)
		return
	print("viper_skill_tooltip_preview_smoke: ok")
	quit(0)


func _assert_character_preview_families(
	renderer: Object,
	skill_data_map: Dictionary,
	common_skill_ids: Array[String],
	expected_family: String,
	character_label: String
) -> void:
	for skill_name_value: Variant in skill_data_map.keys():
		var skill_name := str(skill_name_value)
		if common_skill_ids.has(skill_name):
			continue
		var skill_data: Dictionary = skill_data_map.get(skill_name_value, {}) as Dictionary
		var effect_type: String = str(skill_data.get("effect_type", ""))
		_expect(
			renderer._get_effect_preview_family(effect_type) == expected_family,
			"%s effect %s should use the %s preview family" % [character_label, effect_type, expected_family]
		)


func _assert_common_skill_preview_families(
	renderer: Object,
	skill_data_map: Dictionary,
	common_skill_ids: Array[String],
	character_label: String
) -> void:
	for skill_id: String in common_skill_ids:
		var skill_data_value: Variant = skill_data_map.get(skill_id, {})
		_expect(skill_data_value is Dictionary and not (skill_data_value as Dictionary).is_empty(), "%s snapshot should include common skill %s" % [character_label, skill_id])
		if not (skill_data_value is Dictionary) or (skill_data_value as Dictionary).is_empty():
			continue
		var skill_data: Dictionary = skill_data_value as Dictionary
		var effect_type: String = str(skill_data.get("effect_type", ""))
		var expected_family := "vision" if bool(skill_data.get("vision_chosik", false)) else "fallback"
		_expect(
			renderer._get_effect_preview_family(effect_type) == expected_family,
			"%s common effect %s should use the %s preview family" % [character_label, effect_type, expected_family]
		)


func _test_viper_enhancer_bonus_lines_survive_wrap(renderer: Object, viper_config: Object) -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	var font: Font = ThemeDB.fallback_font
	var text_width := 276.0
	var perk_state := FakePerkState.new()
	perk_state.levels = {
		"blade_amp": 3,
		"kick_enhance": 3,
		"four_poisons": 3,
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
	_expect(blade_rendered.find("curve sharply") >= 0, "Air Blade max-invested tooltip should keep the new curve-launch behavior after wrapping")
	_expect(blade_rendered.find("Sword Aura") >= 0, "Air Blade tooltip should keep Sword Aura Inner Art's main bonus line after wrapping")
	_expect(blade_rendered.find("Lv3+: homing") >= 0, "Air Blade tooltip should keep Sword Aura Inner Art's Lv3+ bonus line after wrapping")

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
	_expect(kick_rendered.find("Heavenly Kick") >= 0, "Hwarang Kick tooltip should keep Heavenly Kick Inner Art's main bonus line after wrapping")
	_expect(kick_rendered.find("knockback ball") >= 0, "Hwarang Kick tooltip should keep Heavenly Kick Inner Art's Lv3+ knockback line after wrapping")

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
	_expect(dual_rendered.find("Four Poisons Unity") >= 0, "Dual Glitch tooltip should keep Four Poisons Unity's main bonus line after wrapping")
	_expect(dual_rendered.find("clones copy skills") >= 0, "Dual Glitch tooltip should keep Four Poisons Unity's Lv5 clone-copy line after wrapping")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
