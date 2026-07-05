extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const Stage1DaljiBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage4PonkBossSkillHudRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd")
const Stage5HongryunBossSkillHudRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")
const Stage6TetriserBossSkillHudRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_official_dalji_spec()
	_verify_commando_panel_avoidance_contract()
	_verify_stage_renderers_share_spec()
	_verify_stage_renderers_use_commando_avoidance()
	_verify_stage6_layout_avoids_commando_panel()
	_verify_stage_renderers_have_hover_tooltips()
	_verify_stage_renderers_sort_by_next_activation()
	_verify_stage1_layout_uses_spec()
	_verify_stage1_layout_sorts_by_next_activation()
	_verify_common_next_activation_sort()
	_verify_stage5_layout_and_inferno_contract()
	_verify_japanese_status_labels()
	_verify_spanish_status_labels()
	_verify_portuguese_brazil_status_labels()
	_verify_russian_status_labels()

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


func _verify_commando_panel_avoidance_contract() -> void:
	var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(260.0)
	var card_size: Vector2 = _get_vector2(metrics.get("card_size", Vector2.ZERO))
	var card_gap: float = float(metrics.get("card_gap", 0.0))
	var margin_x: float = float(metrics.get("margin_x", 0.0))
	var margin_y: float = float(metrics.get("margin_y", 0.0))
	var scale_factor: float = float(metrics.get("scale_factor", 1.0))
	var total_h: float = 3.0 * (card_size.y + card_gap) - card_gap
	var card_x: float = 260.0 - card_size.x - margin_x
	var game_offset := Vector2(260.0, 25.0)
	var centered_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		750.0,
		total_h,
		margin_y,
		card_x,
		card_size.x,
		scale_factor
	)
	var panel_rect := Rect2(Vector2(card_x + 8.0, centered_y + total_h - 6.0), Vector2(card_size.x, 110.0))
	var shifted_y: float = BossSkillCardHudSpec.resolve_stack_start_y(
		game_offset,
		750.0,
		total_h,
		margin_y,
		card_x,
		card_size.x,
		scale_factor,
		panel_rect
	)
	var required_gap: float = BossSkillCardHudSpec.get_commando_firearm_panel_gap(scale_factor)
	_expect(shifted_y + total_h <= panel_rect.position.y - required_gap + 0.01, "boss skillcard shared layout should clear the Commando firearm panel")
	_expect(shifted_y < centered_y, "boss skillcard shared layout should move upward when the firearm panel overlaps its lane")


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


func _verify_stage_renderers_use_commando_avoidance() -> void:
	var renderer_paths := [
		"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd",
	]
	for path in renderer_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("commando_firearm_panel_rect") >= 0, "%s should read the Commando firearm panel rect" % path)
		_expect(source.find("BossSkillCardHudSpec.resolve_stack_start_y") >= 0, "%s should use the shared avoidant stack layout" % path)
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
	_expect(scene_drawer_source.find("build_commando_firearm_panel_state_for_boss_hud") >= 0, "Stage 1 pillar HUD scene drawer should expose the firearm panel rect builder")
	_expect(scene_drawer_source.find("context[\"commando_firearm_panel_rect\"]") >= 0, "post-active HUD pass should seed the firearm panel rect into the draw context")


func _verify_stage6_layout_avoids_commando_panel() -> void:
	# Stage 6 Tetriser (4 boss skills + hatched lingpet = 5 cards) is the stage most
	# likely to overlap the Commando firearm HUD. Prove its rail actually shifts the
	# stack up above the firearm panel, not just that the source mentions the key.
	var renderer := Stage6TetriserBossSkillHudRenderer.new()
	var context := {
		"current_stage": 6,
		"stage6_boss_skill_hud_active": true,
		"view_size": Vector2(2048.0, 1152.0),
		"game_offset": Vector2(512.0, 64.0),
		"game_size": Vector2(1024.0, 1024.0),
		"stage6_boss_skill_hud_skills": [
			{"id": "stage6_tetro_drop", "progress": 0.10},
			{"id": "stage6_guard", "progress": 0.30},
			{"id": "stage6_wall", "progress": 0.55},
			{"id": "stage6_super", "progress": 0.75},
			{"id": "lingpet_skill", "progress": 0.90},
		],
	}
	var default_layout: Dictionary = renderer.build_card_layout(context)
	var default_top: float = _stack_top(default_layout)
	var default_bottom: float = _stack_bottom(default_layout)
	# Anchor an overlapping firearm panel just below the centered stack so the
	# default (no-avoid) layout demonstrably collides — this is the reported bug.
	var panel_rect := Rect2(Vector2(_stack_left(default_layout) + 6.0, default_bottom - 12.0), Vector2(60.0, 140.0))
	_expect(default_bottom > panel_rect.position.y, "default Stage 6 Tetriser cards should reproduce the Commando overlap risk")

	context["commando_firearm_panel_rect"] = panel_rect
	var shifted_layout: Dictionary = renderer.build_card_layout(context)
	var shifted_bottom: float = _stack_bottom(shifted_layout)
	var shifted_top: float = _stack_top(shifted_layout)
	var scale_factor: float = float(shifted_layout.get("scale_factor", 1.0))
	var required_gap: float = BossSkillCardHudSpec.get_commando_firearm_panel_gap(scale_factor)
	_expect(shifted_bottom <= panel_rect.position.y - required_gap + 0.01, "Commando-safe Stage 6 cards should sit above the firearm panel")
	_expect(shifted_top < default_top, "Commando-safe Stage 6 card stack should move upward instead of staying centered")

	context["commando_firearm_panel_rect"] = Rect2(Vector2(12.0, panel_rect.position.y), panel_rect.size)
	var far_layout: Dictionary = renderer.build_card_layout(context)
	_expect(is_equal_approx(_stack_top(far_layout), default_top), "unrelated left-edge panels should not move the Stage 6 card stack")


func _stack_top(layout: Dictionary) -> float:
	var rects: Array = layout.get("rects", [])
	if rects.is_empty():
		return 0.0
	return _get_rect(rects[0]).position.y


func _stack_bottom(layout: Dictionary) -> float:
	var rects: Array = layout.get("rects", [])
	if rects.is_empty():
		return 0.0
	return _get_rect(rects[rects.size() - 1]).end.y


func _stack_left(layout: Dictionary) -> float:
	var rects: Array = layout.get("rects", [])
	if rects.is_empty():
		return 0.0
	return _get_rect(rects[0]).position.x


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _verify_stage_renderers_have_hover_tooltips() -> void:
	var common_source := FileAccess.get_file_as_string("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
	_expect(common_source.find("draw_skill_tooltip") >= 0, "boss skillcard shared spec should expose tooltip drawing")
	var renderer_paths := [
		"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
	]
	for path in renderer_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("get_mouse_position") >= 0, "%s should read the mouse position for skillcard hover" % path)
		_expect(source.find("draw_skill_tooltip") >= 0, "%s should draw a skillcard tooltip on hover" % path)
		_expect(source.find("_get_tooltip_info") >= 0, "%s should provide localized skillcard tooltip copy" % path)
	var stage5_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
	var stage5_pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd")
	var stage5_legacy_pillar_source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_pillar_scene_drawer.gd")
	_expect(stage5_source.find("\"hongryun_fire_machine\"") < 0, "Stage 5 fire machine should not be a Hongryun boss skill card")
	_expect(stage5_pillar_source.find("_append_fire_machine_hud_skill") < 0, "Stage 5 Hongryun pillar drawer should not append the fire machine to boss skill cards")
	_expect(stage5_legacy_pillar_source.find("_append_fire_machine_hud_skill") < 0, "Stage 5 legacy pillar drawer should not append the fire machine to boss skill cards")


func _verify_stage_renderers_sort_by_next_activation() -> void:
	var renderer_paths := [
		"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
		"res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
	]
	for path in renderer_paths:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("compare_skill_entries_by_next_activation") >= 0, "%s should sort the rail by next scheduled activation" % path)


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


func _verify_stage1_layout_sorts_by_next_activation() -> void:
	var renderer := Stage1DaljiBossSkillHudRenderer.new()
	var context := {
		"current_stage": 1,
		"stage1_dalji_boss_skill_hud_active": true,
		"view_size": Vector2(1280.0, 800.0),
		"game_offset": Vector2(260.0, 25.0),
		"game_size": Vector2(760.0, 750.0),
		"stage1_dalji_boss_skill_hud_skills": [
			{"id": "later", "status": "charging", "sort_remaining": 6.0, "progress": 0.90},
			{"id": "locked", "status": "locked", "sort_remaining": 0.1, "progress": 0.99},
			{"id": "soon", "status": "charging", "sort_remaining": 1.0, "progress": 0.10},
		],
	}
	var layout: Dictionary = renderer.build_card_layout(context)
	var entries: Array = layout.get("entries", [])
	_expect(entries.size() == 3, "Stage 1 Dalji layout should keep all sortable skill entries")
	_expect(_entry_ids(entries) == ["soon", "later", "locked"], "Stage 1 Dalji layout should put the next scheduled skill at the top")


func _verify_common_next_activation_sort() -> void:
	var entries := [
		{"id": "locked", "status": "locked", "cooldown_remaining": 0.1, "cooldown_total": 10.0, "progress": 0.99},
		{"id": "later", "status": "charging", "cooldown_remaining": 8.0, "cooldown_total": 10.0, "progress": 0.20},
		{"id": "casting", "status": "casting", "cooldown_remaining": 40.0, "cooldown_total": 40.0, "progress": 1.0},
		{"id": "soon", "status": "charging", "cooldown_remaining": 2.0, "cooldown_total": 40.0, "progress": 0.95},
		{"id": "ready", "status": "ready", "ready": true, "cooldown_remaining": 0.0, "cooldown_total": 25.0, "progress": 1.0},
	]
	entries.sort_custom(Callable(self, "_sort_by_next_activation"))
	_expect(_entry_ids(entries) == ["casting", "ready", "soon", "later", "locked"], "shared boss skillcard sort should use next activation time, with locked/used last")


func _verify_stage5_layout_and_inferno_contract() -> void:
	var state := Stage5HongryunState.new()
	state.debug_set_dragon_orb_count(4)
	var context: Dictionary = state.get_hud_context()
	var skills: Array = context.get("stage5_boss_skill_hud_skills", [])
	_expect(skills.size() == 2, "Stage 5 Hongryun HUD context should ship only the two Hongryun boss skill cards")
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


func _verify_japanese_status_labels() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(BossSkillCardHudSpec._format_cooldown_label(3.0) == "クールタイム3秒", "boss skillcard cooldown labels should localize to Japanese")
	_expect(BossSkillCardHudSpec._format_seconds(3.5) == "3.5秒", "boss skillcard seconds should localize to Japanese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_spanish_status_labels() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(BossSkillCardHudSpec._format_cooldown_label(3.0) == "Recarga 3s", "boss skillcard cooldown labels should localize to Spanish")
	_expect(BossSkillCardHudSpec._format_seconds(3.5) == "3.5s", "boss skillcard seconds should localize to Spanish")
	_expect(BossSkillCardHudSpec._get_tooltip_status_text({"progress": 0.42}, {}) == "Carga 42%", "boss skillcard charge text should localize to Spanish")
	_expect(Stage1DaljiBossSkillHudRenderer.new()._get_tooltip_status_text({"progress": 0.5}) == "Carga 50%", "Stage 1 boss skillcard charge text should localize to Spanish")
	_expect(Stage5HongryunBossSkillHudRenderer.new()._get_tooltip_status_text({"progress": 0.5}) == "Carga 50%", "Stage 5 boss skillcard charge text should localize to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_portuguese_brazil_status_labels() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	_expect(BossSkillCardHudSpec._format_cooldown_label(3.0) == "Recarga 3s", "boss skillcard cooldown labels should localize to Brazilian Portuguese")
	_expect(BossSkillCardHudSpec._format_seconds(3.5) == "3.5s", "boss skillcard seconds should localize to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_russian_status_labels() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	_expect(BossSkillCardHudSpec._format_cooldown_label(3.0) == "Перезарядка 3с", "boss skillcard cooldown labels should localize to Russian")
	_expect(BossSkillCardHudSpec._format_seconds(3.5) == "3.5с", "boss skillcard seconds should localize to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


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


func _entry_ids(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		if entry is Dictionary:
			ids.append(str((entry as Dictionary).get("id", "")))
	return ids


func _sort_by_next_activation(a: Dictionary, b: Dictionary) -> bool:
	return BossSkillCardHudSpec.compare_skill_entries_by_next_activation(a, b)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
