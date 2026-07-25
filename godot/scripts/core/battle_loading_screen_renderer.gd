extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LoadingCameoCatalog := preload("res://scripts/core/loading_cameo_catalog.gd")
const LoadingCameoHost := preload("res://scripts/core/loading_cameo_host.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const LEGACY_STAINED_GLASS_HOST_NODE_NAME := "BattleLoadingStainedGlassHost"
const MIN_LOADING_VISIBLE_SECONDS := 0.6
const FINAL_FADE_SECONDS := 0.2
const LOADING_FONT_PATHS := [
	"res://assets/fonts/NanumSquareB.ttf",
	"res://assets/fonts/PFStardust.ttf",
	"res://assets/fonts/NeoDunggeunmoPro.ttf",
]

var loading_font: Font = null
var loading_cameo_host: Node2D = null
var _loading_cameo_owner: Node = null
var _visible_started_msec: int = -1
var _completion_fade_started_msec: int = -1
var _legacy_host_sweep_done := false
var _tip_start_slot: int = -1


func build_snapshot(owner: Object, module_getter: Callable, context: Dictionary = {}) -> Dictionary:
	var battle_initialized := bool(context.get("battle_initialized", false))
	var stage_landing_intro_started := bool(context.get("stage_landing_intro_started", false))
	var warmup_finished := _is_warmup_finished(module_getter)
	var progress := _resolve_progress(module_getter, warmup_finished, battle_initialized, stage_landing_intro_started)
	if context.has("loading_progress"):
		progress = clampf(float(context.get("loading_progress", progress)), 0.0, 1.0)
	return {
		"title": LanguageSettings.translate_text(str(context.get("loading_title", "스테이지 진입 준비 중"))),
		"subtitle": LanguageSettings.translate_text(str(context.get("loading_subtitle", _build_subtitle(owner)))),
		"status": LanguageSettings.translate_text(str(context.get(
			"loading_status",
			_resolve_status_text(module_getter, warmup_finished, battle_initialized, stage_landing_intro_started)
		))),
		"progress": progress,
		"tip_tier": _resolve_tip_tier(owner),
		"tip_character": _resolve_tip_character(owner),
	}


func draw(
	canvas: CanvasItem,
	owner: Object,
	module_getter: Callable,
	view_size: Vector2,
	context: Dictionary = {}
) -> void:
	if canvas == null:
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(1280.0, 720.0)
	_sweep_legacy_loading_hosts_once(owner)
	_mark_visible_started()
	var snapshot := build_snapshot(owner, module_getter, context)
	var tick_seconds := Time.get_ticks_msec() / 1000.0
	var tip_tier := str(snapshot.get("tip_tier", BattleLoadingTips.TIER_ADVANCED))
	var tip_character := str(snapshot.get("tip_character", ""))
	# The tip rotation clock must be anchored to when THIS loading became
	# visible. Feeding absolute engine uptime opened every loading at a random
	# phase of the rotate window, so the first tip could flip away after a few
	# hundred milliseconds — unreadable on short loads. The start slot is
	# rolled once per loading session so variety comes from the session pick,
	# not from the random phase.
	LoadingCameoCatalog.draw_minimal_chrome(
		canvas,
		_get_loading_font(),
		view_size,
		tip_tier,
		tip_character,
		_elapsed_visible_seconds(),
		true,
		_resolve_tip_start_slot(tip_tier, tip_character)
	)
	var host := _ensure_loading_cameo_host(owner)
	if host != null:
		# Scene changes can expose the previous Control scene's logical size for
		# one draw. The node-backed cameo must use its attached live viewport or
		# that 1280x720 position lands near the center of the 2020px battle view.
		host.show_loading(view_size, tick_seconds, _get_loading_font(), true)


func prewarm_assets() -> void:
	_get_loading_font()
	LoadingCameoHost.prewarm_assets()


func prewarm_stage_assets(_stage: int) -> void:
	prewarm_assets()


func should_hold_completion(owner: Object, module_getter: Callable) -> bool:
	# The intro controller asks this before it activates Akamu's Stage 7 video.
	# Returning early is therefore the real exception gate; relying on the later
	# active-video draw branch would delay or softlock that handoff.
	if int(_safe_owner_get(owner, "current_stage", 1)) == 7:
		return false
	_mark_visible_started()
	if not _is_warmup_finished(module_getter):
		return false
	if _elapsed_visible_seconds() < MIN_LOADING_VISIBLE_SECONDS:
		return true
	_mark_completion_fade_started()
	return _elapsed_completion_fade_seconds() < FINAL_FADE_SECONDS


func hide_loading() -> void:
	_release_loading_cameo_host()
	_visible_started_msec = -1
	_completion_fade_started_msec = -1
	_legacy_host_sweep_done = false
	_tip_start_slot = -1


func release_stained_glass_hosts(owner: Object = null) -> void:
	# Compatibility entrypoint kept for the intro and stage-transition consumers.
	# The old renderer host is no longer created; only sweep a stale node that may
	# survive a hot reload from the previous loading implementation.
	_sweep_legacy_loading_hosts(owner)


func get_loading_cameo_debug_state() -> Dictionary:
	if loading_cameo_host == null or not is_instance_valid(loading_cameo_host):
		return {
			"entry_id": "",
			"frame_count": 0,
			"session_pick_count": 0,
			"visible": false,
			"sprite_count": 0,
		}
	return loading_cameo_host.get_debug_state()


func _resolve_progress(
	module_getter: Callable,
	warmup_finished: bool,
	battle_initialized: bool,
	stage_landing_intro_started: bool
) -> float:
	if not warmup_finished:
		return clampf(_get_warmup_progress(module_getter), 0.02, 0.92)
	if not battle_initialized:
		return 0.94
	if not stage_landing_intro_started:
		return 0.97
	return 1.0


func _resolve_tip_start_slot(tip_tier: String, tip_character: String) -> int:
	if _tip_start_slot < 0:
		var slot_count := BattleLoadingTips.get_rotation_tip_count(tip_tier, tip_character)
		_tip_start_slot = 0 if slot_count <= 0 else randi() % slot_count
	return _tip_start_slot


func _ensure_loading_cameo_host(owner: Object) -> Node2D:
	if loading_cameo_host != null and is_instance_valid(loading_cameo_host):
		if _loading_cameo_owner == owner:
			return loading_cameo_host
		_release_loading_cameo_host()
	if not (owner is Node):
		return null
	loading_cameo_host = LoadingCameoHost.new()
	_loading_cameo_owner = owner as Node
	_loading_cameo_owner.add_child(loading_cameo_host)
	return loading_cameo_host


func _release_loading_cameo_host() -> void:
	if loading_cameo_host != null and is_instance_valid(loading_cameo_host):
		loading_cameo_host.tear_down()
		var parent := loading_cameo_host.get_parent()
		if parent != null:
			parent.remove_child(loading_cameo_host)
		loading_cameo_host.free()
	loading_cameo_host = null
	_loading_cameo_owner = null


func _sweep_legacy_loading_hosts_once(owner: Object) -> void:
	if _legacy_host_sweep_done:
		return
	_legacy_host_sweep_done = true
	_sweep_legacy_loading_hosts(owner)


func _sweep_legacy_loading_hosts(owner: Object) -> void:
	if owner is Node:
		_release_named_legacy_hosts(owner as Node)


func _release_named_legacy_hosts(root: Node) -> void:
	for child in root.get_children():
		if not (child is Node):
			continue
		var child_node := child as Node
		if child_node.name == LEGACY_STAINED_GLASS_HOST_NODE_NAME:
			if child_node.has_method("hide_loading"):
				child_node.call("hide_loading")
			if child_node is CanvasItem:
				(child_node as CanvasItem).visible = false
			child_node.set_process(false)
			child_node.set_physics_process(false)
			root.remove_child(child_node)
			child_node.queue_free()
			continue
		_release_named_legacy_hosts(child_node)


func _mark_visible_started() -> void:
	if _visible_started_msec < 0:
		_visible_started_msec = Time.get_ticks_msec()


func _mark_completion_fade_started() -> void:
	if _completion_fade_started_msec < 0:
		_completion_fade_started_msec = Time.get_ticks_msec()


func _elapsed_visible_seconds() -> float:
	if _visible_started_msec < 0:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - _visible_started_msec) / 1000.0)


func _elapsed_completion_fade_seconds() -> float:
	if _completion_fade_started_msec < 0:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - _completion_fade_started_msec) / 1000.0)


func _resolve_status_text(
	module_getter: Callable,
	warmup_finished: bool,
	battle_initialized: bool,
	stage_landing_intro_started: bool
) -> String:
	if not warmup_finished:
		var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
		if warmup != null and warmup.has_method("get_status_text"):
			return LanguageSettings.translate_text(str(warmup.get_status_text()))
		return LanguageSettings.translate_text("전투 데이터 준비 중")
	if not battle_initialized:
		return LanguageSettings.translate_text("전투 상태 초기화 중")
	if not stage_landing_intro_started:
		return LanguageSettings.translate_text("스테이지 입장 연출 준비 중")
	return LanguageSettings.translate_text("준비 완료")


func _get_warmup_progress(module_getter: Callable) -> float:
	var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
	if warmup != null and warmup.has_method("get_progress"):
		return float(warmup.get_progress(module_getter))
	if _is_warmup_finished(module_getter):
		return 1.0
	return 0.12


func _is_warmup_finished(module_getter: Callable) -> bool:
	var warmup: Object = _get_module(module_getter, "battle_boot_warmup_controller")
	if warmup != null and warmup.has_method("is_finished"):
		return bool(warmup.is_finished())
	var readiness: Object = _get_module(module_getter, "battle_scene_readiness_controller")
	if readiness != null and readiness.has_method("is_boot_warmup_finished"):
		return bool(readiness.is_boot_warmup_finished(module_getter))
	return true


func _resolve_tip_tier(owner: Object) -> String:
	return BattleLoadingTips.tier_for_league(
		BattleSceneConfig.normalize_league_mode(str(_safe_owner_get(owner, "ai_mode", "champion")))
	)


func _resolve_tip_character(owner: Object) -> String:
	return BattleLoadingTips.normalize_character_type(
		str(_safe_owner_get(owner, "selected_character_type", "smasher"))
	)


func _build_subtitle(owner: Object) -> String:
	var stage: int = maxi(1, int(_safe_owner_get(owner, "current_stage", 1)))
	var character_name := str(_safe_owner_get(owner, "selected_character_name", ""))
	if character_name.strip_edges() == "":
		character_name = _character_name_from_runtime(str(_safe_owner_get(owner, "selected_character_type", "smasher")))
	return LanguageSettings.format_stage_character_label(stage, character_name)


func _character_name_from_runtime(character_type: String) -> String:
	match character_type.strip_edges().to_lower():
		"viper":
			return LanguageSettings.translate_text("바이퍼")
		"soldier", "commando":
			return LanguageSettings.translate_text("코만도")
		"blacksmith", "baltor":
			return LanguageSettings.translate_text("발토르")
		"optimus":
			return LanguageSettings.translate_text("옵티머스")
	return LanguageSettings.translate_text("스매셔")


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _get_loading_font() -> Font:
	if loading_font != null:
		return loading_font
	for path_value in LOADING_FONT_PATHS:
		var path: String = str(path_value)
		var font := ProjectResourceLoader.load_font(path)
		if font != null:
			loading_font = font
			return loading_font
	loading_font = ThemeDB.fallback_font
	return loading_font


func _draw_centered_text(canvas: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
