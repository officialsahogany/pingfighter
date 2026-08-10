extends SceneTree

const PlazaTradeItemIconCache := preload("res://scripts/plaza/plaza_trade_item_icon_cache.gd")
const PlazaTradeUiProjection := preload("res://scripts/plaza/plaza_trade_ui_projection.gd")
const PlazaTradeUiRenderer := preload("res://scripts/plaza/plaza_trade_ui_renderer.gd")

const VIEWPORT_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class RenderProbe:
	extends Node2D

	var icon_cache := PlazaTradeItemIconCache.new()
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		var font := ThemeDB.fallback_font
		var player_items := [{"display_name": "장착품", "shop_sell_price": 120, "equipped": true}]
		var shop_items := [{"display_name": "특가품", "shop_price": 240, "shop_featured": true}]
		PlazaTradeUiRenderer.draw_root(self, font, PlazaTradeUiProjection.build_root_snapshot(1.0))
		PlazaTradeUiRenderer.draw_panel(self, font, PlazaTradeUiProjection.build_panel_snapshot("player", player_items, 0, "player", 0, 1.0), 1.0, icon_cache)
		PlazaTradeUiRenderer.draw_panel(self, font, PlazaTradeUiProjection.build_panel_snapshot("shop", shop_items, 0, "", -1, 1.0), 1.0, icon_cache)
		PlazaTradeUiRenderer.draw_feedbacks(self, font, PlazaTradeUiProjection.build_feedback_snapshots([{"action": "sale", "text": "+120G", "age": 0.1, "duration": 0.92}], 1.0))
		PlazaTradeUiRenderer.draw_tooltip(self, font, PlazaTradeUiProjection.build_tooltip_snapshot("player", player_items[0], Vector2(350.0, 350.0), Vector2(VIEWPORT_SIZE), 1.0), 1.0)
		var drag_snapshot := PlazaTradeUiProjection.build_drag_ghost_snapshot(shop_items[0], Vector2(380.0, 540.0), 1.0)
		PlazaTradeUiRenderer.draw_drag_ghost(self, font, drag_snapshot, shop_items[0], icon_cache)
		PlazaTradeUiRenderer.draw_sell_confirm(self, font, PlazaTradeUiProjection.build_sell_confirm_snapshot(player_items[0], 1.0), 1.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := RenderProbe.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	_expect(probe.draw_count > 0, "trade renderer should receive a live draw callback")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "trade renderer should produce a readable viewport image")
		if image != null and not image.is_empty():
			_expect(_count_visible_pixels(image) > 10000, "trade renderer should paint a substantial modal surface")
	else:
		_expect(PlazaTradeUiProjection.build_root_snapshot(1.0).get("modal_rect", Rect2()).size != Vector2.ZERO, "headless renderer contract should retain modal geometry")
	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_trade_ui_renderer_visual_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _is_pixel_capture_available() -> bool:
	return DisplayServer.get_name().to_lower() != "headless" and not OS.has_feature("headless")


func _count_visible_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
