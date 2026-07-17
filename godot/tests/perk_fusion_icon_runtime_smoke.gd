extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")

var _failures: Array[String] = []


func _init() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	_expect(renderer.has_icon("perk_fusion"), "canonical fusion display icon should be renderable without an external PNG")
	for variant in range(5):
		var icon_id := "perk_fusion_%d" % variant
		var asset_path := "res://assets/sprites/perks/perk_fusion_offer_%d.png" % variant
		_expect(FileAccess.file_exists(asset_path), "fusion offer variant %d should have a final PNG asset" % variant)
		var asset_image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
		_expect(asset_image != null and not asset_image.is_empty(), "fusion offer variant %d PNG should decode" % variant)
		if asset_image != null and not asset_image.is_empty():
			_expect(asset_image.get_size() == Vector2i(128, 128), "fusion offer variant %d should be normalized to 128x128" % variant)
			_expect(_corner_alpha_max(asset_image) <= 0.02, "fusion offer variant %d should keep transparent corners" % variant)
			var opaque_ratio := _opaque_ratio(asset_image)
			_expect(opaque_ratio >= 0.08 and opaque_ratio <= 0.78, "fusion offer variant %d should keep a readable, uncropped silhouette" % variant)
		_expect(renderer.has_icon(icon_id), "fusion offer variant %d should be renderable" % variant)
		_expect(icon_id in renderer.covered_ids(), "fusion offer variant %d should participate in icon coverage" % variant)
	var pair_id := PerkFusionIconKey.build(
		"fusion_0",
		1,
		["common_bulk_up", "common_swiftness"]
	)
	_expect(renderer.has_icon(pair_id), "canonical fusion display icon should preserve both material identities")
	_expect(not renderer.has_animated_icon(pair_id), "static material pair should stay on the static icon path")
	var parsed := PerkFusionIconKey.parse(pair_id)
	_expect(str(parsed.get("fusion_id", "")) == "fusion_0", "pair key should preserve the canonical fusion id")
	_expect(int(parsed.get("fusion_revision", 0)) == 1, "pair key should preserve the global fusion revision")
	_expect(parsed.get("sources", []) == ["common_bulk_up", "common_swiftness"], "pair key should preserve both material identities")
	_expect(PerkFusionIconKey.parse("perk_fusion_pair:common_bulk_up|common_swiftness").is_empty(), "legacy two-part fusion icon keys should fail closed")
	var sheet_source_pair := PerkFusionIconKey.build(
		"fusion_sheet_source",
		1,
		["common_bulk_up", "ragnarok_hammer"]
	)
	_expect(not renderer.has_animated_icon(sheet_source_pair), "prepared fusion pairs should use deterministic static companion art instead of freezing an arbitrary sheet frame")
	_expect(renderer.prepare_fusion_pair_icon(pair_id, Vector2(64.0, 64.0), true), "pair compositor should prepare a cached texture outside the draw hot path")
	var first_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(first_stats.get("textures", 0)) == 1 and int(first_stats.get("compositions", 0)) == 1, "first pair preparation should compose one cached texture")
	_expect(renderer.prepare_fusion_pair_icon(pair_id, Vector2(64.0, 64.0), true), "same pair key should remain preparable")
	var hit_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(hit_stats.get("compositions", 0)) == 1, "same fusion/revision/source/size/active key must not recompose")
	var revised_id := PerkFusionIconKey.build("fusion_0", 2, ["common_bulk_up", "common_swiftness"])
	_expect(renderer.prepare_fusion_pair_icon(revised_id, Vector2(64.0, 64.0), true), "new revision should prepare a replacement texture")
	var revised_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(revised_stats.get("compositions", 0)) == 2 and int(revised_stats.get("textures", 0)) == 1, "revision change should invalidate the old fusion texture before recomposing")
	var changed_sources_id := PerkFusionIconKey.build("fusion_0", 2, ["common_bulk_up", "adversity_armor"])
	_expect(renderer.prepare_fusion_pair_icon(changed_sources_id, Vector2(64.0, 64.0), true), "source identity change should prepare a replacement texture")
	var source_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(source_stats.get("compositions", 0)) == 3 and int(source_stats.get("textures", 0)) == 1, "source identity change should invalidate the stale fusion texture")

	# v2(리뷰 P1-3): 복수 융합 공존 — 다른 fusion_id는 서로의 슬롯을 몰아내지
	# 않는다. A/B 교대 준비/드로우 조회가 재합성 스래싱을 만들면 안 된다.
	var second_fusion_id := PerkFusionIconKey.build("fusion_1", 2, ["adversity_armor", "common_swiftness"])
	_expect(renderer.prepare_fusion_pair_icon(second_fusion_id, Vector2(64.0, 64.0), true), "a second fusion should be preparable alongside the first")
	var coexist_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(coexist_stats.get("textures", 0)) == 2, "two distinct fusions should hold two coexisting cached textures")
	_expect(int(coexist_stats.get("compositions", 0)) == 4, "adding a second fusion should compose exactly once more")
	for _alternation in range(6):
		renderer.prepare_fusion_pair_icon(changed_sources_id, Vector2(64.0, 64.0), true)
		renderer.prepare_fusion_pair_icon(second_fusion_id, Vector2(64.0, 64.0), true)
		var alternating_a: Dictionary = renderer._get_icon_source(changed_sources_id)
		var alternating_b: Dictionary = renderer._get_icon_source(second_fusion_id)
		_expect(alternating_a.get("texture", null) != null and alternating_b.get("texture", null) != null, "alternating A/B draw lookups should both hit their own cached texture")
	var thrash_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(thrash_stats.get("compositions", 0)) == 4, "alternating A/B preparation and draw lookups must not recompose (cache thrash)")

	# 드로우 경로는 조회 전용: 준비 안 된 pair id는 소스 해석이 {}로 미스하고
	# (지연 합성 금지) compositions가 늘지 않는다 — 미스 프레임은 draw_icon의
	# 소유 절차 폴백이 담당한다.
	var unprepared_id := PerkFusionIconKey.build("fusion_2", 2, ["common_bulk_up", "common_swiftness"])
	var unprepared_source: Dictionary = renderer._get_icon_source(unprepared_id)
	_expect(unprepared_source.is_empty(), "draw-path icon source must not lazily compose an unprepared fusion pair")
	_expect(renderer.has_icon(unprepared_id), "unprepared fusion pair should still report renderable via the owned procedural fallback")
	var stale_revision_id := PerkFusionIconKey.build("fusion_0", 3, ["common_bulk_up", "adversity_armor"])
	_expect(renderer._get_icon_source(stale_revision_id).is_empty(), "draw-path lookup must not serve a stale-revision fusion texture")
	var lookup_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(lookup_stats.get("compositions", 0)) == 4, "draw-path lookups must never compose")

	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_icon_renderer.gd")
	_expect(source.find("const FUSION_OFFER_ICON_PATHS") >= 0, "fusion offer art should use an explicit PNG path table")
	_expect(source.find("FUSION_OFFER_ICON_PATHS.has(skill_id)") >= 0, "fusion offer art should enter the shared texture cache")
	_expect(source.find("func _draw_perk_fusion_icon(") >= 0, "fusion fallback art should have one owned renderer implementation")
	_expect(source.find("func _draw_perk_fusion_pair_icon(") >= 0, "fusion display art should have an owned two-material compositor")
	_expect(source.find("func _compose_fusion_pair_texture(") >= 0, "fusion display art should cache the composed texture rather than recomposing in draw")
	_expect(source.find("func _get_fusion_source_icon(") >= 0, "fusion display art should prefer deterministic static companion sources")
	_expect(source.find("draw_colored_polygon") < 0 or source.find("func _draw_perk_fusion_icon(") > source.find("draw_colored_polygon"), "fusion icon should avoid animated polygon triangulation hazards")
	# 실 드로우 진입점 소스씰: draw_icon이 pair 키를 소유 폴백 드로어로
	# 라우팅하고, 드로우 소비자(_get_icon_source pair 분기 / pair 드로어)
	# 본문에는 합성 호출이 없어야 한다.
	var draw_icon_body := _extract_function_body(source, "func draw_icon(")
	_expect(draw_icon_body.contains("_draw_perk_fusion_pair_icon"), "real draw_icon entry must route fusion pair keys to the owned pair drawer")
	var icon_source_body := _extract_function_body(source, "func _get_icon_source(")
	_expect(not icon_source_body.contains("prepare_fusion_pair_icon") and not icon_source_body.contains("_compose_fusion_pair_texture"), "draw-path icon source resolution must stay lookup-only")
	var pair_drawer_body := _extract_function_body(source, "func _draw_perk_fusion_pair_icon(")
	_expect(not pair_drawer_body.contains("prepare_fusion_pair_icon") and not pair_drawer_body.contains("_compose_fusion_pair_texture"), "pair drawer must stay lookup-plus-fallback without composing")
	if _failures.is_empty():
		print("perk_fusion_icon_runtime_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# 소스씰용 함수 본문 추출(다음 최상위 func 선언 전까지).
func _extract_function_body(source: String, function_signature_prefix: String) -> String:
	var start: int = source.find(function_signature_prefix)
	if start < 0:
		_failures.append("source seal could not find %s" % function_signature_prefix)
		return ""
	var end: int = source.find("\nfunc ", start + function_signature_prefix.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _corner_alpha_max(image: Image) -> float:
	var size := image.get_size()
	return maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(size.x - 1, 0).a),
		maxf(image.get_pixel(0, size.y - 1).a, image.get_pixel(size.x - 1, size.y - 1).a)
	)


func _opaque_ratio(image: Image) -> float:
	var opaque_pixels := 0
	var size := image.get_size()
	for y in range(size.y):
		for x in range(size.x):
			if image.get_pixel(x, y).a >= 0.10:
				opaque_pixels += 1
	return float(opaque_pixels) / maxf(1.0, float(size.x * size.y))
