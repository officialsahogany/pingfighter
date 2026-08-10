extends RefCounted

const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaTradeInteractionController := preload("res://scripts/plaza/plaza_trade_interaction_controller.gd")
const PlazaTradeItemIconCache := preload("res://scripts/plaza/plaza_trade_item_icon_cache.gd")
const PlazaTradeUiProjection := preload("res://scripts/plaza/plaza_trade_ui_projection.gd")
const PlazaTradeUiRenderer := preload("res://scripts/plaza/plaza_trade_ui_renderer.gd")


static func draw(
	canvas: CanvasItem,
	font: Font,
	player_inventory: Array,
	shop_inventory: Array,
	feedbacks: Array[Dictionary],
	interaction: PlazaTradeInteractionController,
	icon_cache: PlazaTradeItemIconCache,
	scale: float
) -> void:
	if canvas == null or font == null or interaction == null or icon_cache == null:
		return
	var root_snapshot := PlazaTradeUiProjection.build_root_snapshot(scale)
	PlazaTradeUiRenderer.draw_root(canvas, font, root_snapshot)
	var hover_panel := interaction.get_hover_panel()
	var hover_index := interaction.get_hover_index()
	var player_snapshot := PlazaTradeUiProjection.build_panel_snapshot(
		"player",
		player_inventory,
		interaction.get_scroll_offset("player", player_inventory.size()),
		hover_panel,
		hover_index,
		scale
	)
	PlazaTradeUiRenderer.draw_panel(canvas, font, player_snapshot, scale, icon_cache)
	var shop_snapshot := PlazaTradeUiProjection.build_panel_snapshot(
		"shop",
		shop_inventory,
		interaction.get_scroll_offset("shop", shop_inventory.size()),
		hover_panel,
		hover_index,
		scale
	)
	PlazaTradeUiRenderer.draw_panel(canvas, font, shop_snapshot, scale, icon_cache)
	var feedback_snapshots := PlazaTradeUiProjection.build_feedback_snapshots(feedbacks, scale)
	PlazaTradeUiRenderer.draw_feedbacks(canvas, font, feedback_snapshots)
	if interaction.is_confirm_open():
		var sell_confirm_snapshot := PlazaTradeUiProjection.build_sell_confirm_snapshot(
			interaction.get_confirm_item(),
			scale
		)
		PlazaTradeUiRenderer.draw_sell_confirm(canvas, font, sell_confirm_snapshot, scale)
		return
	if not interaction.is_drag_active() and interaction.has_hover_item():
		var tooltip_item := interaction.get_item(
			hover_panel,
			hover_index,
			player_inventory,
			shop_inventory
		)
		var tooltip_snapshot := PlazaTradeUiProjection.build_tooltip_snapshot(
			hover_panel,
			tooltip_item,
			_to_game_position(interaction.get_hover_local_position(), scale),
			PlazaInteriorLayout.GAME_SIZE,
			scale
		)
		PlazaTradeUiRenderer.draw_tooltip(canvas, font, tooltip_snapshot, scale)
	var drag_item := interaction.get_drag_item()
	if interaction.is_drag_active() and not drag_item.is_empty():
		var drag_snapshot := PlazaTradeUiProjection.build_drag_ghost_snapshot(
			drag_item,
			interaction.get_drag_position(),
			scale
		)
		PlazaTradeUiRenderer.draw_drag_ghost(
			canvas,
			font,
			drag_snapshot,
			drag_item,
			icon_cache
		)


static func _to_game_position(local_position: Vector2, scale: float) -> Vector2:
	if scale <= 0.0:
		return Vector2.INF
	return local_position / scale
