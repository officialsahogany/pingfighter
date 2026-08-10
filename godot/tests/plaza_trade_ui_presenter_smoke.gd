extends SceneTree

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaTradeInteractionController := preload("res://scripts/plaza/plaza_trade_interaction_controller.gd")
const PlazaTradeItemIconCache := preload("res://scripts/plaza/plaza_trade_item_icon_cache.gd")
const PlazaTradeUiPresenter := preload("res://scripts/plaza/plaza_trade_ui_presenter.gd")

const VIEWPORT_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class RenderProbe:
	extends Node2D

	var interaction := PlazaTradeInteractionController.new()
	var icon_cache := PlazaTradeItemIconCache.new()
	var player_inventory := [{"display_name": "장착품", "shop_sell_price": 120, "equipped": true}]
	var shop_inventory := [{"display_name": "상품", "shop_price": 240, "shop_featured": true}]
	var feedbacks: Array[Dictionary] = [{"action": "sale", "text": "+120G", "age": 0.1, "duration": 0.92}]
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		PlazaTradeUiPresenter.draw(
			self,
			ThemeDB.fallback_font,
			player_inventory,
			shop_inventory,
			feedbacks,
			interaction,
			icon_cache,
			1.0
		)

	func show_tooltip() -> void:
		interaction.reset_drag()
		interaction.clear_confirm()
		var cell := PlazaInteriorLayout.get_visible_trade_cell_rect(
			PlazaInteriorLayout.SHOP_TRADE_RIGHT_PANEL,
			0
		).get_center()
		interaction.update_hover(cell, cell, player_inventory, shop_inventory)

	func show_drag() -> void:
		interaction.clear_confirm()
		var cell := PlazaInteriorLayout.get_visible_trade_cell_rect(
			PlazaInteriorLayout.SHOP_TRADE_RIGHT_PANEL,
			0
		).get_center()
		interaction.begin_drag(cell, cell, player_inventory, shop_inventory)
		interaction.update_pointer(cell + Vector2(30.0, 20.0))

	func show_confirm() -> void:
		interaction.reset_drag()
		var cell := PlazaInteriorLayout.get_visible_trade_cell_rect(
			PlazaInteriorLayout.SHOP_TRADE_LEFT_PANEL,
			0
		).get_center()
		interaction.perform_at(cell, player_inventory, shop_inventory)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_contract()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := RenderProbe.new()
	viewport.add_child(probe)
	probe.show_tooltip()
	await _redraw_probe(probe)
	probe.show_drag()
	await _redraw_probe(probe)
	probe.show_confirm()
	await _redraw_probe(probe)
	_expect(probe.draw_count >= 3, "presenter should render tooltip, drag, and confirm states")
	if _is_pixel_capture_available():
		var image := viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "presenter should produce a readable viewport image")
		if image != null and not image.is_empty():
			_expect(_count_visible_pixels(image) > 10000, "presenter should paint a substantial modal surface")
	viewport.queue_free()
	if _failures.is_empty():
		print("plaza_trade_ui_presenter_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_trade_ui_presenter.gd")
	var root_index := source.find("PlazaTradeUiRenderer.draw_root(")
	var player_index := source.find("PlazaTradeUiRenderer.draw_panel(")
	var feedback_index := source.find("PlazaTradeUiRenderer.draw_feedbacks(")
	var confirm_index := source.find("PlazaTradeUiRenderer.draw_sell_confirm(")
	var tooltip_index := source.find("PlazaTradeUiRenderer.draw_tooltip(")
	var drag_index := source.find("PlazaTradeUiRenderer.draw_drag_ghost(")
	_expect(root_index >= 0 and root_index < player_index, "presenter should draw the modal root before panels")
	_expect(player_index < feedback_index, "presenter should draw panels before feedback")
	_expect(feedback_index < confirm_index, "presenter should draw feedback before the modal confirmation")
	_expect(confirm_index < tooltip_index and tooltip_index < drag_index, "presenter should preserve confirm/tooltip/drag source order")
	_expect(source.find("if interaction.is_confirm_open():") >= 0, "presenter should branch on confirmation state")
	_expect(source.find("\t\treturn\n\tif not interaction.is_drag_active()") >= 0, "confirmation should suppress tooltip and drag layers")


func _redraw_probe(probe: CanvasItem) -> void:
	probe.queue_redraw()
	await process_frame
	await process_frame


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
