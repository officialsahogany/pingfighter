extends SceneTree

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")
const TowerAscentNodeModalState := preload("res://scripts/tower_ascent/tower_ascent_node_modal_state.gd")

var _failures: Array[String] = []


class FakeTowerFlow:
	extends RefCounted

	var run_id := "tower-hud-run"
	var muhon := 17
	var gold := 4

	func get_run_id() -> String:
		return run_id

	func get_run_state_snapshot() -> Dictionary:
		return {"muhon": muhon, "gold": gold, "chance_gems": 2}


class CachedOnlyRegistry:
	extends RefCounted

	var flow_owner: Object
	var cold_get_calls := 0

	func _init(value: Object) -> void:
		flow_owner = value

	func get_cached_instance(key: String) -> Object:
		return flow_owner if key == "tower_ascent_flow_owner" else null

	func get_instance(_key: String) -> Object:
		cold_get_calls += 1
		return null


func _init() -> void:
	_verify_cached_run_balance_projection()
	_verify_non_tower_path_stays_hidden()
	_verify_layout_pairs_horizontally_at_acceptance_resolution()
	_verify_non_tower_gold_layout_stays_single()
	_verify_frame_free_draw_contract()
	if _failures.is_empty():
		print("tower_battle_muhon_hud_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cached_run_balance_projection() -> void:
	var flow := FakeTowerFlow.new()
	var registry := CachedOnlyRegistry.new(flow)
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var model: Dictionary = drawer.call("_build_tower_muhon_hud_context", registry)
	var pillar_gold := int(drawer.call("_build_gold_hud_amount", {"runtime_perk_gold": 900}, registry))
	_expect(bool(model.get("tower_muhon_hud_visible", false)), "started tower run should expose the Muhon HUD")
	_expect(int(model.get("tower_muhon_hud_amount", -1)) == 17, "Muhon HUD should read the live tower run balance")
	_expect(pillar_gold == 4, "tower pillar gold should read the same run-owned economy as the shop modal")
	var modal := TowerAscentNodeModalState.new()
	modal.open("shop", "shop", flow.get_run_state_snapshot(), [])
	_expect(str(modal.build_view_model().get("gold_text", "")).contains("4"), "shop modal and pillar must project the same run gold in one fixture")
	_expect(registry.cold_get_calls == 0, "tower currency draw projection must never cold-create the tower flow owner")

	flow.muhon = 3
	flow.gold = 9
	model = drawer.call("_build_tower_muhon_hud_context", registry)
	_expect(int(model.get("tower_muhon_hud_amount", -1)) == 3, "Muhon HUD should refresh from the cached run state")
	_expect(int(drawer.call("_build_gold_hud_amount", {}, registry)) == 9, "gold HUD should refresh from the cached run state")


func _verify_non_tower_path_stays_hidden() -> void:
	var flow := FakeTowerFlow.new()
	flow.run_id = ""
	var registry := CachedOnlyRegistry.new(flow)
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var model: Dictionary = drawer.call("_build_tower_muhon_hud_context", registry)
	_expect(not bool(model.get("tower_muhon_hud_visible", true)), "non-tower battle should not show a stale Muhon counter")
	_expect(int(drawer.call("_build_gold_hud_amount", {"runtime_perk_gold": 13}, registry)) == 13, "non-tower battle must retain the prior plaza-plus-runtime gold path")
	_expect(registry.cold_get_calls == 0, "hidden tower currency HUD must remain a cached-only lookup")


func _verify_layout_pairs_horizontally_at_acceptance_resolution() -> void:
	var renderer: Object = Stage1PillarUiRenderer.new()
	var context := {
		"height": 750.0,
		"gold_hud_amount": 99999,
		"tower_muhon_hud_visible": true,
		"tower_muhon_hud_amount": 99999,
	}
	var window_scale := 1246.0 / 750.0
	var logical_window_width := 2020.0 / window_scale
	var game_offset := Vector2((logical_window_width - 760.0) * 0.5, 0.0)
	var game_size := Vector2(760.0, 750.0)
	var layout: Dictionary = renderer.build_currency_hud_layout(game_offset, game_size, context)
	var gold_rect: Rect2 = layout.get("gold_rect", Rect2())
	var muhon_rect: Rect2 = layout.get("muhon_rect", Rect2())
	_expect(bool(layout.get("pair_fits", false)), "99,999 gold and Muhon must fit the 2020x1246 left pillar")
	_expect(is_equal_approx(muhon_rect.position.y, gold_rect.position.y), "tower currencies should share one baseline row")
	_expect(muhon_rect.position.x >= gold_rect.end.x, "Muhon should sit to the right of gold without overlap")
	_expect(muhon_rect.end.x < game_offset.x, "currency pair must stay outside the playfield")
	_expect(gold_rect.position.x >= 0.0, "currency pair must stay on-screen at the acceptance resolution")
	_verify_actual_text_width(renderer, gold_rect, "99,999", float(layout.get("content_scale", 1.0)), "gold")
	_verify_actual_text_width(renderer, muhon_rect, "99,999", float(layout.get("content_scale", 1.0)), "Muhon")


func _verify_non_tower_gold_layout_stays_single() -> void:
	var renderer: Object = Stage1PillarUiRenderer.new()
	var game_offset := Vector2(260.0, 60.0)
	var game_size := Vector2(760.0, 750.0)
	var baseline_context := {"height": 750.0, "gold_hud_amount": 1200}
	var hidden_context := baseline_context.duplicate(true)
	hidden_context["tower_muhon_hud_visible"] = false
	hidden_context["tower_muhon_hud_amount"] = 99999
	var baseline_gold: Rect2 = renderer.build_gold_hud_rect(game_offset, game_size, baseline_context)
	var hidden_gold: Rect2 = renderer.build_gold_hud_rect(game_offset, game_size, hidden_context)
	var hidden_muhon: Rect2 = renderer.build_muhon_hud_rect(game_offset, game_size, hidden_context)
	_expect(hidden_gold == baseline_gold, "hidden tower state must not move or resize the normal gold HUD")
	_expect(hidden_muhon.size == Vector2.ZERO, "non-tower screens must not allocate a Muhon footprint")


func _verify_frame_free_draw_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/stage1_pillar_ui_renderer.gd")
	_expect(source.find("_draw_gold_hud_frame") < 0, "gold currency frame helper must be removed")
	_expect(source.find("_draw_muhon_hud_frame") < 0, "Muhon currency frame helper must be removed")
	_expect(source.find("PremiumPanelFrame") < 0, "currency renderer must not retain flat panel chrome")
	var first_outline := source.find("canvas.draw_string_outline")
	var second_outline := source.find("canvas.draw_string_outline", first_outline + 1)
	_expect(first_outline >= 0 and second_outline > first_outline, "both currency labels must use text outlines")


func _verify_actual_text_width(
	renderer: Object,
	rect: Rect2,
	text: String,
	content_scale: float,
	label: String
) -> void:
	var font: Font = ThemeDB.fallback_font
	_expect(font != null, "%s font must exist for rendered-width proof" % label)
	if font == null:
		return
	var icon_size: float = Stage1PillarUiRenderer.GOLD_HUD_COIN_SIZE * content_scale
	var text_left: float = (
		rect.position.x
		+ Stage1PillarUiRenderer.GOLD_HUD_SIDE_MARGIN * content_scale
		+ icon_size
		+ Stage1PillarUiRenderer.GOLD_HUD_TEXT_GAP * content_scale
	)
	var max_text_width: float = (
		rect.end.x
		- text_left
		- Stage1PillarUiRenderer.GOLD_HUD_TEXT_RIGHT_PAD * content_scale
	)
	var base_font_size: int = int(round(float(Stage1PillarUiRenderer.GOLD_HUD_FONT_SIZE) * content_scale))
	var fitted_font_size: int = int(renderer.call(
		"_fit_gold_font_size",
		font,
		text,
		base_font_size,
		max_text_width
	))
	var actual_drawn_width: float = font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		fitted_font_size
	).x
	_expect(
		actual_drawn_width <= max_text_width + 0.01,
		"%s maximum digits must fit their actual rendered text width" % label
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
