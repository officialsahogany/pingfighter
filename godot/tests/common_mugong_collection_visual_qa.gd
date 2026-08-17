extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")

const VIEW_SIZE := Vector2i(1180, 760)
const CAPTURE_PATH := "res://.tmp/common_mugong_collection_qa.png"
const CELL_FILL := Color(20.0 / 255.0, 25.0 / 255.0, 38.0 / 255.0, 0.96)
const SPECS := [
	{"id": "common_bulk_up", "name": "철산공", "accent": Color(0.73, 0.30, 0.18)},
	{"id": "common_swiftness", "name": "유운보", "accent": Color(0.28, 0.55, 0.52)},
	{"id": "common_expansion", "name": "광맥결", "accent": Color(0.48, 0.30, 0.67)},
	{"id": "training_mastery", "name": "연공심법", "accent": Color(0.66, 0.49, 0.20)},
	{"id": "perk_boost_charge", "name": "축기결", "accent": Color(0.25, 0.48, 0.70)},
	{"id": "perk_laurel_shield", "name": "오엽호신", "accent": Color(0.35, 0.55, 0.30)},
	{"id": "dash_lightweight", "name": "회기보", "accent": Color(0.25, 0.52, 0.66)},
	{"id": "dash_module_control", "name": "수세결", "accent": Color(0.48, 0.30, 0.62)},
	{"id": "dash_jump", "name": "비천보", "accent": Color(0.32, 0.55, 0.38)},
	{"id": "dash_acceleration", "name": "대붕전익", "accent": Color(0.78, 0.28, 0.12)},
	{"id": "dash_amplification", "name": "활주구슬", "accent": Color(0.70, 0.52, 0.18)},
	{"id": "item_luck", "name": "인보결", "accent": Color(0.72, 0.52, 0.18)},
	{"id": "item_cooldown_mastery", "name": "순환결", "accent": Color(0.25, 0.48, 0.68)},
	{"id": "item_gauge_mastery", "name": "기령심법", "accent": Color(0.32, 0.55, 0.36)},
	{"id": "item_caffeine", "name": "연효결", "accent": Color(0.62, 0.27, 0.17)},
	{"id": "item_polish", "name": "개광결", "accent": Color(0.72, 0.62, 0.34)},
	{"id": "item_recycle", "name": "환보결", "accent": Color(0.48, 0.30, 0.58)},
	{"id": "downtown_treasure_map", "name": "천기보도", "accent": Color(0.38, 0.52, 0.30)},
]


class CollectionProbe:
	extends Node2D

	var renderer: Object = null
	var draw_results: Array[bool] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.026, 0.020, 0.015), true)
		draw_results.clear()
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(28.0, 36.0), "공용 무공 18종 · 원형 한지 인장 슬롯", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.95, 0.84, 0.61))
		for index in SPECS.size():
			var spec: Dictionary = SPECS[index]
			var column := index % 5
			var row := index / 5
			var left := 28.0 + float(column) * 230.0
			var top := 76.0 + float(row) * 166.0
			var acquisition_slot := Rect2(Vector2(left, top + 24.0), Vector2(92.0, 92.0))
			var owned_slot := Rect2(Vector2(left + 143.0, top + 52.0), Vector2(36.0, 36.0))
			var accent: Color = spec.get("accent", Color.WHITE)
			CharacterInfoOverlayTextureDrawer.draw_mugong_seal_cell(self, acquisition_slot, CELL_FILL, Color(accent.r, accent.g, accent.b, 0.90), 2.2)
			CharacterInfoOverlayTextureDrawer.draw_mugong_seal_cell(self, owned_slot, CELL_FILL, Color(accent.r, accent.g, accent.b, 0.78), 1.2)
			draw_results.append(renderer.draw_icon(self, str(spec.get("id", "")), acquisition_slot.grow(-6.0), 1.0, true))
			draw_results.append(renderer.draw_icon(self, str(spec.get("id", "")), owned_slot.grow(-2.0), 1.0, true))
			if font != null:
				draw_string(font, Vector2(left, top + 5.0), str(spec.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 19, Color(0.94, 0.84, 0.63))
				var badge := Rect2(left + 29.0, top + 107.0, 44.0, 14.0)
				draw_rect(badge, Color(0.12, 0.075, 0.032, 0.94))
				draw_rect(badge, Color(accent.r, accent.g, accent.b, 0.58), false, 1.0)
				draw_string(font, Vector2(left + 36.0, top + 118.0), "Lv.5", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.98, 0.83, 0.30))
				draw_string(font, Vector2(left + 132.0, top + 108.0), "보유", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.82, 0.72, 0.48))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var renderer := RuntimePerkIconRenderer.new()
	for spec: Dictionary in SPECS:
		var perk_id := str(spec.get("id", ""))
		if not renderer.has_icon(perk_id) or renderer.has_animated_icon(perk_id):
			push_error("Common Mugong should resolve as a static seal before visual QA: %s" % perk_id)
			quit(1)
			return
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("common_mugong_collection_visual_qa: capture skipped under headless display server")
		print("common_mugong_collection_visual_qa: ok")
		quit(0)
		return
	var probe := CollectionProbe.new()
	probe.renderer = renderer
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if probe.draw_results.size() != SPECS.size() * 2 or probe.draw_results.has(false):
		push_error("All 18 common Mugong should draw through round acquisition and owned slots")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save the common Mugong collection visual QA capture")
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	print("common_mugong_collection_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
