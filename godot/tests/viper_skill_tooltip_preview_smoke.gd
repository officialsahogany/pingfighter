extends SceneTree

const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")


func _init() -> void:
	var renderer: Object = TooltipRenderer.new()
	var viper_config: Object = ViperSkillConfig.new()
	var viper_snapshot: Dictionary = viper_config.get_snapshot()
	for skill_name in (viper_snapshot.get("skill_data", {}) as Dictionary).keys():
		var skill_data: Dictionary = (viper_snapshot["skill_data"] as Dictionary)[skill_name]
		var effect_type: String = str(skill_data.get("effect_type", ""))
		_expect(
			renderer._get_effect_preview_family(effect_type) == "viper",
			"Viper effect %s should use the Viper preview family" % effect_type
		)

	var smasher_config: Object = SmasherSkillConfig.new()
	var smasher_snapshot: Dictionary = smasher_config.get_snapshot()
	for skill_name in (smasher_snapshot.get("skill_data", {}) as Dictionary).keys():
		var skill_data: Dictionary = (smasher_snapshot["skill_data"] as Dictionary)[skill_name]
		var effect_type: String = str(skill_data.get("effect_type", ""))
		_expect(
			renderer._get_effect_preview_family(effect_type) == "smasher",
			"Smasher effect %s should stay on the Smasher preview family" % effect_type
		)

	var commando_config: Object = CommandoSkillConfig.new()
	var commando_snapshot: Dictionary = commando_config.get_snapshot()
	for skill_name in (commando_snapshot.get("skill_data", {}) as Dictionary).keys():
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

	_expect(
		renderer._get_effect_preview_family("unknown_preview_key") == "fallback",
		"unknown preview keys should keep the fallback path"
	)
	print("viper_skill_tooltip_preview_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
