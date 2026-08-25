extends SceneTree

const ActiveItemHudLayout := preload("res://scripts/hud/active_item_hud_layout.gd")
const ActiveItemHudRenderer := preload("res://scripts/hud/active_item_hud_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")

const CARD_VIEW_SIZE := Vector2i(2020, 1246)
const SLOT_VIEW_SIZE := Vector2i(760, 900)
const DEFAULT_OUTPUT_DIR := "res://.godot/codex_artifacts/feedback5_training_mugong_tuning"


class TrainingCardCanvas:
	extends Node2D

	var renderer: Object
	var icon_renderer: Object
	var cards: Array[Dictionary] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_VIEW_SIZE)), Color(0.055, 0.045, 0.035, 1.0))
		draw_rect(Rect2(52.0, 46.0, 1916.0, 112.0), Color(0.13, 0.095, 0.055, 1.0))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(92.0, 118.0),
			"피드백5 · 수련 정본 수치 4종",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			38,
			Color(1.0, 0.88, 0.58)
		)
		var rects: Array[Rect2] = [
			Rect2(100.0, 196.0, 860.0, 430.0),
			Rect2(1060.0, 196.0, 860.0, 430.0),
			Rect2(100.0, 696.0, 860.0, 430.0),
			Rect2(1060.0, 696.0, 860.0, 430.0),
		]
		for index: int in range(cards.size()):
			var action := {
				"id": "training_stat:%s" % str(cards[index].get("id", "")),
				"label": str(cards[index].get("name", "")),
				"enabled": true,
				"payload": {"choice": cards[index]},
			}
			renderer.draw_tower_node_card(
				self,
				action,
				rects[index],
				false,
				icon_renderer,
				index
			)


class ActiveSlotCanvas:
	extends Node2D

	var layout: Dictionary = {}
	var renderer: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SLOT_VIEW_SIZE)), Color(0.035, 0.045, 0.075, 1.0))
		draw_rect(Rect2(0.0, 0.0, 760.0, 750.0), Color(0.075, 0.085, 0.12, 1.0))
		draw_rect(Rect2(20.0, 20.0, 720.0, 90.0), Color(0.12, 0.15, 0.21, 0.96))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(42.0, 76.0),
			"수납술 5회 · 기본 3칸 + 5칸 = 액티브 슬롯 8칸",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			25,
			Color(0.78, 0.9, 1.0)
		)
		renderer.draw_slots(self, layout, [], 0, null, null, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("feedback5_training_mugong_tuning_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("feedback5_training_mugong_tuning_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var output_dir := ProjectSettings.globalize_path(DEFAULT_OUTPUT_DIR)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("feedback5 capture directory creation failed: %s" % output_dir)
		quit(1)
		return

	var card_renderer := RuntimePerkOverlayRenderer.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	card_renderer.prewarm_assets()
	icon_renderer.prewarm_assets()
	var catalog := PhysiqueTrainingCatalog.new()
	var cards: Array[Dictionary] = []
	for training_id: String in [
		"physique_paddle_size",
		"physique_dash_recovery",
		"physique_chosik_cooldown",
		"physique_dash_recharge",
	]:
		cards.append(catalog.build_card(training_id, 0))
	var card_viewport := SubViewport.new()
	card_viewport.size = CARD_VIEW_SIZE
	card_viewport.transparent_bg = false
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(card_viewport)
	var card_canvas := TrainingCardCanvas.new()
	card_canvas.renderer = card_renderer
	card_canvas.icon_renderer = icon_renderer
	card_canvas.cards = cards
	card_viewport.add_child(card_canvas)
	var card_path := output_dir.path_join("training_cards_tuned_4_2020x1246.png")
	if not await _save_viewport(card_viewport, card_canvas, CARD_VIEW_SIZE, card_path):
		quit(1)
		return

	var slot_layout: Dictionary = ActiveItemHudLayout.new().build_layout(
		Vector2(SLOT_VIEW_SIZE),
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		760.0,
		0,
		8
	)
	var slot_rects: Array = slot_layout.get("slot_rects", []) as Array
	if slot_rects.size() != 8 or not bool(slot_layout.get("visible", false)):
		push_error("production active-item HUD did not allocate eight visible slots: %s" % slot_layout)
		quit(1)
		return
	var slot_viewport := SubViewport.new()
	slot_viewport.size = SLOT_VIEW_SIZE
	slot_viewport.transparent_bg = false
	slot_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(slot_viewport)
	var slot_canvas := ActiveSlotCanvas.new()
	slot_canvas.layout = slot_layout
	slot_canvas.renderer = ActiveItemHudRenderer.new()
	slot_viewport.add_child(slot_canvas)
	var slot_path := output_dir.path_join("active_item_slots_8_760x900.png")
	if not await _save_viewport(slot_viewport, slot_canvas, SLOT_VIEW_SIZE, slot_path):
		quit(1)
		return

	LanguageSettings.set_test_locale_override("")
	print("feedback5_training_mugong_tuning_visual_qa: cards=철산공2/수세결6/조식심법3/회기보4 slots=8")
	print("feedback5_training_mugong_tuning_visual_qa: evidence=%s" % output_dir)
	print("feedback5_training_mugong_tuning_visual_qa: captures=2")
	print("feedback5_training_mugong_tuning_visual_qa: ok")
	quit(0)


func _save_viewport(
	viewport: SubViewport,
	canvas: Node2D,
	expected_size: Vector2i,
	output_path: String
) -> bool:
	canvas.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = viewport.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty() or image.get_size() != expected_size:
		push_error("feedback5 capture returned an invalid image: %s" % output_path)
		return false
	if image.save_png(output_path) != OK:
		push_error("feedback5 capture save failed: %s" % output_path)
		return false
	print("[Feedback5TrainingMugongVisualQA] %s" % output_path)
	return true
