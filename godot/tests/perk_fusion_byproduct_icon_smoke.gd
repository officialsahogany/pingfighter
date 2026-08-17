extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayTextUtils := preload("res://scripts/hud/character_info_overlay_text_utils.gd")
const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PROMOTED_MUGONG_SEAL_IDS := {"gravitybelt": true, "smartphone": true}

var _failures: Array[String] = []


func _init() -> void:
	_verify_complete_orb_asset_set()
	_verify_tooltip_rows_keep_byproduct_icon_ids()
	_verify_wrapped_tooltip_rows_keep_icon_layout()
	_verify_reveal_row_uses_canonical_byproduct_ids()
	if _failures.is_empty():
		print("perk_fusion_byproduct_icon_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_complete_orb_asset_set() -> void:
	var catalog := PerkFusionByproductCatalog.new()
	var renderer := RuntimePerkIconRenderer.new()
	var all_data: Dictionary = catalog.get_all_data()
	_expect(all_data.size() == 21, "fixture should cover all 14 active, 6 reserved, and 1 retired byproducts")
	for byproduct_id_value: Variant in all_data.keys():
		var byproduct_id := str(byproduct_id_value)
		var asset_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(byproduct_id, ""))
		_expect(not asset_path.is_empty(), "%s should have an explicit PNG-first orb path" % byproduct_id)
		_expect(FileAccess.file_exists(asset_path), "%s orb PNG should exist" % byproduct_id)
		var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
		_expect(image != null and not image.is_empty(), "%s orb PNG should decode" % byproduct_id)
		if image == null or image.is_empty():
			continue
		_expect(_corner_alpha_max(image) <= 0.01, "%s orb should keep truly transparent corners" % byproduct_id)
		_expect(renderer.has_icon(byproduct_id), "%s should resolve through the live runtime icon renderer" % byproduct_id)
		_expect(byproduct_id in renderer.covered_ids(), "%s should participate in icon coverage and prewarm" % byproduct_id)
		if bool(PROMOTED_MUGONG_SEAL_IDS.get(byproduct_id, false)):
			_expect(image.get_size() == Vector2i(256, 256), "%s should reuse its accepted promoted-Mugong seal" % byproduct_id)
			continue
		_expect(image.get_size() == Vector2i(64, 64), "%s orb should use the shared 64px source size" % byproduct_id)
		var alpha_counts := _alpha_counts(image)
		_expect(int(alpha_counts.get("semi", 0)) <= 8, "%s orb should not carry a soft square/checker matte" % byproduct_id)
		var opaque_ratio := float(alpha_counts.get("opaque", 0)) / 4096.0
		_expect(opaque_ratio >= 0.40 and opaque_ratio <= 0.60, "%s orb should keep a consistent, uncropped circular fill" % byproduct_id)


func _verify_tooltip_rows_keep_byproduct_icon_ids() -> void:
	var catalog := PerkFusionByproductCatalog.new()
	for byproduct_id_value: Variant in catalog.get_all_data().keys():
		var byproduct_id := str(byproduct_id_value)
		var tagged_lines := PerkFusionLocalization.tooltip_stat_lines({
			"byproducts": [byproduct_id],
		}, {})
		var entries := CharacterInfoOverlayPerkPresenter.build_perk_stat_entries("\n".join(tagged_lines), "")
		_expect(entries.size() == 1, "%s should produce one tagged tooltip lane" % byproduct_id)
		if entries.size() == 1:
			_expect(str((entries[0] as Dictionary).get("icon_id", "")) == byproduct_id, "%s tooltip lane should retain its canonical icon id" % byproduct_id)


func _verify_wrapped_tooltip_rows_keep_icon_layout() -> void:
	var line_cache: Array = []
	var line_dict_cache: Array = []
	var text_cache: Array[String] = []
	var color_cache: Array[Color] = []
	var state := CharacterInfoOverlayTextUtils.refresh_tooltip_entry_lines(
		null,
		[{"text": "잔향 — 긴 상승무공 설명", "color": Color.WHITE, "icon_id": "reverb"}],
		14,
		120.0,
		4,
		0,
		0,
		0,
		0,
		line_cache,
		line_dict_cache,
		text_cache,
		color_cache,
		Callable(self, "_wrap_fixture"),
		Color.WHITE
	)
	var lines: Array = state.get("lines", []) as Array
	_expect(lines.size() == 2, "wrapped byproduct fixture should produce two lines")
	if lines.size() == 2:
		_expect(str((lines[0] as Dictionary).get("icon_id", "")) == "reverb", "first wrapped line should draw the byproduct orb")
		_expect(bool((lines[0] as Dictionary).get("icon_indent", false)), "first wrapped line should reserve icon width")
		_expect(not (lines[1] as Dictionary).has("icon_id"), "continuation line should not repeat the orb")
		_expect(bool((lines[1] as Dictionary).get("icon_indent", false)), "continuation line should stay aligned with the icon-indented text")


func _verify_reveal_row_uses_canonical_byproduct_ids() -> void:
	var renderer := PerkFusionOverlayRenderer.new()
	var ids := renderer._record_byproduct_ids({
		"byproducts": ["reverb", {"id": "limit_break"}, "reverb", ""],
	})
	_expect(ids == ["reverb", "limit_break"], "reveal row should normalize dictionary/string payloads and remove duplicates")
	var source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	var reveal_body := _extract_function_body(source, "func _draw_reveal(")
	_expect(reveal_body.contains("_draw_byproduct_icon_row"), "real S4 reveal should draw the acquired byproduct orb row")
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
	var dual_body := _extract_function_body(tooltip_source, "static func draw_dual_item_tooltip(")
	_expect(dual_body.contains("breakdown_icon_drawer.call(canvas, icon_id, icon_rect)"), "real fusion tooltip panel should draw icon metadata beside byproduct rows")


func _wrap_fixture(_font: Font, text: String, _size: int, _max_width: float, _max_lines: int) -> Array:
	var split_at := text.find(" — ")
	if split_at < 0:
		return [text]
	return [text.substr(0, split_at), text.substr(split_at + 3)]


func _corner_alpha_max(image: Image) -> float:
	var size := image.get_size()
	return maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(size.x - 1, 0).a),
		maxf(image.get_pixel(0, size.y - 1).a, image.get_pixel(size.x - 1, size.y - 1).a)
	)


func _alpha_counts(image: Image) -> Dictionary:
	var opaque := 0
	var semi := 0
	var transparent := 0
	var size := image.get_size()
	for y in range(size.y):
		for x in range(size.x):
			var alpha := image.get_pixel(x, y).a
			if alpha > 200.0 / 255.0:
				opaque += 1
			elif alpha > 8.0 / 255.0:
				semi += 1
			else:
				transparent += 1
	return {"opaque": opaque, "semi": semi, "transparent": transparent}


func _extract_function_body(source: String, function_signature_prefix: String) -> String:
	var start := source.find(function_signature_prefix)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + function_signature_prefix.length())
	var static_end := source.find("\nstatic func ", start + function_signature_prefix.length())
	if static_end >= 0 and (end < 0 or static_end < end):
		end = static_end
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
