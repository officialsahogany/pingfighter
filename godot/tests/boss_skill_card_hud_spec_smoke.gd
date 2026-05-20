extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const Stage1DaljiBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage4PonkBossSkillHudRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd")
const Stage5HongryunBossSkillHudRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_official_dalji_spec()
	_verify_stage_renderers_share_spec()
	_verify_stage1_layout_uses_spec()
	_verify_stage5_layout_and_inferno_contract()

	if _failures.is_empty():
		print("boss_skill_card_hud_spec_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_official_dalji_spec() -> void:
	_expect(is_equal_approx(BossSkillCardHudSpec.BASE_PILLAR_WIDTH, 80.0), "boss skillcard spec should keep the Dalji base pillar width")
	_expect(is_equal_approx(BossSkillCardHudSpec.CARD_WIDTH_BASE, 33.6), "boss skillcard spec should keep Dalji card width base")
	_expect(is_equal_approx(BossSkillCardHudSpec.CARD_HEIGHT_BASE, 9.0), "boss skillcard spec should keep Dalji card height base")
	_expect(BossSkillCardHudSpec.CARD_MIN_SIZE == Vector2(24.0, 10.0), "boss skillcard spec should keep Dalji minimum card size")
	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(80.0)
	_expect(_vector2_equal(_get_vector2(metrics.get("card_size", Vector2.ZERO)), Vector2(34.0, 10.0)), "official base pillar card rect should resolve to 34x10 after rounding and min clamp")


func _verify_stage_renderers_share_spec() -> void:
	var expected: Dictionary = BossSkillCardHudSpec.get_card_metrics(260.0)
	var renderers := [
		Stage1DaljiBossSkillHudRenderer.new(),
		Stage2BossSkillHudRenderer.new(),
		Stage3BossSkillHudRenderer.new(),
		Stage4PonkBossSkillHudRenderer.new(),
		Stage5HongryunBossSkillHudRenderer.new(),
	]
	for renderer in renderers:
		_expect(renderer.has_method("get_debug_card_metrics"), "boss skillcard renderer should expose debug card metrics")
		var metrics: Dictionary = renderer.get_debug_card_metrics(260.0)
		_expect(_metrics_equal(metrics, expected), "boss skillcard renderer should use the shared Dalji card metrics")


func _verify_stage1_layout_uses_spec() -> void:
	var renderer := Stage1DaljiBossSkillHudRenderer.new()
	var context := {
		"current_stage": 1,
		"stage1_dalji_boss_skill_hud_active": true,
		"view_size": Vector2(1280.0, 800.0),
		"game_offset": Vector2(260.0, 25.0),
		"game_size": Vector2(760.0, 750.0),
		"stage1_dalji_boss_skill_hud_skills": [
			{"id": "whip", "progress": 0.10},
			{"id": "spinning_top", "progress": 0.35},
		],
	}
	var layout: Dictionary = renderer.build_card_layout(context)
	var rects: Array = layout.get("rects", [])
	_expect(rects.size() == 2, "Stage 1 Dalji layout should build two card rects")
	if rects.size() < 1:
		return
	var expected_size: Vector2 = _get_vector2(BossSkillCardHudSpec.get_card_metrics(260.0).get("card_size", Vector2.ZERO))
	var first_rect: Rect2 = rects[0]
	_expect(_vector2_equal(first_rect.size, expected_size), "Stage 1 Dalji layout rect should use the shared official card size")


func _verify_stage5_layout_and_inferno_contract() -> void:
	var state := Stage5HongryunState.new()
	state.debug_set_dragon_orb_count(4)
	var context: Dictionary = state.get_hud_context()
	var skills: Array = context.get("stage5_boss_skill_hud_skills", [])
	_expect(skills.size() == 2, "Stage 5 Hongryun HUD context should ship two cards before fire-machine")
	var inferno: Dictionary = _find_skill(skills, "hongryun_inferno")
	_expect(str(inferno.get("render_kind", "")) == "dragon_orb_gauge", "Stage 5 inferno card should expose the dragon-orb render kind")
	_expect(str(inferno.get("status", "")) == "charging", "Stage 5 inferno card should charge before 5 dragon orbs")

	state.debug_force_inferno_ready()
	state.register_boss_paddle_contact(Vector2(20.0, -30.0), {})
	context = state.get_hud_context()
	skills = context.get("stage5_boss_skill_hud_skills", [])
	inferno = _find_skill(skills, "hongryun_inferno")
	_expect(str(inferno.get("status", "")) == "inferno_charge", "Stage 5 inferno charge phase should expose its own HUD status")
	_expect(is_equal_approx(float(inferno.get("inferno_charge_progress", 0.0)), 1.0), "Stage 5 inferno charge should begin with a full wedge progress")
	_expect(state.should_skip_ball_motion_step(), "Stage 5 inferno charge should request the ball motion hijack")

	var renderer := Stage5HongryunBossSkillHudRenderer.new()
	renderer.prewarm_assets()
	var asset_status: Dictionary = renderer.get_asset_status()
	_expect(bool(asset_status.get("orb_fill_sheet_texture", false)), "Stage 5 inferno card should load the AutoSprite orb fill sheet")
	var layout_context := context.duplicate(true)
	layout_context["current_stage"] = 5
	layout_context["view_size"] = Vector2(1280.0, 800.0)
	layout_context["game_offset"] = Vector2(260.0, 25.0)
	layout_context["game_size"] = Vector2(760.0, 750.0)
	var layout: Dictionary = renderer.build_card_layout(layout_context)
	var rects: Array = layout.get("rects", [])
	_expect(rects.size() == 2, "Stage 5 Hongryun renderer should build two card rects from state context")
	if rects.size() > 0:
		var expected_size: Vector2 = _get_vector2(BossSkillCardHudSpec.get_card_metrics(260.0).get("card_size", Vector2.ZERO))
		var first_rect: Rect2 = rects[0]
		_expect(_vector2_equal(first_rect.size, expected_size), "Stage 5 Hongryun layout rect should use the shared official card size")


func _metrics_equal(left: Dictionary, right: Dictionary) -> bool:
	return (
		is_equal_approx(float(left.get("scale_factor", 0.0)), float(right.get("scale_factor", 0.0)))
		and _vector2_equal(_get_vector2(left.get("card_size", Vector2.ZERO)), _get_vector2(right.get("card_size", Vector2.ZERO)))
		and is_equal_approx(float(left.get("card_gap", 0.0)), float(right.get("card_gap", 0.0)))
		and is_equal_approx(float(left.get("margin_x", 0.0)), float(right.get("margin_x", 0.0)))
		and is_equal_approx(float(left.get("margin_y", 0.0)), float(right.get("margin_y", 0.0)))
	)


func _vector2_equal(left: Vector2, right: Vector2) -> bool:
	return is_equal_approx(left.x, right.x) and is_equal_approx(left.y, right.y)


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _find_skill(skills: Array, skill_id: String) -> Dictionary:
	for value in skills:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
