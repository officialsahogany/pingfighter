extends SceneTree

const CommandoFirearmSelectorRenderer := preload("res://scripts/hud/commando_firearm_selector_renderer.gd")
const CommandoFirearmTooltipRenderer := preload("res://scripts/hud/commando_firearm_tooltip_renderer.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_permanent_firearm_tooltip_uses_final_cooldown()
	_verify_rental_and_base_firearm_tooltip_text()
	_verify_japanese_base_firearm_tooltip_text()
	_verify_spanish_base_firearm_tooltip_text()
	_verify_portuguese_brazil_base_firearm_tooltip_text()

	if _failures.is_empty():
		print("commando_firearm_tooltip_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_permanent_firearm_tooltip_uses_final_cooldown() -> void:
	var selector := CommandoFirearmSelectorRenderer.new()
	var tooltip := CommandoFirearmTooltipRenderer.new()
	var skill_config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()
	skill_config.set_runtime_cooldown_multiplier(0.5)
	_expect(bool(skill_config.unlock_and_equip_skill("bazooka")), "bazooka should unlock for tooltip smoke")
	controller.sync_equipped_permanent(skill_config)
	_expect(bool(controller.set_current_weapon("bazooka")), "bazooka should be selectable for tooltip smoke")

	var panel_state: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var tooltip_state: Dictionary = tooltip.build_hover_state(
		panel_state,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(panel_state.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(not tooltip_state.is_empty(), "hovering the current firearm panel should create tooltip state")
	_expect(str(tooltip_state.get("title", "")) == "바주카포", "permanent firearm tooltip should use the Korean weapon name")
	_expect(str(tooltip_state.get("badge", "")) == "영구", "permanent firearm tooltip should show permanent ownership")
	_expect(str(tooltip_state.get("ammo_text", "")) == "탄약 4/4", "permanent firearm tooltip should expose ammo text")
	_expect(str(tooltip_state.get("ownership_text", "")) == "영구 화기", "permanent firearm tooltip should classify ownership in Korean")
	_expect(str(tooltip_state.get("cooldown_text", "")) == "1초", "firearm tooltip should use final cooldown after multipliers")
	_expect(str(tooltip_state.get("alias_text", "")) == "해금 스킬구슬: 바주카포", "firearm tooltip should explain the unlock orb alias")
	_expect(str(tooltip_state.get("reload_text", "")).contains("재장전"), "permanent firearm tooltip should include reload guidance")

	var snapshot: Dictionary = skill_config.get_snapshot()
	var cooldowns: Dictionary = _get_dict(snapshot.get("cooldown_seconds", {}))
	var skill_data: Dictionary = _get_dict(_get_dict(snapshot.get("skill_data", {})).get("bazooka", {}))
	_expect(is_equal_approx(float(cooldowns.get("bazooka", 0.0)), float(skill_data.get("cooldown", -1.0))), "orb wedge and tooltip data should share the same final cooldown")
	_expect(is_equal_approx(float(cooldowns.get("bazooka", 0.0)), float(tooltip_state.get("cooldown_seconds", -1.0))), "firearm tooltip should match the orb cooldown snapshot")

	_expect(bool(skill_config.unlock_and_equip_skill("commando_pistol")), "Commando pistol should unlock for tooltip smoke")
	controller.sync_equipped_permanent(skill_config)
	_expect(bool(controller.set_current_weapon("commando_pistol")), "Commando pistol should be selectable for tooltip smoke")
	var pistol_panel: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var pistol_tooltip: Dictionary = tooltip.build_hover_state(
		pistol_panel,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(pistol_panel.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(str(pistol_tooltip.get("title", "")) == "베레타", "Commando pistol tooltip should show the Beretta display name")
	_expect(str(pistol_tooltip.get("ammo_text", "")) == "탄약 8/8", "Beretta tooltip should expose its 8-round ammo")
	_expect(str(pistol_tooltip.get("cooldown_text", "")) == "0.5초", "Beretta tooltip should show the doubled internal fire rate")
	_expect(str(pistol_tooltip.get("description", "")).contains("정확도 30%"), "Beretta tooltip should mention the improved accuracy")
	_expect(str(pistol_tooltip.get("reload_text", "")).contains("재장전 스킬"), "Beretta tooltip should explain that ammo is restored by reload skill")

	var outside_state: Dictionary = tooltip.build_hover_state(
		panel_state,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": Vector2(740.0, 740.0),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(outside_state.is_empty(), "firearm tooltip should stay hidden when the panel is not hovered")


func _verify_rental_and_base_firearm_tooltip_text() -> void:
	var selector := CommandoFirearmSelectorRenderer.new()
	var tooltip := CommandoFirearmTooltipRenderer.new()
	var skill_config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()

	var base_panel: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var base_tooltip: Dictionary = tooltip.build_hover_state(
		base_panel,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(base_panel.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(str(base_tooltip.get("title", "")) == "권총", "base firearm tooltip should use the Korean pistol name")
	_expect(str(base_tooltip.get("ammo_text", "")) == "탄약 4/4", "base firearm tooltip should show the four-round pistol magazine")
	_expect(str(base_tooltip.get("ownership_text", "")) == "기본 화기", "base firearm tooltip should classify base ownership")
	_expect(str(base_tooltip.get("cooldown_text", "")) == "1초", "base firearm tooltip should show the original pistol fire cooldown")
	_expect(str(base_tooltip.get("ready_text", "")) == "발사 가능", "base firearm tooltip should show pistol readiness")
	_expect(str(base_tooltip.get("reload_text", "")).contains("150 게이지"), "base firearm tooltip should explain one-round gauge reload")

	_expect(bool(controller.add_rental_weapon("fire_support", 1, 2)), "fire support rental should be available for tooltip smoke")
	_expect(bool(controller.set_current_weapon("fire_support")), "rental fire support should be selectable for tooltip smoke")
	var rental_panel: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var rental_tooltip: Dictionary = tooltip.build_hover_state(
		rental_panel,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(rental_panel.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(str(rental_tooltip.get("title", "")) == "화력지원", "rental firearm tooltip should use the Korean weapon name")
	_expect(str(rental_tooltip.get("badge", "")) == "대여", "rental firearm tooltip should show rental ownership")
	_expect(str(rental_tooltip.get("ammo_text", "")) == "호출권 2/2", "rental firearm tooltip should expose weapon-specific ammo labels")
	_expect(str(rental_tooltip.get("ownership_text", "")) == "대여 화기", "rental firearm tooltip should classify ownership in Korean")
	_expect(str(rental_tooltip.get("reload_text", "")).contains("재장전 대상이 아닙니다"), "rental tooltip should clarify reload exclusion")


func _verify_japanese_base_firearm_tooltip_text() -> void:
	var selector := CommandoFirearmSelectorRenderer.new()
	var tooltip := CommandoFirearmTooltipRenderer.new()
	var skill_config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	var base_panel: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var base_tooltip: Dictionary = tooltip.build_hover_state(
		base_panel,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(base_panel.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(str(base_tooltip.get("ownership_text", "")) == "基本火器", "base firearm ownership should localize to Japanese")
	_expect(str(base_tooltip.get("ready_text", "")) == "発射可能", "base firearm readiness should localize to Japanese")
	_expect(str(base_tooltip.get("reload_text", "")).contains("150ゲージ"), "base firearm reload text should localize to Japanese")
	_expect(str(base_tooltip.get("control_text", "")).contains("左クリック"), "base firearm controls should localize to Japanese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_spanish_base_firearm_tooltip_text() -> void:
	var selector := CommandoFirearmSelectorRenderer.new()
	var tooltip := CommandoFirearmTooltipRenderer.new()
	var skill_config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	var base_panel: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var base_tooltip: Dictionary = tooltip.build_hover_state(
		base_panel,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(base_panel.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(str(base_tooltip.get("ownership_text", "")) == "Arma base", "base firearm ownership should localize to Spanish")
	_expect(str(base_tooltip.get("ready_text", "")) == "Lista para disparar", "base firearm readiness should localize to Spanish")
	_expect(str(base_tooltip.get("reload_text", "")).contains("150"), "base firearm reload text should localize to Spanish")
	_expect(str(base_tooltip.get("control_text", "")).contains("Clic izq."), "base firearm controls should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_portuguese_brazil_base_firearm_tooltip_text() -> void:
	var selector := CommandoFirearmSelectorRenderer.new()
	var tooltip := CommandoFirearmTooltipRenderer.new()
	var skill_config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	var base_panel: Dictionary = selector.build_panel_state(Vector2(120.0, 280.0), 1.0, {"commando_weapon_controller": controller})
	var base_tooltip: Dictionary = tooltip.build_hover_state(
		base_panel,
		Vector2(760.0, 750.0),
		1.0,
		{
			"mouse_pos": _get_rect(base_panel.get("rect", Rect2())).get_center(),
			"skill_config_snapshot": skill_config.get_snapshot(),
		}
	)
	_expect(str(base_tooltip.get("ownership_text", "")) == "Arma base", "base firearm ownership should localize to Brazilian Portuguese")
	_expect(str(base_tooltip.get("ready_text", "")) == "Pronta para disparar", "base firearm readiness should localize to Brazilian Portuguese")
	_expect(str(base_tooltip.get("reload_text", "")).contains("150"), "base firearm reload text should localize to Brazilian Portuguese")
	_expect(str(base_tooltip.get("control_text", "")).contains("Clique esq."), "base firearm controls should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
