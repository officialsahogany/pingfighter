extends SceneTree
# expect-zero-object-leaks

const PerkFusionModalLayout := preload("res://scripts/characters/perk_fusion_modal_layout.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const VIEW_SIZE := Vector2(760.0, 750.0)
const PANEL_SIZE := Vector2(720.0, 690.0)

var _failures: Array[String] = []
var _draw_ran := false
var _renderer: Object


class CatalogStub:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		return {"name": perk_id.capitalize()}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_layout_contract()
	_verify_asset_and_prewarm_contract()
	_verify_painted_scroll_readability_contract()
	_verify_heading_fit_all_languages()
	_verify_source_branch_contract()
	await _verify_textured_and_fallback_draw_branches()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("perk_fusion_modal_painted_shell_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_layout_contract() -> void:
	var helper := PerkFusionModalLayout.new()
	var layout: Dictionary = helper.build_layout(_confirm_snapshot(), VIEW_SIZE)
	var panel_rect: Rect2 = _rect(layout.get("panel_rect", Rect2()))
	_expect(panel_rect.size.is_equal_approx(PANEL_SIZE), "large viewport should retain the authored 720x690 panel")
	var pair_rects: Array = _array(layout.get("pair_rects", []))
	_expect(pair_rects.size() == 2, "confirm layout should expose the scroll pair")
	if pair_rects.size() == 2:
		var left: Rect2 = _rect(pair_rects[0])
		var right: Rect2 = _rect(pair_rects[1])
		var gap := right.position.x - left.end.x
		_expect(gap / panel_rect.size.x >= 0.18, "scroll center gap should preserve the painted-shell vortex lane")
		_expect(left.size.y / panel_rect.size.y >= 0.24, "scroll height should retain the authored 170px presentation span")
	var probability_rect: Rect2 = _rect(layout.get("probability_rect", Rect2()))
	_expect(probability_rect.size.y >= 180.0, "probability lane should fit label, 110px medallion, and percentage rows")
	for button_key: String in ["back_rect", "confirm_rect"]:
		var button_rect: Rect2 = _rect(layout.get(button_key, Rect2()))
		_expect(button_rect.size.x / panel_rect.size.x >= 0.26, "%s should retain the enlarged painted plate width" % button_key)
		_expect(button_rect.size.y / panel_rect.size.y >= 0.07, "%s should retain the enlarged painted plate height" % button_key)
		_expect(panel_rect.encloses(button_rect), "%s should remain inside the panel" % button_key)
	_expect(
		helper.get_action_at(_confirm_snapshot(), _rect(layout.get("confirm_rect", Rect2())).get_center(), VIEW_SIZE) == "confirm",
		"the enlarged confirm plate and hit test should share one layout owner"
	)
	var small_layout: Dictionary = helper.build_layout(_confirm_snapshot(), Vector2(420.0, 560.0))
	var small_panel: Rect2 = _rect(small_layout.get("panel_rect", Rect2()))
	_expect(Rect2(Vector2.ZERO, Vector2(420.0, 560.0)).encloses(small_panel), "small-window painted shell should stay within the viewport")
	var small_probability_rect: Rect2 = _rect(small_layout.get("probability_rect", Rect2()))
	var small_back_rect: Rect2 = _rect(small_layout.get("back_rect", Rect2()))
	var small_medallion_span: float = PerkFusionOverlayRenderer.new()._probability_medallion_span(small_probability_rect)
	_expect(small_probability_rect.size.y >= 125.0, "small-window probability lane should retain enough vertical room")
	_expect(small_medallion_span <= small_probability_rect.size.x * 0.15 + 0.01, "small-window medallions should not overlap the five final-outcome columns")
	_expect(small_probability_rect.end.y < small_back_rect.position.y, "small-window probability lane should finish before the footer buttons")


func _verify_asset_and_prewarm_contract() -> void:
	_renderer = PerkFusionOverlayRenderer.new()
	_renderer.prewarm_assets()
	_expect(bool(_renderer._assets_prewarmed), "painted-shell assets should prewarm at the discrete overlay prewarm point")
	var expected_sizes := {
		"backdrop": Vector2i(1440, 1380),
		"scroll_left": Vector2i(460, 340),
		"scroll_right": Vector2i(460, 340),
		"medallion_stable": Vector2i(220, 220),
		"medallion_side": Vector2i(220, 220),
		"medallion_byproduct": Vector2i(220, 220),
		"button_plate": Vector2i(400, 108),
		"button_primary": Vector2i(400, 108),
	}
	for texture_key: String in expected_sizes.keys():
		var texture: Texture2D = _renderer._texture(texture_key)
		_expect(texture != null, "prewarm should load %s" % texture_key)
		if texture != null:
			_expect(Vector2i(texture.get_width(), texture.get_height()) == expected_sizes[texture_key], "%s should retain its authored 2x dimensions" % texture_key)
	var runtime_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(runtime_source.contains("_perk_fusion_overlay_renderer.prewarm_assets()"), "production overlay prewarm should call the painted-shell renderer")


func _verify_painted_scroll_readability_contract() -> void:
	_expect(not _renderer._candidate_state_border_visible(true, 0, false), "confirm scrolls should suppress the yellow selection rectangle")
	_expect(_renderer._candidate_state_border_visible(true, 0, true), "materials cards should retain their selection-state border")
	var painted_colors: Dictionary = _renderer._candidate_preview_colors(true)
	for color_key: String in ["title", "detail", "option"]:
		var color: Color = painted_colors.get(color_key, Color.WHITE)
		_expect(color.get_luminance() < 0.30, "painted scroll %s should use dark ink on bright hanji" % color_key)
		_expect(color.a >= 0.95, "painted scroll %s should remain opaque enough to read" % color_key)
	var source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	_expect(source.contains("\"scroll_left\" if pair_index == 0 else \"scroll_right\",\n\t\t\tfalse"), "confirm pair should opt out of candidate state borders")


func _verify_heading_fit_all_languages() -> void:
	var panel_rect: Rect2 = PerkFusionModalLayout.new().build_layout({}, VIEW_SIZE).get("panel_rect", Rect2())
	var title_keys: Array[String] = [
		"materials_title", "confirm_title", "animation_title", "outcome_stable",
		"outcome_success", "outcome_side", "outcome_byproduct", "outcome_complete",
	]
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		for title_key: String in title_keys:
			var heading: Dictionary = _renderer._heading_layout(panel_rect, PerkFusionLocalization.text(title_key))
			var title_rect: Rect2 = _rect(heading.get("title_rect", Rect2()))
			var max_width := float(heading.get("title_max_width", 0.0))
			_expect(title_rect.size.x <= max_width + 0.01, "%s/%s title should fit the painted clear span" % [locale, title_key])
			_expect(panel_rect.encloses(title_rect), "%s/%s title should remain inside the panel" % [locale, title_key])
			var title_center_y_frac := (title_rect.get_center().y - panel_rect.position.y) / panel_rect.size.y
			_expect(title_center_y_frac >= 0.10 and title_center_y_frac <= 0.12, "%s/%s title should retain the mockup heading band" % [locale, title_key])
	LanguageSettings.set_test_locale_override("")


func _verify_source_branch_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	_expect(source.contains("if backdrop_texture != null:\n\t\tcanvas.draw_texture_rect(backdrop_texture, panel_rect, false)\n\t\treturn"), "textured shell should return before procedural panel fill and borders")
	_expect(source.contains("if frame_texture != null:") and source.contains("canvas.draw_texture_rect(frame_texture, rect, false)"), "confirm scroll texture should replace the candidate-card fill")
	_expect(source.contains("if button_texture != null:") and source.contains("canvas.draw_texture_rect(button_texture, rect, false, modulate)"), "button plate texture should replace the procedural fill and border")
	_expect(source.contains("if _texture(\"backdrop\") == null:"), "procedural heading rules and stamp should be fallback-only")
	_expect(source.contains("_as_rect2(layout.get(\"back_rect\", Rect2())).position.y - 24.0"), "irreversible warning should anchor to the footer button lane")
	var draw_start := source.find("func draw(")
	_expect(draw_start >= 0 and not source.substr(draw_start).contains("load("), "draw path should consume prewarmed textures without lazy resource loads")


func _verify_textured_and_fallback_draw_branches() -> void:
	var cached_textures: Dictionary = _renderer._textures.duplicate()
	await _draw_confirm_branch()
	_renderer._textures.clear()
	await _draw_confirm_branch()
	_renderer._textures = cached_textures
	_expect(not cached_textures.is_empty(), "textured draw branch should start with production assets")


func _draw_confirm_branch() -> void:
	_draw_ran = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := Control.new()
	probe.custom_minimum_size = VIEW_SIZE
	probe.size = VIEW_SIZE
	probe.draw.connect(_on_probe_draw.bind(probe))
	viewport.add_child(probe)
	for _attempt: int in range(4):
		probe.queue_redraw()
		await process_frame
		if _draw_ran:
			break
	_expect(_draw_ran, "confirm renderer should execute with and without painted textures")
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _on_probe_draw(probe: Control) -> void:
	_draw_ran = true
	_renderer.draw(probe, _confirm_snapshot(), CatalogStub.new(), VIEW_SIZE)


func _confirm_snapshot() -> Dictionary:
	return {
		"phase": "confirm",
		"selected_source_ids": ["alpha", "beta"],
		"source_previews": [
			{
				"perk_id": "alpha",
				"base_level": 5,
				"effective_level": 5,
				"options": [
					{"key": "damage", "value": 18.8, "polarity": "forward"},
					{"key": "cooldown", "value": 4.8, "polarity": "forward"},
					{"key": "duration", "value": 9.0, "polarity": "forward"},
				],
			},
			{"perk_id": "beta", "base_level": 5, "effective_level": 5, "options": []},
		],
		"outcome_preview": {
			"weights": {
				"success": 0.20,
				"side_effect": 0.10,
				"byproduct": 0.70,
				"byproduct_count_1": 0.40,
				"byproduct_count_2": 0.20,
				"byproduct_count_3": 0.10,
			},
		},
	}


func _rect(value: Variant) -> Rect2:
	return value if value is Rect2 else Rect2()


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
