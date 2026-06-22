extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const STAGE_OPTIONS := [
	{"id": 1, "variant": "dalji", "name": "스테이지 1", "desc": "달지"},
	{"id": 1, "variant": "gaksi", "name": "스테이지 1-B", "desc": "각시탈"},
	{"id": 2, "name": "스테이지 2", "desc": "정글"},
	{"id": 3, "name": "스테이지 3", "desc": "멘헤라"},
	{"id": 4, "name": "스테이지 4", "desc": "소림사"},
	{"id": 5, "name": "스테이지 5", "desc": "홍련"},
	{"id": 6, "name": "스테이지 6", "desc": "테트리서"},
	{"id": 8, "name": "스테이지 8", "desc": "아카무 리고"},
	{"id": 9, "name": "스테이지 9", "desc": "미노타우로스"},
	{"id": 10, "name": "스테이지 10", "desc": "최종 관문"},
	{"id": 11, "name": "4천왕", "desc": "스테이지 11"},
	{"id": 12, "name": "진엔딩", "desc": "스테이지 12"},
]

const COLUMNS := 4
const CARD_SIZE := Vector2(148.0, 82.0)
const CARD_GAP := Vector2(14.0, 14.0)
const PANEL_PADDING := Vector2(28.0, 24.0)
const HEADER_HEIGHT := 76.0
const STAGE_RESET_MODULE_KEYS := [
	"status_effect_state",
	"weather_event_state",
	"stage_ball_spawn_intro",
	"stage1_pillar_background",
	"stage2_pillar_background",
	"stage3_pillar_background",
	"stage3_actor_renderer",
	"stage3_playfield_renderer",
	"stage4_pillar_background",
	"stage4_actor_renderer",
	"stage4_map_state",
	"stage4_temple_destruction_event",
	"stage4_moon_event",
	"stage4_bird_event",
	"stage4_brazier_monk_event",
	"stage4_ponk_skill_state",
	"stage4_ponk_boss_skill_hud_renderer",
	"stage4_ponk_gauge_hud_renderer",
	"stage5_hongryun_pillar_background",
	"stage5_hongryun_actor_renderer",
	"stage5_hongryun_pillar_scene_drawer",
	"stage5_hongryun_state",
	"stage5_hongryun_fire_machine_event",
	"stage5_hongryun_boss_skill_hud_renderer",
	"stage6_tetriser_pillar_background",
	"stage6_tetriser_actor_renderer",
	"stage6_tetriser_pillar_scene_drawer",
	"stage6_tetriser_state",
	"stage6_tetriser_boss_skill_hud_renderer",
	"stage1_dalji_whip_skill_state",
	"stage1_dalji_spinning_top_skill_state",
	"stage1_dalji_boss_skill_cooldown_state",
	"stage1_balloon_event",
	"stage2_boss_skill_state",
	"stage3_boss_skill_state",
	"stage2_monkey_banana_event",
]
const EFFECT_CLEAR_MODULE_KEYS := [
	"impact_effects",
	"ball_effects",
]

var open := false
var selected_index := 0
var character_runtime: Object = PlayerCharacterRuntime.new()


func toggle(owner: Object = null) -> void:
	open = not open
	if open:
		selected_index = _get_stage_index(_get_current_stage(owner), _get_stage1_boss_variant(owner))


func close() -> void:
	open = false


func is_open() -> bool:
	return open


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not open:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		if _is_key(key_event, KEY_ESCAPE):
			close()
			return true
		if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_SPACE):
			_apply_selected_stage(owner, registry)
			return true
		if _is_key(key_event, KEY_RIGHT) or _is_key(key_event, KEY_D):
			_move_selection(1, 0)
			return true
		if _is_key(key_event, KEY_LEFT) or _is_key(key_event, KEY_A):
			_move_selection(-1, 0)
			return true
		if _is_key(key_event, KEY_DOWN) or _is_key(key_event, KEY_S):
			_move_selection(0, 1)
			return true
		if _is_key(key_event, KEY_UP) or _is_key(key_event, KEY_W):
			_move_selection(0, -1)
			return true
		var digit_index: int = _digit_to_index(key_event)
		if digit_index >= 0:
			selected_index = digit_index
			_apply_selected_stage(owner, registry)
			return true
		return true

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed:
			return true
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return true
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return true
		var hit_index: int = _get_card_index_at(mouse_event.position, view_size)
		if hit_index >= 0:
			selected_index = hit_index
			_apply_selected_stage(owner, registry)
			return true
		if not _get_panel_rect(view_size).has_point(mouse_event.position):
			close()
		return true

	if event is InputEventMouseMotion:
		var hit_index: int = _get_card_index_at((event as InputEventMouseMotion).position, view_size)
		if hit_index >= 0:
			selected_index = hit_index
		return true

	return true


func draw(canvas: CanvasItem, owner: Object, view_size: Vector2) -> void:
	if canvas == null or not open:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var panel_rect: Rect2 = _get_panel_rect(view_size)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.48))
	canvas.draw_rect(panel_rect, Color(0.035, 0.045, 0.070, 0.97))
	canvas.draw_rect(panel_rect, Color(0.35, 0.78, 1.0, 0.88), false, 2.0)

	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 32.0), "F5 디버그 스테이지 선택", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.88, 0.97, 1.0))
	var current_stage: int = _get_current_stage(owner)
	var current_stage1_boss_variant: String = _get_stage1_boss_variant(owner)
	var info := "현재 스테이지 %d  /  방향키·WASD 이동, Enter·Space 이동, Esc 취소" % current_stage
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, 58.0), info, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 13, Color(0.72, 0.80, 0.88))

	for index in range(STAGE_OPTIONS.size()):
		var option: Dictionary = STAGE_OPTIONS[index]
		_draw_card(
			canvas,
			font,
			_get_card_rect(index, panel_rect),
			option,
			index == selected_index,
			_is_current_option(option, current_stage, current_stage1_boss_variant)
		)

	var foot := "스테이지 5는 홍련, 6번은 테트리서 포팅 슬롯입니다(스캐폴드 단계)."
	canvas.draw_string(font, panel_rect.position + Vector2(22.0, panel_rect.size.y - 18.0), foot, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44.0, 12, Color(0.58, 0.66, 0.74))


func _draw_card(canvas: CanvasItem, font: Font, rect: Rect2, option: Dictionary, selected: bool, is_current: bool) -> void:
	var stage_id: int = int(option.get("id", 1))
	var implemented: bool = stage_id <= 6
	var base := Color(0.10, 0.13, 0.18, 0.96)
	var border := Color(0.24, 0.34, 0.46, 0.82)
	if implemented:
		base = Color(0.10, 0.18, 0.15, 0.96)
		border = Color(0.25, 0.68, 0.52, 0.82)
	if is_current:
		base = base.lerp(Color(0.22, 0.24, 0.12, 1.0), 0.45)
		border = Color(1.0, 0.83, 0.28, 0.95)
	if selected:
		base = base.lerp(Color(0.18, 0.32, 0.42, 1.0), 0.65)
		border = Color(0.80, 0.95, 1.0, 1.0)

	canvas.draw_rect(rect, base)
	canvas.draw_rect(rect, border, false, 2.0 if selected else 1.0)

	var num_text := "%02d" % stage_id
	canvas.draw_string(font, rect.position + Vector2(12.0, 24.0), num_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.86, 0.38))
	canvas.draw_string(font, rect.position + Vector2(12.0, 48.0), str(option.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 15, Color(0.94, 0.98, 1.0))
	var desc_color := Color(0.66, 0.78, 0.88) if implemented else Color(0.62, 0.65, 0.70)
	canvas.draw_string(font, rect.position + Vector2(12.0, 68.0), str(option.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 11, desc_color)


func _apply_selected_stage(owner: Object, registry: Object) -> void:
	if owner == null:
		return
	var selected_option: Dictionary = STAGE_OPTIONS[selected_index]
	var stage_id: int = int(selected_option.get("id", 1))
	var stage1_boss_variant: String = _get_option_stage1_boss_variant(selected_option)
	owner.set("current_stage", stage_id)
	owner.set("stage1_boss_variant", stage1_boss_variant if stage_id == 1 else "dalji")
	_sync_selection_state(owner, stage_id, stage1_boss_variant)
	_reset_runtime_for_stage(owner, registry, stage_id)
	close()
	if owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _reset_runtime_for_stage(owner: Object, registry: Object, stage_id: int) -> void:
	if registry == null:
		return
	_reset_match_runtime(owner, registry)
	_stop_and_restart_stage_audio(registry, stage_id)
	_clear_transient_effects(registry)
	_reset_stage_modules(registry)
	_prewarm_selected_stage_modules(owner, registry, stage_id)

	var commando_weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if commando_weapon_controller != null and commando_weapon_controller.has_method("prepare_stage_start"):
		commando_weapon_controller.prepare_stage_start(stage_id, true)
	var result_screen: Object = _get_instance(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("prepare_stage_start"):
		result_screen.prepare_stage_start(owner, registry, stage_id)

	if owner != null:
		owner.set("weather_type", "")
		owner.set("weather_event_active", false)
		owner.set("weather_event_context", {})

	var ball_physics: Object = _get_instance(registry, "ball_physics")
	if ball_physics != null and ball_physics.has_method("configure_context"):
		ball_physics.configure_context(
			stage_id,
			str(_safe_owner_get(owner, "ai_mode", "champion")),
			bool(_safe_owner_get(owner, "arena_mode_enabled", false)),
			str(_safe_owner_get(owner, "weather_type", ""))
		)

	var update_driver: Object = _get_instance(registry, "battle_scene_update_driver")
	if update_driver != null and update_driver.has_method("reset_ball"):
		update_driver.reset_ball(owner, registry)


func _reset_match_runtime(owner: Object, registry: Object) -> void:
	var match_flow_driver: Object = _get_instance(registry, "battle_scene_match_flow_driver")
	if match_flow_driver != null and match_flow_driver.has_method("reset_game"):
		match_flow_driver.reset_game(owner, registry, Callable(), Callable())
		return

	var score_state: Object = _get_instance(registry, "match_score_state")
	if score_state != null and score_state.has_method("reset"):
		score_state.reset()
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("reset"):
		scoreboard_state.reset()
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state != null and round_state.has_method("reset_game"):
		round_state.reset_game()


func _stop_and_restart_stage_audio(registry: Object, stage_id: int) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	GameplayLoopAudioCleanup.stop_all(audio)
	if audio.has_method("stop_bgm"):
		audio.stop_bgm()
	if audio.has_method("play_stage_bgm"):
		audio.play_stage_bgm(stage_id)


func _clear_transient_effects(registry: Object) -> void:
	for key in EFFECT_CLEAR_MODULE_KEYS:
		var effect_module: Object = _get_instance(registry, str(key))
		if effect_module != null and effect_module.has_method("clear_all"):
			effect_module.clear_all()


func _reset_stage_modules(registry: Object) -> void:
	for key in STAGE_RESET_MODULE_KEYS:
		var stage_module: Object = _get_instance(registry, str(key))
		if stage_module != null and stage_module.has_method("reset"):
			stage_module.reset()


func _prewarm_selected_stage_modules(owner: Object, registry: Object, stage_id: int) -> void:
	_prewarm_active_item_runtime(registry)
	if stage_id == 1:
		_prewarm_stage1_selected_modules(owner, registry)
		return
	if stage_id == 5:
		_prewarm_stage5_selected_modules(owner, registry)
		return
	if stage_id == 6:
		_prewarm_stage6_selected_modules(owner, registry)
		return
	if stage_id != 2:
		return
	for key in [
		"stage2_pillar_background",
		"stage2_actor_renderer",
		"stage2_boss_skill_hud_renderer",
		"stage2_monkey_banana_event",
	]:
		var stage_module: Object = _get_instance(registry, str(key))
		if stage_module != null and stage_module.has_method("prewarm_assets"):
			stage_module.prewarm_assets()


func _prewarm_active_item_runtime(registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	var active_item_hud_visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	if active_item_runtime != null and active_item_runtime.has_method("prewarm_assets"):
		active_item_runtime.prewarm_assets(active_item_hud_visuals)
	elif active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons"):
		active_item_hud_visuals.prewarm_catalog_icons()


func _prewarm_stage1_selected_modules(owner: Object, registry: Object) -> void:
	var stage_background: Object = _get_instance(registry, "stage1_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	var module_getter := Callable(registry, "get_instance") if registry != null and registry.has_method("get_instance") else Callable()
	var pillar_scene_drawer: Object = _get_instance(registry, "stage1_pillar_scene_drawer")
	if pillar_scene_drawer != null and pillar_scene_drawer.has_method("prewarm_assets") and module_getter.is_valid():
		pillar_scene_drawer.prewarm_assets(module_getter, _get_selected_character_type(owner))
	for key in [
		"stage1_balloon_event",
		"stage1_dalji_boss_skill_hud_renderer",
	]:
		var stage_module: Object = _get_instance(registry, str(key))
		if stage_module != null and stage_module.has_method("prewarm_assets"):
			stage_module.prewarm_assets()


func _prewarm_stage5_selected_modules(owner: Object, registry: Object) -> void:
	var stage_background: Object = _get_instance(registry, "stage5_hongryun_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	var module_getter := Callable(registry, "get_instance") if registry != null and registry.has_method("get_instance") else Callable()
	var actor_renderer: Object = _get_instance(registry, "stage5_hongryun_actor_renderer")
	if actor_renderer != null and actor_renderer.has_method("prewarm_assets"):
		actor_renderer.prewarm_assets()
	var pillar_scene_drawer: Object = _get_instance(registry, "stage5_hongryun_pillar_scene_drawer")
	if pillar_scene_drawer != null and pillar_scene_drawer.has_method("prewarm_assets") and module_getter.is_valid():
		pillar_scene_drawer.prewarm_assets(module_getter, _get_selected_character_type(owner))
	var skill_hud: Object = _get_instance(registry, "stage5_hongryun_boss_skill_hud_renderer")
	if skill_hud != null and skill_hud.has_method("prewarm_assets"):
		skill_hud.prewarm_assets()


func _prewarm_stage6_selected_modules(owner: Object, registry: Object) -> void:
	var stage_background: Object = _get_instance(registry, "stage6_tetriser_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	var module_getter := Callable(registry, "get_instance") if registry != null and registry.has_method("get_instance") else Callable()
	var actor_renderer: Object = _get_instance(registry, "stage6_tetriser_actor_renderer")
	if actor_renderer != null and actor_renderer.has_method("prewarm_assets"):
		actor_renderer.prewarm_assets()
	var pillar_scene_drawer: Object = _get_instance(registry, "stage6_tetriser_pillar_scene_drawer")
	if pillar_scene_drawer != null and pillar_scene_drawer.has_method("prewarm_assets") and module_getter.is_valid():
		pillar_scene_drawer.prewarm_assets(module_getter, _get_selected_character_type(owner))
	var skill_hud: Object = _get_instance(registry, "stage6_tetriser_boss_skill_hud_renderer")
	if skill_hud != null and skill_hud.has_method("prewarm_assets"):
		skill_hud.prewarm_assets()


func _sync_selection_state(owner: Object, stage_id: int, stage1_boss_variant: String = "dalji") -> void:
	if owner == null or not owner.has_method("get_node_or_null"):
		return
	var selection_state: Object = owner.get_node_or_null("/root/GameSelectionState")
	if selection_state != null and selection_state.has_method("set_stage"):
		selection_state.set_stage(stage_id, stage1_boss_variant if stage_id == 1 else "dalji")


func _move_selection(dx: int, dy: int) -> void:
	var row: int = int(floor(float(selected_index) / float(COLUMNS)))
	var col: int = selected_index % COLUMNS
	var rows: int = int(ceil(float(STAGE_OPTIONS.size()) / float(COLUMNS)))
	row = wrapi(row + dy, 0, rows)
	col = wrapi(col + dx, 0, COLUMNS)
	selected_index = clampi(row * COLUMNS + col, 0, STAGE_OPTIONS.size() - 1)


func _digit_to_index(key_event: InputEventKey) -> int:
	for stage_id in range(1, 10):
		if _is_key(key_event, KEY_1 + stage_id - 1):
			return _find_stage_index(stage_id)
	if _is_key(key_event, KEY_0):
		return _find_stage_index(10)
	return -1


func _find_stage_index(stage_id: int) -> int:
	return _find_stage_variant_index(stage_id, "dalji")


func _find_stage_variant_index(stage_id: int, stage1_boss_variant: String = "dalji") -> int:
	for index in range(STAGE_OPTIONS.size()):
		var option: Dictionary = STAGE_OPTIONS[index]
		if (
			int(option.get("id", 1)) == stage_id
			and (
				stage_id != 1
				or _get_option_stage1_boss_variant(option) == _normalize_stage1_boss_variant(stage1_boss_variant)
			)
		):
			return index
	return -1


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var grid_size := Vector2(
		COLUMNS * CARD_SIZE.x + (COLUMNS - 1) * CARD_GAP.x,
		3.0 * CARD_SIZE.y + 2.0 * CARD_GAP.y
	)
	var panel_size := grid_size + PANEL_PADDING * 2.0 + Vector2(0.0, HEADER_HEIGHT + 30.0)
	var pos := (view_size - panel_size) * 0.5
	return Rect2(Vector2(max(pos.x, 12.0), max(pos.y, 12.0)), panel_size)


func _get_card_rect(index: int, panel_rect: Rect2) -> Rect2:
	var row: int = int(floor(float(index) / float(COLUMNS)))
	var col: int = index % COLUMNS
	var origin := panel_rect.position + Vector2(PANEL_PADDING.x, PANEL_PADDING.y + HEADER_HEIGHT)
	return Rect2(origin + Vector2(col * (CARD_SIZE.x + CARD_GAP.x), row * (CARD_SIZE.y + CARD_GAP.y)), CARD_SIZE)


func _get_card_index_at(position: Vector2, view_size: Vector2) -> int:
	var panel_rect: Rect2 = _get_panel_rect(view_size)
	for index in range(STAGE_OPTIONS.size()):
		if _get_card_rect(index, panel_rect).has_point(position):
			return index
	return -1


func _get_stage_index(stage_id: int, stage1_boss_variant: String = "dalji") -> int:
	var found_index: int = _find_stage_variant_index(stage_id, stage1_boss_variant)
	return found_index if found_index >= 0 else 0


func _get_current_stage(owner: Object) -> int:
	return int(_safe_owner_get(owner, "current_stage", 1))


func _get_stage1_boss_variant(owner: Object) -> String:
	return _normalize_stage1_boss_variant(str(_safe_owner_get(owner, "stage1_boss_variant", "dalji")))


func _get_option_stage1_boss_variant(option: Dictionary) -> String:
	return _normalize_stage1_boss_variant(str(option.get("variant", "dalji")))


func _normalize_stage1_boss_variant(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == "gaksi" or normalized == "gaksital" or normalized == "talkwangdae":
		return "gaksi"
	return "dalji"


func _is_current_option(option: Dictionary, current_stage: int, current_stage1_boss_variant: String) -> bool:
	var stage_id: int = int(option.get("id", 1))
	if stage_id != current_stage:
		return false
	if stage_id != 1:
		return true
	return _get_option_stage1_boss_variant(option) == _normalize_stage1_boss_variant(current_stage1_boss_variant)


func _get_selected_character_type(owner: Object) -> String:
	var normalized: String = character_runtime.normalize(_safe_owner_get(owner, "selected_character_type", PlayerCharacterRuntime.SMASHER))
	if normalized == PlayerCharacterRuntime.COMMANDO:
		return PlayerCharacterRuntime.COMMANDO
	if normalized == PlayerCharacterRuntime.VIPER:
		return PlayerCharacterRuntime.VIPER
	return PlayerCharacterRuntime.SMASHER


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
