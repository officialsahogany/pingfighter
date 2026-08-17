extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlaySupport := preload("res://scripts/hud/character_info_overlay_support.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const CAPTURE_PATH := "res://.tmp/perk_fusion_source_cards_tooltip_qa.png"
const KOREAN_UI_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")


class TooltipProbe:
	extends Node2D

	var overlay_support: Object = null
	var icon_renderer: Object = null
	var hover_data: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.035, 0.065), true)
		_draw_mock_character_info_backdrop()
		overlay_support._draw_tooltip(
			self,
			hover_data,
			Vector2(650.0, 692.0),
			Vector2(VIEW_SIZE),
			KOREAN_UI_FONT,
			icon_renderer
		)

	func _draw_mock_character_info_backdrop() -> void:
		var panel := Rect2(18.0, 550.0, 724.0, 180.0)
		draw_rect(panel, Color(0.055, 0.090, 0.145, 0.94), true)
		draw_rect(panel, Color(0.22, 0.52, 0.74, 0.65), false, 2.0)
		draw_string(KOREAN_UI_FONT, Vector2(36.0, 582.0), "보유 무공", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.78, 0.90, 1.0))
		var source_a_rect := Rect2(42.0, 612.0, 64.0, 64.0)
		var source_b_rect := Rect2(122.0, 612.0, 64.0, 64.0)
		var fusion_rect := Rect2(202.0, 612.0, 64.0, 64.0)
		icon_renderer.draw_icon(self, "common_bulk_up", source_a_rect, 0.48, true)
		icon_renderer.draw_icon(self, "dash_lightweight", source_b_rect, 0.48, true)
		icon_renderer.draw_icon(self, str(hover_data.get("fusion_draw_id", "perk_fusion")), fusion_rect, 1.0, true)
		draw_rect(fusion_rect.grow(4.0), Color(0.75, 0.48, 1.0, 0.92), false, 2.0)
		draw_string(KOREAN_UI_FONT, Vector2(213.0, 699.0), "합일", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.82, 0.35))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("perk_fusion_source_cards_tooltip_visual_qa: capture skipped under headless display server")
		print("perk_fusion_source_cards_tooltip_visual_qa: ok")
		LanguageSettings.set_test_locale_override("")
		quit(0)
		return

	var catalog := RuntimePerkCatalog.new()
	var acquired := CharacterInfoOverlayPerkPresenter.build_acquired_perks_from_projection(
		[_fusion_entry_fixture()],
		catalog,
		{},
		Color.CORNFLOWER_BLUE,
		Color.GOLD
	)
	if acquired.size() != 1:
		push_error("visual fixture failed to build the fusion entry")
		quit(1)
		return
	var fusion: Dictionary = acquired[0] as Dictionary
	var packed := CharacterInfoOverlayPerkPresenter.pack_fusion_hover_body(
		str(fusion.get("detail", "")),
		str(fusion.get("description", "")),
		fusion.get("fusion_sections", []) as Array
	)
	var payload := CharacterInfoOverlayPerkPresenter.build_fusion_hover_payload(packed)
	var hover_data := CharacterInfoOverlayValueUtils.set_hover_data(
		{},
		str(fusion.get("name", "")),
		str(fusion.get("_level_text", "")),
		str(payload.get("body", "")),
		Color(0.72, 0.46, 0.98),
		null,
		Rect2(202.0, 612.0, 64.0, 64.0),
		payload.get("roll_options", [])
	)
	hover_data["tooltip_kind"] = "fusion"
	hover_data["fusion_sections"] = payload.get("fusion_sections", [])
	hover_data["fusion_draw_id"] = str(fusion.get("_draw_id", "perk_fusion"))

	var icon_renderer := RuntimePerkIconRenderer.new()
	icon_renderer.prewarm_assets()
	icon_renderer.prepare_fusion_pair_icon(str(fusion.get("_draw_id", "")), Vector2(64.0, 64.0), true)
	var overlay_support := CharacterInfoOverlaySupport.new()
	var probe := TooltipProbe.new()
	probe.overlay_support = overlay_support
	probe.icon_renderer = icon_renderer
	probe.hover_data = hover_data
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("failed to save the three-card fusion tooltip capture")
		LanguageSettings.set_test_locale_override("")
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	LanguageSettings.set_test_locale_override("")
	print("perk_fusion_source_cards_tooltip_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)


func _fusion_entry_fixture() -> Dictionary:
	return {
		"type": "fusion",
		"id": "fusion_cheolsan_hoegi",
		"fusion_id": "fusion_cheolsan_hoegi",
		"fusion_revision": 4,
		"sources": ["common_bulk_up", "dash_lightweight"],
		"source_names": ["철산공", "회기보"],
		"base_levels": {"common_bulk_up": 5, "dash_lightweight": 5},
		"effective_levels": {"common_bulk_up": 5, "dash_lightweight": 5},
		"live_source_options": {
			"common_bulk_up": {
				"runtime_skill_bonus": {"value": 0.3, "adjusted_value": 0.24},
			},
		},
		"summary": "철산공 + 회기보 · 주화입마 합일 · 상승무공 1개",
		"slot_cost": 1,
		"record_payload": {
			"fusion_id": "fusion_cheolsan_hoegi",
			"sources": ["common_bulk_up", "dash_lightweight"],
			"outcome": "side_effect",
			"option_penalties": {
				"common_bulk_up": {
					"runtime_skill_bonus": {
						"original_value": 0.3,
						"adjusted_value": 0.24,
						"nominal_pct": 20.0,
					},
				},
			},
			"deleted_options": {},
			"byproducts": ["reverb"],
			"byproduct_payloads": {},
		},
	}
