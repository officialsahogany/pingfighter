extends Control

const PlazaCoinTradeFxRuntimeHost := preload("res://scripts/plaza/plaza_coin_trade_fx_runtime_host.gd")
const PlazaInteriorChromeProjection := preload("res://scripts/plaza/plaza_interior_chrome_projection.gd")
const PlazaInteriorChromeRenderer := preload("res://scripts/plaza/plaza_interior_chrome_renderer.gd")
const PlazaInteriorDrawPrimitives := preload("res://scripts/plaza/plaza_interior_draw_primitives.gd")
const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")
const PlazaInteriorInputPolicy := preload("res://scripts/plaza/plaza_interior_input_policy.gd")
const PlazaInteriorObjectHoverState := preload("res://scripts/plaza/plaza_interior_object_hover_state.gd")
const PlazaInteriorObjectRenderer := preload("res://scripts/plaza/plaza_interior_object_renderer.gd")
const PlazaInteriorObjectSelectionState := preload("res://scripts/plaza/plaza_interior_object_selection_state.gd")
const PlazaInteriorRoomRenderer := preload("res://scripts/plaza/plaza_interior_room_renderer.gd")
const PlazaInteriorViewData := preload("res://scripts/plaza/plaza_interior_view_data.gd")
const PlazaShopClickAnimationState := preload("res://scripts/plaza/plaza_shop_click_animation_state.gd")
const PlazaShopClickFxRenderer := preload("res://scripts/plaza/plaza_shop_click_fx_renderer.gd")
const PlazaShopStrewnVisualSpec := preload("res://scripts/plaza/plaza_shop_strewn_visual_spec.gd")
const PlazaTradeFeedbackState := preload("res://scripts/plaza/plaza_trade_feedback_state.gd")
const PlazaTradeInteractionController := preload("res://scripts/plaza/plaza_trade_interaction_controller.gd")
const PlazaTradeItemIconCache := preload("res://scripts/plaza/plaza_trade_item_icon_cache.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")
const PlazaTradeUiPresenter := preload("res://scripts/plaza/plaza_trade_ui_presenter.gd")

const GAME_SIZE := PlazaInteriorLayout.GAME_SIZE
const EXIT_RECT := PlazaInteriorLayout.EXIT_RECT
const SHOP_TRADE_MODAL_RECT := PlazaInteriorLayout.SHOP_TRADE_MODAL_RECT
const PANEL_CONFIRM_RECT := PlazaInteriorLayout.PANEL_CONFIRM_RECT
const PANEL_CANCEL_RECT := PlazaInteriorLayout.PANEL_CANCEL_RECT
const HOVER_SPEED := 10.0
const FLARE_DURATION := 0.42
const SHOP_STREWN_SPECS := [
	{"id": "shop_strewn_coin_pile", "label": "동전 더미", "kind": "coin_pile", "rect": Rect2(Vector2(475.0, 430.0), Vector2(86.0, 50.0)), "rotation": 0.03},
]

var _view_data: PlazaInteriorViewData = PlazaInteriorViewData.new()
var _close_callback: Callable = Callable()
var _action_callback: Callable = Callable()
var _object_specs: Array[Dictionary] = []
var _object_hover_state: PlazaInteriorObjectHoverState = PlazaInteriorObjectHoverState.new()
var _object_selection_state: PlazaInteriorObjectSelectionState = PlazaInteriorObjectSelectionState.new()
var _flare_timer := 0.0
var _time := 0.0
var _shop_click_animation: PlazaShopClickAnimationState = PlazaShopClickAnimationState.new()
var _trade_ui_open := false
var _trade_interaction_controller: PlazaTradeInteractionController = PlazaTradeInteractionController.new()
var _trade_feedback_state: PlazaTradeFeedbackState = PlazaTradeFeedbackState.new()
var _trade_item_icon_cache: PlazaTradeItemIconCache = PlazaTradeItemIconCache.new()
var _coin_trade_fx_host: PlazaCoinTradeFxRuntimeHost = null


func _ready() -> void:
	# Input is routed in via plaza_scene.handle_plaza_input -> handle_input(); this view has
	# no _gui_input of its own. A STOP filter would consume GUI mouse events and starve
	# battle_scene_shell._unhandled_input (the live mouse path), leaving the shop interior
	# un-hoverable / un-clickable. Stay IGNORE so mouse falls through to that chain.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_coin_trade_fx_host()
	set_process(true)


func _exit_tree() -> void:
	if is_instance_valid(_coin_trade_fx_host):
		_coin_trade_fx_host.tear_down()


func configure(data: Dictionary, close_callback: Callable, action_callback: Callable) -> void:
	_close_callback = close_callback
	_action_callback = action_callback
	_trade_interaction_controller.set_action_callback(action_callback)
	_ensure_coin_trade_fx_host()
	update_state(data)
	if is_inside_tree():
		grab_focus()
	else:
		call_deferred("grab_focus")


func update_state(data: Dictionary) -> void:
	_view_data.apply(data)
	_record_trade_feedback(data.get("last_trade_summary", {}))
	_prewarm_trade_item_icons()
	_clamp_trade_scroll_offsets()
	_object_specs = _build_object_specs()
	_object_hover_state.ensure_specs(_object_specs)
	if (
		_object_selection_state.selected_object_id != ""
		and _find_object_spec(_object_selection_state.selected_object_id).is_empty()
	):
		_object_selection_state.cancel_panel()
	queue_redraw()


func handle_input(event: InputEvent) -> bool:
	var game_pos := Vector2.INF
	var inside_trade_modal := false
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		game_pos = _to_game_pos(mouse_button.position)
		inside_trade_modal = SHOP_TRADE_MODAL_RECT.has_point(game_pos)
	var decision := PlazaInteriorInputPolicy.resolve(
		event,
		_trade_ui_open,
		_trade_interaction_controller.is_confirm_open(),
		_object_selection_state.panel_open,
		inside_trade_modal
	)
	_apply_input_decision(decision, event, game_pos)
	return true


func _apply_input_decision(decision: Dictionary, event: InputEvent, game_pos: Vector2) -> void:
	var action: StringName = decision.get("action", PlazaInteriorInputPolicy.ACTION_CONSUME)
	match action:
		PlazaInteriorInputPolicy.ACTION_CLEAR_TRADE_CONFIRM:
			_clear_trade_confirm()
		PlazaInteriorInputPolicy.ACTION_CLOSE_TRADE:
			_trade_ui_open = false
			queue_redraw()
		PlazaInteriorInputPolicy.ACTION_DISMISS_TRADE:
			_trade_ui_open = false
			_reset_trade_drag()
			_clear_trade_confirm()
			queue_redraw()
		PlazaInteriorInputPolicy.ACTION_CLOSE_VIEW:
			_close()
		PlazaInteriorInputPolicy.ACTION_CONFIRM_SELECTED:
			_confirm_selected_object()
		PlazaInteriorInputPolicy.ACTION_OPEN_ACTION_INDEX:
			_open_object_by_action_index(int(decision.get("action_index", -1)))
		PlazaInteriorInputPolicy.ACTION_UPDATE_TRADE_POINTER:
			var mouse_motion := event as InputEventMouseMotion
			if _trade_interaction_controller.update_pointer(mouse_motion.position):
				queue_redraw()
			_update_trade_hover(mouse_motion.position)
		PlazaInteriorInputPolicy.ACTION_UPDATE_OBJECT_HOVER:
			var mouse_motion := event as InputEventMouseMotion
			_set_hovered_object(_get_object_at_local_pos(mouse_motion.position))
		PlazaInteriorInputPolicy.ACTION_TRADE_CONFIRM_MOUSE:
			_handle_trade_confirm_mouse(game_pos, event as InputEventMouseButton)
		PlazaInteriorInputPolicy.ACTION_TRADE_SCROLL:
			_handle_trade_scroll(game_pos, int(decision.get("direction", 0)))
		PlazaInteriorInputPolicy.ACTION_TRADE_AT_POSITION:
			_perform_trade_at_game_pos(game_pos)
		PlazaInteriorInputPolicy.ACTION_BEGIN_TRADE_DRAG:
			var mouse_button := event as InputEventMouseButton
			_begin_trade_drag(game_pos, mouse_button.position)
		PlazaInteriorInputPolicy.ACTION_FINISH_TRADE_DRAG:
			var mouse_button := event as InputEventMouseButton
			_finish_trade_drag(game_pos, mouse_button.position)
		PlazaInteriorInputPolicy.ACTION_LEFT_CLICK:
			_handle_left_click((event as InputEventMouseButton).position)


func get_status() -> Dictionary:
	var coin_fx_status: Dictionary = {}
	if is_instance_valid(_coin_trade_fx_host):
		coin_fx_status = _coin_trade_fx_host.get_status()
	var trade_status := _trade_interaction_controller.get_status(
		_view_data.player_inventory.size(),
		_view_data.shop_inventory.size()
	)
	return {
		"active": true,
		"building_type": _view_data.building_type,
		"object_count": _object_specs.size(),
		"hovered_object_id": _object_hover_state.hovered_object_id,
		"selected_object_id": _object_selection_state.selected_object_id,
		"clicked_object_id": _object_selection_state.clicked_object_id,
		"panel_open": _object_selection_state.panel_open,
		"trade_ui_open": _trade_ui_open,
		"trade_hover_panel": str(trade_status.get("hover_panel", "")),
		"trade_hover_index": int(trade_status.get("hover_index", -1)),
		"trade_player_scroll": int(trade_status.get("player_scroll", 0)),
		"trade_shop_scroll": int(trade_status.get("shop_scroll", 0)),
		"trade_drag_active": bool(trade_status.get("drag_active", false)),
		"trade_confirm_open": bool(trade_status.get("confirm_open", false)),
		"trade_confirm_panel": str(trade_status.get("confirm_panel", "")),
		"trade_confirm_index": int(trade_status.get("confirm_index", -1)),
		"trade_feedback_count": _trade_feedback_state.feedbacks.size(),
		"shop_click_animation_active": _shop_click_animation.is_active(),
		"pending_shop_click_object_id": _shop_click_animation.get_pending_object_id(),
		"coin_trade_fx_particles_ready": bool(coin_fx_status.get("particles_ready", false)),
		"coin_trade_fx_particle_emitting": bool(coin_fx_status.get("particle_emitting", false)),
		"coin_trade_fx_aura_writhe_shader": bool(coin_fx_status.get("aura_writhe_shader", false)),
		"coin_trade_fx_burst_writhe_shader": bool(coin_fx_status.get("burst_writhe_shader", false)),
		"coin_trade_fx_burst_value": float(coin_fx_status.get("burst_value", 0.0)),
		"player_inventory_count": _view_data.player_inventory.size(),
		"shop_inventory_count": _view_data.shop_inventory.size(),
		"room_replaces_plaza": true,
		"object_texture_count": _get_loaded_object_texture_count(),
	}


func hover_object_for_test(object_id: String) -> Dictionary:
	if _find_object_spec(object_id).is_empty():
		_set_hovered_object("")
	else:
		_set_hovered_object(object_id)
	return get_status()


func click_object_for_test(object_id: String) -> Dictionary:
	var spec := _find_object_spec(object_id)
	if spec.is_empty():
		return get_status()
	_activate_object(spec)
	return get_status()


func confirm_selected_object_for_test() -> bool:
	return _confirm_selected_object()


func click_action_for_test(action_index: int) -> bool:
	if not _open_object_by_action_index(action_index):
		return false
	return _confirm_selected_object()


func open_trade_ui_for_test() -> Dictionary:
	_trade_ui_open = true
	_object_selection_state.hide_panel()
	_reset_trade_drag()
	queue_redraw()
	return get_status()


func scroll_trade_panel_for_test(panel: String, direction: int) -> Dictionary:
	_trade_ui_open = true
	var panel_rect := _get_trade_panel_rect(panel)
	if panel_rect.size != Vector2.ZERO:
		_handle_trade_scroll(panel_rect.get_center(), direction)
	return get_status()


func hover_trade_item_for_test(panel: String, index: int) -> Dictionary:
	_trade_ui_open = true
	var pos := _get_trade_cell_center_for_index(panel, index)
	if pos != Vector2.INF:
		_update_trade_hover(pos * _get_game_scale())
	return get_status()


func is_trade_item_equipped_for_test(panel: String, index: int) -> bool:
	return _is_trade_item_equipped(_get_trade_item(panel, index))


func get_trade_item_price_for_test(panel: String, index: int) -> int:
	return _get_trade_item_price_for_panel(panel, _get_trade_item(panel, index))


func drag_trade_item_for_test(from_panel: String, index: int, to_panel: String) -> Dictionary:
	_trade_ui_open = true
	var start := _get_trade_cell_center_for_index(from_panel, index)
	var release_rect := _get_trade_panel_rect(to_panel)
	if start != Vector2.INF and release_rect.size != Vector2.ZERO:
		var scale := _get_game_scale()
		_begin_trade_drag(start, start * scale)
		_finish_trade_drag(release_rect.get_center(), release_rect.get_center() * scale)
	return get_status()


func reorder_trade_item_for_test(panel: String, from_index: int, to_index: int) -> Dictionary:
	_trade_ui_open = true
	var start := _get_trade_cell_center_for_index(panel, from_index)
	var release := _get_trade_cell_center_for_index(panel, to_index)
	if start != Vector2.INF and release != Vector2.INF:
		var scale := _get_game_scale()
		_begin_trade_drag(start, start * scale)
		_finish_trade_drag(release, release * scale)
	return get_status()


func confirm_trade_sell_for_test() -> Dictionary:
	_confirm_trade_sell()
	return get_status()


func _ensure_coin_trade_fx_host() -> void:
	if not is_instance_valid(_coin_trade_fx_host):
		_coin_trade_fx_host = PlazaCoinTradeFxRuntimeHost.new()
		_coin_trade_fx_host.name = "PlazaCoinTradeFxRuntimeHost"
		add_child(_coin_trade_fx_host)
	_coin_trade_fx_host.ensure_ready()


func _sync_coin_trade_fx() -> bool:
	if not is_instance_valid(_coin_trade_fx_host):
		return false
	var coin_spec := _find_object_spec("shop_strewn_coin_pile")
	var object_id := str(coin_spec.get("id", ""))
	var hover := _object_hover_state.get_amount(object_id)
	var clicked_coin := object_id != "" and object_id == _object_selection_state.clicked_object_id
	var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if clicked_coin else 0.0
	_coin_trade_fx_host.sync_particles(
		_view_data.building_type,
		_trade_ui_open,
		coin_spec,
		hover,
		flare,
		_get_game_scale()
	)
	return _coin_trade_fx_host.is_animating(
		_view_data.building_type,
		_trade_ui_open,
		not coin_spec.is_empty(),
		_object_hover_state.is_visible(object_id),
		clicked_coin,
		_flare_timer
	)


func _process(delta: float) -> void:
	var safe_delta: float = max(0.0, delta)
	_time += safe_delta
	_flare_timer = max(0.0, _flare_timer - safe_delta)
	var changed := _flare_timer > 0.0
	if _advance_trade_feedbacks(safe_delta):
		changed = true
	if _shop_click_animation.advance(safe_delta):
		_finish_shop_click_animation()
		changed = true
	elif _shop_click_animation.is_active():
		changed = true
	if _object_hover_state.advance(_object_specs, safe_delta, HOVER_SPEED):
		changed = true
	if _sync_coin_trade_fx():
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var scale := _get_game_scale()
	var font := ThemeDB.fallback_font
	var topview_shop := _is_topview_shop_backdrop()
	var npc_texture_present := _view_data.npc_texture != null
	var npc_texture_size: Vector2 = Vector2.ZERO
	if npc_texture_present:
		npc_texture_size = _view_data.npc_texture.get_size()
	PlazaInteriorRoomRenderer.draw_room(
		self,
		font,
		size,
		scale,
		_time,
		_view_data.building_type,
		_view_data.accent,
		_view_data.room_backdrop_texture
	)
	if topview_shop:
		var topview_npc_snapshot := PlazaInteriorChromeProjection.build_topview_npc_snapshot(
			npc_texture_present,
			npc_texture_size,
			scale
		)
		PlazaInteriorChromeRenderer.draw_topview_npc(self, topview_npc_snapshot, _view_data.npc_texture)
	var title_snapshot := PlazaInteriorChromeProjection.build_title_snapshot(
		_view_data.title,
		_view_data.subtitle,
		int(_view_data.save_snapshot.get("plaza_gold", 0)),
		scale
	)
	PlazaInteriorChromeRenderer.draw_title(self, font, title_snapshot)
	if topview_shop:
		var speech_snapshot := PlazaInteriorChromeProjection.build_speech_bubble_snapshot(_view_data.last_message, scale)
		PlazaInteriorChromeRenderer.draw_speech_bubble(self, font, speech_snapshot)
	else:
		var npc_snapshot := PlazaInteriorChromeProjection.build_npc_snapshot(
			_view_data.npc_name,
			_view_data.last_message,
			_view_data.accent,
			npc_texture_present,
			npc_texture_size,
			scale
		)
		PlazaInteriorChromeRenderer.draw_npc(self, font, npc_snapshot, _view_data.npc_texture)
	_draw_objects(scale)
	if _shop_click_animation.is_active():
		_draw_shop_click_animation(scale)
	if _trade_ui_open:
		_draw_trade_ui(scale)
	if _object_selection_state.panel_open:
		var selected_spec := _find_object_spec(_object_selection_state.selected_object_id)
		var object_panel_snapshot := PlazaInteriorChromeProjection.build_object_panel_snapshot(
			selected_spec,
			_view_data.accent,
			int(_view_data.save_snapshot.get("ap_current", 0)),
			_view_data.last_message,
			scale
		)
		PlazaInteriorChromeRenderer.draw_object_panel(self, font, object_panel_snapshot, scale)


func _draw_objects(scale: float) -> void:
	var font := ThemeDB.fallback_font
	var topview_shop := _is_topview_shop_backdrop()
	for spec in _object_specs:
		var object_id := str(spec.get("id", ""))
		var kind := str(spec.get("kind", "crystal"))
		var role := str(spec.get("role", ""))
		var hover := _object_hover_state.get_amount(object_id)
		var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if object_id == _object_selection_state.clicked_object_id else 0.0
		var texture := _view_data.get_object_texture(kind)
		if role == "strewn":
			var aura_snapshot: Dictionary = PlazaInteriorObjectRenderer.EMPTY_AURA_SNAPSHOT
			var additive_material: Material = null
			var aura_material: ShaderMaterial = null
			var burst_material: ShaderMaterial = null
			if kind == "coin_pile" and is_instance_valid(_coin_trade_fx_host):
				var rect: Rect2 = spec.get("rect", Rect2())
				aura_snapshot = _coin_trade_fx_host.build_aura_snapshot(rect, scale, hover, flare)
				additive_material = _coin_trade_fx_host.get_additive_material()
				aura_material = _coin_trade_fx_host.get_aura_material()
				burst_material = _coin_trade_fx_host.get_burst_material()
			PlazaInteriorObjectRenderer.draw_strewn_object(
				self,
				font,
				spec,
				hover,
				flare,
				_time,
				_view_data.accent,
				scale,
				texture,
				aura_snapshot,
				additive_material,
				aura_material,
				burst_material
			)
			continue
		if topview_shop and role == "featured":
			PlazaInteriorObjectRenderer.draw_featured_object(self, font, spec, hover, flare, _time, scale, texture)
			continue
		var selected := object_id == _object_selection_state.selected_object_id and _object_selection_state.panel_open
		PlazaInteriorObjectRenderer.draw_standard_object(
			self,
			font,
			spec,
			hover,
			flare,
			selected,
			_time,
			_view_data.accent,
			scale,
			texture
		)


func _draw_shop_click_animation(scale: float) -> void:
	if not _shop_click_animation.is_active():
		return
	var rect_value: Variant = _shop_click_animation.get("object_rect")
	var rect: Rect2 = rect_value if rect_value is Rect2 else Rect2()
	var spec := _get_shop_click_animation_spec()
	var texture_key := PlazaShopClickFxRenderer.get_texture_key(spec)
	var animation_texture: Texture2D = null
	if texture_key != "":
		animation_texture = _view_data.get_object_texture(texture_key)
	PlazaShopClickFxRenderer.draw(
		self,
		spec,
		rect,
		_shop_click_animation.get_progress(),
		_shop_click_animation.get_alpha(),
		_shop_click_animation.get_pulse_scale(),
		_time,
		scale,
		animation_texture
	)


func _get_shop_click_animation_spec() -> Dictionary:
	var object_id := str(_shop_click_animation.get("object_id"))
	var spec := _find_object_spec(object_id)
	if spec.is_empty():
		spec = _shop_click_animation.get_pending_spec()
	return spec


func _draw_trade_ui(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	PlazaTradeUiPresenter.draw(
		self,
		font,
		_view_data.player_inventory,
		_view_data.shop_inventory,
		_trade_feedback_state.feedbacks,
		_trade_interaction_controller,
		_trade_item_icon_cache,
		scale
	)


func _get_loaded_object_texture_count() -> int:
	return _view_data.get_loaded_object_texture_count()


func _is_topview_shop_backdrop() -> bool:
	return _view_data.is_topview_shop_backdrop()


func _handle_left_click(local_pos: Vector2) -> void:
	var game_pos := _to_game_pos(local_pos)
	if EXIT_RECT.has_point(game_pos):
		_close()
		return
	if _object_selection_state.panel_open:
		if PANEL_CONFIRM_RECT.has_point(game_pos):
			_confirm_selected_object()
			return
		if PANEL_CANCEL_RECT.has_point(game_pos):
			_object_selection_state.cancel_panel()
			queue_redraw()
			return
	var object_id := _get_object_at_game_pos(game_pos)
	if object_id != "":
		var spec := _find_object_spec(object_id)
		_activate_object(spec)


func _activate_object(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	if str(spec.get("role", "")) == "strewn":
		_start_shop_click_animation(spec)
		return
	_open_object_panel(spec)


func _open_object_panel(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	var object_id := str(spec.get("id", ""))
	if not _object_selection_state.open_panel(object_id):
		return
	_flare_timer = FLARE_DURATION
	_set_hovered_object(object_id)
	queue_redraw()


func _confirm_selected_object() -> bool:
	var spec := _find_object_spec(_object_selection_state.selected_object_id)
	if spec.is_empty():
		return false
	if str(spec.get("role", "")) == "featured":
		var stock_id := str(spec.get("shop_stock_id", ""))
		if stock_id == "" or not _action_callback.is_valid():
			return false
		var result: Variant = _action_callback.call({
			"type": "shop_trade",
			"panel": "shop",
			"stock_id": stock_id,
		})
		if bool(result):
			queue_redraw()
		return bool(result)
	var action_index := int(spec.get("action_index", -1))
	if action_index < 0:
		return false
	if _action_callback.is_valid():
		var result: Variant = _action_callback.call(action_index)
		queue_redraw()
		return bool(result)
	return false


func _open_object_by_action_index(action_index: int) -> bool:
	for spec in _object_specs:
		if int(spec.get("action_index", -1)) == action_index:
			_activate_object(spec)
			return true
	return false


func _start_shop_click_animation(spec: Dictionary) -> void:
	var object_id := str(spec.get("id", ""))
	if not _object_selection_state.start_click(object_id):
		return
	var meta := _get_shop_animation_meta(str(spec.get("kind", "")))
	var duration := float(meta.get("duration", spec.get("anim_duration", PlazaShopClickAnimationState.DEFAULT_DURATION)))
	if not _shop_click_animation.start_with_spec(spec, duration):
		return
	_trade_ui_open = false
	_flare_timer = FLARE_DURATION
	_set_hovered_object(object_id)
	if str(spec.get("kind", "")) == "coin_pile" and is_instance_valid(_coin_trade_fx_host):
		_coin_trade_fx_host.play_burst()
	queue_redraw()


func _finish_shop_click_animation() -> void:
	var spec := _shop_click_animation.consume_completed_spec()
	if spec.is_empty():
		return
	match str(spec.get("role", "")):
		"strewn":
			_trade_ui_open = true
			_object_selection_state.hide_panel()
		_:
			_open_object_panel(spec)
	queue_redraw()


func _update_trade_hover(local_pos: Vector2) -> void:
	if _trade_interaction_controller.update_hover(
		local_pos,
		_to_game_pos(local_pos),
		_view_data.player_inventory,
		_view_data.shop_inventory
	):
		queue_redraw()


func _handle_trade_click(game_pos: Vector2) -> bool:
	return _perform_trade_at_game_pos(game_pos)


func _perform_trade_at_game_pos(game_pos: Vector2) -> bool:
	var changed := _trade_interaction_controller.perform_at(
		game_pos,
		_view_data.player_inventory,
		_view_data.shop_inventory
	)
	if changed:
		_clamp_trade_scroll_offsets()
		queue_redraw()
	return changed


func _handle_trade_scroll(game_pos: Vector2, direction: int) -> bool:
	if not _trade_interaction_controller.scroll_at(
		game_pos,
		direction,
		_view_data.player_inventory,
		_view_data.shop_inventory
	):
		return false
	_update_trade_hover(_trade_interaction_controller.get_hover_local_position())
	queue_redraw()
	return true


func _begin_trade_drag(game_pos: Vector2, local_pos: Vector2) -> bool:
	var started := _trade_interaction_controller.begin_drag(
		game_pos,
		local_pos,
		_view_data.player_inventory,
		_view_data.shop_inventory
	)
	queue_redraw()
	return started


func _finish_trade_drag(game_pos: Vector2, local_pos: Vector2) -> bool:
	if not _trade_interaction_controller.is_drag_active():
		return false
	var changed := _trade_interaction_controller.finish_drag(
		game_pos,
		local_pos,
		_view_data.player_inventory,
		_view_data.shop_inventory
	)
	_clamp_trade_scroll_offsets()
	queue_redraw()
	return changed


func _reset_trade_drag() -> void:
	_trade_interaction_controller.reset_drag()


func _handle_trade_confirm_mouse(game_pos: Vector2, mouse_button: InputEventMouseButton) -> bool:
	var handled := _trade_interaction_controller.handle_confirm_mouse(
		game_pos,
		mouse_button.button_index,
		mouse_button.pressed,
		_view_data.player_inventory,
		_view_data.shop_inventory
	)
	if handled:
		_clamp_trade_scroll_offsets()
		queue_redraw()
	return handled


func _confirm_trade_sell() -> bool:
	if not _trade_interaction_controller.is_confirm_open():
		return false
	var changed := _trade_interaction_controller.confirm_sell(
		_view_data.player_inventory,
		_view_data.shop_inventory
	)
	_clamp_trade_scroll_offsets()
	queue_redraw()
	return changed


func _clear_trade_confirm() -> void:
	_trade_interaction_controller.clear_confirm()
	queue_redraw()


func _get_trade_panel_rect(panel: String) -> Rect2:
	return _trade_interaction_controller.get_panel_rect(panel)


func _get_trade_item(panel: String, index: int) -> Dictionary:
	return _trade_interaction_controller.get_item(
		panel,
		index,
		_view_data.player_inventory,
		_view_data.shop_inventory
	)


func _get_trade_cell_center_for_index(panel: String, index: int) -> Vector2:
	return _trade_interaction_controller.get_cell_center(
		panel,
		index,
		_view_data.player_inventory,
		_view_data.shop_inventory
	)


func _clamp_trade_scroll_offsets() -> void:
	_trade_interaction_controller.clamp_scroll_offsets(
		_view_data.player_inventory.size(),
		_view_data.shop_inventory.size()
	)


func _close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _set_hovered_object(object_id: String) -> void:
	if _object_hover_state.set_hovered(object_id):
		queue_redraw()


func _get_object_at_local_pos(local_pos: Vector2) -> String:
	return _get_object_at_game_pos(_to_game_pos(local_pos))


func _get_object_at_game_pos(game_pos: Vector2) -> String:
	return PlazaInteriorLayout.hit_test_object(_object_specs, game_pos)


func _find_object_spec(object_id: String) -> Dictionary:
	return PlazaInteriorLayout.find_object_spec(_object_specs, object_id)


func _build_object_specs() -> Array[Dictionary]:
	return PlazaInteriorLayout.build_object_specs(
		_view_data.building_type,
		_view_data.actions,
		_view_data.room_backdrop_texture != null,
		SHOP_STREWN_SPECS
	)


func _get_featured_shop_items() -> Array:
	var result: Array = []
	for item_value in _view_data.shop_inventory:
		var item_data := _get_dict(item_value)
		if bool(item_data.get("shop_featured", false)):
			result.append(item_data)
	return result


func _format_shop_item_label(item_data: Dictionary, fallback: String) -> String:
	if item_data.is_empty():
		return fallback
	var name := str(item_data.get("qualified_display_name", item_data.get("display_name", item_data.get("korean_name", item_data.get("name", fallback)))))
	if name.length() > 8:
		name = name.substr(0, 8)
	var price := int(item_data.get("shop_price", 0))
	if price <= 0:
		return name
	return "%s\n%dG" % [name, price]


func _is_trade_item_equipped(item_data: Dictionary) -> bool:
	return PlazaTradeItemPresentation.is_equipped(item_data)


func _get_trade_item_price_for_panel(panel: String, item_data: Dictionary) -> int:
	return PlazaTradeItemPresentation.get_price_for_panel(panel, item_data)


func _record_trade_feedback(summary_value: Variant) -> void:
	_trade_feedback_state.record(summary_value)


func _advance_trade_feedbacks(delta: float) -> bool:
	return _trade_feedback_state.advance(delta)


func _prewarm_trade_item_icons() -> void:
	_trade_item_icon_cache.prewarm_inventories(_view_data.player_inventory, _view_data.shop_inventory)


func _get_shop_animation_meta(kind: String) -> Dictionary:
	return PlazaShopStrewnVisualSpec.get_animation_meta(kind)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func advance_time_for_test(delta: float) -> Dictionary:
	_process(delta)
	return get_status()


func _to_game_pos(local_pos: Vector2) -> Vector2:
	var scale := _get_game_scale()
	if scale <= 0.0:
		return local_pos
	return local_pos / scale


func _get_game_scale() -> float:
	if GAME_SIZE.x <= 0.0 or size.x <= 0.0:
		return 1.0
	return size.x / GAME_SIZE.x


func _draw_text_shadow(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	PlazaInteriorDrawPrimitives.draw_text_shadow(self, font, pos, text, font_size, color)
