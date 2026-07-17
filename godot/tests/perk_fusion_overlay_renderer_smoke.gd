extends SceneTree

const PerkFusionModalLayout := preload("res://scripts/characters/perk_fusion_modal_layout.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_layout_bounds_and_hit_testing()
	_verify_paged_layout_keeps_highlight_visible()
	_verify_renderer_contract()

	if _failures.is_empty():
		print("perk_fusion_overlay_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_layout_bounds_and_hit_testing() -> void:
	var helper := PerkFusionModalLayout.new()
	var snapshot := {
		"phase": "materials",
		"candidate_ids": ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"],
		"highlight_index": 2,
	}
	for view_size in [Vector2(760.0, 750.0), Vector2(420.0, 560.0), Vector2(300.0, 420.0)]:
		var layout: Dictionary = helper.build_layout(snapshot, view_size)
		var panel_rect: Rect2 = _rect(layout.get("panel_rect", Rect2()))
		_expect(_rect_inside(panel_rect, Rect2(Vector2.ZERO, view_size)), "panel should remain within the requested view")
		_expect(_rect_inside(_rect(layout.get("back_rect", Rect2())), panel_rect), "back button should remain inside the panel")
		_expect(_rect_inside(_rect(layout.get("confirm_rect", Rect2())), panel_rect), "confirm button should remain inside the panel")
		var rects: Array = _array(layout.get("candidate_rects", []))
		_expect(rects.size() == 6, "layout should preserve one rect slot per candidate")
		for index_value in _array(layout.get("visible_candidate_indices", [])):
			var index: int = int(index_value)
			var candidate_rect: Rect2 = _rect(rects[index])
			_expect(candidate_rect.size.x > 0.0 and candidate_rect.size.y > 0.0, "visible candidate rect should have positive size")
			_expect(_rect_inside(candidate_rect, panel_rect), "visible candidate rect should remain inside the panel")
			_expect(helper.get_candidate_index_at(snapshot, candidate_rect.get_center(), view_size) == index, "candidate center should hit its source index")
			_expect(helper.hit_test_candidate(snapshot, candidate_rect.get_center(), view_size) == index, "candidate hit-test alias should preserve the source index")
		_expect(helper.get_candidate_index_at(snapshot, Vector2(-10.0, -10.0), view_size) == -1, "outside point should miss every candidate")
		_expect(helper.get_action_at(snapshot, _rect(layout.get("back_rect", Rect2())).get_center(), view_size) == "back", "back button center should resolve the back action")
		_expect(helper.get_action_at(snapshot, _rect(layout.get("confirm_rect", Rect2())).get_center(), view_size) == "confirm", "confirm button center should resolve the confirm action")


func _verify_paged_layout_keeps_highlight_visible() -> void:
	var helper := PerkFusionModalLayout.new()
	var candidate_ids: Array[String] = []
	for index in range(19):
		candidate_ids.append("candidate_%02d" % index)
	var snapshot := {
		"phase": "materials",
		"candidate_ids": candidate_ids,
		"highlight_index": 18,
	}
	var view_size := Vector2(760.0, 750.0)
	var layout: Dictionary = helper.build_layout(snapshot, view_size)
	var visible_indices: Array = _array(layout.get("visible_candidate_indices", []))
	_expect(visible_indices.has(18), "the page should always include the highlighted candidate")
	_expect(visible_indices.size() <= PerkFusionModalLayout.MAX_COLUMNS * PerkFusionModalLayout.MAX_ROWS, "visible row count should stay clamped")
	var rects: Array = _array(layout.get("candidate_rects", []))
	_expect(rects.size() == candidate_ids.size(), "paging should retain original candidate index alignment")
	_expect(helper.get_candidate_index_at(snapshot, _rect(rects[18]).get_center(), view_size) == 18, "paged hit test should return the original candidate index")


func _verify_renderer_contract() -> void:
	var renderer := PerkFusionOverlayRenderer.new()
	renderer.prewarm_assets()
	renderer.reset()
	renderer.draw(null, {}, null, Vector2.ZERO)
	_expect(renderer.has_method("draw"), "renderer should expose draw")
	_expect(renderer.has_method("prewarm_assets"), "renderer should expose prewarm_assets")
	_expect(renderer.has_method("reset"), "renderer should expose reset")

	var source: String = FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	_expect(source.find("func draw(") >= 0, "renderer should declare the integration draw API")
	_expect(source.find("canvas: CanvasItem") >= 0, "draw API should require a CanvasItem")
	_expect(source.find("fusion_snapshot: Dictionary") >= 0, "draw API should receive the fusion snapshot")
	_expect(source.find("icon_renderer: Object = null") >= 0, "draw API should keep the icon renderer optional")
	for phase_name in ["materials", "confirm", "animation", "reveal"]:
		_expect(source.find("\"%s\"" % phase_name) >= 0, "renderer should explicitly support the %s phase" % phase_name)
	_expect(source.find("PerkFusionLocalization") >= 0, "renderer should route visible copy through the fusion localization owner")
	var layout_source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_modal_layout.gd")
	_expect(source.find("snapshot.get(\"highlighted_index\"") < 0 and layout_source.find("snapshot.get(\"highlighted_index\"") < 0, "overlay and layout should consume only canonical highlight_index")
	for ghost_lookup in [
		"snapshot.get(\"probabilities\"",
		"snapshot.get(\"outcome_probabilities\"",
		"snapshot.get(\"preview\"",
		"snapshot.get(\"duration\"",
		"snapshot.get(\"animation_duration\"",
		"snapshot.get(\"phase_time\"",
		"snapshot.get(\"progress\"",
		"snapshot.get(\"selected_sources\"",
		"snapshot.get(\"record\"",
		"snapshot.get(\"result\"",
		"snapshot.get(\"outcome\"",
		"snapshot.get(\"fusion_revision\"",
	]:
		_expect(source.find(ghost_lookup) < 0, "overlay should not probe ghost snapshot key: %s" % ghost_lookup)
	_expect(source.find("func _format_preview_value(") < 0, "unused preview formatter should be removed")
	_expect(source.find("func _byproduct_name(") < 0, "unused byproduct-name wrapper should be removed")
	var canonical_probabilities: Dictionary = renderer._get_probabilities({
		"outcome_preview": {"weights": {"success": 0.60, "side_effect": 0.25, "byproduct": 0.15}},
	})
	_expect(is_equal_approx(float(canonical_probabilities.get("success", 0.0)), 0.60), "overlay should read probabilities from canonical outcome_preview.weights")
	var fallback_probabilities: Dictionary = renderer._get_probabilities({})
	var authored_weights := PerkFusionOutcomeRules.build_final_outcome_weights(false)
	_expect(fallback_probabilities == authored_weights, "missing preview weights should fall back to the production outcome-rules owner")
	_expect(source.find("weights.get(\"success\", 55.0)") < 0, "overlay must not duplicate authored outcome constants in a renderer fallback")
	_expect(is_equal_approx(renderer._animation_progress({"animation_remaining": 0.55}), 0.5), "overlay animation should read canonical animation_remaining")
	_expect(renderer._selected_sources({"selected_source_ids": ["alpha", "beta"]}) == ["alpha", "beta"], "overlay should read canonical selected_source_ids")
	_expect(renderer._record({"committed_record": {"fusion_id": "fusion_0"}}).get("fusion_id", "") == "fusion_0", "overlay should read canonical committed_record")
	var localization_source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_localization.gd")
	for korean_text in ["퍽 융합 재료 선택", "융합 확인", "융합 중...", "부작용 발생", "부산물 발견", "결정 키를 눌러 계속"]:
		_expect(localization_source.find(korean_text) >= 0, "localization owner should keep Korean copy for: %s" % korean_text)
	_expect(source.find("get_perk_data") >= 0, "renderer should resolve candidate names through the perk catalog")
	_expect(source.find("icon_renderer.draw_icon") >= 0, "renderer should reuse the perk icon renderer when available")
	_expect(source.find("Image.get_image") < 0 and source.find(".get_image(") < 0, "draw path must not scan image pixels")
	_expect(source.find("create_from_image") < 0, "draw path must not create textures from images")
	var detail_lines: Array[String] = renderer._result_lines({
		"sources": ["alpha", "beta"],
		"option_penalties": {
			"alpha": {"power": {"original_value": 100.0, "adjusted_value": 80.0}},
		},
		"deleted_options": {"beta": ["shield"]},
		"byproducts": ["reverb", "limit_break"],
		"byproduct_payloads": {"limit_break": {"eligible_sources": ["alpha"]}},
	}, "side_effect", null)
	var detail_text := "\n".join(detail_lines)
	_expect(detail_text.contains("100") and detail_text.contains("80") and detail_text.contains("20"), "S4 reveal should show actual before/after and realized penalty percent")
	_expect(detail_text.contains(PerkFusionLocalization.option_label("power")) and detail_text.contains(PerkFusionLocalization.option_label("shield")), "S4 reveal should name changed and deleted options without leaking raw keys")
	_expect(detail_text.contains(PerkFusionLocalization.byproduct_name("reverb")), "S4 reveal should list concrete byproduct names")
	_expect(detail_text.contains(PerkFusionLocalization.byproduct_name("limit_break")) and detail_text.contains("alpha"), "S4 reveal should include the limit-break payload target")
	var sensor_preview := PerkFusionLocalization.option_preview("auto_dash_cooldown_sec", 15.0, "reverse")
	var shrapnel_preview := PerkFusionLocalization.option_preview("shard_count", 8, "forward")
	_expect(not sensor_preview.contains("auto_dash_cooldown_sec") and sensor_preview.contains(PerkFusionLocalization.option_label("auto_dash_cooldown_sec")), "S2 preview should localize the sensor cooldown label")
	_expect(sensor_preview.contains("15") and sensor_preview.contains("초"), "S2 preview should show the sensor cooldown unit")
	_expect(not shrapnel_preview.contains("shard_count") and shrapnel_preview.contains(PerkFusionLocalization.option_label("shard_count")), "S2 preview should localize the shrapnel count label")
	_expect(shrapnel_preview.contains("8") and shrapnel_preview.contains("개"), "S2 preview should show the shrapnel count unit")
	_expect(source.find("_draw_reveal(canvas, fusion_snapshot, catalog, layout, icon_renderer)") >= 0, "S4 reveal should receive the icon renderer for its result card")
	_expect(source.find("PerkFusionIconKey.build(") >= 0, "S4 reveal should render the revisioned material-composite result card")


func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	const EPSILON := 0.01
	return (
		inner.position.x >= outer.position.x - EPSILON
		and inner.position.y >= outer.position.y - EPSILON
		and inner.end.x <= outer.end.x + EPSILON
		and inner.end.y <= outer.end.y + EPSILON
	)


func _rect(value: Variant) -> Rect2:
	return value if value is Rect2 else Rect2()


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
