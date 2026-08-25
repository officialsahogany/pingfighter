extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")

var _failures: Array[String] = []


func _init() -> void:
	var catalog := RuntimePerkCatalog.new()
	var levels := {
		"common_bulk_up": 5,
		"common_swiftness": 5,
		"adversity_armor": 1,
	}
	var effective_levels := levels.duplicate(true)
	var projection := {
		"fusion_revision": 1,
		"cache_signature": 101,
		"entries": [
			{
				"type": "fusion",
				"id": "fusion_0",
				"fusion_id": "fusion_0",
				"fusion_revision": 1,
				"sources": ["common_bulk_up", "common_swiftness"],
				"source_names": ["철산공", "유운보"],
				"base_levels": {"common_bulk_up": 5, "common_swiftness": 5},
				"effective_levels": {"common_bulk_up": 5, "common_swiftness": 5},
				"summary": "철산공 + 유운보 · 성공 융합",
				"slot_cost": 1,
				"record_payload": {
					"fusion_id": "fusion_0",
					"sources": ["common_bulk_up", "common_swiftness"],
					"outcome": "side_effect",
					"option_penalties": {
						"common_bulk_up": {
							"runtime_skill_bonus": {
								"original_value": 100.0,
								"adjusted_value": 80.0,
								"nominal_pct": 20.0,
							},
						},
					},
					"deleted_options": {},
					"byproducts": ["reverb"],
				},
			},
			{
				"type": "perk",
				"id": "adversity_armor",
				"perk_id": "adversity_armor",
				"base_level": 1,
				"effective_level": 1,
				"slot_cost": 1,
			},
		],
	}
	var snapshot := {
		"runtime_skill_levels": levels,
		"effective_runtime_skill_levels": effective_levels,
		"perk_fusion_display_projection": projection,
	}
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		levels,
		catalog,
		null,
		snapshot
	)
	_expect(acquired.size() == 2, "character info projection should fold two sources into one fusion entry")
	var fusion_count := 0
	for entry_value: Variant in acquired:
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("_draw_id", "")).begins_with("perk_fusion_pair:"):
			fusion_count += 1
			_expect(str(entry.get("id", "")) == "fusion_0", "character info should preserve fusion identity separately from its icon key")
			var parsed_icon := PerkFusionIconKey.parse(str(entry.get("_draw_id", "")))
			_expect(str(parsed_icon.get("fusion_id", "")) == "fusion_0" and int(parsed_icon.get("fusion_revision", 0)) == 1, "character info composite key should carry fusion identity and revision")
			_expect(parsed_icon.get("sources", []) == ["common_bulk_up", "common_swiftness"], "character info should route both materials into the composite icon")
			_expect(str(entry.get("description", "")).contains("100") and str(entry.get("description", "")).contains("80"), "fusion TAB tooltip should expose the actual before-to-after option values")
			_expect(str(entry.get("description", "")).contains("잔향"), "fusion TAB tooltip should expose acquired byproduct details")
			_expect(str(entry.get("detail", "")) != str(entry.get("description", "")), "fusion TAB tooltip should keep result log and material stats in separate panels")
			var stat_description := str(entry.get("description", ""))
			_expect(stat_description.contains("철산공 · 극성") and stat_description.contains("유운보 · 극성"), "fusion TAB stats should retain both material section headers with the canonical Korean max-rank label")
			_expect(not stat_description.contains("Lv.5"), "fusion TAB stats should not revive the retired Korean Lv.5 label")
	_expect(fusion_count == 1, "character info should render exactly one canonical fusion cell")

	var before_hash: int = CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash(
		levels,
		catalog,
		null,
		snapshot,
		effective_levels
	)
	var changed_snapshot: Dictionary = snapshot.duplicate(true)
	var changed_projection: Dictionary = projection.duplicate(true)
	changed_projection["fusion_revision"] = 2
	changed_projection["cache_signature"] = 102
	changed_snapshot["perk_fusion_display_projection"] = changed_projection
	var after_hash: int = CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash(
		levels,
		catalog,
		null,
		changed_snapshot,
		effective_levels
	)
	_expect(before_hash != after_hash, "character info cache should invalidate on fusion projection changes even when raw levels are identical")

	var overlay := RuntimePerkOverlayRenderer.new()
	var overlay_entries: Array = overlay._build_acquired_perks_for_snapshot(levels, catalog, null, snapshot)
	_expect(overlay_entries.size() == 2, "runtime choice status panel should consume the same folded projection")
	var overlay_ids: Array = []
	for entry_value: Variant in overlay_entries:
		overlay_ids.append(str((entry_value as Dictionary).get("id", "")))
	var found_overlay_pair := false
	for overlay_id_value: Variant in overlay_ids:
		var parsed_overlay := PerkFusionIconKey.parse(str(overlay_id_value))
		if parsed_overlay.get("sources", []) == ["common_bulk_up", "common_swiftness"]:
			found_overlay_pair = true
	_expect(found_overlay_pair, "runtime choice status panel should route fusion art through the revisioned material-pair icon key")
	_expect(not overlay_ids.has("common_bulk_up") and not overlay_ids.has("common_swiftness"), "runtime choice status panel must not redraw folded source perks")

	# 실 진입점 소스씰: 상태 패널의 실 드로우(_draw_status_panel)가 4인자
	# snapshot fold를 직접 소비해야 한다 — fold 빌더가 헬퍼로만 존재하고 실
	# 패널이 레거시 3인자 자체 빌더를 부르면(v1 반려 P1) 위 fold 검증은
	# 공허해진다.
	var status_panel_body := _extract_function_body(
		"res://scripts/hud/runtime_perk_overlay_renderer.gd",
		"func _draw_status_panel("
	)
	_expect(
		status_panel_body.contains("_build_acquired_perks_for_snapshot(levels, catalog, runtime_state, snapshot)"),
		"real status panel draw must consume the 4-arg snapshot fold builder"
	)
	_expect(
		not status_panel_body.contains("= _build_acquired_perks(levels, catalog, runtime_state)"),
		"real status panel draw must not fall back to the projection-blind legacy builder"
	)
	# v3(재리뷰 P1): 합성은 CanvasItem draw 밖 스테이지드 프리웜 소유 —
	# draw 함수 본문에는 prepare/합성 호출이 없어야 한다.
	_expect(
		not status_panel_body.contains("prepare_fusion_pair_icon"),
		"status panel draw must stay lookup-only (composition belongs to the update-path staged prewarm)"
	)

	_verify_staged_prewarm_real_entry()

	if _failures.is_empty():
		print("perk_fusion_display_consumer_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


# v3(재리뷰 P1): 스테이지드 프리웜 실 진입점 — 실제 RuntimePerkState.update()
# (배틀 오버레이 프레임 컨트롤러·플라자·결과화면 스타포인트 핸들러가 부르는
# 그 업데이트 틱)가 레지스트리의 아이콘 렌더러에 융합 재료쌍 텍스처를
# 합성시키고, 무변경 재호출은 마커로 O(1) 단락되는지 행동으로 봉인한다.
func _verify_staged_prewarm_real_entry() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"item_luck": 3, "common_bulk_up": 5}
	_expect(int(catalog.get_perk_data("item_luck").get("max_level", 0)) == 3, "staged prewarm fixture should keep item_luck at the catalog max level")
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "success"},
		catalog
	)
	_expect(not record.is_empty(), "staged prewarm fixture must commit a valid fusion")
	var renderer := RuntimePerkIconRenderer.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_icon_renderer"] = renderer
	state.update(1.0 / 60.0, Vector2(760.0, 750.0), null, registry)
	var stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(stats.get("compositions", 0)) == 1 and int(stats.get("textures", 0)) == 1, "the real state update tick must compose the fusion pair texture outside any draw call")
	var prewarm_projection: Dictionary = state.get_perk_fusion_display_projection()
	var pair_id := ""
	for prewarm_entry_value: Variant in prewarm_projection.get("entries", []) as Array:
		if prewarm_entry_value is Dictionary and str((prewarm_entry_value as Dictionary).get("type", "")) == "fusion":
			var prewarm_entry: Dictionary = prewarm_entry_value
			pair_id = PerkFusionIconKey.build(
				str(prewarm_entry.get("fusion_id", "")),
				int(prewarm_entry.get("fusion_revision", 0)),
				prewarm_entry.get("sources", []) as Array
			)
	_expect(pair_id != "" and renderer._get_icon_source(pair_id).get("texture", null) != null, "the draw-path lookup must hit the update-tick prewarmed texture")
	state.update(1.0 / 60.0, Vector2(760.0, 750.0), null, registry)
	_expect(int(renderer.get_fusion_pair_cache_stats().get("compositions", 0)) == 1, "an unchanged-revision update tick must short-circuit without recomposing")

	# 배선 소스씰: update 실경로와 TAB 오픈/부트 로딩 스텝이 스테이지드
	# 프리웜을 소유한다(드로우 소유 회귀 방지).
	var update_body := _extract_function_body(
		"res://scripts/characters/runtime_perk_state.gd",
		"func _update_internal("
	)
	_expect(update_body.contains("_prewarm_fusion_pair_icons(registry)"), "the real update entry must invoke the fusion icon staged prewarm")
	var tab_prewarm_body := _extract_function_body(
		"res://scripts/hud/character_info_overlay_core.gd",
		"func prewarm_assets("
	)
	_expect(tab_prewarm_body.contains("prewarm_fusion_pair_icons_for_state"), "the TAB overlay open prewarm must stage fusion pair icons")
	var boot_body := _extract_function_body(
		"res://scripts/core/battle_boot_resource_prewarm_controller.gd",
		"func prewarm_runtime_perk_overlay_resources_step("
	)
	_expect(boot_body.contains("prewarm_fusion_pair_icons_for_state"), "the battle boot loading step must stage fusion pair icons for restored saves")
	var grid_body := _extract_function_body(
		"res://scripts/hud/character_info_overlay_core.gd",
		"func _draw_perk_grid("
	)
	_expect(
		not grid_body.contains("prewarm_fusion_pair_icons") and not grid_body.contains("prepare_fusion_pair_icon"),
		"the TAB perk grid draw must stay lookup-only (no composition inside _draw)"
	)


# 소스씰용 함수 본문 추출(다음 최상위 func 선언 전까지) — 오딘 팡 v3의
# 함수본문 추출 씰 패턴.
func _extract_function_body(script_path: String, function_signature_prefix: String) -> String:
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		_failures.append("source seal could not open %s" % script_path)
		return ""
	var source: String = file.get_as_text()
	file.close()
	var start: int = source.find(function_signature_prefix)
	if start < 0:
		_failures.append("source seal could not find %s in %s" % [function_signature_prefix, script_path])
		return ""
	var end: int = source.find("\nfunc ", start + function_signature_prefix.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
