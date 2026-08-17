extends SceneTree

const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlaySupport := preload("res://scripts/hud/character_info_overlay_support.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const KOREAN_UI_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")

const COLLECTION_VIEW_SIZE := Vector2i(1060, 1040)
const REVEAL_VIEW_SIZE := Vector2i(760, 750)
const TOOLTIP_VIEW_SIZE := Vector2i(760, 430)
const COLLECTION_CAPTURE_PATH := "res://.tmp/perk_fusion_byproduct_orb_collection_qa.png"
const REVEAL_CAPTURE_PATH := "res://.tmp/perk_fusion_byproduct_reveal_qa.png"
const TOOLTIP_CAPTURE_PATH := "res://.tmp/perk_fusion_byproduct_tooltip_qa.png"


class CollectionProbe:
	extends Node2D

	var icon_renderer: Object = null
	var byproduct_catalog: Object = null
	var draw_results: Array[bool] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(COLLECTION_VIEW_SIZE)), Color(0.025, 0.030, 0.052), true)
		draw_string(KOREAN_UI_FONT, Vector2(26.0, 40.0), "무공 합일 상승무공 21종 · 64px / 24px", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.96, 0.84, 0.56))
		draw_results.clear()
		# 은퇴 id도 그린다 — 아이콘 경로·PNG는 전수 커버리지 씰을 위해 보존되므로
		# 이 캡처가 21종 전부를 실제로 렌더해야 그 자산이 검증된다.
		var ids: Array = (
			byproduct_catalog.GENERAL_IDS
			+ byproduct_catalog.RARE_IDS
			+ byproduct_catalog.RESERVED_IDS
			+ byproduct_catalog.RETIRED_IDS
		)
		for index in range(ids.size()):
			var byproduct_id := str(ids[index])
			var data: Dictionary = byproduct_catalog.get_data(byproduct_id)
			var column := index % 5
			var row := index / 5
			var left := 24.0 + float(column) * 205.0
			var top := 72.0 + float(row) * 185.0
			var card_rect := Rect2(Vector2(left, top), Vector2(188.0, 165.0))
			var is_reserved := not bool(data.get("runtime_enabled", false))
			var border := Color(0.38, 0.42, 0.58, 0.72) if is_reserved else Color(0.78, 0.58, 0.22, 0.82)
			draw_rect(card_rect, Color(0.050, 0.060, 0.094, 0.96), true)
			draw_rect(card_rect, border, false, 1.5)
			var large_rect := Rect2(Vector2(left + 13.0, top + 42.0), Vector2(64.0, 64.0))
			var small_rect := Rect2(Vector2(left + 105.0, top + 61.0), Vector2(24.0, 24.0))
			draw_results.append(icon_renderer.draw_icon(self, byproduct_id, large_rect, 1.0, true))
			draw_results.append(icon_renderer.draw_icon(self, byproduct_id, small_rect, 1.0, not is_reserved))
			draw_string(KOREAN_UI_FONT, Vector2(left + 12.0, top + 27.0), str(data.get("name", byproduct_id)), HORIZONTAL_ALIGNMENT_LEFT, 164.0, 16, Color(0.94, 0.90, 0.80))
			var rarity_text := str(data.get("rarity", "general"))
			var badge_text := "은퇴" if rarity_text == "retired" else ("예약" if is_reserved else rarity_text)
			draw_string(KOREAN_UI_FONT, Vector2(left + 12.0, top + 132.0), badge_text, HORIZONTAL_ALIGNMENT_LEFT, 76.0, 12, Color(0.55, 0.62, 0.76) if is_reserved else Color(0.88, 0.70, 0.34))
			draw_string(KOREAN_UI_FONT, Vector2(left + 102.0, top + 104.0), "실제 24px", HORIZONTAL_ALIGNMENT_LEFT, 72.0, 11, Color(0.66, 0.72, 0.86))


class RevealProbe:
	extends Node2D

	var icon_renderer: Object = null
	var overlay_renderer: Object = null
	var runtime_catalog: Object = null

	func _draw() -> void:
		overlay_renderer.draw(self, {
			"phase": "reveal",
			"committed_record": {
				"fusion_id": "fusion_visual_qa",
				"created_revision": 1,
				"outcome": "byproduct",
				"sources": ["common_bulk_up", "common_swiftness"],
				"byproducts": ["reverb", "golden_trajectory", "limit_break"],
				"byproduct_payloads": {
					"limit_break": {"eligible_sources": ["common_bulk_up"]},
				},
			},
		}, runtime_catalog, Vector2(REVEAL_VIEW_SIZE), icon_renderer)


class TooltipProbe:
	extends Node2D

	var icon_renderer: Object = null
	var overlay_support: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(TOOLTIP_VIEW_SIZE)), Color(0.025, 0.030, 0.052), true)
		var record := {
			"sources": ["common_bulk_up", "common_swiftness"],
			"source_options": {
				"common_bulk_up": {"paddle_size_pct": {"value": 25.0}},
				"common_swiftness": {"player_speed_pct": {"value": 18.0}},
			},
			"byproducts": ["reverb", "golden_trajectory", "limit_break"],
			"byproduct_payloads": {"limit_break": {"eligible_sources": ["common_bulk_up"]}},
		}
		var source_labels := {"common_bulk_up": "철산공", "common_swiftness": "유운보"}
		var tagged_stats := "\n".join(PerkFusionLocalization.tooltip_stat_lines(record, source_labels, {
			"common_bulk_up": 5,
			"common_swiftness": 5,
		}, {
			"common_bulk_up": 5,
			"common_swiftness": 5,
		}))
		var roll_entries := CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(tagged_stats, "")
		overlay_support._draw_tooltip(self, {
			"title": "철산공 + 유운보 · 무공 합일",
			"subtitle": "합일",
			"body": "새 상승무공 3종을 얻은 합일 기록입니다.",
			"roll_options": roll_entries,
			"tooltip_kind": "fusion",
			"right_header": "무공 옵션",
			"color": Color(0.72, 0.46, 0.98),
			"anchor_rect": Rect2(28.0, 370.0, 42.0, 42.0),
		}, Vector2(30.0, 370.0), Vector2(TOOLTIP_VIEW_SIZE), KOREAN_UI_FONT, icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("perk_fusion_byproduct_icon_visual_qa: capture skipped under headless display server")
		print("perk_fusion_byproduct_icon_visual_qa: ok")
		quit(0)
		return

	var icon_renderer := RuntimePerkIconRenderer.new()
	icon_renderer.prewarm_assets()
	var byproduct_catalog := PerkFusionByproductCatalog.new()
	var runtime_catalog := RuntimePerkCatalog.new()
	var overlay_renderer := PerkFusionOverlayRenderer.new()
	overlay_renderer.prewarm_assets()
	var overlay_support := CharacterInfoOverlaySupport.new()

	var collection_probe := CollectionProbe.new()
	collection_probe.icon_renderer = icon_renderer
	collection_probe.byproduct_catalog = byproduct_catalog
	var collection_viewport := SubViewport.new()
	collection_viewport.size = COLLECTION_VIEW_SIZE
	collection_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	collection_viewport.transparent_bg = false
	get_root().add_child(collection_viewport)
	collection_viewport.add_child(collection_probe)

	var reveal_probe := RevealProbe.new()
	reveal_probe.icon_renderer = icon_renderer
	reveal_probe.overlay_renderer = overlay_renderer
	reveal_probe.runtime_catalog = runtime_catalog
	var reveal_viewport := SubViewport.new()
	reveal_viewport.size = REVEAL_VIEW_SIZE
	reveal_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reveal_viewport.transparent_bg = false
	get_root().add_child(reveal_viewport)
	reveal_viewport.add_child(reveal_probe)

	var tooltip_probe := TooltipProbe.new()
	tooltip_probe.icon_renderer = icon_renderer
	tooltip_probe.overlay_support = overlay_support
	var tooltip_viewport := SubViewport.new()
	tooltip_viewport.size = TOOLTIP_VIEW_SIZE
	tooltip_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tooltip_viewport.transparent_bg = false
	get_root().add_child(tooltip_viewport)
	tooltip_viewport.add_child(tooltip_probe)

	collection_probe.queue_redraw()
	reveal_probe.queue_redraw()
	tooltip_probe.queue_redraw()
	for _frame_index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	if collection_probe.draw_results.size() != 42 or collection_probe.draw_results.has(false):
		push_error("all 21 byproducts should draw through both 64px and 24px runtime paths")
		quit(1)
		return
	var collection_image := collection_viewport.get_texture().get_image()
	var reveal_image := reveal_viewport.get_texture().get_image()
	var tooltip_image := tooltip_viewport.get_texture().get_image()
	if collection_image == null or collection_image.is_empty() or collection_image.save_png(COLLECTION_CAPTURE_PATH) != OK:
		push_error("failed to save the byproduct orb collection capture")
		quit(1)
		return
	if reveal_image == null or reveal_image.is_empty() or reveal_image.save_png(REVEAL_CAPTURE_PATH) != OK:
		push_error("failed to save the byproduct reveal capture")
		quit(1)
		return
	if tooltip_image == null or tooltip_image.is_empty() or tooltip_image.save_png(TOOLTIP_CAPTURE_PATH) != OK:
		push_error("failed to save the byproduct tooltip capture")
		quit(1)
		return
	collection_probe.queue_free()
	collection_viewport.queue_free()
	reveal_probe.queue_free()
	reveal_viewport.queue_free()
	tooltip_probe.queue_free()
	tooltip_viewport.queue_free()
	await process_frame
	print("perk_fusion_byproduct_icon_visual_qa: ok")
	print(ProjectSettings.globalize_path(COLLECTION_CAPTURE_PATH))
	print(ProjectSettings.globalize_path(REVEAL_CAPTURE_PATH))
	print(ProjectSettings.globalize_path(TOOLTIP_CAPTURE_PATH))
	quit(0)
