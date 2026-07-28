extends RefCounted

const Stage1ActiveItemHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_active_item_hud_scene_drawer.gd")
const Stage1TopMiniScoreboardSceneDrawer := preload("res://scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const EXPRESSION_NEUTRAL := "neutral"
const EXPRESSION_HAPPY := "happy"
const EXPRESSION_SAD := "sad"
const EXPRESSION_PAINED := "pained"

const BASE_PREWARM_MODULE_KEYS := [
	"scoreboard_renderer",
	"match_score_state",
	"scoreboard_state",
	"stage1_pillar_ui_renderer",
	"pillar_orb_drawer",
	"smasher_skill_orb_renderer",
	"horn_strawberry_skill_pillar_renderer",
	"odins_eye_skill_pillar_renderer",
	"pillar_status_orb_renderer",
	"active_item_hud_layout",
	"active_item_hud_renderer",
	"active_item_hud_state",
	"active_item_hud_visuals",
	"round_flow_state",
	"battle_feedback_state",
	"orb_hud_state",
	"boss_ai_state",
	"runtime_perk_state",
	"mythic_item_runtime",
	"lingpet_egg_runtime",
]

var active_item_drawer: Object = Stage1ActiveItemHudSceneDrawer.new()
var top_mini_scoreboard_drawer: Object = Stage1TopMiniScoreboardSceneDrawer.new()
var character_runtime: Object = PlayerCharacterRuntime.new()
var _prewarm_step_index := 0
var _prewarm_character_type := ""
var _prewarm_stage1_boss_variant := ""
var _prewarm_finished_for := ""
var _plaza_gold_store: Object = PlazaSaveStore.new()
var _plaza_gold_cache_loaded := false
var _plaza_gold_cache_stage := -1
var _plaza_gold_cache_save_path := ""
var _plaza_gold_cache_value := 0
# _draw_stage1_pillar_ui가 매 프레임 렌더러에 넘기는 ~40키 컨텍스트 재사용 버퍼.
# 키 집합은 고정이고 매 프레임 전 키를 다시 쓴다. 렌더러 체인
# (stage1_pillar_ui_renderer / stage1_pillar_ui_layout /
# stage1_pillar_status_orb_context_builder / commando_firearm_selector_renderer)
# 은 이 dict를 프레임 안에서 읽기만 하고 저장하지 않는 것을 확인했다.
# 새 소비자가 이 dict를 보관하거나 수정하면 안 된다.
var _pillar_ui_render_context: Dictionary = {}
var _default_boss_dash_snapshot: Dictionary = {}


func prewarm_assets(
	module_getter: Callable,
	selected_character_type: String = "smasher",
	stage1_boss_variant: String = "dalji"
) -> void:
	while not prewarm_assets_step(module_getter, selected_character_type, stage1_boss_variant):
		pass


func prewarm_assets_step(
	module_getter: Callable,
	selected_character_type: String = "smasher",
	stage1_boss_variant: String = "dalji"
) -> bool:
	var character_type: String = character_runtime.normalize(selected_character_type)
	var normalized_stage1_boss_variant: String = _normalize_stage1_boss_variant(stage1_boss_variant)
	var prewarm_key := "%s:%s" % [character_type, normalized_stage1_boss_variant]
	if _prewarm_finished_for == prewarm_key:
		return true
	if _prewarm_character_type != character_type or _prewarm_stage1_boss_variant != normalized_stage1_boss_variant:
		_prewarm_character_type = character_type
		_prewarm_stage1_boss_variant = normalized_stage1_boss_variant
		_prewarm_step_index = 0

	var character_keys: Array = _get_character_prewarm_keys(character_type)
	var base_count := BASE_PREWARM_MODULE_KEYS.size()
	if _prewarm_step_index < base_count:
		_get_module(module_getter, str(BASE_PREWARM_MODULE_KEYS[_prewarm_step_index]))
		_prewarm_step_index += 1
		return false

	var character_step := _prewarm_step_index - base_count
	if character_step < character_keys.size():
		_get_module(module_getter, str(character_keys[character_step]))
		_prewarm_step_index += 1
		return false

	var special_step := character_step - character_keys.size()
	match special_step:
		0:
			var cooldown_key: String = _get_stage1_boss_skill_cooldown_key(normalized_stage1_boss_variant)
			if cooldown_key != "":
				_get_module(module_getter, cooldown_key)
			var skill_hud_key: String = _get_stage1_boss_skill_hud_key(normalized_stage1_boss_variant)
			if skill_hud_key != "":
				var skill_hud: Object = _get_module(module_getter, skill_hud_key)
				if skill_hud != null and skill_hud.has_method("prewarm_assets_step"):
					if not bool(skill_hud.prewarm_assets_step()):
						return false
				elif skill_hud != null and skill_hud.has_method("prewarm_assets"):
					skill_hud.prewarm_assets()
		1:
			var status_orb_renderer: Object = _get_module(module_getter, "pillar_status_orb_renderer")
			if status_orb_renderer != null and status_orb_renderer.has_method("prewarm_caches_step"):
				if not bool(status_orb_renderer.prewarm_caches_step()):
					return false
			elif status_orb_renderer != null and status_orb_renderer.has_method("prewarm_caches"):
				status_orb_renderer.prewarm_caches()
		2:
			if character_type == "soldier":
				var firearm_selector: Object = _get_module(module_getter, "commando_firearm_selector_renderer")
				if firearm_selector != null and firearm_selector.has_method("prewarm_assets_step"):
					if not bool(firearm_selector.prewarm_assets_step()):
						return false
				elif firearm_selector != null and firearm_selector.has_method("prewarm_assets"):
					firearm_selector.prewarm_assets()
		3:
			if character_type == "soldier":
				_get_module(module_getter, "commando_weapon_controller")
		4:
			if character_type == "soldier":
				_get_module(module_getter, "commando_firearm_runtime")
		5:
			# 오브 글래스 정적 레이어 베이크 (pillar_orb_chrome_drawer 소유).
			var pillar_orb_drawer: Object = _get_module(module_getter, "pillar_orb_drawer")
			if pillar_orb_drawer != null and pillar_orb_drawer.has_method("prewarm_static_layers_step"):
				if not bool(pillar_orb_drawer.prewarm_static_layers_step()):
					return false
		6:
			_refresh_plaza_gold_cache_from_module_getter(module_getter)
		_:
			_prewarm_finished_for = prewarm_key
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func reset_prewarm_cache() -> void:
	_prewarm_step_index = 0
	_prewarm_character_type = ""
	_prewarm_stage1_boss_variant = ""
	_prewarm_finished_for = ""


func sync_plaza_gold_cache(context: Dictionary, registry: Object, allow_load: bool = true) -> void:
	var result_screen: Object = _get_result_screen_from_registry(registry, allow_load)
	if result_screen == null:
		return
	var stage_id: int = int(context.get("current_stage", _plaza_gold_cache_stage))
	_sync_plaza_gold_cache_from_result_screen(result_screen, stage_id, allow_load)


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	states: Dictionary,
	_view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	top_mini_scoreboard_drawer.draw(canvas, context, registry, states, game_offset, game_size, time_seconds)
	_perf_end(perf_logger, "stage1.pillar.top_mini_scoreboard", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_stage1_pillar_ui(canvas, context, registry, states, game_offset, game_size, time_seconds)
	_perf_end(perf_logger, "stage1.pillar.ui_total", sample_start)


func draw_active_item_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	include_stage1_boss_skill_hud: bool = true
) -> void:
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var time_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_sync_commando_firearm_panel_rect_for_boss_hud(context, registry, game_offset, game_size)
	var sample_start: int = _perf_begin(perf_logger)
	_draw_gold_hud(canvas, context, registry, game_offset, game_size)
	_perf_end(perf_logger, "stage1.pillar.gold_hud", sample_start)
	sample_start = _perf_begin(perf_logger)
	active_item_drawer.draw(canvas, context, registry, view_size, game_offset, game_size)
	_perf_end(perf_logger, "stage1.pillar.active_item_hud", sample_start)
	if include_stage1_boss_skill_hud:
		sample_start = _perf_begin(perf_logger)
		_draw_stage1_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size, time_seconds)
		_perf_end(perf_logger, "stage1.pillar.boss_skill_hud", sample_start)


func _draw_stage1_pillar_ui(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	states: Dictionary,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	var perf_logger: Object = context.get("battle_perf_logger", null)
	var renderer: Object = _get_cached_module(registry, "stage1_pillar_ui_renderer")
	if renderer == null:
		return
	var prep_start: int = _perf_begin(perf_logger)
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	var character_type: String = character_runtime.normalize(context.get("selected_character_type", "smasher"))
	var skill_config_key: String = character_runtime.get_skill_config_key(character_type)
	var dash_state_key: String = character_runtime.get_dash_state_key(character_type)
	var combo_key: String = character_runtime.get_combo_state_key(character_type)
	var skill_state_key: String = character_runtime.get_skill_state_key(character_type)
	var skill_config: Object = _get_cached_module(registry, skill_config_key) if skill_config_key != "" else null
	var skill_config_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null else {}
	var max_skill_slots: int = int(skill_config_snapshot.get("max_slots", 5))
	var skill_cluster_frame_key: String = character_runtime.get_skill_cluster_frame_texture_key(character_type, max_skill_slots)
	var feedback: Object = _get_cached_module(registry, "battle_feedback_state")
	var orb_state: Object = states.get("orb_hud_state", null)
	var dash_state: Object = _get_cached_module(registry, dash_state_key)
	var dash_snapshot: Dictionary = dash_state.get_snapshot() if dash_state != null else {}
	var boss_ai_state: Object = _get_cached_module(registry, "boss_ai_state")
	var boss_dash_snapshot: Dictionary
	if boss_ai_state != null and boss_ai_state.has_method("get_dash_token_snapshot"):
		boss_dash_snapshot = boss_ai_state.get_dash_token_snapshot()
	else:
		# 폴백 기본값은 내용이 불변이므로 한 번만 만들어 재사용한다 (읽기 전용).
		if _default_boss_dash_snapshot.is_empty():
			_default_boss_dash_snapshot = _build_default_boss_dash_snapshot()
		boss_dash_snapshot = _default_boss_dash_snapshot
	var cleanse_status_active := false
	if _skill_snapshot_has_skill(skill_config_snapshot, "cleanse"):
		cleanse_status_active = _is_cleanse_status_active(registry)
	var now_msec: int = Time.get_ticks_msec()
	var pillar_drawer: Object = _get_cached_module(registry, "pillar_orb_drawer")
	var skill_orb_renderer: Object = _get_cached_module(registry, "smasher_skill_orb_renderer")
	var status_orb_renderer: Object = _get_cached_module(registry, "pillar_status_orb_renderer")
	var combo_renderer: Object = _get_cached_module(registry, "smasher_combo_renderer") if combo_key != "" else null
	var combo_state: Object = _get_cached_module(registry, combo_key) if combo_key != "" else null
	var skill_state: Object = _get_cached_module(registry, skill_state_key) if skill_state_key != "" else null
	var commando_firearm_selector_renderer: Object = _get_cached_module(registry, "commando_firearm_selector_renderer") if character_type == "soldier" else null
	var commando_weapon_controller: Object = _get_cached_module(registry, "commando_weapon_controller") if character_type == "soldier" else null
	var commando_firearm_runtime: Object = _get_cached_module(registry, "commando_firearm_runtime") if character_type == "soldier" else null
	var commando_firearm_context: Dictionary = {}
	if commando_firearm_runtime != null and commando_firearm_runtime.has_method("get_actor_draw_context"):
		commando_firearm_context = commando_firearm_runtime.get_actor_draw_context()
	var mythic_item_runtime: Object = _get_cached_module(registry, "mythic_item_runtime")
	var sensor_context: Dictionary = mythic_item_runtime.get_sensor_context() if mythic_item_runtime != null and mythic_item_runtime.has_method("get_sensor_context") else {}
	var horn_strawberry_context: Dictionary = mythic_item_runtime.get_horn_strawberry_context() if mythic_item_runtime != null and mythic_item_runtime.has_method("get_horn_strawberry_context") else {}
	var horn_strawberry_skill_pillar_renderer: Object = _get_cached_module(registry, "horn_strawberry_skill_pillar_renderer")
	var odins_eye_context: Dictionary = mythic_item_runtime.get_odins_eye_context() if mythic_item_runtime != null and mythic_item_runtime.has_method("get_odins_eye_context") else {}
	var odins_eye_skill_pillar_renderer: Object = _get_cached_module(registry, "odins_eye_skill_pillar_renderer")
	var lingpet_runtime: Object = _get_cached_module(registry, "lingpet_egg_runtime")
	# Reactive pillar portraits: resolve the boss / player face from live stun +
	# per-point score state (stateless direct mapping; latch/decay lands in a later
	# slice). Read the modules via the registry so the face does not depend on
	# whichever context keys the HUD context happens to carry.
	var status_effect_state: Object = _get_cached_module(registry, "status_effect_state")
	var scoreboard_state: Object = _get_cached_module(registry, "scoreboard_state")
	var portrait_expr: Dictionary = _resolve_portrait_expressions(status_effect_state, scoreboard_state)
	_perf_end(perf_logger, "stage1.pillar.ui_prepare", prep_start)
	var renderer_start: int = _perf_begin(perf_logger)
	# 매 프레임 새 Dictionary 리터럴 대신 멤버 dict를 재사용한다 (할당 제거).
	# 키 집합은 고정이고 아래에서 전 키를 다시 쓰므로 이전 프레임 값이 남지 않는다.
	var ui_context: Dictionary = _pillar_ui_render_context
	ui_context["battle_perf_logger"] = perf_logger
	ui_context["height"] = float(context.get("height", 750.0))
	ui_context["selected_character_type"] = character_type
	ui_context["pillar_hud_static_lod"] = bool(context.get("pillar_hud_static_lod", false))
	ui_context["pillar_drawer"] = pillar_drawer
	ui_context["skill_orb_renderer"] = skill_orb_renderer
	ui_context["horn_strawberry_skill_pillar_renderer"] = horn_strawberry_skill_pillar_renderer
	ui_context["horn_strawberry_context"] = horn_strawberry_context
	ui_context["odins_eye_skill_pillar_renderer"] = odins_eye_skill_pillar_renderer
	ui_context["odins_eye_context"] = odins_eye_context
	ui_context["status_orb_renderer"] = status_orb_renderer
	ui_context["commando_firearm_selector_renderer"] = commando_firearm_selector_renderer
	ui_context["commando_weapon_controller"] = commando_weapon_controller
	ui_context["commando_firearm_slingshot_state"] = _get_dict(commando_firearm_context.get("commando_firearm_slingshot_state", context.get("commando_firearm_slingshot_state", {})))
	ui_context["commando_firearm_pistol_state"] = _get_dict(commando_firearm_context.get("commando_firearm_pistol_state", context.get("commando_firearm_pistol_state", {})))
	ui_context["commando_firearm_weapon_fire_sheet_state"] = _get_dict(commando_firearm_context.get("commando_firearm_weapon_fire_sheet_state", context.get("commando_firearm_weapon_fire_sheet_state", {})))
	ui_context["commando_firearm_suicide_drone_state"] = _get_dict(commando_firearm_context.get("commando_firearm_suicide_drone_state", context.get("commando_firearm_suicide_drone_state", {})))
	ui_context["combo_renderer"] = combo_renderer
	ui_context["combo_state"] = combo_state
	ui_context["cluster_frame_texture"] = _get_value(textures, skill_cluster_frame_key)
	ui_context["cluster_frame_slots"] = max_skill_slots
	ui_context["skill_orb_frame_texture"] = _get_value(textures, "skill_orb_frame_texture")
	ui_context["skill_icons"] = context.get("skill_icons", {})
	ui_context["skill_state"] = skill_state
	ui_context["skill_config_snapshot"] = skill_config_snapshot
	ui_context["cleanse_status_active"] = cleanse_status_active
	ui_context["special_gauge"] = float(context.get("special_gauge", 0.0))
	ui_context["gauge_max"] = float(context.get("gauge_max", 500.0))
	ui_context["gauge_flash_timer"] = feedback.get_gauge_flash_timer() if feedback != null else 0.0
	ui_context["gauge_flash_duration"] = feedback.get_gauge_flash_duration() if feedback != null else 0.45
	ui_context["gauge_frame_texture"] = _get_value(textures, "gauge_orb_frame_texture")
	ui_context["gauge_orb_ki_jade_ornament_texture"] = _get_value(textures, "gauge_orb_ki_jade_ornament_texture")
	ui_context["gauge_frame_spin_angle"] = orb_state.get_gauge_spin_angle(now_msec) if orb_state != null else 0.0
	ui_context["dash_snapshot"] = dash_snapshot
	ui_context["dash_flash_timer"] = feedback.get_dash_flash_timer() if feedback != null else 0.0
	ui_context["dash_flash_duration"] = feedback.get_dash_flash_duration() if feedback != null else 0.55
	ui_context["dash_divider_anim_progress"] = feedback.get_dash_divider_anim_progress() if feedback != null else 1.0
	ui_context["dash_frame_texture"] = _get_value(textures, "dash_token_frame_texture")
	ui_context["dash_token_bell_cell_texture"] = _get_value(textures, "dash_token_bell_cell_texture")
	ui_context["dash_frame_spin_angle"] = orb_state.get_dash_token_spin_angle(now_msec) if orb_state != null else 0.0
	ui_context["sensor_context"] = sensor_context
	ui_context["lingpet_runtime"] = lingpet_runtime
	ui_context["boss_dash_visible"] = not bool(context.get("arena_mode_enabled", false))
	ui_context["boss_dash_snapshot"] = boss_dash_snapshot
	ui_context["boss_dash_frame_texture"] = null
	ui_context["boss_dash_frame_spin_angle"] = 0.0
	# This HUD drawer is reused by stage6/7/8 pillar scene drawers, so gate the
	# reactive portrait to the Stage 1 slice (v1 scope). Boss identity resolves from
	# stage1_boss_variant, which is only meaningful on Stage 1.
	ui_context["portrait_enabled"] = int(context.get("current_stage", 1)) == 1
	var boss_expression: String = _normalize_expression(portrait_expr.get("boss", "neutral"))
	var player_expression: String = _normalize_expression(portrait_expr.get("player", "neutral"))
	ui_context["portrait_boss_expression"] = boss_expression
	ui_context["portrait_player_expression"] = player_expression
	ui_context["portrait_boss_identity"] = _normalize_stage1_boss_variant(context.get("stage1_boss_variant", "dalji"))
	ui_context["portrait_player_identity"] = character_type
	ui_context["portrait_boss_face"] = _resolve_portrait_face(textures, ui_context["portrait_boss_identity"], boss_expression)
	ui_context["portrait_player_face"] = _resolve_portrait_face(textures, ui_context["portrait_player_identity"], player_expression)
	renderer.draw(canvas, game_offset, game_size, time_seconds, ui_context)
	_perf_end(perf_logger, "stage1.pillar.ui_renderer", renderer_start)


func _draw_stage1_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	if int(context.get("current_stage", 1)) != 1:
		return
	var stage1_boss_variant: String = _normalize_stage1_boss_variant(context.get("stage1_boss_variant", "dalji"))
	if stage1_boss_variant == "gaksi":
		_draw_stage1_gaksital_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size, time_seconds)
	elif stage1_boss_variant == "dalji":
		_draw_stage1_dalji_boss_skill_hud(canvas, context, registry, view_size, game_offset, game_size, time_seconds)


func _draw_stage1_dalji_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	var renderer: Object = _get_cached_module(registry, "stage1_dalji_boss_skill_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return
	var cooldown_state: Object = _get_cached_module(registry, "stage1_dalji_boss_skill_cooldown_state")
	if cooldown_state == null or not cooldown_state.has_method("get_hud_context"):
		return
	var hud_context: Dictionary = context.duplicate()
	hud_context.merge(cooldown_state.get_hud_context(), true)
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	hud_context["time_seconds"] = time_seconds
	var firearm_panel_state: Dictionary = _build_commando_firearm_panel_state_for_boss_hud(
		context,
		registry,
		game_offset,
		game_size
	)
	var firearm_panel_rect: Rect2 = _get_rect(firearm_panel_state.get("rect", Rect2()))
	if firearm_panel_rect.size.x > 0.0 and firearm_panel_rect.size.y > 0.0:
		hud_context["commando_firearm_panel_rect"] = firearm_panel_rect
	# The hatched lingpet casts on every stage, so its skill card rides every
	# stage's boss skill-card rail via the shared helper (gated on companion-active,
	# so egg / none states never expose it). append_entry also force-enables the
	# rail's active flag so the card shows even when no boss skill is live.
	LingpetRailCard.append_entry(hud_context, registry, "stage1_dalji_boss_skill_hud_skills", "stage1_dalji_boss_skill_hud_active")
	renderer.draw(canvas, hud_context)


func _draw_stage1_gaksital_boss_skill_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	var renderer: Object = _get_cached_module(registry, "stage1_gaksital_boss_skill_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return
	var cooldown_state: Object = _get_cached_module(registry, "stage1_gaksital_boss_skill_cooldown_state")
	if cooldown_state == null or not cooldown_state.has_method("get_hud_context"):
		return
	var hud_context: Dictionary = context.duplicate()
	hud_context.merge(cooldown_state.get_hud_context(), true)
	hud_context["view_size"] = view_size
	hud_context["game_offset"] = game_offset
	hud_context["game_size"] = game_size
	hud_context["time_seconds"] = time_seconds
	var firearm_panel_state: Dictionary = _build_commando_firearm_panel_state_for_boss_hud(
		context,
		registry,
		game_offset,
		game_size
	)
	var firearm_panel_rect: Rect2 = _get_rect(firearm_panel_state.get("rect", Rect2()))
	if firearm_panel_rect.size.x > 0.0 and firearm_panel_rect.size.y > 0.0:
		hud_context["commando_firearm_panel_rect"] = firearm_panel_rect
	LingpetRailCard.append_entry(hud_context, registry, "stage1_gaksital_boss_skill_hud_skills", "stage1_gaksital_boss_skill_hud_active")
	renderer.draw(canvas, hud_context)


func _draw_gold_hud(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var renderer: Object = _get_cached_module(registry, "stage1_pillar_ui_renderer")
	if renderer == null or not renderer.has_method("draw_gold_hud"):
		return
	var hud_context: Dictionary = {
		"height": float(context.get("height", 750.0)),
		"gold_hud_amount": _build_gold_hud_amount(context, registry),
	}
	renderer.draw_gold_hud(canvas, game_offset, game_size, hud_context)


func build_commando_firearm_panel_state_for_boss_hud(
	context: Dictionary,
	registry: Object,
	game_offset: Vector2,
	game_size: Vector2
) -> Dictionary:
	return _build_commando_firearm_panel_state_for_boss_hud(context, registry, game_offset, game_size)


func _sync_commando_firearm_panel_rect_for_boss_hud(
	context: Dictionary,
	registry: Object,
	game_offset: Vector2,
	game_size: Vector2
) -> void:
	var firearm_panel_state: Dictionary = build_commando_firearm_panel_state_for_boss_hud(
		context,
		registry,
		game_offset,
		game_size
	)
	var firearm_panel_rect: Rect2 = _get_rect(firearm_panel_state.get("rect", Rect2()))
	if firearm_panel_rect.size.x > 0.0 and firearm_panel_rect.size.y > 0.0:
		context["commando_firearm_panel_rect"] = firearm_panel_rect
	else:
		context.erase("commando_firearm_panel_rect")


func _build_commando_firearm_panel_state_for_boss_hud(
	context: Dictionary,
	registry: Object,
	game_offset: Vector2,
	game_size: Vector2
) -> Dictionary:
	if registry == null:
		return {}
	var character_type: String = character_runtime.normalize(context.get("selected_character_type", "smasher"))
	if character_type != "soldier":
		return {}
	var pillar_renderer: Object = _get_cached_module(registry, "stage1_pillar_ui_renderer")
	if pillar_renderer == null or not pillar_renderer.has_method("build_commando_firearm_panel_state"):
		return {}
	var selector_renderer: Object = _get_cached_module(registry, "commando_firearm_selector_renderer")
	var weapon_controller: Object = _get_cached_module(registry, "commando_weapon_controller")
	if selector_renderer == null or weapon_controller == null:
		return {}
	var skill_config_key: String = character_runtime.get_skill_config_key(character_type)
	var skill_config: Object = _get_cached_module(registry, skill_config_key) if skill_config_key != "" else null
	var skill_config_snapshot: Dictionary = skill_config.get_snapshot() if skill_config != null and skill_config.has_method("get_snapshot") else {}
	var commando_firearm_runtime: Object = _get_cached_module(registry, "commando_firearm_runtime")
	var commando_firearm_context: Dictionary = {}
	if commando_firearm_runtime != null and commando_firearm_runtime.has_method("get_actor_draw_context"):
		commando_firearm_context = commando_firearm_runtime.get_actor_draw_context()
	return pillar_renderer.build_commando_firearm_panel_state(game_offset, game_size, {
		"height": float(context.get("height", 750.0)),
		"selected_character_type": character_type,
		"pillar_drawer": _get_cached_module(registry, "pillar_orb_drawer"),
		"skill_orb_renderer": _get_cached_module(registry, "smasher_skill_orb_renderer"),
		"horn_strawberry_skill_pillar_renderer": _get_cached_module(registry, "horn_strawberry_skill_pillar_renderer"),
		"horn_strawberry_context": _get_horn_strawberry_context(registry),
		"odins_eye_skill_pillar_renderer": _get_cached_module(registry, "odins_eye_skill_pillar_renderer"),
		"odins_eye_context": _get_odins_eye_context(registry),
		"commando_firearm_selector_renderer": selector_renderer,
		"commando_weapon_controller": weapon_controller,
		"commando_firearm_slingshot_state": _get_dict(commando_firearm_context.get("commando_firearm_slingshot_state", context.get("commando_firearm_slingshot_state", {}))),
		"commando_firearm_pistol_state": _get_dict(commando_firearm_context.get("commando_firearm_pistol_state", context.get("commando_firearm_pistol_state", {}))),
		"commando_firearm_weapon_fire_sheet_state": _get_dict(commando_firearm_context.get("commando_firearm_weapon_fire_sheet_state", context.get("commando_firearm_weapon_fire_sheet_state", {}))),
		"commando_firearm_suicide_drone_state": _get_dict(commando_firearm_context.get("commando_firearm_suicide_drone_state", context.get("commando_firearm_suicide_drone_state", {}))),
		"skill_config_snapshot": skill_config_snapshot,
	})


func _get_value(source: Dictionary, key: String) -> Variant:
	return source.get(key, null)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_horn_strawberry_context(registry: Object) -> Dictionary:
	var mythic_item_runtime: Object = _get_cached_module(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_horn_strawberry_context"):
		var value: Variant = mythic_item_runtime.get_horn_strawberry_context()
		if value is Dictionary:
			return value
	return {}


func _get_odins_eye_context(registry: Object) -> Dictionary:
	var mythic_item_runtime: Object = _get_cached_module(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_odins_eye_context"):
		var value: Variant = mythic_item_runtime.get_odins_eye_context()
		if value is Dictionary:
			return value
	return {}


func _build_gold_hud_amount(context: Dictionary, registry: Object) -> int:
	return maxi(0, _get_cached_plaza_gold(context, registry) + _get_runtime_gold(context, registry))


func _get_cached_plaza_gold(context: Dictionary, registry: Object) -> int:
	var stage_id: int = int(context.get("current_stage", 1))
	var result_screen: Object = _get_result_screen_from_registry(registry, false)
	if result_screen != null:
		_sync_plaza_gold_cache_from_result_screen(result_screen, stage_id, false)
	if _plaza_gold_cache_loaded:
		_plaza_gold_cache_stage = stage_id
	return _plaza_gold_cache_value


func _refresh_plaza_gold_cache_from_module_getter(_module_getter: Callable) -> void:
	# 프리웜은 결과화면 모듈을 콜드 생성하지 않는다 — 그 첫 인스턴스화가 전환
	# 프레임 1237ms 스톨의 정체였다(2026-07-24 [PrewarmColdInstantiate] 진단으로
	# 확정, fps=2). 광장 골드 캐시는 경량 PlazaSaveStore(기본 경로)에서 직접
	# 데운다. 결과화면의 get_plaza_save_summary()도 동일 PlazaSaveStore 클래스·
	# 동일 기본 경로(SAVE_PATH)에 위임할 뿐이라 프로덕션에서 값이 정확히 같다
	# (커스텀 경로는 set_plaza_save_path_for_test 테스트 전용). 결과화면은
	# 스테이지 클리어 시점(실제 필요 시)에 자연 생성된다. draw 경로는 이미
	# allow_lazy_create=false 피크라 결과화면을 강제 생성하지 않는다.
	# (Hot-Path Lazy Init Trap: 프리웜에서 무거운 모듈 강제 생성 금지 → 직접읽기.)
	# 드로어 자체 스토어의 현재 경로를 쓴다(프로덕션=기본 SAVE_PATH, 테스트는
	# set_plaza_gold_store_save_path_for_test로 오버라이드해 실 세이브 미오염).
	var plaza_save_path: String = PlazaSaveStore.SAVE_PATH
	if _plaza_gold_store != null:
		plaza_save_path = str(_plaza_gold_store.save_path)
	_reload_plaza_gold_cache(plaza_save_path, _plaza_gold_cache_stage)


# 테스트 전용: 프리웜 골드 캐시가 읽는 광장 세이브 경로를 임시 파일로
# 지정해 실 유저 세이브(user://plaza_save.cfg)를 오염시키지 않게 한다.
func set_plaza_gold_store_save_path_for_test(path: String) -> void:
	if _plaza_gold_store == null:
		_plaza_gold_store = PlazaSaveStore.new()
	if _plaza_gold_store.has_method("set_save_path"):
		_plaza_gold_store.set_save_path(path)


func _sync_plaza_gold_cache_from_result_screen(result_screen: Object, stage_id: int, allow_load: bool) -> bool:
	var summary: Dictionary = {}
	if result_screen.has_method("get_cached_plaza_save_summary"):
		summary = _get_dict(result_screen.get_cached_plaza_save_summary())
	if allow_load and result_screen.has_method("get_plaza_save_summary"):
		summary = _get_dict(result_screen.get_plaza_save_summary())
		var save_path: String = str(summary.get("save_path", _plaza_gold_cache_save_path)).strip_edges()
		if save_path != "":
			_reload_plaza_gold_cache(save_path, stage_id)
			return true
	return _apply_plaza_gold_cache_summary(summary, stage_id)


func _apply_plaza_gold_cache_summary(summary: Dictionary, stage_id: int) -> bool:
	if summary.is_empty() or not summary.has("plaza_gold"):
		return false
	_plaza_gold_cache_loaded = true
	_plaza_gold_cache_stage = stage_id
	_plaza_gold_cache_save_path = str(summary.get("save_path", "")).strip_edges()
	_plaza_gold_cache_value = maxi(0, int(summary.get("plaza_gold", 0)))
	return true


func _reload_plaza_gold_cache(save_path: String, stage_id: int) -> void:
	_plaza_gold_cache_loaded = true
	_plaza_gold_cache_stage = stage_id
	_plaza_gold_cache_save_path = save_path
	_plaza_gold_cache_value = 0
	if _plaza_gold_store == null:
		_plaza_gold_store = PlazaSaveStore.new()
	if save_path != "" and _plaza_gold_store.has_method("set_save_path"):
		_plaza_gold_store.set_save_path(save_path)
	if _plaza_gold_store.has_method("load"):
		_plaza_gold_store.load()
	if _plaza_gold_store.has_method("get_summary"):
		var summary: Dictionary = _get_dict(_plaza_gold_store.get_summary())
		_plaza_gold_cache_value = maxi(0, int(summary.get("plaza_gold", 0)))


func _get_result_screen_from_registry(registry: Object, allow_lazy_create: bool) -> Object:
	if registry == null:
		return null
	if not allow_lazy_create:
		return _get_cached_module(registry, "stage_clear_result_screen")
	if registry.has_method("get_instance"):
		var instance: Variant = registry.get_instance("stage_clear_result_screen")
		if typeof(instance) == TYPE_OBJECT and is_instance_valid(instance):
			return instance as Object
	return _get_cached_module(registry, "stage_clear_result_screen")


func _get_runtime_gold(context: Dictionary, registry: Object) -> int:
	if context.has("runtime_perk_gold"):
		return maxi(0, int(context.get("runtime_perk_gold", 0)))
	var runtime_gold := 0
	var runtime_perk_state: Object = _get_cached_module(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_snapshot"):
		var snapshot: Dictionary = _get_dict(runtime_perk_state.get_snapshot())
		runtime_gold = maxi(0, int(snapshot.get("gold_from_perks", 0)))
	return runtime_gold


func _skill_snapshot_has_skill(skill_config_snapshot: Dictionary, skill_id: String) -> bool:
	var equipped: Variant = skill_config_snapshot.get("equipped_skills", [])
	if not (equipped is Array):
		return false
	return (equipped as Array).has(skill_id)


func _is_cleanse_status_active(registry: Object) -> bool:
	if registry == null:
		return false
	var cleanse_state: Object = _get_cached_module(registry, "smasher_cleanse_state")
	if cleanse_state == null or not cleanse_state.has_method("has_status_effect"):
		return false
	return bool(cleanse_state.has_status_effect({
		"movement_state": _get_cached_module(registry, "player_movement_state"),
		"active_item_runtime": _get_cached_module(registry, "active_item_runtime"),
	}))


# Resolve the reactive-portrait face for boss + player from live runtime state.
# Priority: per-point score result (only during the scoreboard pulse window) >
# stun (pained) > neutral — mirrors the boss sprite contract (defeat/victory > stun).
# Stateless: reads current flags each frame; the ~1.75s scoreboard pulse means the
# happy/sad face flashes per point and returns to neutral between points (a latch +
# decay layer is a later slice). Boss stun currently reads the main status channel
# (covers active_item_boss_stun / status_boss_stun); ragnarok-hammer stun is a later
# refinement.
func _resolve_portrait_expressions(status_effect_state: Object, scoreboard_state: Object) -> Dictionary:
	var boss_expr := "neutral"
	var player_expr := "neutral"
	if scoreboard_state != null and scoreboard_state.has_method("is_active") and bool(scoreboard_state.is_active()):
		var side := ""
		if scoreboard_state.has_method("get_last_scoring_side"):
			side = str(scoreboard_state.get_last_scoring_side())
		if side == "player":
			boss_expr = "sad"
			player_expr = "happy"
		elif side == "boss":
			boss_expr = "happy"
			player_expr = "sad"
	if status_effect_state != null:
		if boss_expr == "neutral" and status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("boss", "stun")):
			boss_expr = "pained"
		if player_expr == "neutral" and status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
			player_expr = "pained"
	return {"boss": boss_expr, "player": player_expr}


func _normalize_expression(value: Variant) -> String:
	var id: String = str(value).strip_edges().to_lower()
	if id == EXPRESSION_HAPPY or id == EXPRESSION_SAD or id == EXPRESSION_PAINED:
		return id
	return EXPRESSION_NEUTRAL


func _resolve_portrait_face(textures: Dictionary, identity: Variant, expression: String) -> Dictionary:
	var normalized_identity: String = str(identity).strip_edges().to_lower()
	if normalized_identity != "dalji":
		return {}
	var portrait_texture: Variant = _get_value(textures, "boss_portrait_sheet")
	if not (portrait_texture is Texture2D):
		return {}
	var frame_index: int = 0
	match _normalize_expression(expression):
		EXPRESSION_NEUTRAL:
			frame_index = 0
		EXPRESSION_PAINED:
			frame_index = 1
		EXPRESSION_HAPPY:
			frame_index = 2
		EXPRESSION_SAD:
			frame_index = 3
	return {
		"texture": portrait_texture as Texture2D,
		"frame": frame_index,
		"cols": 2,
		"rows": 2,
		"head_source_rect": Rect2(0.13, 0.03, 0.68, 0.80),
		"tint": Color.WHITE,
	}


func _build_default_boss_dash_snapshot() -> Dictionary:
	return {
		"tokens": 1,
		"max_tokens": 1,
		"charge_timer": 0.0,
		"recharge_frames": 1.0,
		"charge_progress": 1.0,
		"available_timer": 1.0,
		"active": false,
		"recovering": false,
		"stun_timer": 0.0,
	}


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_character_prewarm_keys(character_type: String) -> Array:
	var keys: Array = []
	var skill_config_key: String = character_runtime.get_skill_config_key(character_type)
	var dash_state_key: String = character_runtime.get_dash_state_key(character_type)
	var combo_key: String = character_runtime.get_combo_state_key(character_type)
	var skill_state_key: String = character_runtime.get_skill_state_key(character_type)
	for character_key in [skill_config_key, dash_state_key, combo_key, skill_state_key]:
		if character_key != "" and not keys.has(character_key):
			keys.append(character_key)
	if combo_key != "":
		keys.append("smasher_combo_renderer")
	return keys


func _prewarm_modules(module_getter: Callable, keys: Array) -> void:
	for key_value in keys:
		_get_module(module_getter, str(key_value))


func _normalize_stage1_boss_variant(value: Variant) -> String:
	var variant: String = str(value).strip_edges().to_lower()
	if variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]:
		return "gaksi"
	if variant in ["podo", "pododaejang", "podo_daejang"]:
		return "podo"
	return "dalji"


func _get_stage1_boss_skill_cooldown_key(stage1_boss_variant: String) -> String:
	match _normalize_stage1_boss_variant(stage1_boss_variant):
		"gaksi":
			return "stage1_gaksital_boss_skill_cooldown_state"
		"dalji":
			return "stage1_dalji_boss_skill_cooldown_state"
	return ""


func _get_stage1_boss_skill_hud_key(stage1_boss_variant: String) -> String:
	match _normalize_stage1_boss_variant(stage1_boss_variant):
		"gaksi":
			return "stage1_gaksital_boss_skill_hud_renderer"
		"dalji":
			return "stage1_dalji_boss_skill_hud_renderer"
	return ""


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	# 진단(2026-07-24, 로딩 히치 조사): 이 헬퍼는 프리웜 전용 콜드
	# 인스턴스화 경로다(draw는 _get_cached_module 사용). stage1_pillar_scene
	# 프리웜 단일 스텝 1242ms의 정체가 어느 모듈의 첫 로드/컴파일인지 라벨이
	# 안 찍혀 미상이므로, 임계 초과 시 모듈 키와 함께 1회 경고한다. 실제 콜드
	# 스톨에서만 발화하는 비동작 계측(스텝당 1콜이라 오버헤드 무시).
	var cold_start: int = Time.get_ticks_usec()
	var value: Variant = module_getter.call(key)
	var cold_ms: float = float(Time.get_ticks_usec() - cold_start) / 1000.0
	if cold_ms >= 60.0:
		push_warning("[PrewarmColdInstantiate] stage1_pillar_hud module '%s' first-fetch %.1fms" % [key, cold_ms])
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_cached_module(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
		return null
	if registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null
