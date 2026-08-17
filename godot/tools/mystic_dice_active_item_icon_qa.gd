extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemHudSlotRenderer := preload("res://scripts/hud/active_item_hud_slot_renderer.gd")
const ActiveItemHudVisuals := preload("res://scripts/hud/active_item_hud_visuals.gd")

const VIEW_SIZE := Vector2i(720, 420)
const BACKGROUND := Color(0.035, 0.045, 0.075, 1.0)
const OUTPUT_PATH := "user://mystic_dice_active_item_icon_qa.png"


class QaCanvas:
	extends Node2D

	var item_data: Dictionary = {}
	var slot_renderer: Object
	var visuals: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND)
		draw_rect(Rect2(58.0, 52.0, 604.0, 312.0), Color(0.075, 0.085, 0.13, 1.0))
		draw_rect(Rect2(58.0, 52.0, 604.0, 312.0), Color(0.42, 0.50, 0.72, 0.65), false, 2.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(84.0, 94.0), "ACTIVE ITEM HUD / FATE YUT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23, Color(0.9, 0.93, 1.0))
		draw_string(font, Vector2(84.0, 128.0), "actual slot renderer at compact and standard sizes", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.62, 0.69, 0.86))

		var compact_rect := Rect2(116.0, 166.0, 54.0, 54.0)
		var standard_rect := Rect2(248.0, 154.0, 78.0, 78.0)
		slot_renderer.draw_slot(self, compact_rect, item_data, 1.0, visuals, {}, true, false, "1")
		slot_renderer.draw_slot(self, standard_rect, item_data, 1.35, visuals, {}, false, false, "2")
		draw_string(font, Vector2(94.0, 254.0), "compact", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.82, 0.85, 0.94))
		draw_string(font, Vector2(251.0, 254.0), "standard", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.82, 0.85, 0.94))

		var raw_texture: Texture2D = visuals.get_icon_texture(item_data)
		if raw_texture != null:
			draw_rect(Rect2(425.0, 154.0, 128.0, 128.0), Color(0.02, 0.025, 0.045, 1.0))
			draw_texture_rect(raw_texture, Rect2(441.0, 170.0, 96.0, 96.0), false)
		draw_string(font, Vector2(430.0, 310.0), "icon detail", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.82, 0.85, 0.94))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("mystic_dice_active_item_icon_qa requires a renderer")
		quit(1)
		return
	RenderingServer.set_default_clear_color(BACKGROUND)
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var canvas := QaCanvas.new()
	canvas.item_data = ActiveItemCatalog.new().build_item_by_name("mystic_dice")
	canvas.slot_renderer = ActiveItemHudSlotRenderer.new()
	canvas.visuals = ActiveItemHudVisuals.new()
	canvas.visuals.prewarm_catalog_icons()
	root.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index: int in range(8):
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		push_error("mystic_dice_active_item_icon_qa: viewport capture failed")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	if image.save_png(output_path) != OK:
		push_error("mystic_dice_active_item_icon_qa: save failed")
		quit(1)
		return
	print("mystic_dice_active_item_icon_qa: evidence=%s" % output_path)
	print("mystic_dice_active_item_icon_qa: ok")
	quit(0)
