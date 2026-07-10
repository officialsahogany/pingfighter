extends SceneTree

const GameplayHudModuleCatalog := preload("res://scripts/resources/gameplay_hud_module_catalog.gd")
const HornStrawberrySkillPillarRenderer := preload("res://scripts/hud/horn_strawberry_skill_pillar_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")

var _failures: Array[String] = []


class FakeSelectorRenderer:
	extends RefCounted

	var build_count := 0

	func build_panel_state(_panel_center: Vector2, _scale_factor: float, _context: Dictionary) -> Dictionary:
		build_count += 1
		return {
			"rect": Rect2(Vector2(10.0, 20.0), Vector2(100.0, 40.0)),
		}


func _init() -> void:
	_verify_catalog_registration()
	_verify_context_and_ready_state()
	_verify_tooltip_data_and_hover()
	_verify_orb_key_label_layout()
	_verify_commando_panel_hidden_while_transformed()

	if _failures.is_empty():
		print("horn_strawberry_skill_hud_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_registration() -> void:
	var catalog := GameplayHudModuleCatalog.new()
	var spec: Dictionary = catalog.get_spec("horn_strawberry_skill_pillar_renderer")
	_expect(not spec.is_empty(), "horn strawberry skill HUD renderer should be registered in the HUD catalog")
	_expect(str(spec.get("path", "")) == "res://scripts/hud/horn_strawberry_skill_pillar_renderer.gd", "horn strawberry HUD catalog path should point at the renderer")


func _verify_context_and_ready_state() -> void:
	var renderer := HornStrawberrySkillPillarRenderer.new()
	var skill_context: Dictionary = _build_skill_context(renderer, 450.0)
	var skill_order: Array = skill_context.get("equipped_skills", [])
	_expect(int(skill_context.get("max_slots", 0)) == 4, "horn strawberry HUD should expose four skill slots")
	_expect(skill_order.size() == 4, "horn strawberry HUD should equip four transformed skills")
	_expect(str(skill_order[0]) == "horn_strawberry_horn_charge", "W horn charge should be the first transformed orb")
	_expect(str(skill_order[1]) == "horn_strawberry_field", "S field should be the second transformed orb")
	_expect(str(skill_order[2]) == "horn_strawberry_eat", "Space/click eat should be the third transformed orb")
	_expect(str(skill_order[3]) == "horn_strawberry_bomb", "A+D bomb should be the fourth transformed orb")

	var costs: Dictionary = skill_context.get("skill_costs", {})
	_expect(is_equal_approx(float(costs.get("horn_strawberry_horn_charge", 0.0)), 300.0), "horn charge HUD cost should be 300")
	_expect(is_equal_approx(float(costs.get("horn_strawberry_field", 0.0)), 100.0), "field HUD cost should be 100")
	_expect(is_equal_approx(float(costs.get("horn_strawberry_eat", 0.0)), 50.0), "eat HUD cost should be 50")
	_expect(is_equal_approx(float(costs.get("horn_strawberry_bomb", 0.0)), 400.0), "bomb HUD cost should be 400")

	# Python-original orb colors: charge (220,40,50), field (50,150,40) green,
	# eat (240,220,100) yellow, bomb (255,80,40) orange.
	var colors: Dictionary = skill_context.get("skill_colors", {})
	_expect(_color_matches(colors.get("horn_strawberry_horn_charge"), Color8(220, 40, 50)), "horn charge orb color should match the Python original red")
	_expect(_color_matches(colors.get("horn_strawberry_field"), Color8(50, 150, 40)), "field orb color should match the Python original green")
	_expect(_color_matches(colors.get("horn_strawberry_eat"), Color8(240, 220, 100)), "eat orb color should match the Python original yellow")
	_expect(_color_matches(colors.get("horn_strawberry_bomb"), Color8(255, 80, 40)), "bomb orb color should match the Python original orange")

	var cooldown_ratios: Dictionary = skill_context.get("skill_cooldown_remaining_ratios", {})
	_expect(is_equal_approx(float(cooldown_ratios.get("horn_strawberry_horn_charge", 0.0)), 0.5), "horn charge HUD cooldown wedge should use remaining/max")
	var ready: Dictionary = skill_context.get("skill_ready_overrides", {})
	_expect(not bool(ready.get("horn_strawberry_horn_charge", true)), "horn charge should not be ready during cooldown")
	_expect(not bool(ready.get("horn_strawberry_field", true)), "field should not be ready while holding")
	_expect(bool(ready.get("horn_strawberry_eat", false)), "eat should be ready when gauge and cooldown allow it")
	_expect(bool(ready.get("horn_strawberry_bomb", false)), "bomb should be ready when gauge and cooldown allow it")

	var progress: Dictionary = skill_context.get("skill_progress_overrides", {})
	_expect(is_equal_approx(float(progress.get("horn_strawberry_field", 0.0)), 0.5), "field hold progress should be exposed to the HUD ring")

	var slot_renderer := SmasherSkillOrbSlotRenderer.new()
	_expect(
		is_equal_approx(slot_renderer._get_cooldown_remaining(null, "horn_strawberry_horn_charge", 0, {}, skill_context), 0.5),
		"shared orb slot renderer should honor transformed cooldown ratio overrides"
	)
	_expect(
		slot_renderer._is_activation_condition_met("horn_strawberry_eat", skill_context),
		"shared orb slot renderer should honor transformed ready overrides"
	)
	_expect(
		not slot_renderer._is_activation_condition_met("horn_strawberry_field", skill_context),
		"shared orb slot renderer should honor transformed not-ready overrides"
	)


func _verify_tooltip_data_and_hover() -> void:
	var renderer := HornStrawberrySkillPillarRenderer.new()
	var skill_context: Dictionary = _build_skill_context(renderer, 450.0)
	var center := Vector2(100.0, 600.0)
	var orb_radius := 55.0
	var positions: Array = renderer.get_slot_positions(center, orb_radius, 1.0, skill_context)
	var hovered: Dictionary = renderer.find_hovered_skill(positions[2], center, orb_radius, 1.0, skill_context)
	_expect(str(hovered.get("name", "")) == "horn_strawberry_eat", "horn strawberry hover hit-test should return the transformed skill data")
	_expect(str(hovered.get("korean", "")) == "딸기먹기", "horn strawberry tooltip data should expose Korean skill names")
	_expect(str(hovered.get("how_to_use", "")).find("Space") >= 0, "eat tooltip should mention Space input")

	var tooltip_renderer := SmasherSkillOrbTooltipRenderer.new()
	var bomb_rows: Array = tooltip_renderer._get_control_rows("horn_strawberry_bomb", "smasher")
	_expect(not bomb_rows.is_empty(), "horn strawberry bomb tooltip should use a keycap control row")
	_expect(str(bomb_rows[0][0][1]) == "A", "bomb tooltip should start with A keycap")
	_expect(str(bomb_rows[0][2][1]) == "D", "bomb tooltip should include D keycap")


func _verify_orb_key_label_layout() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_symbol_renderer.gd")
	_expect(source.find("const KEY_LABEL_SINGLE_Y_OFFSET := 0.32") >= 0, "single-key orb labels should use the raised in-orb y offset")
	_expect(source.find("const KEY_LABEL_COMBO_Y_OFFSET := 0.36") >= 0, "combo orb labels should use the raised in-orb y offset")
	_expect(source.find("icon_radius * 0.46") < 0, "orb key labels should not use the old lower y offset that can overflow")


func _verify_commando_panel_hidden_while_transformed() -> void:
	var pillar_renderer := Stage1PillarUiRenderer.new()
	var selector := FakeSelectorRenderer.new()
	var horn_renderer := HornStrawberrySkillPillarRenderer.new()
	var panel_state: Dictionary = pillar_renderer.build_commando_firearm_panel_state(
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		{
			"height": 750.0,
			"selected_character_type": "soldier",
			"commando_firearm_selector_renderer": selector,
			"horn_strawberry_skill_pillar_renderer": horn_renderer,
			"horn_strawberry_context": _build_horn_context(),
			"skill_config_snapshot": {
				"max_slots": 5,
				"equipped_skills": [],
			},
		}
	)
	_expect(panel_state.is_empty(), "commando firearm panel should be hidden while horn strawberry transformed HUD is active")
	_expect(selector.build_count == 0, "hidden commando panel should not build selector state")


func _build_skill_context(renderer: Object, special_gauge: float) -> Dictionary:
	var layout := Stage1PillarUiLayout.new()
	var base_context: Dictionary = layout.build_skill_orb_context({
		"selected_character_type": "smasher",
		"skill_config_snapshot": {
			"max_slots": 5,
			"equipped_skills": [],
		},
	}, null)
	return renderer.build_skill_orb_context(_build_horn_context(), special_gauge, null, base_context)


func _build_horn_context() -> Dictionary:
	return {
		"transformed": true,
		"horn_charge": {
			"active": false,
			"cooldown_sec": 10.0,
			"cooldown_max_sec": 20.0,
			"phase_timer_sec": 0.0,
			"phase_duration_sec": 0.43,
		},
		"field": {
			"holding": true,
			"hold_timer_sec": 0.5,
			"hold_min_sec": 1.0,
			"cooldown_sec": 0.0,
			"cooldown_max_sec": 10.0,
			"barrier_count": 0,
		},
		"eat": {
			"eating": false,
			"eat_timer_sec": 0.0,
			"eat_duration_sec": 0.8,
			"cooldown_sec": 0.0,
			"cooldown_max_sec": 0.8,
		},
		"bomb": {
			"holding": false,
			"hold_timer_sec": 0.0,
			"hold_sec": 0.5,
			"throwing": false,
			"throw_timer_sec": 0.0,
			"throw_duration_sec": 1.0,
			"cooldown_sec": 0.0,
			"cooldown_max_sec": 30.0,
		},
	}


func _color_matches(value: Variant, expected: Color) -> bool:
	if not (value is Color):
		return false
	var color: Color = value
	return (
		abs(color.r - expected.r) < 0.005
		and abs(color.g - expected.g) < 0.005
		and abs(color.b - expected.b) < 0.005
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
