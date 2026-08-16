extends Control

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaAcademyTransactions := preload("res://scripts/plaza/plaza_academy_transactions.gd")
const PlazaBlacksmithTransactions := preload("res://scripts/plaza/plaza_blacksmith_transactions.gd")
const PlazaGachaTransactions := preload("res://scripts/plaza/plaza_gacha_transactions.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const PlazaShopInventoryState := preload("res://scripts/plaza/plaza_shop_inventory_state.gd")
const PlazaShopStock := preload("res://scripts/plaza/plaza_shop_stock.gd")
const PlazaShopTransactions := preload("res://scripts/plaza/plaza_shop_transactions.gd")
const PlazaTavernTransactions := preload("res://scripts/plaza/plaza_tavern_transactions.gd")
const PlazaThemeCatalog := preload("res://scripts/plaza/plaza_theme_catalog.gd")
const PlazaInteriorView := preload("res://scripts/plaza/plaza_interior_view.gd")
const PlazaWarpPillarFxHost := preload("res://scripts/plaza/plaza_warp_pillar_fx_host.gd")
const PlazaCharacterInfoOverlayHost := preload("res://scripts/plaza/plaza_character_info_overlay_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const PlazaTransactionMessageFormatter := preload("res://scripts/plaza/plaza_transaction_message_formatter.gd")
const PlazaTransitionState := preload("res://scripts/plaza/plaza_transition_state.gd")
const PlazaBuildingMenuSessionState := preload("res://scripts/plaza/plaza_building_menu_session_state.gd")
const PlazaTransactionSummaryStore := preload("res://scripts/plaza/plaza_transaction_summary_store.gd")
const PlazaBuildingMenuCatalog := preload("res://scripts/plaza/plaza_building_menu_catalog.gd")
const PlazaMinimapProjection := preload("res://scripts/plaza/plaza_minimap_projection.gd")
const PlazaMinimapRenderer := preload("res://scripts/plaza/plaza_minimap_renderer.gd")
const PlazaActorVisualProjection := preload("res://scripts/plaza/plaza_actor_visual_projection.gd")
const PlazaActorRenderer := preload("res://scripts/plaza/plaza_actor_renderer.gd")
const PlazaMapWorldHost := preload("res://scripts/plaza/plaza_map_world_host.gd")
const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaFlowGatePolicy := preload("res://scripts/plaza/plaza_flow_gate_policy.gd")
const PlazaTradeItemPresentation := preload("res://scripts/plaza/plaza_trade_item_presentation.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")
const PlazaStatusSnapshotBuilder := preload("res://scripts/plaza/plaza_status_snapshot_builder.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const MAP_SIZE := PlazaAssetLoader.HWANGYEOK_MAP_WORLD_SIZE
const CAMERA_SMOOTHING := 0.08
const CAMERA_LEAD_X := 100.0
const GROUND_Y := 666.0
const BUILDING_BASELINE_Y := 640.0
const SIDEWALK_TOP := 596.0
const EXIT_ZONE := Rect2(Vector2(MAP_SIZE.x - 150.0, SIDEWALK_TOP), Vector2(120.0, 92.0))
const DIALOG_DURATION := 2.25
const BANK_ACTION_IDS := ["deposit", "withdraw", "interest"]

var current_stage: int = 1
var plaza_theme: Dictionary = {}
var exit_callback: Callable = Callable()

var _driven_by_controller := false
var _floor_textures: Dictionary = {}
var _building_specs: Array[Dictionary] = []
var _player_pos := Vector2(120.0, GROUND_Y)
var _camera_x := 0.0
var _dialog_text := ""
var _dialog_timer := 0.0
var _menu_session: PlazaBuildingMenuSessionState = PlazaBuildingMenuSessionState.new()
var _transaction_summaries: PlazaTransactionSummaryStore = PlazaTransactionSummaryStore.new()
var _plaza_save_store: Object = PlazaSaveStore.new()
var _plaza_shop_stock: Object = PlazaShopStock.new()
var _plaza_blacksmith_transactions: Object = PlazaBlacksmithTransactions.new()
var _plaza_gacha_transactions: Object = PlazaGachaTransactions.new()
var _plaza_lingpet_store_transactions: Object = PlazaLingpetStoreTransactions.new()
var _plaza_academy_transactions: Object = PlazaAcademyTransactions.new()
var _plaza_tavern_transactions: Object = PlazaTavernTransactions.new()
var _runtime_perk_overlay_renderer: Object = RuntimePerkOverlayRenderer.new()
var _runtime_perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
var _status_snapshot_builder: Object = PlazaStatusSnapshotBuilder.new()
var _plaza_save_snapshot: Dictionary = {}
var _shop_inventory_state: PlazaShopInventoryState = PlazaShopInventoryState.new()
var _plaza_shop_transactions: Object = PlazaShopTransactions.new()
var _runtime_owner: Object = null
var _runtime_registry: Object = null
var _hovered_building_type := ""
var _map_seed := 0
var _full_layout_for_test := false
var _selected_character_type := "smasher"
var _player_textures: Dictionary = {}
var _interior_npc_textures: Dictionary = {}
var _interior_room_textures: Dictionary = {}
var _interior_object_textures: Dictionary = {}
var _lingpet_companion_texture: Texture2D = null
var _lingpet_companion_pet_id := ""
var _lingpet_companion_draw_size := 92.0
var _lingpet_follower_pos := Vector2.ZERO
var _lingpet_follower_initialized := false
var _transition_state: PlazaTransitionState = PlazaTransitionState.new()
var _map_world_host: Control = null
var _warp_pillar_fx_host: Node = null
var _character_info_overlay_host: Control = null
var _interior_view: Control = null
var _last_input_dir := Vector2.RIGHT
var _test_input_active := false
var _test_input_dir := Vector2.ZERO
var _plaza_exit_finished := false
var _map_world_ticks_msec_for_test := -1
var _map_world_glow_strength_for_test := -1.0
var _map_world_render_background_for_test := true
var _map_world_fill_color_for_test := PlazaMapWorldHost.DEFAULT_FILL_COLOR
var _r3_production := false
var _r3_entry_host: Control = null
var _r3_pending_interaction: Dictionary = {}
var _r3_last_tick: Dictionary = {}
var _r3_tick_failure_count := 0

static var _prewarm_stage_id := -1
static var _prewarm_phase := 0


static func prewarm_assets_step(stage_id: int = 1) -> bool:
	return _prewarm_assets_with_world_host_step(stage_id, true)


static func prewarm_assets_threaded_step(stage_id: int = 1) -> bool:
	return _prewarm_assets_with_world_host_step(stage_id, true)


static func prewarm_assets_blocking_step(stage_id: int = 1) -> bool:
	return _prewarm_assets_with_world_host_step(stage_id, false)


static func get_prewarm_asset_status() -> Dictionary:
	var base_status := PlazaAssetLoader.get_prewarm_status()
	var building_status := PlazaAssetLoader.get_building_prewarm_status(
		PlazaAssetLoader.HWANGYEOK_BUILDING_ASSET_SET_ID
	)
	var status := base_status.duplicate(true)
	status["stage_id"] = int(base_status.get("stage_id", _prewarm_stage_id))
	status["base_status"] = base_status
	status["hwangyeok_building_status"] = building_status
	status["phase"] = _prewarm_phase
	status["complete"] = (
		bool(base_status.get("complete", false))
		and bool(building_status.get("complete", false))
	)
	return status


static func reset_prewarm_assets_for_test() -> void:
	PlazaAssetLoader.reset_for_test()
	_prewarm_stage_id = -1
	_prewarm_phase = 0


static func _prewarm_assets_with_world_host_step(stage_id: int, use_threaded_texture_loads: bool) -> bool:
	var normalized_stage := PlazaThemeCatalog.normalize_stage_id(stage_id)
	if _prewarm_stage_id != normalized_stage:
		_prewarm_stage_id = normalized_stage
		_prewarm_phase = 0
	PlazaWarpPillarFxHost.prewarm_assets()
	if _prewarm_phase == 0:
		if not PlazaAssetLoader.prewarm_assets_step(normalized_stage, use_threaded_texture_loads):
			return false
		_prewarm_phase = 1
	if _prewarm_phase == 1:
		if not PlazaMapWorldHost.prewarm_owned_assets_step(
			PlazaAssetLoader.get_hwangyeok_building_manifest_paths(),
			use_threaded_texture_loads,
			PlazaAssetLoader.HWANGYEOK_BUILDING_ASSET_SET_ID
		):
			return false
		_prewarm_phase = 2
	return true


func _ready() -> void:
	# When driven by the result-screen controller, live mouse input arrives via
	# battle_scene_shell._unhandled_input -> handle_plaza_input (global coords). A STOP
	# filter consumes GUI mouse events and starves that path (which left the shop interior
	# un-clickable). Stay IGNORE while driven so mouse falls through; keyboard still reaches
	# _gui_input through focus. Standalone (non-driven) keeps STOP for its own _gui_input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _driven_by_controller else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	set_process(not _driven_by_controller)
	if not _r3_production:
		_ensure_map_world_host()
		_ensure_warp_pillar_fx_host()
	_ensure_character_info_overlay_host()
	if plaza_theme.is_empty():
		configure({"current_stage": current_stage}, Callable(), false)
	else:
		_sync_game_rect()
		if not _r3_production:
			_sync_map_world_host(_sample_map_world_ticks_msec())
	_sync_warp_pillar_fx_host()
	_sync_character_info_overlay_host()
	grab_focus()


func configure(data: Dictionary, on_exit: Callable = Callable(), driven_by_controller: bool = false) -> void:
	_driven_by_controller = driven_by_controller
	set_process(not _driven_by_controller)
	_r3_production = bool(data.get("r3_production", false))
	var r3_host_value: Variant = data.get("r3_entry_host", null)
	_r3_entry_host = r3_host_value as Control if r3_host_value is Control else null
	_r3_pending_interaction.clear()
	_r3_last_tick.clear()
	_r3_tick_failure_count = 0
	current_stage = PlazaThemeCatalog.normalize_stage_id(int(data.get("current_stage", current_stage)))
	plaza_theme = PlazaThemeCatalog.get_theme(current_stage)
	exit_callback = on_exit
	_plaza_exit_finished = false
	_runtime_owner = data.get("runtime_owner", null) as Object
	_runtime_registry = data.get("runtime_registry", null) as Object
	_selected_character_type = PlazaAssetLoader.normalize_player_character_type(data.get("selected_character_type", _get_runtime_owner_selected_character_type()))
	_player_textures = PlazaAssetLoader.load_player_textures(_selected_character_type)
	_interior_npc_textures = PlazaAssetLoader.load_interior_npc_textures()
	_interior_room_textures = PlazaAssetLoader.load_interior_room_textures()
	_interior_object_textures = PlazaAssetLoader.load_interior_object_textures()
	if not _r3_production:
		_refresh_lingpet_companion_visual()
	var save_path := str(data.get("plaza_save_path", "")).strip_edges()
	if save_path != "" and _plaza_save_store != null and _plaza_save_store.has_method("set_save_path"):
		_plaza_save_store.set_save_path(save_path)
	_floor_textures = {} if _r3_production else PlazaAssetLoader.load_floor_textures(current_stage)
	_refresh_plaza_save_snapshot()
	_full_layout_for_test = bool(data.get("full_layout_for_test", false))
	_map_seed = int(data.get("map_seed", 0))
	if _map_seed <= 0 and not _full_layout_for_test:
		_map_seed = _get_or_create_stage_map_seed(current_stage)
		_refresh_plaza_save_snapshot()
	var force_tavern := _should_force_tavern_for_current_stage()
	if _r3_production and _r3_entry_host != null and _r3_entry_host.has_method("get_layout_snapshot"):
		var r3_layout := _r3_entry_host.call("get_layout_snapshot") as Dictionary
		_building_specs = _dictionary_array(r3_layout.get("building_specs", []))
		_player_pos = r3_layout.get("spawn_anchor", Vector2(120.0, GROUND_Y)) as Vector2
	else:
		_building_specs = PlazaAssetLoader.build_hwangyeok_building_specs(
			current_stage,
			_map_seed,
			_full_layout_for_test,
			force_tavern
		)
		_player_pos = _normalize_player_pos(Vector2(120.0, GROUND_Y))
		_lingpet_follower_initialized = false
		_update_lingpet_follower(0.0)
	_camera_x = _get_target_camera_x()
	_close_building_menu(false)
	_transaction_summaries.clear_all()
	_close_character_info_overlay(false)
	_clear_building_transition()
	_clear_plaza_warp_transition()
	if bool(data.get("play_arrival_transition", false)) and not _r3_production:
		_start_plaza_warp_transition("arrive")
	_dialog_text = ""
	_dialog_timer = 0.0
	_sync_game_rect()
	if not _r3_production:
		_sync_map_world_host(_sample_map_world_ticks_msec())
	_sync_character_info_overlay_host()
	queue_redraw()


func update_plaza(delta: float) -> void:
	_sync_game_rect()
	# The retained world is sync-driven. Sample once for this rendered frame,
	# then pass the same tick to every owned background/building layer.
	var frame_ticks_msec := _sample_map_world_ticks_msec()
	var flow_gate := _get_flow_gate()
	match flow_gate:
		PlazaFlowGatePolicy.RUNTIME_PERK:
			_update_runtime_perk_overlay(delta)
		PlazaFlowGatePolicy.CHARACTER_INFO:
			_update_character_info_overlay(delta)
		PlazaFlowGatePolicy.PLAZA_WARP:
			_update_plaza_warp_transition(delta)
		PlazaFlowGatePolicy.BUILDING_TRANSITION:
			_update_building_transition(delta)
		PlazaFlowGatePolicy.INTERIOR_MENU:
			_ensure_interior_view()
			_sync_interior_view_state()
		PlazaFlowGatePolicy.STREET:
			pass
	if PlazaFlowGatePolicy.blocks_street_update(flow_gate):
		_dialog_timer = 0.0
		_update_hovered_building()
		if not _r3_production:
			_sync_map_world_host(frame_ticks_msec)
		queue_redraw()
		return
	var input_dir := _get_input_dir()
	if _r3_production:
		if _r3_entry_host == null or not is_instance_valid(_r3_entry_host):
			_r3_tick_failure_count += 1
			return
		_r3_last_tick = _r3_entry_host.call("tick_exterior", input_dir, maxf(0.0, delta), Time.get_ticks_msec()) as Dictionary
		if not bool(_r3_last_tick.get("valid", false)):
			_r3_tick_failure_count += 1
			return
		_player_pos = _r3_last_tick.get("player_world_position", _player_pos) as Vector2
		var guardian_value: Variant = _r3_last_tick.get("guardian_world_position", Vector2.INF)
		if guardian_value is Vector2 and (guardian_value as Vector2).is_finite():
			_lingpet_follower_pos = guardian_value as Vector2
		_lingpet_follower_initialized = true
		_dialog_timer = maxf(0.0, _dialog_timer - maxf(0.0, delta))
		queue_redraw()
		return
	if input_dir != Vector2.ZERO:
		_last_input_dir = input_dir.normalized()
	var move_result: Dictionary = PlazaPlayerController.move_player(
		_player_pos,
		Vector2(input_dir.x, 0.0),
		delta,
		[],
		MAP_SIZE
	)
	_player_pos = _normalize_player_pos(move_result.get("player_pos", _player_pos))
	_update_lingpet_follower(delta)
	var target_camera_x := _get_target_camera_x()
	var fps_scale: float = max(0.0, delta) * 60.0
	var blend: float = clampf(CAMERA_SMOOTHING * fps_scale, 0.0, 1.0)
	_camera_x = lerpf(_camera_x, target_camera_x, blend)
	_dialog_timer = max(0.0, _dialog_timer - max(0.0, delta))
	_update_hovered_building()
	_sync_map_world_host(frame_ticks_msec)
	queue_redraw()


func handle_plaza_input(event: InputEvent) -> bool:
	match _get_flow_gate():
		PlazaFlowGatePolicy.RUNTIME_PERK:
			return _handle_runtime_perk_overlay_input(event)
		PlazaFlowGatePolicy.CHARACTER_INFO:
			return _handle_character_info_overlay_input(event)
		PlazaFlowGatePolicy.PLAZA_WARP, PlazaFlowGatePolicy.BUILDING_TRANSITION:
			return true
		PlazaFlowGatePolicy.INTERIOR_MENU:
			if _is_character_info_tab_event(event):
				_open_character_info_overlay()
				return true
			if _ensure_interior_view():
				return _interior_view.handle_input(_localize_interior_event(event))
			return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if _is_character_info_tab_event(event):
			_open_character_info_overlay()
			return true
		if key_event.keycode == KEY_ESCAPE:
			_exit_plaza()
			return true
		if _r3_production and key_event.keycode == KEY_R:
			if _r3_entry_host != null:
				_r3_entry_host.call("request_guardian_recall", _player_pos)
			return true
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
			_try_interact()
			return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		if _r3_production:
			_try_interact()
			return true
		var world_pos := _screen_to_world(mouse_event.position)
		if EXIT_ZONE.has_point(world_pos):
			_exit_plaza()
			return true
		var building := _get_building_at_world_pos(world_pos)
		if not building.is_empty():
			_show_building_dialog(building)
			return true
	return true


func get_status() -> Dictionary:
	var status: Dictionary = _status_snapshot_builder.build(_build_status_snapshot_context()) as Dictionary
	status["r3_production"] = _r3_production
	status["r3_tick_failure_count"] = _r3_tick_failure_count
	status["r3_last_tick"] = _r3_last_tick.duplicate(true)
	status["r3_entry_status"] = _r3_entry_host.call("get_debug_status") if _r3_entry_host != null and is_instance_valid(_r3_entry_host) else {}
	return status


func refresh_progress_state_after_entry_commit() -> void:
	# PlazaScene owns a separate store instance from the result screen. The
	# atomic commit writes through the result owner after this scene was hidden-
	# configured, so reload the same path before exposing the first R3 frame.
	if _plaza_save_store != null and _plaza_save_store.has_method("load"):
		_plaza_save_store.call("load")
	_refresh_plaza_save_snapshot()
	queue_redraw()


func _build_status_snapshot_context() -> Dictionary:
	var active_building := _get_interactable_building()
	var warp_fx_status := _get_warp_pillar_fx_status()
	var character_info_status := _get_character_info_overlay_status()
	var interior_status := _get_interior_view_status()
	var active_menu_type := _menu_session.building_type
	return {
		"flow_gate": _get_flow_gate(),
		"current_stage": current_stage,
		"plaza_theme": plaza_theme,
		"player_pos": _player_pos,
		"player_textures": _player_textures,
		"camera_x": _camera_x,
		"ground_y": GROUND_Y,
		"world_size": MAP_SIZE,
		"map_seed": _map_seed,
		"full_layout_for_test": _full_layout_for_test,
		"selected_character_type": _selected_character_type,
		"player_sprite_frame": _get_player_sprite_frame(),
		"lingpet_companion_visible": _is_lingpet_companion_visible(),
		"lingpet_companion_pet_id": _lingpet_companion_pet_id,
		"lingpet_follower_pos": _lingpet_follower_pos,
		"building_count": _building_specs.size(),
		"hovered_building_type": _hovered_building_type,
		"active_building": active_building,
		"dialog_text": _dialog_text if _dialog_timer > 0.0 else "",
		"menu_open": _menu_session.is_open,
		"building_transition_active": _transition_state.building_active,
		"building_transition_phase": _transition_state.building_phase,
		"building_transition_progress": _get_building_transition_progress(),
		"plaza_warp_active": _transition_state.warp_active,
		"plaza_warp_phase": _transition_state.warp_phase,
		"plaza_warp_progress": _get_plaza_warp_progress(),
		"warp_fx_status": warp_fx_status,
		"character_info_status": character_info_status,
		"active_menu_type": active_menu_type,
		"active_menu_title": _menu_session.title,
		"active_menu_subtitle": _menu_session.subtitle,
		"active_menu_actions": _menu_session.actions,
		"active_menu_last_message": _menu_session.last_message,
		"active_menu_visit_ap_consumed": _menu_session.visit_ap_consumed,
		"interior_view_active": _is_interior_view_active(),
		"interior_status": interior_status,
		"interior_npc_texture_loaded": _get_interior_npc_texture(active_menu_type) != null,
		"interior_room_texture_loaded": _get_interior_room_texture(active_menu_type) != null,
		"last_bank_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.BANK),
		"last_shop_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.SHOP),
		"last_blacksmith_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.BLACKSMITH),
		"last_gacha_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.GACHA),
		"last_lingpet_store_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.LINGPET_STORE),
		"last_academy_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.ACADEMY),
		"last_tavern_transaction_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.TAVERN),
		"runtime_perk_choice_active": _is_runtime_perk_overlay_active(),
		"runtime_perk_choice_count": _get_runtime_perk_choice_count(),
		"runtime_perk_selected_index": _get_runtime_perk_selected_index(),
		"save_snapshot": _plaza_save_snapshot,
		"shop_inventory_count": _shop_inventory_state.size(),
		"tavern_active_quest": _get_tavern_active_quest_summary(),
		"active_item_slot_count": _get_active_item_slot_count(),
		"owned_lingpet_count": _get_owned_lingpet_count(),
		"blacksmith_target_summary": _get_blacksmith_target_summary(),
		"exit_zone": EXIT_ZONE,
		"minimap_state": _build_minimap_state(),
		"game_rect": get_global_rect(),
	}


func _get_flow_gate() -> StringName:
	return PlazaFlowGatePolicy.resolve(
		_is_runtime_perk_overlay_active(),
		_is_character_info_overlay_active(),
		_transition_state.warp_active,
		_transition_state.building_active,
		_menu_session.is_open
	)


func set_plaza_save_path_for_test(path: String) -> void:
	if _plaza_save_store != null and _plaza_save_store.has_method("set_save_path"):
		_plaza_save_store.set_save_path(path)
		_refresh_plaza_save_snapshot()


func set_player_pos_for_test(pos: Vector2) -> void:
	_player_pos = _normalize_player_pos(pos)
	_lingpet_follower_initialized = false
	_update_lingpet_follower(0.0)
	_camera_x = _get_target_camera_x()
	_update_hovered_building()
	queue_redraw()


func move_player_for_test(input_dir: Vector2, delta: float) -> Dictionary:
	_test_input_active = true
	_test_input_dir = input_dir
	update_plaza(delta)
	_test_input_active = false
	return get_status()


func trigger_interaction_for_test(complete_transition: bool = true) -> bool:
	var handled := _try_interact()
	if handled and complete_transition:
		_complete_building_transition_for_test()
	return handled


func get_building_at_world_pos_for_test(world_pos: Vector2) -> Dictionary:
	return _get_building_at_world_pos(world_pos)


func click_world_pos_for_test(world_pos: Vector2) -> bool:
	# Mirrors the left-click branch of handle_plaza_input: pick a building at the
	# world position and open its menu. Returns true if a building menu opened.
	if _menu_session.is_open or _transition_state.building_active or _transition_state.warp_active:
		return false
	var building := _get_building_at_world_pos(world_pos)
	if building.is_empty():
		return false
	_show_building_dialog(building)
	_complete_building_transition_for_test()
	return _menu_session.is_open


func close_menu_for_test(complete_transition: bool = true) -> void:
	_close_building_menu(not complete_transition)
	if complete_transition:
		_complete_building_transition_for_test()


func advance_building_transition_for_test(delta: float) -> Dictionary:
	_update_building_transition(delta)
	queue_redraw()
	return get_status()


func advance_plaza_warp_transition_for_test(delta: float) -> Dictionary:
	_update_plaza_warp_transition(delta)
	queue_redraw()
	return get_status()


func trigger_menu_action_for_test(action_index: int = 0) -> bool:
	if _is_interior_view_active():
		return _trigger_interior_action(action_index)
	return _trigger_menu_action(action_index)


func hover_interior_object_for_test(object_id: String) -> Dictionary:
	if not _is_interior_view_active():
		return get_status()
	if _interior_view.has_method("hover_object_for_test"):
		_interior_view.hover_object_for_test(object_id)
	return get_status()


func click_interior_object_for_test(object_id: String) -> Dictionary:
	if not _is_interior_view_active():
		return get_status()
	if _interior_view.has_method("click_object_for_test"):
		_interior_view.click_object_for_test(object_id)
	return get_status()


func confirm_interior_object_for_test() -> bool:
	if not _is_interior_view_active():
		return false
	if _interior_view.has_method("confirm_selected_object_for_test"):
		return bool(_interior_view.confirm_selected_object_for_test())
	return false


func click_interior_action_for_test(action_index: int = 0) -> bool:
	if not _is_interior_view_active():
		return false
	if _interior_view.has_method("click_action_for_test"):
		return bool(_interior_view.click_action_for_test(action_index))
	return false


func advance_interior_view_for_test(delta: float) -> Dictionary:
	if not _is_interior_view_active():
		return {}
	if _interior_view.has_method("advance_time_for_test"):
		var result: Variant = _interior_view.advance_time_for_test(delta)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return _get_interior_view_status()


func trade_interior_item_for_test(panel: String, index: int) -> Dictionary:
	if _menu_session.building_type != "shop":
		return get_status()
	_trigger_interior_action({
		"type": "shop_trade",
		"panel": panel,
		"index": index,
	})
	return get_status()


func get_interior_trade_item_price_for_test(panel: String, index: int) -> int:
	if not _is_interior_view_active():
		return -1
	if _interior_view.has_method("get_trade_item_price_for_test"):
		return int(_interior_view.get_trade_item_price_for_test(panel, index))
	return -1


func get_shop_inventory_snapshot_for_test() -> Array:
	return _shop_inventory_state.snapshot()


func reorder_interior_trade_item_for_test(panel: String, from_index: int, to_index: int) -> Dictionary:
	if _menu_session.building_type != "shop":
		return get_status()
	_trigger_interior_action({
		"type": "shop_trade_reorder",
		"panel": panel,
		"from_index": from_index,
		"to_index": to_index,
	})
	return get_status()


func get_flicker_samples_for_test() -> Dictionary:
	var ticks_msec := Time.get_ticks_msec()
	return {
		"ground_0": PlazaBackgroundProjection.discrete_flicker("ground:0", ticks_msec),
		"ground_1": PlazaBackgroundProjection.discrete_flicker("ground:1140", ticks_msec),
		"accent_0": PlazaBackgroundProjection.discrete_flicker("accent:250", ticks_msec),
		"accent_1": PlazaBackgroundProjection.discrete_flicker("accent:980", ticks_msec),
		"medallion_0": PlazaBackgroundProjection.discrete_flicker("medallion:560", ticks_msec),
		"medallion_1": PlazaBackgroundProjection.discrete_flicker("medallion:1320", ticks_msec),
	}


func get_building_specs_for_test() -> Array[Dictionary]:
	return _building_specs.duplicate(true)


func set_map_world_ticks_msec_for_test(ticks_msec: int) -> void:
	# -1 restores production sampling from Time at the update_plaza owner.
	_map_world_ticks_msec_for_test = -1 if ticks_msec < 0 else ticks_msec


func set_map_world_glow_strength_for_test(strength: float) -> void:
	# Negative restores manifest-authored strengths. Tests still have to call
	# update_plaza(); they cannot bypass the production owner sync path.
	_map_world_glow_strength_for_test = -1.0 if strength < 0.0 else strength


func set_map_world_fill_fixture_for_test(render_background: bool, fill_color: Color) -> void:
	_map_world_render_background_for_test = render_background
	_map_world_fill_color_for_test = fill_color


func get_map_world_host_status_for_test() -> Dictionary:
	if _map_world_host == null or not is_instance_valid(_map_world_host):
		return {"active": false, "visible": false, "attached": false}
	if not _map_world_host.has_method("get_debug_status"):
		return {"active": false, "visible": false, "attached": true}
	var status_value: Variant = _map_world_host.call("get_debug_status")
	var status: Dictionary = (status_value as Dictionary).duplicate(true) if status_value is Dictionary else {}
	status["attached"] = _map_world_host.get_parent() == self
	return status


func get_map_world_layer_statuses_for_test() -> Array[Dictionary]:
	if _map_world_host == null or not is_instance_valid(_map_world_host):
		return []
	if not _map_world_host.has_method("get_building_layer_statuses"):
		return []
	var statuses_value: Variant = _map_world_host.call("get_building_layer_statuses")
	if statuses_value is Array:
		var statuses: Array[Dictionary] = []
		for status_value in statuses_value as Array:
			statuses.append((status_value as Dictionary).duplicate(true) if status_value is Dictionary else {})
		return statuses
	return []


func force_blacksmith_roll_for_test(roll_value: int) -> void:
	if _plaza_blacksmith_transactions != null and _plaza_blacksmith_transactions.has_method("force_next_roll_for_test"):
		_plaza_blacksmith_transactions.force_next_roll_for_test(roll_value)


func force_gacha_item_for_test(item_name: String) -> void:
	if _plaza_gacha_transactions != null and _plaza_gacha_transactions.has_method("force_next_item_for_test"):
		_plaza_gacha_transactions.force_next_item_for_test(item_name)


func _process(delta: float) -> void:
	if _driven_by_controller:
		return
	update_plaza(delta)


func _gui_input(event: InputEvent) -> void:
	if handle_plaza_input(event):
		accept_event()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		_clear_map_world_host()
		return
	if _r3_production:
		# The production R3 host owns the entire exterior, including actor Y-sort,
		# camera and minimap. Drawing an R1 exterior here creates a dual-world bug.
		_draw_runtime_perk_overlay()
		return
	var scale := _get_game_scale()
	_draw_world_objects(scale)
	_draw_overlay_ui(scale)
	_draw_runtime_perk_overlay()


func _sync_game_rect() -> void:
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var view_size := viewport.get_visible_rect().size
	if view_size == Vector2.ZERO:
		return
	var fitted_rect := PlazaWorldGeometry.fit_game_rect(view_size, GAME_SIZE)
	size = fitted_rect.size
	position = fitted_rect.position
	if _is_interior_view_active():
		_interior_view.position = Vector2.ZERO
		_interior_view.size = size
	_sync_character_info_overlay_host()


func _get_game_scale() -> float:
	return PlazaWorldGeometry.get_game_scale(size, GAME_SIZE)


func _get_target_camera_x() -> float:
	return PlazaWorldGeometry.get_target_camera_x(_player_pos.x, GAME_SIZE.x, MAP_SIZE.x, CAMERA_LEAD_X)


func _get_input_dir() -> Vector2:
	if _test_input_active:
		return _test_input_dir.normalized() if _r3_production else Vector2(signf(_test_input_dir.x), 0.0)
	var dir_x := 0.0
	var dir_y := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir_x += 1.0
	if _r3_production:
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			dir_y -= 1.0
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			dir_y += 1.0
		return Vector2(dir_x, dir_y).normalized()
	return Vector2(signf(dir_x), 0.0)


func _is_character_info_tab_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB


func _handle_runtime_perk_overlay_input(event: InputEvent) -> bool:
	var runtime_state := _get_runtime_perk_state()
	if runtime_state == null or not runtime_state.has_method("handle_input"):
		return true
	var overlay_event := _localize_runtime_perk_event(event)
	runtime_state.handle_input(overlay_event, _runtime_owner, _runtime_registry, size)
	queue_redraw()
	return true


func _handle_character_info_overlay_input(event: InputEvent) -> bool:
	if _character_info_overlay_host != null and is_instance_valid(_character_info_overlay_host) and _character_info_overlay_host.has_method("handle_overlay_input"):
		_character_info_overlay_host.handle_overlay_input(_localize_character_info_event(event))
	queue_redraw()
	return true


func _localize_runtime_perk_event(event: InputEvent) -> InputEvent:
	if not (event is InputEventMouse):
		return event
	var duplicated := event.duplicate()
	if duplicated is InputEventMouse:
		var mouse_event := duplicated as InputEventMouse
		mouse_event.position = (event as InputEventMouse).position - get_global_rect().position
	return duplicated


func _localize_character_info_event(event: InputEvent) -> InputEvent:
	return _localize_interior_event(event)


func _localize_interior_event(event: InputEvent) -> InputEvent:
	if not (event is InputEventMouse):
		return event
	var duplicated := event.duplicate()
	if duplicated is InputEventMouse:
		var mouse_event := duplicated as InputEventMouse
		mouse_event.position = (event as InputEventMouse).position - get_global_rect().position
	return duplicated


func _update_runtime_perk_overlay(delta: float) -> void:
	var runtime_state := _get_runtime_perk_state()
	if runtime_state != null and runtime_state.has_method("update"):
		runtime_state.update(max(0.0, delta), size, _runtime_owner, _runtime_registry)


func _update_character_info_overlay(delta: float) -> void:
	if _character_info_overlay_host == null or not is_instance_valid(_character_info_overlay_host):
		return
	if _character_info_overlay_host.has_method("update_overlay"):
		_character_info_overlay_host.update_overlay(maxf(0.0, delta))


func _draw_runtime_perk_overlay() -> void:
	var runtime_state := _get_runtime_perk_state()
	var catalog := _get_runtime_perk_catalog()
	if runtime_state == null or catalog == null:
		return
	if _runtime_perk_overlay_renderer == null or not _runtime_perk_overlay_renderer.has_method("draw"):
		return
	if not _is_runtime_perk_overlay_active():
		return
	_runtime_perk_overlay_renderer.draw(self, runtime_state, catalog, size, _runtime_perk_icon_renderer)


func _is_runtime_perk_overlay_active() -> bool:
	var runtime_state := _get_runtime_perk_state()
	if runtime_state == null:
		return false
	var snapshot := _get_runtime_perk_snapshot(runtime_state)
	if bool(snapshot.get("choice_active", false)):
		return true
	if runtime_state.has_method("has_pending_unlock_swap") and bool(runtime_state.has_pending_unlock_swap()):
		return true
	if runtime_state.has_method("is_choice_flight_active") and bool(runtime_state.is_choice_flight_active()):
		return true
	if _runtime_perk_overlay_renderer != null and _runtime_perk_overlay_renderer.has_method("has_visible_effects"):
		return bool(_runtime_perk_overlay_renderer.has_visible_effects(runtime_state))
	return false


func _get_runtime_perk_state() -> Object:
	if _runtime_registry == null or not _runtime_registry.has_method("get_instance"):
		return null
	return _runtime_registry.get_instance("runtime_perk_state")


func _get_runtime_perk_catalog() -> Object:
	if _runtime_registry == null or not _runtime_registry.has_method("get_instance"):
		return null
	return _runtime_registry.get_instance("runtime_perk_catalog")


func _get_runtime_perk_snapshot(runtime_state: Object = null) -> Dictionary:
	var state := runtime_state if runtime_state != null else _get_runtime_perk_state()
	if state != null and state.has_method("get_snapshot"):
		var result: Variant = state.get_snapshot()
		if result is Dictionary:
			return result
	return {}


func _get_runtime_perk_choice_count() -> int:
	var choices_value: Variant = _get_runtime_perk_snapshot().get("current_choices", [])
	return (choices_value as Array).size() if choices_value is Array else 0


func _get_runtime_perk_selected_index() -> int:
	return int(_get_runtime_perk_snapshot().get("selected_index", -1))


func _normalize_player_pos(pos: Vector2) -> Vector2:
	return PlazaWorldGeometry.normalize_player_position(
		pos,
		MAP_SIZE,
		GROUND_Y,
		PlazaPlayerController.PLAYER_COLLISION_SIZE
	)


func _get_runtime_owner_selected_character_type() -> String:
	if _runtime_owner == null:
		return _selected_character_type
	var value: Variant = _runtime_owner.get("selected_character_type")
	if str(value).strip_edges() == "":
		return _selected_character_type
	return str(value)


func _is_player_walking() -> bool:
	var live_input_dir := Vector2.ZERO if _test_input_active else _get_input_dir()
	return PlazaActorVisualProjection.is_player_walking(
		_test_input_active,
		_test_input_dir,
		live_input_dir
	)


func _get_player_facing_direction() -> int:
	return PlazaActorVisualProjection.get_facing_direction(_last_input_dir)


func _get_player_sprite_frame() -> int:
	var frame_count: int = max(1, int(_player_textures.get("frame_count", 8)))
	return PlazaActorVisualProjection.get_player_sprite_frame(
		Time.get_ticks_msec(),
		_is_player_walking(),
		frame_count
	)


func _get_sheet_frame_rect(texture: Texture2D, frame: int, grid_cols: int, grid_rows: int) -> Rect2:
	if texture == null:
		return Rect2()
	return PlazaActorVisualProjection.get_sheet_frame_rect(
		texture.get_size(),
		frame,
		grid_cols,
		grid_rows
	)


func _refresh_lingpet_companion_visual() -> void:
	_lingpet_companion_pet_id = _get_active_lingpet_pet_id()
	_lingpet_companion_texture = null
	_lingpet_companion_draw_size = 92.0
	_lingpet_follower_initialized = false
	if _lingpet_companion_pet_id == "":
		return
	var path := LingpetCatalog.get_visual_path(_lingpet_companion_pet_id, "companion_walk")
	if path == "":
		return
	_lingpet_companion_texture = ProjectResourceLoader.load_imported_texture(path, "", "")
	_lingpet_companion_draw_size = max(44.0, LingpetCatalog.get_visual_layout_value(_lingpet_companion_pet_id, "companion_walk_draw_size", 92.0))
	_update_lingpet_follower(0.0)


func _get_active_lingpet_pet_id() -> String:
	if _runtime_owner == null:
		return ""
	var state_value: String = str(_runtime_owner.get("lingpet_state")).strip_edges().to_lower()
	var active_id := ""
	for key in ["active_lingpet_id", "current_lingpet_id", "lingpet_id"]:
		var value := str(_runtime_owner.get(str(key))).strip_edges()
		if value != "":
			active_id = value
			break
	if active_id == "":
		return ""
	if state_value != "" and state_value != "companion" and state_value != "active" and state_value != "동행":
		return ""
	return active_id


func _is_lingpet_companion_visible() -> bool:
	return _lingpet_companion_texture != null and _lingpet_companion_pet_id != ""


func _update_lingpet_follower(delta: float) -> void:
	if not _is_lingpet_companion_visible():
		return
	var target_pos := PlazaActorVisualProjection.get_lingpet_follow_target(
		_player_pos,
		_get_player_facing_direction(),
		MAP_SIZE.x,
		PlazaPlayerController.PLAYER_COLLISION_SIZE.x,
		GROUND_Y
	)
	_lingpet_follower_pos = PlazaActorVisualProjection.project_lingpet_follower_position(
		_lingpet_follower_pos,
		_lingpet_follower_initialized,
		target_pos,
		delta
	)
	_lingpet_follower_initialized = true


func _draw_world_objects(scale: float) -> void:
	if _transition_state.warp_active:
		var plaza_warp_progress := _get_plaza_warp_progress()
		var plaza_actor_alpha := _get_plaza_warp_actor_alpha(plaza_warp_progress)
		if plaza_actor_alpha > 0.01:
			var plaza_actor_lift := _get_plaza_warp_actor_lift(plaza_warp_progress)
			_draw_lingpet_follower(scale, plaza_actor_alpha, _lingpet_follower_pos + Vector2(0.0, plaza_actor_lift * 0.72))
			_draw_player(scale, plaza_actor_alpha, _player_pos + Vector2(0.0, plaza_actor_lift))
		return
	if _transition_state.building_active:
		var transition_progress := _get_building_transition_progress()
		var actor_alpha := _get_building_transition_actor_alpha(transition_progress)
		if actor_alpha > 0.01:
			var actor_lift := _get_building_transition_actor_lift(transition_progress)
			_draw_lingpet_follower(scale, actor_alpha, _transition_state.building_lingpet_pos + Vector2(0.0, actor_lift * 0.72))
			_draw_player(scale, actor_alpha, _transition_state.building_player_pos + Vector2(0.0, actor_lift))
		return
	_draw_lingpet_follower(scale)
	_draw_player(scale)

func _draw_player(scale: float, alpha: float = 1.0, world_pos: Vector2 = Vector2.INF) -> void:
	var draw_world_pos := _player_pos if world_pos == Vector2.INF else world_pos
	var moving := _is_player_walking()
	PlazaActorRenderer.draw_player(
		self,
		_player_textures,
		draw_world_pos,
		_camera_x,
		scale,
		alpha,
		moving,
		_get_player_facing_direction(),
		PlazaActorVisualProjection.get_player_sprite_frame(
			Time.get_ticks_msec(),
			moving,
			max(1, int(_player_textures.get("frame_count", 8)))
		)
	)


func _draw_lingpet_follower(scale: float, alpha: float = 1.0, world_pos: Vector2 = Vector2.INF) -> void:
	if not _is_lingpet_companion_visible():
		return
	var draw_world_pos := _lingpet_follower_pos if world_pos == Vector2.INF else world_pos
	PlazaActorRenderer.draw_lingpet(
		self,
		_lingpet_companion_texture,
		_lingpet_companion_draw_size,
		draw_world_pos,
		_camera_x,
		scale,
		alpha,
		Time.get_ticks_msec()
	)


func _get_building_transition_actor_alpha(progress: float) -> float:
	return _transition_state.get_building_actor_alpha(progress)


func _get_building_transition_actor_lift(progress: float) -> float:
	return _transition_state.get_building_actor_lift(progress)


func _get_plaza_warp_actor_alpha(progress: float) -> float:
	return _transition_state.get_warp_actor_alpha(progress)


func _get_plaza_warp_actor_lift(progress: float) -> float:
	return _transition_state.get_warp_actor_lift(progress)


func _sample_map_world_ticks_msec() -> int:
	if _map_world_ticks_msec_for_test >= 0:
		return _map_world_ticks_msec_for_test
	return Time.get_ticks_msec()


func _ensure_map_world_host() -> void:
	if _map_world_host != null and is_instance_valid(_map_world_host):
		return
	if not is_inside_tree():
		return
	var host := PlazaMapWorldHost.new()
	host.name = "PlazaMapWorldHost"
	host.position = Vector2.ZERO
	host.size = size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The live plaza root is z=1200. This must stay relative so -1 resolves to
	# 1199: below root actors/UI, but above the underlying result/battle stack.
	host.z_as_relative = true
	host.z_index = PlazaMapWorldHost.HOST_Z_INDEX
	host.set_process(false)
	add_child(host)
	_map_world_host = host
	_map_world_host.call("set_active", false)


func _sync_map_world_host(ticks_msec: int) -> bool:
	if _r3_production:
		if _map_world_host != null and is_instance_valid(_map_world_host):
			_map_world_host.call("set_active", false)
		return false
	if not is_inside_tree():
		return false
	_ensure_map_world_host()
	if _map_world_host == null or not is_instance_valid(_map_world_host):
		return false
	_map_world_host.position = Vector2.ZERO
	if size.x <= 1.0 or size.y <= 1.0 or _plaza_exit_finished or _menu_session.is_open or _is_interior_view_active():
		_map_world_host.call("set_active", false)
		return false
	var state := {
		"render_size": size,
		"game_size": GAME_SIZE,
		"render_scale": _get_game_scale(),
		"render_background": _map_world_render_background_for_test,
		"draw_opaque_fill": true,
		"fill_color": _map_world_fill_color_for_test,
		"floor_textures": _floor_textures,
		"camera_x": _camera_x,
		"exit_zone": EXIT_ZONE,
		"sidewalk_top": SIDEWALK_TOP,
		"building_baseline_y": BUILDING_BASELINE_Y,
		"ticks_msec": ticks_msec,
		"building_specs": _get_map_world_building_specs_for_sync(),
	}
	return bool(_map_world_host.call("sync_state", state, true))


func _get_map_world_building_specs_for_sync() -> Array[Dictionary]:
	if _map_world_glow_strength_for_test < 0.0:
		return _building_specs
	var specs: Array[Dictionary] = []
	for source_spec in _building_specs:
		var spec := source_spec.duplicate(true)
		spec["sign_glow_strength"] = _map_world_glow_strength_for_test
		spec["window_glow_strength"] = _map_world_glow_strength_for_test
		specs.append(spec)
	return specs


func _clear_map_world_host() -> void:
	if _map_world_host == null or not is_instance_valid(_map_world_host):
		return
	if _map_world_host.has_method("clear_transient_canvas_items"):
		_map_world_host.call("clear_transient_canvas_items")
	else:
		_map_world_host.visible = false


func clear_transient_canvas_items() -> void:
	_clear_map_world_host()
	if _r3_production and _r3_entry_host != null and is_instance_valid(_r3_entry_host):
		_r3_entry_host.call("teardown_scene")


func _exit_tree() -> void:
	clear_transient_canvas_items()


func _ensure_character_info_overlay_host() -> void:
	if _character_info_overlay_host != null and is_instance_valid(_character_info_overlay_host):
		return
	var host := PlazaCharacterInfoOverlayHost.new()
	host.name = "PlazaCharacterInfoOverlayHost"
	host.position = Vector2.ZERO
	host.size = size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The live plaza root is driven above battle/result UI at z_index=1200.
	# Keep this child relative so TAB-opened character info is not stranded
	# below the plaza's opaque draw pass in the result-controller path.
	host.z_as_relative = true
	host.z_index = 120
	add_child(host)
	_character_info_overlay_host = host
	_sync_character_info_overlay_host()


func _sync_character_info_overlay_host() -> void:
	if _character_info_overlay_host == null or not is_instance_valid(_character_info_overlay_host):
		return
	_character_info_overlay_host.position = Vector2.ZERO
	_character_info_overlay_host.size = size
	if _character_info_overlay_host.has_method("configure"):
		_character_info_overlay_host.configure(_runtime_owner, _runtime_registry, Callable(self, "_get_runtime_instance"))


func _open_character_info_overlay() -> void:
	_ensure_character_info_overlay_host()
	_sync_character_info_overlay_host()
	if _character_info_overlay_host != null and _character_info_overlay_host.has_method("open"):
		_character_info_overlay_host.open(_runtime_owner, _runtime_registry, Callable(self, "_get_runtime_instance"))
	queue_redraw()


func _close_character_info_overlay(from_input: bool = false) -> void:
	if _character_info_overlay_host == null or not is_instance_valid(_character_info_overlay_host):
		return
	if _character_info_overlay_host.has_method("close"):
		_character_info_overlay_host.close(from_input)


func _is_character_info_overlay_active() -> bool:
	return _character_info_overlay_host != null and is_instance_valid(_character_info_overlay_host) and _character_info_overlay_host.has_method("is_active") and bool(_character_info_overlay_host.is_active())


func _get_character_info_overlay_status() -> Dictionary:
	if _character_info_overlay_host == null or not is_instance_valid(_character_info_overlay_host):
		return {"active": false, "visible": false}
	if _character_info_overlay_host.has_method("get_status"):
		var value: Variant = _character_info_overlay_host.get_status()
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {
		"active": _is_character_info_overlay_active(),
		"visible": bool(_character_info_overlay_host.visible),
	}


func _ensure_warp_pillar_fx_host() -> void:
	if _warp_pillar_fx_host != null and is_instance_valid(_warp_pillar_fx_host):
		return
	_warp_pillar_fx_host = PlazaWarpPillarFxHost.new()
	_warp_pillar_fx_host.name = "PlazaWarpPillarFxHost"
	_warp_pillar_fx_host.set_process(false)
	add_child(_warp_pillar_fx_host)
	_warp_pillar_fx_host.set_active(false)


func _sync_warp_pillar_fx_host() -> void:
	if _r3_production:
		if _warp_pillar_fx_host != null and is_instance_valid(_warp_pillar_fx_host):
			_warp_pillar_fx_host.set_active(false)
		return
	if not is_inside_tree():
		return
	_ensure_warp_pillar_fx_host()
	if _warp_pillar_fx_host == null or not _warp_pillar_fx_host.has_method("sync_state"):
		return
	if not _transition_state.warp_active:
		_warp_pillar_fx_host.sync_state([], false)
		return
	var scale := _get_game_scale()
	var progress := _get_plaza_warp_progress()
	var actor_states: Array[Dictionary] = []
	actor_states.append({
		"screen_pos": _world_to_local(_player_pos, scale),
		"progress": progress,
		"phase": _transition_state.warp_phase,
		"strength": 1.0,
	})
	if _is_lingpet_companion_visible():
		actor_states.append({
			"screen_pos": _world_to_local(_lingpet_follower_pos, scale),
			"progress": progress,
			"phase": _transition_state.warp_phase,
			"strength": 0.66,
		})
	_warp_pillar_fx_host.sync_state(actor_states, true)


func _get_warp_pillar_fx_status() -> Dictionary:
	if _warp_pillar_fx_host == null or not is_instance_valid(_warp_pillar_fx_host):
		return {"active": false, "actor_count": 0}
	var actor_count := 0
	if _warp_pillar_fx_host.has_method("get_active_actor_count"):
		actor_count = int(_warp_pillar_fx_host.get_active_actor_count())
	return {
		"active": bool(_warp_pillar_fx_host.visible),
		"actor_count": actor_count,
	}


func _draw_overlay_ui(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	_draw_minimap(scale)
	if _transition_state.warp_active:
		return
	if _transition_state.building_active:
		return
	if _menu_session.is_open:
		return
	var active_building := _get_interactable_building()
	if not active_building.is_empty():
		var label := "%s  Space" % str(active_building.get("display_name", "건물"))
		var panel := Rect2(Vector2(244.0, 684.0) * scale, Vector2(272.0, 42.0) * scale)
		draw_rect(panel, Color(0.02, 0.04, 0.07, 0.72), true)
		draw_rect(panel, Color(0.0, 0.88, 1.0, 0.55), false, max(1.0, 1.5 * scale))
		draw_string(font, panel.position + Vector2(20.0, 28.0) * scale, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(18.0 * scale), Color(0.88, 1.0, 1.0, 0.96))
	if _dialog_timer > 0.0 and _dialog_text != "":
		var dialog := Rect2(Vector2(130.0, 610.0) * scale, Vector2(500.0, 62.0) * scale)
		draw_rect(dialog, Color(0.02, 0.018, 0.05, 0.88), true)
		draw_rect(dialog, Color(1.0, 0.32, 0.92, 0.72), false, max(1.0, 2.0 * scale))
		draw_string(font, dialog.position + Vector2(22.0, 39.0) * scale, _dialog_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(22.0 * scale), Color(1.0, 0.94, 1.0, 1.0))


func _get_interior_npc_texture(building_type: String) -> Texture2D:
	if building_type == "":
		return null
	var texture: Variant = _interior_npc_textures.get(building_type, null)
	return texture if texture is Texture2D else null


func _get_interior_room_texture(building_type: String) -> Texture2D:
	if building_type == "":
		return null
	var texture: Variant = _interior_room_textures.get(building_type, null)
	return texture if texture is Texture2D else null


func _draw_minimap(scale: float) -> void:
	PlazaMinimapRenderer.draw(self, _build_minimap_state(), scale)


func _build_minimap_state() -> Dictionary:
	return PlazaMinimapProjection.build(
		_building_specs,
		_camera_x,
		_player_pos.x,
		GAME_SIZE.x,
		MAP_SIZE.x,
		EXIT_ZONE.get_center().x
	)


func _get_minimap_building_color(building_type: String) -> Color:
	for spec in _building_specs:
		if str(spec.get("type", "")) != building_type:
			continue
		var marker_color_value: Variant = spec.get("marker_color", null)
		if marker_color_value is Color:
			return marker_color_value as Color
	return PlazaMinimapProjection.get_building_color(building_type)


func _world_to_local(world_pos: Vector2, scale: float) -> Vector2:
	return PlazaWorldGeometry.world_to_local(world_pos, _camera_x, scale)


func _world_rect_to_local(world_rect: Rect2, scale: float) -> Rect2:
	return PlazaWorldGeometry.world_rect_to_local(world_rect, _camera_x, scale)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return PlazaWorldGeometry.screen_to_world(
		screen_pos,
		get_global_rect().position,
		_camera_x,
		_get_game_scale()
	)


func _get_exit_zone_screen_rect() -> Rect2:
	return _world_rect_to_local(EXIT_ZONE, _get_game_scale())


func _event_position_or_player(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return _world_to_local(_player_pos, _get_game_scale())


func _get_interactable_building() -> Dictionary:
	return PlazaWorldGeometry.find_interactable_building(_building_specs, _player_pos)


func _get_building_at_world_pos(world_pos: Vector2) -> Dictionary:
	return PlazaWorldGeometry.find_building_at_world_position(_building_specs, world_pos)


func _update_hovered_building() -> void:
	var active_building := _get_interactable_building()
	_hovered_building_type = str(active_building.get("type", ""))


func _try_interact() -> bool:
	if _menu_session.is_open or _transition_state.building_active or _transition_state.warp_active:
		return false
	if _r3_production:
		if _r3_entry_host == null or not is_instance_valid(_r3_entry_host):
			return false
		var interaction := _r3_entry_host.call("try_interact") as Dictionary
		if not bool(interaction.get("valid", false)):
			return false
		if str(interaction.get("interaction_kind", "")) == "exit":
			_exit_plaza()
			return true
		if str(interaction.get("interaction_kind", "")) != "building":
			return false
		var building := (interaction.get("building", {}) as Dictionary).duplicate(true)
		building["type"] = str(interaction.get("building_type", building.get("type", "")))
		building["r3_interaction"] = interaction.duplicate(true)
		_r3_pending_interaction = interaction.duplicate(true)
		_show_building_dialog(building)
		return true
	if EXIT_ZONE.has_point(_player_pos):
		_exit_plaza()
		return true
	var building := _get_interactable_building()
	if building.is_empty():
		return false
	_show_building_dialog(building)
	return true


func _show_building_dialog(building: Dictionary) -> void:
	_start_building_enter_transition(building)


func _open_building_menu(building: Dictionary) -> void:
	var building_type := str(building.get("type", ""))
	var menu_state := PlazaBuildingMenuCatalog.build_open_state(
		building_type,
		str(building.get("display_name", "건물"))
	)
	_refresh_plaza_save_snapshot()
	var actions: Variant = menu_state.get("actions", [])
	if building_type == "academy":
		actions = PlazaAcademyTransactions.get_menu_action_labels()
	if building_type == "lingpet_store":
		actions = PlazaLingpetStoreTransactions.get_menu_action_labels(_runtime_registry)
	if building_type == "tavern":
		actions = PlazaTavernTransactions.get_menu_action_labels()
	_menu_session.open_menu(
		building_type,
		str(menu_state.get("title", building.get("display_name", "건물"))),
		str(menu_state.get("subtitle", "")),
		actions
	)
	if building_type == "shop":
		_refresh_shop_inventory_for_visit()
	_transaction_summaries.clear_all()
	_dialog_text = ""
	_dialog_timer = 0.0
	_open_interior_view()
	queue_redraw()


func _open_interior_view() -> void:
	# Retained children survive immediate-mode early returns unless explicitly
	# failed closed before the interior takes ownership of the canvas.
	_clear_map_world_host()
	_free_interior_view()
	var view := PlazaInteriorView.new()
	_interior_view = view
	view.name = "PlazaInteriorView"
	view.position = Vector2.ZERO
	view.size = size
	# IGNORE so the view never consumes GUI mouse: input is forwarded via handle_plaza_input.
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	view.configure(
		_build_interior_view_data(),
		Callable(self, "_close_building_menu"),
		Callable(self, "_trigger_interior_action")
	)


func _ensure_interior_view() -> bool:
	if not _menu_session.is_open:
		return false
	if not _is_interior_view_active():
		_open_interior_view()
	return _is_interior_view_active()


func _sync_interior_view_state() -> void:
	if not _is_interior_view_active():
		return
	_interior_view.size = size
	if _interior_view.has_method("update_state"):
		_interior_view.update_state(_build_interior_view_data())


func _free_interior_view() -> void:
	if _interior_view != null and is_instance_valid(_interior_view):
		_interior_view.queue_free()
	_interior_view = null


func _is_interior_view_active() -> bool:
	return _interior_view != null and is_instance_valid(_interior_view)


func _get_interior_view_status() -> Dictionary:
	if not _is_interior_view_active() or not _interior_view.has_method("get_status"):
		return {}
	var value: Variant = _interior_view.get_status()
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _build_interior_view_data() -> Dictionary:
	return {
		"building_type": _menu_session.building_type,
		"title": _menu_session.title,
		"subtitle": _menu_session.subtitle,
		"actions": _menu_session.actions.duplicate(),
		"last_message": _menu_session.last_message,
		"npc_name": PlazaBuildingMenuCatalog.get_npc_name(_menu_session.building_type),
		"npc_texture": _get_interior_npc_texture(_menu_session.building_type),
		"room_texture": _get_interior_room_texture(_menu_session.building_type),
		"object_textures": _interior_object_textures.duplicate(false),
		"accent_color": _get_minimap_building_color(_menu_session.building_type),
		"save_snapshot": _plaza_save_snapshot.duplicate(true),
		"player_inventory": _get_passive_inventory_snapshot(),
		"shop_inventory": _get_shop_inventory_snapshot(),
		"last_trade_summary": _transaction_summaries.get_summary(PlazaTransactionSummaryStore.SHOP),
	}


func _refresh_shop_inventory_for_visit() -> void:
	if _plaza_shop_stock == null or not _plaza_shop_stock.has_method("build_inventory"):
		_shop_inventory_state.clear()
		return
	var catalog := _get_runtime_instance("mythic_item_catalog")
	var value: Variant = _plaza_shop_stock.build_inventory(catalog, -1, 0, _runtime_registry)
	_shop_inventory_state.replace(value)


func _get_passive_inventory_snapshot() -> Array:
	var mythic_item_runtime := _get_runtime_instance("mythic_item_runtime")
	if mythic_item_runtime == null:
		return []
	var items_value: Variant = mythic_item_runtime.get("inventory_items")
	if not (items_value is Array) and mythic_item_runtime.has_method("get_snapshot"):
		var snapshot_value: Variant = mythic_item_runtime.get_snapshot()
		if snapshot_value is Dictionary:
			items_value = (snapshot_value as Dictionary).get("inventory_items", [])
	var catalog := _get_runtime_instance("mythic_item_catalog")
	return PlazaTradeItemPresentation.project_inventory(items_value, catalog, true)


func _get_shop_inventory_snapshot() -> Array:
	var catalog := _get_runtime_instance("mythic_item_catalog")
	return PlazaTradeItemPresentation.project_inventory(_shop_inventory_state.snapshot(), catalog)


func _get_runtime_instance(key: String) -> Object:
	if _runtime_registry == null or not _runtime_registry.has_method("get_instance"):
		return null
	return _runtime_registry.get_instance(key)


func _duplicate_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item_value in value as Array:
		if item_value is Dictionary:
			result.append((item_value as Dictionary).duplicate(true))
	return result


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _trigger_interior_action(action_value: Variant) -> bool:
	var handled := false
	if action_value is Dictionary:
		handled = _trigger_shop_trade_action(action_value as Dictionary)
	else:
		handled = _trigger_menu_action(int(action_value))
	_sync_interior_view_state()
	return handled


func _start_building_enter_transition(building: Dictionary) -> void:
	if not _transition_state.start_building("enter", building, _player_pos, _lingpet_follower_pos):
		return
	_dialog_text = ""
	_dialog_timer = 0.0
	queue_redraw()


func _start_building_return_transition() -> void:
	if not _transition_state.start_building("return", {}, _player_pos, _lingpet_follower_pos):
		return
	queue_redraw()


func _update_building_transition(delta: float) -> void:
	if not _transition_state.building_active:
		return
	if not _transition_state.advance_building(delta):
		return
	if _transition_state.building_phase == "enter":
		var target := _transition_state.building_target.duplicate(true)
		_clear_building_transition()
		if not target.is_empty():
			if _r3_production:
				var interaction := target.get("r3_interaction", _r3_pending_interaction) as Dictionary
				if _r3_entry_host == null or interaction.is_empty() or not bool(_r3_entry_host.call("enter_interior", interaction)):
					_r3_pending_interaction.clear()
					return
				_r3_pending_interaction.clear()
			_open_building_menu(target)
		return
	_clear_building_transition()


func _complete_building_transition_for_test() -> void:
	if not _transition_state.building_active:
		return
	_update_building_transition(PlazaTransitionState.BUILDING_DURATION)


func _clear_building_transition() -> void:
	_transition_state.clear_building()


func _get_building_transition_progress() -> float:
	return _transition_state.get_building_progress()


func _start_plaza_warp_transition(phase: String) -> void:
	if not _transition_state.start_warp(phase):
		return
	_dialog_text = ""
	_dialog_timer = 0.0
	_sync_warp_pillar_fx_host()
	queue_redraw()


func _update_plaza_warp_transition(delta: float) -> void:
	if not _transition_state.warp_active:
		return
	var completed := _transition_state.advance_warp(delta)
	_sync_warp_pillar_fx_host()
	if not completed:
		return
	var completed_phase := _transition_state.warp_phase
	_clear_plaza_warp_transition()
	if completed_phase == "exit":
		_finish_plaza_exit()


func _clear_plaza_warp_transition() -> void:
	_transition_state.clear_warp()
	_sync_warp_pillar_fx_host()


func _get_plaza_warp_progress() -> float:
	return _transition_state.get_warp_progress()


func _refresh_plaza_save_snapshot() -> void:
	if _plaza_save_store == null or not _plaza_save_store.has_method("get_summary"):
		_plaza_save_snapshot = {}
		return
	_plaza_save_snapshot = _plaza_save_store.get_summary()


func _get_or_create_stage_map_seed(stage_id: int) -> int:
	if _plaza_save_store == null or not _plaza_save_store.has_method("get_or_create_stage_map_seed"):
		return maxi(1, int(abs(hash("plaza_stage_%d" % stage_id))))
	return int(_plaza_save_store.get_or_create_stage_map_seed(stage_id))


func _should_force_tavern_for_current_stage() -> bool:
	var active_quest: Dictionary = _plaza_save_snapshot.get("tavern_active_quest", {})
	if active_quest.is_empty():
		return false
	return int(active_quest.get("accepted_stage", current_stage)) < current_stage


func _trigger_menu_action(action_index: int) -> bool:
	if not _menu_session.is_open:
		return false
	match _menu_session.building_type:
		"bank":
			return _trigger_bank_menu_action(action_index)
		"gacha":
			return _trigger_gacha_menu_action(action_index)
		"lingpet_store":
			return _trigger_lingpet_store_menu_action(action_index)
		"blacksmith":
			return _trigger_blacksmith_menu_action(action_index)
		"academy":
			return _trigger_academy_menu_action(action_index)
		"tavern":
			return _trigger_tavern_menu_action(action_index)
		_:
			_menu_session.set_message("아직 준비 중입니다.")
			queue_redraw()
			return false


func _apply_facility_transaction_outcome(facility: String, summary: Dictionary, message: String) -> bool:
	_transaction_summaries.record(facility, summary)
	if int(summary.get("ap_spent", 0)) > 0:
		_menu_session.mark_visit_ap_consumed()
	_menu_session.set_message(message)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_bank_menu_action(action_index: int) -> bool:
	if action_index < 0 or action_index >= BANK_ACTION_IDS.size():
		return false
	if _plaza_save_store == null or not _plaza_save_store.has_method("perform_bank_transaction"):
		_menu_session.set_message("은행 장부를 열 수 없습니다.")
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_save_store.perform_bank_transaction(
		str(BANK_ACTION_IDS[action_index]),
		current_stage,
		PlazaSaveStore.BANK_TRANSACTION_AMOUNT,
		_menu_session.needs_visit_ap()
	)
	return _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.BANK,
		summary,
		_format_bank_transaction_message(summary)
	)

func _trigger_shop_trade_action(action: Dictionary) -> bool:
	if _menu_session.building_type != "shop":
		return false
	var action_type := str(action.get("type", "shop_trade"))
	if action_type == "shop_trade_reorder":
		return _trigger_shop_trade_reorder_action(action)
	if action_type != "shop_trade":
		return false
	var summary: Dictionary = _plaza_shop_transactions.perform_trade(
		action,
		_shop_inventory_state,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		_menu_session.needs_visit_ap()
	)
	_play_shop_trade_audio(summary)
	return _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.SHOP,
		summary,
		_format_shop_transaction_message(summary)
	)


func _trigger_shop_trade_reorder_action(action: Dictionary) -> bool:
	var changed: bool = bool(_plaza_shop_transactions.reorder_trade(
		action,
		_shop_inventory_state,
		_runtime_owner,
		_runtime_registry
	))
	if changed:
		_menu_session.set_message("아이템 순서를 바꿨습니다.")
		_refresh_plaza_save_snapshot()
		queue_redraw()
	return changed


func _play_shop_trade_audio(summary: Dictionary) -> void:
	if not bool(summary.get("changed", false)):
		return
	var game_audio := _get_runtime_instance("game_audio")
	if game_audio == null:
		return
	var action := str(summary.get("action", ""))
	if action in ["purchase", "sale"] and game_audio.has_method("play_trade"):
		game_audio.play_trade()
	elif game_audio.has_method("play_item_get"):
		game_audio.play_item_get()


func _trigger_gacha_menu_action(action_index: int) -> bool:
	if _plaza_gacha_transactions == null or not _plaza_gacha_transactions.has_method("perform_action"):
		_menu_session.set_message("가챠 장치를 찾을 수 없습니다.")
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_gacha_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		_menu_session.needs_visit_ap()
	)
	return _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.GACHA,
		summary,
		_format_gacha_transaction_message(summary)
	)


func _trigger_lingpet_store_menu_action(action_index: int) -> bool:
	if _plaza_lingpet_store_transactions == null or not _plaza_lingpet_store_transactions.has_method("perform_action"):
		_menu_session.set_message("수호령 장치를 찾을 수 없습니다.")
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_lingpet_store_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		_menu_session.needs_visit_ap()
	)
	_menu_session.set_actions(PlazaLingpetStoreTransactions.get_menu_action_labels(_runtime_registry))
	return _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.LINGPET_STORE,
		summary,
		_format_lingpet_store_transaction_message(summary)
	)


func _trigger_blacksmith_menu_action(action_index: int) -> bool:
	if _plaza_blacksmith_transactions == null or not _plaza_blacksmith_transactions.has_method("perform_action"):
		_menu_session.set_message("대장간 장부를 찾을 수 없습니다.")
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_blacksmith_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_menu_session.needs_visit_ap()
	)
	return _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.BLACKSMITH,
		summary,
		_format_blacksmith_transaction_message(summary)
	)


func _trigger_academy_menu_action(action_index: int) -> bool:
	if _plaza_academy_transactions == null or not _plaza_academy_transactions.has_method("perform_action"):
		_menu_session.set_message("아카데미 장치를 찾을 수 없습니다.")
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_academy_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		_menu_session.needs_visit_ap()
	)
	var changed := _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.ACADEMY,
		summary,
		_format_academy_transaction_message(summary)
	)
	if bool(summary.get("choice_opened", false)):
		var message := _menu_session.last_message
		_close_building_menu(false)
		_dialog_text = message
		_dialog_timer = DIALOG_DURATION
		_update_runtime_perk_overlay(0.0)
	return changed


func _trigger_tavern_menu_action(action_index: int) -> bool:
	if _plaza_tavern_transactions == null or not _plaza_tavern_transactions.has_method("perform_action"):
		_menu_session.set_message("선술집 의뢰 장치를 찾을 수 없습니다.")
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_tavern_transactions.perform_action(
		action_index,
		_plaza_save_store,
		current_stage,
		_menu_session.needs_visit_ap()
	)
	return _apply_facility_transaction_outcome(
		PlazaTransactionSummaryStore.TAVERN,
		summary,
		_format_tavern_transaction_message(summary)
	)


func _format_bank_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_bank(summary)


func _format_shop_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_shop(summary)


func _format_gacha_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_gacha(summary)


func _format_lingpet_store_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_lingpet_store(summary)


func _format_blacksmith_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_blacksmith(summary)


func _format_academy_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_academy(summary)


func _format_tavern_transaction_message(summary: Dictionary) -> String:
	return PlazaTransactionMessageFormatter.format_tavern(summary)


func _close_building_menu(play_return_transition: bool = true) -> void:
	var should_play_return := play_return_transition and _menu_session.is_open and not _transition_state.building_active
	if _r3_production and _menu_session.is_open:
		if _r3_entry_host == null or not bool(_r3_entry_host.call("return_from_interior")):
			return
	_close_character_info_overlay(false)
	_free_interior_view()
	_menu_session.reset()
	_transaction_summaries.clear_on_menu_close()
	if should_play_return:
		_start_building_return_transition()
	queue_redraw()


func _get_blacksmith_target_summary() -> Dictionary:
	if _plaza_blacksmith_transactions == null or not _plaza_blacksmith_transactions.has_method("get_target_summary"):
		return {}
	var result: Variant = _plaza_blacksmith_transactions.get_target_summary(_runtime_owner)
	if result is Dictionary:
		return result
	return {}


func _get_tavern_active_quest_summary() -> Dictionary:
	var quest_value: Variant = _plaza_save_snapshot.get("tavern_active_quest", {})
	if quest_value is Dictionary:
		return (quest_value as Dictionary).duplicate(true)
	return {}


func _get_active_item_slot_count() -> int:
	if _runtime_owner == null:
		return 0
	var value: Variant = _runtime_owner.get("active_item_slots")
	if not (value is Array):
		return 0
	var count := 0
	for item_value in value as Array:
		if item_value is Dictionary:
			var item_data: Dictionary = item_value
			if str(item_data.get("name", item_data.get("effect", ""))) != "":
				count += 1
	return count


func _get_owned_lingpet_count() -> int:
	if _runtime_owner == null:
		return 0
	var owned_lookup := {}
	for key in ["lingpet_owned_pet_ids", "owned_lingpet_ids", "owned_ringpet_ids"]:
		var ids_value: Variant = _runtime_owner.get(str(key))
		if ids_value is Array:
			for raw_id in ids_value as Array:
				var pet_id := str(raw_id).strip_edges()
				if pet_id != "":
					owned_lookup[pet_id] = true
	for key in ["lingpet_collection", "ringpet_collection", "owned_lingpets", "owned_ringpets"]:
		var collection_value: Variant = _runtime_owner.get(str(key))
		if collection_value is Dictionary:
			for raw_id in (collection_value as Dictionary).keys():
				var pet_id := str(raw_id).strip_edges()
				if pet_id != "" and bool((collection_value as Dictionary).get(raw_id, false)):
					owned_lookup[pet_id] = true
	return owned_lookup.size()


func _exit_plaza() -> void:
	if _r3_production:
		_finish_plaza_exit()
		return
	if _transition_state.warp_active:
		return
	_start_plaza_warp_transition("exit")


func _finish_plaza_exit() -> void:
	_plaza_exit_finished = true
	clear_transient_canvas_items()
	if exit_callback.is_valid():
		exit_callback.call()


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value as Array:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
