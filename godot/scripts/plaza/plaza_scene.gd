extends Control

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaBlacksmithTransactions := preload("res://scripts/plaza/plaza_blacksmith_transactions.gd")
const PlazaGachaTransactions := preload("res://scripts/plaza/plaza_gacha_transactions.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")
const PlazaPlayerController := preload("res://scripts/plaza/plaza_player_controller.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const PlazaShopTransactions := preload("res://scripts/plaza/plaza_shop_transactions.gd")
const PlazaThemeCatalog := preload("res://scripts/plaza/plaza_theme_catalog.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const MAP_SIZE := Vector2(3040.0, 750.0)
const CAMERA_SMOOTHING := 0.08
const CAMERA_LEAD_X := 100.0
const FLOOR_REPEAT := 380.0
const GROUND_STRIP_REPEAT := 1140.0
const GROUND_STRIP_HEIGHT := 154.0
const MIDGROUND_WALL_REPEAT := 960.0
const MIDGROUND_WALL_TOP := 388.0
const MIDGROUND_WALL_HEIGHT := 180.0
const FAR_SKY_WIDTH := 1520.0
const FAR_SKY_HEIGHT := 430.0
const GROUND_Y := 666.0
const BUILDING_BASELINE_Y := 640.0
const SIDEWALK_TOP := 596.0
const SIDEWALK_HEIGHT := 92.0
const UNDERGROUND_TOP := 688.0
const EXIT_ZONE := Rect2(Vector2(MAP_SIZE.x - 150.0, SIDEWALK_TOP), Vector2(120.0, 92.0))
const DIALOG_DURATION := 2.25
const MENU_PANEL_RECT := Rect2(Vector2(126.0, 216.0), Vector2(508.0, 352.0))
const MENU_CLOSE_RECT := Rect2(Vector2(534.0, 232.0), Vector2(72.0, 34.0))
const MENU_ACTION_ROW_START_Y := 108.0
const MENU_ACTION_ROW_HEIGHT := 44.0
const MENU_ACTION_ROW_STEP := 58.0
const BANK_ACTION_IDS := ["deposit", "withdraw", "interest"]

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
var _plaza_save_store: Object = PlazaSaveStore.new()
var _plaza_shop_transactions: Object = PlazaShopTransactions.new()
var _plaza_blacksmith_transactions: Object = PlazaBlacksmithTransactions.new()
var _plaza_gacha_transactions: Object = PlazaGachaTransactions.new()
var _plaza_lingpet_store_transactions: Object = PlazaLingpetStoreTransactions.new()
var _plaza_save_snapshot: Dictionary = {}
var _runtime_owner: Object = null
var _runtime_registry: Object = null
var _hovered_building_type := ""
var _last_input_dir := Vector2.RIGHT
var _test_input_active := false
var _test_input_dir := Vector2.ZERO


static func prewarm_assets_step(stage_id: int = 1) -> bool:
	return PlazaAssetLoader.prewarm_assets_step(stage_id, true)


static func prewarm_assets_threaded_step(stage_id: int = 1) -> bool:
	return PlazaAssetLoader.prewarm_assets_step(stage_id, true)


static func prewarm_assets_blocking_step(stage_id: int = 1) -> bool:
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
	if plaza_theme.is_empty():
		configure({"current_stage": current_stage}, Callable(), false)
	grab_focus()


func configure(data: Dictionary, on_exit: Callable = Callable(), driven_by_controller: bool = false) -> void:
	_driven_by_controller = driven_by_controller
	set_process(not _driven_by_controller)
	current_stage = PlazaThemeCatalog.normalize_stage_id(int(data.get("current_stage", current_stage)))
	plaza_theme = PlazaThemeCatalog.get_theme(current_stage)
	exit_callback = on_exit
	_runtime_owner = data.get("runtime_owner", null) as Object
	_runtime_registry = data.get("runtime_registry", null) as Object
	var save_path := str(data.get("plaza_save_path", "")).strip_edges()
	if save_path != "" and _plaza_save_store != null and _plaza_save_store.has_method("set_save_path"):
		_plaza_save_store.set_save_path(save_path)
	_floor_textures = PlazaAssetLoader.load_floor_textures(current_stage)
	_building_specs = PlazaAssetLoader.build_building_specs(current_stage)
	_refresh_plaza_save_snapshot()
	_player_pos = _normalize_player_pos(Vector2(120.0, GROUND_Y))
	_camera_x = _get_target_camera_x()
	_close_building_menu()
	_dialog_text = ""
	_dialog_timer = 0.0
	_sync_game_rect()
	queue_redraw()


func update_plaza(delta: float) -> void:
	_sync_game_rect()
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
	var target_camera_x := _get_target_camera_x()
	var fps_scale: float = max(0.0, delta) * 60.0
	var blend: float = clampf(CAMERA_SMOOTHING * fps_scale, 0.0, 1.0)
	_camera_x = lerpf(_camera_x, target_camera_x, blend)
	_dialog_timer = max(0.0, _dialog_timer - max(0.0, delta))
	_update_hovered_building()
	queue_redraw()


func handle_plaza_input(event: InputEvent) -> bool:
	if _menu_open:
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
		"building_count": _building_specs.size(),
		"collision_rect_count": 0,
		"hovered_building_type": _hovered_building_type,
		"interactable_building_type": str(active_building.get("type", "")),
		"dialog_text": _dialog_text if _dialog_timer > 0.0 else "",
		"menu_open": _menu_open,
		"active_menu_type": _active_menu_type,
		"active_menu_title": _active_menu_title,
		"active_menu_subtitle": _active_menu_subtitle,
		"active_menu_actions": _active_menu_actions.duplicate(),
		"active_menu_last_message": _active_menu_last_message,
		"active_menu_visit_ap_consumed": _active_menu_visit_ap_consumed,
		"last_bank_transaction_summary": _last_bank_transaction_summary.duplicate(true),
		"last_shop_transaction_summary": _last_shop_transaction_summary.duplicate(true),
		"last_blacksmith_transaction_summary": _last_blacksmith_transaction_summary.duplicate(true),
		"last_gacha_transaction_summary": _last_gacha_transaction_summary.duplicate(true),
		"last_lingpet_store_transaction_summary": _last_lingpet_store_transaction_summary.duplicate(true),
		"plaza_gold": int(_plaza_save_snapshot.get("plaza_gold", 0)),
		"ap_current": int(_plaza_save_snapshot.get("ap_current", 0)),
		"bank_deposit_gold": int(_plaza_save_snapshot.get("bank_deposit_gold", 0)),
		"active_item_slot_count": _get_active_item_slot_count(),
		"owned_lingpet_count": _get_owned_lingpet_count(),
		"blacksmith_target_summary": _get_blacksmith_target_summary(),
		"exit_zone": EXIT_ZONE,
		"game_rect": get_global_rect(),
	}


func set_plaza_save_path_for_test(path: String) -> void:
	if _plaza_save_store != null and _plaza_save_store.has_method("set_save_path"):
		_plaza_save_store.set_save_path(path)
		_refresh_plaza_save_snapshot()


func set_player_pos_for_test(pos: Vector2) -> void:
	_player_pos = _normalize_player_pos(pos)
	_camera_x = _get_target_camera_x()
	_update_hovered_building()
	queue_redraw()


func move_player_for_test(input_dir: Vector2, delta: float) -> Dictionary:
	_test_input_active = true
	_test_input_dir = input_dir
	update_plaza(delta)
	_test_input_active = false
	return get_status()


func trigger_interaction_for_test() -> bool:
	return _try_interact()


func close_menu_for_test() -> void:
	_close_building_menu()


func trigger_menu_action_for_test(action_index: int = 0) -> bool:
	return _trigger_menu_action(action_index)


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


func _get_game_scale() -> float:
	return size.x / GAME_SIZE.x if GAME_SIZE.x > 0.0 else 1.0


func _get_target_camera_x() -> float:
	return clampf(_player_pos.x - GAME_SIZE.x * 0.5 + CAMERA_LEAD_X, 0.0, MAP_SIZE.x - GAME_SIZE.x)


func _get_input_dir() -> Vector2:
	if _test_input_active:
		return Vector2(signf(_test_input_dir.x), 0.0)
	var dir_x := 0.0
	if Input.is_action_pressed("ui_left"):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_right"):
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


func _normalize_player_pos(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, PlazaPlayerController.PLAYER_COLLISION_SIZE.x * 0.5, MAP_SIZE.x - PlazaPlayerController.PLAYER_COLLISION_SIZE.x * 0.5),
		GROUND_Y
	)


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
			draw_texture_rect(
				wall_texture,
				Rect2(Vector2(texture_x, MIDGROUND_WALL_TOP) * scale, Vector2(MIDGROUND_WALL_REPEAT, MIDGROUND_WALL_HEIGHT) * scale),
				false,
				Color(1.0, 1.0, 1.0, 0.90)
			)
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


func _draw_player(scale: float) -> void:
	var local := _world_to_local(_player_pos, scale)
	draw_circle(local + Vector2(0.0, 4.0) * scale, 21.0 * scale, Color(0.0, 0.0, 0.0, 0.24))
	draw_rect(Rect2(local + Vector2(-14.0, -52.0) * scale, Vector2(28.0, 48.0) * scale), Color(0.08, 0.32, 0.46, 1.0), true)
	draw_rect(Rect2(local + Vector2(-16.0, -54.0) * scale, Vector2(32.0, 52.0) * scale), Color(0.0, 0.9, 1.0, 0.74), false, max(1.0, 2.0 * scale))
	draw_circle(local + Vector2(0.0, -70.0) * scale, 15.0 * scale, Color(1.0, 0.86, 0.64, 1.0))
	draw_line(local + Vector2(-9.0, -4.0) * scale, local + Vector2(-15.0, 12.0) * scale, Color(0.0, 0.8, 1.0, 0.9), max(1.0, 3.0 * scale))
	draw_line(local + Vector2(9.0, -4.0) * scale, local + Vector2(15.0, 12.0) * scale, Color(0.0, 0.8, 1.0, 0.9), max(1.0, 3.0 * scale))


func _draw_overlay_ui(scale: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	if _menu_open:
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.38), true)
	var panel := Rect2(MENU_PANEL_RECT.position * scale, MENU_PANEL_RECT.size * scale)
	draw_rect(panel, Color(0.018, 0.023, 0.040, 0.95), true)
	draw_rect(panel, Color(0.0, 0.86, 1.0, 0.48), false, max(1.0, 2.0 * scale))
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


func _draw_menu_action_row(font: Font, scale: float, index: int, y: float, label: String) -> void:
	var row := Rect2(Vector2(MENU_PANEL_RECT.position.x + 30.0, y) * scale, Vector2(MENU_PANEL_RECT.size.x - 60.0, 44.0) * scale)
	draw_rect(row, Color(0.06, 0.085, 0.115, 0.76), true)
	draw_rect(row, Color(0.0, 0.76, 0.92, 0.22), false, max(1.0, 1.0 * scale))
	var number_text := "%02d" % (index + 1)
	_draw_text_shadow(font, row.position + Vector2(16.0, 29.0) * scale, number_text, int(16.0 * scale), Color(0.0, 0.92, 1.0, 0.82))
	_draw_text_shadow(font, row.position + Vector2(64.0, 30.0) * scale, label, int(20.0 * scale), Color(0.94, 0.98, 1.0, 0.96))
	var state_text := "실행" if _is_executable_menu_type(_active_menu_type) else "준비 중"
	var state_color := Color(0.72, 1.0, 0.86, 0.82) if _is_executable_menu_type(_active_menu_type) else Color(1.0, 0.72, 0.94, 0.70)
	_draw_text_shadow(font, row.position + Vector2(row.size.x / scale - 86.0, 29.0) * scale, state_text, int(15.0 * scale), state_color)


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
	for i in range(_building_specs.size() - 1, -1, -1):
		var spec := _building_specs[i]
		var rect: Rect2 = spec.get("interaction_rect", Rect2())
		if rect.has_point(world_pos):
			return spec
	return {}


func _update_hovered_building() -> void:
	var active_building := _get_interactable_building()
	_hovered_building_type = str(active_building.get("type", ""))


func _try_interact() -> bool:
	if _menu_open:
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
	_open_building_menu(building)


func _open_building_menu(building: Dictionary) -> void:
	var building_type := str(building.get("type", ""))
	var spec: Dictionary = BUILDING_MENU_SPECS.get(building_type, {})
	_refresh_plaza_save_snapshot()
	_menu_open = true
	_active_menu_type = building_type
	_active_menu_title = str(spec.get("title", building.get("display_name", "건물")))
	_active_menu_subtitle = str(spec.get("subtitle", ""))
	_active_menu_actions = _get_string_array(spec.get("actions", []))
	_active_menu_last_message = ""
	_active_menu_visit_ap_consumed = false
	_last_bank_transaction_summary = {}
	_last_shop_transaction_summary = {}
	_last_blacksmith_transaction_summary = {}
	_last_gacha_transaction_summary = {}
	_last_lingpet_store_transaction_summary = {}
	_dialog_text = ""
	_dialog_timer = 0.0
	queue_redraw()


func _refresh_plaza_save_snapshot() -> void:
	if _plaza_save_store == null or not _plaza_save_store.has_method("get_summary"):
		_plaza_save_snapshot = {}
		return
	_plaza_save_snapshot = _plaza_save_store.get_summary()


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


func _close_building_menu() -> void:
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
	queue_redraw()


func _is_executable_menu_type(menu_type: String) -> bool:
	return ["bank", "shop", "gacha", "lingpet_store", "blacksmith"].has(menu_type)


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
	if exit_callback.is_valid():
		exit_callback.call()


func _discrete_flicker(seed_text: String) -> float:
	var tick := int(floor(Time.get_ticks_msec() * 0.047))
	var h := int(hash(seed_text)) ^ (tick * 1103515245)
	return float(abs(h) % 1000) / 1000.0


func _flicker_alpha(seed_text: String, base_alpha: float, amplitude: float) -> float:
	return clampf(base_alpha + _discrete_flicker(seed_text) * amplitude, 0.0, 1.0)
