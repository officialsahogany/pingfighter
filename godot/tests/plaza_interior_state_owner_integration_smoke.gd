extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var view_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_view.gd")
	var scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	var trade_interaction_controller_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_trade_interaction_controller.gd")
	var trade_ui_projection_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_trade_ui_projection.gd")
	var trade_ui_renderer_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_trade_ui_renderer.gd")
	var trade_ui_presenter_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_trade_ui_presenter.gd")
	var draw_primitives_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_draw_primitives.gd")
	var chrome_projection_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_chrome_projection.gd")
	var chrome_renderer_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_chrome_renderer.gd")
	var room_renderer_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_room_renderer.gd")
	var object_renderer_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_object_renderer.gd")
	var coin_aura_renderer_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_coin_trade_aura_renderer.gd")
	var coin_fx_runtime_host_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_coin_trade_fx_runtime_host.gd")
	var click_fx_renderer_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_shop_click_fx_renderer.gd")
	_verify_typed_owners(view_source)
	_verify_manual_mirrors_removed(view_source)
	_verify_runtime_delegation(
		view_source,
		scene_source,
		trade_interaction_controller_source,
		trade_ui_projection_source,
		trade_ui_renderer_source,
		trade_ui_presenter_source,
		draw_primitives_source,
		chrome_projection_source,
		chrome_renderer_source,
		room_renderer_source,
		object_renderer_source,
		coin_aura_renderer_source,
		coin_fx_runtime_host_source,
		click_fx_renderer_source
	)
	if _failures.is_empty():
		print("plaza_interior_state_owner_integration_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_typed_owners(source: String) -> void:
	var owners := {
		"_view_data": "PlazaInteriorViewData",
		"_object_hover_state": "PlazaInteriorObjectHoverState",
		"_object_selection_state": "PlazaInteriorObjectSelectionState",
		"_shop_click_animation": "PlazaShopClickAnimationState",
		"_trade_interaction_controller": "PlazaTradeInteractionController",
		"_trade_feedback_state": "PlazaTradeFeedbackState",
		"_trade_item_icon_cache": "PlazaTradeItemIconCache",
	}
	for field_name in owners:
		var type_name := str(owners[field_name])
		_expect(
			source.find("var %s: %s = %s.new()" % [field_name, type_name, type_name]) >= 0,
			"%s should use its concrete state owner" % field_name
		)
	_expect(
		source.find("var _coin_trade_fx_host: PlazaCoinTradeFxRuntimeHost = null") >= 0,
		"coin trade FX should use its concrete runtime host"
	)


func _verify_manual_mirrors_removed(source: String) -> void:
	for declaration in [
		"var _building_type",
		"var _title",
		"var _subtitle",
		"var _actions",
		"var _last_message",
		"var _npc_name",
		"var _npc_texture",
		"var _room_backdrop_texture",
		"var _object_textures",
		"var _accent",
		"var _save_snapshot",
		"var _player_inventory",
		"var _shop_inventory",
		"var _object_hover:",
		"var _hovered_object_id",
		"var _selected_object_id",
		"var _clicked_object_id",
		"var _panel_open",
		"var _trade_hover_panel",
		"var _trade_hover_index",
		"var _trade_scroll_offsets",
		"var _trade_drag_panel",
		"var _trade_drag_index",
		"var _trade_drag_start",
		"var _trade_drag_pos",
		"var _trade_drag_item",
		"var _trade_confirm_panel",
		"var _trade_confirm_index",
		"var _trade_confirm_item",
		"var _trade_feedbacks",
		"var _last_trade_feedback_signature",
		"var _item_icon_textures",
		"var _pending_shop_click_spec",
		"var _trade_hover_state",
		"var _trade_scroll_state",
		"var _trade_drag_state",
		"var _trade_sell_confirm_state",
		"var _trade_action_dispatcher",
		"var _coin_fx_pulse_value",
		"var _coin_fx_burst_value",
	]:
		_expect(source.find(declaration) < 0, "%s should not remain as mirrored state" % declaration)


func _verify_runtime_delegation(
	view_source: String,
	scene_source: String,
	trade_interaction_controller_source: String,
	trade_ui_projection_source: String,
	trade_ui_renderer_source: String,
	trade_ui_presenter_source: String,
	draw_primitives_source: String,
	chrome_projection_source: String,
	chrome_renderer_source: String,
	room_renderer_source: String,
	object_renderer_source: String,
	coin_aura_renderer_source: String,
	coin_fx_runtime_host_source: String,
	click_fx_renderer_source: String
) -> void:
	for call_site in [
		"_view_data.apply(",
		"PlazaInteriorLayout.hit_test_object(",
		"PlazaInteriorLayout.build_object_specs(",
		"_object_hover_state.advance(",
		"_object_selection_state.open_panel(",
		"_trade_interaction_controller.set_action_callback(",
		"_trade_interaction_controller.update_pointer(",
		"_trade_interaction_controller.update_hover(",
		"_trade_interaction_controller.perform_at(",
		"_trade_interaction_controller.scroll_at(",
		"_trade_interaction_controller.begin_drag(",
		"_trade_interaction_controller.finish_drag(",
		"_trade_interaction_controller.handle_confirm_mouse(",
		"_trade_interaction_controller.confirm_sell(",
		"_trade_feedback_state.record(",
		"_trade_item_icon_cache.prewarm_inventories(",
		"PlazaShopStrewnVisualSpec.get_animation_meta(",
		"PlazaInteriorInputPolicy.resolve(",
		"_coin_trade_fx_host.sync_particles(",
		"_coin_trade_fx_host.is_animating(",
		"_coin_trade_fx_host.build_aura_snapshot(",
		"_coin_trade_fx_host.get_additive_material(",
		"_coin_trade_fx_host.get_aura_material(",
		"_coin_trade_fx_host.get_burst_material(",
		"_coin_trade_fx_host.play_burst(",
		"_coin_trade_fx_host.tear_down(",
		"PlazaTradeUiPresenter.draw(",
		"PlazaInteriorChromeProjection.build_title_snapshot(",
		"PlazaInteriorChromeProjection.build_npc_snapshot(",
		"PlazaInteriorChromeProjection.build_topview_npc_snapshot(",
		"PlazaInteriorChromeProjection.build_speech_bubble_snapshot(",
		"PlazaInteriorChromeProjection.build_object_panel_snapshot(",
		"PlazaInteriorChromeRenderer.draw_title(",
		"PlazaInteriorChromeRenderer.draw_npc(",
		"PlazaInteriorChromeRenderer.draw_topview_npc(",
		"PlazaInteriorChromeRenderer.draw_speech_bubble(",
		"PlazaInteriorChromeRenderer.draw_object_panel(",
		"PlazaInteriorRoomRenderer.draw_room(",
		"PlazaInteriorObjectRenderer.draw_standard_object(",
		"PlazaInteriorObjectRenderer.draw_featured_object(",
		"PlazaInteriorObjectRenderer.draw_strewn_object(",
		"PlazaShopClickFxRenderer.get_texture_key(",
		"PlazaShopClickFxRenderer.draw(",
		"PlazaInteriorDrawPrimitives.draw_text_shadow(",
		"PlazaTradeItemPresentation.is_equipped(",
		"PlazaTradeItemPresentation.get_price_for_panel(",
	]:
		_expect(view_source.find(call_site) >= 0, "%s should be used by the live interior view" % call_site)
	for controller_owner_call in [
		"PlazaInteriorLayout.get_trade_cell_index_at_pos(",
		"PlazaInteriorLayout.get_trade_drop_index_at_pos(",
		"_hover_state.update(",
		"_scroll_state.scroll_rows(",
		"_drag_state.start(",
		"PlazaTradeDropDecision.resolve(",
		"_sell_confirm_state.open(",
		"_action_dispatcher.dispatch_trade(",
		"_action_dispatcher.dispatch_reorder(",
	]:
		_expect(
			trade_interaction_controller_source.find(controller_owner_call) >= 0,
			"trade interaction controller should own %s" % controller_owner_call
		)
	for presenter_owner_call in [
		"PlazaTradeUiProjection.build_root_snapshot(",
		"PlazaTradeUiProjection.build_panel_snapshot(",
		"PlazaTradeUiProjection.build_tooltip_snapshot(",
		"PlazaTradeUiProjection.build_drag_ghost_snapshot(",
		"PlazaTradeUiProjection.build_feedback_snapshots(",
		"PlazaTradeUiProjection.build_sell_confirm_snapshot(",
		"PlazaTradeUiRenderer.draw_root(",
		"PlazaTradeUiRenderer.draw_panel(",
		"PlazaTradeUiRenderer.draw_tooltip(",
		"PlazaTradeUiRenderer.draw_drag_ghost(",
		"PlazaTradeUiRenderer.draw_feedbacks(",
		"PlazaTradeUiRenderer.draw_sell_confirm(",
	]:
		_expect(
			trade_ui_presenter_source.find(presenter_owner_call) >= 0,
			"trade UI presenter should own %s" % presenter_owner_call
		)
	for duplicate_layout in [
		"const SHOP_TRADE_MODAL_RECT := Rect2",
		"const SHOP_TRADE_LEFT_PANEL := Rect2",
		"const SHOP_TRADE_RIGHT_PANEL := Rect2",
		"const SHOP_TRADE_CELL_SIZE := 42.0",
		"const PANEL_RECT := Rect2",
		"const NPC_RECT :=",
		"const SHOP_TOPVIEW_NPC_RECT :=",
		"const TITLE_RECT :=",
		"const GOLD_RECT :=",
		"const PANEL_RECT :=",
		"const SHOP_STREWN_ANIMATION_META :=",
		"const PROCEDURAL_ROOM_NEON_SIGNS :=",
	]:
		_expect(view_source.find(duplicate_layout) < 0, "%s should remain owned by PlazaInteriorLayout" % duplicate_layout)
	for duplicate_input_or_fx in [
		"event is InputEventKey",
		"event is InputEventMouseMotion",
		"key_event.keycode",
		"func _build_coin_trade_particle_material",
		"var _coin_trade_fx_state",
		"var _coin_fx_particles",
		"var _coin_fx_particle_process_material",
		"var _coin_fx_pulse_tween",
		"var _coin_fx_burst_tween",
		"func _prewarm_coin_trade_fx_assets",
		"func _ensure_coin_trade_particles",
		"func _start_coin_trade_pulse_tween",
		"func _play_coin_trade_burst_tween",
		"func _sync_coin_trade_particles",
		"func _get_coin_fx_additive_material",
		"func _get_coin_fx_aura_material",
		"func _get_coin_fx_burst_material",
		"PlazaTradeUiProjection.",
		"PlazaTradeUiRenderer.",
		"var tooltip_size := Vector2(230.0, 148.0)",
		"var visible_ratio := clampf(float(SHOP_TRADE_VISIBLE_CELLS)",
		"var alpha := 1.0 - _smooth_unit(progress)",
		"func _get_shop_item_color",
		"func _format_trade_gold_amount",
		"func _smooth_unit",
		"func _format_trade_item_name",
		"func _format_trade_item_description",
		"func _format_trade_item_rolls",
	]:
		_expect(view_source.find(duplicate_input_or_fx) < 0, "%s should remain outside the live view" % duplicate_input_or_fx)
	for shop_click_state_call in [
		"_shop_click_animation.start_with_spec(",
		"_shop_click_animation.get_pending_object_id(",
		"_shop_click_animation.get_pending_spec(",
		"_shop_click_animation.consume_completed_spec(",
	]:
		_expect(
			view_source.find(shop_click_state_call) >= 0,
			"shop click payload lifecycle should delegate through %s" % shop_click_state_call
		)
	for trade_draw_helper in [
		"func _draw_trade_panel",
		"func _draw_trade_scrollbar",
		"func _draw_trade_tooltip",
		"func _draw_trade_drag_ghost",
		"func _draw_trade_feedbacks",
		"func _draw_trade_sell_confirm",
		"func _draw_trade_item_icon",
		"func _draw_wrapped_text",
	]:
		_expect(view_source.find(trade_draw_helper) < 0, "%s should remain owned outside the live view" % trade_draw_helper)
	for chrome_draw_helper in [
		"func _draw_title_bar",
		"func _draw_npc",
		"func _draw_topview_shopkeeper",
		"func _draw_shopkeeper_speech_bubble",
		"func _draw_npc_placeholder",
		"func _draw_object_panel",
		"func _draw_button",
	]:
		_expect(view_source.find(chrome_draw_helper) < 0, "%s should remain owned outside the live view" % chrome_draw_helper)
	for room_draw_helper in [
		"func _draw_room_background",
		"func _draw_room_backdrop_texture",
		"func _draw_shop_table",
		"func _draw_room_neon_sign",
		"func _draw_wall_neon_props",
		"func _draw_room_clutter",
		"func _draw_table_clutter",
	]:
		_expect(view_source.find(room_draw_helper) < 0, "%s should remain owned outside the live view" % room_draw_helper)
	for object_draw_helper in [
		"func _draw_object(",
		"func _draw_featured_object",
		"func _draw_strewn_object",
		"func _draw_coin_pile_magic_aura",
		"func _draw_coin_fx_shaded_texture",
		"func _draw_coin_fx_texture",
		"func _draw_strewn_trade_label",
		"func _draw_strewn_texture",
		"func _get_strewn_texture_draw_size",
		"func _draw_money_bundle",
		"func _draw_coin_pile(",
		"func _draw_gear_prop",
		"func _draw_wrench_prop",
		"func _draw_data_cube_prop",
		"func _draw_circuit_prop",
		"func _get_strewn_color",
		"func _draw_shop_click_animation_frame",
		"func _draw_object_icon",
		"func _draw_object_texture",
		"func _get_object_texture_draw_size",
		"func _get_object_texture_center_offset",
		"func _get_sheet_frame_rect",
	]:
		_expect(view_source.find(object_draw_helper) < 0, "%s should remain owned outside the live view" % object_draw_helper)
	_expect(
		trade_ui_projection_source.find("PlazaInteriorLayout.get_visible_trade_cell_rect(") >= 0,
		"trade UI projection should own visible cell geometry"
	)
	for renderer_primitive in [
		"canvas.draw_rect(",
		"canvas.draw_circle(",
		"canvas.draw_texture_rect(",
		"PlazaInteriorDrawPrimitives.draw_wrapped_text(",
	]:
		_expect(
			trade_ui_renderer_source.find(renderer_primitive) >= 0,
			"trade UI renderer should own %s" % renderer_primitive
		)
	for shared_primitive in [
		"static func draw_text_shadow(",
		"static func draw_wrapped_text(",
		"static func draw_button(",
	]:
		_expect(
			draw_primitives_source.find(shared_primitive) >= 0,
			"interior draw primitives should own %s" % shared_primitive
		)
	for chrome_projection_owner in [
		"static func build_title_snapshot(",
		"static func build_npc_snapshot(",
		"static func build_topview_npc_snapshot(",
		"static func build_speech_bubble_snapshot(",
		"static func build_object_panel_snapshot(",
	]:
		_expect(
			chrome_projection_source.find(chrome_projection_owner) >= 0,
			"interior chrome projection should own %s" % chrome_projection_owner
		)
	for chrome_renderer_owner in [
		"canvas.draw_rect(",
		"canvas.draw_texture_rect(",
		"canvas.draw_colored_polygon(",
		"PlazaInteriorDrawPrimitives.draw_button(",
	]:
		_expect(
			chrome_renderer_source.find(chrome_renderer_owner) >= 0,
			"interior chrome renderer should own %s" % chrome_renderer_owner
		)
	for room_renderer_owner in [
		"static func draw_room(",
		"static func get_cover_source_rect(",
		"canvas.draw_texture_rect_region(",
		"const PROCEDURAL_ROOM_NEON_SIGNS :=",
	]:
		_expect(
			room_renderer_source.find(room_renderer_owner) >= 0,
			"interior room renderer should own %s" % room_renderer_owner
		)
	for object_renderer_owner in [
		"static func draw_standard_object(",
		"static func draw_featured_object(",
		"static func draw_strewn_object(",
		"PlazaShopStrewnVisualSpec.get_texture_draw_size(",
		"PlazaShopStrewnVisualSpec.get_color(",
		"canvas.draw_set_transform(",
	]:
		_expect(
			object_renderer_source.find(object_renderer_owner) >= 0,
			"interior object renderer should own %s" % object_renderer_owner
		)
	for coin_aura_owner in [
		"ImpactFlareTextureCache.get_glow_texture(",
		"ImpactShockwaveTextureCache.get_full_ring_texture(",
		"canvas.material = draw_material",
		"canvas.material = previous_material",
	]:
		_expect(
			coin_aura_renderer_source.find(coin_aura_owner) >= 0,
			"coin aura renderer should own %s" % coin_aura_owner
		)
	for coin_fx_runtime_owner in [
		"extends Node2D",
		"set_process(false)",
		"func sync_particles(",
		"func play_burst(",
		"func tear_down(",
		"func _exit_tree(",
		"GPUParticles2D.new()",
		"create_tween()",
		"WritheEmberMaterial.build_material(\"shop_coin_trade_aura\")",
		"WritheEmberMaterial.build_material(\"shop_coin_trade_burst\")",
	]:
		_expect(
			coin_fx_runtime_host_source.find(coin_fx_runtime_owner) >= 0,
			"coin trade FX runtime host should own %s" % coin_fx_runtime_owner
		)
	for click_fx_owner in [
		"static func get_texture_key(",
		"static func draw(",
		"PlazaShopStrewnVisualSpec.get_sheet_frame_rect(",
		"canvas.draw_texture_rect_region(",
	]:
		_expect(
			click_fx_renderer_source.find(click_fx_owner) >= 0,
			"shop click FX renderer should own %s" % click_fx_owner
		)
	_expect(
		scene_source.find("PlazaTradeItemPresentation.project_inventory(") >= 0,
		"plaza scene should delegate trade inventory presentation"
	)
	_expect(
		scene_source.find("func _with_shop_icon_paths") < 0,
		"plaza scene should not keep a duplicate trade inventory projector"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
