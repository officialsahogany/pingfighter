extends Control

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaAcademyTransactions := preload("res://scripts/plaza/plaza_academy_transactions.gd")
const PlazaBlacksmithTransactions := preload("res://scripts/plaza/plaza_blacksmith_transactions.gd")
const PlazaGachaTransactions := preload("res://scripts/plaza/plaza_gacha_transactions.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const PlazaShopTransactions := preload("res://scripts/plaza/plaza_shop_transactions.gd")
const PlazaTavernTransactions := preload("res://scripts/plaza/plaza_tavern_transactions.gd")
const PlazaThemeCatalog := preload("res://scripts/plaza/plaza_theme_catalog.gd")
const PlazaInteriorView := preload("res://scripts/plaza/plaza_interior_view.gd")
const PlazaWarpPillarFxHost := preload("res://scripts/plaza/plaza_warp_pillar_fx_host.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const MAP_SIZE := Vector2(1900.0, 750.0)
const CAMERA_SMOOTHING := 0.08
const CAMERA_LEAD_X := 100.0
const FLOOR_REPEAT := 380.0
const GROUND_STRIP_REPEAT := 1140.0
const GROUND_STRIP_HEIGHT := 154.0
const MIDGROUND_WALL_REPEAT := 960.0
const MIDGROUND_WALL_TOP := 388.0
const MIDGROUND_WALL_HEIGHT := 180.0
const MIDGROUND_WALL_ALPHA := 0.90
const MIDGROUND_WALL_TOP_FADE_HEIGHT := 38.0
const MIDGROUND_WALL_TOP_FADE_SLICE := 4.0
const FAR_SKY_WIDTH := 1520.0
const FAR_SKY_HEIGHT := 430.0
const GROUND_Y := 666.0
const BUILDING_BASELINE_Y := 640.0
const SIDEWALK_TOP := 596.0
const SIDEWALK_HEIGHT := 92.0
const UNDERGROUND_TOP := 688.0
const EXIT_ZONE := Rect2(Vector2(MAP_SIZE.x - 150.0, SIDEWALK_TOP), Vector2(120.0, 92.0))
const DIALOG_DURATION := 2.25
const INTERIOR_NPC_RECT := Rect2(Vector2(46.0, 126.0), Vector2(244.0, 420.0))
const INTERIOR_SPEECH_RECT := Rect2(Vector2(40.0, 584.0), Vector2(280.0, 82.0))
const MENU_PANEL_RECT := Rect2(Vector2(326.0, 132.0), Vector2(390.0, 488.0))
const MENU_CLOSE_RECT := Rect2(Vector2(630.0, 148.0), Vector2(58.0, 32.0))
const MENU_ACTION_ROW_START_Y := 124.0
const MENU_ACTION_ROW_HEIGHT := 48.0
const MENU_ACTION_ROW_STEP := 56.0
const BANK_ACTION_IDS := ["deposit", "withdraw", "interest"]
const MINIMAP_PANEL_RECT := Rect2(Vector2(486.0, 18.0), Vector2(238.0, 58.0))
const MINIMAP_TRACK_INSET := Vector2(18.0, 41.0)
const MINIMAP_TRACK_SIZE := Vector2(202.0, 5.0)
const MINIMAP_ICON_SIZE := 15.0
const MINIMAP_ICON_MIN_GAP := 17.0
const PLAYER_SPRITE_DRAW_SIZE := Vector2(148.0, 148.0)
const PLAYER_SPRITE_FOOT_OFFSET := Vector2(0.0, 8.0)
const LINGPET_FOLLOW_OFFSET_X := 58.0
const LINGPET_FOLLOW_OFFSET_Y := -20.0
const LINGPET_COMPANION_GRID_COLS := 5
const LINGPET_COMPANION_GRID_ROWS := 5
const LINGPET_COMPANION_FRAME_COUNT := 25
const BUILDING_ENTRY_DURATION := 1.0
const PLAZA_WARP_DURATION := 1.0

const INTERIOR_NPC_NAMES := {
	"shop": "상점주인 모라",
	"bank": "은행원 도윤",
	"gacha": "가챠 오퍼레이터 루미",
	"lingpet_store": "링펫 사육사 링링",
	"blacksmith": "대장장이 강철",
	"tavern": "선술집 주인 하랑",
	"academy": "아카데미 교관 서율",
}

const INTERIOR_GREETING_LINES := {
	"shop": "어서오세요!|필요한 장비를 골라볼까요?",
	"bank": "금고는 안전합니다.|맡기거나 찾아가세요.",
	"gacha": "캡슐이 돌 준비를|마쳤어요.",
	"lingpet_store": "공명 알이 오늘도|반짝이고 있어요.",
	"blacksmith": "좋은 장비는|망치질을 버팁니다.",
	"tavern": "의뢰서를|확인해 보시겠습니까?",
	"academy": "새 기술을 익힐|준비가 됐나요?",
}

const BUILDING_MENU_SPECS := {
	"shop": {
		"title": "상점",
		"subtitle": "골드로 아이템을 사고파는 곳",
		"actions": ["벽돌 구매 80G", "부메랑 구매 120G", "마지막 아이템 판매"],
	},
	"bank": {
		"title": "은행",
		"subtitle": "골드를 맡기고 찾는 금고",
		"actions": ["예금 100G", "출금 100G", "이자 정산"],
	},
	"gacha": {
		"title": "가챠샵",
		"subtitle": "아이템 뽑기 장치",
		"actions": ["액티브 캡슐 뽑기 150G"],
	},
	"lingpet_store": {
		"title": "링펫스토어",
		"subtitle": "링펫 알과 링펫 관련 상점",
		"actions": ["공명 알 뽑기 250G", "링펫 관리"],
	},
	"blacksmith": {
		"title": "대장간",
		"subtitle": "아이템을 강화하는 공방",
		"actions": ["마지막 아이템 강화"],
	},
	"tavern": {
		"title": "선술집",
		"subtitle": "퀘스트를 받는 의뢰소",
		"actions": ["퀘스트 받기"],
	},
	"academy": {
		"title": "아카데미",
		"subtitle": "액티브 스킬을 얻고 교환하는 곳",
		"actions": ["스킬 획득", "스킬 교환"],
	},
}

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
var _menu_open := false
var _active_menu_type := ""
var _active_menu_title := ""
var _active_menu_subtitle := ""
var _active_menu_actions: Array[String] = []
var _active_menu_last_message := ""
var _active_menu_visit_ap_consumed := false
var _last_bank_transaction_summary: Dictionary = {}
var _last_shop_transaction_summary: Dictionary = {}
var _last_blacksmith_transaction_summary: Dictionary = {}
var _last_gacha_transaction_summary: Dictionary = {}
var _last_lingpet_store_transaction_summary: Dictionary = {}
var _last_academy_transaction_summary: Dictionary = {}
var _last_tavern_transaction_summary: Dictionary = {}
var _plaza_save_store: Object = PlazaSaveStore.new()
var _plaza_shop_transactions: Object = PlazaShopTransactions.new()
var _plaza_blacksmith_transactions: Object = PlazaBlacksmithTransactions.new()
var _plaza_gacha_transactions: Object = PlazaGachaTransactions.new()
var _plaza_lingpet_store_transactions: Object = PlazaLingpetStoreTransactions.new()
var _plaza_academy_transactions: Object = PlazaAcademyTransactions.new()
var _plaza_tavern_transactions: Object = PlazaTavernTransactions.new()
var _runtime_perk_overlay_renderer: Object = RuntimePerkOverlayRenderer.new()
var _runtime_perk_icon_renderer: Object = RuntimePerkIconRenderer.new()
var _plaza_save_snapshot: Dictionary = {}
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
var _building_transition_active := false
var _building_transition_phase := ""
var _building_transition_timer := 0.0
var _building_transition_target: Dictionary = {}
var _building_transition_player_pos := Vector2.ZERO
var _building_transition_lingpet_pos := Vector2.ZERO
var _plaza_warp_active := false
var _plaza_warp_phase := ""
var _plaza_warp_timer := 0.0
var _warp_pillar_fx_host: Node = null
var _interior_view: Control = null
var _last_input_dir := Vector2.RIGHT
var _test_input_active := false
var _test_input_dir := Vector2.ZERO


static func prewarm_assets_step(stage_id: int = 1) -> bool:
	PlazaWarpPillarFxHost.prewarm_assets()
	return PlazaAssetLoader.prewarm_assets_step(stage_id, true)


static func prewarm_assets_threaded_step(stage_id: int = 1) -> bool:
	PlazaWarpPillarFxHost.prewarm_assets()
	return PlazaAssetLoader.prewarm_assets_step(stage_id, true)


static func prewarm_assets_blocking_step(stage_id: int = 1) -> bool:
	PlazaWarpPillarFxHost.prewarm_assets()
	return PlazaAssetLoader.prewarm_assets_step(stage_id, false)


static func get_prewarm_asset_status() -> Dictionary:
	return PlazaAssetLoader.get_prewarm_status()


static func reset_prewarm_assets_for_test() -> void:
	PlazaAssetLoader.reset_for_test()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	set_process(not _driven_by_controller)
	_ensure_warp_pillar_fx_host()
	if plaza_theme.is_empty():
		configure({"current_stage": current_stage}, Callable(), false)
	_sync_warp_pillar_fx_host()
	grab_focus()


func configure(data: Dictionary, on_exit: Callable = Callable(), driven_by_controller: bool = false) -> void:
	_driven_by_controller = driven_by_controller
	set_process(not _driven_by_controller)
	current_stage = PlazaThemeCatalog.normalize_stage_id(int(data.get("current_stage", current_stage)))
	plaza_theme = PlazaThemeCatalog.get_theme(current_stage)
	exit_callback = on_exit
	_runtime_owner = data.get("runtime_owner", null) as Object
	_runtime_registry = data.get("runtime_registry", null) as Object
	_selected_character_type = PlazaAssetLoader.normalize_player_character_type(data.get("selected_character_type", _get_runtime_owner_selected_character_type()))
	_player_textures = PlazaAssetLoader.load_player_textures(_selected_character_type)
	_interior_npc_textures = PlazaAssetLoader.load_interior_npc_textures()
	_interior_room_textures = PlazaAssetLoader.load_interior_room_textures()
	_interior_object_textures = PlazaAssetLoader.load_interior_object_textures()
	_refresh_lingpet_companion_visual()
	var save_path := str(data.get("plaza_save_path", "")).strip_edges()
	if save_path != "" and _plaza_save_store != null and _plaza_save_store.has_method("set_save_path"):
		_plaza_save_store.set_save_path(save_path)
	_floor_textures = PlazaAssetLoader.load_floor_textures(current_stage)
	_refresh_plaza_save_snapshot()
	_full_layout_for_test = bool(data.get("full_layout_for_test", false))
	_map_seed = int(data.get("map_seed", 0))
	if _map_seed <= 0 and not _full_layout_for_test:
		_map_seed = _get_or_create_stage_map_seed(current_stage)
		_refresh_plaza_save_snapshot()
	var force_tavern := _should_force_tavern_for_current_stage()
	_building_specs = PlazaAssetLoader.build_building_specs(
		current_stage,
		_map_seed,
		MAP_SIZE.x,
		_full_layout_for_test,
		force_tavern
	)
	_player_pos = _normalize_player_pos(Vector2(120.0, GROUND_Y))
	_lingpet_follower_initialized = false
	_update_lingpet_follower(0.0)
	_camera_x = _get_target_camera_x()
	_close_building_menu(false)
	_clear_building_transition()
	_clear_plaza_warp_transition()
	if bool(data.get("play_arrival_transition", false)):
		_start_plaza_warp_transition("arrive")
	_dialog_text = ""
	_dialog_timer = 0.0
	_sync_game_rect()
	queue_redraw()


func update_plaza(delta: float) -> void:
	_sync_game_rect()
	if _is_runtime_perk_overlay_active():
		_update_runtime_perk_overlay(delta)
		_dialog_timer = 0.0
		_update_hovered_building()
		queue_redraw()
		return
	if _plaza_warp_active:
		_update_plaza_warp_transition(delta)
		_dialog_timer = 0.0
		_update_hovered_building()
		queue_redraw()
		return
	if _building_transition_active:
		_update_building_transition(delta)
		_dialog_timer = 0.0
		_update_hovered_building()
		queue_redraw()
		return
	if _menu_open:
		_dialog_timer = 0.0
		_update_hovered_building()
		queue_redraw()
		return
	var input_dir := _get_input_dir()
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
	queue_redraw()


func handle_plaza_input(event: InputEvent) -> bool:
	if _is_runtime_perk_overlay_active():
		return _handle_runtime_perk_overlay_input(event)
	if _plaza_warp_active:
		return true
	if _building_transition_active:
		return true
	if _menu_open:
		if _is_interior_view_active():
			return _interior_view.handle_input(_localize_interior_event(event))
		return _handle_menu_input(event)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE:
			_exit_plaza()
			return true
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
			_try_interact()
			return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
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
	var active_building := _get_interactable_building()
	var warp_fx_status := _get_warp_pillar_fx_status()
	var interior_status := _get_interior_view_status()
	return {
		"current_stage": current_stage,
		"theme_id": str(plaza_theme.get("id", "")),
		"side_scroll": true,
		"player_pos": _player_pos,
		"player_collision_rect": PlazaPlayerController.get_collision_rect(_player_pos),
		"camera_x": _camera_x,
		"camera_y": 0.0,
		"ground_y": GROUND_Y,
		"world_size": MAP_SIZE,
		"map_seed": _map_seed,
		"full_layout_for_test": _full_layout_for_test,
		"selected_character_type": _selected_character_type,
		"player_sprite_loaded": bool(_player_textures.get("has_sprite", false)),
		"player_sprite_mode": "sheet" if bool(_player_textures.get("has_sprite", false)) else "neutral_placeholder",
		"player_sprite_frame": _get_player_sprite_frame(),
		"lingpet_companion_visible": _is_lingpet_companion_visible(),
		"lingpet_companion_pet_id": _lingpet_companion_pet_id,
		"lingpet_follower_pos": _lingpet_follower_pos,
		"building_count": _building_specs.size(),
		"collision_rect_count": 0,
		"hovered_building_type": _hovered_building_type,
		"interactable_building_type": str(active_building.get("type", "")),
		"dialog_text": _dialog_text if _dialog_timer > 0.0 else "",
		"menu_open": _menu_open,
		"building_transition_active": _building_transition_active,
		"building_transition_phase": _building_transition_phase,
		"building_transition_progress": _get_building_transition_progress(),
		"plaza_warp_active": _plaza_warp_active,
		"plaza_warp_phase": _plaza_warp_phase,
		"plaza_warp_progress": _get_plaza_warp_progress(),
		"warp_pillar_fx_active": bool(warp_fx_status.get("active", false)),
		"warp_pillar_fx_actor_count": int(warp_fx_status.get("actor_count", 0)),
		"active_menu_type": _active_menu_type,
		"active_menu_title": _active_menu_title,
		"active_menu_subtitle": _active_menu_subtitle,
		"active_menu_actions": _active_menu_actions.duplicate(),
		"active_menu_last_message": _active_menu_last_message,
		"active_menu_visit_ap_consumed": _active_menu_visit_ap_consumed,
		"interior_view_active": _is_interior_view_active(),
		"interior_view_status": interior_status.duplicate(true),
		"interior_room_replaces_plaza": bool(interior_status.get("room_replaces_plaza", false)),
		"interior_panel_open": bool(interior_status.get("panel_open", false)),
		"interior_hovered_object_id": str(interior_status.get("hovered_object_id", "")),
		"interior_selected_object_id": str(interior_status.get("selected_object_id", "")),
		"interior_npc_texture_loaded": _get_interior_npc_texture(_active_menu_type) != null,
		"interior_room_texture_loaded": _get_interior_room_texture(_active_menu_type) != null,
		"interior_object_texture_count": int(interior_status.get("object_texture_count", 0)),
		"last_bank_transaction_summary": _last_bank_transaction_summary.duplicate(true),
		"last_shop_transaction_summary": _last_shop_transaction_summary.duplicate(true),
		"last_blacksmith_transaction_summary": _last_blacksmith_transaction_summary.duplicate(true),
		"last_gacha_transaction_summary": _last_gacha_transaction_summary.duplicate(true),
		"last_lingpet_store_transaction_summary": _last_lingpet_store_transaction_summary.duplicate(true),
		"last_academy_transaction_summary": _last_academy_transaction_summary.duplicate(true),
		"last_tavern_transaction_summary": _last_tavern_transaction_summary.duplicate(true),
		"runtime_perk_choice_active": _is_runtime_perk_overlay_active(),
		"runtime_perk_choice_count": _get_runtime_perk_choice_count(),
		"runtime_perk_selected_index": _get_runtime_perk_selected_index(),
		"plaza_gold": int(_plaza_save_snapshot.get("plaza_gold", 0)),
		"ap_current": int(_plaza_save_snapshot.get("ap_current", 0)),
		"bank_deposit_gold": int(_plaza_save_snapshot.get("bank_deposit_gold", 0)),
		"tavern_active_quest": _get_tavern_active_quest_summary(),
		"active_item_slot_count": _get_active_item_slot_count(),
		"owned_lingpet_count": _get_owned_lingpet_count(),
		"blacksmith_target_summary": _get_blacksmith_target_summary(),
		"exit_zone": EXIT_ZONE,
		"minimap_state": _build_minimap_state(),
		"game_rect": get_global_rect(),
	}


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
	if _menu_open or _building_transition_active or _plaza_warp_active:
		return false
	var building := _get_building_at_world_pos(world_pos)
	if building.is_empty():
		return false
	_show_building_dialog(building)
	_complete_building_transition_for_test()
	return _menu_open


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


func get_flicker_samples_for_test() -> Dictionary:
	return {
		"ground_0": _discrete_flicker("ground:0"),
		"ground_1": _discrete_flicker("ground:1140"),
		"accent_0": _discrete_flicker("accent:250"),
		"accent_1": _discrete_flicker("accent:980"),
		"medallion_0": _discrete_flicker("medallion:560"),
		"medallion_1": _discrete_flicker("medallion:1320"),
	}


func get_building_specs_for_test() -> Array[Dictionary]:
	return _building_specs.duplicate(true)


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
		return
	var scale := _get_game_scale()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.014, 0.022, 1.0))
	_draw_parallax_background(scale)
	_draw_ground_strip(scale)
	_draw_exit_zone(scale)
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
	var scale: float = min(view_size.x / GAME_SIZE.x, view_size.y / GAME_SIZE.y)
	size = GAME_SIZE * scale
	position = (view_size - size) * 0.5
	if _is_interior_view_active():
		_interior_view.position = Vector2.ZERO
		_interior_view.size = size


func _get_game_scale() -> float:
	return size.x / GAME_SIZE.x if GAME_SIZE.x > 0.0 else 1.0


func _get_target_camera_x() -> float:
	return clampf(_player_pos.x - GAME_SIZE.x * 0.5 + CAMERA_LEAD_X, 0.0, MAP_SIZE.x - GAME_SIZE.x)


func _get_input_dir() -> Vector2:
	if _test_input_active:
		return Vector2(signf(_test_input_dir.x), 0.0)
	var dir_x := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir_x += 1.0
	return Vector2(signf(dir_x), 0.0)


func _handle_menu_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return true
		if key_event.keycode == KEY_ESCAPE:
			_close_building_menu()
			return true
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			_trigger_menu_action(int(key_event.keycode - KEY_1))
			return true
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		var local_pos := _screen_to_local_game(mouse_event.position)
		if MENU_CLOSE_RECT.has_point(local_pos):
			_close_building_menu()
			return true
		var clicked_action := _get_menu_action_index_at(local_pos)
		if clicked_action >= 0:
			_trigger_menu_action(clicked_action)
			return true
		return true
	return true


func _handle_runtime_perk_overlay_input(event: InputEvent) -> bool:
	var runtime_state := _get_runtime_perk_state()
	if runtime_state == null or not runtime_state.has_method("handle_input"):
		return true
	var overlay_event := _localize_runtime_perk_event(event)
	runtime_state.handle_input(overlay_event, _runtime_owner, _runtime_registry, size)
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
	return Vector2(
		clampf(pos.x, PlazaPlayerController.PLAYER_COLLISION_SIZE.x * 0.5, MAP_SIZE.x - PlazaPlayerController.PLAYER_COLLISION_SIZE.x * 0.5),
		GROUND_Y
	)


func _get_runtime_owner_selected_character_type() -> String:
	if _runtime_owner == null:
		return _selected_character_type
	var value: Variant = _runtime_owner.get("selected_character_type")
	if str(value).strip_edges() == "":
		return _selected_character_type
	return str(value)


func _is_player_walking() -> bool:
	if _test_input_active:
		return absf(_test_input_dir.x) > 0.01
	return absf(_get_input_dir().x) > 0.01


func _get_player_facing_direction() -> int:
	return -1 if _last_input_dir.x < -0.01 else 1


func _get_player_sprite_frame() -> int:
	var frame_count: int = max(1, int(_player_textures.get("frame_count", 8)))
	var duration_msec: int = 760 if _is_player_walking() else 1040
	return int(floor(float(Time.get_ticks_msec() % duration_msec) / float(duration_msec) * float(frame_count))) % frame_count


func _get_sheet_frame_rect(texture: Texture2D, frame: int, grid_cols: int, grid_rows: int) -> Rect2:
	if texture == null:
		return Rect2()
	var safe_cols: int = max(1, grid_cols)
	var safe_rows: int = max(1, grid_rows)
	var max_frame: int = max(0, safe_cols * safe_rows - 1)
	var safe_frame: int = clampi(frame, 0, max_frame)
	var texture_size: Vector2 = texture.get_size()
	var cell_size := Vector2(texture_size.x / float(safe_cols), texture_size.y / float(safe_rows))
	var col: int = safe_frame % safe_cols
	@warning_ignore("integer_division")
	var row: int = int(safe_frame / safe_cols)
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


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
	var facing := _get_player_facing_direction()
	var target_x := clampf(
		_player_pos.x - float(facing) * LINGPET_FOLLOW_OFFSET_X,
		PlazaPlayerController.PLAYER_COLLISION_SIZE.x * 0.5,
		MAP_SIZE.x - PlazaPlayerController.PLAYER_COLLISION_SIZE.x * 0.5
	)
	var target_pos := Vector2(target_x, GROUND_Y + LINGPET_FOLLOW_OFFSET_Y)
	if not _lingpet_follower_initialized:
		_lingpet_follower_pos = target_pos
		_lingpet_follower_initialized = true
		return
	var blend := clampf(max(0.0, delta) * 60.0 * 0.12, 0.0, 1.0)
	_lingpet_follower_pos = _lingpet_follower_pos.lerp(target_pos, blend)


func _draw_parallax_background(scale: float) -> void:
	_draw_sky_gradient(scale)
	if not _draw_far_sky_asset(scale):
		_draw_moon(scale)
		_draw_cloud_band(scale, 0.16, 92.0, Color(0.40, 0.66, 0.70, 0.58))
		_draw_cloud_band(scale, 0.28, 152.0, Color(0.15, 0.31, 0.45, 0.64))
	_draw_midground_wall(scale)


func _draw_sky_gradient(scale: float) -> void:
	var bands := 10
	for idx in range(bands):
		var t := float(idx) / float(max(1, bands - 1))
		var color := Color(0.025 + t * 0.035, 0.045 + t * 0.04, 0.105 + t * 0.07, 1.0)
		draw_rect(Rect2(Vector2(0.0, GAME_SIZE.y * t * 0.62) * scale, Vector2(GAME_SIZE.x, GAME_SIZE.y * 0.07) * scale), color, true)


func _draw_far_sky_asset(scale: float) -> bool:
	var sky_texture: Texture2D = _floor_textures.get("far_sky", null)
	if sky_texture == null:
		return false
	var x := -clampf(_camera_x * 0.04, 0.0, FAR_SKY_WIDTH - GAME_SIZE.x)
	draw_texture_rect(
		sky_texture,
		Rect2(Vector2(x, 0.0) * scale, Vector2(FAR_SKY_WIDTH, FAR_SKY_HEIGHT) * scale),
		false,
		Color(1.0, 1.0, 1.0, 0.96)
	)
	return true


func _draw_moon(scale: float) -> void:
	var moon_center := Vector2(645.0 - _camera_x * 0.04, 116.0) * scale
	draw_circle(moon_center, 78.0 * scale, Color(0.78, 0.94, 0.73, 0.88))
	draw_circle(moon_center + Vector2(-26.0, 14.0) * scale, 12.0 * scale, Color(0.55, 0.75, 0.58, 0.22))
	draw_circle(moon_center + Vector2(22.0, -16.0) * scale, 18.0 * scale, Color(0.50, 0.70, 0.58, 0.18))


func _draw_cloud_band(scale: float, parallax: float, y: float, color: Color) -> void:
	var tile_width := 420.0
	var offset := fposmod(-_camera_x * parallax, tile_width) - tile_width
	for idx in range(5):
		var x := offset + float(idx) * tile_width
		draw_circle(Vector2(x + 70.0, y) * scale, 42.0 * scale, color)
		draw_circle(Vector2(x + 132.0, y - 18.0) * scale, 58.0 * scale, color)
		draw_circle(Vector2(x + 210.0, y + 4.0) * scale, 46.0 * scale, color)
		draw_rect(Rect2(Vector2(x + 62.0, y - 6.0) * scale, Vector2(188.0, 38.0) * scale), color, true)


func _draw_midground_wall(scale: float) -> void:
	var wall_texture: Texture2D = _floor_textures.get("midground_wall", null)
	if wall_texture != null:
		var texture_offset := fposmod(-_camera_x * 0.48, MIDGROUND_WALL_REPEAT) - MIDGROUND_WALL_REPEAT
		for idx in range(4):
			var texture_x := texture_offset + float(idx) * MIDGROUND_WALL_REPEAT
			_draw_midground_wall_asset_tile(wall_texture, texture_x, scale)
		return
	var parallax := 0.48
	var tile_width := 320.0
	var offset := fposmod(-_camera_x * parallax, tile_width) - tile_width
	var wall_y := 458.0
	for idx in range(8):
		var x := offset + float(idx) * tile_width
		var wall_rect := Rect2(Vector2(x, wall_y) * scale, Vector2(260.0, 98.0) * scale)
		draw_rect(wall_rect, Color(0.045, 0.075, 0.105, 0.88), true)
		draw_rect(wall_rect, Color(0.0, 0.72, 0.86, 0.20), false, max(1.0, 1.0 * scale))
		for post_idx in range(4):
			var post_x := x + 28.0 + float(post_idx) * 68.0
			draw_rect(Rect2(Vector2(post_x, wall_y - 24.0) * scale, Vector2(10.0, 122.0) * scale), Color(0.11, 0.095, 0.065, 0.95), true)
			draw_circle(Vector2(post_x + 5.0, wall_y - 28.0) * scale, 9.0 * scale, Color(0.98, 0.72, 0.26, 0.68))


func _draw_midground_wall_asset_tile(wall_texture: Texture2D, texture_x: float, scale: float) -> void:
	var texture_size := wall_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fade_height := minf(MIDGROUND_WALL_TOP_FADE_HEIGHT, MIDGROUND_WALL_HEIGHT)
	var y := 0.0
	while y < fade_height:
		var slice_height := minf(MIDGROUND_WALL_TOP_FADE_SLICE, fade_height - y)
		var fade_t := (y + slice_height * 0.5) / maxf(1.0, fade_height)
		_draw_midground_wall_asset_region(wall_texture, texture_size, texture_x, y, slice_height, _smooth_unit(fade_t) * MIDGROUND_WALL_ALPHA, scale)
		y += slice_height
	if fade_height < MIDGROUND_WALL_HEIGHT:
		_draw_midground_wall_asset_region(
			wall_texture,
			texture_size,
			texture_x,
			fade_height,
			MIDGROUND_WALL_HEIGHT - fade_height,
			MIDGROUND_WALL_ALPHA,
			scale
		)


func _draw_midground_wall_asset_region(
	wall_texture: Texture2D,
	texture_size: Vector2,
	texture_x: float,
	region_y: float,
	region_height: float,
	alpha: float,
	scale: float
) -> void:
	var source_y := region_y / MIDGROUND_WALL_HEIGHT * texture_size.y
	var source_height := region_height / MIDGROUND_WALL_HEIGHT * texture_size.y
	draw_texture_rect_region(
		wall_texture,
		Rect2(Vector2(texture_x, MIDGROUND_WALL_TOP + region_y) * scale, Vector2(MIDGROUND_WALL_REPEAT, region_height) * scale),
		Rect2(Vector2(0.0, source_y), Vector2(texture_size.x, source_height)),
		Color(1.0, 1.0, 1.0, alpha)
	)


func _draw_ground_strip(scale: float) -> void:
	var ground_strip: Texture2D = _floor_textures.get("ground_strip", null)
	var ground_strip_emissive: Texture2D = _floor_textures.get("ground_strip_emissive", null)
	var base_01: Texture2D = _floor_textures.get("base_01", null)
	var base_02: Texture2D = _floor_textures.get("base_02", null)
	var border: Texture2D = _floor_textures.get("border", null)
	var border_emissive: Texture2D = _floor_textures.get("border_emissive", null)
	var medallion: Texture2D = _floor_textures.get("medallion", null)
	var medallion_emissive: Texture2D = _floor_textures.get("medallion_emissive", null)
	var accent: Texture2D = _floor_textures.get("accent", null)
	var accent_emissive: Texture2D = _floor_textures.get("accent_emissive", null)
	var use_side_cutouts := ground_strip != null
	if use_side_cutouts:
		medallion = _floor_textures.get("medallion_cutout", medallion)
		medallion_emissive = _floor_textures.get("medallion_cutout_emissive", medallion_emissive)
		accent = _floor_textures.get("accent_cutout", accent)
		accent_emissive = _floor_textures.get("accent_cutout_emissive", accent_emissive)
	var first_x: int
	if ground_strip != null:
		first_x = int(floor(_camera_x / GROUND_STRIP_REPEAT)) * int(GROUND_STRIP_REPEAT)
		for world_x in range(first_x - int(GROUND_STRIP_REPEAT), int(_camera_x + GAME_SIZE.x + GROUND_STRIP_REPEAT), int(GROUND_STRIP_REPEAT)):
			var strip_rect := Rect2(Vector2(world_x, SIDEWALK_TOP), Vector2(GROUND_STRIP_REPEAT, GROUND_STRIP_HEIGHT))
			_draw_texture_world(ground_strip, strip_rect, scale)
			var strip_alpha := _flicker_alpha("ground:%d" % world_x, 0.48, 0.18)
			_draw_texture_world(ground_strip_emissive, strip_rect, scale, Color(1.0, 1.0, 1.0, strip_alpha))
	else:
		first_x = int(floor(_camera_x / FLOOR_REPEAT)) * int(FLOOR_REPEAT)
		for world_x in range(first_x - int(FLOOR_REPEAT), int(_camera_x + GAME_SIZE.x + FLOOR_REPEAT), int(FLOOR_REPEAT)):
			var tile_x := int(world_x / int(FLOOR_REPEAT))
			var texture := base_01 if tile_x % 2 == 0 else base_02
			_draw_texture_world(texture, Rect2(Vector2(world_x, SIDEWALK_TOP), Vector2(FLOOR_REPEAT, SIDEWALK_HEIGHT)), scale)
		draw_rect(Rect2(Vector2(0.0, UNDERGROUND_TOP) * scale, Vector2(GAME_SIZE.x, GAME_SIZE.y - UNDERGROUND_TOP) * scale), Color(0.006, 0.011, 0.026, 1.0), true)
		_draw_vr_strata(scale)
		draw_line(Vector2(0.0, UNDERGROUND_TOP) * scale, Vector2(GAME_SIZE.x, UNDERGROUND_TOP) * scale, Color(1.0, 0.32, 0.92, 0.54), max(1.0, 2.0 * scale))
	if use_side_cutouts:
		var border_alpha := _flicker_alpha("border:%d" % first_x, 0.12, 0.14)
		_draw_texture_world(border_emissive, Rect2(Vector2(first_x - FLOOR_REPEAT, SIDEWALK_TOP + 8.0), Vector2(FLOOR_REPEAT * 4.0, 28.0)), scale, Color(1.0, 1.0, 1.0, border_alpha))
	else:
		_draw_texture_world(border, Rect2(Vector2(first_x - FLOOR_REPEAT, SIDEWALK_TOP + 8.0), Vector2(FLOOR_REPEAT * 4.0, 28.0)), scale, Color(1.0, 1.0, 1.0, 0.92))
		_draw_texture_world(border_emissive, Rect2(Vector2(first_x - FLOOR_REPEAT, SIDEWALK_TOP + 8.0), Vector2(FLOOR_REPEAT * 4.0, 28.0)), scale, Color(1.0, 1.0, 1.0, 0.50))
	for pos_x in [560.0, 1320.0, 2080.0, 2840.0]:
		_draw_texture_world(medallion, Rect2(Vector2(pos_x, SIDEWALK_TOP + 20.0), Vector2(118.0, 118.0)), scale)
		var medallion_alpha := _flicker_alpha("medallion:%d" % int(pos_x), 0.34, 0.18)
		_draw_texture_world(medallion_emissive, Rect2(Vector2(pos_x, SIDEWALK_TOP + 20.0), Vector2(118.0, 118.0)), scale, Color(1.0, 1.0, 1.0, medallion_alpha))
	for pos_x in [250.0, 980.0, 1750.0, 2460.0]:
		_draw_texture_world(accent, Rect2(Vector2(pos_x, SIDEWALK_TOP + 28.0), Vector2(96.0, 96.0)), scale)
		var accent_alpha := _flicker_alpha("accent:%d" % int(pos_x), 0.40, 0.18)
		_draw_texture_world(accent_emissive, Rect2(Vector2(pos_x, SIDEWALK_TOP + 28.0), Vector2(96.0, 96.0)), scale, Color(1.0, 1.0, 1.0, accent_alpha))
	draw_line(Vector2(0.0, SIDEWALK_TOP) * scale, Vector2(GAME_SIZE.x, SIDEWALK_TOP) * scale, Color(0.0, 0.9, 1.0, 0.28), max(1.0, 1.5 * scale))


func _draw_vr_strata(scale: float) -> void:
	for layer_idx in range(4):
		var y := UNDERGROUND_TOP + 10.0 + float(layer_idx) * 15.0
		var layer_alpha := _flicker_alpha("strata-line:%d" % layer_idx, 0.14, 0.10)
		var color := Color(0.0, 0.56 + float(layer_idx) * 0.08, 0.86, layer_alpha)
		draw_line(Vector2(0.0, y) * scale, Vector2(GAME_SIZE.x, y + 6.0) * scale, color, max(1.0, 1.0 * scale))
	for idx in range(18):
		var world_x := float(idx) * 180.0 + 40.0
		var local_x := fposmod(world_x - _camera_x * 1.18, GAME_SIZE.x + 180.0) - 90.0
		var h := 8.0 + float((idx * 17) % 19)
		var block_alpha := _flicker_alpha("strata-block:%d" % idx, 0.10, 0.16)
		var color := Color(0.0, 0.92, 1.0, block_alpha)
		draw_rect(Rect2(Vector2(local_x, UNDERGROUND_TOP + 18.0 + float((idx * 13) % 42)) * scale, Vector2(54.0, h) * scale), color, true)


func _draw_exit_zone(scale: float) -> void:
	var rect := _world_rect_to_local(EXIT_ZONE, scale)
	draw_rect(rect, Color(0.0, 0.9, 1.0, 0.12), true)
	draw_rect(rect, Color(0.0, 0.9, 1.0, 0.42), false, max(1.0, 2.0 * scale))
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, rect.position + Vector2(25.0, 55.0) * scale, "나가기", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(22.0 * scale), Color(0.78, 1.0, 1.0, 0.92))


func _draw_world_objects(scale: float) -> void:
	for spec in _building_specs:
		_draw_building(spec, scale)
	if _plaza_warp_active:
		var plaza_warp_progress := _get_plaza_warp_progress()
		var plaza_actor_alpha := _get_plaza_warp_actor_alpha(plaza_warp_progress)
		if plaza_actor_alpha > 0.01:
			var plaza_actor_lift := _get_plaza_warp_actor_lift(plaza_warp_progress)
			_draw_lingpet_follower(scale, plaza_actor_alpha, _lingpet_follower_pos + Vector2(0.0, plaza_actor_lift * 0.72))
			_draw_player(scale, plaza_actor_alpha, _player_pos + Vector2(0.0, plaza_actor_lift))
		return
	if _building_transition_active:
		var transition_progress := _get_building_transition_progress()
		var actor_alpha := _get_building_transition_actor_alpha(transition_progress)
		if actor_alpha > 0.01:
			var actor_lift := _get_building_transition_actor_lift(transition_progress)
			_draw_lingpet_follower(scale, actor_alpha, _building_transition_lingpet_pos + Vector2(0.0, actor_lift * 0.72))
			_draw_player(scale, actor_alpha, _building_transition_player_pos + Vector2(0.0, actor_lift))
		return
	_draw_lingpet_follower(scale)
	_draw_player(scale)


func _draw_building(spec: Dictionary, scale: float) -> void:
	var base_texture: Texture2D = spec.get("base_texture", null)
	if base_texture == null:
		return
	var world_rect: Rect2 = spec.get("visual_rect", Rect2())
	if world_rect.size == Vector2.ZERO:
		var source_size: Vector2 = spec.get("source_size", Vector2.ONE)
		var origin_pivot: Vector2 = spec.get("origin_pivot", source_size * 0.5)
		var display_scale: float = float(spec.get("display_scale", 1.0))
		var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
		world_rect = Rect2(pivot_pos - origin_pivot * display_scale, source_size * display_scale)
	var local_rect := _world_rect_to_local(world_rect, scale)
	if local_rect.position.x > size.x + 80.0 or local_rect.end.x < -80.0:
		return
	var shadow_rect := Rect2(Vector2(local_rect.position.x + local_rect.size.x * 0.12, BUILDING_BASELINE_Y * scale), Vector2(local_rect.size.x * 0.76, 18.0 * scale))
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.22), true)
	draw_texture_rect(base_texture, local_rect, false)
	var sign_texture: Texture2D = spec.get("sign_texture", null)
	var window_texture: Texture2D = spec.get("window_texture", null)
	var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
	var flicker_seed := "%s:%d" % [str(spec.get("type", "")), int(round(pivot_pos.x))]
	var pulse: float = _discrete_flicker(flicker_seed)
	if sign_texture != null:
		draw_texture_rect(sign_texture, local_rect, false, Color(1.0, 1.0, 1.0, 0.72 + pulse * 0.22))
	if window_texture != null:
		draw_texture_rect(window_texture, local_rect, false, Color(1.0, 0.93, 0.78, 0.56 + pulse * 0.12))


func _draw_player(scale: float, alpha: float = 1.0, world_pos: Vector2 = Vector2.INF) -> void:
	var draw_world_pos := _player_pos if world_pos == Vector2.INF else world_pos
	if _draw_player_sheet(scale, alpha, draw_world_pos):
		return
	_draw_player_placeholder(scale, alpha, draw_world_pos)


func _draw_player_sheet(scale: float, alpha: float = 1.0, world_pos: Vector2 = Vector2.INF) -> bool:
	if not bool(_player_textures.get("has_sprite", false)):
		return false
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if safe_alpha <= 0.01:
		return true
	var moving := _is_player_walking()
	var direction := _get_player_facing_direction()
	var texture: Texture2D = null
	if moving:
		var key := "walk_left" if direction < 0 else "walk_right"
		texture = _player_textures.get(key, null)
	if texture == null:
		texture = _player_textures.get("idle", null)
	if texture == null:
		texture = _player_textures.get("walk_left", null) if direction < 0 else _player_textures.get("walk_right", null)
	if texture == null:
		return false
	var src_rect := _get_sheet_frame_rect(texture, _get_player_sprite_frame(), int(_player_textures.get("grid_cols", 4)), int(_player_textures.get("grid_rows", 2)))
	var draw_world_pos := _player_pos if world_pos == Vector2.INF else world_pos
	var local := _world_to_local(draw_world_pos, scale)
	var draw_size := PLAYER_SPRITE_DRAW_SIZE * scale
	var draw_rect := Rect2(
		local + (PLAYER_SPRITE_FOOT_OFFSET - Vector2(PLAYER_SPRITE_DRAW_SIZE.x * 0.5, PLAYER_SPRITE_DRAW_SIZE.y)) * scale,
		draw_size
	)
	_draw_ground_shadow(local + Vector2(0.0, 6.0) * scale, 24.0 * scale, 8.5 * scale, safe_alpha)
	draw_texture_rect_region(texture, draw_rect, src_rect, Color(1.0, 1.0, 1.0, safe_alpha))
	return true


func _draw_player_placeholder(scale: float, alpha: float = 1.0, world_pos: Vector2 = Vector2.INF) -> void:
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if safe_alpha <= 0.01:
		return
	var draw_world_pos := _player_pos if world_pos == Vector2.INF else world_pos
	var local := _world_to_local(draw_world_pos, scale)
	_draw_ground_shadow(local + Vector2(0.0, 6.0) * scale, 23.0 * scale, 8.0 * scale, safe_alpha)
	draw_rect(Rect2(local + Vector2(-15.0, -56.0) * scale, Vector2(30.0, 52.0) * scale), Color(0.30, 0.34, 0.38, 0.96 * safe_alpha), true)
	draw_rect(Rect2(local + Vector2(-17.0, -58.0) * scale, Vector2(34.0, 56.0) * scale), Color(0.74, 0.82, 0.88, 0.55 * safe_alpha), false, max(1.0, 2.0 * scale))
	draw_circle(local + Vector2(0.0, -74.0) * scale, 15.0 * scale, Color(0.68, 0.70, 0.72, safe_alpha))
	draw_line(local + Vector2(-9.0, -6.0) * scale, local + Vector2(-16.0, 12.0) * scale, Color(0.66, 0.74, 0.78, 0.9 * safe_alpha), max(1.0, 3.0 * scale))
	draw_line(local + Vector2(9.0, -6.0) * scale, local + Vector2(16.0, 12.0) * scale, Color(0.66, 0.74, 0.78, 0.9 * safe_alpha), max(1.0, 3.0 * scale))


func _draw_lingpet_follower(scale: float, alpha: float = 1.0, world_pos: Vector2 = Vector2.INF) -> void:
	if not _is_lingpet_companion_visible():
		return
	var safe_alpha := clampf(alpha, 0.0, 1.0)
	if safe_alpha <= 0.01:
		return
	var draw_world_pos := _lingpet_follower_pos if world_pos == Vector2.INF else world_pos
	var local := _world_to_local(draw_world_pos, scale)
	var draw_size := Vector2(_lingpet_companion_draw_size, _lingpet_companion_draw_size) * scale
	var draw_rect := Rect2(local + Vector2(-draw_size.x * 0.5, -draw_size.y + 8.0 * scale), draw_size)
	_draw_ground_shadow(local + Vector2(0.0, 6.0) * scale, max(14.0, _lingpet_companion_draw_size * 0.26) * scale, max(5.0, _lingpet_companion_draw_size * 0.095) * scale, safe_alpha * 0.9)
	var frame := int(floor(float(Time.get_ticks_msec() % 2000) / 2000.0 * float(LINGPET_COMPANION_FRAME_COUNT)))
	var src_rect := _get_sheet_frame_rect(_lingpet_companion_texture, frame, LINGPET_COMPANION_GRID_COLS, LINGPET_COMPANION_GRID_ROWS)
	draw_texture_rect_region(_lingpet_companion_texture, draw_rect, src_rect, Color(1.0, 1.0, 1.0, safe_alpha))


# Soft flattened ground contact shadow. Drawn as 3 concentric ellipses (no
# transform -- avoids the draw_set_transform trap) so the edge fades instead of
# reading as a flat gray disc, and the wide/short ratio matches the slight
# top-down plaza view. `intensity` scales with the actor alpha so the shadow
# dissolves together with the warp.
func _draw_ground_shadow(center: Vector2, radius_x: float, radius_y: float, intensity: float) -> void:
	if intensity <= 0.01 or radius_x <= 0.5 or radius_y <= 0.5:
		return
	for layer in [[1.0, 0.06], [0.66, 0.08], [0.36, 0.10]]:
		var s := float(layer[0])
		var a := float(layer[1]) * intensity
		if a <= 0.003:
			continue
		var pts := PackedVector2Array()
		for i in range(24):
			var ang := TAU * float(i) / 24.0
			pts.append(center + Vector2(cos(ang) * radius_x * s, sin(ang) * radius_y * s))
		draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, a))


func _get_building_transition_actor_alpha(progress: float) -> float:
	var eased := _smooth_unit(progress)
	if _building_transition_phase == "return":
		return eased
	return 1.0 - eased


func _get_building_transition_actor_lift(progress: float) -> float:
	var eased := _smooth_unit(progress)
	if _building_transition_phase == "return":
		return -34.0 * (1.0 - eased)
	return -42.0 * eased


func _get_plaza_warp_actor_alpha(progress: float) -> float:
	var eased := _smooth_unit(progress)
	if _plaza_warp_phase == "arrive":
		return eased
	return 1.0 - eased


func _get_plaza_warp_actor_lift(progress: float) -> float:
	var eased := _smooth_unit(progress)
	if _plaza_warp_phase == "arrive":
		return -42.0 * (1.0 - eased)
	return -48.0 * eased


func _ensure_warp_pillar_fx_host() -> void:
	if _warp_pillar_fx_host != null and is_instance_valid(_warp_pillar_fx_host):
		return
	_warp_pillar_fx_host = PlazaWarpPillarFxHost.new()
	_warp_pillar_fx_host.name = "PlazaWarpPillarFxHost"
	_warp_pillar_fx_host.set_process(false)
	add_child(_warp_pillar_fx_host)
	_warp_pillar_fx_host.set_active(false)


func _sync_warp_pillar_fx_host() -> void:
	if not is_inside_tree():
		return
	_ensure_warp_pillar_fx_host()
	if _warp_pillar_fx_host == null or not _warp_pillar_fx_host.has_method("sync_state"):
		return
	if not _plaza_warp_active:
		_warp_pillar_fx_host.sync_state([], false)
		return
	var scale := _get_game_scale()
	var progress := _get_plaza_warp_progress()
	var actor_states: Array[Dictionary] = []
	actor_states.append({
		"screen_pos": _world_to_local(_player_pos, scale),
		"progress": progress,
		"phase": _plaza_warp_phase,
		"strength": 1.0,
	})
	if _is_lingpet_companion_visible():
		actor_states.append({
			"screen_pos": _world_to_local(_lingpet_follower_pos, scale),
			"progress": progress,
			"phase": _plaza_warp_phase,
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
	if _plaza_warp_active:
		return
	if _building_transition_active:
		return
	if _menu_open:
		if _is_interior_view_active():
			return
		_draw_building_menu(font, scale)
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


func _draw_building_menu(font: Font, scale: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.54), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.18, 0.26, 0.12), true)
	_draw_interior_npc_panel(font, scale)
	_draw_interior_speech_panel(font, scale)
	var panel := Rect2(MENU_PANEL_RECT.position * scale, MENU_PANEL_RECT.size * scale)
	var menu_color := _get_minimap_building_color(_active_menu_type)
	draw_rect(panel, Color(0.014, 0.020, 0.038, 0.97), true)
	draw_rect(panel, Color(menu_color.r * 0.12, menu_color.g * 0.12, menu_color.b * 0.12, 0.52), true)
	draw_rect(panel, Color(0.0, 0.86, 1.0, 0.42), false, max(1.0, 2.0 * scale))
	draw_line(
		panel.position + Vector2(18.0, 18.0) * scale,
		panel.position + Vector2(MENU_PANEL_RECT.size.x - 18.0, 18.0) * scale,
		menu_color,
		max(1.0, 1.5 * scale)
	)
	draw_line(
		panel.position + Vector2(0.0, 70.0) * scale,
		panel.position + Vector2(MENU_PANEL_RECT.size.x, 70.0) * scale,
		Color(1.0, 0.32, 0.92, 0.46),
		max(1.0, 1.5 * scale)
	)
	_draw_text_shadow(font, panel.position + Vector2(30.0, 45.0) * scale, _active_menu_title, int(28.0 * scale), Color(1.0, 0.94, 0.76, 1.0))
	if _active_menu_subtitle != "":
		_draw_text_shadow(font, panel.position + Vector2(30.0, 70.0) * scale, _active_menu_subtitle, int(15.0 * scale), Color(0.78, 0.90, 0.96, 0.82))
	var close_rect := Rect2(MENU_CLOSE_RECT.position * scale, MENU_CLOSE_RECT.size * scale)
	draw_rect(close_rect, Color(0.06, 0.10, 0.15, 0.86), true)
	draw_rect(close_rect, Color(0.0, 0.88, 1.0, 0.55), false, max(1.0, 1.2 * scale))
	_draw_text_shadow(font, close_rect.position + Vector2(18.0, 23.0) * scale, "닫기", int(16.0 * scale), Color(0.88, 1.0, 1.0, 0.96))
	var row_y := MENU_PANEL_RECT.position.y + MENU_ACTION_ROW_START_Y
	for idx in range(_active_menu_actions.size()):
		_draw_menu_action_row(font, scale, idx, row_y + float(idx) * MENU_ACTION_ROW_STEP, _active_menu_actions[idx])
	var note_y := MENU_PANEL_RECT.end.y - 38.0
	if _active_menu_type == "bank":
		var ledger_text := "보유 %dG  |  예금 %dG  |  열쇠 %d" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("bank_deposit_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var message := _active_menu_last_message if _active_menu_last_message != "" else "첫 은행 처리 때 열쇠 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	elif _active_menu_type == "shop":
		var shop_ledger_text := "보유 %dG  |  열쇠 %d  |  액티브 %d개" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
			_get_active_item_slot_count(),
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, shop_ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var shop_message := _active_menu_last_message if _active_menu_last_message != "" else "첫 거래 때 열쇠 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, shop_message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	elif _active_menu_type == "gacha":
		var gacha_ledger_text := "보유 %dG  |  열쇠 %d  |  액티브 %d개  |  1회 %dG" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
			_get_active_item_slot_count(),
			PlazaGachaTransactions.PULL_COST,
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, gacha_ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var gacha_message := _active_menu_last_message if _active_menu_last_message != "" else "첫 뽑기 때 열쇠 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, gacha_message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	elif _active_menu_type == "lingpet_store":
		var lingpet_ledger_text := "보유 %dG  |  열쇠 %d  |  링펫 %d종  |  알 %dG" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
			_get_owned_lingpet_count(),
			PlazaLingpetStoreTransactions.EGG_COST,
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, lingpet_ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var lingpet_message := _active_menu_last_message if _active_menu_last_message != "" else "첫 알 뽑기 때 열쇠 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, lingpet_message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	elif _active_menu_type == "tavern":
		var active_quest := _get_tavern_active_quest_summary()
		var offered_quest := PlazaTavernTransactions.get_stage_offer(current_stage)
		var visible_quest := active_quest if not active_quest.is_empty() else offered_quest
		var quest_state := "진행 중" if not active_quest.is_empty() else "제안"
		var tavern_ledger_text := "보유 %dG  |  행동력 %d  |  %s: %s +%dG" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
			quest_state,
			str(visible_quest.get("name", "의뢰")),
			int(visible_quest.get("reward_gold", 0)),
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, tavern_ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var tavern_message := _active_menu_last_message if _active_menu_last_message != "" else "첫 의뢰 처리 때 행동력 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, tavern_message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	elif _active_menu_type == "academy":
		var academy_ledger_text := "보유 %dG  |  행동력 %d  |  수업료 %dG" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
			PlazaAcademyTransactions.LESSON_COST,
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, academy_ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var academy_message := _active_menu_last_message if _active_menu_last_message != "" else "첫 수업 처리 때 행동력 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, academy_message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	elif _active_menu_type == "blacksmith":
		var target_summary := _get_blacksmith_target_summary()
		var target_text := "대상 없음"
		if bool(target_summary.get("has_target", false)):
			target_text = "%s +%d" % [
				str(target_summary.get("display_name", "아이템")),
				int(target_summary.get("level", 0)),
			]
		var blacksmith_ledger_text := "보유 %dG  |  열쇠 %d  |  %s  |  비용 %dG" % [
			int(_plaza_save_snapshot.get("plaza_gold", 0)),
			int(_plaza_save_snapshot.get("ap_current", 0)),
			target_text,
			int(target_summary.get("cost", 0)),
		]
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y - 22.0) * scale, blacksmith_ledger_text, int(15.0 * scale), Color(0.78, 1.0, 0.94, 0.88))
		var blacksmith_message := _active_menu_last_message if _active_menu_last_message != "" else "첫 강화 시도 때 열쇠 1개를 사용합니다."
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, blacksmith_message, int(15.0 * scale), Color(1.0, 0.82, 0.56, 0.92))
	else:
		_draw_text_shadow(font, Vector2(MENU_PANEL_RECT.position.x + 30.0, note_y) * scale, "준비 중", int(16.0 * scale), Color(1.0, 0.72, 0.94, 0.88))


func _draw_interior_npc_panel(font: Font, scale: float) -> void:
	var npc_rect := Rect2(INTERIOR_NPC_RECT.position * scale, INTERIOR_NPC_RECT.size * scale)
	var accent := _get_minimap_building_color(_active_menu_type)
	draw_rect(npc_rect, Color(0.018, 0.025, 0.038, 0.95), true)
	draw_rect(npc_rect, Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.48), true)
	draw_rect(npc_rect, accent, false, max(1.0, 2.0 * scale))
	for idx in range(6):
		var y := INTERIOR_NPC_RECT.position.y + 54.0 + float(idx) * 52.0
		draw_line(
			Vector2(INTERIOR_NPC_RECT.position.x + 14.0, y) * scale,
			Vector2(INTERIOR_NPC_RECT.end.x - 14.0, y - 36.0) * scale,
			Color(accent.r, accent.g, accent.b, 0.11),
			max(1.0, 1.0 * scale)
		)
	var npc_texture := _get_interior_npc_texture(_active_menu_type)
	if npc_texture != null:
		_draw_interior_npc_texture(npc_texture, scale)
	else:
		_draw_interior_npc_placeholder(accent, scale)
	var name_text := str(INTERIOR_NPC_NAMES.get(_active_menu_type, "광장 안내원"))
	_draw_text_shadow(font, (INTERIOR_NPC_RECT.position + Vector2(22.0, INTERIOR_NPC_RECT.size.y - 18.0)) * scale, name_text, int(17.0 * scale), Color(0.94, 0.98, 1.0, 0.96))


func _draw_interior_npc_texture(texture: Texture2D, scale: float) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_rect := Rect2(
		(INTERIOR_NPC_RECT.position + Vector2(8.0, 8.0)) * scale,
		(INTERIOR_NPC_RECT.size - Vector2(16.0, 42.0)) * scale
	)
	var fit_scale: float = min(fit_rect.size.x / texture_size.x, fit_rect.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * fit_scale
	var draw_pos: Vector2 = Vector2(fit_rect.get_center().x - draw_size.x * 0.5, fit_rect.end.y - draw_size.y)
	draw_texture_rect(texture, Rect2(draw_pos, draw_size), false)


func _draw_interior_npc_placeholder(accent: Color, scale: float) -> void:
	var badge_center := INTERIOR_NPC_RECT.position + Vector2(44.0, 44.0)
	draw_circle(badge_center * scale, 23.0 * scale, Color(0.0, 0.0, 0.0, 0.34))
	draw_circle(badge_center * scale, 20.0 * scale, Color(0.018, 0.032, 0.050, 0.94))
	draw_arc(badge_center * scale, 20.0 * scale, 0.0, TAU, 30, accent, max(1.0, 2.0 * scale), true)
	draw_circle(badge_center * scale, 5.8 * scale, accent)
	var center_x := INTERIOR_NPC_RECT.position.x + INTERIOR_NPC_RECT.size.x * 0.52
	var foot_y := INTERIOR_NPC_RECT.end.y - 38.0
	var head_center := Vector2(center_x, foot_y - 248.0)
	draw_circle(head_center * scale, 38.0 * scale, Color(0.78, 0.84, 0.88, 0.94))
	draw_circle((head_center + Vector2(-11.0, -5.0)) * scale, 10.0 * scale, Color(accent.r, accent.g, accent.b, 0.64))
	draw_circle((head_center + Vector2(13.0, -8.0)) * scale, 8.0 * scale, Color(accent.r, accent.g, accent.b, 0.48))
	draw_rect(Rect2((head_center + Vector2(-8.0, 33.0)) * scale, Vector2(16.0, 30.0) * scale), Color(0.60, 0.68, 0.74, 0.92), true)
	var body_rect := Rect2(Vector2(center_x - 48.0, foot_y - 186.0) * scale, Vector2(96.0, 138.0) * scale)
	draw_rect(body_rect, Color(0.20, 0.24, 0.30, 0.96), true)
	draw_rect(body_rect, Color(accent.r, accent.g, accent.b, 0.22), true)
	draw_line(Vector2(center_x - 38.0, foot_y - 154.0) * scale, Vector2(center_x - 84.0, foot_y - 95.0) * scale, Color(0.62, 0.70, 0.76, 0.88), max(1.0, 9.0 * scale))
	draw_line(Vector2(center_x + 38.0, foot_y - 154.0) * scale, Vector2(center_x + 82.0, foot_y - 104.0) * scale, Color(0.62, 0.70, 0.76, 0.88), max(1.0, 9.0 * scale))
	draw_line(Vector2(center_x - 22.0, foot_y - 48.0) * scale, Vector2(center_x - 42.0, foot_y) * scale, Color(0.44, 0.52, 0.60, 0.90), max(1.0, 10.0 * scale))
	draw_line(Vector2(center_x + 22.0, foot_y - 48.0) * scale, Vector2(center_x + 42.0, foot_y) * scale, Color(0.44, 0.52, 0.60, 0.90), max(1.0, 10.0 * scale))


func _draw_interior_speech_panel(font: Font, scale: float) -> void:
	var speech_rect := Rect2(INTERIOR_SPEECH_RECT.position * scale, INTERIOR_SPEECH_RECT.size * scale)
	var accent := _get_minimap_building_color(_active_menu_type)
	draw_rect(speech_rect, Color(0.96, 0.90, 0.82, 0.94), true)
	draw_rect(speech_rect, Color(accent.r, accent.g, accent.b, 0.32), false, max(1.0, 2.0 * scale))
	_draw_text_shadow(font, speech_rect.position + Vector2(16.0, 27.0) * scale, str(INTERIOR_NPC_NAMES.get(_active_menu_type, "광장 안내원")), int(15.0 * scale), Color(0.18, 0.12, 0.08, 1.0))
	var greeting := str(INTERIOR_GREETING_LINES.get(_active_menu_type, "무엇을 도와드릴까요?"))
	var greeting_lines := greeting.split("|", false)
	for idx in range(min(2, greeting_lines.size())):
		draw_string(
			font,
			speech_rect.position + Vector2(16.0, 54.0 + float(idx) * 21.0) * scale,
			str(greeting_lines[idx]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			int(16.0 * scale),
			Color(0.10, 0.08, 0.07, 0.96)
		)


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


func _draw_menu_action_row(font: Font, scale: float, index: int, y: float, label: String) -> void:
	var row := Rect2(Vector2(MENU_PANEL_RECT.position.x + 30.0, y) * scale, Vector2(MENU_PANEL_RECT.size.x - 60.0, MENU_ACTION_ROW_HEIGHT) * scale)
	draw_rect(row, Color(0.06, 0.085, 0.115, 0.76), true)
	draw_rect(row, Color(0.0, 0.76, 0.92, 0.22), false, max(1.0, 1.0 * scale))
	var number_text := "%02d" % (index + 1)
	_draw_text_shadow(font, row.position + Vector2(16.0, 29.0) * scale, number_text, int(16.0 * scale), Color(0.0, 0.92, 1.0, 0.82))
	_draw_text_shadow(font, row.position + Vector2(64.0, 30.0) * scale, label, int(20.0 * scale), Color(0.94, 0.98, 1.0, 0.96))
	var state_text := "실행" if _is_executable_menu_type(_active_menu_type) else "준비 중"
	var state_color := Color(0.72, 1.0, 0.86, 0.82) if _is_executable_menu_type(_active_menu_type) else Color(1.0, 0.72, 0.94, 0.70)
	_draw_text_shadow(font, row.position + Vector2(row.size.x / scale - 86.0, 29.0) * scale, state_text, int(15.0 * scale), state_color)


func _draw_minimap(scale: float) -> void:
	var state := _build_minimap_state()
	var panel_rect: Rect2 = state.get("panel_rect", MINIMAP_PANEL_RECT)
	var track_rect: Rect2 = state.get("track_rect", _get_minimap_track_rect())
	var camera_rect: Rect2 = state.get("camera_rect", Rect2())
	var player_marker: Vector2 = state.get("player_marker", Vector2.ZERO)
	var exit_marker: Vector2 = state.get("exit_marker", Vector2.ZERO)
	var panel_px := Rect2(panel_rect.position * scale, panel_rect.size * scale)
	var track_px := Rect2(track_rect.position * scale, track_rect.size * scale)
	draw_rect(panel_px, Color(0.006, 0.014, 0.026, 0.82), true)
	draw_rect(panel_px, Color(0.0, 0.82, 1.0, 0.46), false, max(1.0, 1.0 * scale))
	draw_line(
		(panel_rect.position + Vector2(10.0, 10.0)) * scale,
		(panel_rect.position + Vector2(panel_rect.size.x - 10.0, 10.0)) * scale,
		Color(0.0, 0.82, 1.0, 0.18),
		max(1.0, 1.0 * scale)
	)
	draw_rect(track_px, Color(0.025, 0.050, 0.072, 0.92), true)
	draw_rect(track_px, Color(0.0, 0.86, 1.0, 0.34), false, max(1.0, 1.0 * scale))
	if camera_rect.size.x > 0.0:
		draw_rect(Rect2(camera_rect.position * scale, camera_rect.size * scale), Color(0.30, 0.78, 1.0, 0.16), true)
	var markers_value: Variant = state.get("building_markers", [])
	if markers_value is Array:
		for marker_value in markers_value:
			if not (marker_value is Dictionary):
				continue
			var marker := marker_value as Dictionary
			var marker_pos: Vector2 = marker.get("position", Vector2.ZERO)
			var icon_pos: Vector2 = marker.get("icon_position", marker_pos + Vector2(0.0, -17.0))
			var marker_color := _get_minimap_building_color(str(marker.get("type", "")))
			draw_line(marker_pos * scale, icon_pos * scale, Color(marker_color.r, marker_color.g, marker_color.b, 0.34), max(1.0, 1.0 * scale))
			draw_rect(Rect2((marker_pos + Vector2(-1.4, -5.0)) * scale, Vector2(2.8, 10.0) * scale), marker_color, true)
			_draw_minimap_building_badge(marker, icon_pos, marker_color, scale)
	draw_line(
		(exit_marker + Vector2(0.0, -8.0)) * scale,
		(exit_marker + Vector2(0.0, 8.0)) * scale,
		Color(1.0, 0.80, 0.30, 0.94),
		max(1.0, 2.0 * scale)
	)
	draw_line(
		(exit_marker + Vector2(-5.0, -4.0)) * scale,
		exit_marker * scale,
		Color(1.0, 0.80, 0.30, 0.86),
		max(1.0, 1.5 * scale)
	)
	draw_line(
		(exit_marker + Vector2(-5.0, 4.0)) * scale,
		exit_marker * scale,
		Color(1.0, 0.80, 0.30, 0.86),
		max(1.0, 1.5 * scale)
	)
	draw_circle(player_marker * scale, 4.6 * scale, Color(0.0, 0.96, 1.0, 0.96))
	draw_circle(player_marker * scale, 2.0 * scale, Color(1.0, 1.0, 1.0, 0.92))


func _build_minimap_state() -> Dictionary:
	var track_rect := _get_minimap_track_rect()
	var marker_y := track_rect.get_center().y
	var camera_start_x := _world_x_to_minimap_x(_camera_x)
	var camera_end_x := _world_x_to_minimap_x(_camera_x + GAME_SIZE.x)
	var building_markers: Array[Dictionary] = []
	for spec in _building_specs:
		var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
		if pivot_pos == Vector2.ZERO:
			var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
			pivot_pos = interaction_rect.get_center()
		var identity_emblem_value: Variant = spec.get("identity_emblem", {})
		var identity_emblem: Dictionary = identity_emblem_value as Dictionary if identity_emblem_value is Dictionary else {}
		building_markers.append({
			"type": str(spec.get("type", "")),
			"identity_emblem_id": str(identity_emblem.get("id", "")),
			"world_x": pivot_pos.x,
			"position": Vector2(_world_x_to_minimap_x(pivot_pos.x), marker_y),
		})
	building_markers = _resolve_minimap_icon_positions(building_markers, track_rect)
	return {
		"panel_rect": MINIMAP_PANEL_RECT,
		"track_rect": track_rect,
		"camera_rect": Rect2(
			Vector2(camera_start_x, track_rect.position.y - 5.0),
			Vector2(max(4.0, camera_end_x - camera_start_x), 15.0)
		),
		"player_marker": Vector2(_world_x_to_minimap_x(_player_pos.x), marker_y),
		"exit_marker": Vector2(_world_x_to_minimap_x(EXIT_ZONE.get_center().x), marker_y),
		"building_markers": building_markers,
	}


func _get_minimap_track_rect() -> Rect2:
	return Rect2(MINIMAP_PANEL_RECT.position + MINIMAP_TRACK_INSET, MINIMAP_TRACK_SIZE)


func _world_x_to_minimap_x(world_x: float) -> float:
	var track_rect := _get_minimap_track_rect()
	var ratio := clampf(world_x / max(1.0, MAP_SIZE.x), 0.0, 1.0)
	return track_rect.position.x + ratio * track_rect.size.x


func _resolve_minimap_icon_positions(markers: Array[Dictionary], track_rect: Rect2) -> Array[Dictionary]:
	if markers.is_empty():
		return markers
	var resolved: Array[Dictionary] = markers.duplicate(true)
	resolved.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("world_x", 0.0)) < float(b.get("world_x", 0.0)))
	var icon_y: float = track_rect.position.y - 17.0
	var left_limit: float = track_rect.position.x + MINIMAP_ICON_SIZE * 0.5
	var right_limit: float = track_rect.end.x - MINIMAP_ICON_SIZE * 0.5
	var icon_positions: Array[float] = []
	for idx in range(resolved.size()):
		var marker_pos: Vector2 = resolved[idx].get("position", Vector2.ZERO)
		var icon_x := clampf(marker_pos.x, left_limit, right_limit)
		if idx > 0:
			icon_x = max(icon_x, icon_positions[idx - 1] + MINIMAP_ICON_MIN_GAP)
		icon_positions.append(icon_x)
	if not icon_positions.is_empty():
		var overflow: float = float(icon_positions[icon_positions.size() - 1]) - right_limit
		if overflow > 0.0:
			for idx in range(icon_positions.size()):
				icon_positions[idx] = float(icon_positions[idx]) - overflow
		var underflow: float = left_limit - float(icon_positions[0])
		if underflow > 0.0:
			for idx in range(icon_positions.size()):
				icon_positions[idx] = float(icon_positions[idx]) + underflow
	for idx in range(resolved.size()):
		resolved[idx]["icon_position"] = Vector2(float(icon_positions[idx]), icon_y)
	return resolved


func _get_minimap_building_color(building_type: String) -> Color:
	match building_type:
		"bank":
			return Color(1.0, 0.78, 0.32, 0.96)
		"tavern":
			return Color(1.0, 0.50, 0.32, 0.92)
		"academy":
			return Color(0.72, 0.66, 1.0, 0.92)
		"shop":
			return Color(0.32, 0.92, 1.0, 0.92)
		"gacha":
			return Color(1.0, 0.32, 0.92, 0.92)
		"lingpet_store":
			return Color(0.45, 1.0, 0.72, 0.92)
		"blacksmith":
			return Color(1.0, 0.62, 0.24, 0.92)
		_:
			return Color(0.88, 0.96, 1.0, 0.86)


func _draw_minimap_building_badge(marker: Dictionary, icon_pos: Vector2, marker_color: Color, scale: float) -> void:
	var building_type := str(marker.get("type", ""))
	var radius := MINIMAP_ICON_SIZE * 0.52
	draw_circle(icon_pos * scale, (radius + 1.7) * scale, Color(0.0, 0.0, 0.0, 0.42))
	draw_circle(icon_pos * scale, radius * scale, Color(0.018, 0.032, 0.050, 0.96))
	draw_circle(icon_pos * scale, (radius - 1.5) * scale, Color(marker_color.r * 0.16, marker_color.g * 0.16, marker_color.b * 0.16, 0.92))
	draw_arc(icon_pos * scale, radius * scale, 0.0, TAU, 20, marker_color, max(1.0, 1.1 * scale), true)
	match building_type:
		"bank":
			_draw_minimap_bank_emblem(icon_pos, marker_color, scale)
		"shop":
			_draw_minimap_shop_emblem(icon_pos, marker_color, scale)
		"gacha":
			_draw_minimap_gacha_emblem(icon_pos, marker_color, scale)
		"lingpet_store":
			_draw_minimap_lingpet_emblem(icon_pos, marker_color, scale)
		"blacksmith":
			_draw_minimap_blacksmith_emblem(icon_pos, marker_color, scale)
		"tavern":
			_draw_minimap_tavern_emblem(icon_pos, marker_color, scale)
		"academy":
			_draw_minimap_academy_emblem(icon_pos, marker_color, scale)
		_:
			draw_circle(icon_pos * scale, 2.6 * scale, marker_color)


func _draw_minimap_bank_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_circle((center + Vector2(-1.5, -0.5)) * scale, 3.4 * scale, Color(1.0, 0.82, 0.34, 0.96))
	draw_arc((center + Vector2(-1.5, -0.5)) * scale, 3.4 * scale, 0.0, TAU, 12, Color(0.16, 0.08, 0.02, 0.92), max(1.0, 0.9 * scale), true)
	draw_line((center + Vector2(-1.5, -3.6)) * scale, (center + Vector2(-1.5, 2.8)) * scale, Color(0.16, 0.08, 0.02, 0.82), max(1.0, 0.8 * scale))
	draw_line((center + Vector2(-4.4, -0.4)) * scale, (center + Vector2(1.4, -0.4)) * scale, Color(0.16, 0.08, 0.02, 0.82), max(1.0, 0.8 * scale))
	draw_line((center + Vector2(2.8, 3.0)) * scale, (center + Vector2(6.0, 3.0)) * scale, color, max(1.0, 1.2 * scale))
	draw_line((center + Vector2(3.4, 0.8)) * scale, (center + Vector2(5.6, 0.8)) * scale, color, max(1.0, 1.2 * scale))


func _draw_minimap_shop_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_circle((center + Vector2(-3.2, -1.8)) * scale, 2.6 * scale, Color(1.0, 0.78, 0.32, 0.96))
	draw_rect(Rect2((center + Vector2(0.0, -2.8)) * scale, Vector2(5.4, 5.4) * scale), Color(color.r, color.g, color.b, 0.92), false, max(1.0, 1.1 * scale))
	draw_line((center + Vector2(0.0, -0.2)) * scale, (center + Vector2(5.4, -0.2)) * scale, color, max(1.0, 0.8 * scale))


func _draw_minimap_gacha_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_circle(center * scale, 4.0 * scale, Color(1.0, 1.0, 1.0, 0.16))
	draw_arc(center * scale, 4.0 * scale, -0.15, TAU * 0.72, 16, color, max(1.0, 1.1 * scale), true)
	draw_line((center + Vector2(2.8, -3.4)) * scale, (center + Vector2(5.3, -1.3)) * scale, color, max(1.0, 1.0 * scale))
	draw_line((center + Vector2(-4.0, 0.0)) * scale, (center + Vector2(4.0, 0.0)) * scale, color, max(1.0, 1.0 * scale))


func _draw_minimap_lingpet_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_circle((center + Vector2(0.0, 0.8)) * scale, 3.4 * scale, Color(0.92, 1.0, 0.88, 0.94))
	draw_circle((center + Vector2(0.0, -2.6)) * scale, 2.4 * scale, Color(0.92, 1.0, 0.88, 0.94))
	draw_arc(center * scale, 5.0 * scale, -0.55, 2.55, 18, color, max(1.0, 1.0 * scale), true)
	draw_arc(center * scale, 5.0 * scale, 2.9, 5.55, 18, color, max(1.0, 1.0 * scale), true)


func _draw_minimap_blacksmith_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_line((center + Vector2(-4.8, -4.0)) * scale, (center + Vector2(1.6, 2.4)) * scale, color, max(1.0, 1.8 * scale))
	draw_rect(Rect2((center + Vector2(-6.0, -5.8)) * scale, Vector2(4.6, 3.0) * scale), Color(1.0, 0.80, 0.42, 0.96), true)
	draw_line((center + Vector2(-3.8, 4.6)) * scale, (center + Vector2(5.2, 4.6)) * scale, color, max(1.0, 1.5 * scale))
	draw_line((center + Vector2(-1.4, 2.4)) * scale, (center + Vector2(2.8, 2.4)) * scale, color, max(1.0, 1.2 * scale))


func _draw_minimap_tavern_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_rect(Rect2((center + Vector2(-4.4, -3.8)) * scale, Vector2(6.2, 7.0) * scale), Color(0.96, 0.84, 0.62, 0.92), true)
	draw_line((center + Vector2(-3.2, -1.6)) * scale, (center + Vector2(0.6, -1.6)) * scale, Color(0.18, 0.10, 0.04, 0.86), max(1.0, 0.8 * scale))
	draw_circle((center + Vector2(4.0, 1.8)) * scale, 2.3 * scale, color)
	draw_line((center + Vector2(4.0, 4.0)) * scale, (center + Vector2(4.0, 5.8)) * scale, color, max(1.0, 0.9 * scale))


func _draw_minimap_academy_emblem(center: Vector2, color: Color, scale: float) -> void:
	draw_rect(Rect2((center + Vector2(-5.6, -3.2)) * scale, Vector2(5.0, 6.0) * scale), Color(0.82, 0.86, 1.0, 0.88), false, max(1.0, 1.0 * scale))
	draw_rect(Rect2((center + Vector2(0.6, -3.2)) * scale, Vector2(5.0, 6.0) * scale), Color(0.82, 0.86, 1.0, 0.88), false, max(1.0, 1.0 * scale))
	draw_line(center * scale, (center + Vector2(0.0, 3.4)) * scale, color, max(1.0, 0.8 * scale))
	draw_circle((center + Vector2(0.0, -5.0)) * scale, 2.1 * scale, color)


func _draw_text_shadow(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(0.84, color.a)))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_texture_world(texture: Texture2D, world_rect: Rect2, scale: float, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var local_rect := _world_rect_to_local(world_rect, scale)
	if local_rect.position.x > size.x or local_rect.end.x < 0.0 or local_rect.position.y > size.y or local_rect.end.y < 0.0:
		return
	draw_texture_rect(texture, local_rect, false, modulate)


func _world_to_local(world_pos: Vector2, scale: float) -> Vector2:
	return Vector2(world_pos.x - _camera_x, world_pos.y) * scale


func _world_rect_to_local(world_rect: Rect2, scale: float) -> Rect2:
	return Rect2(_world_to_local(world_rect.position, scale), world_rect.size * scale)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var global_rect := get_global_rect()
	var scale := _get_game_scale()
	if scale <= 0.0:
		return Vector2.ZERO
	var local_pos := screen_pos - global_rect.position
	return Vector2(local_pos.x / scale + _camera_x, local_pos.y / scale)


func _screen_to_local_game(screen_pos: Vector2) -> Vector2:
	var global_rect := get_global_rect()
	var scale := _get_game_scale()
	if scale <= 0.0:
		return Vector2.ZERO
	return (screen_pos - global_rect.position) / scale


func _get_exit_zone_screen_rect() -> Rect2:
	return _world_rect_to_local(EXIT_ZONE, _get_game_scale())


func _event_position_or_player(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return _world_to_local(_player_pos, _get_game_scale())


func _get_interactable_building() -> Dictionary:
	for spec in _building_specs:
		var rect: Rect2 = spec.get("interaction_rect", Rect2())
		if rect.has_point(_player_pos):
			return spec
	return {}


func _get_building_at_world_pos(world_pos: Vector2) -> Dictionary:
	# Mouse picking hit-tests the full visible building (visual_rect) plus its
	# ground entrance strip (interaction_rect), so clicking anywhere on the
	# structure -- roof/walls included -- opens the menu, not just the base band.
	# Reverse order = front-most (last-drawn) wins on overlapping/adjacent buildings.
	for i in range(_building_specs.size() - 1, -1, -1):
		var spec := _building_specs[i]
		var visual_rect: Rect2 = spec.get("visual_rect", Rect2())
		if visual_rect.size != Vector2.ZERO and visual_rect.has_point(world_pos):
			return spec
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		if interaction_rect.has_point(world_pos):
			return spec
	return {}


func _update_hovered_building() -> void:
	var active_building := _get_interactable_building()
	_hovered_building_type = str(active_building.get("type", ""))


func _try_interact() -> bool:
	if _menu_open or _building_transition_active or _plaza_warp_active:
		return false
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
	var spec: Dictionary = BUILDING_MENU_SPECS.get(building_type, {})
	_refresh_plaza_save_snapshot()
	_menu_open = true
	_active_menu_type = building_type
	_active_menu_title = str(spec.get("title", building.get("display_name", "건물")))
	_active_menu_subtitle = str(spec.get("subtitle", ""))
	_active_menu_actions = _get_string_array(spec.get("actions", []))
	if building_type == "academy":
		_active_menu_actions = PlazaAcademyTransactions.get_menu_action_labels()
	if building_type == "lingpet_store":
		_active_menu_actions = PlazaLingpetStoreTransactions.get_menu_action_labels(_runtime_registry)
	if building_type == "tavern":
		_active_menu_actions = PlazaTavernTransactions.get_menu_action_labels()
	_active_menu_last_message = ""
	_active_menu_visit_ap_consumed = false
	_last_bank_transaction_summary = {}
	_last_shop_transaction_summary = {}
	_last_blacksmith_transaction_summary = {}
	_last_gacha_transaction_summary = {}
	_last_lingpet_store_transaction_summary = {}
	_last_academy_transaction_summary = {}
	_last_tavern_transaction_summary = {}
	_dialog_text = ""
	_dialog_timer = 0.0
	_open_interior_view()
	queue_redraw()


func _open_interior_view() -> void:
	_free_interior_view()
	var view := PlazaInteriorView.new()
	_interior_view = view
	view.name = "PlazaInteriorView"
	view.position = Vector2.ZERO
	view.size = size
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(view)
	view.configure(
		_build_interior_view_data(),
		Callable(self, "_close_building_menu"),
		Callable(self, "_trigger_interior_action")
	)


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
		"building_type": _active_menu_type,
		"title": _active_menu_title,
		"subtitle": _active_menu_subtitle,
		"actions": _active_menu_actions.duplicate(),
		"last_message": _active_menu_last_message,
		"npc_name": str(INTERIOR_NPC_NAMES.get(_active_menu_type, "")),
		"npc_texture": _get_interior_npc_texture(_active_menu_type),
		"room_texture": _get_interior_room_texture(_active_menu_type),
		"object_textures": _interior_object_textures.duplicate(false),
		"accent_color": _get_minimap_building_color(_active_menu_type),
		"save_snapshot": _plaza_save_snapshot.duplicate(true),
	}


func _trigger_interior_action(action_index: int) -> bool:
	var handled := _trigger_menu_action(action_index)
	_sync_interior_view_state()
	return handled


func _start_building_enter_transition(building: Dictionary) -> void:
	if _building_transition_active:
		return
	_building_transition_active = true
	_building_transition_phase = "enter"
	_building_transition_timer = 0.0
	_building_transition_target = building.duplicate(true)
	_building_transition_player_pos = _player_pos
	_building_transition_lingpet_pos = _lingpet_follower_pos
	_dialog_text = ""
	_dialog_timer = 0.0
	queue_redraw()


func _start_building_return_transition() -> void:
	if _building_transition_active:
		return
	_building_transition_active = true
	_building_transition_phase = "return"
	_building_transition_timer = 0.0
	_building_transition_target = {}
	_building_transition_player_pos = _player_pos
	_building_transition_lingpet_pos = _lingpet_follower_pos
	queue_redraw()


func _update_building_transition(delta: float) -> void:
	if not _building_transition_active:
		return
	_building_transition_timer = min(BUILDING_ENTRY_DURATION, _building_transition_timer + max(0.0, delta))
	if _building_transition_timer < BUILDING_ENTRY_DURATION:
		return
	if _building_transition_phase == "enter":
		var target := _building_transition_target.duplicate(true)
		_clear_building_transition()
		if not target.is_empty():
			_open_building_menu(target)
		return
	_clear_building_transition()


func _complete_building_transition_for_test() -> void:
	if not _building_transition_active:
		return
	_update_building_transition(BUILDING_ENTRY_DURATION)


func _clear_building_transition() -> void:
	_building_transition_active = false
	_building_transition_phase = ""
	_building_transition_timer = 0.0
	_building_transition_target = {}
	_building_transition_player_pos = Vector2.ZERO
	_building_transition_lingpet_pos = Vector2.ZERO


func _get_building_transition_progress() -> float:
	if not _building_transition_active:
		return 0.0
	return clampf(_building_transition_timer / max(0.001, BUILDING_ENTRY_DURATION), 0.0, 1.0)


func _start_plaza_warp_transition(phase: String) -> void:
	if _plaza_warp_active:
		return
	_plaza_warp_active = true
	_plaza_warp_phase = phase
	_plaza_warp_timer = 0.0
	_dialog_text = ""
	_dialog_timer = 0.0
	_sync_warp_pillar_fx_host()
	queue_redraw()


func _update_plaza_warp_transition(delta: float) -> void:
	if not _plaza_warp_active:
		return
	_plaza_warp_timer = min(PLAZA_WARP_DURATION, _plaza_warp_timer + max(0.0, delta))
	_sync_warp_pillar_fx_host()
	if _plaza_warp_timer < PLAZA_WARP_DURATION:
		return
	var completed_phase := _plaza_warp_phase
	_clear_plaza_warp_transition()
	if completed_phase == "exit":
		_finish_plaza_exit()


func _clear_plaza_warp_transition() -> void:
	_plaza_warp_active = false
	_plaza_warp_phase = ""
	_plaza_warp_timer = 0.0
	_sync_warp_pillar_fx_host()


func _get_plaza_warp_progress() -> float:
	if not _plaza_warp_active:
		return 0.0
	return clampf(_plaza_warp_timer / max(0.001, PLAZA_WARP_DURATION), 0.0, 1.0)


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
	if not _menu_open:
		return false
	match _active_menu_type:
		"bank":
			return _trigger_bank_menu_action(action_index)
		"shop":
			return _trigger_shop_menu_action(action_index)
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
			_active_menu_last_message = "아직 준비 중입니다."
			queue_redraw()
			return false


func _trigger_bank_menu_action(action_index: int) -> bool:
	if action_index < 0 or action_index >= BANK_ACTION_IDS.size():
		return false
	if _plaza_save_store == null or not _plaza_save_store.has_method("perform_bank_transaction"):
		_active_menu_last_message = "은행 장부를 열 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_save_store.perform_bank_transaction(
		str(BANK_ACTION_IDS[action_index]),
		current_stage,
		PlazaSaveStore.BANK_TRANSACTION_AMOUNT,
		not _active_menu_visit_ap_consumed
	)
	_last_bank_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_bank_transaction_message(summary)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_shop_menu_action(action_index: int) -> bool:
	if _plaza_shop_transactions == null or not _plaza_shop_transactions.has_method("perform_action"):
		_active_menu_last_message = "상점 장부를 찾을 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_shop_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		not _active_menu_visit_ap_consumed
	)
	_last_shop_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_shop_transaction_message(summary)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_gacha_menu_action(action_index: int) -> bool:
	if _plaza_gacha_transactions == null or not _plaza_gacha_transactions.has_method("perform_action"):
		_active_menu_last_message = "가챠 장치를 찾을 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_gacha_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		not _active_menu_visit_ap_consumed
	)
	_last_gacha_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_gacha_transaction_message(summary)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_lingpet_store_menu_action(action_index: int) -> bool:
	if _plaza_lingpet_store_transactions == null or not _plaza_lingpet_store_transactions.has_method("perform_action"):
		_active_menu_last_message = "링펫 장치를 찾을 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_lingpet_store_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		not _active_menu_visit_ap_consumed
	)
	_last_lingpet_store_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_lingpet_store_transaction_message(summary)
	_active_menu_actions = PlazaLingpetStoreTransactions.get_menu_action_labels(_runtime_registry)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_blacksmith_menu_action(action_index: int) -> bool:
	if _plaza_blacksmith_transactions == null or not _plaza_blacksmith_transactions.has_method("perform_action"):
		_active_menu_last_message = "대장간 장부를 찾을 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_blacksmith_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		not _active_menu_visit_ap_consumed
	)
	_last_blacksmith_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_blacksmith_transaction_message(summary)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_academy_menu_action(action_index: int) -> bool:
	if _plaza_academy_transactions == null or not _plaza_academy_transactions.has_method("perform_action"):
		_active_menu_last_message = "아카데미 장치를 찾을 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_academy_transactions.perform_action(
		action_index,
		_plaza_save_store,
		_runtime_owner,
		_runtime_registry,
		not _active_menu_visit_ap_consumed
	)
	_last_academy_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_academy_transaction_message(summary)
	_refresh_plaza_save_snapshot()
	if bool(summary.get("choice_opened", false)):
		var message := _active_menu_last_message
		_close_building_menu(false)
		_last_academy_transaction_summary = summary.duplicate(true)
		_dialog_text = message
		_dialog_timer = DIALOG_DURATION
		_update_runtime_perk_overlay(0.0)
	else:
		queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _trigger_tavern_menu_action(action_index: int) -> bool:
	if _plaza_tavern_transactions == null or not _plaza_tavern_transactions.has_method("perform_action"):
		_active_menu_last_message = "선술집 의뢰 장치를 찾을 수 없습니다."
		queue_redraw()
		return false
	var summary: Dictionary = _plaza_tavern_transactions.perform_action(
		action_index,
		_plaza_save_store,
		current_stage,
		not _active_menu_visit_ap_consumed
	)
	_last_tavern_transaction_summary = summary.duplicate(true)
	if int(summary.get("ap_spent", 0)) > 0:
		_active_menu_visit_ap_consumed = true
	_active_menu_last_message = _format_tavern_transaction_message(summary)
	_refresh_plaza_save_snapshot()
	queue_redraw()
	return bool(summary.get("handled", false)) and bool(summary.get("changed", false))


func _get_menu_action_index_at(local_pos: Vector2) -> int:
	if not _menu_open:
		return -1
	for idx in range(_active_menu_actions.size()):
		var row := Rect2(
			Vector2(MENU_PANEL_RECT.position.x + 30.0, MENU_PANEL_RECT.position.y + MENU_ACTION_ROW_START_Y + float(idx) * MENU_ACTION_ROW_STEP),
			Vector2(MENU_PANEL_RECT.size.x - 60.0, MENU_ACTION_ROW_HEIGHT)
		)
		if row.has_point(local_pos):
			return idx
	return -1


func _format_bank_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"no_plaza_gold":
				return "맡길 골드가 없습니다."
			"no_bank_deposit":
				return "찾거나 정산할 예금이 없습니다."
			"interest_already_claimed":
				return "이번 스테이지 이자는 이미 정산했습니다."
			_:
				return "지금은 처리할 수 없습니다."
	match str(summary.get("action", "")):
		"deposit":
			return "%dG를 예금했습니다." % int(summary.get("delta_deposit", 0))
		"withdraw":
			return "%dG를 출금했습니다." % int(summary.get("delta_gold", 0))
		"interest":
			return "이자 %dG를 받았습니다." % int(summary.get("interest_gold", 0))
	return "처리했습니다."


func _format_shop_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var display_name := str(summary.get("display_name", summary.get("item_name", "")))
	if display_name == "":
		display_name = "아이템"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "골드가 부족합니다."
			"active_slots_full":
				return "액티브 슬롯이 가득 찼습니다."
			"no_active_item":
				return "판매할 액티브 아이템이 없습니다."
			"missing_item_runtime", "missing_owner":
				return "아이템 가방을 찾을 수 없습니다."
			_:
				return "지금은 거래할 수 없습니다."
	match str(summary.get("action", "")):
		"purchase":
			return "%s을(를) 구매했습니다. %dG" % [display_name, int(summary.get("delta_gold", 0))]
		"sale":
			return "%s을(를) 판매했습니다. +%dG" % [display_name, int(summary.get("sell_price", 0))]
	return "거래했습니다."


func _format_gacha_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var display_name := str(summary.get("display_name", summary.get("item_name", "")))
	if display_name == "":
		display_name = "아이템"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "뽑기 비용이 부족합니다."
			"active_slots_full":
				return "액티브 슬롯이 가득 찼습니다."
			"missing_item_runtime", "missing_owner":
				return "아이템 가방을 찾을 수 없습니다."
			"empty_gacha_pool":
				return "뽑기 캡슐이 비어 있습니다."
			_:
				return "지금은 뽑을 수 없습니다."
	return "%s을(를) 뽑았습니다. %dG" % [display_name, int(summary.get("delta_gold", 0))]


func _format_lingpet_store_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	if str(summary.get("action", "")) == "ring_core":
		if not bool(summary.get("changed", false)):
			match reason:
				"no_ap":
					return "행동력이 부족합니다."
				"not_enough_gold":
					return "링코어 강화 비용이 부족합니다."
				"missing_affinity_store":
					return "링코어 장부를 찾을 수 없습니다."
				"max_ring_core_tier":
					return "링코어가 이미 최대 단계입니다."
				"missing_ring_core_price":
					return "링코어 가격표가 비어 있습니다."
				"ring_core_upgrade_failed":
					return "링코어 강화에 실패했습니다."
				_:
					return "지금은 링코어를 강화할 수 없습니다."
		return "%s 링코어가 친밀도 Lv.%d까지 열렸습니다. -%dG" % [
			str(summary.get("ring_core_name", "링코어")),
			int(summary.get("new_cap", 0)),
			abs(int(summary.get("delta_gold", 0))),
		]
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "알 뽑기 비용이 부족합니다."
			"egg_already_active":
				return "이미 깨어날 알이 기다리고 있습니다."
			"no_hatch_candidates":
				return "지금 뽑을 수 있는 새 링펫 알이 없습니다."
			"missing_lingpet_runtime", "missing_owner":
				return "링펫 장치를 찾을 수 없습니다."
			"manage_stub":
				return "링펫 관리는 다음 단계에서 열립니다."
			_:
				return "지금은 알을 뽑을 수 없습니다."
	return "공명 알이 전투에 나타났습니다. -%dG" % abs(int(summary.get("delta_gold", 0)))


func _format_blacksmith_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var display_name := str(summary.get("display_name", summary.get("item_name", "")))
	if display_name == "":
		display_name = "아이템"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "열쇠가 부족합니다."
			"not_enough_gold":
				return "강화 비용이 부족합니다."
			"no_active_item":
				return "강화할 액티브 아이템이 없습니다."
			"max_level":
				return "%s은(는) 이미 최대 강화입니다." % display_name
			"missing_owner":
				return "아이템 가방을 찾을 수 없습니다."
			_:
				return "지금은 강화할 수 없습니다."
	match str(summary.get("result", "")):
		"success":
			return "%s +%d 강화 성공! -%dG" % [
				display_name,
				int(summary.get("new_level", 0)),
				abs(int(summary.get("delta_gold", 0))),
			]
		"maintain":
			return "%s 강화 유지. -%dG" % [display_name, abs(int(summary.get("delta_gold", 0)))]
		"fail":
			return "%s 강화 실패. 아이템은 유지됩니다. -%dG" % [display_name, abs(int(summary.get("delta_gold", 0)))]
	return "강화를 시도했습니다."


func _format_academy_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "행동력이 부족합니다."
			"not_enough_gold":
				return "수업료가 부족합니다."
			"missing_owner":
				return "현재 캐릭터를 찾을 수 없습니다."
			"missing_runtime_perk_state", "missing_runtime_perk_catalog":
				return "스킬 수업 장치를 찾을 수 없습니다."
			"choice_already_active":
				return "이미 진행 중인 스킬 선택이 있습니다."
			"no_academy_choices":
				return "지금 배울 수 있는 스킬이 없습니다."
			"exchange_stub":
				return "스킬 교환은 다음 단계에서 열립니다."
			_:
				return "지금은 수업을 진행할 수 없습니다."
	if bool(summary.get("choice_opened", false)):
		return "스킬 수업을 시작합니다. -%dG" % abs(int(summary.get("delta_gold", 0)))
	return "수업료를 냈지만 선택지를 열지 못했습니다."


func _format_tavern_transaction_message(summary: Dictionary) -> String:
	var reason := str(summary.get("reason", ""))
	var quest_name := str(summary.get("quest_name", "의뢰"))
	if quest_name == "":
		quest_name = "의뢰"
	if not bool(summary.get("changed", false)):
		match reason:
			"no_ap":
				return "행동력이 부족합니다."
			"quest_already_active":
				return "이미 진행 중인 의뢰가 있습니다."
			"stage_already_accepted":
				return "이번 스테이지의 의뢰는 이미 받았습니다."
			"invalid_quest":
				return "의뢰서가 손상되었습니다."
			"no_active_quest":
				return "보고할 의뢰가 없습니다."
			"quest_in_progress":
				return "다음 전투를 마친 뒤 보고할 수 있습니다."
			"missing_plaza_save_store":
				return "의뢰 장부를 찾을 수 없습니다."
			_:
				return "지금은 의뢰를 처리할 수 없습니다."
	match str(summary.get("action", "")):
		"accept":
			return "%s 의뢰를 받았습니다." % quest_name
		"complete":
			return "%s 보고 완료. +%dG" % [quest_name, int(summary.get("delta_gold", 0))]
	return "의뢰를 처리했습니다."


func _close_building_menu(play_return_transition: bool = true) -> void:
	var should_play_return := play_return_transition and _menu_open and not _building_transition_active
	_free_interior_view()
	_menu_open = false
	_active_menu_type = ""
	_active_menu_title = ""
	_active_menu_subtitle = ""
	_active_menu_actions.clear()
	_active_menu_last_message = ""
	_active_menu_visit_ap_consumed = false
	_last_shop_transaction_summary = {}
	_last_blacksmith_transaction_summary = {}
	_last_gacha_transaction_summary = {}
	_last_lingpet_store_transaction_summary = {}
	_last_tavern_transaction_summary = {}
	if should_play_return:
		_start_building_return_transition()
	queue_redraw()


func _is_executable_menu_type(menu_type: String) -> bool:
	return ["bank", "shop", "gacha", "lingpet_store", "blacksmith", "academy", "tavern"].has(menu_type)


func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(str(item))
	return result


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
	if _plaza_warp_active:
		return
	_start_plaza_warp_transition("exit")


func _finish_plaza_exit() -> void:
	if exit_callback.is_valid():
		exit_callback.call()


func _discrete_flicker(seed_text: String) -> float:
	var tick := int(floor(Time.get_ticks_msec() * 0.047))
	var h := int(hash(seed_text)) ^ (tick * 1103515245)
	return float(abs(h) % 1000) / 1000.0


func _flicker_alpha(seed_text: String, base_alpha: float, amplitude: float) -> float:
	return clampf(base_alpha + _discrete_flicker(seed_text) * amplitude, 0.0, 1.0)


func _stable_hash_unit(seed_text: String) -> float:
	return float(abs(int(hash(seed_text))) % 10000) / 10000.0


func _smooth_unit(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
