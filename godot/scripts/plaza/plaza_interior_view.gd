extends Control

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PlazaShopClickAnimationState := preload("res://scripts/plaza/plaza_shop_click_animation_state.gd")
const WritheEmberMaterial := preload("res://scripts/effects/writhe_ember_material.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const NPC_RECT := Rect2(Vector2(26.0, 118.0), Vector2(236.0, 500.0))
const SHOP_TOPVIEW_NPC_RECT := Rect2(Vector2(28.0, 40.0), Vector2(250.0, 520.0))
const TITLE_RECT := Rect2(Vector2(24.0, 20.0), Vector2(330.0, 76.0))
const GOLD_RECT := Rect2(Vector2(610.0, 22.0), Vector2(126.0, 34.0))
const EXIT_RECT := Rect2(Vector2(24.0, 700.0), Vector2(88.0, 30.0))
const SHOP_TRADE_MODAL_RECT := Rect2(Vector2(70.0, 165.0), Vector2(620.0, 420.0))
const SHOP_TRADE_LEFT_PANEL := Rect2(Vector2(90.0, 215.0), Vector2(280.0, 320.0))
const SHOP_TRADE_RIGHT_PANEL := Rect2(Vector2(390.0, 215.0), Vector2(280.0, 320.0))
const SHOP_TRADE_CELL_SIZE := 42.0
const SHOP_TRADE_CELL_GAP := 6.0
const SHOP_TRADE_CELL_START_OFFSET := Vector2(14.0, 38.0)
const SHOP_TRADE_VISIBLE_CELLS := 30
const SHOP_TRADE_COLUMNS := 5
const SHOP_TRADE_DRAG_THRESHOLD := 6.0
const SHOP_TRADE_CONFIRM_RECT := Rect2(Vector2(224.0, 296.0), Vector2(312.0, 146.0))
const SHOP_TRADE_CONFIRM_SELL_RECT := Rect2(Vector2(258.0, 390.0), Vector2(108.0, 32.0))
const SHOP_TRADE_CONFIRM_CANCEL_RECT := Rect2(Vector2(394.0, 390.0), Vector2(108.0, 32.0))
const SHOP_TRADE_FEEDBACK_DURATION := 0.92
const PANEL_RECT := Rect2(Vector2(516.0, 456.0), Vector2(212.0, 186.0))
const PANEL_CONFIRM_RECT := Rect2(Vector2(540.0, 588.0), Vector2(80.0, 32.0))
const PANEL_CANCEL_RECT := Rect2(Vector2(632.0, 588.0), Vector2(70.0, 32.0))
const HOVER_SPEED := 10.0
const FLARE_DURATION := 0.42
const SHOP_STREWN_SPECS := [
	{"id": "shop_strewn_coin_pile", "label": "동전 더미", "kind": "coin_pile", "rect": Rect2(Vector2(475.0, 430.0), Vector2(86.0, 50.0)), "rotation": 0.03},
]
const SHOP_STREWN_ANIMATION_META := {
	"coin_pile": {"texture_key": "coin_pile_anim", "cols": 5, "rows": 5, "frames": 25, "duration": 0.72},
}
# Wall neon word for the procedural (no-backdrop) room, per building. The shop
# uses its own top-view backdrop and never hits this path, so a generic "BUY"
# here used to mislabel every other building (e.g. a "BUY" sign inside the bank).
const PROCEDURAL_ROOM_NEON_SIGNS := {
	"bank": "BANK",
	"gacha": "GACHA",
	"lingpet_store": "PET",
	"blacksmith": "FORGE",
	"tavern": "PUB",
	"academy": "SKILL",
}

var _building_type := ""
var _title := ""
var _subtitle := ""
var _actions: Array[String] = []
var _last_message := ""
var _npc_name := ""
var _npc_texture: Texture2D = null
var _room_backdrop_texture: Texture2D = null
var _object_textures: Dictionary = {}
var _accent := Color(0.0, 0.86, 1.0, 1.0)
var _save_snapshot: Dictionary = {}
var _close_callback: Callable = Callable()
var _action_callback: Callable = Callable()
var _object_specs: Array[Dictionary] = []
var _object_hover: Dictionary = {}
var _hovered_object_id := ""
var _selected_object_id := ""
var _clicked_object_id := ""
var _panel_open := false
var _flare_timer := 0.0
var _time := 0.0
var _shop_click_animation: Object = PlazaShopClickAnimationState.new()
var _pending_shop_click_spec: Dictionary = {}
var _trade_ui_open := false
var _trade_hover_panel := ""
var _trade_hover_index := -1
var _trade_scroll_offsets := {"player": 0, "shop": 0}
var _trade_drag_panel := ""
var _trade_drag_index := -1
var _trade_drag_start := Vector2.ZERO
var _trade_drag_pos := Vector2.ZERO
var _trade_drag_item: Dictionary = {}
var _trade_confirm_panel := ""
var _trade_confirm_index := -1
var _trade_confirm_item: Dictionary = {}
var _trade_feedbacks: Array[Dictionary] = []
var _last_trade_feedback_signature := ""
var _player_inventory: Array = []
var _shop_inventory: Array = []
var _item_icon_textures: Dictionary = {}
var _coin_fx_additive_material: CanvasItemMaterial = null
var _coin_fx_aura_material: ShaderMaterial = null
var _coin_fx_burst_material: ShaderMaterial = null
var _coin_fx_particles: GPUParticles2D = null
var _coin_fx_particle_process_material: ParticleProcessMaterial = null
var _coin_fx_pulse_value := 0.0
var _coin_fx_burst_value := 0.0
var _coin_fx_pulse_tween: Tween = null
var _coin_fx_burst_tween: Tween = null


func _ready() -> void:
	# Input is routed in via plaza_scene.handle_plaza_input -> handle_input(); this view has
	# no _gui_input of its own. A STOP filter would consume GUI mouse events and starve
	# battle_scene_shell._unhandled_input (the live mouse path), leaving the shop interior
	# un-hoverable / un-clickable. Stay IGNORE so mouse falls through to that chain.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_coin_trade_fx_runtime()
	set_process(true)


func configure(data: Dictionary, close_callback: Callable, action_callback: Callable) -> void:
	_close_callback = close_callback
	_action_callback = action_callback
	_ensure_coin_trade_fx_runtime()
	update_state(data)
	if is_inside_tree():
		grab_focus()
	else:
		call_deferred("grab_focus")


func update_state(data: Dictionary) -> void:
	_building_type = str(data.get("building_type", _building_type))
	_title = str(data.get("title", _title))
	_subtitle = str(data.get("subtitle", _subtitle))
	_actions = _get_string_array(data.get("actions", _actions))
	_last_message = str(data.get("last_message", _last_message))
	_npc_name = str(data.get("npc_name", _npc_name))
	var texture_value: Variant = data.get("npc_texture", _npc_texture)
	_npc_texture = texture_value if texture_value is Texture2D else null
	var room_texture_value: Variant = data.get("room_texture", _room_backdrop_texture)
	_room_backdrop_texture = room_texture_value if room_texture_value is Texture2D else null
	var object_textures_value: Variant = data.get("object_textures", _object_textures)
	if object_textures_value is Dictionary:
		_object_textures = (object_textures_value as Dictionary).duplicate(false)
	var accent_value: Variant = data.get("accent_color", _accent)
	_accent = accent_value if accent_value is Color else _accent
	var snapshot_value: Variant = data.get("save_snapshot", _save_snapshot)
	if snapshot_value is Dictionary:
		_save_snapshot = (snapshot_value as Dictionary).duplicate(true)
	_player_inventory = _duplicate_dictionary_array(data.get("player_inventory", _player_inventory))
	_shop_inventory = _duplicate_dictionary_array(data.get("shop_inventory", _shop_inventory))
	_record_trade_feedback(data.get("last_trade_summary", {}))
	_prewarm_trade_item_icons()
	_clamp_trade_scroll_offsets()
	_object_specs = _build_object_specs()
	for spec in _object_specs:
		var object_id := str(spec.get("id", ""))
		if object_id != "" and not _object_hover.has(object_id):
			_object_hover[object_id] = 0.0
	if _selected_object_id != "" and _find_object_spec(_selected_object_id).is_empty():
		_panel_open = false
		_selected_object_id = ""
	queue_redraw()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE:
			if _trade_ui_open:
				if _trade_confirm_panel != "":
					_clear_trade_confirm()
				else:
					_trade_ui_open = false
					queue_redraw()
				return true
			_close()
			return true
		if _trade_ui_open:
			return true
		if _panel_open and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			_confirm_selected_object()
			return true
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			var action_index := int(key_event.keycode - KEY_1)
			_open_object_by_action_index(action_index)
			return true
		return true
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		if _trade_ui_open:
			_trade_drag_pos = mouse_event.position
			_update_trade_hover(mouse_event.position)
			return true
		_set_hovered_object(_get_object_at_local_pos(mouse_event.position))
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if _trade_ui_open:
			var game_pos := _to_game_pos(mouse_button.position)
			if _trade_confirm_panel != "":
				_handle_trade_confirm_mouse(game_pos, mouse_button)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
				_handle_trade_scroll(game_pos, -1)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
				_handle_trade_scroll(game_pos, 1)
			elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
				_perform_trade_at_game_pos(game_pos)
			elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
				if mouse_button.pressed:
					if not SHOP_TRADE_MODAL_RECT.has_point(game_pos):
						_trade_ui_open = false
						_reset_trade_drag()
						_clear_trade_confirm()
						queue_redraw()
					else:
						_begin_trade_drag(game_pos, mouse_button.position)
				else:
					_finish_trade_drag(game_pos, mouse_button.position)
			return true
		if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
			return true
		_handle_left_click(mouse_button.position)
		return true
	return true


func get_status() -> Dictionary:
	return {
		"active": true,
		"building_type": _building_type,
		"object_count": _object_specs.size(),
		"hovered_object_id": _hovered_object_id,
		"selected_object_id": _selected_object_id,
		"clicked_object_id": _clicked_object_id,
		"panel_open": _panel_open,
		"trade_ui_open": _trade_ui_open,
		"trade_hover_panel": _trade_hover_panel,
		"trade_hover_index": _trade_hover_index,
		"trade_player_scroll": int(_trade_scroll_offsets.get("player", 0)),
		"trade_shop_scroll": int(_trade_scroll_offsets.get("shop", 0)),
		"trade_drag_active": _trade_drag_panel != "",
		"trade_confirm_open": _trade_confirm_panel != "",
		"trade_confirm_panel": _trade_confirm_panel,
		"trade_confirm_index": _trade_confirm_index,
		"trade_feedback_count": _trade_feedbacks.size(),
		"shop_click_animation_active": _shop_click_animation.is_active(),
		"pending_shop_click_object_id": str(_pending_shop_click_spec.get("id", "")),
		"coin_trade_fx_particles_ready": _coin_fx_particles != null,
		"coin_trade_fx_particle_emitting": _coin_fx_particles != null and _coin_fx_particles.emitting,
		"coin_trade_fx_aura_writhe_shader": WritheEmberMaterial.is_material_using_shader(_coin_fx_aura_material),
		"coin_trade_fx_burst_writhe_shader": WritheEmberMaterial.is_material_using_shader(_coin_fx_burst_material),
		"coin_trade_fx_burst_value": _coin_fx_burst_value,
		"player_inventory_count": _player_inventory.size(),
		"shop_inventory_count": _shop_inventory.size(),
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
	_panel_open = false
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


func _prewarm_coin_trade_fx_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	WritheEmberMaterial.prewarm()
	_get_coin_fx_additive_material()
	_get_coin_fx_aura_material()
	_get_coin_fx_burst_material()


func _ensure_coin_trade_fx_runtime() -> void:
	_prewarm_coin_trade_fx_assets()
	_ensure_coin_trade_particles()
	if is_inside_tree() and (_coin_fx_pulse_tween == null or not _coin_fx_pulse_tween.is_valid()):
		_start_coin_trade_pulse_tween()


func _ensure_coin_trade_particles() -> void:
	if _coin_fx_particles != null:
		return
	_coin_fx_particle_process_material = _build_coin_trade_particle_material()
	var particles := GPUParticles2D.new()
	particles.name = "CoinTradeSparkParticles"
	particles.amount = 34
	particles.lifetime = 0.92
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.84
	particles.fixed_fps = 60
	particles.local_coords = true
	particles.visibility_rect = Rect2(-130.0, -105.0, 260.0, 210.0)
	particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
	particles.material = _get_coin_fx_additive_material()
	particles.process_material = _coin_fx_particle_process_material
	particles.emitting = false
	particles.z_index = 60
	add_child(particles)
	_coin_fx_particles = particles


func _start_coin_trade_pulse_tween() -> void:
	if not is_inside_tree():
		return
	if _coin_fx_pulse_tween != null and _coin_fx_pulse_tween.is_valid():
		_coin_fx_pulse_tween.kill()
	_coin_fx_pulse_tween = create_tween()
	_coin_fx_pulse_tween.set_loops()
	_coin_fx_pulse_tween.tween_property(self, "_coin_fx_pulse_value", 1.0, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_coin_fx_pulse_tween.tween_property(self, "_coin_fx_pulse_value", 0.0, 0.64).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_coin_trade_burst_tween() -> void:
	_coin_fx_burst_value = 0.35
	if not is_inside_tree():
		return
	if _coin_fx_burst_tween != null and _coin_fx_burst_tween.is_valid():
		_coin_fx_burst_tween.kill()
	_coin_fx_burst_tween = create_tween()
	_coin_fx_burst_tween.tween_property(self, "_coin_fx_burst_value", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_coin_fx_burst_tween.tween_property(self, "_coin_fx_burst_value", 0.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _sync_coin_trade_particles() -> void:
	if _coin_fx_particles == null:
		return
	var spec := _find_object_spec("shop_strewn_coin_pile")
	if _building_type != "shop" or _trade_ui_open or spec.is_empty():
		_coin_fx_particles.emitting = false
		return
	var object_id := str(spec.get("id", ""))
	var hover := float(_object_hover.get(object_id, 0.0))
	var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if object_id == _clicked_object_id else 0.0
	var intensity := clampf(hover * 0.90 + flare * 0.45 + _coin_fx_burst_value * 0.85, 0.0, 1.0)
	if intensity <= 0.03:
		_coin_fx_particles.emitting = false
		return
	var rect: Rect2 = spec.get("rect", Rect2())
	var scale := _get_game_scale()
	_coin_fx_particles.position = rect.get_center() * scale + Vector2(0.0, -5.0) * scale
	_coin_fx_particles.visibility_rect = Rect2(-150.0 * scale, -118.0 * scale, 300.0 * scale, 220.0 * scale)
	_coin_fx_particles.emitting = true
	var mat := _coin_fx_particle_process_material
	if mat != null:
		mat.color = Color(1.0, 0.82, 0.30, 0.24 + intensity * 0.48)
		mat.emission_box_extents = Vector3(maxf(34.0, rect.size.x * 0.48) * scale, maxf(12.0, rect.size.y * 0.22) * scale, 0.0)
		mat.initial_velocity_min = 7.0 + _coin_fx_burst_value * 24.0
		mat.initial_velocity_max = 38.0 + _coin_fx_burst_value * 72.0
		mat.scale_min = 0.022 + _coin_fx_burst_value * 0.010
		mat.scale_max = 0.060 + _coin_fx_burst_value * 0.025


func _is_coin_trade_fx_animating() -> bool:
	if _building_type != "shop" or _trade_ui_open:
		return false
	if _coin_fx_burst_value > 0.01:
		return true
	var spec := _find_object_spec("shop_strewn_coin_pile")
	if spec.is_empty():
		return false
	var object_id := str(spec.get("id", ""))
	return float(_object_hover.get(object_id, 0.0)) > 0.01 or (object_id == _clicked_object_id and _flare_timer > 0.0)


func _build_coin_trade_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 42.0
	mat.gravity = Vector3(0.0, -42.0, 0.0)
	mat.initial_velocity_min = 7.0
	mat.initial_velocity_max = 38.0
	mat.damping_min = 5.0
	mat.damping_max = 26.0
	mat.scale_min = 0.022
	mat.scale_max = 0.060
	mat.color = Color(1.0, 0.82, 0.30, 0.42)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(42.0, 14.0, 0.0)
	return mat


func _get_coin_fx_additive_material() -> CanvasItemMaterial:
	if _coin_fx_additive_material == null:
		_coin_fx_additive_material = CanvasItemMaterial.new()
		_coin_fx_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _coin_fx_additive_material


func _get_coin_fx_aura_material() -> ShaderMaterial:
	if _coin_fx_aura_material == null:
		_coin_fx_aura_material = WritheEmberMaterial.build_material("shop_coin_trade_aura")
	return _coin_fx_aura_material


func _get_coin_fx_burst_material() -> ShaderMaterial:
	if _coin_fx_burst_material == null:
		_coin_fx_burst_material = WritheEmberMaterial.build_material("shop_coin_trade_burst")
	return _coin_fx_burst_material


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
	for spec in _object_specs:
		var object_id := str(spec.get("id", ""))
		var current := float(_object_hover.get(object_id, 0.0))
		var target := 1.0 if object_id == _hovered_object_id else 0.0
		var next := move_toward(current, target, safe_delta * HOVER_SPEED)
		if not is_equal_approx(current, next):
			changed = true
			_object_hover[object_id] = next
	_sync_coin_trade_particles()
	if _is_coin_trade_fx_animating():
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var scale := _get_game_scale()
	_draw_room_background(scale)
	if _is_topview_shop_backdrop():
		_draw_topview_shopkeeper(scale)
	_draw_title_bar(scale)
	if _is_topview_shop_backdrop():
		_draw_shopkeeper_speech_bubble(scale)
	else:
		_draw_npc(scale)
	if _room_backdrop_texture == null:
		_draw_shop_table(scale)
	_draw_objects(scale)
	if _shop_click_animation.is_active():
		_draw_shop_click_animation(scale)
	if _trade_ui_open:
		_draw_trade_ui(scale)
	if _panel_open:
		_draw_object_panel(scale)


func _draw_room_background(scale: float) -> void:
	if _draw_room_backdrop_texture():
		return
	var full_rect := Rect2(Vector2.ZERO, size)
	draw_rect(full_rect, Color(0.006, 0.008, 0.014, 1.0), true)
	for idx in range(16):
		var t := float(idx) / 15.0
		var band := Rect2(Vector2(0.0, t * GAME_SIZE.y) * scale, Vector2(GAME_SIZE.x, GAME_SIZE.y / 15.0 + 2.0) * scale)
		draw_rect(band, Color(0.012 + t * 0.018, 0.010 + t * 0.010, 0.025 + t * 0.026, 1.0), true)
	var pulse := 0.5 + 0.5 * sin(_time * 3.7)
	for idx in range(10):
		var x := 296.0 + float(idx) * 46.0
		var y := 96.0 + float(idx % 3) * 42.0
		draw_line(Vector2(x, y) * scale, Vector2(x + 72.0, y + 122.0) * scale, Color(_accent.r, _accent.g, _accent.b, 0.07 + pulse * 0.03), max(1.0, 1.4 * scale))
	for idx in range(7):
		var panel := Rect2(Vector2(305.0 + float(idx) * 58.0, 70.0 + float(idx % 2) * 28.0) * scale, Vector2(42.0, 82.0) * scale)
		draw_rect(panel, Color(0.015, 0.020, 0.034, 0.84), true)
		draw_rect(panel, Color(0.75, 0.12, 0.95, 0.18), false, max(1.0, 1.0 * scale))
	var floor_rect := Rect2(Vector2(258.0, 464.0) * scale, Vector2(486.0, 226.0) * scale)
	draw_rect(floor_rect, Color(0.028, 0.026, 0.038, 0.98), true)
	for idx in range(9):
		var y := 484.0 + float(idx) * 22.0
		draw_line(Vector2(270.0, y) * scale, Vector2(724.0, y - 18.0) * scale, Color(0.0, 0.80, 0.94, 0.050), max(1.0, 1.0 * scale))
	for idx in range(8):
		var x := 292.0 + float(idx) * 54.0
		draw_line(Vector2(x, 666.0) * scale, Vector2(x + 88.0, 476.0) * scale, Color(1.0, 0.22, 0.92, 0.042), max(1.0, 1.0 * scale))
	_draw_room_neon_sign(scale)
	_draw_wall_neon_props(scale)
	_draw_room_clutter(scale)


func _draw_room_backdrop_texture() -> bool:
	if _room_backdrop_texture == null:
		return false
	var texture_size := _room_backdrop_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return false
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 1.0), true)
	var target_ratio := size.x / size.y
	var source_ratio := texture_size.x / texture_size.y
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	if source_ratio > target_ratio:
		var crop_width := texture_size.y * target_ratio
		source_rect.position.x = (texture_size.x - crop_width) * 0.5
		source_rect.size.x = crop_width
	elif source_ratio < target_ratio:
		var crop_height := texture_size.x / target_ratio
		source_rect.position.y = (texture_size.y - crop_height) * 0.5
		source_rect.size.y = crop_height
	draw_texture_rect_region(_room_backdrop_texture, Rect2(Vector2.ZERO, size), source_rect)
	return true


func _draw_title_bar(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var title_rect := Rect2(TITLE_RECT.position * scale, TITLE_RECT.size * scale)
	draw_rect(title_rect, Color(0.020, 0.016, 0.052, 0.78), true)
	draw_rect(title_rect, Color(0.78, 0.18, 1.0, 0.62), false, max(1.0, 1.2 * scale))
	_draw_text_shadow(font, title_rect.position + Vector2(18.0, 34.0) * scale, "VR " + _title, int(27.0 * scale), Color(0.94, 0.70, 1.0, 1.0))
	if _subtitle != "":
		_draw_text_shadow(font, title_rect.position + Vector2(20.0, 58.0) * scale, _subtitle, int(13.0 * scale), Color(0.88, 0.96, 1.0, 0.82))
	var gold_rect := Rect2(GOLD_RECT.position * scale, GOLD_RECT.size * scale)
	draw_rect(gold_rect, Color(0.014, 0.018, 0.022, 0.82), true)
	draw_rect(gold_rect, Color(1.0, 0.78, 0.24, 0.42), false, max(1.0, 1.0 * scale))
	_draw_text_shadow(font, gold_rect.position + Vector2(24.0, 23.0) * scale, "%dG" % int(_save_snapshot.get("plaza_gold", 0)), int(15.0 * scale), Color(1.0, 0.90, 0.52, 0.96))
	var exit_rect := Rect2(EXIT_RECT.position * scale, EXIT_RECT.size * scale)
	draw_rect(exit_rect, Color(0.040, 0.015, 0.070, 0.86), true)
	draw_rect(exit_rect, Color(0.88, 0.20, 1.0, 0.56), false, max(1.0, 1.0 * scale))
	_draw_text_shadow(font, exit_rect.position + Vector2(20.0, 21.0) * scale, "나가기", int(14.0 * scale), Color(0.96, 0.80, 1.0, 0.96))


func _draw_npc(scale: float) -> void:
	var font := ThemeDB.fallback_font
	var npc_rect := Rect2(NPC_RECT.position * scale, NPC_RECT.size * scale)
	draw_rect(npc_rect, Color(0.006, 0.010, 0.020, 0.92), true)
	draw_rect(npc_rect, Color(_accent.r * 0.10, _accent.g * 0.10, _accent.b * 0.14, 0.44), true)
	draw_rect(npc_rect, Color(0.76, 0.20, 1.0, 0.52), false, max(1.0, 1.4 * scale))
	if _npc_texture != null:
		var tex_size := _npc_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var fit_rect := Rect2((NPC_RECT.position + Vector2(6.0, 10.0)) * scale, (NPC_RECT.size - Vector2(12.0, 72.0)) * scale)
			var fit_scale: float = min(fit_rect.size.x / tex_size.x, fit_rect.size.y / tex_size.y)
			var draw_size := tex_size * fit_scale
			var draw_pos := Vector2(fit_rect.get_center().x - draw_size.x * 0.5, fit_rect.end.y - draw_size.y)
			draw_texture_rect(_npc_texture, Rect2(draw_pos, draw_size), false)
	else:
		_draw_npc_placeholder(scale)
	if font == null:
		return
	_draw_text_shadow(font, (NPC_RECT.position + Vector2(18.0, NPC_RECT.size.y - 40.0)) * scale, _npc_name, int(15.0 * scale), Color(0.94, 0.98, 1.0, 0.95))
	var message := _last_message if _last_message != "" else "필요한 물건이 있으면 테이블의 물건을 골라봐."
	_draw_text_shadow(font, (NPC_RECT.position + Vector2(18.0, NPC_RECT.size.y - 18.0)) * scale, message, int(12.0 * scale), Color(1.0, 0.78, 0.95, 0.88))


func _draw_topview_shopkeeper(scale: float) -> void:
	if _npc_texture == null:
		return
	var tex_size := _npc_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var target_rect := Rect2(SHOP_TOPVIEW_NPC_RECT.position * scale, SHOP_TOPVIEW_NPC_RECT.size * scale)
	var fit_scale: float = min(target_rect.size.x / tex_size.x, target_rect.size.y / tex_size.y)
	var draw_size := tex_size * fit_scale
	var draw_pos := Vector2(target_rect.get_center().x - draw_size.x * 0.5, target_rect.end.y - draw_size.y)
	var npc_draw_rect := Rect2(draw_pos, draw_size)
	draw_texture_rect(_npc_texture, Rect2(npc_draw_rect.position + Vector2(7.0, 8.0) * scale, npc_draw_rect.size), false, Color(0.0, 0.0, 0.0, 0.34))
	draw_texture_rect(_npc_texture, npc_draw_rect, false, Color(0.92, 0.86, 1.0, 0.88))


func _draw_shopkeeper_speech_bubble(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var bubble_rect := Rect2(Vector2(286.0, 204.0) * scale, Vector2(244.0, 72.0) * scale)
	draw_rect(bubble_rect, Color(0.018, 0.012, 0.036, 0.82), true)
	draw_rect(bubble_rect, Color(0.86, 0.18, 1.0, 0.58), false, max(1.0, 1.1 * scale))
	var tail := PackedVector2Array([
		Vector2(286.0, 242.0) * scale,
		Vector2(286.0, 262.0) * scale,
		Vector2(246.0, 258.0) * scale,
	])
	draw_colored_polygon(tail, Color(0.018, 0.012, 0.036, 0.82))
	draw_line(tail[0], tail[2], Color(0.86, 0.18, 1.0, 0.44), max(1.0, 1.0 * scale))
	draw_line(tail[1], tail[2], Color(0.86, 0.18, 1.0, 0.44), max(1.0, 1.0 * scale))
	var message := _last_message if _last_message != "" else "필요한 거 있어?\n좋은 걸로 골라왔지."
	var lines := message.split("\n", false, 2)
	if lines.size() == 1:
		lines = str(lines[0]).split("|", false, 2)
	for idx in range(mini(lines.size(), 2)):
		_draw_text_shadow(
			font,
			bubble_rect.position + Vector2(18.0, 27.0 + float(idx) * 24.0) * scale,
			str(lines[idx]),
			int(15.0 * scale),
			Color(1.0, 0.72, 1.0, 0.96)
		)


func _draw_npc_placeholder(scale: float) -> void:
	var center := NPC_RECT.position + Vector2(NPC_RECT.size.x * 0.5, 216.0)
	draw_circle(center * scale, 42.0 * scale, Color(0.64, 0.68, 0.76, 0.92))
	draw_rect(Rect2((center + Vector2(-46.0, 46.0)) * scale, Vector2(92.0, 150.0) * scale), Color(0.22, 0.22, 0.30, 0.94), true)
	draw_line((center + Vector2(-34.0, 76.0)) * scale, (center + Vector2(-86.0, 126.0)) * scale, Color(0.78, 0.76, 0.86, 0.86), max(1.0, 8.0 * scale))
	draw_line((center + Vector2(34.0, 76.0)) * scale, (center + Vector2(88.0, 120.0)) * scale, Color(0.78, 0.76, 0.86, 0.86), max(1.0, 8.0 * scale))


func _draw_shop_table(scale: float) -> void:
	var table_rect := Rect2(Vector2(292.0, 438.0) * scale, Vector2(438.0, 154.0) * scale)
	draw_rect(table_rect, Color(0.030, 0.022, 0.034, 0.98), true)
	draw_rect(table_rect, Color(0.0, 0.88, 0.92, 0.20), false, max(1.0, 1.5 * scale))
	draw_line(Vector2(308.0, 458.0) * scale, Vector2(710.0, 430.0) * scale, Color(1.0, 0.18, 0.92, 0.28), max(1.0, 1.0 * scale))
	draw_line(Vector2(312.0, 594.0) * scale, Vector2(704.0, 566.0) * scale, Color(0.0, 0.90, 1.0, 0.20), max(1.0, 1.0 * scale))
	_draw_table_clutter(scale)


func _draw_room_neon_sign(scale: float) -> void:
	var label := str(PROCEDURAL_ROOM_NEON_SIGNS.get(_building_type, ""))
	if label == "":
		return
	var sign_rect := Rect2(Vector2(544.0, 108.0) * scale, Vector2(116.0, 54.0) * scale)
	draw_rect(sign_rect, Color(0.018, 0.024, 0.036, 0.92), true)
	draw_rect(sign_rect, Color(1.0, 0.08, 0.80, 0.46), false, max(1.0, 1.4 * scale))
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var font_size := int(23.0 * scale)
	if font_size <= 0:
		return
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var text_pos := Vector2(sign_rect.get_center().x - text_width * 0.5, sign_rect.position.y + 38.0 * scale)
	_draw_text_shadow(font, text_pos, label, font_size, Color(1.0, 0.40, 0.95, 0.94))


func _draw_wall_neon_props(scale: float) -> void:
	var cat_rect := Rect2(Vector2(650.0, 196.0) * scale, Vector2(68.0, 62.0) * scale)
	draw_rect(cat_rect, Color(0.018, 0.018, 0.032, 0.78), true)
	draw_rect(cat_rect, Color(1.0, 0.16, 0.82, 0.34), false, max(1.0, 1.0 * scale))
	var cat_center := Vector2(684.0, 226.0)
	draw_circle(cat_center * scale, 16.0 * scale, Color(1.0, 0.18, 0.86, 0.08))
	draw_arc(cat_center * scale, 16.0 * scale, 0.0, TAU, 32, Color(1.0, 0.28, 0.90, 0.72), max(1.0, 1.3 * scale), true)
	draw_line((cat_center + Vector2(-10.0, -12.0)) * scale, (cat_center + Vector2(-18.0, -24.0)) * scale, Color(1.0, 0.28, 0.90, 0.72), max(1.0, 1.3 * scale))
	draw_line((cat_center + Vector2(10.0, -12.0)) * scale, (cat_center + Vector2(18.0, -24.0)) * scale, Color(1.0, 0.28, 0.90, 0.72), max(1.0, 1.3 * scale))
	draw_circle((cat_center + Vector2(-6.0, -2.0)) * scale, 2.0 * scale, Color(0.0, 0.92, 1.0, 0.90))
	draw_circle((cat_center + Vector2(7.0, -2.0)) * scale, 2.0 * scale, Color(0.0, 0.92, 1.0, 0.90))
	var board_rect := Rect2(Vector2(596.0, 282.0) * scale, Vector2(122.0, 72.0) * scale)
	draw_rect(board_rect, Color(0.016, 0.026, 0.030, 0.70), true)
	draw_rect(board_rect, Color(0.0, 0.88, 1.0, 0.24), false, max(1.0, 1.0 * scale))
	for idx in range(5):
		var y := 296.0 + float(idx) * 10.0
		draw_line(Vector2(610.0, y) * scale, Vector2(700.0 - float(idx % 2) * 18.0, y + 4.0) * scale, Color(0.0, 0.92, 1.0, 0.13), max(1.0, 0.8 * scale))


func _draw_room_clutter(scale: float) -> void:
	for idx in range(22):
		var x := 288.0 + fposmod(float(idx) * 71.0, 438.0)
		var y := 604.0 + fposmod(float(idx) * 37.0, 78.0)
		var color := Color(1.0, 0.72, 0.24, 0.20) if idx % 3 == 0 else Color(0.0, 0.86, 1.0, 0.13)
		if idx % 4 == 0:
			draw_circle(Vector2(x, y) * scale, (3.5 + float(idx % 5)) * scale, color)
			draw_circle(Vector2(x, y) * scale, (2.0 + float(idx % 3)) * scale, Color(0.0, 0.0, 0.0, 0.28))
		else:
			var chip := Rect2(Vector2(x, y) * scale, Vector2(18.0 + float(idx % 5) * 3.0, 8.0 + float(idx % 3) * 3.0) * scale)
			draw_rect(chip, Color(0.018, 0.024, 0.030, 0.72), true)
			draw_rect(chip, color, false, max(1.0, 0.8 * scale))
	for idx in range(7):
		var start := Vector2(312.0 + float(idx) * 58.0, 686.0)
		var end := start + Vector2(44.0 + float(idx % 2) * 30.0, -34.0 - float(idx % 3) * 14.0)
		draw_line(start * scale, end * scale, Color(0.68, 0.16, 0.92, 0.13), max(1.0, 1.2 * scale))


func _draw_table_clutter(scale: float) -> void:
	for idx in range(18):
		var x := 316.0 + fposmod(float(idx) * 49.0, 386.0)
		var y := 470.0 + fposmod(float(idx) * 29.0, 96.0)
		if idx % 5 == 0:
			draw_circle(Vector2(x, y) * scale, 6.0 * scale, Color(1.0, 0.76, 0.22, 0.46))
			draw_circle(Vector2(x, y) * scale, 3.0 * scale, Color(0.25, 0.15, 0.04, 0.46))
		elif idx % 3 == 0:
			var vial := Rect2(Vector2(x, y) * scale, Vector2(8.0, 24.0) * scale)
			draw_rect(vial, Color(0.0, 0.94, 1.0, 0.18), true)
			draw_rect(vial, Color(0.0, 0.94, 1.0, 0.42), false, max(1.0, 0.8 * scale))
		else:
			var card := Rect2(Vector2(x, y) * scale, Vector2(24.0, 16.0) * scale)
			draw_rect(card, Color(0.024, 0.028, 0.040, 0.82), true)
			draw_rect(card, Color(1.0, 0.24, 0.88, 0.22), false, max(1.0, 0.8 * scale))


func _draw_objects(scale: float) -> void:
	for spec in _object_specs:
		_draw_object(spec, scale)


func _draw_object(spec: Dictionary, scale: float) -> void:
	if str(spec.get("role", "")) == "strewn":
		_draw_strewn_object(spec, scale)
		return
	if _is_topview_shop_backdrop() and str(spec.get("role", "")) == "featured":
		_draw_featured_object(spec, scale)
		return
	var font := ThemeDB.fallback_font
	var object_id := str(spec.get("id", ""))
	var rect: Rect2 = spec.get("rect", Rect2())
	var hover := float(_object_hover.get(object_id, 0.0))
	var selected := object_id == _selected_object_id and _panel_open
	var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if object_id == _clicked_object_id else 0.0
	var lift := hover * 12.0 + flare * 10.0
	var draw_rect_game := Rect2(rect.position + Vector2(0.0, -lift), rect.size)
	var center := draw_rect_game.get_center()
	var glow_color := Color(_accent.r, _accent.g, _accent.b, 0.16 + hover * 0.20 + flare * 0.32)
	draw_circle(center * scale, (54.0 + hover * 10.0 + flare * 28.0) * scale, glow_color)
	draw_circle(center * scale, (34.0 + hover * 4.0) * scale, Color(0.0, 0.95, 1.0, 0.15 + hover * 0.12))
	var pedestal := Rect2(Vector2(rect.position.x + 10.0, rect.end.y - 22.0) * scale, Vector2(rect.size.x - 20.0, 26.0) * scale)
	draw_rect(pedestal, Color(0.014, 0.022, 0.030, 0.94), true)
	draw_rect(pedestal, Color(0.0, 0.88, 1.0, 0.28), false, max(1.0, 1.0 * scale))
	_draw_object_icon(str(spec.get("kind", "crystal")), center, hover, flare, scale)
	var ring_color := Color(1.0, 0.36, 0.94, 0.68) if selected else Color(0.0, 0.86, 1.0, 0.34 + hover * 0.34)
	draw_arc(center * scale, (43.0 + hover * 5.0) * scale, -PI * 0.12 + _time, TAU * 0.82 + _time, 42, ring_color, max(1.0, 1.8 * scale), true)
	if font != null:
		var label := str(spec.get("label", ""))
		var label_rect := Rect2(Vector2(rect.position.x - 8.0, rect.end.y + 10.0) * scale, Vector2(rect.size.x + 16.0, 38.0) * scale)
		draw_rect(label_rect, Color(0.012, 0.014, 0.022, 0.78), true)
		draw_rect(label_rect, Color(_accent.r, _accent.g, _accent.b, 0.30), false, max(1.0, 1.0 * scale))
		_draw_text_shadow(font, label_rect.position + Vector2(10.0, 24.0) * scale, label, int(13.0 * scale), Color(0.94, 0.98, 1.0, 0.96))


func _draw_featured_object(spec: Dictionary, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var object_id := str(spec.get("id", ""))
	var rect: Rect2 = spec.get("rect", Rect2())
	var hover := float(_object_hover.get(object_id, 0.0))
	var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if object_id == _clicked_object_id else 0.0
	var center := rect.get_center() + Vector2(0.0, -hover * 8.0 - flare * 7.0)
	var pad_color: Color = spec.get("pad_color", Color(0.0, 0.86, 1.0, 1.0))
	draw_circle(center * scale, (48.0 + hover * 10.0 + flare * 16.0) * scale, Color(pad_color.r, pad_color.g, pad_color.b, 0.18 + hover * 0.18 + flare * 0.24))
	draw_arc(center * scale, (50.0 + hover * 5.0) * scale, _time * 0.9, TAU + _time * 0.9, 48, Color(pad_color.r, pad_color.g, pad_color.b, 0.54 + hover * 0.22), max(1.0, 1.8 * scale), true)
	_draw_object_icon(str(spec.get("kind", "crystal")), center, hover, flare, scale)
	if font != null:
		var label_rect := Rect2(Vector2(rect.position.x - 6.0, rect.end.y + 6.0) * scale, Vector2(rect.size.x + 12.0, 48.0) * scale)
		draw_rect(label_rect, Color(0.0, 0.0, 0.0, 0.72), true)
		draw_rect(label_rect, Color(pad_color.r, pad_color.g, pad_color.b, 0.50), false, max(1.0, 1.0 * scale))
		var label_lines := str(spec.get("label", "")).split("\n", false, 2)
		for line_index in range(mini(label_lines.size(), 2)):
			_draw_text_shadow(
				font,
				label_rect.position + Vector2(10.0, 18.0 + float(line_index) * 18.0) * scale,
				str(label_lines[line_index]),
				int(11.0 * scale),
				Color(0.94, 0.98, 1.0, 0.96)
			)


func _draw_strewn_object(spec: Dictionary, scale: float) -> void:
	var object_id := str(spec.get("id", ""))
	var rect: Rect2 = spec.get("rect", Rect2())
	var hover := float(_object_hover.get(object_id, 0.0))
	var flare := clampf(_flare_timer / FLARE_DURATION, 0.0, 1.0) if object_id == _clicked_object_id else 0.0
	var center := rect.get_center()
	var kind := str(spec.get("kind", "coin_pile"))
	var base_color := _get_strewn_color(kind)
	if kind == "coin_pile":
		_draw_coin_pile_magic_aura(rect, hover, flare, scale)
	else:
		draw_circle(center * scale, (max(rect.size.x, rect.size.y) * (0.50 + hover * 0.26) + flare * 22.0) * scale, Color(base_color.r, base_color.g, base_color.b, 0.10 + hover * 0.26 + flare * 0.22))
	if not _draw_strewn_texture(spec, hover, scale):
		match kind:
			"money_bundle":
				_draw_money_bundle(rect, hover, scale)
			"coin_pile":
				_draw_coin_pile(rect, hover, scale)
			"gear":
				_draw_gear_prop(rect, hover, scale)
			"wrench_tool":
				_draw_wrench_prop(rect, hover, scale)
			"data_cube":
				_draw_data_cube_prop(rect, hover, scale)
			"circuit_gadget":
				_draw_circuit_prop(rect, hover, scale)
			_:
				draw_rect(Rect2(rect.position * scale, rect.size * scale), Color(base_color.r, base_color.g, base_color.b, 0.45 + hover * 0.18), true)
	# Interactive affordance: a rotating ring + a "거래" label so the trade entry
	# reads as clickable instead of blending into the busy backdrop clutter.
	if kind != "coin_pile":
		var ring_radius: float = (max(rect.size.x, rect.size.y) * 0.62 + hover * 8.0 + flare * 10.0) * scale
		var ring_color := Color(1.0, 0.84, 0.34, 0.42 + hover * 0.42 + flare * 0.42)
		draw_arc(center * scale, ring_radius, -PI * 0.1 + _time * 1.1, TAU * 0.84 + _time * 1.1, 48, ring_color, max(1.0, (1.4 + hover * 1.4) * scale), true)
	_draw_strewn_trade_label(spec, rect, hover, scale)


func _draw_coin_pile_magic_aura(rect: Rect2, hover: float, flare: float, scale: float) -> void:
	var energy: float = clampf(hover * 0.95 + flare * 0.42 + _coin_fx_burst_value * 0.92, 0.0, 1.75)
	if energy <= 0.01:
		return
	var center_px: Vector2 = rect.get_center() * scale + Vector2(0.0, 4.0) * scale
	var base_size: float = float(max(rect.size.x, rect.size.y)) * scale
	var pulse: float = _coin_fx_pulse_value
	var burst: float = _coin_fx_burst_value
	var additive := _get_coin_fx_additive_material()
	var aura_material := _get_coin_fx_aura_material()
	var burst_material := _get_coin_fx_burst_material()
	var backplate_size := Vector2(base_size * (2.12 + hover * 0.22 + burst * 0.42), base_size * (1.30 + hover * 0.14 + burst * 0.28))
	var backplate_alpha := clampf(0.10 + hover * 0.26 + flare * 0.10 + burst * 0.18 + pulse * 0.04, 0.0, 0.58)
	_draw_coin_fx_texture(
		ImpactFlareTextureCache.get_glow_texture(),
		Rect2(center_px - backplate_size * 0.5, backplate_size),
		Color(1.0, 0.62, 0.16, backplate_alpha),
		additive
	)
	var ring_size := Vector2(base_size * (1.86 + hover * 0.24 + burst * 0.38), base_size * (0.92 + hover * 0.12 + burst * 0.22))
	_draw_coin_fx_shaded_texture(
		ImpactShockwaveTextureCache.get_full_ring_texture(),
		Rect2(center_px - ring_size * 0.5, ring_size),
		Color(1.0, 0.82, 0.30, clampf(0.16 + hover * 0.34 + burst * 0.22, 0.0, 0.72)),
		aura_material,
		0.80 + energy * 0.34
	)
	var accent_size := ring_size * Vector2(0.78 + pulse * 0.05, 0.62 + pulse * 0.04)
	_draw_coin_fx_shaded_texture(
		ImpactShockwaveTextureCache.get_full_ring_texture(),
		Rect2(center_px - accent_size * 0.5 + Vector2(0.0, -2.0) * scale, accent_size),
		Color(0.22, 0.95, 1.0, clampf(0.06 + hover * 0.14 + burst * 0.18, 0.0, 0.34)),
		aura_material,
		0.62 + energy * 0.24
	)
	if burst > 0.01:
		var burst_size := Vector2(base_size * (1.36 + burst * 0.86), base_size * (1.02 + burst * 0.42))
		_draw_coin_fx_texture(
			ImpactFlareTextureCache.get_burst_texture(),
			Rect2(center_px - burst_size * 0.5, burst_size),
			Color(1.0, 0.86, 0.32, 0.26 * burst),
			additive
		)
		var burst_ring_size := ring_size * (1.00 + burst * 0.42)
		_draw_coin_fx_shaded_texture(
			ImpactShockwaveTextureCache.get_full_ring_texture(),
			Rect2(center_px - burst_ring_size * 0.5, burst_ring_size),
			Color(1.0, 0.94, 0.56, 0.34 * burst),
			burst_material,
			1.08 + burst * 0.72
		)


func _draw_coin_fx_shaded_texture(texture: Texture2D, rect: Rect2, color: Color, mat: ShaderMaterial, intensity: float) -> void:
	if mat != null:
		mat.set_shader_parameter("elapsed", _time)
		mat.set_shader_parameter("intensity", intensity)
	_draw_coin_fx_texture(texture, rect, color, mat)


func _draw_coin_fx_texture(texture: Texture2D, rect: Rect2, color: Color, mat: Material) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0 or color.a <= 0.0:
		return
	var previous_material: Material = material
	material = mat
	draw_texture_rect(texture, rect, false, color)
	material = previous_material


func _draw_strewn_trade_label(spec: Dictionary, rect: Rect2, hover: float, scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var label := str(spec.get("label", "")).strip_edges()
	var text := "%s  ·  거래" % label if label != "" else "거래"
	var font_size := int(13.0 * scale)
	if font_size <= 0:
		return
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var pad := 12.0 * scale
	var pill_size := Vector2(text_width + pad * 2.0, 26.0 * scale)
	var pill_pos := Vector2(rect.get_center().x * scale - pill_size.x * 0.5, (rect.end.y + 14.0) * scale)
	var pill := Rect2(pill_pos, pill_size)
	draw_rect(pill, Color(0.018, 0.014, 0.030, 0.86), true)
	draw_rect(pill, Color(1.0, 0.82, 0.30, 0.46 + hover * 0.42), false, max(1.0, 1.2 * scale))
	_draw_text_shadow(font, pill_pos + Vector2(pad, 18.0 * scale), text, font_size, Color(1.0, 0.92, 0.60, 0.96))


func _draw_strewn_texture(spec: Dictionary, hover: float, scale: float) -> bool:
	var kind := str(spec.get("kind", ""))
	var texture := _get_object_texture(kind)
	if texture == null:
		return false
	var rect: Rect2 = spec.get("rect", Rect2())
	var center := rect.get_center()
	var draw_size := _get_strewn_texture_draw_size(kind, rect) * (1.0 + hover * 0.08)
	var rotation := float(spec.get("rotation", 0.0)) + hover * 0.035 * sin(_time * 5.4)
	var alpha := 0.94 + hover * 0.06
	var local_rect := Rect2(-draw_size * 0.5 * scale, draw_size * scale)
	draw_set_transform(center * scale, rotation, Vector2.ONE)
	draw_texture_rect(texture, local_rect, false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _get_strewn_texture_draw_size(kind: String, rect: Rect2) -> Vector2:
	match kind:
		"money_bundle":
			return Vector2(92.0, 72.0)
		"coin_pile":
			return Vector2(108.0, 88.0)
		"gear":
			return Vector2(64.0, 64.0)
		"wrench_tool":
			return Vector2(100.0, 66.0)
		"data_cube":
			return Vector2(78.0, 78.0)
		"circuit_gadget":
			return Vector2(94.0, 68.0)
		_:
			return rect.size


func _draw_money_bundle(rect: Rect2, hover: float, scale: float) -> void:
	for idx in range(3):
		var offset := Vector2(float(idx) * 10.0, -float(idx % 2) * 3.0)
		var bill := Rect2((rect.position + offset) * scale, Vector2(38.0, 22.0) * scale)
		draw_rect(bill, Color(0.08, 0.34, 0.22, 0.92), true)
		draw_rect(bill, Color(0.30, 1.0, 0.62, 0.40 + hover * 0.22), false, max(1.0, 1.0 * scale))
		draw_line(bill.position + Vector2(10.0, bill.size.y * 0.5), bill.position + Vector2(bill.size.x - 10.0, bill.size.y * 0.5), Color(0.80, 1.0, 0.70, 0.44), max(1.0, 1.0 * scale))


func _draw_coin_pile(rect: Rect2, hover: float, scale: float) -> void:
	for idx in range(10):
		var x := rect.position.x + fposmod(float(idx) * 17.0, rect.size.x - 8.0)
		var y := rect.position.y + fposmod(float(idx) * 11.0, rect.size.y - 8.0)
		var radius := (4.0 + float(idx % 3)) * scale
		draw_circle(Vector2(x, y) * scale, radius, Color(1.0, 0.70, 0.22, 0.78 + hover * 0.18))
		draw_circle(Vector2(x - 1.0, y - 1.0) * scale, radius * 0.42, Color(1.0, 0.95, 0.50, 0.42))


func _draw_gear_prop(rect: Rect2, hover: float, scale: float) -> void:
	var center := rect.get_center() * scale
	for idx in range(8):
		var angle := _time * (0.7 + hover * 0.8) + float(idx) * TAU / 8.0
		var outer := center + Vector2(cos(angle), sin(angle)) * 24.0 * scale
		var inner := center + Vector2(cos(angle), sin(angle)) * 15.0 * scale
		draw_line(inner, outer, Color(0.78, 0.66, 0.42, 0.82), max(1.0, 3.0 * scale))
	draw_arc(center, 22.0 * scale, 0.0, TAU, 32, Color(0.92, 0.78, 0.44, 0.76 + hover * 0.20), max(1.0, 3.0 * scale), true)
	draw_arc(center, 8.0 * scale, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.62), max(1.0, 3.0 * scale), true)


func _draw_wrench_prop(rect: Rect2, hover: float, scale: float) -> void:
	var start := (rect.position + Vector2(8.0, rect.size.y - 8.0)) * scale
	var end := (rect.end - Vector2(8.0, rect.size.y - 12.0)) * scale
	draw_line(start, end, Color(0.58, 0.72, 0.76, 0.88), max(1.0, 6.0 * scale))
	draw_arc(end, 10.0 * scale, -PI * 0.25, PI * 1.25, 24, Color(0.78, 0.96, 1.0, 0.82 + hover * 0.14), max(1.0, 3.0 * scale), true)
	draw_circle(start, 7.0 * scale, Color(0.38, 0.46, 0.50, 0.86))


func _draw_data_cube_prop(rect: Rect2, hover: float, scale: float) -> void:
	var center := rect.get_center()
	var s := rect.size * 0.58
	var diamond := PackedVector2Array([
		(center + Vector2(0.0, -s.y * 0.55)) * scale,
		(center + Vector2(s.x * 0.55, 0.0)) * scale,
		(center + Vector2(0.0, s.y * 0.55)) * scale,
		(center + Vector2(-s.x * 0.55, 0.0)) * scale,
	])
	draw_colored_polygon(diamond, Color(0.16, 0.78, 1.0, 0.26 + hover * 0.14))
	for idx in range(4):
		draw_line(diamond[idx], diamond[(idx + 1) % 4], Color(0.42, 1.0, 1.0, 0.84), max(1.0, 1.6 * scale))
	draw_line((center + Vector2(-s.x * 0.35, 0.0)) * scale, (center + Vector2(s.x * 0.35, 0.0)) * scale, Color(1.0, 0.24, 0.92, 0.52), max(1.0, 1.0 * scale))


func _draw_circuit_prop(rect: Rect2, hover: float, scale: float) -> void:
	var board := Rect2(rect.position * scale, rect.size * scale)
	draw_rect(board, Color(0.02, 0.11, 0.12, 0.88), true)
	draw_rect(board, Color(0.0, 0.92, 1.0, 0.34 + hover * 0.24), false, max(1.0, 1.0 * scale))
	for idx in range(4):
		var y := board.position.y + (10.0 + float(idx) * 8.0) * scale
		draw_line(Vector2(board.position.x + 8.0 * scale, y), Vector2(board.end.x - 8.0 * scale, y + float(idx % 2) * 5.0 * scale), Color(0.0, 0.94, 0.86, 0.44 + hover * 0.18), max(1.0, 1.0 * scale))
	draw_circle(board.get_center(), 5.0 * scale, Color(1.0, 0.25, 0.88, 0.72))


func _get_strewn_color(kind: String) -> Color:
	match kind:
		"money_bundle":
			return Color(0.42, 1.0, 0.62, 1.0)
		"coin_pile":
			return Color(1.0, 0.75, 0.24, 1.0)
		"gear", "wrench_tool":
			return Color(0.86, 0.76, 0.58, 1.0)
		"data_cube", "circuit_gadget":
			return Color(0.0, 0.90, 1.0, 1.0)
		_:
			return _accent


func _draw_shop_click_animation(scale: float) -> void:
	if not _shop_click_animation.is_active():
		return
	var rect_value: Variant = _shop_click_animation.get("object_rect")
	var rect: Rect2 = rect_value if rect_value is Rect2 else Rect2()
	var spec := _get_shop_click_animation_spec()
	var kind := str(spec.get("kind", ""))
	if kind == "coin_pile":
		_draw_shop_click_animation_frame(rect, _shop_click_animation.get_progress(), _shop_click_animation.get_alpha(), scale)
		return
	var center := rect.get_center() * scale
	var progress: float = _shop_click_animation.get_progress()
	var alpha: float = _shop_click_animation.get_alpha()
	var pulse_scale: float = _shop_click_animation.get_pulse_scale()
	var radius: float = max(rect.size.x, rect.size.y) * (0.62 + progress * 1.1) * pulse_scale * scale
	draw_circle(center, radius, Color(0.0, 0.92, 1.0, 0.08 * alpha))
	draw_arc(center, radius, _time * 2.8, TAU + _time * 2.8, 54, Color(0.0, 0.95, 1.0, 0.72 * alpha), max(1.0, 2.0 * scale), true)
	draw_arc(center, radius * 0.68, -_time * 3.3, TAU - _time * 3.3, 42, Color(1.0, 0.25, 0.92, 0.56 * alpha), max(1.0, 1.6 * scale), true)
	_draw_shop_click_animation_frame(rect, progress, alpha, scale)
	for idx in range(6):
		var angle := progress * TAU * 1.5 + float(idx) * TAU / 6.0
		var sparkle_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.72
		draw_circle(sparkle_pos, (2.0 + 2.0 * (1.0 - progress)) * scale, Color(1.0, 0.86, 0.38, 0.75 * alpha))


func _get_shop_click_animation_spec() -> Dictionary:
	var object_id := str(_shop_click_animation.get("object_id"))
	var spec := _find_object_spec(object_id)
	if spec.is_empty():
		spec = _pending_shop_click_spec
	return spec


func _draw_shop_click_animation_frame(rect: Rect2, progress: float, alpha: float, scale: float) -> bool:
	var spec := _get_shop_click_animation_spec()
	var kind := str(spec.get("kind", ""))
	var meta := _get_shop_animation_meta(kind)
	if meta.is_empty():
		return false
	var texture := _get_object_texture(str(meta.get("texture_key", "")))
	if texture == null:
		return false
	var frame_count := maxi(1, int(meta.get("frames", 1)))
	var cols := maxi(1, int(meta.get("cols", 1)))
	var rows := maxi(1, int(meta.get("rows", 1)))
	var frame_index := clampi(int(floor(progress * float(frame_count))), 0, frame_count - 1)
	var source_rect := _get_sheet_frame_rect(texture, cols, rows, frame_index)
	var center := rect.get_center()
	var draw_size := _get_strewn_texture_draw_size(kind, rect) * (1.36 + sin(progress * PI) * 0.18)
	var draw_rect := Rect2((center - draw_size * 0.5) * scale, draw_size * scale)
	draw_texture_rect_region(texture, draw_rect, source_rect, Color(1.0, 1.0, 1.0, clampf(alpha + 0.12, 0.0, 1.0)))
	return true


func _draw_trade_ui(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, GAME_SIZE * scale), Color(0.0, 0.0, 0.0, 0.70), true)
	var modal := Rect2(SHOP_TRADE_MODAL_RECT.position * scale, SHOP_TRADE_MODAL_RECT.size * scale)
	draw_rect(modal, Color(22.0 / 255.0, 26.0 / 255.0, 40.0 / 255.0, 0.98), true)
	draw_rect(modal, Color(0.88, 0.20, 1.0, 0.72), false, max(1.0, 1.4 * scale))
	_draw_text_shadow(font, modal.position + Vector2(24.0, 34.0) * scale, "아이템 거래", int(20.0 * scale), Color(0.96, 0.78, 1.0, 1.0))
	_draw_text_shadow(font, modal.position + Vector2(438.0, 34.0) * scale, "ESC", int(13.0 * scale), Color(0.78, 0.92, 1.0, 0.78))
	_draw_trade_panel(SHOP_TRADE_LEFT_PANEL, "내 인벤토리 (판매)", _player_inventory, Color(0.0, 0.88, 1.0, 0.82), scale)
	_draw_trade_panel(SHOP_TRADE_RIGHT_PANEL, "상점 물품 (구매)", _shop_inventory, Color(1.0, 0.78, 0.24, 0.82), scale)
	_draw_trade_feedbacks(scale)
	if _trade_confirm_panel != "":
		_draw_trade_sell_confirm(scale)
	else:
		_draw_trade_tooltip(scale)
		_draw_trade_drag_ghost(scale)


func _draw_trade_panel(panel_rect: Rect2, title: String, items: Array, border_color: Color, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var panel := Rect2(panel_rect.position * scale, panel_rect.size * scale)
	var panel_key := _get_trade_panel_key(panel_rect)
	var scroll_offset := _get_trade_scroll_offset(panel_key, items)
	draw_rect(panel, Color(30.0 / 255.0, 36.0 / 255.0, 54.0 / 255.0, 0.94), true)
	draw_rect(panel, border_color, false, max(1.0, 1.2 * scale))
	if font != null:
		_draw_text_shadow(font, panel.position + Vector2(14.0, 24.0) * scale, "%s  %d" % [title, items.size()], int(15.0 * scale), Color(border_color.r, border_color.g, border_color.b, 1.0))
	var start := panel_rect.position + SHOP_TRADE_CELL_START_OFFSET
	for idx in range(SHOP_TRADE_VISIBLE_CELLS):
		var col := idx % 5
		var row := int(float(idx) / 5.0)
		var cell_rect := Rect2(
			(start + Vector2(float(col) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP), float(row) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP))) * scale,
			Vector2(SHOP_TRADE_CELL_SIZE, SHOP_TRADE_CELL_SIZE) * scale
		)
		var item_index := scroll_offset + idx
		var is_hovered := panel_key == _trade_hover_panel and item_index == _trade_hover_index
		draw_rect(cell_rect, Color(0.05, 0.06, 0.09, 0.88), true)
		draw_rect(cell_rect, Color(border_color.r, border_color.g, border_color.b, 0.48 if is_hovered else 0.20), false, max(1.0, (1.8 if is_hovered else 1.0) * scale))
		if item_index < items.size():
			var item_data := _get_dict(items[item_index])
			var item_color := _get_shop_item_color(item_data, border_color)
			draw_circle(cell_rect.get_center(), SHOP_TRADE_CELL_SIZE * 0.28 * scale, Color(item_color.r, item_color.g, item_color.b, 0.44))
			if not _draw_trade_item_icon(item_data, cell_rect, scale):
				draw_circle(cell_rect.get_center(), SHOP_TRADE_CELL_SIZE * 0.17 * scale, Color(item_color.r, item_color.g, item_color.b, 0.76))
			if bool(item_data.get("shop_featured", false)):
				var badge_rect := Rect2(cell_rect.end - Vector2(14.0, 14.0) * scale, Vector2(10.0, 10.0) * scale)
				draw_rect(badge_rect, Color(1.0, 0.78, 0.24, 0.92), true)
			if _is_trade_item_equipped(item_data):
				var equipped_rect := Rect2(cell_rect.position + Vector2(3.0, 3.0) * scale, Vector2(13.0, 13.0) * scale)
				draw_rect(equipped_rect, Color(0.0, 0.92, 1.0, 0.82), true)
				draw_rect(equipped_rect, Color(0.92, 1.0, 1.0, 0.92), false, max(1.0, 0.8 * scale))
				if font != null:
					_draw_text_shadow(font, equipped_rect.position + Vector2(3.0, 10.0) * scale, "E", int(9.0 * scale), Color(0.02, 0.03, 0.05, 0.95))
			if font != null:
				var price := _get_trade_item_price_for_panel(panel_key, item_data)
				if price > 0:
					_draw_text_shadow(font, cell_rect.position + Vector2(4.0, 39.0) * scale, _format_trade_gold_amount(price), int(8.0 * scale), Color(1.0, 0.92, 0.62, 0.88))
	if items.size() > SHOP_TRADE_VISIBLE_CELLS:
		_draw_trade_scrollbar(panel_rect, items.size(), scroll_offset, border_color, scale)


func _draw_trade_scrollbar(panel_rect: Rect2, item_count: int, scroll_offset: int, border_color: Color, scale: float) -> void:
	var track := Rect2((panel_rect.position + Vector2(panel_rect.size.x - 12.0, 48.0)) * scale, Vector2(4.0, 260.0) * scale)
	draw_rect(track, Color(0.0, 0.0, 0.0, 0.38), true)
	var max_offset := maxi(1, item_count - SHOP_TRADE_VISIBLE_CELLS)
	var visible_ratio := clampf(float(SHOP_TRADE_VISIBLE_CELLS) / float(item_count), 0.12, 1.0)
	var handle_h := maxf(24.0 * scale, track.size.y * visible_ratio)
	var travel := maxf(1.0, track.size.y - handle_h)
	var handle_y := track.position.y + travel * float(scroll_offset) / float(max_offset)
	var handle := Rect2(Vector2(track.position.x, handle_y), Vector2(track.size.x, handle_h))
	draw_rect(handle, Color(border_color.r, border_color.g, border_color.b, 0.78), true)


func _draw_trade_tooltip(scale: float) -> void:
	if _trade_drag_panel != "" or _trade_hover_panel == "" or _trade_hover_index < 0:
		return
	var item_data := _get_trade_item(_trade_hover_panel, _trade_hover_index)
	if item_data.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var mouse_game := _to_game_pos(_trade_drag_pos)
	var tooltip_size := Vector2(230.0, 148.0)
	var tooltip_pos := mouse_game + Vector2(18.0, 14.0)
	if tooltip_pos.x + tooltip_size.x > GAME_SIZE.x - 12.0:
		tooltip_pos.x = mouse_game.x - tooltip_size.x - 18.0
	if tooltip_pos.y + tooltip_size.y > GAME_SIZE.y - 12.0:
		tooltip_pos.y = GAME_SIZE.y - tooltip_size.y - 12.0
	tooltip_pos.x = clampf(tooltip_pos.x, 12.0, GAME_SIZE.x - tooltip_size.x - 12.0)
	tooltip_pos.y = clampf(tooltip_pos.y, 12.0, GAME_SIZE.y - tooltip_size.y - 12.0)
	var rect := Rect2(tooltip_pos * scale, tooltip_size * scale)
	var border := Color(0.0, 0.88, 1.0, 0.82) if _trade_hover_panel == "player" else Color(1.0, 0.78, 0.24, 0.86)
	draw_rect(rect, Color(0.018, 0.021, 0.033, 0.96), true)
	draw_rect(rect, border, false, max(1.0, 1.0 * scale))
	var name := _format_trade_item_name(item_data)
	var name_color := _get_shop_item_color(item_data, Color(0.94, 0.98, 1.0, 1.0))
	_draw_text_shadow(font, rect.position + Vector2(12.0, 22.0) * scale, name, int(14.0 * scale), name_color)
	var price := _get_trade_item_price_for_panel(_trade_hover_panel, item_data)
	var price_label := "판매가" if _trade_hover_panel == "player" else "구매가"
	var price_text := "%s %sG" % [price_label, _format_trade_gold_amount(price)] if price > 0 else "%s -" % price_label
	_draw_text_shadow(font, rect.position + Vector2(12.0, 42.0) * scale, price_text, int(12.0 * scale), Color(1.0, 0.91, 0.56, 0.94))
	if bool(item_data.get("shop_featured", false)):
		_draw_text_shadow(font, rect.position + Vector2(118.0, 42.0) * scale, "오늘의 특가", int(11.0 * scale), Color(1.0, 0.50, 0.95, 0.92))
	var desc := _format_trade_item_description(item_data)
	_draw_wrapped_text(font, rect.position + Vector2(12.0, 64.0) * scale, desc, 206.0 * scale, int(10.0 * scale), Color(0.80, 0.90, 0.94, 0.88), 14.0 * scale, 4)
	var roll_text := _format_trade_item_rolls(item_data)
	if roll_text != "":
		_draw_wrapped_text(font, rect.position + Vector2(12.0, 122.0) * scale, roll_text, 206.0 * scale, int(9.0 * scale), Color(0.68, 1.0, 0.88, 0.82), 12.0 * scale, 2)


func _draw_trade_drag_ghost(scale: float) -> void:
	if _trade_drag_panel == "" or _trade_drag_item.is_empty():
		return
	var item_color := _get_shop_item_color(_trade_drag_item, Color(0.9, 0.8, 1.0, 1.0))
	draw_circle(_trade_drag_pos, 26.0 * scale, Color(item_color.r, item_color.g, item_color.b, 0.22))
	var icon_texture := _get_trade_item_icon_texture(_trade_drag_item)
	if icon_texture != null:
		draw_texture_rect(icon_texture, Rect2(_trade_drag_pos - Vector2(18.0, 18.0) * scale, Vector2(36.0, 36.0) * scale), false)
	else:
		draw_circle(_trade_drag_pos, 15.0 * scale, Color(item_color.r, item_color.g, item_color.b, 0.74))
	var font := ThemeDB.fallback_font
	if font != null:
		_draw_text_shadow(font, _trade_drag_pos + Vector2(18.0, -10.0) * scale, _format_trade_item_name(_trade_drag_item), int(10.0 * scale), Color(0.96, 0.98, 1.0, 0.92))


func _draw_trade_feedbacks(scale: float) -> void:
	if _trade_feedbacks.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	for idx in range(_trade_feedbacks.size()):
		var feedback := _get_dict(_trade_feedbacks[idx])
		var duration := maxf(0.001, float(feedback.get("duration", SHOP_TRADE_FEEDBACK_DURATION)))
		var progress := clampf(float(feedback.get("age", 0.0)) / duration, 0.0, 1.0)
		var alpha := 1.0 - _smooth_unit(progress)
		var action := str(feedback.get("action", ""))
		var color := Color(0.58, 1.0, 0.72, alpha) if action == "sale" else Color(1.0, 0.78, 0.32, alpha)
		var pos := (SHOP_TRADE_MODAL_RECT.position + Vector2(310.0, 82.0 - progress * 36.0 - float(idx) * 18.0)) * scale
		_draw_text_shadow(font, pos, str(feedback.get("text", "")), int(16.0 * scale), color)


func _draw_trade_sell_confirm(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var rect := Rect2(SHOP_TRADE_CONFIRM_RECT.position * scale, SHOP_TRADE_CONFIRM_RECT.size * scale)
	draw_rect(rect, Color(0.006, 0.008, 0.014, 0.96), true)
	draw_rect(rect, Color(0.0, 0.88, 1.0, 0.76), false, max(1.0, 1.2 * scale))
	var item_name := _format_trade_item_name(_trade_confirm_item)
	_draw_text_shadow(font, rect.position + Vector2(20.0, 30.0) * scale, "장착 중인 아이템입니다", int(16.0 * scale), Color(0.84, 1.0, 1.0, 0.96))
	_draw_wrapped_text(font, rect.position + Vector2(20.0, 56.0) * scale, "%s을(를) 판매할까요?" % item_name, 272.0 * scale, int(12.0 * scale), Color(0.92, 0.96, 1.0, 0.90), 17.0 * scale, 2)
	_draw_button(SHOP_TRADE_CONFIRM_SELL_RECT, "판매", Color(1.0, 0.68, 0.28, 0.88), scale)
	_draw_button(SHOP_TRADE_CONFIRM_CANCEL_RECT, "취소", Color(0.0, 0.84, 1.0, 0.78), scale)


func _draw_trade_item_icon(item_data: Dictionary, cell_rect: Rect2, scale: float) -> bool:
	var texture := _get_trade_item_icon_texture(item_data)
	if texture == null:
		return false
	var icon_rect := cell_rect.grow(-4.0 * scale)
	draw_texture_rect(texture, icon_rect, false, Color(1.0, 1.0, 1.0, 0.96))
	return true


func _draw_object_icon(kind: String, center: Vector2, hover: float, flare: float, scale: float) -> void:
	if _draw_object_texture(kind, center, hover, flare, scale):
		return
	var alpha := 0.88 + hover * 0.10
	match kind:
		"capsule":
			var body := Rect2((center + Vector2(-18.0, -30.0 - flare * 5.0)) * scale, Vector2(36.0, 60.0) * scale)
			draw_rect(body, Color(0.06, 0.95, 1.0, 0.24 + hover * 0.16), true)
			draw_rect(body, Color(0.0, 0.96, 1.0, alpha), false, max(1.0, 2.0 * scale))
			draw_circle((center + Vector2(0.0, -20.0)) * scale, 18.0 * scale, Color(1.0, 0.30, 0.92, 0.50))
			draw_circle((center + Vector2(0.0, 20.0)) * scale, 18.0 * scale, Color(0.0, 0.88, 1.0, 0.46))
		"sell":
			draw_rect(Rect2((center + Vector2(-30.0, -20.0)) * scale, Vector2(60.0, 40.0) * scale), Color(1.0, 0.72, 0.22, 0.24), true)
			draw_rect(Rect2((center + Vector2(-30.0, -20.0)) * scale, Vector2(60.0, 40.0) * scale), Color(1.0, 0.82, 0.32, alpha), false, max(1.0, 2.0 * scale))
			draw_line((center + Vector2(-20.0, 0.0)) * scale, (center + Vector2(20.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), max(1.0, 3.0 * scale))
			draw_line((center + Vector2(9.0, -12.0)) * scale, (center + Vector2(22.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), max(1.0, 3.0 * scale))
			draw_line((center + Vector2(9.0, 12.0)) * scale, (center + Vector2(22.0, 0.0)) * scale, Color(1.0, 0.88, 0.42, 0.92), max(1.0, 3.0 * scale))
		_:
			draw_circle(center * scale, (25.0 + flare * 5.0) * scale, Color(0.80, 0.22, 1.0, 0.30 + hover * 0.16))
			draw_rect(Rect2((center + Vector2(-15.0, -25.0)) * scale, Vector2(30.0, 50.0) * scale), Color(0.76, 0.20, 1.0, 0.24), true)
			draw_line((center + Vector2(0.0, -30.0)) * scale, (center + Vector2(24.0, 2.0)) * scale, Color(0.92, 0.58, 1.0, alpha), max(1.0, 2.2 * scale))
			draw_line((center + Vector2(24.0, 2.0)) * scale, (center + Vector2(0.0, 32.0)) * scale, Color(0.55, 0.94, 1.0, alpha), max(1.0, 2.2 * scale))
			draw_line((center + Vector2(0.0, 32.0)) * scale, (center + Vector2(-24.0, 2.0)) * scale, Color(0.92, 0.58, 1.0, alpha), max(1.0, 2.2 * scale))
			draw_line((center + Vector2(-24.0, 2.0)) * scale, (center + Vector2(0.0, -30.0)) * scale, Color(0.55, 0.94, 1.0, alpha), max(1.0, 2.2 * scale))


func _draw_object_texture(kind: String, center: Vector2, hover: float, flare: float, scale: float) -> bool:
	var texture := _get_object_texture(kind)
	if texture == null:
		return false
	var draw_size := _get_object_texture_draw_size(kind) * (1.0 + hover * 0.07 + flare * 0.12)
	var center_offset := _get_object_texture_center_offset(kind)
	var rect := Rect2((center + center_offset - draw_size * 0.5) * scale, draw_size * scale)
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.96 + hover * 0.04))
	return true


func _get_object_texture(kind: String) -> Texture2D:
	var texture: Variant = _object_textures.get(kind, null)
	return texture if texture is Texture2D else null


func _get_object_texture_draw_size(kind: String) -> Vector2:
	match kind:
		"capsule":
			return Vector2(74.0, 96.0)
		"sell":
			return Vector2(92.0, 88.0)
		_:
			return Vector2(72.0, 98.0)


func _get_object_texture_center_offset(kind: String) -> Vector2:
	match kind:
		"sell":
			return Vector2(0.0, -2.0)
		_:
			return Vector2(0.0, -4.0)


func _get_loaded_object_texture_count() -> int:
	var count := 0
	for texture in _object_textures.values():
		if texture is Texture2D:
			count += 1
	return count


func _is_topview_shop_backdrop() -> bool:
	return _building_type == "shop" and _room_backdrop_texture != null


func _draw_object_panel(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var spec := _find_object_spec(_selected_object_id)
	if spec.is_empty():
		return
	var panel := Rect2(PANEL_RECT.position * scale, PANEL_RECT.size * scale)
	draw_rect(panel, Color(0.010, 0.014, 0.024, 0.96), true)
	draw_rect(panel, Color(_accent.r * 0.12, _accent.g * 0.12, _accent.b * 0.12, 0.50), true)
	draw_rect(panel, Color(0.0, 0.90, 1.0, 0.48), false, max(1.0, 1.2 * scale))
	_draw_text_shadow(font, panel.position + Vector2(20.0, 32.0) * scale, str(spec.get("label", "")), int(18.0 * scale), Color(0.94, 0.98, 1.0, 0.96))
	_draw_text_shadow(font, panel.position + Vector2(20.0, 62.0) * scale, "선택한 오브젝트의 기능을 실행합니다.", int(12.0 * scale), Color(0.78, 0.92, 0.96, 0.78))
	var ap_text := "AP %d" % int(_save_snapshot.get("ap_current", 0))
	_draw_text_shadow(font, panel.position + Vector2(20.0, 92.0) * scale, ap_text, int(13.0 * scale), Color(0.72, 1.0, 0.88, 0.90))
	if _last_message != "":
		_draw_text_shadow(font, panel.position + Vector2(20.0, 118.0) * scale, _last_message, int(12.0 * scale), Color(1.0, 0.78, 0.58, 0.90))
	_draw_button(PANEL_CONFIRM_RECT, "실행", Color(0.0, 0.84, 1.0, 0.86), scale)
	_draw_button(PANEL_CANCEL_RECT, "취소", Color(1.0, 0.30, 0.90, 0.70), scale)


func _draw_button(rect: Rect2, label: String, color: Color, scale: float) -> void:
	var font := ThemeDB.fallback_font
	var draw_rect_scaled := Rect2(rect.position * scale, rect.size * scale)
	draw_rect(draw_rect_scaled, Color(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.92), true)
	draw_rect(draw_rect_scaled, color, false, max(1.0, 1.0 * scale))
	if font != null:
		_draw_text_shadow(font, draw_rect_scaled.position + Vector2(21.0, 22.0) * scale, label, int(13.0 * scale), Color(0.94, 0.98, 1.0, 0.96))


func _handle_left_click(local_pos: Vector2) -> void:
	var game_pos := _to_game_pos(local_pos)
	if EXIT_RECT.has_point(game_pos):
		_close()
		return
	if _panel_open:
		if PANEL_CONFIRM_RECT.has_point(game_pos):
			_confirm_selected_object()
			return
		if PANEL_CANCEL_RECT.has_point(game_pos):
			_panel_open = false
			_selected_object_id = ""
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
	_selected_object_id = str(spec.get("id", ""))
	_clicked_object_id = _selected_object_id
	_panel_open = true
	_flare_timer = FLARE_DURATION
	_set_hovered_object(_selected_object_id)
	queue_redraw()


func _confirm_selected_object() -> bool:
	var spec := _find_object_spec(_selected_object_id)
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
	_pending_shop_click_spec = spec.duplicate(true)
	_selected_object_id = str(spec.get("id", ""))
	_clicked_object_id = _selected_object_id
	_panel_open = false
	_trade_ui_open = false
	_flare_timer = FLARE_DURATION
	_set_hovered_object(_selected_object_id)
	var meta := _get_shop_animation_meta(str(spec.get("kind", "")))
	var duration := float(meta.get("duration", spec.get("anim_duration", PlazaShopClickAnimationState.DEFAULT_DURATION)))
	_shop_click_animation.start(_selected_object_id, spec.get("rect", Rect2()), duration)
	if str(spec.get("kind", "")) == "coin_pile":
		_play_coin_trade_burst_tween()
	queue_redraw()


func _finish_shop_click_animation() -> void:
	var spec := _pending_shop_click_spec.duplicate(true)
	_pending_shop_click_spec.clear()
	if spec.is_empty():
		return
	match str(spec.get("role", "")):
		"strewn":
			_trade_ui_open = true
			_panel_open = false
		_:
			_open_object_panel(spec)
	queue_redraw()


func _update_trade_hover(local_pos: Vector2) -> void:
	var game_pos := _to_game_pos(local_pos)
	var next_panel := _get_trade_panel_at_game_pos(game_pos)
	var next_index := -1
	if next_panel == "player":
		next_index = _get_trade_cell_index_at_game_pos(SHOP_TRADE_LEFT_PANEL, _player_inventory, game_pos)
	elif next_panel == "shop":
		next_index = _get_trade_cell_index_at_game_pos(SHOP_TRADE_RIGHT_PANEL, _shop_inventory, game_pos)
	if _trade_hover_panel == next_panel and _trade_hover_index == next_index:
		return
	_trade_hover_panel = next_panel
	_trade_hover_index = next_index
	queue_redraw()


func _handle_trade_click(game_pos: Vector2) -> bool:
	return _perform_trade_at_game_pos(game_pos)


func _perform_trade_at_game_pos(game_pos: Vector2) -> bool:
	var panel := _get_trade_panel_at_game_pos(game_pos)
	if panel == "":
		return false
	var index := -1
	if panel == "player":
		index = _get_trade_cell_index_at_game_pos(SHOP_TRADE_LEFT_PANEL, _player_inventory, game_pos)
	elif panel == "shop":
		index = _get_trade_cell_index_at_game_pos(SHOP_TRADE_RIGHT_PANEL, _shop_inventory, game_pos)
	return _perform_trade(panel, index)


func _perform_trade(panel: String, index: int, bypass_confirm: bool = false) -> bool:
	if panel == "" or index < 0:
		return false
	if panel == "player" and not bypass_confirm:
		var item_data := _get_trade_item(panel, index)
		if _is_trade_item_equipped(item_data):
			return _open_trade_sell_confirm(index, item_data)
	if _action_callback.is_valid():
		var result: Variant = _action_callback.call({
			"type": "shop_trade",
			"panel": panel,
			"index": index,
		})
		if bool(result):
			_clamp_trade_scroll_offsets()
			queue_redraw()
		return bool(result)
	return false


func _perform_trade_reorder(panel: String, from_index: int, to_index: int) -> bool:
	if panel == "" or from_index < 0 or to_index < 0 or from_index == to_index:
		return false
	if _action_callback.is_valid():
		var result: Variant = _action_callback.call({
			"type": "shop_trade_reorder",
			"panel": panel,
			"from_index": from_index,
			"to_index": to_index,
		})
		if bool(result):
			_clamp_trade_scroll_offsets()
			queue_redraw()
		return bool(result)
	return false


func _handle_trade_scroll(game_pos: Vector2, direction: int) -> bool:
	var panel := _get_trade_panel_at_game_pos(game_pos)
	if panel == "":
		return false
	var items := _get_trade_items_for_panel(panel)
	if items.size() <= SHOP_TRADE_VISIBLE_CELLS:
		return false
	var current := _get_trade_scroll_offset(panel, items)
	var max_offset := _get_trade_max_scroll_offset(items)
	var next := clampi(current + direction * SHOP_TRADE_COLUMNS, 0, max_offset)
	next = int(floor(float(next) / float(SHOP_TRADE_COLUMNS))) * SHOP_TRADE_COLUMNS
	if next == current:
		return false
	_trade_scroll_offsets[panel] = next
	_update_trade_hover(_trade_drag_pos)
	queue_redraw()
	return true


func _begin_trade_drag(game_pos: Vector2, local_pos: Vector2) -> bool:
	var panel := _get_trade_panel_at_game_pos(game_pos)
	var index := -1
	if panel == "player":
		index = _get_trade_cell_index_at_game_pos(SHOP_TRADE_LEFT_PANEL, _player_inventory, game_pos)
	elif panel == "shop":
		index = _get_trade_cell_index_at_game_pos(SHOP_TRADE_RIGHT_PANEL, _shop_inventory, game_pos)
	if index < 0:
		_reset_trade_drag()
		return false
	_trade_drag_panel = panel
	_trade_drag_index = index
	_trade_drag_start = local_pos
	_trade_drag_pos = local_pos
	_trade_drag_item = _get_trade_item(panel, index)
	queue_redraw()
	return true


func _finish_trade_drag(game_pos: Vector2, local_pos: Vector2) -> bool:
	if _trade_drag_panel == "":
		return false
	var start_panel := _trade_drag_panel
	var start_index := _trade_drag_index
	var dragged_item := _trade_drag_item.duplicate(true)
	var release_panel := _get_trade_panel_at_game_pos(game_pos)
	var distance := local_pos.distance_to(_trade_drag_start)
	_reset_trade_drag()
	if start_index < 0:
		return false
	if release_panel != "" and release_panel != start_panel:
		if start_panel == "player" and _is_trade_item_equipped(dragged_item):
			return _open_trade_sell_confirm(start_index, dragged_item)
		return _perform_trade(start_panel, start_index)
	if release_panel == start_panel and distance > SHOP_TRADE_DRAG_THRESHOLD:
		var to_index := _get_trade_drop_index_at_game_pos(start_panel, game_pos)
		if to_index >= 0:
			return _perform_trade_reorder(start_panel, start_index, to_index)
	if distance <= SHOP_TRADE_DRAG_THRESHOLD:
		return _perform_trade(start_panel, start_index)
	queue_redraw()
	return false


func _reset_trade_drag() -> void:
	_trade_drag_panel = ""
	_trade_drag_index = -1
	_trade_drag_start = Vector2.ZERO
	_trade_drag_pos = Vector2.ZERO
	_trade_drag_item.clear()


func _handle_trade_confirm_mouse(game_pos: Vector2, mouse_button: InputEventMouseButton) -> bool:
	if _trade_confirm_panel == "":
		return false
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
		if SHOP_TRADE_CONFIRM_SELL_RECT.has_point(game_pos):
			_confirm_trade_sell()
		elif SHOP_TRADE_CONFIRM_CANCEL_RECT.has_point(game_pos) or not SHOP_TRADE_CONFIRM_RECT.has_point(game_pos):
			_clear_trade_confirm()
		return true
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		_clear_trade_confirm()
		return true
	return true


func _open_trade_sell_confirm(index: int, item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false
	_trade_confirm_panel = "player"
	_trade_confirm_index = index
	_trade_confirm_item = item_data.duplicate(true)
	_reset_trade_drag()
	queue_redraw()
	return true


func _confirm_trade_sell() -> bool:
	if _trade_confirm_panel == "" or _trade_confirm_index < 0:
		return false
	var panel := _trade_confirm_panel
	var index := _trade_confirm_index
	_clear_trade_confirm()
	return _perform_trade(panel, index, true)


func _clear_trade_confirm() -> void:
	_trade_confirm_panel = ""
	_trade_confirm_index = -1
	_trade_confirm_item.clear()
	queue_redraw()


func _get_trade_cell_index_at_game_pos(panel_rect: Rect2, items: Array, game_pos: Vector2) -> int:
	var start := panel_rect.position + SHOP_TRADE_CELL_START_OFFSET
	var panel_key := _get_trade_panel_key(panel_rect)
	var scroll_offset := _get_trade_scroll_offset(panel_key, items)
	for idx in range(SHOP_TRADE_VISIBLE_CELLS):
		var col := idx % 5
		var row := int(float(idx) / 5.0)
		var cell_rect := Rect2(
			start + Vector2(float(col) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP), float(row) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP)),
			Vector2(SHOP_TRADE_CELL_SIZE, SHOP_TRADE_CELL_SIZE)
		)
		if cell_rect.has_point(game_pos):
			var item_index := scroll_offset + idx
			return item_index if item_index < items.size() else -1
	return -1


func _get_trade_drop_index_at_game_pos(panel: String, game_pos: Vector2) -> int:
	var panel_rect := _get_trade_panel_rect(panel)
	var items := _get_trade_items_for_panel(panel)
	if panel_rect.size == Vector2.ZERO or items.is_empty():
		return -1
	var start := panel_rect.position + SHOP_TRADE_CELL_START_OFFSET
	var scroll_offset := _get_trade_scroll_offset(panel, items)
	for idx in range(SHOP_TRADE_VISIBLE_CELLS):
		var col := idx % SHOP_TRADE_COLUMNS
		var row := int(float(idx) / float(SHOP_TRADE_COLUMNS))
		var cell_rect := Rect2(
			start + Vector2(float(col) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP), float(row) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP)),
			Vector2(SHOP_TRADE_CELL_SIZE, SHOP_TRADE_CELL_SIZE)
		)
		if cell_rect.has_point(game_pos):
			return clampi(scroll_offset + idx, 0, items.size() - 1)
	return -1


func _get_trade_panel_at_game_pos(game_pos: Vector2) -> String:
	if SHOP_TRADE_LEFT_PANEL.has_point(game_pos):
		return "player"
	if SHOP_TRADE_RIGHT_PANEL.has_point(game_pos):
		return "shop"
	return ""


func _get_trade_panel_rect(panel: String) -> Rect2:
	if panel == "player":
		return SHOP_TRADE_LEFT_PANEL
	if panel == "shop":
		return SHOP_TRADE_RIGHT_PANEL
	return Rect2()


func _get_trade_panel_key(panel_rect: Rect2) -> String:
	if panel_rect == SHOP_TRADE_LEFT_PANEL:
		return "player"
	if panel_rect == SHOP_TRADE_RIGHT_PANEL:
		return "shop"
	return ""


func _get_trade_items_for_panel(panel: String) -> Array:
	if panel == "player":
		return _player_inventory
	if panel == "shop":
		return _shop_inventory
	return []


func _get_trade_item(panel: String, index: int) -> Dictionary:
	var items := _get_trade_items_for_panel(panel)
	if index < 0 or index >= items.size():
		return {}
	return _get_dict(items[index])


func _get_trade_cell_center_for_index(panel: String, index: int) -> Vector2:
	var panel_rect := _get_trade_panel_rect(panel)
	var items := _get_trade_items_for_panel(panel)
	if panel_rect.size == Vector2.ZERO or index < 0 or index >= items.size():
		return Vector2.INF
	var scroll_offset := _get_trade_scroll_offset(panel, items)
	if index < scroll_offset or index >= scroll_offset + SHOP_TRADE_VISIBLE_CELLS:
		return Vector2.INF
	var visible_index := index - scroll_offset
	var col := visible_index % SHOP_TRADE_COLUMNS
	var row := int(float(visible_index) / float(SHOP_TRADE_COLUMNS))
	var start := panel_rect.position + SHOP_TRADE_CELL_START_OFFSET
	return start + Vector2(float(col) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP), float(row) * (SHOP_TRADE_CELL_SIZE + SHOP_TRADE_CELL_GAP)) + Vector2(SHOP_TRADE_CELL_SIZE, SHOP_TRADE_CELL_SIZE) * 0.5


func _get_trade_scroll_offset(panel: String, items: Array) -> int:
	var offset := int(_trade_scroll_offsets.get(panel, 0))
	offset = clampi(offset, 0, _get_trade_max_scroll_offset(items))
	_trade_scroll_offsets[panel] = offset
	return offset


func _get_trade_max_scroll_offset(items: Array) -> int:
	if items.size() <= SHOP_TRADE_VISIBLE_CELLS:
		return 0
	var raw := items.size() - SHOP_TRADE_VISIBLE_CELLS
	return int(ceil(float(raw) / float(SHOP_TRADE_COLUMNS))) * SHOP_TRADE_COLUMNS


func _clamp_trade_scroll_offsets() -> void:
	_get_trade_scroll_offset("player", _player_inventory)
	_get_trade_scroll_offset("shop", _shop_inventory)


func _close() -> void:
	if _close_callback.is_valid():
		_close_callback.call()


func _set_hovered_object(object_id: String) -> void:
	if _hovered_object_id == object_id:
		return
	_hovered_object_id = object_id
	queue_redraw()


func _get_object_at_local_pos(local_pos: Vector2) -> String:
	return _get_object_at_game_pos(_to_game_pos(local_pos))


func _get_object_at_game_pos(game_pos: Vector2) -> String:
	for idx in range(_object_specs.size() - 1, -1, -1):
		var spec := _object_specs[idx]
		var rect: Rect2 = spec.get("rect", Rect2())
		if rect.grow(12.0).has_point(game_pos):
			return str(spec.get("id", ""))
	return ""


func _find_object_spec(object_id: String) -> Dictionary:
	for spec in _object_specs:
		if str(spec.get("id", "")) == object_id:
			return spec
	return {}


func _build_object_specs() -> Array[Dictionary]:
	if _building_type == "shop":
		return _build_topview_shop_object_specs()
	var result: Array[Dictionary] = []
	var count: int = mini(_actions.size(), 4)
	if count <= 0:
		return result
	var rects := _get_default_object_rects(count)
	for idx in range(count):
		var kind := _get_object_kind(idx)
		result.append({
			"id": "%s_action_%d" % [_building_type, idx],
			"action_index": idx,
			"label": str(_actions[idx]),
			"kind": kind,
			"rect": rects[idx],
		})
	return result


func _build_topview_shop_object_specs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var action_index := 0
	for spec_value in SHOP_STREWN_SPECS:
		var spec: Dictionary = spec_value.duplicate(true)
		spec["action_index"] = action_index
		spec["role"] = "strewn"
		result.append(spec)
	return result


func _get_default_object_rects(count: int) -> Array[Rect2]:
	if count == 1:
		return [Rect2(Vector2(438.0, 392.0), Vector2(126.0, 132.0))]
	if count == 2:
		return [
			Rect2(Vector2(368.0, 400.0), Vector2(118.0, 128.0)),
			Rect2(Vector2(548.0, 400.0), Vector2(118.0, 128.0)),
		]
	if count == 3:
		if _room_backdrop_texture != null and _building_type == "shop":
			return [
				Rect2(Vector2(282.0, 348.0), Vector2(112.0, 118.0)),
				Rect2(Vector2(408.0, 344.0), Vector2(118.0, 122.0)),
				Rect2(Vector2(560.0, 350.0), Vector2(112.0, 118.0)),
			]
		return [
			Rect2(Vector2(318.0, 404.0), Vector2(116.0, 124.0)),
			Rect2(Vector2(464.0, 390.0), Vector2(126.0, 136.0)),
			Rect2(Vector2(610.0, 404.0), Vector2(112.0, 124.0)),
		]
	return [
		Rect2(Vector2(304.0, 406.0), Vector2(100.0, 118.0)),
		Rect2(Vector2(418.0, 394.0), Vector2(108.0, 128.0)),
		Rect2(Vector2(540.0, 394.0), Vector2(108.0, 128.0)),
		Rect2(Vector2(662.0, 406.0), Vector2(84.0, 118.0)),
	]


func _get_object_kind(index: int) -> String:
	match _building_type:
		"shop":
			return ["crystal", "capsule", "sell"][mini(index, 2)]
		"bank":
			return "sell"
		"gacha", "lingpet_store":
			return "capsule"
		_:
			return "crystal"


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(str(item))
	return result


func _duplicate_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _get_featured_shop_items() -> Array:
	var result: Array = []
	for item_value in _shop_inventory:
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


func _get_shop_item_color(item_data: Dictionary, fallback: Color) -> Color:
	var color_value: Variant = item_data.get("quality_color", item_data.get("color", fallback))
	if color_value is Color:
		return color_value
	return fallback


func _is_trade_item_equipped(item_data: Dictionary) -> bool:
	return bool(item_data.get("equipped", false)) or str(item_data.get("_equipped_slot", "")) != ""


func _get_trade_item_price_for_panel(panel: String, item_data: Dictionary) -> int:
	if item_data.is_empty():
		return 0
	if panel == "player":
		return maxi(0, int(item_data.get("shop_sell_price", item_data.get("sell_price", 0))))
	if panel == "shop":
		return maxi(0, int(item_data.get("shop_price", item_data.get("price", 0))))
	return 0


func _format_trade_gold_amount(amount: int) -> String:
	var sign := "-" if amount < 0 else ""
	var digits := str(absi(amount))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.substr(digits.length() - 3, 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return sign + digits + result


func _record_trade_feedback(summary_value: Variant) -> void:
	if not (summary_value is Dictionary):
		return
	var summary: Dictionary = summary_value
	if not bool(summary.get("changed", false)):
		return
	var action := str(summary.get("action", ""))
	if not ["purchase", "sale"].has(action):
		return
	var signature := "%s|%s|%s|%s|%s" % [
		action,
		str(summary.get("item_name", "")),
		str(summary.get("display_name", "")),
		str(summary.get("delta_gold", 0)),
		str(summary.get("plaza_gold", "")),
	]
	if signature == _last_trade_feedback_signature:
		return
	_last_trade_feedback_signature = signature
	var delta_gold := int(summary.get("delta_gold", 0))
	var gold_text := "+%dG" % delta_gold if delta_gold >= 0 else "-%dG" % abs(delta_gold)
	var display_name := str(summary.get("display_name", ""))
	var feedback_text := gold_text if display_name == "" else "%s  %s" % [gold_text, display_name]
	_trade_feedbacks.append({
		"action": action,
		"text": feedback_text,
		"age": 0.0,
		"duration": SHOP_TRADE_FEEDBACK_DURATION,
	})
	while _trade_feedbacks.size() > 4:
		_trade_feedbacks.pop_front()


func _advance_trade_feedbacks(delta: float) -> bool:
	if _trade_feedbacks.is_empty():
		return false
	for idx in range(_trade_feedbacks.size() - 1, -1, -1):
		var feedback := _get_dict(_trade_feedbacks[idx])
		var next_age := float(feedback.get("age", 0.0)) + delta
		if next_age >= float(feedback.get("duration", SHOP_TRADE_FEEDBACK_DURATION)):
			_trade_feedbacks.remove_at(idx)
		else:
			feedback["age"] = next_age
			_trade_feedbacks[idx] = feedback
	return true


func _smooth_unit(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _prewarm_trade_item_icons() -> void:
	var all_items: Array = []
	all_items.append_array(_player_inventory)
	all_items.append_array(_shop_inventory)
	for item_value in all_items:
		var item_data := _get_dict(item_value)
		var path := _get_trade_item_icon_path(item_data)
		if path == "" or _item_icon_textures.has(path):
			continue
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			_item_icon_textures[path] = null
			continue
		_item_icon_textures[path] = ProjectResourceLoader.load_imported_texture(path)


func _get_trade_item_icon_texture(item_data: Dictionary) -> Texture2D:
	var path := _get_trade_item_icon_path(item_data)
	if path == "":
		return null
	var texture: Variant = _item_icon_textures.get(path, null)
	return texture if texture is Texture2D else null


func _get_trade_item_icon_path(item_data: Dictionary) -> String:
	var path := str(item_data.get("icon_path", ""))
	if path == "":
		path = str(item_data.get("icon", ""))
	if path == "":
		path = str(item_data.get("texture_path", ""))
	if path.begins_with("res://"):
		return path
	return ""


func _format_trade_item_name(item_data: Dictionary) -> String:
	var name := str(item_data.get("qualified_display_name", item_data.get("display_name", item_data.get("korean_name", item_data.get("name", "아이템")))))
	return name if name != "" else "아이템"


func _format_trade_item_description(item_data: Dictionary) -> String:
	for key in ["description", "desc", "korean_desc", "tooltip", "summary"]:
		var text := str(item_data.get(key, "")).strip_edges()
		if text != "":
			return text
	var item_name := str(item_data.get("name", ""))
	if item_name != "":
		return "%s의 효과를 전투 중에 발동합니다." % _format_trade_item_name(item_data)
	return "상세 효과는 장착 후 확인할 수 있습니다."


func _format_trade_item_rolls(item_data: Dictionary) -> String:
	var roll_value: Variant = item_data.get("rolled_options", item_data.get("roll_options", []))
	if not (roll_value is Array):
		return ""
	var parts: Array[String] = []
	for option_value in roll_value as Array:
		var option := _get_dict(option_value)
		if option.is_empty():
			continue
		var label := str(option.get("label", option.get("stat", option.get("id", ""))))
		var value_text := str(option.get("display_value", option.get("value", "")))
		if label != "":
			parts.append("%s %s" % [label, value_text])
		if parts.size() >= 2:
			break
	return " / ".join(parts)


func _draw_wrapped_text(font: Font, pos: Vector2, text: String, max_width: float, font_size: int, color: Color, line_height: float, max_lines: int) -> int:
	if font == null or text == "" or font_size <= 0 or max_lines <= 0:
		return 0
	var words := text.replace("\n", " ").split(" ", false)
	var lines: Array[String] = []
	var current := ""
	for word_value in words:
		var word := str(word_value)
		var candidate := word if current == "" else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			current = candidate
		else:
			if current != "":
				lines.append(current)
			current = word
		if lines.size() >= max_lines:
			break
	if current != "" and lines.size() < max_lines:
		lines.append(current)
	for idx in range(lines.size()):
		_draw_text_shadow(font, pos + Vector2(0.0, line_height * float(idx)), lines[idx], font_size, color)
	return lines.size()


func _get_shop_animation_meta(kind: String) -> Dictionary:
	var value: Variant = SHOP_STREWN_ANIMATION_META.get(kind, {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _get_sheet_frame_rect(texture: Texture2D, cols: int, rows: int, frame_index: int) -> Rect2:
	if texture == null or cols <= 0 or rows <= 0:
		return Rect2()
	var texture_size := texture.get_size()
	var cell_size := Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var safe_index := maxi(0, frame_index)
	var col := safe_index % cols
	var row := int(float(safe_index) / float(cols))
	row = mini(row, rows - 1)
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


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
	if font == null or text == "" or font_size <= 0:
		return
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(0.82, color.a)))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
