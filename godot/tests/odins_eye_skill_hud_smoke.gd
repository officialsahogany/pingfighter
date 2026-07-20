extends SceneTree

const OdinsEyeSkillPillarRenderer := preload("res://scripts/hud/odins_eye_skill_pillar_renderer.gd")
const SmasherSkillOrbSlotRenderer := preload("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const GameplayHudModuleCatalog := preload("res://scripts/resources/gameplay_hud_module_catalog.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")

const SKILL_DARK_SWAMP := "odins_eye_dark_swamp"

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
	_verify_visibility_and_layout_contract()
	_verify_ready_state_matrix()
	_verify_tooltip_metadata_and_hover()
	_verify_catalog_registration()
	_verify_pillar_swap_predicate()
	_verify_commando_panel_hidden_while_transformed()
	_verify_tooltip_pipeline_ownership_while_transformed()

	if _failures.is_empty():
		print("odins_eye_skill_hud_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_visibility_and_layout_contract() -> void:
	var renderer := OdinsEyeSkillPillarRenderer.new()
	_expect(not renderer.is_active({"transformed": false}), "normal character form should keep the regular skill HUD")
	_expect(renderer.is_active({"transformed": true}), "Odin transformed form should activate its skill HUD")

	var skill_context: Dictionary = _build_skill_context(renderer, _build_odin_context(), 100.0)
	var skill_order: Array = skill_context.get("equipped_skills", [])
	_expect(int(skill_context.get("max_slots", 0)) == 1, "Odin transformed HUD should expose exactly one skill slot")
	_expect(skill_order.size() == 1 and str(skill_order[0]) == SKILL_DARK_SWAMP, "the transformed slot should contain Dark Swamp")
	var costs: Dictionary = skill_context.get("skill_costs", {})
	var cooldowns: Dictionary = skill_context.get("cooldown_seconds", {})
	_expect(is_equal_approx(float(costs.get(SKILL_DARK_SWAMP, 0.0)), 100.0), "Dark Swamp HUD cost should be 100")
	_expect(is_equal_approx(float(cooldowns.get(SKILL_DARK_SWAMP, 0.0)), 2.0), "Dark Swamp HUD cooldown should be 2.0 seconds")

	var positions: Array[Vector2] = renderer.get_slot_positions(Vector2(120.0, 600.0), 55.0, 1.0, skill_context)
	_expect(positions.size() == 1, "one-slot Odin HUD should produce one orb position")
	if not positions.is_empty():
		_expect(positions[0].x < 120.0 and is_equal_approx(positions[0].y, 600.0), "Dark Swamp orb should sit directly left of the gauge")


func _verify_ready_state_matrix() -> void:
	var renderer := OdinsEyeSkillPillarRenderer.new()
	var ready_context: Dictionary = _build_skill_context(renderer, _build_odin_context(), 100.0)
	_expect(_is_ready(ready_context), "enabled transformed Dark Swamp should be ready at 100 gauge")

	var low_gauge_context: Dictionary = _build_skill_context(renderer, _build_odin_context(), 99.0)
	_expect(not _is_ready(low_gauge_context), "Dark Swamp should be disabled below 100 gauge")

	var disabled_odin: Dictionary = _build_odin_context()
	var disabled_swamp: Dictionary = disabled_odin["dark_swamp"]
	disabled_swamp["enabled"] = false
	_expect(not _is_ready(_build_skill_context(renderer, disabled_odin, 100.0)), "Dark Swamp should not be ready before revival finalize enables it")

	var revival_odin: Dictionary = _build_odin_context()
	revival_odin["revival_animation_active"] = true
	_expect(not _is_ready(_build_skill_context(renderer, revival_odin, 100.0)), "Dark Swamp should stay disabled during the revival cinematic")

	var death_odin: Dictionary = _build_odin_context()
	death_odin["death_animation_active"] = true
	_expect(not _is_ready(_build_skill_context(renderer, death_odin, 100.0)), "Dark Swamp should stay disabled during the death cinematic")

	var active_odin: Dictionary = _build_odin_context()
	var active_swamp: Dictionary = active_odin["dark_swamp"]
	active_swamp["active"] = true
	var active_context: Dictionary = _build_skill_context(renderer, active_odin, 100.0)
	_expect(not _is_ready(active_context), "Dark Swamp should not be ready while its spike wave is active")
	var active_overrides: Dictionary = active_context.get("skill_active_overrides", {})
	_expect(bool(active_overrides.get(SKILL_DARK_SWAMP, false)), "active spike wave state should be exposed to the HUD ring")

	var cooldown_odin: Dictionary = _build_odin_context()
	var cooldown_swamp: Dictionary = cooldown_odin["dark_swamp"]
	cooldown_swamp["cooldown_remaining_frames"] = 60.0
	cooldown_swamp["cooldown_ratio"] = 0.5
	var cooldown_context: Dictionary = _build_skill_context(renderer, cooldown_odin, 100.0)
	_expect(not _is_ready(cooldown_context), "Dark Swamp should not be ready during cooldown")
	var ratios: Dictionary = cooldown_context.get("skill_cooldown_remaining_ratios", {})
	_expect(is_equal_approx(float(ratios.get(SKILL_DARK_SWAMP, 0.0)), 0.5), "HUD cooldown wedge should use the runtime ratio")

	var slot_renderer := SmasherSkillOrbSlotRenderer.new()
	_expect(
		is_equal_approx(slot_renderer._get_cooldown_remaining(null, SKILL_DARK_SWAMP, 0, {}, cooldown_context), 0.5),
		"shared slot renderer should honor Odin's cooldown ratio override"
	)
	_expect(
		not slot_renderer._is_activation_condition_met(SKILL_DARK_SWAMP, cooldown_context),
		"shared slot renderer should honor Odin's not-ready override"
	)


func _verify_tooltip_metadata_and_hover() -> void:
	var renderer := OdinsEyeSkillPillarRenderer.new()
	var skill_context: Dictionary = _build_skill_context(renderer, _build_odin_context(), 100.0)
	var center := Vector2(120.0, 600.0)
	var positions: Array[Vector2] = renderer.get_slot_positions(center, 55.0, 1.0, skill_context)
	if positions.is_empty():
		_expect(false, "Dark Swamp hover smoke requires an orb position")
		return
	var hovered: Dictionary = renderer.find_hovered_skill(positions[0], center, 55.0, 1.0, skill_context)
	_expect(str(hovered.get("name", "")) == SKILL_DARK_SWAMP, "hover hit-test should return Dark Swamp metadata")
	_expect(str(hovered.get("korean", "")) == "어둠의 늪", "tooltip should expose the Korean skill name")
	_expect(str(hovered.get("how_to_use", "")).find("좌클릭") >= 0, "tooltip should explain the left-click input")
	_expect(str(hovered.get("effect_type", "")) == "odins_eye_dark_swamp", "tooltip should route to the Odin Dark Swamp effect preview")
	var preview_metadata: Dictionary = hovered.get("preview_metadata", {})
	_expect(str(preview_metadata.get("scene", "")) == "player_to_boss_spike_wave", "preview metadata should identify the player-to-boss spike wave")
	_expect(int(preview_metadata.get("spike_count", 0)) == 12, "preview metadata should preserve the twelve-spike identity")
	var boss_effects: Array = preview_metadata.get("boss_effects", [])
	_expect(boss_effects.has("knockback") and boss_effects.has("stun"), "preview metadata should describe the boss knockback and stun")


func _build_skill_context(renderer: Object, odins_eye_context: Dictionary, special_gauge: float) -> Dictionary:
	var layout := Stage1PillarUiLayout.new()
	var base_context: Dictionary = layout.build_skill_orb_context({
		"selected_character_type": "smasher",
		"skill_config_snapshot": {
			"max_slots": 5,
			"equipped_skills": [],
		},
	}, null)
	return renderer.build_skill_orb_context(odins_eye_context, special_gauge, null, base_context)


# 툴팁 파이프라인 소유권 씰(2026-07-21 2차 리포트): 실제 보이는 툴팁은
# smasher_skill_orb_tooltip_renderer 내부 hover 파이프라인이다. 변신 중
# 이 파이프라인에 오딘 분기가 없으면 그려지지 않는 일반 클러스터 위치로
# hover가 해석돼 "드라이브" 유령 툴팁이 뜬다.
func _verify_tooltip_pipeline_ownership_while_transformed() -> void:
	var tooltip_renderer := SmasherSkillOrbTooltipRenderer.new()
	var odins_renderer := OdinsEyeSkillPillarRenderer.new()
	var odin_context: Dictionary = _build_odin_context()
	var skill_context: Dictionary = _build_skill_context(odins_renderer, odin_context, 100.0)
	var left_center := Vector2(120.0, 600.0)
	var positions: Array[Vector2] = odins_renderer.get_slot_positions(left_center, 55.0, 1.0, skill_context)
	_expect(not positions.is_empty(), "tooltip pipeline seal needs the Odin orb position")
	if positions.is_empty():
		return
	var hover_context := {
		"odins_eye_active": true,
		"odins_eye_context": odin_context,
		"odins_eye_skill_pillar_renderer": odins_renderer,
		"skill_context": skill_context,
		"mouse_pos": positions[0],
		"left_center": left_center,
		"orb_radius": 55.0,
		"scale_factor": 1.0,
		"selected_character_type": "smasher",
		# 유령 툴팁 판별자: 일반 스매셔 클러스터 데이터가 남아 있어도 변신
		# 중에는 절대 해석되면 안 된다.
		"skill_config_snapshot": {
			"equipped_skills": ["drive"],
			"skill_data": {"drive": {"name": "drive", "korean": "드라이브"}},
		},
	}
	var hovered: Dictionary = tooltip_renderer._find_hovered_skill(hover_context)
	_expect(
		str(hovered.get("name", "")) == SKILL_DARK_SWAMP,
		"hovering the Odin orb while transformed should resolve the Dark Swamp tooltip (got '%s')" % str(hovered.get("name", ""))
	)
	var miss_context: Dictionary = hover_context.duplicate(true)
	miss_context["mouse_pos"] = Vector2(-500.0, -500.0)
	miss_context["odins_eye_skill_pillar_renderer"] = odins_renderer
	var missed: Dictionary = tooltip_renderer._find_hovered_skill(miss_context)
	_expect(
		missed.is_empty(),
		"missing the Odin orb while transformed must not fall through to the normal cluster (ghost Drive tooltip)"
	)
	var by_name: Dictionary = tooltip_renderer._find_skill_by_name(hover_context, SKILL_DARK_SWAMP)
	_expect(
		str(by_name.get("name", "")) == SKILL_DARK_SWAMP and by_name.has("slot_rect"),
		"gamepad-selected lookup should resolve Dark Swamp data with a slot rect while transformed"
	)
	var firearm_context: Dictionary = hover_context.duplicate(true)
	firearm_context["selected_character_type"] = "soldier"
	_expect(
		tooltip_renderer._find_hovered_commando_firearm(firearm_context).is_empty(),
		"commando firearm hover must stay suppressed while the Odin HUD is active"
	)


# 라이브 배선 씰(2026-07-21 회귀 복원): 렌더러 모듈이 GREEN이어도 HUD 모듈
# 카탈로그 미등록이면 scene drawer의 _get_cached_module이 null을 돌려 오브가
# 라이브에서 영구 부재였다("변신했는데 스킬도 안 씀" 증상의 HUD 절반).
func _verify_catalog_registration() -> void:
	var catalog := GameplayHudModuleCatalog.new()
	var spec: Dictionary = catalog.get_spec("odins_eye_skill_pillar_renderer")
	_expect(not spec.is_empty(), "Odin's Eye skill HUD renderer should be registered in the HUD module catalog")
	_expect(
		str(spec.get("path", "")) == "res://scripts/hud/odins_eye_skill_pillar_renderer.gd",
		"Odin HUD catalog path should point at the pillar renderer"
	)


func _verify_pillar_swap_predicate() -> void:
	var pillar_renderer := Stage1PillarUiRenderer.new()
	var odins_renderer := OdinsEyeSkillPillarRenderer.new()
	_expect(
		pillar_renderer._is_odins_eye_skill_hud_active(odins_renderer, _build_odin_context()),
		"pillar UI should swap to the Odin orb renderer while transformed"
	)
	_expect(
		not pillar_renderer._is_odins_eye_skill_hud_active(odins_renderer, {"transformed": false}),
		"pillar UI should keep the normal orb renderer when Odin is not transformed"
	)
	_expect(
		not pillar_renderer._is_odins_eye_skill_hud_active(null, _build_odin_context()),
		"missing Odin renderer module should fail closed to the normal orb renderer"
	)


func _verify_commando_panel_hidden_while_transformed() -> void:
	var pillar_renderer := Stage1PillarUiRenderer.new()
	var selector := FakeSelectorRenderer.new()
	var odins_renderer := OdinsEyeSkillPillarRenderer.new()
	var panel_state: Dictionary = pillar_renderer.build_commando_firearm_panel_state(
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		{
			"height": 750.0,
			"selected_character_type": "soldier",
			"commando_firearm_selector_renderer": selector,
			"odins_eye_skill_pillar_renderer": odins_renderer,
			"odins_eye_context": _build_odin_context(),
			"skill_config_snapshot": {
				"max_slots": 5,
				"equipped_skills": [],
			},
		}
	)
	_expect(panel_state.is_empty(), "commando firearm panel should be hidden while the Odin transformed HUD is active")
	_expect(selector.build_count == 0, "hidden commando panel should not build selector state while Odin HUD is active")


func _build_odin_context() -> Dictionary:
	return {
		"transformed": true,
		"revival_animation_active": false,
		"death_animation_active": false,
		"dark_swamp": {
			"enabled": true,
			"active": false,
			"cooldown_remaining_frames": 0.0,
			"cooldown_ratio": 0.0,
			"gauge_cost": 100.0,
			"spikes": [],
		},
	}


func _is_ready(skill_context: Dictionary) -> bool:
	var ready: Dictionary = skill_context.get("skill_ready_overrides", {})
	return bool(ready.get(SKILL_DARK_SWAMP, false))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
